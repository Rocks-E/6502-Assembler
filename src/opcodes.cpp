#include "opcodes.hpp"

instr_info::instr_info() {}
instr_info::instr_info(uint8_t count, uint8_t loc, uint16_t flags) : mode_count(count), base_location(loc), mode_flags(flags) {}

// Enter an instruction and the mode we want to use to see if the operation exists and if so what the opcode is
// Return value < 0 for error
int16_t find_opcode(std::string instr, ADDR_MODE mode) {
	
	instr_info info;
	
	try {
		// Check the map by the instruction pneumonic to get the instruction info
		// If it is not found, return -1
		info = instruction_map.at(instr);
	}
	catch(std::out_of_range oore) {
		std::cerr << "ERROR: No such instruction pneumonic found: " << instr << '\n';
		return -1;
	}
	
	// If the mode requested isn't present in the mode_flags of this instruction, the addressing mode is not applicable so -2 is returned
	if(!(info.mode_flags & (1 << mode))) {
		std::cerr << "ERROR: Addressing mode not applicable for this instruction " << instr << '\n';
		return -2;
	}
	
	// Start at whatever the opcode base is
	// In most cases, we will then apply an offset based on the pattern above (addr_offsets)
	uint8_t opcode = info.base_location;
	
	// We only need to even check this if there are multiple modes for the given instruction. Otherwise, it only has the base
	if(info.mode_count > 1) {
		
		// LoaD into X and LoaD into Y both use immediate for the base and their absolute Y uses what is usually the absolute X offset
		if(instr == "LDX" || instr == "LDY") {
			switch(mode) {
				case ADDR_MODE::IMMEDIATE:
					//Keep as base
					break;
				case ADDR_MODE::ABSOLUTE_Y:
					opcode += addr_offsets[ADDR_MODE::ABSOLUTE_X];
					break;
				default:
					opcode += addr_offsets[mode];
			}
		}
		// NO oPeration is a weird one that has many options, any of which we can use regularly with the offsets EXCEPT implied and immediate
		// Immediate we will just tie to 0x80, the first immediate NOP, and implied we can use the standard base since it is the regular NOP we will want to use
		else if(instr == "NOP") {
			switch(mode) {
				case ADDR_MODE::IMMEDIATE:
					opcode = 0x80;
					break;
				case ADDR_MODE::IMPLIED:
					//Keep as base
					break;
				default:
					opcode = addr_offsets[mode];
			}
		}
		// Load A + load X is an illegal operation, but like LDX and LDY it uses the regular absolute X offset for its absolute Y mode
		else if(instr == "LAX") {
			switch(mode) {
				case ADDR_MODE::ABSOLUTE_Y:
					opcode += addr_offsets[ADDR_MODE::ABSOLUTE_X];
					break;
				default:
					opcode += addr_offsets[mode];
			}
		}
		// Store High-byte of addr + 1 and A and x at addr, has indirect Y as its base and uses the absolute offset for its absolute Y
		// There are only two SHA instructions, so no default is needed
		else if(instr == "SHA") {
			switch(mode) {
				case ADDR_MODE::INDIRECT_Y:
					//keep base
					break;
				case ADDR_MODE::ABSOLUTE_Y:
					opcode += addr_offsets[ADDR_MODE::ABSOLUTE];
			}
		}
		// Both ComPare with X and ComPare with Y use immediate addressing at their base, but any other modes work the same as normal
		else if((instr == "CPX" || instr == "CPY") && mode == ADDR_MODE::IMMEDIATE) {
			// Keep base
		}
		// Just use the standard offsets
		else {
			opcode += addr_offsets[mode];
		}

	}
	
	return opcode;
	
}