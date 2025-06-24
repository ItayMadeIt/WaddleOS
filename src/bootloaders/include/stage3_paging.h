#include <stage3_core.h>

#define PAGE_SIZE 0x1000
#define PAGE_ENTRIES (PAGE_SIZE / sizeof(page_entry_t))

#define FLAG_BIT(X) (1ull << X)

#define PAGE_PRESENT   FLAG_BIT(0)
#define PAGE_WRITABLE  FLAG_BIT(1)
#define PAGE_USER      FLAG_BIT(2)

#define KERNEL_PAGE_FLAGS (PAGE_PRESENT | PAGE_WRITABLE)

typedef uint64_t page_entry_t;

typedef struct page_map
{
    page_entry_t entries[PAGE_ENTRIES];
} __attribute__((aligned(PAGE_SIZE))) page_map_t;

/// @brief Sets CR3 to page_level4 and enables PAE
/// @param page_level4 top page map
void set_cr3_func(uint32_t page_level4);

void setup_paging();