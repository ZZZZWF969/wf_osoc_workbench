#include "../include/difftest.h"
#include "../include/memory.h"

CPU_state cpu;

void cpu_state_update(){
	for(int i = 0; i < 32l; i++){
		cpu.gpr[i] = top_gpr[i];
	}
	cpu.pc = top_pc;
}

void (*ref_difftest_memcpy)(paddr_t addr, void *buf, size_t n, bool direction) = NULL;
void (*ref_difftest_regcpy)(void *dut, bool direction) = NULL;
void (*ref_difftest_exec)(uint64_t n) = NULL;
void (*ref_difftest_raise_intr)(uint64_t NO) = NULL;

static bool is_skip_ref = false;
static int skip_dut_nr_inst = 0;

const char* regs2[] = {
  "$0", "ra", "sp", "gp", "tp", "t0", "t1", "t2",
  "s0", "s1", "a0", "a1", "a2", "a3", "a4", "a5",
  "a6", "a7", "s2", "s3", "s4", "s5", "s6", "s7",
  "s8", "s9", "s10", "s11", "t3", "t4", "t5", "t6"
};

bool isa_check_reg(CPU_state *ref_r, vaddr_t pc){
	bool correct = true;
	int i = 0;
	if (ref_r->pc != pc) correct = false;
	for(i = 0; i < 32; i++){
		if(ref_r->gpr[i] != top_gpr[i]) correct = false;
	}
	if(correct == false){
		printf("========difftest failed========\n");
		printf("ref_pc = %x\n",ref_r->pc);
		printf("dut_pc = %x\n",top_pc);
		for(i = 0; i < 32; i++){
			if(ref_r->gpr[i] != top_gpr[i]){
				printf("ref-%3s   0x%08x\n",regs2[i], ref_r->gpr[i]);
				printf("dut-%3s   0x%08x\n",regs2[i], top_gpr[i]);
			}
    	}
	}
	return correct;
}

static void checkreg(CPU_state *ref_r, vaddr_t pc){
	if(!isa_check_reg(ref_r, pc)){
		npc_state.state = NPC_ABORT;
		npc_state.state = pc;
	}
}

void init_difftest(char *ref_so_file, long img_size, int port) 
{
    assert(ref_so_file != NULL);
    void *handle;
    handle = dlopen(ref_so_file, RTLD_LAZY);
    if (!handle) {
        fprintf(stderr, "dlopen error: %s\n", dlerror());
        exit(1);
    }
    printf("%s\n",ref_so_file);
    assert(handle);

    ref_difftest_memcpy = (void (*)(uint32_t, void*, size_t, bool))dlsym(handle, "difftest_memcpy");
    assert(ref_difftest_memcpy);

    ref_difftest_regcpy = (void (*)(void*, bool))dlsym(handle, "difftest_regcpy");
    assert(ref_difftest_regcpy);

    ref_difftest_exec = (void (*)(uint64_t))dlsym(handle, "difftest_exec");
    assert(ref_difftest_exec);

    void (*ref_difftest_init)(int) = (void (*)(int))dlsym(handle, "difftest_init");
    assert(ref_difftest_init);

    printf("The result of every instruction will be compared with %s. "
        "This will help you a lot for debugging, but also significantly reduce the performance.\n", ref_so_file);

    ref_difftest_init(port);
    ref_difftest_memcpy(MEM_BASE, guest_to_host(MEM_BASE), img_size, DIFFTEST_TO_REF);
}

void difftest_skip_ref(){
  is_skip_ref = true;
  skip_dut_nr_inst = 0;
}

void difftest_step(vaddr_t pc){
	
	CPU_state ref_r;

	if (skip_dut_nr_inst > 0) {
		ref_difftest_regcpy(&ref_r, DIFFTEST_TO_DUT);
		if (ref_r.pc == pc) {
			skip_dut_nr_inst = 0;
			checkreg(&ref_r, pc);
			return;
		}
		skip_dut_nr_inst --;
		if (skip_dut_nr_inst == 0)
			printf("can not catch up with ref.pc = 0x%08x at pc = 0x%08x", ref_r.pc, pc);
//			panic("can not catch up with ref.pc = " FMT_WORD " at pc = " FMT_WORD, ref_r.pc, pc);
		return;
	}

	if (is_skip_ref) {
		// to skip the checking of an instruction, just copy the reg state to reference design
		cpu_state_update();
		ref_difftest_regcpy(&cpu, DIFFTEST_TO_REF);
		is_skip_ref = false;
		return;
	}

	ref_difftest_exec(1);
	ref_difftest_regcpy(&ref_r, DIFFTEST_TO_DUT);

	checkreg(&ref_r, pc);
}