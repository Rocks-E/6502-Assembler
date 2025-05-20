TEST_IN_DIR = Test_Input_Files
TEST_OUT_DIR = Test_Output_Files
PROG_NAME = rsr_asm
CC = g++
CFLAGS = -std=c++23

all: clean parse scan

debug: CFLAGS += -D_DEBUG -g -Wall -O0
debug: clear_terminal clean parse scan

test: debug
	./$(PROG_NAME) -i $(TEST_IN_DIR)/test_a_cr.asm -o $(TEST_OUT_DIR)/test_a_cr.bin -t $(TEST_OUT_DIR)/test_a_cr.tmp.asm -k -s
	./$(PROG_NAME) -i $(TEST_IN_DIR)/test_a_lf.asm -o $(TEST_OUT_DIR)/test_a_lf.bin -t $(TEST_OUT_DIR)/test_a_lf.tmp.asm -k -s
	./$(PROG_NAME) -i $(TEST_IN_DIR)/test_a_crlf.asm -o $(TEST_OUT_DIR)/test_a_crlf.bin -t $(TEST_OUT_DIR)/test_a_crlf.tmp.asm -k -s
	./$(PROG_NAME) -i $(TEST_IN_DIR)/test_b.asm -o $(TEST_OUT_DIR)/test_b.bin -t $(TEST_OUT_DIR)/test_b.tmp.asm -k -s
	./$(PROG_NAME) -i $(TEST_IN_DIR)/test_c.asm -o $(TEST_OUT_DIR)/test_c.bin -t $(TEST_OUT_DIR)/test_c.tmp.asm -k -s
	./$(PROG_NAME) -i $(TEST_IN_DIR)/test_d.asm -o $(TEST_OUT_DIR)/test_d.bin -t $(TEST_OUT_DIR)/test_d.tmp.asm -k -s
	./$(PROG_NAME) -i $(TEST_IN_DIR)/test_e.asm -o $(TEST_OUT_DIR)/test_e.bin -t $(TEST_OUT_DIR)/test_e.tmp.asm -k -s
	./$(PROG_NAME) -i $(TEST_IN_DIR)/test_f.asm -o $(TEST_OUT_DIR)/test_f.bin -t $(TEST_OUT_DIR)/test_f.tmp.asm -k -s
	./$(PROG_NAME) -i $(TEST_IN_DIR)/test_g.asm -o $(TEST_OUT_DIR)/test_g.bin -t $(TEST_OUT_DIR)/test_g.tmp.asm -k -s

scan: scanner.cpp
	$(CC) $(CFLAGS) scanner.cpp parser.cpp parser_structs.cpp opcodes.cpp preprocessor.cpp -o scan

scanner.cpp: scanner.l
	flex -o scanner.cpp scanner.l

parse: parser.cpp scanner.cpp
	$(CC) $(CFLAGS) parser.cpp scanner.cpp parser_structs.cpp opcodes.cpp preprocessor.cpp -o $(PROG_NAME)

parser.cpp parser.hpp: parser.y
	bison -v --report=all -d -o parser.cpp parser.y

clean:
	rm -f scan scanner.cpp parse parser.cpp parser.hpp
	
clear_terminal:
	clear
