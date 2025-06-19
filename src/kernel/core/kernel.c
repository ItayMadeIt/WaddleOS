#include <stdint.h>

volatile int a[1000];

void kernel_main() 
{
    volatile char* vga = (volatile char*)0xB8000;
    const char* msg = "KERNEL FUCKING WR0TE TH1S";
    for (int i = 0; msg[i] != '\0'; i++) 
    {
        vga[i * 2]     = msg[i];   // character
        vga[i * 2 + 1] = 0x07;     // attribute: light gray on black
    }

    while (1);
}
