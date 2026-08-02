#include "include/memory.h"
#include <bits/mman-linux.h>
#include <cstdlib>
#include "include/state.h"
#include "include/device.h"

byte_t* vmem = NULL;  //用全局变量方便操作

void create_virtual_memory(){

    //检查是否真的需要分配内存
    if(vmem != NULL){
        printf("Virtual memory already exists\n");
        //return vmem;
    }

    // 使用 mmap 分配匿名私有内存映射
    void* virtual_memory = mmap(NULL, MEMSIZE, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    
    //检测内存分配是否成功
    if (virtual_memory == MAP_FAILED) {
        perror("mmap virtual memory failed\n");
        assert(0);
    }
    
    //将分配到的地址转到全局变量
    vmem = (byte_t*)virtual_memory;

    //输出分配成功信息
    printf(ANSI_FG_BLUE"Virtual memory created via mmap, size: %dMB" ANSI_NONE "\n", MEM_SIZE);
    printf(ANSI_FG_BLUE"Memory address range: [0x%08x - 0x%08x]" ANSI_NONE "\n", MEM_BASE, MEM_BASE+MEMSIZE-1);
	//return virtual_memory;
}

void destory_virtual_memory(byte_t* memory){
    if(memory == NULL)  printf("no memory can destory\n");
    else{
        int mem_ret = munmap(memory, MEMSIZE);
        if(mem_ret == 0) printf(ANSI_FG_BLUE "physic memory [%p - %p] has been free" ANSI_NONE "\n", memory, memory+MEMSIZE-1);
		else printf(ANSI_FG_RED"physic memory [%p - %p] free FAILED" ANSI_NONE "\n",memory, memory+MEMSIZE-1);
    }
}

void memory_not_use(){
	destory_virtual_memory(vmem);
}

uint8_t* guest_to_host(paddr_t paddr){return vmem+paddr-MEM_BASE;}

void serial_putch(char c);

void pmem_write(paddr_t addr, int len, word_t data){
    if(addr-MEM_BASE < MEMSIZE){
        host_write(guest_to_host(addr), len, data);
        return;
	}
//	printf("serial write: 0x%08x\n", addr);
	if(addr == SERIAL_PORT){
		printf("%c",data);
	}
    else{
//		printf(ANSI_FG_RED"address = %08x out of bound of memory" ANSI_NONE "\n", addr);
		assert(0);
    }
}

uint64_t get_time();
// void get_time();

word_t pmem_read(paddr_t addr, int len){
    if(addr-MEM_BASE < MEMSIZE){
        word_t ret = host_read(guest_to_host(addr), len);
        return ret;
    }else if(addr == RTC_ADDR){
		return get_time();
		// get_time();
		// return 0;
	}
    else{
//		printf(ANSI_FG_RED"address = %08x out of bound of memory" ANSI_NONE "\n", addr);
		return 0;
		assert(0);
    }
}

word_t vmem_read(vaddr_t addr, int len){
    return pmem_read(addr, len);
}

void vmem_write(vaddr_t addr, int len, word_t data){
    return pmem_write(addr, len, data);
}

extern "C" word_t mem_read(vaddr_t addr, int len){
//	printf("memory read at address: 0x%08x\n",addr);
    return vmem_read(addr, len);
}

extern "C" void mem_write(vaddr_t addr, int len, word_t data){
//	printf("memory write at address: 0x%08x , data: 0x%08x\n",addr, data);
    return vmem_write(addr, len, data);
}