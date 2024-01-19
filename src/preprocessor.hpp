#ifndef PREPROCESSOR_HPP
#define PREPROCESSOR_HPP

#include <iostream>
#include <vector>
#include <map>
#include <string>
#include <sstream>
#include <fstream>
#include <iomanip>
#include <regex>
#include <cstdint>
#include "opcodes.hpp"

void to_upper(std::string &str);
std::istream &getline_multiplatform(std::istream &istr, std::string &str);
std::string strip_info(std::fstream &file, std::map<std::string, std::string> &symbols_table);
void find_and_replace(std::string &str, const std::string &find_word, const std::string &replace_word);
void fix_zeros(std::string &str);
void convert_radix(std::string &str, uint8_t dest_radix, uint8_t src_radix);

#endif