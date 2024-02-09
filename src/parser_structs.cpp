#include "parser_structs.hpp"

std::map<std::string, uint16_t> constants;

/** struct symbol_info **/

/*
symbol_info::symbol_info() {}
symbol_info::symbol_info(uint16_t addr) : address(addr), value_set(true) {}

void symbol_info::set_address(uint16_t addr) {

	this->address = addr;
	this->value_set = true;

}
*/

/** struct address_data **/
	
address_data::address_data() : full_size(false), data((uint16_t)0) {}
	
address_data::address_data(uint32_t addr_val) : data((uint16_t)addr_val) {
	if(!(addr_val & 0x10000))
		this->full_size = false;
}
address_data::address_data(uint16_t addr_val, bool full) : full_size(full), data(addr_val) {}
address_data::address_data(const std::string &label_name) : is_address(false), data(label_name) {}
address_data::address_data(const address_data &other) : is_address(other.is_address), full_size(other.full_size), data(other.data) {}

address_data::~address_data() {}

std::string address_data::to_string() const {
	
	if(!this->is_address)
		return GET_LABEL(*this);
	
	std::stringstream result_stream;
	result_stream << GET_ADDRESS(*this);
	
	return result_stream.str();
	
}

uint16_t address_data::get_data() const {
	return this->is_address ? GET_ADDRESS(*this) : constants[GET_LABEL(*this)];
}

bool address_data::is_full_size() const {
	return this->is_address ? GET_ADDRESS(*this) > 0xFF : this->full_size;
}

address_data address_data::operator*(const address_data &other) const {
	
	if(!this->is_address || !other.is_address)
		throw new std::domain_error("ERROR: Cannot perform arithmetic on labels.");
	
	return address_data(GET_ADDRESS(*this) * GET_ADDRESS(other), this->full_size || other.full_size);
	
}
address_data address_data::operator/(const address_data &other) const{
	
	if(!this->is_address || !other.is_address)
		throw new std::domain_error("ERROR: Cannot perform arithmetic on labels.");
	
	return address_data(GET_ADDRESS(*this) / GET_ADDRESS(other), this->full_size || other.full_size);
	
}
address_data address_data::operator+(const address_data &other) const{
	
	if(!this->is_address || !other.is_address)
		throw new std::domain_error("ERROR: Cannot perform arithmetic on labels.");
	
	return address_data(GET_ADDRESS(*this) + GET_ADDRESS(other), this->full_size || other.full_size);
	
}
address_data address_data::operator-(const address_data &other) const{
	
	if(!this->is_address || !other.is_address)
		throw new std::domain_error("ERROR: Cannot perform arithmetic on labels.");
	
	return address_data(GET_ADDRESS(*this) - GET_ADDRESS(other), this->full_size || other.full_size);
	
}
address_data address_data::operator&(const address_data &other) const{
	
	if(!this->is_address || !other.is_address)
		throw new std::domain_error("ERROR: Cannot perform arithmetic on labels.");
	
	return address_data(GET_ADDRESS(*this) & GET_ADDRESS(other), this->full_size || other.full_size);
	
}
address_data address_data::operator|(const address_data &other) const{
	
	if(!this->is_address || !other.is_address)
		throw new std::domain_error("ERROR: Cannot perform arithmetic on labels.");
	
	return address_data(GET_ADDRESS(*this) | GET_ADDRESS(other), this->full_size || other.full_size);
	
}
address_data address_data::operator^(const address_data &other) const{
	
	if(!this->is_address || !other.is_address)
		throw new std::domain_error("ERROR: Cannot perform arithmetic on labels.");
	
	return address_data(GET_ADDRESS(*this) ^ GET_ADDRESS(other), this->full_size || other.full_size);
	
}
address_data address_data::operator<<(const address_data &other) const{
	
	if(!this->is_address || !other.is_address)
		throw new std::domain_error("ERROR: Cannot perform arithmetic on labels.");
	
	return address_data(GET_ADDRESS(*this) << GET_ADDRESS(other), this->full_size || other.full_size);
	
}
address_data address_data::operator>>(const address_data &other) const{
	
	if(!this->is_address || !other.is_address)
		throw new std::domain_error("ERROR: Cannot perform arithmetic on labels.");
	
	return address_data(GET_ADDRESS(*this) >> GET_ADDRESS(other), this->full_size || other.full_size);
	
}
address_data address_data::operator~() const{
	
	if(!this->is_address)
		throw new std::domain_error("ERROR: Cannot perform arithmetic on labels.");
	
	uint16_t data;
	
	if(this->full_size)
		data = ~GET_ADDRESS(*this);
	else
		data = (uint8_t)(~GET_ADDRESS(*this));
	
	return address_data(data, this->full_size);
	
}
address_data address_data::operator-() const{
	
	if(!this->is_address)
		throw new std::domain_error("ERROR: Cannot perform arithmetic on labels.");
	
	uint16_t data;
	
	if(this->full_size)
		data = -GET_ADDRESS(*this);
	else
		data = (uint8_t)(-GET_ADDRESS(*this));
	
	return address_data(data, this->full_size);
	
}

