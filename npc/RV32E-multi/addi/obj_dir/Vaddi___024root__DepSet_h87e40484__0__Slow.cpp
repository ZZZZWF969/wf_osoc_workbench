// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design implementation internals
// See Vaddi.h for the primary calling header

#include "verilated.h"
#include "verilated_dpi.h"

#include "Vaddi___024root.h"

VL_ATTR_COLD void Vaddi___024root___eval_static(Vaddi___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vaddi__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vaddi___024root___eval_static\n"); );
}

VL_ATTR_COLD void Vaddi___024root___eval_initial__TOP(Vaddi___024root* vlSelf);

VL_ATTR_COLD void Vaddi___024root___eval_initial(Vaddi___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vaddi__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vaddi___024root___eval_initial\n"); );
    // Body
    Vaddi___024root___eval_initial__TOP(vlSelf);
    vlSelf->__Vtrigrprev__TOP__clk = vlSelf->clk;
}

VL_ATTR_COLD void Vaddi___024root___eval_initial__TOP(Vaddi___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vaddi__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vaddi___024root___eval_initial__TOP\n"); );
    // Body
    vlSelf->RAM_WEN = 0U;
    vlSelf->RAM_WDATA = 0U;
    vlSelf->RAM_WADDR = 0U;
}

VL_ATTR_COLD void Vaddi___024root___eval_final(Vaddi___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vaddi__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vaddi___024root___eval_final\n"); );
}

VL_ATTR_COLD void Vaddi___024root___eval_triggers__stl(Vaddi___024root* vlSelf);
#ifdef VL_DEBUG
VL_ATTR_COLD void Vaddi___024root___dump_triggers__stl(Vaddi___024root* vlSelf);
#endif  // VL_DEBUG
VL_ATTR_COLD void Vaddi___024root___eval_stl(Vaddi___024root* vlSelf);

VL_ATTR_COLD void Vaddi___024root___eval_settle(Vaddi___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vaddi__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vaddi___024root___eval_settle\n"); );
    // Init
    CData/*0:0*/ __VstlContinue;
    // Body
    vlSelf->__VstlIterCount = 0U;
    __VstlContinue = 1U;
    while (__VstlContinue) {
        __VstlContinue = 0U;
        Vaddi___024root___eval_triggers__stl(vlSelf);
        if (vlSelf->__VstlTriggered.any()) {
            __VstlContinue = 1U;
            if (VL_UNLIKELY((0x64U < vlSelf->__VstlIterCount))) {
#ifdef VL_DEBUG
                Vaddi___024root___dump_triggers__stl(vlSelf);
#endif
                VL_FATAL_MT("addi.sv", 3, "", "Settle region did not converge.");
            }
            vlSelf->__VstlIterCount = ((IData)(1U) 
                                       + vlSelf->__VstlIterCount);
            Vaddi___024root___eval_stl(vlSelf);
        }
    }
}

#ifdef VL_DEBUG
VL_ATTR_COLD void Vaddi___024root___dump_triggers__stl(Vaddi___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vaddi__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vaddi___024root___dump_triggers__stl\n"); );
    // Body
    if ((1U & (~ (IData)(vlSelf->__VstlTriggered.any())))) {
        VL_DBG_MSGF("         No triggers active\n");
    }
    if (vlSelf->__VstlTriggered.at(0U)) {
        VL_DBG_MSGF("         'stl' region trigger index 0 is active: Internal 'stl' trigger - first iteration\n");
    }
}
#endif  // VL_DEBUG

VL_ATTR_COLD void Vaddi___024root___stl_sequent__TOP__0(Vaddi___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vaddi__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vaddi___024root___stl_sequent__TOP__0\n"); );
    // Body
    vlSelf->RAM_RADDR = vlSelf->addi__DOT__pc;
    vlSelf->addi__DOT__REG_ARR__DOT__rs1_data = vlSelf->addi__DOT__REG_ARR__DOT__reg_array
        [(0x1fU & (vlSelf->RAM_RDATA >> 0xfU))];
}

VL_ATTR_COLD void Vaddi___024root___eval_stl(Vaddi___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vaddi__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vaddi___024root___eval_stl\n"); );
    // Body
    if (vlSelf->__VstlTriggered.at(0U)) {
        Vaddi___024root___stl_sequent__TOP__0(vlSelf);
    }
}

#ifdef VL_DEBUG
VL_ATTR_COLD void Vaddi___024root___dump_triggers__ico(Vaddi___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vaddi__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vaddi___024root___dump_triggers__ico\n"); );
    // Body
    if ((1U & (~ (IData)(vlSelf->__VicoTriggered.any())))) {
        VL_DBG_MSGF("         No triggers active\n");
    }
    if (vlSelf->__VicoTriggered.at(0U)) {
        VL_DBG_MSGF("         'ico' region trigger index 0 is active: Internal 'ico' trigger - first iteration\n");
    }
}
#endif  // VL_DEBUG

#ifdef VL_DEBUG
VL_ATTR_COLD void Vaddi___024root___dump_triggers__act(Vaddi___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vaddi__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vaddi___024root___dump_triggers__act\n"); );
    // Body
    if ((1U & (~ (IData)(vlSelf->__VactTriggered.any())))) {
        VL_DBG_MSGF("         No triggers active\n");
    }
    if (vlSelf->__VactTriggered.at(0U)) {
        VL_DBG_MSGF("         'act' region trigger index 0 is active: @(posedge clk)\n");
    }
}
#endif  // VL_DEBUG

#ifdef VL_DEBUG
VL_ATTR_COLD void Vaddi___024root___dump_triggers__nba(Vaddi___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vaddi__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vaddi___024root___dump_triggers__nba\n"); );
    // Body
    if ((1U & (~ (IData)(vlSelf->__VnbaTriggered.any())))) {
        VL_DBG_MSGF("         No triggers active\n");
    }
    if (vlSelf->__VnbaTriggered.at(0U)) {
        VL_DBG_MSGF("         'nba' region trigger index 0 is active: @(posedge clk)\n");
    }
}
#endif  // VL_DEBUG

VL_ATTR_COLD void Vaddi___024root___ctor_var_reset(Vaddi___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vaddi__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vaddi___024root___ctor_var_reset\n"); );
    // Body
    vlSelf->clk = VL_RAND_RESET_I(1);
    vlSelf->rst = VL_RAND_RESET_I(1);
    vlSelf->RAM_RDATA = VL_RAND_RESET_I(32);
    vlSelf->RAM_RADDR = VL_RAND_RESET_I(32);
    vlSelf->RAM_WDATA = VL_RAND_RESET_I(32);
    vlSelf->RAM_WADDR = VL_RAND_RESET_I(32);
    vlSelf->RAM_WEN = VL_RAND_RESET_I(1);
    vlSelf->addi__DOT__pc = VL_RAND_RESET_I(32);
    vlSelf->addi__DOT__REG_ARR__DOT__rs1_data = VL_RAND_RESET_I(32);
    for (int __Vi0 = 0; __Vi0 < 32; ++__Vi0) {
        vlSelf->addi__DOT__REG_ARR__DOT__reg_array[__Vi0] = VL_RAND_RESET_I(32);
    }
    vlSelf->addi__DOT__REG_ARR__DOT__unnamedblk1__DOT__i = VL_RAND_RESET_I(32);
    vlSelf->__Vtrigrprev__TOP__clk = VL_RAND_RESET_I(1);
    for (int __Vi0 = 0; __Vi0 < 2; ++__Vi0) {
        vlSelf->__Vm_traceActivity[__Vi0] = 0;
    }
}
