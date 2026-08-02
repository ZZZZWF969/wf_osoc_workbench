#include "include/npcpp.hpp"
#include <iostream>

void npc_sdb_mainloop();
void npc_init(int argc, char *argv[]);
void memory_not_use();
int is_statu_bad();
uint64_t get_time();

VerilatedVcdC* tfp = nullptr;
VRV32E_CPU* top = nullptr;

uint64_t wave_count = 0;

void cpu_reset(){
	top->rst = 1; top->clk = 0; top->eval(); tfp->dump(wave_count++);	//初始复位
	top->clk = 1; top->eval(); tfp->dump(wave_count++);					//释放复位
	top->clk = 0; top->rst = 0; top->eval(); tfp->dump(wave_count++);	//解除复位
}

int main(int argc, char** argv){

	// for(int i = 0; i < argc; i++){
	// 	printf("argv[%d]: %s\n",i, argv[i]);
	// }
	
	get_time();

	Verilated::commandArgs(argc, argv);
	Verilated::traceEverOn(true);
	tfp = new VerilatedVcdC;
	top = new VRV32E_CPU;
	top->trace(tfp, 99);
	tfp->open("waveform.vcd");

	//initialize NPC
	cpu_reset();
	npc_init(argc, argv);
	std::cout << "NPC复位完成, 可以开始运行" << std::endl;

	npc_sdb_mainloop();

	tfp->close();
	delete tfp; delete top;
	memory_not_use();
	
	return is_statu_bad();
}