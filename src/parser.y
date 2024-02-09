/* Something */

%{
#include <iostream>
#include <string>
#include <cstdint>
#include <vector>
#include <map>
#include "opcodes.hpp"
#include "parser_structs.hpp"

#include "parser.hpp"

#define MAX_ROM_SIZE 0x10000

//Store label
extern std::map<std::string, uint16_t> constants;
extern bool _verbose;

uint16_t latest_location = 0;

static char _error = 0;

uint8_t rom_dump[MAX_ROM_SIZE] = {0};

void yyerror(YYLTYPE *loc, char const *err);

extern int yylex();

%}

%define api.pure full
%define api.push-pull push

%union {
	std::vector<expression_data> *exp_vec;
	std::vector<statement_data> *stmnt_vec;
	statement_data *stmnt;
	std::string *str;
	address_data *addr;
	expression_data *exp_data;
	uint32_t u32;
}

%token HASH TIMES DIVIDE PLUS MINUS AND OR XOR NOT LSHIFT RSHIFT
%token ACCUMULATOR COMMA_X COMMA_Y
%token LPAREN RPAREN COMMA COLON NEWLINE LBRACKET RBRACKET
%token BYTE WORD ORG

%token <str> IDENTIFIER INSTRUCTION LABEL
%token <u32> ADDRESS

%type <stmnt_vec> statement_list
%type <stmnt> statement op_statement directive_statement data_statement
%type <exp_vec> byte_list word_list 
%type <addr> address_value
%type <exp_data> expression s_expression a_expression m_expression u_expression p_expression 

%left TIMES DIVIDE
%left PLUS MINUS
%left AND OR XOR
%right NOT

%start program

%locations

%define parse.error verbose

%%

program
	/* Rolled up program */
	/* Convert each statement sequentially into its binary equivalent */
	/* Any time a label is encountered, replace it with the current byte */
	: statement_list {
	
		//std::cout << "Starting roll-up\n";
		
		std::vector<statement_data> program_list = *$1;
	
		uint16_t current_byte = 0;
		
		// Set each label
		// Determine the byte location for each statement
		for(statement_data &current_line : program_list) {
			
			current_line.location = current_byte;
			
			switch(current_line.stmnt_mode) {
				
				// Insert the label into the constants table at the current byte
				case STATEMENT_MODE::ST_LABEL:
					if(constants.contains(current_line.op_name))
						throw new std::logic_error("Cannot name a label twice.");
					constants.insert(std::pair<std::string, uint16_t>(current_line.op_name, current_byte));
					break;
					
				// Evaluate the org expression and move to that byte
				case STATEMENT_MODE::ST_ORG:
					current_line.replace_labels();
					current_byte = current_line.operand_expressions[0].evaluate();
					break;
					
				// Move the current_byte cursor by however many bytes this instruction/dataset takes
				case STATEMENT_MODE::ST_DATA_WORD:
				case STATEMENT_MODE::ST_DATA_BYTE:
				case STATEMENT_MODE::ST_OPERATION:
				{
					
					uint16_t line_byte_count = current_line.byte_count();
					// Check if the statement will overflow the ROM
					// Maybe we could use some form of banking to allow for bigger ROM compilation
					// This will not prevent writing the ROM, but it will overwrite early ROM values
					if(MAX_ROM_SIZE - current_byte < line_byte_count) {
						std::cerr << "WARNING: Max ROM size exceeded!\n";
						_error++;
						latest_location = MAX_ROM_SIZE - 1;
					}
					
					current_byte += line_byte_count;
					
					// Update the latest location if it is less than the current byte, for use in the [s]hrink ROM option
					if(latest_location < current_byte)
						latest_location = current_byte;
					
				}
				
			}
			
		}
		
		//std::cout << "Last location used: " << latest_location << '\n';
		
		//std::cout << "Labels and locations have been set.\n";
		
		// All labels and locations have been determined, evaluate all statements and write to the ROM
		for(statement_data &current_line : program_list) {
			
			// Skip org/label statements
			if(current_line.stmnt_mode == STATEMENT_MODE::ST_ORG || current_line.stmnt_mode == STATEMENT_MODE::ST_LABEL)
				continue;
			
			// Replace labels and evaluate
			current_line.replace_labels();
			std::vector<uint8_t> line_bytes = current_line.to_binary(current_line.location);
			
			// Write to ROM
			for(size_t c = 0; c < line_bytes.size(); c++)
				rom_dump[current_line.location + c] = line_bytes[c];
			
		}
		
	}
	;
	