std::ostream &operator<<(std::ostream &os, const address_data &ad) {
	
	os << ad.to_string();
	return os;
	
}

/** struct pf_stack_value **/

pf_stack_value::pf_stack_value(uint32_t val) : data(val) {}
pf_stack_value::pf_stack_value(const address_data &addr) : data(addr) {}
pf_stack_value::pf_stack_value(ARITHMETIC_OPERATOR op) : data(op) {
	this->is_operand = false;
}

pf_stack_value::~pf_stack_value() {}

std::string pf_stack_value::to_string() const {
	
	if(this->is_operand)
		return GET_OPERAND(*this).to_string();
	
	std::stringstream result_stream;
	
	result_stream << static_cast<char>(GET_OPERATOR(*this));
	
	return result_stream.str();
	
}

std::ostream &operator<<(std::ostream &os, const pf_stack_value &psv) {
	
	os << psv.to_string();
	return os;
	
}

/** struct expression_data **/
	
expression_data::expression_data() {}
expression_data::expression_data(uint32_t val) {
	this->op_vector.push_back(val);
}
expression_data::expression_data(const address_data &addr) {
	this->op_vector.push_back(addr);
}
//expression_data::expression_data(std::vector<address_data> *addr_list) : op_vector(*addr_list) {}
expression_data::expression_data(const expression_data &other_data) : op_vector(other_data.op_vector) {}

std::string expression_data::to_string() const {
	
	if(this->op_vector.size() == 0)
		return std::string("");
	
	std::stringstream result_stream;
	
	result_stream << this->op_vector[0].to_string();
	
	for(size_t c = 1; c < this->op_vector.size(); c++)
		result_stream << ", " << this->op_vector[c].to_string();
	
	return result_stream.str();
	
}

// Replace should ONLY be called once all labels are defined
void expression_data::replace_labels() {
	
	// Check if each expression value is an operand and has a label, replace with the constant value if it is
	for(pf_stack_value &exp_value : this->op_vector)
		if(exp_value.is_operand && !GET_OPERAND(exp_value).is_address)
			exp_value.data = constants.contains(GET_LABEL(GET_OPERAND(exp_value))) ? address_data(constants[GET_LABEL(GET_OPERAND(exp_value))]) : address_data(0xFFFF);
	
}

// Return true if any part of this expression is a label
bool expression_data::contains_label() const {
	
	for(const pf_stack_value &exp_value : this->op_vector)
		if(exp_value.is_operand && !GET_OPERAND(exp_value).is_address)
				return true;

	return false;
	
}

