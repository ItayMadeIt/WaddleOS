#include <stage3_mem.h>
#include <stage3_paging.h>

void stage3_main(mem_map_entry_t* mem_map_entry)
{
    setup_memory_heap(mem_map_entry);

    setup_paging();
}