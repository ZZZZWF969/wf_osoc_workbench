// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Tracing implementation internals
#include "verilated_vcd_c.h"
#include "Vaddi__Syms.h"


VL_ATTR_COLD void Vaddi___024root__trace_init_sub__TOP__0(Vaddi___024root* vlSelf, VerilatedVcd* tracep) {
    if (false && vlSelf) {}  // Prevent unused
    Vaddi__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vaddi___024root__trace_init_sub__TOP__0\n"); );
    // Init
    const int c = vlSymsp->__Vm_baseCode;
    // Body
    tracep->declBit(c+36,"clk", false,-1);
    tracep->declBit(c+37,"rst", false,-1);
    tracep->declBus(c+38,"RAM_RDATA", false,-1, 31,0);
    tracep->declBus(c+39,"RAM_RADDR", false,-1, 31,0);
    tracep->declBus(c+40,"RAM_WDATA", false,-1, 31,0);
    tracep->declBus(c+41,"RAM_WADDR", false,-1, 31,0);
    tracep->declBit(c+42,"RAM_WEN", false,-1);
    tracep->pushNamePrefix("addi ");
    tracep->declBit(c+36,"clk", false,-1);
    tracep->declBit(c+37,"rst", false,-1);
    tracep->declBus(c+38,"RAM_RDATA", false,-1, 31,0);
    tracep->declBus(c+39,"RAM_RADDR", false,-1, 31,0);
    tracep->declBus(c+40,"RAM_WDATA", false,-1, 31,0);
    tracep->declBus(c+41,"RAM_WADDR", false,-1, 31,0);
    tracep->declBit(c+42,"RAM_WEN", false,-1);
    tracep->declBus(c+43,"rs1_addr", false,-1, 4,0);
    tracep->declBus(c+44,"reg_rd", false,-1, 4,0);
    tracep->declBus(c+45,"read_data_1", false,-1, 31,0);
    tracep->declBus(c+1,"pc", false,-1, 31,0);
    tracep->declBus(c+46,"reg_write_data", false,-1, 31,0);
    tracep->declBus(c+47,"immediate", false,-1, 31,0);
    tracep->pushNamePrefix("REG_ARR ");
    tracep->declBit(c+36,"clk", false,-1);
    tracep->declBit(c+37,"rst", false,-1);
    tracep->declBit(c+48,"wen", false,-1);
    tracep->declBus(c+43,"raddr1", false,-1, 4,0);
    tracep->declBus(c+49,"raddr2", false,-1, 4,0);
    tracep->declBus(c+44,"write_rd", false,-1, 4,0);
    tracep->declBus(c+46,"write_data", false,-1, 31,0);
    tracep->declBus(c+45,"read_data_1", false,-1, 31,0);
    tracep->declBus(c+2,"read_data_2", false,-1, 31,0);
    tracep->declBus(c+45,"rs1_data", false,-1, 31,0);
    tracep->declBus(c+2,"rs2_data", false,-1, 31,0);
    for (int i = 0; i < 32; ++i) {
        tracep->declBus(c+3+i*1,"reg_array", true,(i+0), 31,0);
    }
    tracep->pushNamePrefix("unnamedblk1 ");
    tracep->declBus(c+35,"i", false,-1, 31,0);
    tracep->popNamePrefix(3);
}

VL_ATTR_COLD void Vaddi___024root__trace_init_top(Vaddi___024root* vlSelf, VerilatedVcd* tracep) {
    if (false && vlSelf) {}  // Prevent unused
    Vaddi__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vaddi___024root__trace_init_top\n"); );
    // Body
    Vaddi___024root__trace_init_sub__TOP__0(vlSelf, tracep);
}

VL_ATTR_COLD void Vaddi___024root__trace_full_top_0(void* voidSelf, VerilatedVcd::Buffer* bufp);
void Vaddi___024root__trace_chg_top_0(void* voidSelf, VerilatedVcd::Buffer* bufp);
void Vaddi___024root__trace_cleanup(void* voidSelf, VerilatedVcd* /*unused*/);

