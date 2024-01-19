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
#define OPTSTRING "i:o:lskvh"
#define MAX_ROM_SIZE 0x10000

YYSTYPE yylval;
YYLTYPE yylloc;
yypstate *pstate = yypstate_new();

extern FILE *yyin;
extern uint8_t rom_dump[];
//extern std::map<std::string, std::string> symbols_table;

extern uint16_t latest_location;

bool _verbose = false;

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
 /* Newline, compatible with CRLF, LF, and CR */
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
	bool keep_temp = false, shrink_rom = false;
	size_t rom_size_limit = MAX_ROM_SIZE;

	while(1) {
		int32_t opt;
		static struct option long_options[] = {
			{"in_file", 	required_argument, 	0, 'i'},
			{"out_file",	required_argument, 	0, 'o'},
			{"limit_size",	required_argument,	0, 'l'},
			{"shrink_rom",	no_argument,		0, 's'},
			{"keep_temp",	no_argument,		0, 'k'},
			{"verbose",		no_argument,		0, 'v'},
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
				
			case 'l':
				try {
					
					// Set the size limit to the specified size
					rom_size_limit = std::stoul(optarg);
					
					// If it exceeds 64KiB, set to 64KiB
					if(rom_size_limit > MAX_ROM_SIZE)
						rom_size_limit = MAX_ROM_SIZE;
					
				}
				// If this is not a valid decimal number, notify the user
				catch (std::invalid_argument &ia) {
					
					std::cerr << "ERROR: Please enter a decimal value for the ROM size limit.\n";
					return -2;
					
				}
				// If this is outside the range of an unsigned short, set to 64KiB
				catch (std::out_of_range &oor) {
					rom_size_limit = MAX_ROM_SIZE;
				}
				
				break;
				
			case 's':
				shrink_rom = true;
				break;
				
			case 'k':
				keep_temp = true;
				break;
				
			case 'v':
				_verbose = true;
				break;
				
			case 'h':
				std::cout << argv[0] << "\n"
				"Converts 6502 assembly files to 6502 machine language files.\n"
				"Usage: " << argv[0] << " --[i]n_file <asm_file> --[o]ut_file <bin_file> (--[l]imit_size <byte_count>) (--[s]hrink_rom) (--[k]eep_temp) (--[v]erbose) (--[h]elp)\n"
				"\t[i] - Specify an input 6502 ASM file to convert\n"
				"\t[o] - Specify the name and location of the 6502 binary file to output\n"
				"\t[l] - Set the maximum generated ROM size (default 64KiB)\n"
				"\t[s] - Shrink the ROM to fit the latest necessary index determined by the ASM file\n"
				"\t[k] - Prevent the temporary ASM file created by the preprocessor from being deleted\n"
				"\t[v] - Turn on verbose messaging. WARNING: May include a *lot* of text\n"
				"\t[h] - Display this message\n";
				return 0;
				
			default:
				std::cerr << "Uknown command line argument: " << opt << '\n';
				return -1;
			
		}
	}
	
	if(in_filename == nullptr || out_filename == nullptr) {
		
		std::cerr << "ERROR: Must define an output file\n";
		
		return -2;
		
	}
	
	std::fstream asm_file(in_filename, std::ios::in);
	if(!asm_file) {
		std::cerr << "Unable to open ASM file for reading.\n";
		return -3;
	}
	
	// String to store the stripped assembly file info in a helpful configuration
	std::string asm_string;
	
	// Preprocessor stuff, pull in the input file, strip symbol info for replacing, remove unnecessary info
	{
		
		// Build a symbol table, strip the file and close
		std::map<std::string, std::string> symbols_table;
		asm_string = strip_info(asm_file, symbols_table);
		asm_file.close();
		
		// Replace each symbol discovered
		for(std::pair<std::string, std::string> constant : symbols_table)
			find_and_replace(asm_string, std::get<0>(constant), std::get<1>(constant));
		
	}
	
	// Change all "just 0" values to $00
	// Seems kinda hacky but it saves on some headaches for the numeric conversion step
	fix_zeros(asm_string);
	
	// Convert each binary, octal, and decimal value into hexadecimal
	// This makes it easy to check for the hex prefix for any numbers and standardizes the radix
	convert_radix(asm_string, 16, 2);
	convert_radix(asm_string, 16, 8);
	convert_radix(asm_string, 16, 10);
	
	// Write the formatted ASM to a temp file so we can set yyin to read from it
	std::fstream temp_file(TEMP_FILENAME, std::ios::out | std::ios::trunc);
	temp_file << asm_string;
	temp_file.close();
	
	// Set yyin to the temp file, make sure it opens successfully
	yyin = fopen(TEMP_FILENAME, "r");
	if(!yyin) {
		
		if(!keep_temp)
			remove(TEMP_FILENAME);
		
		std::cerr << "Unable to open temp file for reading.\n";
		return -4;
		
	}

	// Scan and parse
	if(!yylex()) {
		
		// Remove the temporary file unless -k is specified
		if(!keep_temp)
			remove(TEMP_FILENAME);
		
		// If [s], shrink the ROM to its smallest possible size given the input
		// If the size [l]imit is set lower, use this instead
		if(shrink_rom)
			rom_size_limit = rom_size_limit < latest_location ? rom_size_limit : latest_location;
		
		// Open the intended output file, write the ROM, and close
		std::ofstream out_file(out_filename, std::ios::out | std::ios::binary | std::ios::trunc);
		
		// Limit the ROM to the size specified
		out_file.write((char *)rom_dump, rom_size_limit);
		out_file.close();
		
	}
	else {
		
		if(!keep_temp)
			remove(TEMP_FILENAME);
		
		std::cerr << "Ah fuck\n";
		return 1;
		
	}
	
	return 0;
	
}
