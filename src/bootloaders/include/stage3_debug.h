#ifndef DEBUG_H
#define DEBUG_H

#include <stdint.h>
#include <stdarg.h>

void putchar(char c);
void print_hex(uint64_t val);
void print_dec(uint64_t val);
void printf(const char* fmt, ...);

#endif 
