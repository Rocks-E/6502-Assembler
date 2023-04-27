/* Something */

%{
#include <iostream>
#include <string>
#include <cstdint>
#include <vector>
#include <map>
#include "parser.hpp"
#include "opcodes.hpp"

#define ROM_SIZE 0x10000

struct symbol_info {
	symbol_info() {
		this->address = 0;
		this->value_set = false;
	};
	void set_address(uint16_t addr) {
		this->address = addr;
		this->value_set = true;
	};
	uint16_t address;
	std::vector<uint16_t> loc;
	bool value_set;
};

//Store label
static std::map<std::string, symbol_info> constants;
static char _error = 0;
static uint16_t current_byte;

uint8_t rom_dump[ROM_SIZE];

void yyerror(YYLTYPE *loc, char const *err);

extern int yylex();

%}

%define api.pure full
%define api.push-pull push

%union {
	std::vector<uint8_t> *byte_vec;
	std::string *str;
	uint16_t u16;
	uint8_t u8;
}

%token IDENTIFIER FLOAT INTEGER TRUE FALSE
%token ASSIGN
%token LPAREN RPAREN COMMA COLON NEWLINE

%token u8 LPAREN RPAREN COMMA COLON NEWLINE EQUALS
%token u8 LITERAL
%token str IDENTIFIER
%token u16 ADDRESS

%type byte_vec byteList wordList addressList directiveStatement opStatement statement statementList
%type byte_vec directiveStatement 
%type u16 addressValue

%start program

%locations

%define parse.error verbose

%%

program
	/* Rolled up program */
	/* Fill every constant location with its determined value */
	: statementList {
		
	}
	;
	
statementList
	: statementList NEWLINE statement {
		$$ = new std::vector<uint8_t>(*$1);
		$$->insert($$->end(), $3->begin(), $3->end());
	}
	| statement
	;
	
statement
	/* Operation (instruction) statement */
	: opStatement {
		$$ = $1;
	}
	/* .byte, .word, or .org statement */
	| directiveStatement {
	
	}
	/* Set a constant, should only be done once per constant since this needs to apply to all instances of it */
	| IDENTIFIER EQUALS ADDRESS {
		if(constants.contains($1)) {
			if(constants[$1].value_set) {
				std::cerr << "Error: cannot set a constant value twice (" << $1 << ").\n";
				//throw error
			}
		}
		else {
			constants.insert({$1,{}});
		}
		constants[$1].set_address($3);
		
		// Empty vector
		$$ = new std::vector<uint8_t>;
		
	}
	/* Set a label, should only be done once per label since a label can only point to one address */
	| IDENTIFIER COLON {
		if(constants.contains($1)) {
			if(constants[$1].value_set) {
				std::cerr << "Error: cannot name a label twice (" << $1 << ").\n";
				//throw error
			}
		}
		else {
			constants.insert({$1, {}});
		}
		constants[$1].set_address(current_byte);
		
		// Empty vector
		$$ = new std::vector<uint8_t>;
		
	}
	;

