all: clean parse scan

scan: scanner.cpp
	g++ -g -std=c++23 scanner.cpp parser.cpp parser_structs.cpp opcodes.cpp preprocessor.cpp -o scan

scanner.cpp: scanner.l
	flex -o scanner.cpp scanner.l

parse: parser.cpp scanner.cpp
	g++ -g -std=c++23 parser.cpp scanner.cpp parser_structs.cpp opcodes.cpp preprocessor.cpp -o jsr_asm

parser.cpp parser.hpp: parser.y
	bison -v --report=all -d -o parser.cpp parser.y

clean:
	rm -f scan scanner.cpp parse parser.cpp parser.hpp