// Evaluate should ONLY be called if we know that this has no labels
uint16_t expression_data::evaluate() {
	
	// Check if this has already been evaluated, return the value if so
	if(this->op_vector.size() == 1)
		return GET_ADDRESS(GET_OPERAND(this->op_vector[0]));

	// Create a stack to store values on
	std::stack<address_data> addr_stack;
	
	// Loop through the expression operation/operand vector
	for(const pf_stack_value &stack_val : this->op_vector) {
		
		address_data working_vals[3];
		
		// If this is an operand, push it onto the stack
		if(stack_val.is_operand)
			addr_stack.push(GET_OPERAND(stack_val));
		// Otherwise, perform the operation
		else {
			
			ARITHMETIC_OPERATOR next_op = GET_OPERATOR(stack_val);
			
			uint8_t operand_count;
			switch(next_op) {
				
				case ARITHMETIC_OPERATOR::AR_MUL:
				case ARITHMETIC_OPERATOR::AR_DIV:
				case ARITHMETIC_OPERATOR::AR_ADD:
				case ARITHMETIC_OPERATOR::AR_SUB:
				case ARITHMETIC_OPERATOR::AR_AND:
				case ARITHMETIC_OPERATOR::AR_IOR:
				case ARITHMETIC_OPERATOR::AR_XOR:
				case ARITHMETIC_OPERATOR::AR_ASL:
				case ARITHMETIC_OPERATOR::AR_ASR:
					operand_count = 2;
					break;
					
				case ARITHMETIC_OPERATOR::AR_NOT:
				case ARITHMETIC_OPERATOR::AR_NEG:
					operand_count = 1;
					break;
				
			}
			
			bool full_size = false;
			
			// Pop the requisite number of operands off the top of the stack
			for(size_t c = operand_count; c > 0; c--) {
				
				working_vals[c] = addr_stack.top();
				addr_stack.pop();
				
				// Set to full size if any operands are full size
				if(working_vals[c].full_size)
					full_size = true;
				
			}
			
			working_vals[0].full_size = full_size;

			// Perform the operation
			switch(next_op) {
				
				case ARITHMETIC_OPERATOR::AR_MUL:
					working_vals[0] = working_vals[1] * working_vals[2];
					break;                                                                                                                         

				case ARITHMETIC_OPERATOR::AR_DIV:                                                                                                  
					working_vals[0] = working_vals[1] / working_vals[2];
					break;                                                                                                                         

				case ARITHMETIC_OPERATOR::AR_ADD:                                                                                                  
					working_vals[0] = working_vals[1] + working_vals[2];
					break;                                                                                                                         

				case ARITHMETIC_OPERATOR::AR_SUB:                                                                                                  
					working_vals[0] = working_vals[1] - working_vals[2];
					break;                                                                                                                         

				case ARITHMETIC_OPERATOR::AR_AND:                                                                                                  
					working_vals[0] = working_vals[1] & working_vals[2];
					break;                                                                                                                         

				case ARITHMETIC_OPERATOR::AR_IOR:                                                                                                  
					working_vals[0] = working_vals[1] | working_vals[2];
					break;                                                                                                                         

				case ARITHMETIC_OPERATOR::AR_XOR:                                                                                                  
					working_vals[0] = working_vals[1] ^ working_vals[2];
					break;
					
				case ARITHMETIC_OPERATOR::AR_ASL:
					working_vals[0] = working_vals[1] << working_vals[2];
					break;
					
				case ARITHMETIC_OPERATOR::AR_ASR:
					working_vals[0] = working_vals[1] >> working_vals[2];
					break;
					
				case ARITHMETIC_OPERATOR::AR_NOT:
					working_vals[0] = ~working_vals[1];
					break;
				
				case ARITHMETIC_OPERATOR::AR_NEG:
					working_vals[0] = -working_vals[1];
					break;
				
			}
			
			// Push the value back onto the stack
			addr_stack.push(working_vals[0]);
			
		}
		
	}
	
	// Replace the 
	this->op_vector.clear();
	this->op_vector.push_back(addr_stack.top());
	
	// At the end, only one value should be on the stack as the result of all operations
	return GET_ADDRESS(addr_stack.top());
	
}

// Apply a binary arithmetic operation to two expressions
expression_data *expression_data::binary_op(const expression_data &exp_a, const expression_data &exp_b, ARITHMETIC_OPERATOR op) {
	
	// Create a new expression, appending the second to the first
	expression_data *result_data = new expression_data(exp_a);
	result_data->op_vector.insert(result_data->op_vector.end(), exp_b.op_vector.cbegin(), exp_b.op_vector.cend());
	
	// Add the operation at the end of the expression
	result_data->op_vector.push_back(op);
	
	return result_data;
	
}

std::ostream &operator<<(std::ostream &os, const expression_data &ed) {
	
	os << ed.to_string();
	return os;
	
}

/** struct statement_data **/
	
statement_data::statement_data() {};

statement_data::statement_data(const std::string &name) : op_name(name) {}
statement_data::statement_data(const std::string &name, ADDR_MODE op_type) : op_name(name), op_mode(op_type) {}
statement_data::statement_data(const std::vector<expression_data> &values) : operand_expressions(values) {}
statement_data::statement_data(const std::string &name, const std::vector<expression_data> &values, STATEMENT_MODE mode) : op_name(name), operand_expressions(values), stmnt_mode(mode) {}
statement_data::statement_data(const std::string &name, const expression_data &data_val, ADDR_MODE op_type) : op_name(name), operand_expressions(1, data_val), stmnt_mode(STATEMENT_MODE::ST_OPERATION), op_mode(op_type) {}

