// C++ 适配层：让 C 侧表达式求值器可以读取 NPC 的寄存器
// （top_gpr/top_pc 依赖 verilator 生成的 C++ 头，无法在 .c 文件中使用）

#include "../include/npcpp.hpp"
#include "../include/sdb.h"
#include <cstdlib>
#include <cstring>

extern const char* regs[];	// reg.cpp 中的 ABI 寄存器名表

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
