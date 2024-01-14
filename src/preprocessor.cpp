#include "preprocessor.hpp"

std::map<std::string, std::string> symbols_table;

void to_upper(std::string &str) {
	
	for(size_t c = 0; c < str.length(); c++)
		if((str[c] > 0x60) && (str[c] < 0x7B))
			str[c] -= 0x20;
	
}

std::string strip_info(std::fstream &file) {
	
	std::stringstream result_stream;
	std::regex 	space_regex("[ \t]+"), comma_regex("[ \t]?,[ \t]?"), starting_whitespace_regex("^[ \t]+"), comment_regex(";.*"), 
				symbol_regex("[A-Z_][A-Z0-9_]*"), number_regex("[%$0]?[0-9A-F]+"), ending_whitespace_regex("[ \t]*((\r?\n)|\r)$");
	
	while(file) {
		
		std::vector<std::string> assignment_names;
		std::string current_line;
		
		// Get the next line
		std::getline(file, current_line);
		
		// Remove comments
		current_line = std::regex_replace(current_line, comment_regex, "");
		// Remove starting whitespace
		current_line = std::regex_replace(current_line, starting_whitespace_regex, "");
		
		// Ignore blank lines
		if(current_line.find_first_not_of(" \r\n\t") == std::string::npos)
			continue;
		
		// Truncate spaces
		current_line = std::regex_replace(current_line, space_regex, " ");
		// Truncate comma spacing
		current_line = std::regex_replace(current_line, comma_regex, ",");
		current_line = std::regex_replace(current_line, ending_whitespace_regex, "\n");
		
		// Capitalize line for simpler processing
		to_upper(current_line);
		
		// Add any non-assignments to the output stream and continue to the next line
		if(current_line.find('=') == std::string::npos) {
			
			result_stream << current_line;
			continue;
			
		}
		
		for(std::smatch names_match; std::regex_search(current_line, names_match, symbol_regex);) {
			
			std::string symbol_name = names_match.str();
			
			if(symbols_table.contains(symbol_name))
				throw new std::logic_error("ERROR: Cannot define symbol twice.");
			
			// Ensure this symbol is not a restricted word
			if(std::find(instruction_names.begin(), instruction_names.end(), symbol_name) != instruction_names.end())
				throw new std::domain_error("ERROR: Cannot use restricted word [" + symbol_name + "] as a symbol.");
			if(symbol_name == std::string("A"))
				throw new std::domain_error("ERROR: Cannot use restricted word [" + symbol_name + "] as a symbol.");
			
			assignment_names.push_back(symbol_name);
			
			current_line = names_match.suffix();
			
		}
		
		std::smatch number_match;
		
		// Pull the numeric value for this assignment
		if(!std::regex_search(current_line, number_match, number_regex))
			throw new std::runtime_error("ERROR: All symbols must be set to a numeric value.");
		
		std::string number_string = number_match.str();
		if(number_string[0] == '$')
			number_string.insert(0, 1, '$');
		
		// Add each new symbol to the symbol map with its determined value
		for(std::string symbol_name : assignment_names)
			symbols_table.insert(std::pair<std::string, std::string>(symbol_name, number_string));
		
		// Clear the assignment_names vector so it can be used on next loop
		assignment_names.clear();
		
	}
	
	std::string return_string = result_stream.str();
	if(return_string[return_string.length() - 1] == '\n')
		return_string.pop_back();
	
	return return_string;
	
}

void find_and_replace(std::string &str, const std::string &find_word, const std::string &replace_word) {
	
	//std::regex find_regex(find_word), symbol_regex("[A-Z_][A-Z0-9_]*");
	
	std::regex find_regex("(\\b(" + find_word + "))(?:(?![A-Z_]))");
	
	/*
	std::smatch word_match;
	// Search for all matches to the original word
	for(std::string::const_iterator search_start(str.cbegin()); std::regex_search(search_start, str.cend(), word_match, find_regex);) {
		
		// Get the full match
		//std::string found_word = word_match[0];
		std::string next_char = word_match.suffix().str().substr(0, 1);
		// Check the next character to see if it is a valid identifier character
		// If not, replace the word
		// If so, continue without replacing
		if(std::regex_match(next_char, symbol_regex)) {
			search_start += find_word.length();
			continue;
		}
		
		// Replace the matched find word with the replace word
		str.replace(word_match.position(), find_word.length(), replace_word);
		
	}
	*/
	
	str = std::regex_replace(str, find_regex, replace_word);
	
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
			src_radix_regex = "([ ,\\[])0[0-7]*";
			break;
		
		case 10:
			src_radix_regex = "([ ,\\[])[1-9][0-9]*";
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
		
		// Replace the matched number with the converted one
		str.replace(number_match.position(), number_string.length(), result_stream.str());
		
	}
	
}