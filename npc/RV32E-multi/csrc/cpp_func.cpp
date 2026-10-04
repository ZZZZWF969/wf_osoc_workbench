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
	IFDEF(CONFIG_NPC_ITRACE, itrace_inst(top_ir_pc, top_inst);)		//指令踪迹：退休沿记录本条指令
	IFDEF(CONFIG_NPC_MTRACE, mtrace_retire_print();)				//访存踪迹：退休沿打印本条指令读写
	IFDEF(CONFIG_NPC_DIFFTEST, difftest_step(top_pc);)				//difftest：REF推一条并比对（skip标志由设备访问点置位，top_pc已=下一条地址）
	IFDEF(CONFIG_NPC_WATCHPOINT, watchpoint_difftest();)			//监视点：退休沿求值（原逐拍调用，粒度改逐指令）
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
	while(1){
		sim_cycle_count++;
		device_update();
		//授权改为恒授权——每拍首次kbd_read消费、拍内后续调用返回稳定值（keyboard.cpp内消费后清零），
		//原"读窗口武装"行保留以便验证失败时回退
		FIFO_read_allow = 1;
		//posedge前快照：ex_valid=1表示本沿是WB提交沿（退休沿），拍末GPR/CSR/store提交、pc更新
		bool will_retire = top_ex_valid;
		top->clk = 1; top->eval(); IFDEF(CONFIG_NPC_WAVE, tfp->dump(wave_count++);)	//时钟拉高

		if(will_retire){
			sim_retire_count++;	
			trace_and_difftest();	//退休沿统一监视：itrace/mtrace/difftest/watchpoint（GPR已提交，top_pc=下一条地址）
		}
		
		//仿真结束逻辑
		if(Verilated::gotFinish()){
			//ebreak在EX拍停机等不到退休沿，此处补记本条指令（本拍已退休则不重复记）
			if(!will_retire){
				sim_retire_count++;			//ebreak计入退休指令数，使CPI统计完整
				IFDEF(CONFIG_NPC_ITRACE, itrace_inst(top_ir_pc, top_inst);)
			}
//			npctrap(top->PC, top_gpr[10]);
			//修改（总线看门狗）：超时已置NPC_ABORT并带abort_reason，npctrap会覆盖为END导致误报GOOD/BAD TRAP
			if(npc_state.state != NPC_ABORT){
				npctrap(top->PC, top_gpr[10]);
			}
			std::cout<<std::string(ANSI_FG_YELLOW)+"get finish signal by DPI-C at PC=0x"
			<<std::hex<<top->PC<<std::string(ANSI_NONE)
			<<std::endl;
			top->clk = 0; top->eval(); IFDEF(CONFIG_NPC_WAVE, tfp->dump(wave_count++);)	//补完negedge：clk收低、波形完整
			return;
		}
		top->clk = 0; top->eval(); IFDEF(CONFIG_NPC_WAVE, tfp->dump(wave_count++);)	//时钟拉低
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
		//退出状态：NPC_ABORT按abort_reason区分（difftest失败/AXI总线错误），NPC_END按a0区分GOOD/BAD TRAP
		//修改（B通道补全）：ABORT原因改为动态记录，日志终态可区分总线错误与difftest失败
		char abort_status[80];
		const char* status;
//		if(npc_state.state == NPC_ABORT)			status = "ABORT (difftest failed)";
		if(npc_state.state == NPC_ABORT){
			snprintf(abort_status, sizeof(abort_status), "ABORT (%s)",
				npc_state.abort_reason ? npc_state.abort_reason : "unknown");
			status = abort_status;
		}
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

//总线错误停机（MEM_CTRL检查resp非OKAY时RTL调用）：打印并以ABORT终止；
//abort_reason记录原因供cpi_report日志终态区分（static指针常驻，进程退出前有效）
extern "C" void bus_error(unsigned int resp){
	std::cout<<std::string(ANSI_FG_RED)+"AXI bus error: resp=0x"
	<<std::hex<<resp<<" at PC=0x"<<top->PC<<std::string(ANSI_NONE)<<std::endl;
	static char reason[48];
	snprintf(reason, sizeof(reason), "AXI bus error (resp=0x%x)", resp);
	npc_state.abort_reason = reason;
	set_npc_state(NPC_ABORT, top->PC, 0);
}

//总线超时停机（MEM_CTRL看门狗触发）：等待ready/rvalid/bvalid超阈值，从设备无响应。
//与bus_error不同：无退休沿可依托，须置gotFinish让exec_once当拍退出（npctrap有ABORT保护，不会被覆盖成END）
extern "C" void bus_timeout(unsigned int channel){
	//channel：0=数据等rvalid 1=数据等bvalid 2=数据等ready 3=取指等rvalid 4=取指等arready
	const char* what = channel == 0 ? "waiting rvalid" :
	                   channel == 1 ? "waiting bvalid" :
	                   channel == 2 ? "waiting ar/aw/w ready" :
	                   channel == 3 ? "waiting ifu rvalid" : "waiting ifu arready";
	std::cout<<std::string(ANSI_FG_RED)+"AXI bus timeout: "+what+" at PC=0x"
	<<std::hex<<top->PC<<std::string(ANSI_NONE)<<std::endl;
	static char reason[48];
	snprintf(reason, sizeof(reason), "AXI bus timeout (%s)", what);
	npc_state.abort_reason = reason;
	set_npc_state(NPC_ABORT, top->PC, 0);
	Verilated::gotFinish(true);
}