statement_list
	// Take the current statement_list, add new statements to the end of it
	: statement NEWLINE statement_list {
		
		/*
		$$ = new std::vector<statement_data>(*$1);
		delete $1;
		
		$$->push_back(*$3);
		delete $3;
		*/
		
		////std::cout << *$1 << '\n';
		
		$$ = new std::vector<statement_data>(*$3);
		delete $3;
		
		$$->insert($$->begin(), *$1);
		delete $1;
		
	}
	// Base statement case, just add to a statement vector
	| statement {
		
		////std::cout << "Base: " << *$1 << '\n';
		
		$$ = new std::vector<statement_data>();
		
		$$->push_back(*$1);
		delete $1;
		
	}
	;
	
statement
	/* Operation (instruction) statement */
	// Fine as is
	: op_statement
	/* .byte, .word, or .org statement */
	// Empty if .org statement, n/2n bytes for .byte and .word statements
	| directive_statement
	/* Set a label, should only be done once per label since a label can only point to one address */
	| LABEL {
		
		$$ = new statement_data(*$1);
		delete $1;
		
		$$->stmnt_mode = STATEMENT_MODE::ST_LABEL;
		
	}
	;

op_statement
	/* OPC (ADDR, X) -> X-indexed, indirect -> mem[zpg[addr + x]] */
	/* 2 byte operation */
	: INSTRUCTION LPAREN expression COMMA_X RPAREN {
		
		//std::cout << "Ind x\n";
		
		$$ = new statement_data(*$1, *$3, ADDR_MODE::INDIRECT_X);
		delete $1; delete $3;
		
	}
	/* OPC (ADDR), Y -> Indirect, Y-indexed -> mem[zpg[addr] + y + c] */
	/* 2 byte operation */
	| INSTRUCTION LPAREN expression RPAREN COMMA_Y {
		
		//std::cout << "Ind y\n";
		
		$$ = new statement_data(*$1, *$3, ADDR_MODE::INDIRECT_Y);
		delete $1; delete $3;
		
	}
	/* OPC (ADDR) -> Indirect -> mem[mem[addr]] */
	/* 3 byte operation - ONLY APPLICABLE TO JMP */
	| INSTRUCTION LPAREN expression RPAREN {
		
		//std::cout << "Ind\n";
		
		$$ = new statement_data(*$1, *$3, ADDR_MODE::INDIRECT);
		delete $1; delete $3;

	}
	/* OPC ADDR, X -> Absolute, X-indexed OR zeropage, X-indexed -> mem[addr + x] OR zpg[addr + x] (effectively mem[addr + x] where addr < 0x100) */
	/* 2 bytes if zeropage, 3 bytes if absolute */
	| INSTRUCTION expression COMMA_X {
		
		//std::cout << "Abs/zpg x\n";
		
		$$ = new statement_data(*$1);
		delete $1;
		
		//std::cout << "Statement created\n";
		
		ADDR_MODE op_mode = $2->contains_label() || $2->evaluate() > 0xFF ? ADDR_MODE::ABSOLUTE_X : ADDR_MODE::ZEROPAGE_X;
		$$->op_mode = op_mode;
		
		//std::cout << "Address mode set\n";
		
		$$->operand_expressions.push_back(*$2);
		delete $2;
		
		//std::cout << "Operand pushed\n";
		
		//std::cout << *$$ << '\n';
		
	}
	/* OPC ADDR, Y -> Absolute, Y-indexed OR zeropage, Y-indexed -> mem[addr + y] OR zpg[addr + y] (effectively mem[addr + y] where addr < 0x100) */
	/* 2 bytes if zeropage, 3 bytes if absolute */
	| INSTRUCTION expression COMMA_Y {
		
		//std::cout << "Abs/zpg y\n";
		
		$$ = new statement_data(*$1);
		delete $1;
		
		ADDR_MODE op_mode = $2->contains_label() || $2->evaluate() > 0xFF ? ADDR_MODE::ABSOLUTE_Y : ADDR_MODE::ZEROPAGE_Y;
		
		$$->op_mode = op_mode;
		
		$$->operand_expressions.push_back(*$2);
		delete $2;
		
	}
	/* OPC ADDR -> Zeropage, absolute, or relative */
	| INSTRUCTION expression {
		
		//std::cout << "Abs/zpg/rel\n";
		
		$$ = new statement_data(*$1);
		delete $1;
		
		//std::cout << "Statement created\n";
		
		ADDR_MODE op_mode;
		if($$->op_name[0] == 'B' && $$->op_name != "BIT")
			op_mode = ADDR_MODE::RELATIVE;
		else
			op_mode = $2->contains_label() || $2->evaluate() > 0xFF ? ADDR_MODE::ABSOLUTE : ADDR_MODE::ZEROPAGE;
		
		$$->op_mode = op_mode;
		
		//std::cout << "Address mode set\n";
		
		$$->operand_expressions.push_back(*$2);
		delete $2;
		
		//std::cout << "Operand pushed\n";
		
		//std::cout << *$$ << '\n';
		
	}
	| INSTRUCTION ACCUMULATOR {
		
		//std::cout << "Acc\n";
		
		$$ = new statement_data(*$1, ADDR_MODE::IMPLIED);
		delete $1;
		
	}
	/* OPC # -> Immediate, opcode followed by a literal expression */
	| INSTRUCTION HASH expression {
		
		//std::cout << "Imm\n";
		
		$$ = new statement_data(*$1, *$3, ADDR_MODE::IMMEDIATE);
		delete $1; delete $3;		
		
	}
	/* OPC -> Implied, no further parameters are needed */
	/* 1 byte */
	| INSTRUCTION {
		
		//std::cout << "Imp\n";
		
		$$ = new statement_data(*$1);
		delete $1;
		
		$$->op_mode = ADDR_MODE::IMPLIED;
		
	}
	;

