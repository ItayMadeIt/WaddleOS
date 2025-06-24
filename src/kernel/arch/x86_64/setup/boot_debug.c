#include <stdarg.h>
#include <stdint.h>

static uint16_t* vga_buffer = (uint16_t*)0xB8000;
static uint16_t cursor = 0;

#define VGA_WIDTH 80
#define WHITE_ON_BLACK 0x0F

static void putchar(char c) 
{
    if (c == '\n') 
    {
        cursor += VGA_WIDTH - (cursor % VGA_WIDTH);
    }
    else 
    {
        vga_buffer[cursor++] = (WHITE_ON_BLACK << 8) | c;
    }
}

static void print_hex(uint64_t val) 
{
    const char* hex_chars = "0123456789ABCDEF";
    
    for (int i = 60; i >= 0; i -= 4)
    {
        putchar(hex_chars[(val >> i) & 0xF]);
    }
}

static void print_dec(uint64_t val) {
    char buf[20];
    int i = 0;
    if (val == 0) {
        putchar('0');
        return;
    }
    while (val > 0) {
        buf[i++] = '0' + (val % 10);
        val /= 10;
    }
    while (i--)
        putchar(buf[i]);
}

void printf(const char* fmt, ...) 
{
    va_list args;
    va_start(args, fmt);
    
    for (; *fmt; fmt++) 
    {
        if (*fmt != '%') 
        {
            putchar(*fmt);
            continue;
        }

        fmt++; // skip '%'

        switch (*fmt) 
        {
            case 'x':
                print_hex(va_arg(args, uint32_t));
                break;
            case 'd':
                print_dec(va_arg(args, uint32_t));
                break;
            case 's': 
                const char* s = va_arg(args, const char*);
                while (*s)
                    putchar(*s++);
                break;
            case 'c':
                putchar((char)va_arg(args, int));
                break;
            case '%':
                putchar('%');
                break;
            default:
                putchar('?');
                break;
        }
    }

    va_end(args);
}
