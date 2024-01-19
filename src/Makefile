CC = g++
CFLAGS = -std=c++23

all: clean parse scan

debug: CFLAGS += -D_DEBUG -g -Wall -O0
debug: clear_terminal clean parse scan

scan: scanner.cpp
	$(CC) $(CFLAGS) scanner.cpp parser.cpp parser_structs.cpp opcodes.cpp preprocessor.cpp -o scan

scanner.cpp: scanner.l
	flex -o scanner.cpp scanner.l

parse: parser.cpp scanner.cpp
	$(CC) $(CFLAGS) parser.cpp scanner.cpp parser_structs.cpp opcodes.cpp preprocessor.cpp -o jsr_asm

parser.cpp parser.hpp: parser.y
	bison -v --report=all -d -o parser.cpp parser.y

clean:
	rm -f scan scanner.cpp parse parser.cpp parser.hpp
	
clear_terminal:
	clear