opStatement
	/* OPC (ADDR, X) -> X-indexed, indirect -> mem[zpg[addr + x]] */
	/* 2 byte operation */
	: INSTRUCTION LPAREN addressValue COMMA_X RPAREN {
		
		$$ = new std::vector<uint8_t>(2);
		
		int16_t opcode = find_opcode($1, ADDR_MODE::INDIRECT_X);
		if(opcode < 0) {
			// Throw error
		}
		
		(*$$)[0] = opcode;
		(*$$)[1] = $3 & 0xFF;
		
	}
	/* OPC (ADDR), Y -> Indirect, Y-indexed -> mem[zpg[addr] + y + c] */
	/* 2 byte operation */
	| INSTRUCTION LPAREN addressValue RPAREN COMMA_Y {
		
		$$ = new std::vector<uint8_t>(2);
		
		int16_t opcode = find_opcode($1, ADDR_MODE::INDIRECT_Y);
		if(opcode < 0) {
			
		}
		
		(*$$)[0] = opcode;
		(*$$)[1] = $3 & 0xFF;
		
	}
	/* OPC (ADDR) -> Indirect -> mem[mem[addr]] */
	/* 3 byte operation - ONLY APPLICABLE TO JMP */
	| INSTRUCTION LPAREN addressValue RPAREN {
		
		$$ = new std::vector<uint8_t>(3);
		
		int16_t opcode = find_opcode($1, ADDR_MODE::INDIRECT);
		if(opcode < 0) {
			//Throw error
		}
		
		(*$$)[0] = opcode;
		(*$$)[1] = $3 & 0xFF;
		(*$$)[2] = $3 >> 8;

	}
	/* OPC ADDR, X -> Absolute, X-indexed OR zeropage, X-indexed -> mem[addr + x] OR zpg[addr + x] (effectively mem[addr + x] where addr < 0x100) */
	/* 2 bytes if zeropage, 3 bytes if absolute */
	| INSTRUCTION addressValue COMMA_X {
		
		$$ = new std::vector<uint8_t>(2);
		
		int16_t opcode;
		bool absolute_addr = false;
		
		// Check for absolute X-indexed if this is over 1 byte, otherwise use zeropage
		if($2 > 0xFF) {
			opcode = find_opcode($1, ADDR_MODE::ABSOLUTE_X);
			absolute_addr = true;
		}
		else
			opcode = find_opcode($1, ADDR_MODE::ZEROPAGE_X);

		// If no valid operation was found, throw an error (undecided)
		if(opcode < 0) {
			//Throw error
		}
		else {
			
			(*$$)[0] = opcode;
			(*$$)[1] = $3 & 0xFF;
			
			if(absolute_addr)
				$$->push_back($3 >> 8);
			
		}
	}
	/* OPC ADDR, Y -> Absolute, Y-indexed OR zeropage, Y-indexed -> mem[addr + y] OR zpg[addr + y] (effectively mem[addr + y] where addr < 0x100) */
	/* 2 bytes if zeropage, 3 bytes if absolute */
	| INSTRUCTION addressValue COMMA_Y {
		//Indirect
		int16_t temp;
		$$ = new std::vector<uint8_t>;
		temp = find_opcode($1, ADDR_MODE::INDIRECT_Y);
		if(temp < 0) {
			//Throw error
		}
		else {
			$$->push_back(temp);
			$$->push_back($2 & 0xFF);
			$$->push_back($2 >> 8);
		}
	}
	| INSTRUCTION addressValue {
		//Indirect
		int16_t temp;
		$$ = new std::vector<uint8_t>;
		//Branch instructions (relative)
		if($1[0] == 'B' || $1[0] == 'b') {
			
		}
		if($2 < 0x100) {
			temp = find_opcode($1, ADDR_MODE::ZEROPAGE);
			if(temp < 0) {
				temp = find_opcode($1, ADDR_MODE::ABSOLUTE);
			}
		}
		temp = find_opcode($1, ADDR_MODE::INDIRECT);
		if(temp < 0) {
			//Throw error
		}
		else {
			$$->push_back(temp);
			$$->push_back($2 & 0xFF);
			$$->push_back($2 >> 8);
		}
	}
	| INSTRUCTION ACCUMULATOR {
		//Accumulator (implied)
		int16_t temp;
		$$ = new std::vector<uint8_t>;
		temp = find_opcode($1, ADDR_MODE::IMPLIED);
		if(temp < 0) {
			//Throw error
		}
		else {
			$$->push_back(temp);
		}
	}
	| INSTRUCTION LITERAL {
		//Immediate
		int16_t temp;
		$$ = new std::vector<uint8_t>;
		temp = find_opcode($1, ADDR_MODE::IMMEDIATE);
		if(temp < 0) {
			//Throw error
		}
		else {
			$$->push_back(temp);
			$$->push_back($2);
		}
	}
	| INSTRUCTION {
		//Implied
		int16_t temp;
		$$ = new std::vector<uint8_t>;
		temp = find_opcode($1, ADDR_MODE::IMPLIED);
		if(temp < 0) {
			//Throw error
		}
		else {
			$$->push_back(temp);
		}
	}
	;
	
