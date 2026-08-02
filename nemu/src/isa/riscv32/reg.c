/***************************************************************************************
* Copyright (c) 2014-2024 Zihao Yu, Nanjing University
*
* NEMU is licensed under Mulan PSL v2.
* You can use this software according to the terms and conditions of the Mulan PSL v2.
* You may obtain a copy of Mulan PSL v2 at:
*          http://license.coscl.org.cn/MulanPSL2
*
* THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND,
* EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT,
* MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
*
* See the Mulan PSL v2 for more details.
***************************************************************************************/

#include <isa.h>
#include "local-include/reg.h"

const char* regs[] = {
  "$0", "ra", "sp", "gp", "tp", "t0", "t1", "t2",
  "s0", "s1", "a0", "a1", "a2", "a3", "a4", "a5",
  "a6", "a7", "s2", "s3", "s4", "s5", "s6", "s7",
  "s8", "s9", "s10", "s11", "t3", "t4", "t5", "t6"
};

void isa_reg_display() {
int number = sizeof(regs)/sizeof(regs[0]);
for (int i = 0;i < number;i++){
	printf("%d. %s: 0x%08x \t \n", i,regs[i],cpu.gpr[i]);
}
printf("%d. PC: 0x%08x \t \n", number, cpu.pc);
printf("mtvec: 0x%08x \t \n", cpu.csr.mtvec);
printf("mepc: 0x%08x \t \n", cpu.csr.mepc);
printf("mstatus: 0x%08x \t \n", cpu.csr.mstatus);
printf("mcause: 0x%08x \t \n", cpu.csr.mcause);
//printf("\n");
}

int name_to_index(const char* s, bool* success){
	int index = -1, number = sizeof(regs)/sizeof(regs[0]);
	for (int i = 0; i < number; i++){
		if (strcmp(regs[i],s) == 0) index = i;
		//printf("regs[%d]: %s\n",i,regs[i]);
		//printf("%d",index);
	}
	if (index == -1) {
		printf("failed to find the register.\n"); 
		*success = false; 
		return 0;
	}
	else return index;
}

word_t isa_reg_str2val(const char* s, bool* success){
	*success = true;
	//printf("reg in: %s\n",s);
	const char* reg_name = s+1;
	//printf("reg out: %s\n",reg_name);
	if (strcmp(reg_name, "pc") == 0) return cpu.pc;
	int index = name_to_index(reg_name, success);
	word_t value = cpu.gpr[index];
	return value;
}
