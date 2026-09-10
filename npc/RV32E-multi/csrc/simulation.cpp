#include "include/npcpp.hpp"
#include <iostream>

void itrace_inst(word_t pc, uint32_t inst);
void npc_sdb_mainloop();
void npc_init(int argc, char *argv[]);
void memory_not_use();
int is_statu_bad();
uint64_t get_time();

VerilatedVcdC* tfp = nullptr;
VRV32E_CPU* top = nullptr;

uint64_t wave_count = 0;

void cpu_reset(){
	top->rst = 1; top->clk = 0; top->eval(); IFDEF(CONFIG_NPC_WAVE, tfp->dump(wave_count++);)	//初始复位
	top->clk = 1; top->eval(); IFDEF(CONFIG_NPC_WAVE, tfp->dump(wave_count++);)
	top->clk = 0; top->eval(); IFDEF(CONFIG_NPC_WAVE, tfp->dump(wave_count++);)
	top->clk = 1; top->eval(); IFDEF(CONFIG_NPC_WAVE, tfp->dump(wave_count++);)					//释放复位
	//修改（多周期适配）：注释掉复位时的itrace记录——此刻INST还是复位值0，会记出
	//(0x80000000, 0x00000000)的假条目（反汇编为unknown）；首条指令由exec_once退休拍正确记录
	//IFDEF(CONFIG_NPC_ITRACE, itrace_inst(top_pc, top_inst);)
	top->clk = 0; top->rst = 0; top->eval(); IFDEF(CONFIG_NPC_WAVE, tfp->dump(wave_count++);)	//解除复位
}

int main(int argc, char** argv){

	// for(int i = 0; i < argc; i++){
	// 	printf("argv[%d]: %s\n",i, argv[i]);
	// }
	
	get_time();

	Verilated::commandArgs(argc, argv);
#ifdef CONFIG_NPC_WAVE
	Verilated::traceEverOn(true);
	tfp = new VerilatedVcdC;
	top = new VRV32E_CPU;
	top->trace(tfp, 99);
	tfp->open("waveform.vcd");
#else
	top = new VRV32E_CPU;
#endif

	//initialize NPC
	
	npc_init(argc, argv);
	cpu_reset();
	std::cout << "NPC复位完成, 可以开始运行" << std::endl;

	npc_sdb_mainloop();

#ifdef CONFIG_NPC_WAVE
	tfp->close();
	delete tfp;
#endif
	delete top;
	memory_not_use();

	//关闭日志文件：确保CPI统计末行等缓冲内容落盘
	{
		extern FILE* npc_log_file;
		if(npc_log_file != NULL){ fclose(npc_log_file); npc_log_file = NULL; }
	}

	return is_statu_bad();
}