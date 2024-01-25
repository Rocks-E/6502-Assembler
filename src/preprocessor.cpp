#include "preprocessor.hpp"

//std::map<std::string, std::string> symbols_table;

void to_upper(std::string &str) {
	
	for(size_t c = 0; c < str.length(); c++)
		if((str[c] > 0x60) && (str[c] < 0x7B))
			str[c] -= 0x20;
	
}

// Shitty hack so we don't have to deal with 0's
void fix_zeros(std::string &str) {
	
	std::regex zero_regex("([\\(\\[\\+\\-\\*\\/ ,#])(0+)(?:(?![1-9A-F]))");
	str = std::regex_replace(str, zero_regex, "$1$$00");
	
}

void convert_radix(std::string &str, uint8_t dest_radix, uint8_t src_radix) {
	
	// Do nothing if the bases match
	if(src_radix == dest_radix)
		return;
	
	std::regex src_radix_regex;
	
	// Determine the regex needed to find numbers of the specified base
	switch(src_radix) {
		
		case 0b10:
			src_radix_regex = "%[01]+";
			break;
		
		case 010:
			src_radix_regex = "([\\(\\[\\+\\-\\*\\/ ,#])0[0-7]+";
			break;
		
		case 10:
			src_radix_regex = "([\\(\\[\\+\\-\\*\\/ ,#])([1-9][0-9]*)";
			break;
		
		case 0x10:
			src_radix_regex = "$$[0-9A-F]+";
			break;
		
	}
	
	std::smatch number_match;
	// Search for all matches to numbers of this base
	for(std::string::const_iterator search_start(str.cbegin()); std::regex_search(search_start, str.cend(), number_match, src_radix_regex);) {
		
		// Get the full match
		std::string number_string = number_match[0];
		// Convert to a numeric value based on the radix provided
		uint16_t number_value = std::stoul(number_string.c_str() + 1, nullptr, src_radix);
		
		// Create a stream and add the first submatch if one is found - this will only be for octal and decimal
		std::stringstream result_stream;
		result_stream << number_match[1];
		
		// Build the converted number string based on the desired radix
		switch(dest_radix) {
			
			// For binary, convert to 4 bits for each hex digit the number would require
			case 0b10:
			
				result_stream << '%';
			
				if(number_value > 0xFFF)
					result_stream << std::bitset<16>(number_value);
				else if(number_value > 0xFF)
					result_stream << std::bitset<12>(number_value);
				else if(number_value > 0xF)
					result_stream << std::bitset<8>(number_value);
				else
					result_stream << std::bitset<4>(number_value);
			
				break;
			
			case 010:
				result_stream << '0' << std::oct << number_value;
				break;
			
			case 10:
				result_stream << std::dec << number_value;
				break;
			
			// For hexadecimal, convert to a 2 or 4 digit number depending on if the number is below or above 0x100 respectively
			case 0x10:
				result_stream << '$' << std::setfill('0') << std::setw(number_value > 0xFF ? 4 : 2) << std::hex << std::uppercase << number_value;
				break;
			
		}
		
		//std::cout << "Replacing " << number_string << " with " << result_stream.str() << " at position " << number_match.position() << ", length " << number_string.length() << '\n';
		//std::cout << "String at " << number_match.position() - 4 << " to " << number_match.position() + number_string.length() << ": " << str.substr(number_match.position() - 4, 4 + number_string.length()) << '\n'; 
		
		// Replace the matched number with the converted one
		str.replace(number_match.position(), number_string.length(), result_stream.str());
		
		search_start = str.cbegin();
		//std::cout << str;
		
	}
	
}

// Taken from an answer at https://stackoverflow.com/questions/6089231/getting-std-ifstream-to-handle-lf-cr-and-crlf
std::istream &getline_multiplatform(std::istream &istr, std::string &str) {
	
	str.clear();
	
	std::istream::sentry se(istr, true);
	std::streambuf *sb = istr.rdbuf();
	
	while(1) {
		
		int32_t c = sb->sbumpc();
		
		switch(c) {
			
			case '\n':
				return istr;
				
			case '\r':
			
				if(sb->sgetc() == '\n')
					sb->sbumpc();
				
				return istr;
				
			case std::streambuf::traits_type::eof():
			
				if(str.empty())
					istr.setstate(std::ios::eofbit);
				
				return istr;
			
			default:
				str += (char)c;
			
		}
		
	}
	
}

void find_and_replace(std::string &str, const std::string &find_word, const std::string &replace_word) {
	
	std::regex find_regex("(\\b(" + find_word + "))(?:(?![A-Z_]))");
	str = std::regex_replace(str, find_regex, replace_word);
	
}

