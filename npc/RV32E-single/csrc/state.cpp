#include "include/state.h"

NPCstate npc_state = { .state = NPC_STOP };

int is_statu_bad(){
	int good = (npc_state.state == NPC_END && npc_state.halt_ret == 0) || npc_state.state == NPC_QUIT;
	return !good;
}

void set_npc_state(int state, word_t halt_pc, word_t halt_ret){
	npc_state.state = state;
	npc_state.halt_pc = halt_pc;
	npc_state.halt_ret = halt_ret;
}

void npctrap(word_t halt_pc, word_t halt_ret){
	set_npc_state(NPC_END, halt_pc, halt_ret);
}