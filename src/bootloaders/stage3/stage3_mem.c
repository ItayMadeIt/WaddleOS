#include <stage3_core.h>
#include <stage3_mem.h>

#define MAX_32BIT_VALUE 0xFFFFFFFF

static uint32_t next_pow2(uint32_t value)
{
    if (value <= 1) return 1;

    uint32_t index;
    __asm__("bsr %1, %0"
            : "=r"(index)
            : "r"(value - 1));

    return 1u << (index + 1);
}

uint32_t malloc_addr;

static bool in_region(mem_map_entry_t* entry, uint32_t addr)
{
    // make it into 2 - 64 bit values:
    uint64_t base = ((uint64_t)entry->baseHigh << 32) | entry->baseLow;
    uint64_t length = ((uint64_t)entry->lengthHigh << 32) | entry->lengthLow;

    return (base <= addr && addr <= base + length);
}

void* bump_malloc(uint32_t size)
{
    malloc_addr -= size;

    return (void*)malloc_addr;
}

void* bump_malloc_aligned(uint32_t size, uint32_t alignment)
{
    uint32_t alignment_mask = next_pow2(alignment) - 1;
    
    // Adjust malloc_addr down
    malloc_addr = (malloc_addr - size) & ~alignment_mask;

    return (void*)malloc_addr;
}

// Simple bump allocator
bool setup_memory_heap(mem_map_entry_t* entry)
{
    const uint32_t kernel_addr = 0x100000; 

    while (in_region(entry, kernel_addr) == false || entry->type != MEM_USABLE)
    {
        entry++;

        if (entry->type == MEM_END_LIST)
        {
            return false;
        }
    }

    uint64_t base = ((uint64_t)entry->baseHigh << 32) | entry->baseLow;
    uint64_t length = ((uint64_t)entry->lengthHigh << 32) | entry->lengthLow;

    uint64_t max_mem_addr = base + length;

    if (max_mem_addr > MAX_32BIT_VALUE)
    {
        max_mem_addr = MAX_32BIT_VALUE;
    }

    malloc_addr = max_mem_addr & ~0xF; // align to 16 bytees

    return true;
}