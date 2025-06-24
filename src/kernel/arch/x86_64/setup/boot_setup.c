
#include <stdint.h>

void printf(const char* fmt, ...);

void boot_main()
{
    printf("Gdt Uses Null Number, Yikes...");

    while (1);
}