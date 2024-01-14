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
#include <getopt.h>
#include "opcodes.hpp"
#include "parser_structs.hpp"
#include "preprocessor.hpp"

#include "parser.hpp"

#define YY_USER_ACTION yylloc.first_line = yylloc.last_line = yylineno;
#define PUSH_TOKEN(token) do { \
	int32_t s = yypush_parse(pstate, token, &yylval, &yylloc); \
	if(s != YYPUSH_MORE) { \
		yypstate_delete(pstate); \
		return s; \
	} \
} while(0)
	
#define TEMP_FILENAME ".tmp_f.asm"
#define OPTSTRING "i:o:h"
#define ROM_SIZE 0x10000

YYSTYPE yylval;
YYLTYPE yylloc;
yypstate *pstate = yypstate_new();

extern FILE *yyin;

extern uint8_t rom_dump[];

extern std::map<std::string, std::string> symbols_table;

std::string *to_upper(char *str) {
	
	std::string *result = new std::string(str);	
	
	for(size_t c = 0; c < result->length(); c++)
		if((result->at(c) > 0x60) && (result->at(c) < 0x7B))
			result->at(c) -= 0x20;
	
	return result;
	
}

char to_upper(char c) {
	return (c > 0x60 && c < 0x7B) ? c - 0x20 : c;
}

template <class T>
bool vector_contains(std::vector<T> vec, T val) {
	return (std::find(vec.begin(), vec.end(), val) != vec.end());
}

uint8_t reserved_type(std::string str) {
	
	// Return 1 for valid instructions
	if(vector_contains(instruction_names, str))
		return 1;
	
	// Return 2 for accumulator
	if(str == "A")
		return 2;
	
	// For any non-reserved identifiers, return 0
	return 0;
	
}

%}

 /* Instruction pneumonics used for 6502 instruction set, all except one illegal and useless instruction (USBC) are 3 letters */
DIRECTIVE (BYTE)|(WORD)|(ORG)
 /* Identifiers can use letters, numbers, and underscores but must start with a letter or underscore */
IDENTIFIER [A-Z_][A-Z_0-9]*
 /* Numeric operands, can be of four different types: $[0-9A-F]+ - hex, 0[0-7]+ - octal, %[01]+ - binary, [1-9][0-9]* - decimal */
OPERAND $[0-9A-F]+
 /* Any form of punctuation marks including left and right parentheses, commas, colons, and periods */
PUNCTUATION \(|\)|\,|\.|\=
 /* Binary operations */
EXPRESSION_TOKEN \+|\-|\*|\/|\[|\]
 /* Newline, compatible with both CRLF, LF, and CR */
NEWLINE (\r?\n)|\r
WHITESPACE [ \t]+

%%

 /* Label to name a memory address */
{IDENTIFIER}\: {
	
	// Cut off the colon
	std::string text_string(yytext);
	text_string.pop_back();
	
	yylval.str = new std::string(text_string);
	
	if(reserved_type(text_string))
		throw new std::domain_error("ERROR: Cannot use restricted keyword as label name.");
	
	PUSH_TOKEN(LABEL);
	
}

# {
	PUSH_TOKEN(HASH);
}

 /* Instruction, accumulator, or label used in a statement */
{IDENTIFIER} {
	
	int32_t return_token;
	
	switch(reserved_type({yytext})) {
		
		case 0:
			return_token = IDENTIFIER;
			break;
		
		case 1:
			return_token = INSTRUCTION;
			break;
		
		case 2:
			return_token = ACCUMULATOR;
			break;
		
	}
	
	yylval.str = new std::string(yytext);
	PUSH_TOKEN(return_token);
	
}

 /* Numeric operand, can be in hexadecimal ONLY thanks to preprocessor. Immediate if prefixed with # */
{OPERAND} {

	// Get the specified value as hex
	yylval.u16 = std::stoul(yytext + 1, nullptr, 0x10);

	PUSH_TOKEN(ADDRESS);
	
}

 /* Determine which register should be used for indexing */
\,(Y|X) {
	
	int32_t return_token;
	
	switch(yytext[1]) {
		
		case 'Y':
			return_token = COMMA_Y;
			break;
			
		case 'X':
			return_token = COMMA_X;
			break;
			
	}
	
	PUSH_TOKEN(return_token);
	
}

 /* Directives for declaring byte (8 bit) or word (16 bit), and org (move to another memory address) */
\.{DIRECTIVE} {
	
	int32_t return_token;
	
	switch(yytext[1]) {
		
		case 'B':
			return_token = BYTE;
			break;
			
		case 'W':
			return_token = WORD;
			break;
			
		case 'O':
			return_token = ORG;
			break;
			
	}
	
	PUSH_TOKEN(return_token);
	
}

{EXPRESSION_TOKEN} {
	
	int32_t return_token;
	
	switch(yytext[0]) {
		
		case '+':
			return_token = PLUS;
			break;
			
		case '-':
			return_token = MINUS;
			break;
		
		case '*':
			return_token = TIMES;
			break;
		
		case '/':
			return_token = DIVIDE;
			break;
		
		case '[':
			return_token = LBRACKET;
			break;
		
		case ']':
			return_token = RBRACKET;
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

	}
	
	PUSH_TOKEN(return_token);
	
}

{WHITESPACE} {
	
}

{NEWLINE} {
	PUSH_TOKEN(NEWLINE);
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

int32_t main(int32_t argc, char * const *argv) {

	char *in_filename = nullptr, *out_filename = nullptr;

	while(1) {
		int32_t opt;
		static struct option long_options[] = {
			{"in_file", 	required_argument, 	0, 'i'},
			{"out_file",	required_argument, 	0, 'o'},
			{"help",		no_argument,		0, 'h'},
			{0,				0,					0,   0}
		};
		
		if((opt = getopt_long(argc, argv, OPTSTRING, long_options, NULL)) == -1)
			break;
		
		switch(opt) {
			case 'i':
				in_filename = optarg;
				break;
				
			case 'o':
				out_filename = optarg;
				break;
				
			case 'h':
				std::cout << "I dunno help or something\n";
				return 0;
			
		}
	}
	
	if(in_filename == nullptr || out_filename == nullptr) {
		
		std::cerr << "ERROR: Must define an output file\n";
		
		return 1;
		
	}
	
	std::fstream asm_file(in_filename, std::ios::in);
	if(!asm_file) 
		throw new std::runtime_error("Unable to open file for reading.");
	
	std::string asm_string = strip_info(asm_file);
	asm_file.close();
	
	for(std::pair<std::string, std::string> constant : symbols_table)
		find_and_replace(asm_string, std::get<0>(constant), std::get<1>(constant));
	
	convert_radix(asm_string, 16, 2);
	convert_radix(asm_string, 16, 8);
	convert_radix(asm_string, 16, 10);
	
	std::fstream temp_file(TEMP_FILENAME, std::ios::out | std::ios::trunc);
	temp_file << asm_string;
	temp_file.close();
	
	yyin = fopen(TEMP_FILENAME, "r");
	if(!yyin)
		throw new std::runtime_error("Unabled to open file for reading.");

	if(!yylex()) {
		remove(TEMP_FILENAME);
		std::ofstream out_file(out_filename, std::ios::out | std::ios::binary | std::ios::trunc);
		out_file.write((char *)rom_dump, ROM_SIZE);
		out_file.close();
	}
	else {
		std::cerr << "Ah fuck\n";
		return 1;
	}
	
	return 0;
	
}
