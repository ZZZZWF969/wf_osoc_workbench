#include "include/npcpp.hpp"
#include "include/vmem.h"
#include "include/state.h"
#include "include/sdb.h"
#include <iostream>
#include <cstdlib>
#include <vector>
#include <cstdint>
#include <string.h>
#include "include/device.h"

int FIFO_read_allow = 0;
extern int FIFO_read_allow;

extern void sim_finish();
extern void halt();

void itrace_inst(word_t pc, uint32_t inst);
void itrace_display();
void difftest_step(vaddr_t pc);
void npctrap(word_t halt_pc, word_t halt_ret);

void difftest_skip_ref();

void trace_and_difftest(){
	IFDEF(CONFIG_NPC_DIFFTEST, difftest_step(top_irpc);)
}

// 周期外设任务：键盘用拍数节流（每 1000 拍 poll 一次，≈0.1~1ms 延迟，开销小），
// VGA 用 60Hz 真实时间节流（帧率稳定，get_time 仅在 poll 分支执行）
void poll_sdl_events();
void vga_update_screen();

static void device_update(){
	static uint64_t poll_counter = 0;
	if(++poll_counter % 1000 != 0) return;
	poll_sdl_events();
	static uint64_t last = 0;
	uint64_t now = get_time();
	if(now - last >= 1000000 / 60){
		last = now;
		vga_update_screen();
	}
}

void exec_once(){
//	top->INST = vmem_read(top->PC, 4);		//取指
	device_update();
	top->clk = 1;
	// 修改：授权只给"本拍真实执行 load 指令"的拍——时序取指下 posedge 锁存下一条后
	// IDU 会立即重算（nba 阶段），若下一条是 LW 会提前触发 kbd_read 消费，必须用本拍指令判断
	// 原：FIFO_read_allow = 1;
	FIFO_read_allow = ((top_inst & 0x7f) == 0x03) ? 1 : 0;
	top->eval(); IFDEF(CONFIG_NPC_WAVE, tfp->dump(wave_count++);)	//时钟拉高
	IFDEF(CONFIG_NPC_ITRACE, itrace_inst(top_irpc, top_inst);)
	//仿真结束逻辑
	if(Verilated::gotFinish()){
		npctrap(top->PC, top_gpr[10]);
		std::cout<<std::string(ANSI_FG_YELLOW)+"get finish signal by DPI-C at PC=0x"
		<<std::hex<<top->PC<<std::string(ANSI_NONE)
		<<std::endl;
		return;
	}
		// if(is_io_device(top->RAM_ADDR)){
		// 	// std::cout<<"skip difftest"<<std::endl;
		// 	IFDEF(CONFIG_NPC_DIFFTEST, difftest_skip_ref();)
		// }else{
		// 	trace_and_difftest();
		// }
	top->clk = 0; top->eval(); IFDEF(CONFIG_NPC_WAVE, tfp->dump(wave_count++);)	//时钟拉低
	IFDEF(CONFIG_NPC_WATCHPOINT, watchpoint_difftest();)
	return;
}

extern "C" void execute(uint64_t n){

	switch(npc_state.state){
		case NPC_END: case NPC_ABORT: case NPC_QUIT:
		printf("Program execution has ended. To restart the program, exit NPC and run again.\n");
		return;
		default:npc_state.state = NPC_RUNNING;
	}

	for( ; n > 0; n--){
		if(npc_state.state != NPC_RUNNING){
			IFDEF(CONFIG_NPC_ITRACE, itrace_display();)
			break;
		}
		exec_once();					//等不用了记得改回去
		if(is_io_device(top->RAM_ADDR) && top->RAM_ADDR!=KBD_ADDR ){
			// std::cout<<"skip difftest"<<std::endl;
			IFDEF(CONFIG_NPC_DIFFTEST, difftest_skip_ref();)
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