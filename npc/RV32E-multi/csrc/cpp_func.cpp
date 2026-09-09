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
void mtrace_retire_print();

void difftest_skip_ref();

void trace_and_difftest(){
	IFDEF(CONFIG_NPC_DIFFTEST, difftest_step(top_pc);)
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
//修改（多周期适配）：原函数体"一次调用走一个时钟周期"基于单周期假设（1周期=1指令），
//多周期RTL下一条指令占IF/ID/EX/WB共4拍，原实现导致itrace重复记录、difftest四倍速跑飞。
//重定义为"驱动时钟直至本条指令退休或仿真结束"，恢复"1次exec_once=1条指令"的契约，
//si/difftest/itrace等监视调用结构随之自动恢复正确。原函数体整体注释保留如下：
//	top->INST = vmem_read(top->PC, 4);		//取指
//	device_update();
//	top->clk = 1;
//	// 修改：授权只给"本拍真实执行 load 指令"的拍——时序取指下 posedge 锁存下一条后
//	// IDU 会立即重算（nba 阶段），若下一条是 LW 会提前触发 kbd_read 消费，必须用本拍指令判断
//	// FIFO_read_allow = ((top_inst & 0x7f) == 0x03) ? 1 : 0;	//修改（键盘问题修复）：多周期下一条load占据INST寄存器4拍，原判定在ID锁存拍与EX锁存拍各授权一次，kbd_read双重dequeue吞掉按键事件
//	//修改（键盘问题修复）：加if_valid门控，授权收窄到指令首次呈现拍（SEND拍），保证每条load只dequeue一次
//	FIFO_read_allow = (top_if_valid && ((top_inst & 0x7f) == 0x03)) ? 1 : 0;
//	top->eval(); IFDEF(CONFIG_NPC_WAVE, tfp->dump(wave_count++);)	//时钟拉高
//	IFDEF(CONFIG_NPC_ITRACE, itrace_inst(top_pc, top_inst);)		//修改（多周期适配）：itrace移至下方退休拍（每拍记录会同指令重复3次且PC错配）
//	//仿真结束逻辑
//	if(Verilated::gotFinish()){
//		npctrap(top->PC, top_gpr[10]);
//		std::cout<<std::string(ANSI_FG_YELLOW)+"get finish signal by DPI-C at PC=0x"
//		<<std::hex<<top->PC<<std::string(ANSI_NONE)
//		<<std::endl;
//		return;
//	}
//		// if(is_io_device(top->RAM_ADDR)){
//		// 	// std::cout<<"skip difftest"<<std::endl;
//		// 	IFDEF(CONFIG_NPC_DIFFTEST, difftest_skip_ref();)
//		// }else{
//		// 	trace_and_difftest();
//		// }
//	top->clk = 0; top->eval(); IFDEF(CONFIG_NPC_WAVE, tfp->dump(wave_count++);)	//时钟拉低
//	IFDEF(CONFIG_NPC_WATCHPOINT, watchpoint_difftest();)
//	return;

	//内层循环：逐拍驱动时钟，直到本条指令退休（WB提交沿）或仿真结束
	while(1){
		device_update();
		//授权逻辑不变（键盘问题修复）：只在load指令首次呈现拍（SEND拍）授权一次dequeue
		FIFO_read_allow = (top_if_valid && ((top_inst & 0x7f) == 0x03)) ? 1 : 0;
		//posedge前快照：ex_valid=1表示本沿是WB提交沿（退休沿），拍末GPR/CSR/store提交、pc更新
		bool will_retire = top_ex_valid;
		//MMIO判定限load/store（RAM_ADDR=EXU组合地址，对跳转类=目标地址、非访存指令=残留值，须过滤）
		bool retire_is_mmio = will_retire && is_io_device(top->RAM_ADDR)
			&& (((top_inst & 0x7f) == 0x03) || ((top_inst & 0x7f) == 0x23));
		top->clk = 1; top->eval(); IFDEF(CONFIG_NPC_WAVE, tfp->dump(wave_count++);)	//时钟拉高
		if(will_retire){
			//退休拍统一监视点：此刻GPR/CSR/store已提交，top_pc=下一条地址，ir_pc/INST
			//仍是本条指令，mtrace捕获区必属本条指令（读发生在退休沿前，store写在退休沿内）
			IFDEF(CONFIG_NPC_ITRACE, itrace_inst(top_ir_pc, top_inst);)
			IFDEF(CONFIG_NPC_MTRACE, mtrace_retire_print();)
			if(retire_is_mmio){
				IFDEF(CONFIG_NPC_DIFFTEST, difftest_skip_ref();)	//MMIO访问：DUT状态回拷REF，跳过比对
			}else{
				trace_and_difftest();					//普通指令：REF推一条并比对（top_pc已=下一条地址）
			}
		}
		//仿真结束逻辑
		if(Verilated::gotFinish()){
			//ebreak在ID拍停机等不到退休沿，此处补记本条指令（本拍已退休则不重复记）
			if(!will_retire){
				IFDEF(CONFIG_NPC_ITRACE, itrace_inst(top_ir_pc, top_inst);)
			}
			npctrap(top->PC, top_gpr[10]);
			std::cout<<std::string(ANSI_FG_YELLOW)+"get finish signal by DPI-C at PC=0x"
			<<std::hex<<top->PC<<std::string(ANSI_NONE)
			<<std::endl;
			top->clk = 0; top->eval(); IFDEF(CONFIG_NPC_WAVE, tfp->dump(wave_count++);)	//补完negedge：clk收低、波形完整
			return;
		}
		top->clk = 0; top->eval(); IFDEF(CONFIG_NPC_WAVE, tfp->dump(wave_count++);)	//时钟拉低
		IFDEF(CONFIG_NPC_WATCHPOINT, watchpoint_difftest();)	//逐拍检查；NPC_STOP不作循环出口，退休沿自然停在指令边界
		if(will_retire) return;		//本条指令已退休且本拍走完：1次exec_once=1条指令
	}
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
		//修改（多周期适配）：difftest已移回exec_once退休拍触发（此处逐拍触发会使REF四倍速跑飞）
		// if(is_io_device(top->RAM_ADDR) /*&& top->RAM_ADDR!=KBD_ADDR*/ ){
		// 	// std::cout<<"skip difftest"<<std::endl;
		// 	IFDEF(CONFIG_NPC_DIFFTEST, difftest_skip_ref();)
		// }else{
		// 	trace_and_difftest();
		// }
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