addressValue
	: ADDRESS {
		$$ = $1;
	}
	| IDENTIFIER {
		if(constants.contains($1)) {
			if(constants[$1].value_set) {
				$$ = $1;
			}
			else {
				constants[$1].loc.push_back(current_byte);
				$$ = 0;
			}
		}
		else {
			constants.insert({$1, {}};
			constants[$1].loc.push_back(current_byte);
			$$ = 0;
		}
	}
	;

directiveStatement
	: BYTE byteList {
		$$ = new std::vector<uint8_t>($2);
		delete $2;
	}
	| WORD wordList {
		$$ = new std::vector<uint8_t>($2);
		delete $2;
	}
	| ORG ADDRESS {
		current_byte = $2;
		//Empty vector
		$$ = new std::vector<uint8_t>;
	}
	;
	
byteList
	: byteList COMMA ADDRESS{
		$$ = new std::vector<uint8_t>($1);
		$$->insert($$->begin(), $3 & 0xFF);
		delete $1;
	}
	| ADDRESS {
		$$ = new std::vector<uint8_t>;
		$$->push_back($1 & 0xFF);
	}
	;
	
wordList
	: wordList COMMA ADDRESS{
		$$ = new std::vector<uint8_t>($1);
		$$->insert($$->begin(), $3 >> 8);
		$$->insert($$->begin(), $3 & 0xFF);
		delete $1;
	}
	| ADDRESS {
		$$ = new std::vector<uint8_t>;
		$$->push_back($1 & 0xFF);
		$$->push_back($1 >> 8);
	}
	;

program
	: statementList {
	
		if(_error == 0) {
		
			std::set<std::string>::iterator symbolIterator = symbols.begin();
			
			$$ = new std::string();
			
			//Wrap in main and include iostream for value checking
			*$$ += "#include <iostream>\n\nint main() {\n\/\/Begin: variable declaration\n";
			
			//Declare all variables
			for(symbolIterator = symbols.begin(); symbolIterator != symbols.end(); symbolIterator++) {
				*$$ += "\tdouble ";
				*$$ += (*symbolIterator);
				*$$ += ";\n";
				//*$$ += "\tdouble " + (*symbolIterator) + ";\n";
			}
			
			*$$ += "\/\/End: variable declaration\n\/\/Begin: program\n";
			
			//Write program
			*$$ += *$1;
			
			*$$ += "\/\/End: program\n\/\/Begin: variable printing\n";
			
			//Write variable checks
			for(symbolIterator = symbols.begin(); symbolIterator != symbols.end(); symbolIterator++) {
				*$$ += "\tstd::cout << \"";
				*$$ += (*symbolIterator);
				*$$ += ": \" << ";
				*$$ += (*symbolIterator);
				*$$ += " << \'\\n\';\n";
				//*$$ += "\tdouble " + (*symbolIterator) + ";\n";
			}
			
			*$$ += "\/\/End: variable printing\n\/\/Main end\n";
			
			//Standard return
			*$$ += "\treturn 0;\n}";
			
			delete $1;
			
			//Store in programOut extern variable to print if no errors
			//This took forever to get
			programOut = new std::string(*$$);
			
			//Tried just printing if no error was found, but error4.py and error5.py would throw errors and still print
			//std::cout << *$$ << std::endl;
			
		}

	}
	;

statementList
	: statementList statement {
		$$ = new std::string(*$1); 
		*$$ += *$2; 
		delete $1; delete $2;
	}
	| statement {
		$$ = new std::string(*$1); 
		delete $1; 
	}
	;
	
statement
	: ifStatement
	| whileStatement
	| assignStatement
	| BREAK NEWLINE {
		int c;
		$$ = new std::string();
		for(c = 0; c < @1.first_column; c++) {
			*$$ += '\t';
		}
		*$$ += "break;\n";
	}
	;
	
assignStatement
	: IDENTIFIER ASSIGN expression NEWLINE {
		int c;
		$$ = new std::string();
		
		symbols.insert(*$1);
		
		for(c = 0; c < @1.first_column; c++) {
			*$$ += '\t';
		}
		*$$ += *$1 + " = " + *$3 + ";\n"; 
		delete $1; delete $3;
	}
	| IDENTIFIER ASSIGN assignStatement {
		$$ = new std::string(*$1);
		*$$ += " = " + *$3;
		delete $1; delete $3;
	}
	;
	
ifStatement 
	: IF ifMain {
		int c;
		$$ = new std::string();
		for(c = 0; c < @1.first_column; c++) {
			*$$ += '\t';
		}
		*$$ += "if(" + *$2;
		delete $2;
	}
	;
	
elifStatement
	: ELIF ifMain {
		int c;
		$$ = new std::string();
		for(c = 0; c < @1.first_column; c++) {
			*$$ += '\t';
		}
		*$$ += "else if(" + *$2;
		delete $2;
	}
	;
	
ifMain
	: expression COLON NEWLINE blockStatement {
		$$ = new std::string(*$1);
		*$$ += ")" + *$4;
		delete $1; delete $4;
	}
	| expression COLON NEWLINE blockStatement elifStatement {
		$$ = new std::string(*$1);
		*$$ += ")" + *$4 + *$5;
		delete $1; delete $4; delete $5;
	}
	| expression COLON NEWLINE blockStatement ELSE COLON NEWLINE blockStatement {
		int c;
		$$ = new std::string(*$1);
		*$$ += ")" + *$4;
		for(c = 0; c < @1.first_column; c++) {
			*$$ += '\t';
		}
		*$$ += "else " + *$8;
		delete $1; delete $4; delete $8;
	}
	;
	
whileStatement
	: WHILE expression COLON NEWLINE blockStatement {
		int c;
		$$ = new std::string();
		for(c = 0; c < @1.first_column; c++) {
			*$$ += '\t';
		}
		*$$ += "while(" + *$2 + ")" + *$5;
		delete $2; delete $5;
	}
	;

blockStatement
	: INDENT statementList DEDENT {
		int c;
		$$ = new std::string("{\n");
		*$$ += *$2;
		for(c = 0; c < @1.first_column; c++) {
			*$$ += '\t';
		}
		*$$ += "}\n";
		delete $2;
	}
	;
	
expression
	: LPAREN expression RPAREN {
		$$ = new std::string("("); 
		*$$ += *$2 + std::string(")"); 
		delete $2;
	}
	| expression TIMES expression {
		$$ = new std::string(*$1);
		*$$ += std::string(" * ") + *$3;
		delete $1; delete $3;
		//*$$ = *$1 + " * " + *$3;
	}
	| expression DIVIDEBY expression {	
		$$ = new std::string(*$1);
		*$$ += std::string(" / ") + *$3;
		delete $1; delete $3;
		//*$$ = *$1 + " / " + *$3;
	}
	| expression PLUS expression {
		$$ = new std::string(*$1);
		*$$ += std::string(" + ") + *$3;
		delete $1; delete $3;
		//*$$ = *$1 + " + " + *$3;
	}
	| expression MINUS expression {
		$$ = new std::string(*$1);
		*$$ += std::string(" - ") + *$3;
		delete $1; delete $3;
		//*$$ = *$1 + " - " + *$3;
	}
	| expression EQ expression {
		$$ = new std::string(*$1);
		*$$ += std::string(" == ") + *$3;
		delete $1; delete $3;
		//*$$ = *$1 + " == " + *$3;
	}
	| expression NE expression {
		$$ = new std::string(*$1);
		*$$ += std::string(" != ") + *$3;
		delete $1; delete $3;
		//*$$ = *$1 + " != " + *$3;
	}
	| expression GT expression {
		$$ = new std::string(*$1);
		*$$ += std::string(" > ") + *$3;
		delete $1; delete $3;
		//*$$ = *$1 + " > " + *$3;
	}
	| expression GE expression {
		$$ = new std::string(*$1);
		*$$ += std::string(" >= ") + *$3;
		delete $1; delete $3;
		//*$$ = *$1 + " >= " + *$3;
	}
	| expression LT expression {
		$$ = new std::string(*$1);
		*$$ += std::string(" < ") + *$3;
		delete $1; delete $3;
		//*$$ = *$1 + " < " + *$3;
	}
	| expression LE expression {
		$$ = new std::string(*$1);
		*$$ += std::string(" <= ") + *$3;
		delete $1; delete $3;
		//*$$ = *$1 + " <= " + *$3;
	}
	| expression AND expression {
		$$ = new std::string(*$1);
		*$$ += " && " + *$3;
		delete $1; delete $3;
		//*$$ = *$1 + " && " + *$3;
	}
	| expression OR expression {
		$$ = new std::string(*$1);
		*$$ += std::string(" || ") + *$3;
		delete $1; delete $3;
		//*$$ = *$1 + " || " + *$3;
	}
	| NOT expression {
		$$ = new std::string("!"); 
		*$$ += *$2; 
		delete $2;
	}
	| value
	;
	
value
	: INTEGER {$$ = new std::string(*$1); delete $1;}
	| FLOAT {$$ = new std::string(*$1); delete $1;}
	| IDENTIFIER {
		//Throw an error if the variable wasn't given a value before use
		if(symbols.count(*$1) == 0) {
			std::cerr << "Use of uninitialized identifier: " << *$1 << " on line " << @1.first_line << ".\n";
			_error = 1;
			YYERROR;
		}
		else {
			$$ = new std::string(*$1);
		}
		delete $1;
	}
	| TRUE {$$ = new std::string("true");}
	| FALSE {$$ = new std::string("false");}
	;

%%

void yyerror(YYLTYPE *loc, char const *err) {
	std::cerr << "Error: " << err << " on line " << loc->first_line << std::endl;
	//This _error doesn't really work but seems useful regardless if I could work out its bugs
	_error = 1;
	//Immediately terminate if an error is received. Probably not a good way to handle this
	exit(1);
}