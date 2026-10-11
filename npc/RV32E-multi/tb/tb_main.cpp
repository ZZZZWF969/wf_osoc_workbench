//仲裁器测试台主循环：驱动时钟（clk为本测试台输入），等tb_done/gotFinish后按tb_pass判定退出
#include <cstdio>
#include <cstdint>
#include "VRV32E_ARB_TB.h"
#include "verilated.h"

int main(int argc, char** argv){
	Verilated::commandArgs(argc, argv);
	VRV32E_ARB_TB* top = new VRV32E_ARB_TB;
	top->clk = 0;
	top->tb_done = 0;
	top->tb_pass = 0;
	uint64_t half_cycles = 0;
	while(!top->tb_done && !Verilated::gotFinish() && half_cycles < 20000000){
		top->clk = !top->clk;
		top->eval();
		half_cycles++;
	}
	bool pass = (top->tb_pass != 0);
	printf("[TB-MAIN] %s (half_cycles=%llu)\n", pass ? "TB PASS" : "TB FAIL",
		(unsigned long long)half_cycles);
	delete top;
	return pass ? 0 : 1;
}
