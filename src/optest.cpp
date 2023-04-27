#include "opcodes.hpp"

int32_t main() {
	return find_opcode("LDA", ADDR_MODE::IMMEDIATE);
}