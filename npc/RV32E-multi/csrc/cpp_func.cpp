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

//CPI统计（常开，无配置开关）：exec_once内层循环逐拍/逐退休指令计数，停机时报告
uint64_t sim_cycle_count = 0;		//仿真时钟周期数
uint64_t sim_retire_count = 0;		//退休指令数
extern FILE* npc_log_file;		//-l日志文件：CPI统计作为日志最后一行

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
//si/difftest/itrace等监视调用结构随之自动恢复正确。

	//内层循环：逐拍驱动时钟，直到本条指令退休（WB提交沿）或仿真结束
	while(1){
		sim_cycle_count++;				//每迭代=一个完整时钟周期
		device_update();
		//授权逻辑不变（键盘问题修复）：只在load指令首次呈现拍（SEND拍）授权一次dequeue
		// FIFO_read_allow = (top_if_valid && ((top_inst & 0x7f) == 0x03)) ? 1 : 0;	//修改（键盘问题二次复发修复）：插入RDU读取级后if_valid(SEND拍)与读窗口(read_en拍)错开一拍，授权给了无人调用的拍，真正读键盘的三次调用全部无授权，按键永远读不到
		//修改（键盘问题二次复发修复）：改为读窗口武装——读空闲拍(RAM_REN=0)武装授权，
		//读窗口内保持无授权；窗口内首笔kbd_read消费一次，窗口内其余调用(含EXU采样笔)返回同一稳定值。
		//授权与调用同源于内存口，不再绑定任何流水级信号，对增删流水级结构性免疫
		FIFO_read_allow = top->RAM_REN ? 0 : 1;
		//posedge前快照：ex_valid=1表示本沿是WB提交沿（退休沿），拍末GPR/CSR/store提交、pc更新
		bool will_retire = top_ex_valid;
		//MMIO判定限load/store（RAM_ADDR=EXU组合地址，对跳转类=目标地址、非访存指令=残留值，须过滤）
		bool retire_is_mmio = will_retire && is_io_device(top->RAM_ADDR)
			&& (((top_inst & 0x7f) == 0x03) || ((top_inst & 0x7f) == 0x23));
		top->clk = 1; top->eval(); IFDEF(CONFIG_NPC_WAVE, tfp->dump(wave_count++);)	//时钟拉高

		if(will_retire){
			sim_retire_count++;				//退休沿：自跳转停机指令与gotFinish同拍，也在此计入
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

//CPI统计报告：停机时打印终端并写入日志最后一行（无退休指令时CPI记0防除零）
//日志侧先写退出状态块再写CPI，头尾画线与中间运行痕迹划分（与文件头NPC run info块对称）
void cpi_report(){
	double cpi = sim_retire_count ? (double)sim_cycle_count / (double)sim_retire_count : 0;
	printf("retired %llu instructions in %llu cycles, CPI = %.2f\n",
		(unsigned long long)sim_retire_count, (unsigned long long)sim_cycle_count, cpi);
	if(npc_log_file != NULL){
		//退出状态：NPC_ABORT即difftest比对失败，NPC_END按a0区分GOOD/BAD TRAP
		const char* status;
		if(npc_state.state == NPC_ABORT)			status = "ABORT (difftest failed)";
		else if(npc_state.halt_ret == 0)			status = "HIT GOOD TRAP";
		else										status = "HIT BAD TRAP";
		fprintf(npc_log_file, "===== NPC exit status =====\n");
		fprintf(npc_log_file, "%s at pc = 0x%08x\n", status, npc_state.halt_pc);
		fprintf(npc_log_file, "retired %llu instructions in %llu cycles, CPI = %.2f\n",
			(unsigned long long)sim_retire_count, (unsigned long long)sim_cycle_count, cpi);
		fprintf(npc_log_file, "==========================\n");
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
		exec_once();
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
		cpi_report();		//停机时报告CPI统计（si中途暂停与q退出不走此分支）
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