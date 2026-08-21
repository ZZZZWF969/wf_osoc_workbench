// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design internal header
// See Vaddi.h for the primary calling header

#ifndef VERILATED_VADDI___024ROOT_H_
#define VERILATED_VADDI___024ROOT_H_  // guard

#include "verilated.h"

class Vaddi__Syms;

class Vaddi___024root final : public VerilatedModule {
  public:

    // DESIGN SPECIFIC STATE
    VL_IN8(clk,0,0);
    VL_IN8(rst,0,0);
    VL_OUT8(RAM_WEN,0,0);
    CData/*0:0*/ __Vtrigrprev__TOP__clk;
    CData/*0:0*/ __VactContinue;
    VL_IN(RAM_RDATA,31,0);
    VL_OUT(RAM_RADDR,31,0);
    VL_OUT(RAM_WDATA,31,0);
    VL_OUT(RAM_WADDR,31,0);
    IData/*31:0*/ addi__DOT__pc;
    IData/*31:0*/ addi__DOT__REG_ARR__DOT__rs1_data;
    IData/*31:0*/ addi__DOT__REG_ARR__DOT__unnamedblk1__DOT__i;
    IData/*31:0*/ __VstlIterCount;
    IData/*31:0*/ __VicoIterCount;
    IData/*31:0*/ __VactIterCount;
    VlUnpacked<IData/*31:0*/, 32> addi__DOT__REG_ARR__DOT__reg_array;
    VlUnpacked<CData/*0:0*/, 2> __Vm_traceActivity;
    VlTriggerVec<1> __VstlTriggered;
    VlTriggerVec<1> __VicoTriggered;
    VlTriggerVec<1> __VactTriggered;
    VlTriggerVec<1> __VnbaTriggered;

    // INTERNAL VARIABLES
    Vaddi__Syms* const vlSymsp;

    // CONSTRUCTORS
    Vaddi___024root(Vaddi__Syms* symsp, const char* v__name);
    ~Vaddi___024root();
    VL_UNCOPYABLE(Vaddi___024root);

    // INTERNAL METHODS
    void __Vconfigure(bool first);
} VL_ATTR_ALIGNED(VL_CACHE_LINE_BYTES);


#endif  // guard
