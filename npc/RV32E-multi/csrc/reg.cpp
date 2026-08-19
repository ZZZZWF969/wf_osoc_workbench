#include "include/npc.h"
#include "include/npcpp.hpp"

const char* regs[] = {
  "$0", "ra", "sp", "gp", "tp", "t0", "t1", "t2",
  "s0", "s1", "a0", "a1", "a2", "a3", "a4", "a5",
  "a6", "a7", "s2", "s3", "s4", "s5", "s6", "s7",
  "s8", "s9", "s10", "s11", "t3", "t4", "t5", "t6"
};

//int number = sizeof(regs)/sizeof(regs[0]);

void reg_display(){
	for(int i = 0;  i < reg_number; i++){
		word_t reg_value = top_gpr[i];
		printf("%d. %s: 0x%08x \t \n", i, regs[i], reg_value);
	}
	printf("%d. pc: 0x%08x \t \n",reg_number, top_pc);
}