directive_statement
	: data_statement
	| ORG expression {
		
		$$ = new statement_data();
		
		$$->operand_expressions.push_back(*$2);
		delete $2;
		
		$$->stmnt_mode = STATEMENT_MODE::ST_ORG;
		
	}
	;
	
data_statement
	: BYTE byte_list {
		
		$$ = new statement_data(*$2);
		delete $2;
		
		$$->stmnt_mode = STATEMENT_MODE::ST_DATA_BYTE;
		
	}
	| WORD word_list {
		
		$$ = new statement_data(*$2);
		delete $2;
		
		$$->stmnt_mode = STATEMENT_MODE::ST_DATA_WORD;
		
	}
	;
	
byte_list
	: expression COMMA byte_list {
		
		$$ = new std::vector<expression_data>(*$3);
		delete $3;
		
		expression_data temp(*$1);
		delete $1;
		
		$$->insert($$->begin(), temp);
		
	}
	| expression {
		
		$$ = new std::vector<expression_data>();
		
		expression_data temp(*$1);
		delete $1;
		
		$$->push_back(temp);
		
	}
	;
	
word_list
	: expression COMMA word_list {
		
		$$ = new std::vector<expression_data>(*$3);
		delete $3;
		
		$$->insert($$->begin(), {*$1});
		delete $1;		
		
	}
	| expression {
		
		$$ = new std::vector<expression_data>();
		
		$$->push_back({*$1});		
		delete $1;
		
	}
	;
	
/*
Ex:
LDA #[$10 + V1 * [V2 * V3 - V4 / V5] - V6 * $02]
$10, V1, V2, V3, *, V4, V5, /, -, *, +, V5, $02, *, -

[$10 + V1 * [V2 - V3 / V4] - V5 * $02]
[expression]
[expression + expression]
[addr + expression - expression]
[addr + expression * [expression] - expression]
[addr + expression * [expression * expression] - expression * expression]
[addr + addr * [expression * expression - expression / expression] - addr * addr]
[addr + addr * [addr - addr / addr] - addr * addr]
[a + b * [c * d - e / f] - g * h]

*/

