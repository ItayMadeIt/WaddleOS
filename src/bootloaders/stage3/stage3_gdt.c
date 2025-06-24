#include <stage3_gdt.h>

gdt_entry_t gdt_entries[GDT_ENTRIES];
gdt_descriptor_t gdt_descriptor;

void setup_64bit_gdt()
{
    gdt_entries[0] = NULL;
    gdt_entries[1] = CODE_KERNEL_GDT;
    gdt_entries[2] = DATA_KERNEL_GDT;
    gdt_entries[3] = CODE_USER_GDT;
    gdt_entries[4] = DATA_USER_GDT;

    gdt_descriptor.offset = gdt_entries;
    gdt_descriptor.size = sizeof(gdt_entries)-1;

    lgdt_func(&gdt_descriptor);
}