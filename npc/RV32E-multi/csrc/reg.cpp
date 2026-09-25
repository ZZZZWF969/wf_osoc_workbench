#include "include/npc.h"
#include "include/npcpp.hpp"
#include "../include/sdb.h"
#include <cstdlib>
#include <cstring>

const char* regs[] = {
  "$0", "ra", "sp", "gp", "tp", "t0", "t1", "t2",
  "s0", "s1", "a0", "a1", "a2", "a3", "a4", "a5",
  "a6", "a7", "s2", "s3", "s4", "s5", "s6", "s7",
  "s8", "s9", "s10", "s11", "t3", "t4", "t5", "t6"
};

void reg_display(){
	for(int i = 0;  i < reg_number; i++){
		word_t reg_value = top_gpr[i];
		printf("%d. %s: 0x%08x \t \n", i, regs[i], reg_value);
	}
	printf("%d. pc: 0x%08x \t \n",reg_number, top_pc);
}

extern "C" word_t reg_str2val(const char* s, bool* success){
	const char* reg_name = s + 1;	//跳过 '$' 前缀
	if (strcmp(reg_name, "pc") == 0) return top_pc;
	if (reg_name[0] >= '0' && reg_name[0] <= '9'){
		int index = atoi(reg_name);
		if (index < 32) return top_gpr[index];
	}
	for (int i = 0; i < 32; i++){
		if (strcmp(reg_name, regs[i]) == 0) return top_gpr[i];
	}
	*success = false;
	return 0;
}
