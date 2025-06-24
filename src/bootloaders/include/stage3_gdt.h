#include <stage3_core.h>

#define GDT_ENTRIES 5

// GDT 64 flags

#define GDT_DPL(x)     ((uint64_t)(x&0b11) << 45)
#define GDT_RW(x)      ((uint64_t)(x&0b1 ) << 41)
#define GDT_EXEC(x)    ((uint64_t)(x&0b1 ) << 43)
#define GDT_PRESENT    ((uint64_t)     1   << 47)
#define GDT_NO_SYS_SEG ((uint64_t)     1   << 44)

#define GDT_MAX_LIMIT  ((uint64_t)   0xF   << 48) | ((uint64_t)0xFFFF << 0)
#define GDT_ZERO_BASE  ((uint64_t)     0        ) /*No need to write more...*/

#define GDT_FLAG_LONG  ((uint64_t)     1   << 53)
#define GDT_FLAG_DB    ((uint64_t)     1   << 53)
#define GDT_FLAG_GRAN  ((uint64_t)     1   << 55)

#define CODE_KERNEL_GDT (GDT_DPL(0) | GDT_NO_SYS_SEG | GDT_MAX_LIMIT | GDT_FLAG_GRAN | GDT_RW(0) | GDT_EXEC(1) | GDT_PRESENT | GDT_FLAG_LONG)
#define DATA_KERNEL_GDT (GDT_DPL(0) | GDT_NO_SYS_SEG | GDT_MAX_LIMIT | GDT_FLAG_GRAN | GDT_RW(1) | GDT_EXEC(0) | GDT_PRESENT | GDT_FLAG_DB)
#define CODE_USER_GDT   (GDT_DPL(3) | GDT_NO_SYS_SEG | GDT_MAX_LIMIT | GDT_FLAG_GRAN | GDT_RW(0) | GDT_EXEC(1) | GDT_PRESENT | GDT_FLAG_LONG)
#define DATA_USER_GDT   (GDT_DPL(3) | GDT_NO_SYS_SEG | GDT_MAX_LIMIT | GDT_FLAG_GRAN | GDT_RW(1) | GDT_EXEC(0) | GDT_PRESENT | GDT_FLAG_DB)

typedef uint64_t gdt_entry_t;

typedef struct gdt_descriptor
{
    uint16_t size;
    uint32_t offset;
} __attribute__((packed)) gdt_descriptor_t;

void lgdt_func(uint32_t gdt_descriptor);
void setup_64bit_gdt();