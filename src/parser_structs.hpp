#ifndef PARSER_STRUCTS_HPP
#define PARSER_STRUCTS_HPP

#include <stack>
#include <vector>
#include <map>
#include <sstream>
#include <variant>
#include "opcodes.hpp"

#define GET_OPERAND(x) (std::get<address_data>((x).data))
#define GET_OPERATOR(x) (std::get<ARITHMETIC_OPERATOR>((x).data))
#define GET_ADDRESS(x) (std::get<uint16_t>((x).data))
#define GET_LABEL(x) (std::get<std::string>((x).data))

//std::map<std::string, uint16_t> constants;

/* from opcodes.hpp
enum ADDR_MODE : uint8_t {
	IMMEDIATE  = 0x0,
	ZEROPAGE   = 0x1,
	ZEROPAGE_X = 0x2,
	ZEROPAGE_Y = 0x3,
	ABSOLUTE   = 0x4,
	ABSOLUTE_X = 0x5,
	ABSOLUTE_Y = 0x6,
	INDIRECT   = 0x7,
	INDIRECT_X = 0x8,
	INDIRECT_Y = 0x9,
	RELATIVE   = 0xA,
	IMPLIED    = 0xB
};
*/

enum ARITHMETIC_OPERATOR : char {
	AR_MUL = '*',
	AR_DIV = '/',
	AR_ADD = '+',
	AR_SUB = '-',
	AR_AND = '&',
	AR_IOR = '|',
	AR_XOR = '^',
	AR_NOT = '~',
	AR_NEG = '!',
	AR_ASL = '<',
	AR_ASR = '>'
};

enum STATEMENT_MODE : uint8_t {
	ST_OPERATION,
	ST_DATA_WORD,
	ST_DATA_BYTE,
	ST_ORG,
	ST_LABEL
};

/*
struct symbol_info {
	
	symbol_info();
	symbol_info(uint16_t addr);
	
	void set_address(uint16_t addr);
	
	uint16_t address = 0;
	bool value_set = false;
	
}
*/

struct address_data {
	
	address_data();
	address_data(uint32_t addr_val);
	address_data(uint16_t addr_val, bool full);
	address_data(const std::string &label_name);
	address_data(const address_data &other);
	~address_data();
	
	std::string to_string() const;
	
	uint16_t get_data() const;
	bool is_full_size() const;
	
	address_data operator*(const address_data &other) const;
	address_data operator/(const address_data &other) const;
	address_data operator+(const address_data &other) const;
	address_data operator-(const address_data &other) const;
	address_data operator&(const address_data &other) const;
	address_data operator|(const address_data &other) const;
	address_data operator^(const address_data &other) const;
	address_data operator<<(const address_data &other) const;
	address_data operator>>(const address_data &other) const;
	address_data operator~() const;
	address_data operator-() const;
	
	bool is_address = true, full_size = true;
	std::variant<uint16_t, std::string> data;
	
	/*
	union {
		uint16_t address;
		std::string label;
	};
	*/
	
};

struct pf_stack_value {

	pf_stack_value(uint32_t val);
	pf_stack_value(const address_data &addr);
	pf_stack_value(ARITHMETIC_OPERATOR op);
	~pf_stack_value();
	
	std::string to_string() const;

	bool is_operand = true;

	std::variant<address_data, ARITHMETIC_OPERATOR> data;

	/*
	union {
		address_data operand;
		ARITHMETIC_OPERATOR operation;
	};
	*/
	
};

struct expression_data {
	
	expression_data();
	expression_data(uint32_t val);
	expression_data(const address_data &addr);
	expression_data(const expression_data &other_data);
	
	std::string to_string() const;
	
	void replace_labels();
	bool contains_label() const;
	uint16_t evaluate();
	
	static expression_data *binary_op(const expression_data &exp_a, const expression_data &exp_b, ARITHMETIC_OPERATOR op);
	
	std::vector<pf_stack_value> op_vector;
	bool full_size = true;
	
};
/*
std::vector<pf_stack_value> -> list of operations in postfix notation
Build a stack with operands, pop off two values for operation, operate, put back on stack
*/

struct statement_data {
	
	statement_data();
	
	statement_data(const std::string &name);
	statement_data(const std::string &name, ADDR_MODE op_type);
	
	statement_data(const std::vector<expression_data> &values);
	
	statement_data(const std::string &name, const std::vector<expression_data> &values, STATEMENT_MODE mode);
	statement_data(const std::string &name, const expression_data &data_val, ADDR_MODE op_type);
	
	std::string to_string() const;
	
	bool validate_operation(uint8_t *opcode_out);
	
	std::vector<uint8_t> to_binary(uint16_t current_byte = 0);
	size_t byte_count() const;
	void replace_labels();
	
	// Store the operation name so we can turn this into the appropriate opcode later
	std::string op_name;
	
	// Number of expressions -> number of operands (needed for data statements)
	// Each expression will be evaluated if:
	//	1) The expression ONLY contains values
	//	2) All symbols in the expression have been defined already
	// For absolute/zeropage instructions, we will attempt to use the zeropage instruction only if the expression contains only values
	// Thus, if an expression contains a label and is absolute/zeropage
	std::vector<expression_data> operand_expressions;
	
	// Default mode for translation
	STATEMENT_MODE stmnt_mode = STATEMENT_MODE::ST_OPERATION;
	ADDR_MODE op_mode = ADDR_MODE::IMMEDIATE;
	uint16_t location;
	
};

std::ostream &operator<<(std::ostream &os, const address_data &ad);
std::ostream &operator<<(std::ostream &os, const pf_stack_value &psv);
std::ostream &operator<<(std::ostream &os, const expression_data &ed);
std::ostream &operator<<(std::ostream &os, const statement_data &sd);

#endif