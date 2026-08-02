#include "verilated.h"
#include "verilated_vcd_c.h"
#include "Vaddi.h"
#include <iostream>
#include <cstdlib>
#include <vector>
#include <cstdint>

// 改进的虚拟内存类
class Riscv32VirtualMemory {
public:
    Riscv32VirtualMemory(uint32_t base_addr = 0x80000000, uint32_t size_bytes = 8 * 1024 * 1024)
        : base_address(base_addr), memory_size(size_bytes) {
        phys_memory.resize(size_bytes, 0);
        std::cout << "RISC-V 32 Virtual Memory Initialized: " 
                  << size_bytes / (1024 * 1024) << " MB at base 0x"
                  << std::hex << base_addr << std::dec << "\n";
    }
    
    void write_instruction(uint32_t addr, uint32_t instruction) {
        write32(addr, instruction, true);
    }
    
    void write_instructions(uint32_t start_addr, const std::vector<uint32_t>& instructions) {
        for (size_t i = 0; i < instructions.size(); i++) {
            write_instruction(start_addr + i * 4, instructions[i]);
        }
    }
    
    uint32_t read32(uint32_t addr) {
        // 地址映射：将0x80000000映射到0x0
        uint32_t paddr = addr - base_address;
        
        // 修复边界检查
        if (paddr >= memory_size || paddr + 3 >= memory_size) {
            std::cerr << "Physical read address out of range: 0x" 
                      << std::hex << addr << " (mapped to 0x" << paddr << ")"
                      << std::dec << std::endl;
            exit(1);
        }
        return (static_cast<uint32_t>(phys_memory[paddr]) |
               (static_cast<uint32_t>(phys_memory[paddr+1]) << 8) |
               (static_cast<uint32_t>(phys_memory[paddr+2]) << 16) |
               (static_cast<uint32_t>(phys_memory[paddr+3]) << 24));
    }
    
    void write32(uint32_t addr, uint32_t data, bool wen) {
        if (wen) {
            // 地址映射：将0x80000000映射到0x0
            uint32_t paddr = addr - base_address;
            
            // 修复边界检查
            if (paddr >= memory_size || paddr + 3 >= memory_size) {
                std::cerr << "Physical write address out of range: 0x" 
                          << std::hex << addr << " (mapped to 0x" << paddr << ")"
                          << std::dec << std::endl;
                exit(1);
            }
            phys_memory[paddr]   = static_cast<uint8_t>(data & 0xFF);
            phys_memory[paddr+1] = static_cast<uint8_t>((data >> 8) & 0xFF);
            phys_memory[paddr+2] = static_cast<uint8_t>((data >> 16) & 0xFF);
            phys_memory[paddr+3] = static_cast<uint8_t>((data >> 24) & 0xFF);
        }
    }

private:
    std::vector<uint8_t> phys_memory;
    uint32_t base_address;  // 基地址 (0x80000000)
    uint32_t memory_size;   // 内存大小 (8MB)
};

extern "C" void sim_finish(){
	Verilated::gotFinish(true);
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Verilated::traceEverOn(true);
    VerilatedVcdC* tfp = new VerilatedVcdC;
    
    Vysyx_25060166CPU* top = new Vysyx_25060166CPU;
    top->trace(tfp, 99);
    tfp->open("waveform.vcd");

    // 初始化内存并写入测试指令到0x80000000
    Riscv32VirtualMemory vmem(0x80000000);  // 明确指定基地址
    vmem.write_instructions(0x80000000, {
    // 交替正负操作
    0xFFF00093,  // addi x1, x0, -1
    0x00108113,  // addi x2, x1, 1   -> x2=0
    0xFFF10193,  // addi x3, x2, -1  -> x3=-1
    0x00218213,  // addi x4, x3, 2   -> x4=1
    0xFFD20293,  // addi x5, x4, -3  -> x5=-2
    0x00100073   // EBREAK
    /*// 大数操作
    0x7FF28313,  // addi x6, x5, 2047 -> x6=2045
    0x80030393,  // addi x7, x6, -2048 -> x7=-3
    0x7FF38413,  // addi x8, x7, 2047  -> x8=2044
    0x80040493,  // addi x9, x8, -2048 -> x9=-4*/
    
    });

    // 复位序列（高电平有效）
    top->rst = 1;  // 激活复位
    top->clk = 0;
    top->eval();
    tfp->dump(0);
    
    // 释放复位
    top->clk = 1;
    top->eval();
    tfp->dump(1);
    
    top->clk = 0;
    top->rst = 0;  // 解除复位
    top->eval();
    tfp->dump(2);
    
    // 预取第一条指令
    top->RAM_RDATA = vmem.read32(top->RAM_RADDR);
    tfp->dump(3);

    int instruction_count = 0;
    //const int MAX_INSTRUCTIONS = 10;
    vluint64_t main_time = 4;

    // 仿真主循环
    while (/*instruction_count < MAX_INSTRUCTIONS && */!Verilated::gotFinish()) {
        top->clk = !top->clk;
        
        // 在时钟下降沿处理内存操作
        if (!top->clk) {
            // 处理内存写入
            if (top->RAM_WEN) {
                vmem.write32(top->RAM_WADDR, top->RAM_WDATA, true);
            }
            // 预取下条指令
            top->RAM_RDATA = vmem.read32(top->RAM_RADDR);
        }
        
        top->eval();
        tfp->dump(main_time++);
        
        // 在时钟上升沿计数指令
        if (top->clk) {
            instruction_count++;
            // 计算当前执行指令地址（PC-4）
            uint32_t current_pc = top->RAM_RADDR - 4;
           /* if (top->RAM_RDATA == 0x00100073) {
                std::cout << "simulation end" << std::endl;
                break;
            }*/
            std::cout << "Instruction " << instruction_count 
                      << " executed at 0x" << std::hex << current_pc 
                      << std::dec << std::endl;
        }
    }

    // 仿真结束输出
    std::cout << "\nSimulation finished after " << instruction_count << " instructions.\n";
    std::cout << "Final PC: 0x" << std::hex << top->RAM_RADDR << std::dec << std::endl;

    // 关闭波形文件并清理资源
    tfp->close();
    delete tfp;
    delete top;
    return 0;
}
