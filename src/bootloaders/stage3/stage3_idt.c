#include <stage3_idt.h>

idt_entry_t idt[IDT_ENTRIES_COUNT];
idt_descriptor_t idt_ptr;

void setup_idt()
{
    idt_ptr.base = (uint32_t)&idt[0];
    idt_ptr.limit = sizeof(idt) - 1;

    uint32_t isr_addr = (uint32_t)&isr;

    for (uint32_t i = 0; i < IDT_ENTRIES_COUNT; i++)
    {
        idt[i].offset_low  = isr_addr & 0xFFFF;
        idt[i].offset_high = (isr_addr >> 16) & 0xFFFF;
        idt[i].selector    = 0x08; // for now - kernel only code segment
        idt[i].zero        = 0x00;

        // Trap type attribute probably is a possible reason
        idt[i].type_attr   = 0x8E; // (p=1, dpl=0b00, type=0b1110 => type_attributes=0b1000_1110=0x8E)

        switch (i)
        {
        case 3:
        case 4:
            idt[i].selector = 0x8F;
            break;
        
        default:
            break;
        } 
    }

    lidt_func(&idt_ptr);
    sti_func();
}