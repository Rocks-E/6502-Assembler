Command-line-based 6502 Assembler

This is a pretty basic 6502 assembler written in C++ using Flex and Bison. Written for my own use for help testing as I build an NES emulator, and for practice writing translators.

Requirements:
<ol>
	<li>
		A device running Linux (if you're on Windows, just get WSL)
	</li>
	<li>
		The following packages (can be installed via apt on Ubuntu):
		<ol>
			<li>
				g++
			</li>
			<li>
				bison
			</li>
			<li>
				flex
			</li>
			<li>
				make
			</li>
		</ol>
	</li>
</ol>

To compile, download the src files and run "make".

The output command-line executable should be called "rsr_asm" - this can be modified in the Makefile. For help, run "./rsr_asm -h".

Some details about the assembly files supported by this assembler:
<ul>
	<li>
		Supported mnemonics and addressing modes can be found here: https://www.masswerk.at/6502/6502_instruction_set.html
	</li>
	<li>
		Supports four bases:
		<ul>
			<li>
				Binary - Prefixed with '%' (e.g., %10010011 -> 147)
			</li>
			<li>
				Octal - Prefixed with '0' (e.g., 0577 -> 383)
			</li>
			<li>
				Decimal - Any number starting with 1-9, followed by standard decimal digits
			</li>
			<li>
				Hexadecimal	- Prefixed with '$' (e.g., $FF -> 255)
			</li>
		</ul>
	</li>
	<li>
		Converts strings to ASCII byte lists
		<ul>
			<li> 
				Three supported escape sequences, \0, \", and \\
			</li>
			<li>
				Any other specific bytes with no associated keyboard character can be entered by closing the string and adding a byte with that value
			</li>
			<li>
				Strings can be "concatenated" as if they were just byte lists by adding a comma and then another string, byte, label, constant, etc.
			</li>
		</ul>
  	</li>
	<li>
		Supports simple arithmetic expressions (+, -, *, /, &, |, ^, ~, -, <<, >>)
			<ul>
				<li>
					Unary operations (negation [-] and bitwise NOT [~]) are handled before binary operations
				</li>
				<li>
					Expressions can be surrounded by square brackets ([]) for precedence, otherwise pemdas is used for arithmetic binary expressions (* and /, then + and -)
				</li>
				<li>
					Bitwise binary operations are performed last in rough accordance to C++ operator precedence rules (<< and >>, then &, |, and ^)
				</li>
			</ul>
	</li>
	<li>
		Can use compound assignment statements to set multiple equal constants (e.g., _A = _B = _C = $5A)
		<ul>
			<li>
				NOTE: Assignments now support expressions! Defining constants in terms of other constants requires the other constants to be defined above, otherwise $FFFF will be inserted.
			</li>
		</ul>
	</li>
	<li>
		Use directives to set the index and declare data:
		<ul>
			<li>
				.ORG &lt;loc&gt; - Moves the program counter to the given location
			</li>
			<li>
				.BYTE &lt;byte_list&gt; - Declares a list of sequential bytes starting at the current program counter
			</li>
			<li>
				.WORD &lt;word_list&gt; - Declares a list of sequential words (2 byte values, little endian) starting at the current program counter 
			</li>
		</ul>
	</li>
</ul>
	

More updates to come, including actual error messages, more command-line arguments, and features such as multiple file input (maybe).