std::string statement_data::to_string() const {
	
	std::stringstream result_stream;
	
	result_stream << "Statement location: " << this->location << "\nStatement type: ";
	
	switch(this->stmnt_mode) {
		
		case STATEMENT_MODE::ST_OPERATION:
		
			result_stream << "Instruction\nInstruction: [" << this->op_name << "]\nAddressing mode: ";
			
			switch(this->op_mode) {
				
				case ADDR_MODE::IMMEDIATE:
					result_stream << "IMMEDIATE";
					break;

				case ADDR_MODE::ZEROPAGE:
					result_stream << "ZEROPAGE";
					break;

				case ADDR_MODE::ZEROPAGE_X:
					result_stream << "ZEROPAGE_X";
					break;

				case ADDR_MODE::ZEROPAGE_Y:
					result_stream << "ZEROPAGE_Y";
					break;

				case ADDR_MODE::ABSOLUTE:
					result_stream << "ABSOLUTE";
					break;

				case ADDR_MODE::ABSOLUTE_X:
					result_stream << "ABSOLUTE_X";
					break;

				case ADDR_MODE::ABSOLUTE_Y:
					result_stream << "ABSOLUTE_Y";
					break;

				case ADDR_MODE::INDIRECT:
					result_stream << "INDIRECT";
					break;

				case ADDR_MODE::INDIRECT_X:
					result_stream << "INDIRECT_X";
					break;

				case ADDR_MODE::INDIRECT_Y:
					result_stream << "INDIRECT_Y";
					break;

				case ADDR_MODE::RELATIVE:
					result_stream << "RELATIVE";
					break;

				case ADDR_MODE::IMPLIED:
					result_stream << "IMPLIED";
					break;
				
			}
			
			result_stream << "\nOperands: ";
			
			if(this->op_mode == ADDR_MODE::IMPLIED)
				result_stream << "None";
			else
				for(size_t c = 0; c < this->operand_expressions.size(); c++)
					result_stream << "\n\t" << this->operand_expressions[c].to_string();
			
			break;
			
		case STATEMENT_MODE::ST_LABEL:
			result_stream << "Label\nLabel: " << this->op_name;
			break;
			
		case STATEMENT_MODE::ST_ORG:
			result_stream << "ORG\nTarget: " << this->operand_expressions[0].to_string();
			break;
			
		case STATEMENT_MODE::ST_DATA_WORD:
			result_stream << "WORD\nWords: ";
			for(size_t c = 0; c < this->operand_expressions.size(); c++)
				result_stream << "\n\t" << this->operand_expressions[c].to_string();
			break;
			
		case STATEMENT_MODE::ST_DATA_BYTE:
			result_stream << "BYTE\nBytes: ";
			for(size_t c = 0; c < this->operand_expressions.size(); c++)
				result_stream << "\n\t" << this->operand_expressions[c].to_string();
			break;
		
	}
	
	return result_stream.str();
	
}

void statement_data::replace_labels() {
	for(expression_data &exp_val : this->operand_expressions)
		exp_val.replace_labels();
}

bool statement_data::validate_operation(uint8_t *opcode_out) {
	
	int16_t opcode_check = find_opcode(this->op_name, this->op_mode);
	
	// Check if the opcode exists
	if(opcode_check < 0) {
		
		int8_t op_change;
		
		switch(this->op_mode) {
			
			case ADDR_MODE::ZEROPAGE:
			case ADDR_MODE::ZEROPAGE_X:
			case ADDR_MODE::ZEROPAGE_Y:
				op_change = 3;
				break;
			
			case ADDR_MODE::ABSOLUTE:
			case ADDR_MODE::ABSOLUTE_X:
			case ADDR_MODE::ABSOLUTE_Y:
				op_change = -3;
				break;
				
			// Any other addressing mode cannot meaningfully be swapped
			default:
				return false;
			
		}
		
		// Add or subtract 3 from the address mode (converts to/from zpg and abs) for an additional test
		ADDR_MODE test_mode = static_cast<ADDR_MODE>((uint8_t)this->op_mode + op_change);
		
		// If the opcode still does not exist, return failure
		if((opcode_check = find_opcode(this->op_name, test_mode)) < 0)
			return false;
		
		// If the opcode does exist, change the addressing mode
		this->op_mode = test_mode;
		
	}
	
	if(opcode_out != nullptr)
		*opcode_out = opcode_check;
	
	// If the opcode exists, return success
	return true;
	
}

