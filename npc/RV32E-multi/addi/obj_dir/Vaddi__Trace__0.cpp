// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Tracing implementation internals
#include "verilated_vcd_c.h"
#include "Vaddi__Syms.h"


void Vaddi___024root__trace_chg_sub_0(Vaddi___024root* vlSelf, VerilatedVcd::Buffer* bufp);

void Vaddi___024root__trace_chg_top_0(void* voidSelf, VerilatedVcd::Buffer* bufp) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vaddi___024root__trace_chg_top_0\n"); );
    // Init
    Vaddi___024root* const __restrict vlSelf VL_ATTR_UNUSED = static_cast<Vaddi___024root*>(voidSelf);
    Vaddi__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    if (VL_UNLIKELY(!vlSymsp->__Vm_activity)) return;
    // Body
    Vaddi___024root__trace_chg_sub_0((&vlSymsp->TOP), bufp);
}

void Vaddi___024root__trace_chg_sub_0(Vaddi___024root* vlSelf, VerilatedVcd::Buffer* bufp) {
    if (false && vlSelf) {}  // Prevent unused
    Vaddi__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vaddi___024root__trace_chg_sub_0\n"); );
    // Init
    uint32_t* const oldp VL_ATTR_UNUSED = bufp->oldp(vlSymsp->__Vm_baseCode + 1);
    // Body
    if (VL_UNLIKELY(vlSelf->__Vm_traceActivity[1U])) {
        bufp->chgIData(oldp+0,(vlSelf->addi__DOT__pc),32);
        bufp->chgIData(oldp+1,(vlSelf->addi__DOT__REG_ARR__DOT__reg_array
                               [0U]),32);
        bufp->chgIData(oldp+2,(vlSelf->addi__DOT__REG_ARR__DOT__reg_array[0]),32);
        bufp->chgIData(oldp+3,(vlSelf->addi__DOT__REG_ARR__DOT__reg_array[1]),32);
        bufp->chgIData(oldp+4,(vlSelf->addi__DOT__REG_ARR__DOT__reg_array[2]),32);
        bufp->chgIData(oldp+5,(vlSelf->addi__DOT__REG_ARR__DOT__reg_array[3]),32);
        bufp->chgIData(oldp+6,(vlSelf->addi__DOT__REG_ARR__DOT__reg_array[4]),32);
        bufp->chgIData(oldp+7,(vlSelf->addi__DOT__REG_ARR__DOT__reg_array[5]),32);
        bufp->chgIData(oldp+8,(vlSelf->addi__DOT__REG_ARR__DOT__reg_array[6]),32);
        bufp->chgIData(oldp+9,(vlSelf->addi__DOT__REG_ARR__DOT__reg_array[7]),32);
        bufp->chgIData(oldp+10,(vlSelf->addi__DOT__REG_ARR__DOT__reg_array[8]),32);
        bufp->chgIData(oldp+11,(vlSelf->addi__DOT__REG_ARR__DOT__reg_array[9]),32);
        bufp->chgIData(oldp+12,(vlSelf->addi__DOT__REG_ARR__DOT__reg_array[10]),32);
        bufp->chgIData(oldp+13,(vlSelf->addi__DOT__REG_ARR__DOT__reg_array[11]),32);
        bufp->chgIData(oldp+14,(vlSelf->addi__DOT__REG_ARR__DOT__reg_array[12]),32);
        bufp->chgIData(oldp+15,(vlSelf->addi__DOT__REG_ARR__DOT__reg_array[13]),32);
        bufp->chgIData(oldp+16,(vlSelf->addi__DOT__REG_ARR__DOT__reg_array[14]),32);
        bufp->chgIData(oldp+17,(vlSelf->addi__DOT__REG_ARR__DOT__reg_array[15]),32);
        bufp->chgIData(oldp+18,(vlSelf->addi__DOT__REG_ARR__DOT__reg_array[16]),32);
        bufp->chgIData(oldp+19,(vlSelf->addi__DOT__REG_ARR__DOT__reg_array[17]),32);
        bufp->chgIData(oldp+20,(vlSelf->addi__DOT__REG_ARR__DOT__reg_array[18]),32);
        bufp->chgIData(oldp+21,(vlSelf->addi__DOT__REG_ARR__DOT__reg_array[19]),32);
        bufp->chgIData(oldp+22,(vlSelf->addi__DOT__REG_ARR__DOT__reg_array[20]),32);
        bufp->chgIData(oldp+23,(vlSelf->addi__DOT__REG_ARR__DOT__reg_array[21]),32);
        bufp->chgIData(oldp+24,(vlSelf->addi__DOT__REG_ARR__DOT__reg_array[22]),32);
        bufp->chgIData(oldp+25,(vlSelf->addi__DOT__REG_ARR__DOT__reg_array[23]),32);
        bufp->chgIData(oldp+26,(vlSelf->addi__DOT__REG_ARR__DOT__reg_array[24]),32);
        bufp->chgIData(oldp+27,(vlSelf->addi__DOT__REG_ARR__DOT__reg_array[25]),32);
        bufp->chgIData(oldp+28,(vlSelf->addi__DOT__REG_ARR__DOT__reg_array[26]),32);
        bufp->chgIData(oldp+29,(vlSelf->addi__DOT__REG_ARR__DOT__reg_array[27]),32);
        bufp->chgIData(oldp+30,(vlSelf->addi__DOT__REG_ARR__DOT__reg_array[28]),32);
        bufp->chgIData(oldp+31,(vlSelf->addi__DOT__REG_ARR__DOT__reg_array[29]),32);
        bufp->chgIData(oldp+32,(vlSelf->addi__DOT__REG_ARR__DOT__reg_array[30]),32);
        bufp->chgIData(oldp+33,(vlSelf->addi__DOT__REG_ARR__DOT__reg_array[31]),32);
        bufp->chgIData(oldp+34,(vlSelf->addi__DOT__REG_ARR__DOT__unnamedblk1__DOT__i),32);
    }
    bufp->chgBit(oldp+35,(vlSelf->clk));
    bufp->chgBit(oldp+36,(vlSelf->rst));
    bufp->chgIData(oldp+37,(vlSelf->RAM_RDATA),32);
    bufp->chgIData(oldp+38,(vlSelf->RAM_RADDR),32);
    bufp->chgIData(oldp+39,(vlSelf->RAM_WDATA),32);
    bufp->chgIData(oldp+40,(vlSelf->RAM_WADDR),32);
    bufp->chgBit(oldp+41,(vlSelf->RAM_WEN));
    bufp->chgCData(oldp+42,((0x1fU & (vlSelf->RAM_RDATA 
                                      >> 0xfU))),5);
    bufp->chgCData(oldp+43,((0x1fU & (vlSelf->RAM_RDATA 
                                      >> 7U))),5);
    bufp->chgIData(oldp+44,(vlSelf->addi__DOT__REG_ARR__DOT__reg_array
                            [(0x1fU & (vlSelf->RAM_RDATA 
                                       >> 0xfU))]),32);
    bufp->chgIData(oldp+45,(((((- (IData)((vlSelf->RAM_RDATA 
                                           >> 0x1fU))) 
                               << 0xcU) | (vlSelf->RAM_RDATA 
                                           >> 0x14U)) 
                             + vlSelf->addi__DOT__REG_ARR__DOT__reg_array
                             [(0x1fU & (vlSelf->RAM_RDATA 
                                        >> 0xfU))])),32);
    bufp->chgIData(oldp+46,((((- (IData)((vlSelf->RAM_RDATA 
                                          >> 0x1fU))) 
                              << 0xcU) | (vlSelf->RAM_RDATA 
                                          >> 0x14U))),32);
}

void Vaddi___024root__trace_cleanup(void* voidSelf, VerilatedVcd* /*unused*/) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vaddi___024root__trace_cleanup\n"); );
    // Init
    Vaddi___024root* const __restrict vlSelf VL_ATTR_UNUSED = static_cast<Vaddi___024root*>(voidSelf);
    Vaddi__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    // Body
    vlSymsp->__Vm_activity = false;
    vlSymsp->TOP.__Vm_traceActivity[0U] = 0U;
    vlSymsp->TOP.__Vm_traceActivity[1U] = 0U;
}
