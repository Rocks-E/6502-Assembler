#include <iostream>
#include <map>
#include <stdexcept>
#include <cstdint>

struct instr_info {
	instr_info() {
		//this->mode_count = 0; this->base_location = 0; this->mode_flags = 0;
	}
	instr_info(uint8_t count, uint8_t loc, uint16_t flags) : mode_count(count), base_location(loc), mode_flags(flags) {
		//this->mode_count = count; this->base_location = loc; this->mode_flags = flags;
	}
	uint8_t mode_count = 0, base_location = 0;
	uint16_t mode_flags = 0;
};

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

//Ordered by ADDR_MODE
static uint8_t addr_offsets[] = {
	/*IMMEDIATE*/	0x08, 
	/*ZEROPAGE*/	0x04, 
	/*ZEROPAGE_X*/	0x14, 
	/*ZEROPAGE_Y*/	0x14, 
	/*ABSOLUTE*/	0x0C,
	/*ABSOLUTE_X*/	0x1C, 
	/*ABSOLUTE_Y*/	0x18, 
	/*INDIRECT*/	0x2C, 
	/*INDIRECT_X*/	0x00, 
	/*INDIRECT_Y*/	0x10, 
	/*RELATIVE*/	0x00, 
	/*IMPLIED*/		0x08
};

// {{Op pneumonic}, {modes, base, flags}}
// I hate this USBC command. I know it's illegal, I don't have to implement it, but it may be needed eventually because some developer had a use for it, somehow. Thus, the below map has some added whitespace to account for it
static std::map<std::string, instr_info> instruction_map = {
		{{"ADC"},{8,0x61,0x377}},{{"ALR"},{1,0x4B,0x001}},{{"ANC"},{1,0x0B,0x001}},{{"AND"},{8,0x21,0x377}}, {{"ANE"},{1,0x8B,0x001}},{{"ARR"},{1,0x6B,0x001}},{{"ASL"},{5,0x02,0x836}},{{"BCC"},{1,0x90,0x400}},
		{{"BCS"},{1,0xB0,0x400}},{{"BEQ"},{1,0xF0,0x400}},{{"BIT"},{2,0x20,0x012}},{{"BMI"},{1,0x30,0x400}}, {{"BNE"},{1,0xD0,0x400}},{{"BPL"},{1,0x10,0x400}},{{"BRK"},{1,0x00,0x800}},{{"BVC"},{1,0x50,0x400}},
		{{"BVS"},{1,0x70,0x400}},{{"CLC"},{1,0x18,0x800}},{{"CLD"},{1,0xD8,0x800}},{{"CLI"},{1,0x58,0x800}}, {{"CLV"},{1,0xB8,0x800}},{{"CMP"},{8,0xC1,0x377}},{{"CPX"},{3,0xE0,0x013}},{{"CPY"},{3,0xC0,0x013}},
		{{"DCP"},{7,0xC3,0x376}},{{"DEC"},{4,0xC2,0x036}},{{"DEX"},{1,0xCA,0x800}},{{"DEY"},{1,0x88,0x800}}, {{"EOR"},{8,0x41,0x377}},{{"INC"},{4,0xE2,0x036}},{{"INX"},{1,0xE8,0x800}},{{"INY"},{1,0xC8,0x800}},
		{{"ISC"},{7,0xE3,0x376}},{{"JAM"},{1,0x02,0x800}},{{"JMP"},{2,0x40,0x090}},{{"JSR"},{1,0x20,0x010}}, {{"LAS"},{1,0xBB,0x040}},{{"LAX"},{6,0xA3,0x35A}},{{"LDA"},{8,0xA1,0x377}},{{"LDX"},{5,0xA2,0x05B}},
		{{"LDY"},{5,0xA0,0x037}},{{"LSR"},{5,0x42,0x836}},{{"LXA"},{1,0xAB,0x001}},{{"NOP"},{6,0xEA,0x837}}, {{"ORA"},{8,0x01,0x377}},{{"PHA"},{1,0x68,0x800}},{{"PHP"},{1,0x08,0x800}},{{"PLA"},{1,0x68,0x800}},
		{{"PLP"},{1,0x28,0x800}},{{"RLA"},{7,0x23,0x376}},{{"ROL"},{5,0x22,0x836}},{{"ROR"},{5,0x62,0x836}}, {{"RRA"},{7,0x63,0x376}},{{"RTI"},{1,0x40,0x800}},{{"RTS"},{1,0x60,0x800}},{{"SAX"},{4,0x83,0x11A}},
		{{"SBC"},{8,0xE1,0x377}},{{"SBX"},{1,0xCB,0x001}},{{"SEC"},{1,0x38,0x800}},{{"SED"},{1,0xF8,0x800}}, {{"SEI"},{1,0x78,0x800}},{{"SHA"},{2,0x93,0x240}},{{"SHX"},{1,0x9E,0x040}},{{"SHY"},{1,0x9C,0x020}},
		{{"SLO"},{7,0x03,0x376}},{{"SRE"},{7,0x43,0x376}},{{"STA"},{7,0x81,0x376}},{{"STX"},{3,0x82,0x016}}, {{"STY"},{3,0x80,0x016}},{{"TAS"},{1,0x9B,0x040}},{{"TAX"},{1,0xAA,0x800}},{{"TAY"},{1,0xA8,0x800}},
		{{"TSX"},{1,0xBA,0x800}},{{"TXA"},{1,0x8A,0x800}},{{"TXS"},{1,0x9A,0x800}},{{"TYA"},{1,0x98,0x800}},{{"USBC"},{1,0xEB,0x001}}
};

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
	
};