std::vector<uint8_t> statement_data::to_binary(uint16_t current_byte) {
	
	std::vector<uint8_t> result_vec(this->byte_count());
	
	this->replace_labels();
	
	switch(this->stmnt_mode) {
		
		case STATEMENT_MODE::ST_DATA_WORD:
			
			for(size_t c = 0; c < this->operand_expressions.size(); c++) {
				
				uint16_t temp_val = this->operand_expressions[c].evaluate();
				
				result_vec[2 * c] = temp_val & 0xFF;
				result_vec[2 * c + 1] = temp_val >> 8;
				
			}
			
			break;
		
		case STATEMENT_MODE::ST_DATA_BYTE:	
			for(size_t c = 0; c < this->operand_expressions.size(); c++)
				result_vec[c] = this->operand_expressions[c].evaluate() & 0xFF;
			break;
		
		case STATEMENT_MODE::ST_OPERATION:
		
			uint8_t instr_opcode;
			if(!this->validate_operation(&instr_opcode)) {
				std::cerr << "ERROR: Addressing mode is not applicable to this instruction. [" << (uint16_t)this->stmnt_mode << "]\n";
				throw new std::logic_error("ERROR: Addressing mode is not applicable to this instruction.");
			}
			
			// Set the instruction code byte
			result_vec[0] = instr_opcode;
		
			switch(this->op_mode) {
				
				// 3 byte instructions, low byte goes first
				case ADDR_MODE::ABSOLUTE:
				case ADDR_MODE::ABSOLUTE_X:
				case ADDR_MODE::ABSOLUTE_Y:
				case ADDR_MODE::INDIRECT:
				{
					uint16_t exp_result = this->operand_expressions[0].evaluate();
					result_vec[1] = exp_result & 0xFF;
					result_vec[2] = exp_result >> 8;
					break;
				}
				
				// Determine the offset needed to reach the correct location (can only be in the range [-128, +127]), 2 byte instructions
				case ADDR_MODE::RELATIVE:
				{
					// This is gonna be pretty complicated probably fuck
					// Need to calculate the offset necessary to get to the desired location
					// Get the current byte, take the difference between it and the target byte, 
					uint16_t intended_address = this->operand_expressions[0].evaluate();
					int32_t address_offset = intended_address - (current_byte + 2);
					if(address_offset < -128 || address_offset > 127) {
						std::cerr << "ERROR: Target address [" << intended_address << "] is out of range ([" << address_offset << "] not in range [-128, 127].\n";
						throw new std::logic_error("ERROR: Target address is out of range.");
					}
					
					result_vec[1] = (int8_t)address_offset;
					
					break;
				}
				
				// Do nothing if this is implied, these are 1 byte instructions
				case ADDR_MODE::IMPLIED:
					break;
					
				
				// 2 byte instructions
				case ADDR_MODE::IMMEDIATE:
				case ADDR_MODE::ZEROPAGE:
				case ADDR_MODE::ZEROPAGE_X:
				case ADDR_MODE::ZEROPAGE_Y:
				case ADDR_MODE::INDIRECT_X:
				case ADDR_MODE::INDIRECT_Y:
					result_vec[1] = this->operand_expressions[0].evaluate() & 0xFF;
					break;
				
			}
		
			break;
		
		//default:
		case STATEMENT_MODE::ST_ORG:
		case STATEMENT_MODE::ST_LABEL:
			break;
		
	}
	
	return result_vec;
	
}

size_t statement_data::byte_count() const {
	
	// If data, this should be >0
	// If an operation, this should be 1 or 0
	// Ignore for org/label
	size_t num_bytes = this->operand_expressions.size();
	
	switch(this->stmnt_mode) {
		
		case STATEMENT_MODE::ST_ORG:
		case STATEMENT_MODE::ST_LABEL:
			return 0;
			
		// If these are words, each expression will result in 2 bytes
		case STATEMENT_MODE::ST_DATA_WORD:
			num_bytes <<= 1;
			break;
		
		case STATEMENT_MODE::ST_OPERATION:
		
			// Increment by 1 for the instruction
			num_bytes++;
			
			// For indirect addressing or any type of absolute addressing, add a byte
			if((uint8_t)((uint8_t)this->op_mode - 4) < 4)
				num_bytes++;

			break;
			
		//default:
		case STATEMENT_MODE::ST_DATA_BYTE:
			break;
		
	}
	
	return num_bytes;
	
}

std::ostream &operator<<(std::ostream &os, const statement_data &sd) {
	
	os << sd.to_string();
	return os;
	
}