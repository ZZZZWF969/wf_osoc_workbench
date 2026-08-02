#include "memory.h"

void* create_virtual_memory();
void destory_virtual_memory(void* memory);
word_t vmem_read(vaddr_t addr, int len);
void vmem_write(vaddr_t addr, int len, word_t data);