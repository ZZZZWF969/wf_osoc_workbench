#include "include/memory.h"
#include <bits/mman-linux.h>
#include <cstdlib>
#include "include/state.h"
#include "include/device.h"
#include <generated/autoconf.h>
#include "macro.h"
#include "include/device.h"
#include "npcpp.hpp"

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

//void serial_putch(char c);

void pmem_write(paddr_t addr, int len, word_t data){
    if(addr-MEM_BASE < MEMSIZE){
        host_write(guest_to_host(addr), len, data);
        return;
	}else if(is_io_device(addr)){
		//serial_putch(data);
		io_device_write(addr, len, data);
	}else{
		printf(ANSI_FG_RED"address = %08x out of bound of memory" ANSI_NONE "\n", addr);
		assert(0);
    }
}

//uint64_t get_time();
// void get_time();

extern "C" word_t pmem_read(paddr_t addr, int len){
//	printf(ANSI_FG_RED"read_memory address = %08x , pc: %08x" ANSI_NONE "\n", addr, top->PC);
    if(addr-MEM_BASE < MEMSIZE){
        word_t ret = host_read(guest_to_host(addr), len);
        return ret;
    }else if(is_io_device(addr)){
//		printf(ANSI_FG_RED"read device address = %08x , pc: %08x" ANSI_NONE "\n", addr, top->PC);
		return io_device_read(addr, len);
	}else{
//		printf(ANSI_FG_RED"address = %08x out of bound of memory, pc: %08x" ANSI_NONE "\n", addr, top->PC);
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

//mtrace捕获区（多周期适配）：DPI层只捕获不打印，exec_once退休拍统一输出。
//多周期下取指也走本DPI、且load数据读在一拍内会被组合逻辑多次触发，此处打印会
//刷屏且重复；退休拍打印每指令恰一次且天然不含取指
word_t mtrace_last_read_addr = 0;
word_t mtrace_last_read_ret = 0;
word_t mtrace_last_write_addr = 0;
word_t mtrace_last_write_data = 0;
int mtrace_last_write_len = 0;

//退休拍内存踪迹打印：按本条指令opcode决定打印读还是写（捕获区时序上必属本条指令：
//load数据读全部发生在退休沿之前，store写恰在退休沿内，下一条取指在退休沿之后）
void mtrace_retire_print(){
	uint32_t opcode = top_inst & 0x7f;
	if(opcode == 0x03){		//load：打印读捕获区
		printf("pc=0x%08x  memory read  addr: 0x%08x , ret: 0x%08x\n"
			, top_ir_pc, mtrace_last_read_addr, mtrace_last_read_ret);
	}else if(opcode == 0x23){	//store：打印写捕获区（含mem_write实际收到的掩码数据与宽度）
		printf("pc=0x%08x  memory write addr: 0x%08x , len: %d , data: 0x%08x\n"
			, top_ir_pc, mtrace_last_write_addr, mtrace_last_write_len, mtrace_last_write_data);
	}
}

extern "C" word_t mem_read(vaddr_t addr, int len){
	word_t ret = vmem_read(addr, len);							//等不用了记得改回去
	//修改（多周期适配）：printf移至exec_once退休拍，此处只捕获最近一次读（取指也走本DPI会刷屏）
	//IFDEF(CONFIG_NPC_MTRACE, printf("memory read at address: 0x%08x , ret: 0x%08x\n",addr, ret);)
	IFDEF(CONFIG_NPC_MTRACE, mtrace_last_read_addr = addr; mtrace_last_read_ret = ret;)
	return ret;
//	return vmem_read(addr, len);
}

extern "C" void mem_write(vaddr_t addr, int len, word_t data){
	//修改（多周期适配）：printf移至exec_once退休拍，此处只捕获最近一次写
	//IFDEF(CONFIG_NPC_MTRACE, printf("memory write at address: 0x%08x , data: 0x%08x\n",addr, data);)
	IFDEF(CONFIG_NPC_MTRACE, mtrace_last_write_addr = addr; mtrace_last_write_data = data; mtrace_last_write_len = len;)
    return vmem_write(addr, len, data);
}
