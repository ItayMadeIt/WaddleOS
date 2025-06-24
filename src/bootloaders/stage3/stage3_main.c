#include <stage3_paging.h>
#include <stage3_debug.h>

void stage3_main()
{
    setup_idt();

    setup_paging();

    setup_64bit_gdt();
}