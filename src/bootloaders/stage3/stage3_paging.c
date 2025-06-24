#include <stage3_paging.h>

page_map_t page_map_level_4;
page_map_t page_directory_pointer_table_identity_map;
page_map_t page_directory_pointer_table_kernel;
page_map_t page_directory_identity_map;
page_map_t page_directory_kernel;
#define PAGE_TABLES_IDENTITY_MAP_COUNT 1
page_map_t page_tables_identity_map[PAGE_TABLES_IDENTITY_MAP_COUNT];
#define PAGE_TABLES_KERNEL_COUNT 12
page_map_t page_tables_kernel[PAGE_TABLES_KERNEL_COUNT];

#define APPLY_PAGE_FLAGS(page_map) ((uint64_t)((uint64_t)page_map | KERNEL_PAGE_FLAGS))

#define KERNEL_VIRT (0xFFFFFFFF80000000)
#define KERNEL_PHYS (0x100000)

static void setup_identity_map_pages()
{
    page_map_level_4.entries[0] = 
        APPLY_PAGE_FLAGS(&page_directory_pointer_table_identity_map);

    page_directory_pointer_table_identity_map.entries[0] = 
        APPLY_PAGE_FLAGS(&page_directory_identity_map);

    for (uint64_t i = 0; i < PAGE_TABLES_IDENTITY_MAP_COUNT; i++)
    {
        page_directory_identity_map.entries[i] = APPLY_PAGE_FLAGS(&page_tables_identity_map[i]);
    }


    // Ensure all tables have valid pages
    uint64_t addr = APPLY_PAGE_FLAGS(0); 
    for (uint64_t i = 0; i < PAGE_TABLES_IDENTITY_MAP_COUNT; i++)
    {
        for (uint64_t j = 0; j < PAGE_ENTRIES; j++)
        {
            page_tables_identity_map[i].entries[j] = addr;

            addr += PAGE_SIZE;
        }
    }
}

static void setup_kernel_pages()
{
    page_map_level_4.entries[(KERNEL_VIRT >> 39)  & 0x1FF] 
        = APPLY_PAGE_FLAGS(&page_directory_pointer_table_kernel);
    
    page_directory_pointer_table_kernel.entries[(KERNEL_VIRT >> 30)  & 0x1FF] 
        = APPLY_PAGE_FLAGS(&page_directory_kernel);
    
    for (uint64_t i = 0; i < PAGE_TABLES_KERNEL_COUNT; i++)
    {
        page_directory_kernel.entries[((KERNEL_VIRT >> 21)  & 0x1FF) + i] 
            = APPLY_PAGE_FLAGS(&page_tables_kernel[i]);    
    }
    
    // Ensure all tables have valid pages
    uint64_t addr = KERNEL_PHYS;

    for (uint64_t i = 0; i < PAGE_TABLES_KERNEL_COUNT; i++)
    {
        for (uint64_t j = 0; j < PAGE_ENTRIES; j++)
        {
            page_tables_kernel[i].entries[j] = APPLY_PAGE_FLAGS(addr);

            addr += PAGE_SIZE;
        }
    }
}

void setup_paging()
{
    // all global vars above are already initialized to zero (.bss section)
    setup_identity_map_pages();

    setup_kernel_pages();

    set_cr3_func(&page_map_level_4);
}