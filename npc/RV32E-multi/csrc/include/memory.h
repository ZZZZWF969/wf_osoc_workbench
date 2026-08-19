#include <stdio.h>
#include <sys/mman.h>
#include <fcntl.h>
#include <unistd.h>
#include <assert.h>
#include <stdint.h>
#include "word.h"
#include "ansi.h"

#define MEM_SIZE 128
#define MEMSIZE MEM_SIZE*1024*1024
#define MEM_BASE 0x80000000

uint8_t* guest_to_host(paddr_t paddr);

static inline word_t host_read(void* addr, int len){
    switch(len){
        case 1: return *(uint8_t  *)addr;
        case 2: return *(uint16_t *)addr;
        case 4: return *(uint32_t *)addr;
        default: printf(ANSI_FG_RED "ATENTION: HERE HAPPENED AN UNDEFINED MEMORY READ!\n" ANSI_NONE); return 0;
    }
}

static inline void host_write(void* addr, int len, word_t data){
    switch(len){
        case 1: *(uint8_t  *)addr = data; return;
        case 2: *(uint16_t *)addr = data; return;
        case 4: *(uint32_t *)addr = data; return;
        default: printf(ANSI_FG_RED "ATENTION: HAPPENED AN UNDEFINED MEMORY WRITE\n" ANSI_NONE); assert(0);
    }
}

