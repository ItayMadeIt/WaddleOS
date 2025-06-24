#include <stage3_core.h>

#define IDT_ENTRIES_COUNT 256

void isr();
void lidt_func(uint32_t gdt_addr);
void sti_func();

typedef struct idt_entry {
    uint16_t offset_low;
    uint16_t selector;
    uint8_t  zero;
    uint8_t  type_attr;
    uint16_t offset_high;
} __attribute__((packed)) idt_entry_t;

typedef struct idt_descriptor {
    uint16_t limit;
    uint32_t base;
} __attribute__((packed)) idt_descriptor_t;