std::string strip_info(std::fstream &file, std::map<std::string, std::string> &symbols_table) {
	
	std::stringstream result_stream;
	std::regex 	space_regex("[ \t]+"), comma_regex("[ \t]?,[ \t]?"), starting_whitespace_regex("^[ \t]+"), comment_regex(";.*"), 
				symbol_regex("[\\(\\[\\+\\-\\*\\/ ,#]([A-Z_][A-Z0-9_]*)[\\)\\]\\+\\-\\*\\/ ,\n]"), expression_regex("[\\[\\]\\+\\-\\*\\/\\$A-Z0-9_ ]+\n"), ending_whitespace_regex("[ \t]*\n"), prefix_regex("\\$"),
				assign_regex(" ?([A-Z_][A-Z0-9_]*) ?=");
	
	// Thinking of adding the "original" line numbers to the beginning of each line of the temp file
	// Maybe I could use that for better error messaging to let users know which actual line of the ASM file had an issue
	//size_t line_number = 0;
	
	while(file) {
		
		std::vector<std::string> assignment_names;
		std::string current_line;
		
		// Get the next line
		getline_multiplatform(file, current_line);
		current_line += '\n';
		
		// Remove comments
		current_line = std::regex_replace(current_line, comment_regex, "");
		// Remove starting whitespace
		current_line = std::regex_replace(current_line, starting_whitespace_regex, "");
		
		// Convert newlines
		//current_line = std::regex_replace(current_line, newline_regex, "\n");
		
		// Ignore blank lines
		if(current_line.find_first_not_of(" \r\n\t") == std::string::npos)
			continue;
		
		// Truncate spaces
		current_line = std::regex_replace(current_line, space_regex, " ");
		// Truncate comma spacing
		current_line = std::regex_replace(current_line, comma_regex, ",");
		// Replace any ending whitespace and newlines with just a standard newline character
		current_line = std::regex_replace(current_line, ending_whitespace_regex, "\n");
		
		// Capitalize line for simpler processing
		to_upper(current_line);
		
		// Do all base conversions now wherever applicable
		fix_zeros(current_line);
		convert_radix(current_line, 16, 2);
		convert_radix(current_line, 16, 8);
		convert_radix(current_line, 16, 10);
		
		// Add any non-assignments to the output stream and continue to the next line
		if(current_line.find('=') == std::string::npos) {
			
			// See above comment about line_number. Not currently supported by the parser, so I'm not including it here yet
			result_stream << /*line_number++ << '\t' <<*/ current_line;
			continue;
			
		}
		
		
		
		// Match all symbol names in the (possibly) compound assignment statement
		for(std::smatch names_match; std::regex_search(current_line, names_match, assign_regex);) {
			
			std::string symbol_name = names_match[1].str();
			
			if(symbols_table.contains(symbol_name))
				throw new std::logic_error("ERROR: Cannot define symbol twice.");
			
			// Ensure this symbol is not a restricted word
			if(std::find(instruction_names.begin(), instruction_names.end(), symbol_name) != instruction_names.end())
				throw new std::domain_error("ERROR: Cannot use restricted word [" + symbol_name + "] as a symbol.");
			if(symbol_name == std::string("A") || symbol_name == std::string("X") || symbol_name == std::string("Y"))
				throw new std::domain_error("ERROR: Cannot use restricted word [" + symbol_name + "] as a symbol.");
			
			assignment_names.push_back(symbol_name);
			
			current_line = names_match.suffix();
			
		}
		
		// Find anything after the last assignment operator and set that as the replacement string
		
		std::smatch expression_match;
		
		// Pull the expression for this assignment
		if(!std::regex_search(current_line, expression_match, expression_regex))
			throw new std::runtime_error("ERROR: All symbols must be set to a numeric value.");
		
		std::string expression_string = expression_match.str();
		
		// If there is a space after the = sign, replace with a left bracket
		// There cannot be a space after the expression due to removing ending whitespace above, and there can only be up to one before the expression due to truncating spaces above
		// If there was no space, insert a left bracket
		if(expression_string[0] == ' ')
			expression_string[0] = '[';
		else
			expression_string.insert(0, 1, '[');
		
		// Add a right bracket to close the expression
		// This will ensure it is wrapped and its precedence is not affected by the find and replace
		if(expression_string[expression_string.length() - 1] == '\n')
			expression_string[expression_string.length() - 1] = ']';
		else
			expression_string += ']';
		
		// Replace any '$' prefixes with "$$" to allow it to work with the find and replace regex
		expression_string = std::regex_replace(expression_string, prefix_regex, "$$$$");
		
		// Replace any symbols that were in this expression with their literal values
		// If a symbol hasn't been encountered yet, set to $FFFF
		std::smatch symbol_match;
		for(std::string::const_iterator search_start(expression_string.cbegin()); std::regex_search(search_start, expression_string.cend(), symbol_match, symbol_regex);) {
			
			std::string matched_symbol = symbol_match[1];
			std::string symbol_value = symbols_table.contains(matched_symbol) ? symbols_table[matched_symbol] : "$$FFFF";
			
			expression_string.replace(symbol_match.position() + 1, matched_symbol.length(), symbol_value);
			
			search_start = expression_string.cbegin();
			
		}
		// Maybe this could be enhanced to allow later-defined symbols using a tree, where a parent node relies on its child nodes being evaluable before it can be evaluated
		// Once all symbols are in the symbols table, trees could be constructed in this format for any symbols that are not currently evaluable
		// They can then be evaluated from the leaves up to the root and replaced in the symbols table where applicable
		
		// Add each new symbol to the symbol map with its determined value
		for(std::string symbol_name : assignment_names)
			symbols_table.insert(std::pair<std::string, std::string>(symbol_name, expression_string));
		
		// Clear the assignment_names vector so it can be used on next loop
		assignment_names.clear();
		
	}
	
	std::string return_string = result_stream.str();
	if(return_string[return_string.length() - 1] == '\n')
		return_string.pop_back();
	
	return return_string;
	
}