#include "verilated.h"
#include "verilated_vcd_c.h"
#include "VRV32E_CPU.h"
#include "c2cpp.h"
#include "../../build/verilator/VRV32E_CPU___024root.h"
#include <generated/autoconf.h>
#include "macro.h"
#include "word.h"
#include <iomanip>

#define top_gpr top->rootp->RV32E_CPU__DOT__REG_ARR__DOT__reg_array
#define top_pc top->rootp->RV32E_CPU__DOT__IFU__DOT__pc
#define top_ir_pc top->rootp->RV32E_CPU__DOT__IFU__DOT__ir_pc
#define top_inst top->rootp->RV32E_CPU__DOT__IFU__DOT__INST
//#define top_if_valid top->rootp->RV32E_CPU__DOT__IFU__DOT__if_valid	//修改（键盘问题二次复发修复）：授权方案改为读窗口武装(RAM_REN)后此宏不再被引用
//退休信号（WBU最终输入valid，写回拍单拍有效），供exec_once判定本沿是否为指令提交沿
//修改（访存SRAM化）：访存指令的写回沿来自DSRAM完成拍，退休沿改指顶层路由后的wbu_in_valid
//#define top_ex_valid top->rootp->RV32E_CPU__DOT__EXU__DOT__ex_valid
#define top_ex_valid top->rootp->RV32E_CPU__DOT__wbu_in_valid

extern uint64_t wave_count;
extern VerilatedVcdC* tfp;
extern VRV32E_CPU* top;
