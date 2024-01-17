Command-line-based 6502 Assembler

This is a pretty basic 6502 assembler written in C++ using Flex and Bison. Written for my own use for help testing as I build an NES emulator, and for practice writing translators.

Requirements:
  1) A device running Linux (if you're on Windows, just get WSL)
  2) The following packages (can be installed via apt on Ubuntu):
     1) g++
     2) bison
     3) flex
     4) make

To compile, download the src files and run "make".

The output command-line executable should be called "jsr_asm" - this can be modified in the Makefile. For help, run "./jsr_asm -h".

More updates to come, including actual error messages, more command-line arguments, and features such as multiple file input (maybe).
