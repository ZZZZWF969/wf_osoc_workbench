#include "../include/npc.h"

#ifdef CONFIG_NPC_ITRACE

#define IRING_BUF_SIZE 16

void disassemble(char *str, int size, uint64_t pc, uint8_t *code, int nbyte);

typedef struct{
    word_t pc;
    uint32_t inst;
}ItraceNode;

ItraceNode iring_buffer[IRING_BUF_SIZE];

int inst_count = 0;
bool full = false;

void itrace_inst(word_t pc, uint32_t inst){
    iring_buffer[inst_count].pc = pc;
    iring_buffer[inst_count].inst = inst;
    inst_count = (inst_count+1)%IRING_BUF_SIZE; //当存够16个时下标自动回到0
    full = full||(!inst_count);     //当下标再次回到0就知道满了
}

void itrace_display(){
    if(!full && !inst_count) return;

    int count = full ? IRING_BUF_SIZE : inst_count;
    int start = full ? inst_count : 0;
    int i;

    for(i = 0; i < count; i++){
        int idx = (start + i) % IRING_BUF_SIZE;
        char buffer[64];
        disassemble(buffer, sizeof(buffer), iring_buffer[idx].pc, (uint8_t*)&iring_buffer[idx].inst, 4);
        if((idx + 1) % IRING_BUF_SIZE == inst_count)    printf("--->");
        else                                            printf("    ");
        printf("0x%08x    %s\n", iring_buffer[idx].pc, buffer);
    }
}

#endif // CONFIG_NPC_ITRACE
