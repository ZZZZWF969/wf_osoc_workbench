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
#define top_inst top->rootp->RV32E_CPU__DOT__IFU__DOT__INST

extern uint64_t wave_count;
extern VerilatedVcdC* tfp;
extern VRV32E_CPU* top;