/*

	Expressions are handled by building upward, starting with expressions inside brackets and single values
	Multiplicative expressions are then handled (*,/) left to right by appending the operator onto the end of the two expressions as they are
	Additive expressions (+,-) are handled similarly
	At the end, they should be in postfix notation already

*/
	
/* standard expression, the lowest priority expressions with an additive operation */
expression
	: expression AND s_expression {
		
		$$ = expression_data::binary_op(*$1, *$3, ARITHMETIC_OPERATOR::AR_AND);
		delete $1; delete $3;
		
	}
	| expression OR s_expression {
		
		$$ = expression_data::binary_op(*$1, *$3, ARITHMETIC_OPERATOR::AR_IOR);
		delete $1; delete $3;
		
	}
	| expression XOR s_expression {
		
		$$ = expression_data::binary_op(*$1, *$3, ARITHMETIC_OPERATOR::AR_XOR);
		delete $1; delete $3;
		
	}
	| s_expression
	;
	
s_expression
	: s_expression LSHIFT a_expression {
		
		$$ = expression_data::binary_op(*$1, *$3, ARITHMETIC_OPERATOR::AR_ASL);
		delete $1; delete $3;
		
	}
	| s_expression RSHIFT a_expression {
		
		$$ = expression_data::binary_op(*$1, *$3, ARITHMETIC_OPERATOR::AR_ASR);
		delete $1; delete $3;
			
	}
	| a_expression
	;
	
a_expression
	: a_expression PLUS m_expression {
		
		$$ = expression_data::binary_op(*$1, *$3, ARITHMETIC_OPERATOR::AR_ADD);
		delete $1; delete $3;
		
	}
	| a_expression MINUS m_expression {
		
		$$ = expression_data::binary_op(*$1, *$3, ARITHMETIC_OPERATOR::AR_SUB);
		delete $1; delete $3;
		
	}
	| m_expression
	;
	
/* [m]ultiplicative expression, expressions that use a multiplication operation or are a p-expression */
m_expression
	: m_expression TIMES p_expression {
		
		$$ = expression_data::binary_op(*$1, *$3, ARITHMETIC_OPERATOR::AR_MUL);
		delete $1; delete $3;
		
	}
	| m_expression DIVIDE p_expression {
		
		$$ = expression_data::binary_op(*$1, *$3, ARITHMETIC_OPERATOR::AR_DIV);		
		delete $1; delete $3;
		
	}
	| u_expression
	| p_expression
	;
	
u_expression
	: MINUS p_expression {
		
		$$ = new expression_data(*$2);
		delete $2;
		
		$$->op_vector.push_back(ARITHMETIC_OPERATOR::AR_NEG);
		
	}
	| NOT p_expression {
		
		$$ = new expression_data(*$2);
		delete $2;
		
		$$->op_vector.push_back(ARITHMETIC_OPERATOR::AR_NOT);
		
	}
	;
	
/* [p]arentheses expression, expressions that are either by themselves a whole value or are inside parentheses, making it a complete expression */
p_expression
	: LBRACKET expression RBRACKET {
		
		//std::cout << "Bracket expression\n";
		
		$$ = new expression_data(*$2);
		delete $2;
		
		//std::cout << "Exp: [" << *$$ << "]\n";
		
	}
	| address_value {
		
		//std::cout << "Single address value: " << *$1 << '\n';
		
		$$ = new expression_data(*$1);
		delete $1;
		
		//std::cout << "Address converted to p_expression: " << *$$ << '\n';
		
	}
	;

/* Address values can be either an address or an identifier (label) */
/* These are full size by default, but we will optimize addresses (not identifiers) to 1 byte when possible for instructions with zeropage modes */
address_value
	: ADDRESS {
		$$ = new address_data($1);
		//std::cout << "Address: " << *$$ << '\n';
	}
	| IDENTIFIER {
		
		$$ = new address_data(*$1);
		delete $1;
		
		//std::cout << "Label: " << *$$ << '\n';
		
	}
	;

%%

void yyerror(YYLTYPE *loc, char const *err) {
	std::cerr << "Error: " << err << " on line " << loc->first_line << std::endl;
	//This _error doesn't really work but seems useful regardless if I could work out its bugs
	_error = 1;
	//Immediately terminate if an error is received. Probably not a good way to handle this
	exit(1);
}