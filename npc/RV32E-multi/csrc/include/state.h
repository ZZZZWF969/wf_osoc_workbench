#include "npc.h"
#include "ansi.h"

enum{ NPC_RUNNING, NPC_STOP, NPC_END, NPC_ABORT, NPC_QUIT };

typedef struct {
	int state;
	word_t halt_pc;
	word_t halt_ret;
	//修改（B通道补全）：NPC_ABORT的原因（"difftest failed"/"AXI bus error..."），供日志终态区分；其余状态无意义
	const char *abort_reason;
} NPCstate;

extern NPCstate npc_state;

//修改（B通道补全）：原型移入头文件，供cpp_func.cpp的bus_error调用（原仅state.cpp内部使用）
void set_npc_state(int state, word_t halt_pc, word_t halt_ret);

