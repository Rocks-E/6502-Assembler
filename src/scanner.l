/*
 * Lexer definition for 6502 assembly.
 */

/*
 * Since we're only parsing 1 file, we don't need to have yywrap() (plus,
 * having it included messes up compilation).
 */
%option noyywrap

%option yylineno

%{
#include <iostream>
#include <fstream>
#include <cstdlib>
#include <cstdint>
#include <string>
#include <map>
#include "parser.hpp"

#define YY_USER_ACTION yylloc.first_line = yylloc.last_line = yylineno; yylloc.first_column = indent + 1;
#define PUSH_TOKEN(token) do { \
	int32_t s = yypush_parse(pstate, token, &yylval, &yylloc); \
	if(s != YYPUSH_MORE) { \
		yypstate_delete(pstate); \
		return s; \
	} \
} while(0)

YYSTYPE yylval;
YYLTYPE yylloc;
yypstate *pstate = yypstate_new();

extern uint8_t rom_dump[ROM_SIZE];

std::string *to_upper(char *str) {
	
	int32_t c;
	std::string *result = new std::string(str);	
	
	for(c = 0; c < result->length(); c++) {
		if((*result)[c] > 0x60 && (*result)[c] < 0x7B) {
			(*result)[c] -= 0x20;
		}
	}
	
	return result;
	
}

%}

 /* Identifiers can use letters, numbers, and underscores but must start with a letter or underscore */
IDENTIFIER [a-zA-Z_][a-zA-Z_0-9]*
 /* Instruction pneumonics used for 6502 instruction set, all except one instruction (USBC) are 3 letters */
INSTRUCTION [A-Za-Z]{3,4}
 /* Numeric operands, can be of four different types: $[0-9A-F]+ - hex, 0[0-7]+ - octal, %[01]+ - binary, [1-9][0-9]* - decimal */
OPERAND (\$[0-9A-Fa-f]+|[1-9][0-9]*|0[0-7]+|\%[01]+)
 /* Any form of punctuation marks including left and right parentheses, commas, colons, and periods */
PUNCTUATION (\(|\)|\,|\:|\.)
 /* Newline, compatible with both CRLF and LF */
NEWLINE \r?\n

%%

^;.*{NEWLINE} {
	//Consume whole-line comments
}

;.* {
	//Consume in-line comment
}

 /* Label to name a memory address */
\: {
	PUSH_TOKEN(LABEL);
}

 /* Instruction, starts with any number of tabs and then the pneumonic */
^[\t ]*{INSTRUCTION} {
	yylval = to_upper(yytext);
	PUSH_TOKEN(INSTRUCTION);
}

 /* Numeric operand, can be in hexadecimal, decimal, octal, or binary depending on prefix ($, 1-9, 0, and % respectively). Literal if prefixed with # */
#?{OPERAND} {

	int32_t return_token;
	uint8_t radix, pos;

	// Set the position according to where the number should begin and the return token to either LITERAL (immediate) or ADDRESS
	if(yytext[0] == '#') {
		pos = 2;
		return_token = LITERAL;
	}
	else {
		pos = 1;
		return_token = ADDRESS;
	}
	
	// Use the given prefix to determine 
	switch(yytext[pos - 1]) {
			
		// Hexadecimal
		case '$':
			radix = 16;
			break;
		// Octal
		case '0':
			radix = 8;
			break;
		// Binary:
		case '%':
			radix = 2;
			break;
		// Decimal (or error)
		default:
			if(yytext[1] < '1' || yytext[1] > '9') {
				// Throw error
			}
			
			radix = 10;
		
	}
	
	// Get the specified value as the radix determined above
	yylval = std::stoul(yytext + pos, nullptr, radix); 

	PUSH_TOKEN(return_token);
	
}

 /* Named value */
{IDENTIFIER} {
	yylval = new std::string(yytext);
	PUSH_TOKEN(IDENTIFIER);
}

 /* Determine which register should be used for indexing */
\, ?([yY]|[xX]) {
	
	int32_t return_token;
	
	switch(yytext[strlen(yytext) - 1]) {
		case 'y':
		case 'Y':
			return_token = COMMA_Y;
			break;
		case 'x':
		case 'X':
			return_token = COMMA_X;
			break;
	}
	
	PUSH_TOKEN(return_token);
	
}

 /* Directives for declaring byte (8 bit) or word (16 bit), and org (move to another memory address) */
\.([bB][yY][tT][eE]|[wW][oO][rR][dD]|[oO][rR][gG]) {
	
	int32_t return_token;
	
	switch(yytext[1]) {
		case 'b':
		case 'B':
			return_token = BYTE;
			break;
		case 'w':
		case 'W':
			return_token = WORD;
			break;
		case 'o':
		case 'O':
			return_token = ORG;
			break;
	}
	
	PUSH_TOKEN(return_token);
	
}

 /* Catch any punctuation marks */
{PUNCTUATION} {
	
	int32_t return_token;
	
	switch(yytext[0]) {
		case '(':
			return_token = LPAREN;
			break;
		case ')':
			return_token = RPAREN;
			break;
		case ',':
			return_token = COMMA;
			break;
		case ':':
			return_token = COLON;
			break;
		default:
			
	}
	
	PUSH_TOKEN(return_token);
	
}

 /* Used to specify the accumulator for a small subset of instructions */
a|A {
	PUSH_TOKEN(ACCUMULATOR)
}

^[\r\n\t ]*\n {
	//Consume empty lines
}

{NEWLINE} {
	PUSH_TOKEN(NEWLINE);
}

[ \t\r\n] {
	//Consume whitespace
}

<<EOF>> {

	int32_t s = yypush_parse(pstate, 0, NULL, NULL);
	yypstate_delete(pstate);
	return s;
	
}

. {
	std::cerr << "Bad character received on line " << yylineno << ": " << *yytext << '\n';
	PUSH_TOKEN(*yytext);
}

%%

int32_t main() {

	/*
	while((opt = getopt_long()) != -1) {
		switch(opt) {
			case 'i':
				
				break;
			case 'o':
			
				break;
		}
	}	
	*/

	if(!yylex()) {
		outfile.open(outfile_name);
		outfile.write(rom_dump, ROM_SIZE);
		outfile.close();
	}
	else {
		//
	}
	return 0;
}
