#include <stdbool.h>
#include <stdint.h>

typedef enum {
    MEM_END_LIST = 0,           // Mem end-of-list (Custom type)
    MEM_USABLE = 1,             // Usable RAM
    MEM_RESERVED = 2,           // Reserved by BIOS/system
    MEM_ACPI_RECLAIMABLE = 3,   // Usable after ACPI init
    MEM_ACPI_NVS = 4,           // ACPI NVS memory (do not use)
    MEM_BAD = 5,                // Bad RAM (don't touch)
} mem_type_t;

typedef struct mem_map_entry
{
    uint32_t baseLow;
    uint32_t baseHigh;
    uint32_t lengthLow;   
    uint32_t lengthHigh;   
    uint32_t type;
    
    uint32_t acpi_attrs; // ACPI 3.0 "extended attributes"

} __attribute__((packed)) mem_map_entry_t;

bool setup_memory_heap(mem_map_entry_t* entry);