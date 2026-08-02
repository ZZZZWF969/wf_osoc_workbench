#include "include/npcpp.hpp"
#include "include/vmem.h"
#include "include/state.h"
#include <iostream>
#include <cstdlib>
#include <vector>
#include <cstdint>
#include <string.h>

extern void sim_finish();
extern void halt();

void itrace_inst(word_t pc, uint32_t inst);
void itrace_display();
void difftest_step(vaddr_t pc);
void npctrap(word_t halt_pc, word_t halt_ret);

void trace_and_difftest(){
	difftest_step(top->PC);
}

void exec_once(){
	top->INST = vmem_read(top->PC, 4);		//取指
	itrace_inst(top->PC, top->INST);
	top->clk = 1; top->eval(); tfp->dump(wave_count++);	//时钟拉高
	//仿真结束逻辑
	if(Verilated::gotFinish()){
		npctrap(top->PC, top_gpr[10]);
		std::cout<<std::string(ANSI_FG_YELLOW)+"get finish signal by DPI-C at PC=0x"
		<<std::hex<<top->PC<<std::string(ANSI_NONE)
		<<std::endl;
		return;
	}
	top->clk = 0; top->eval(); tfp->dump(wave_count++);	//时钟拉低

	//itrace
	// char logbuf[128];
	// char *p = logbuf;
	// p += snprintf(p, sizeof(logbuf), "0x%08x", top->PC);
	// int ilen = 4;			//length of instruction
	// int i;
	// uint8_t *inst = (uint8_t *)&top->INST;
	// for (i = ilen - 1; i >= 0; i --) {
	// 	p += snprintf(p, 4, " %02x", inst[i]);
	// }
	// printf("%s\n",logbuf);
	// int ilen_max = 4;
	// int space_len = ilen_max - ilen;
	// if (space_len < 0) space_len = 0;
	// space_len = space_len * 3 + 1;
	// memset(p, ' ', space_len);
	// p += space_len;

	// void disassemble(char *str, int size, uint64_t p_c, uint8_t *code, int nbyte);
	// disassemble(p, logbuf + sizeof(logbuf) - p, top->PC, (uint8_t *)&top->INST, ilen);
	//itrace
	
	return;
}

void difftest_skip_ref();

extern "C" void execute(uint64_t n){

	switch(npc_state.state){
		case NPC_END: case NPC_ABORT: case NPC_QUIT:
		printf("Program execution has ended. To restart the program, exit NPC and run again.\n");
		return;
		default:npc_state.state = NPC_RUNNING;
	}

	for( ; n > 0; n--){
		if(npc_state.state != NPC_RUNNING){
			itrace_display();
			break;
		}
		exec_once();
		if(top->RAM_ADDR == 0xa00003f8 || top->RAM_ADDR == 0xa0000048 || top->RAM_ADDR == 0xa000004c){
			// std::cout<<"skip difftest"<<std::endl;
			difftest_skip_ref();
		}else{
			trace_and_difftest();
		}
	}
	
	//HIT GOOD/BAD TRAP
	switch (npc_state.state){
	case NPC_RUNNING: 
		npc_state.state = NPC_STOP; 
		break;
	case NPC_END: case NPC_ABORT:
		std::cout<<"NPC: "					//打印开始
		<<(npc_state.state == NPC_ABORT? (std::string(ANSI_FG_RED) + "ABORT" + ANSI_NONE) :		//ABORT
		  (npc_state.halt_ret == 0? 				//程序结束判断a0
		  (std::string(ANSI_FG_GREEN) + "HIT GOOD TRAP" + ANSI_NONE) :			//return 0; 
		  (std::string(ANSI_FG_RED) + "HIT BAD TRAP" + ANSI_NONE)))				//return 不是0;
		<<" at pc = 0x"
		<<std::hex<<npc_state.halt_pc<<std::dec<<std::endl;
	default:
		break;
	}
}

extern "C" void halt(){
	Verilated::gotFinish(true);
	std::cout<<std::string(ANSI_FG_RED)+"halt stop"+ANSI_NONE
	// <<std::hex<<top->PC<<"\nINST: "
	// <<std::setw(8)<<std::setfill('0')<<top->INST<<std::dec
	<<std::endl;
}

extern "C" void sim_finish(){
	std::cout<<std::string(ANSI_FG_GREEN)+"ebreak stop simulation"+ANSI_NONE<<std::endl;
	Verilated::gotFinish(true);
	return;
}