VL_ATTR_COLD void Vaddi___024root__trace_register(Vaddi___024root* vlSelf, VerilatedVcd* tracep) {
    if (false && vlSelf) {}  // Prevent unused
    Vaddi__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vaddi___024root__trace_register\n"); );
    // Body
    tracep->addFullCb(&Vaddi___024root__trace_full_top_0, vlSelf);
    tracep->addChgCb(&Vaddi___024root__trace_chg_top_0, vlSelf);
    tracep->addCleanupCb(&Vaddi___024root__trace_cleanup, vlSelf);
}

VL_ATTR_COLD void Vaddi___024root__trace_full_sub_0(Vaddi___024root* vlSelf, VerilatedVcd::Buffer* bufp);

VL_ATTR_COLD void Vaddi___024root__trace_full_top_0(void* voidSelf, VerilatedVcd::Buffer* bufp) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vaddi___024root__trace_full_top_0\n"); );
    // Init
    Vaddi___024root* const __restrict vlSelf VL_ATTR_UNUSED = static_cast<Vaddi___024root*>(voidSelf);
    Vaddi__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    // Body
    Vaddi___024root__trace_full_sub_0((&vlSymsp->TOP), bufp);
}

VL_ATTR_COLD void Vaddi___024root__trace_full_sub_0(Vaddi___024root* vlSelf, VerilatedVcd::Buffer* bufp) {
    if (false && vlSelf) {}  // Prevent unused
    Vaddi__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vaddi___024root__trace_full_sub_0\n"); );
    // Init
    uint32_t* const oldp VL_ATTR_UNUSED = bufp->oldp(vlSymsp->__Vm_baseCode);
    // Body
    bufp->fullIData(oldp+1,(vlSelf->addi__DOT__pc),32);
    bufp->fullIData(oldp+2,(vlSelf->addi__DOT__REG_ARR__DOT__reg_array
                            [0U]),32);
    bufp->fullIData(oldp+3,(vlSelf->addi__DOT__REG_ARR__DOT__reg_array[0]),32);
    bufp->fullIData(oldp+4,(vlSelf->addi__DOT__REG_ARR__DOT__reg_array[1]),32);
    bufp->fullIData(oldp+5,(vlSelf->addi__DOT__REG_ARR__DOT__reg_array[2]),32);
    bufp->fullIData(oldp+6,(vlSelf->addi__DOT__REG_ARR__DOT__reg_array[3]),32);
    bufp->fullIData(oldp+7,(vlSelf->addi__DOT__REG_ARR__DOT__reg_array[4]),32);
    bufp->fullIData(oldp+8,(vlSelf->addi__DOT__REG_ARR__DOT__reg_array[5]),32);
    bufp->fullIData(oldp+9,(vlSelf->addi__DOT__REG_ARR__DOT__reg_array[6]),32);
    bufp->fullIData(oldp+10,(vlSelf->addi__DOT__REG_ARR__DOT__reg_array[7]),32);
    bufp->fullIData(oldp+11,(vlSelf->addi__DOT__REG_ARR__DOT__reg_array[8]),32);
    bufp->fullIData(oldp+12,(vlSelf->addi__DOT__REG_ARR__DOT__reg_array[9]),32);
    bufp->fullIData(oldp+13,(vlSelf->addi__DOT__REG_ARR__DOT__reg_array[10]),32);
    bufp->fullIData(oldp+14,(vlSelf->addi__DOT__REG_ARR__DOT__reg_array[11]),32);
    bufp->fullIData(oldp+15,(vlSelf->addi__DOT__REG_ARR__DOT__reg_array[12]),32);
    bufp->fullIData(oldp+16,(vlSelf->addi__DOT__REG_ARR__DOT__reg_array[13]),32);
    bufp->fullIData(oldp+17,(vlSelf->addi__DOT__REG_ARR__DOT__reg_array[14]),32);
    bufp->fullIData(oldp+18,(vlSelf->addi__DOT__REG_ARR__DOT__reg_array[15]),32);
    bufp->fullIData(oldp+19,(vlSelf->addi__DOT__REG_ARR__DOT__reg_array[16]),32);
    bufp->fullIData(oldp+20,(vlSelf->addi__DOT__REG_ARR__DOT__reg_array[17]),32);
    bufp->fullIData(oldp+21,(vlSelf->addi__DOT__REG_ARR__DOT__reg_array[18]),32);
    bufp->fullIData(oldp+22,(vlSelf->addi__DOT__REG_ARR__DOT__reg_array[19]),32);
    bufp->fullIData(oldp+23,(vlSelf->addi__DOT__REG_ARR__DOT__reg_array[20]),32);
    bufp->fullIData(oldp+24,(vlSelf->addi__DOT__REG_ARR__DOT__reg_array[21]),32);
    bufp->fullIData(oldp+25,(vlSelf->addi__DOT__REG_ARR__DOT__reg_array[22]),32);
    bufp->fullIData(oldp+26,(vlSelf->addi__DOT__REG_ARR__DOT__reg_array[23]),32);
    bufp->fullIData(oldp+27,(vlSelf->addi__DOT__REG_ARR__DOT__reg_array[24]),32);
    bufp->fullIData(oldp+28,(vlSelf->addi__DOT__REG_ARR__DOT__reg_array[25]),32);
    bufp->fullIData(oldp+29,(vlSelf->addi__DOT__REG_ARR__DOT__reg_array[26]),32);
    bufp->fullIData(oldp+30,(vlSelf->addi__DOT__REG_ARR__DOT__reg_array[27]),32);
    bufp->fullIData(oldp+31,(vlSelf->addi__DOT__REG_ARR__DOT__reg_array[28]),32);
    bufp->fullIData(oldp+32,(vlSelf->addi__DOT__REG_ARR__DOT__reg_array[29]),32);
    bufp->fullIData(oldp+33,(vlSelf->addi__DOT__REG_ARR__DOT__reg_array[30]),32);
    bufp->fullIData(oldp+34,(vlSelf->addi__DOT__REG_ARR__DOT__reg_array[31]),32);
    bufp->fullIData(oldp+35,(vlSelf->addi__DOT__REG_ARR__DOT__unnamedblk1__DOT__i),32);
    bufp->fullBit(oldp+36,(vlSelf->clk));
    bufp->fullBit(oldp+37,(vlSelf->rst));
    bufp->fullIData(oldp+38,(vlSelf->RAM_RDATA),32);
    bufp->fullIData(oldp+39,(vlSelf->RAM_RADDR),32);
    bufp->fullIData(oldp+40,(vlSelf->RAM_WDATA),32);
    bufp->fullIData(oldp+41,(vlSelf->RAM_WADDR),32);
    bufp->fullBit(oldp+42,(vlSelf->RAM_WEN));
    bufp->fullCData(oldp+43,((0x1fU & (vlSelf->RAM_RDATA 
                                       >> 0xfU))),5);
    bufp->fullCData(oldp+44,((0x1fU & (vlSelf->RAM_RDATA 
                                       >> 7U))),5);
    bufp->fullIData(oldp+45,(vlSelf->addi__DOT__REG_ARR__DOT__reg_array
                             [(0x1fU & (vlSelf->RAM_RDATA 
                                        >> 0xfU))]),32);
    bufp->fullIData(oldp+46,(((((- (IData)((vlSelf->RAM_RDATA 
                                            >> 0x1fU))) 
                                << 0xcU) | (vlSelf->RAM_RDATA 
                                            >> 0x14U)) 
                              + vlSelf->addi__DOT__REG_ARR__DOT__reg_array
                              [(0x1fU & (vlSelf->RAM_RDATA 
                                         >> 0xfU))])),32);
    bufp->fullIData(oldp+47,((((- (IData)((vlSelf->RAM_RDATA 
                                           >> 0x1fU))) 
                               << 0xcU) | (vlSelf->RAM_RDATA 
                                           >> 0x14U))),32);
    bufp->fullBit(oldp+48,(1U));
    bufp->fullCData(oldp+49,(0U),5);
}
