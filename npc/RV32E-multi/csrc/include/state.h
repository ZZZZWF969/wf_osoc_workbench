#include "npc.h"
#include "ansi.h"

enum{ NPC_RUNNING, NPC_STOP, NPC_END, NPC_ABORT, NPC_QUIT };

typedef struct {
	int state;
	word_t halt_pc;
	word_t halt_ret;
} NPCstate;

extern NPCstate npc_state;

