`define RV32E_WIDTH 32
`define RV32E_REG_NUM 32
`define RV32E_MEMBASE 32'h8000_0000

//INST_CODE
`define EXU_DEFAULT 6'b111_111
`define ADD 6'd0
`define ADDI 6'd1
`define AUIPC 6'd2
`define JAL 6'd3
`define JALR 6'd4
`define LUI 6'd5
`define SW 6'd6
`define LW 6'd7
`define SUB 6'd8
`define SLTIU 6'd9
`define BNE 6'd10
`define LBU 6'd11
`define BGE 6'd12
`define BEQ 6'd13
`define OR 6'd14
`define XOR 6'd15
`define SLTU 6'd16
`define LH 6'd17
`define LHU 6'd18
`define SLLI 6'd19
`define SLL 6'd20
`define SRLI 6'd21
`define SRL 6'd22
`define XORI 6'd23
`define ANDI 6'd24
`define AND 6'd25
`define SRAI 6'd26
`define SRA 6'd27
`define SH 6'd28
`define SLT 6'd29
`define BLT 6'd30
`define BGEU 6'd31
`define SB 6'd32
`define BLTU 6'd33
`define ORI 6'd34
`define LB 6'd35
`define	ECALL 6'd36
`define CSRRS 6'd37
`define CSRRW 6'd38
`define MRET 6'd39
`define EBREAK 6'd40

//ALU_OP
`define ALU_ADD  4'd0
`define ALU_SUB  4'd1
`define ALU_SLT  4'd2
`define ALU_SLTU 4'd3
`define ALU_AND  4'd4
`define ALU_OR   4'd5
`define ALU_XOR  4'd6
`define ALU_SLL  4'd7
`define ALU_SRL  4'd8
`define ALU_SRA  4'd9

//CSR_RD
`define MSTATUS	12'h300
`define MTVEC	12'h305
`define MEPC	12'h341
`define MCAUSE	12'h342

//AXI_RESP（AXI4-Lite响应码；EXOKAY为AXI4独占访问专用，Lite不出现，不定义）
`define AXI_RESP_OKAY	2'b00
`define AXI_RESP_SLVERR	2'b10
`define AXI_RESP_DECERR	2'b11

//XBAR从设备注册表（RV32E_AXI_XBAR按此译码路由；段重叠时低槽位优先，需人工自检不重叠）
//新增设备：登记对应槽位BASE/END并在RV32E_AXI_XBAR.v确认该槽位已连线（按槽0/1模式扩展）
//修改（从设备现实化）：原槽0主存宽区间拆为SRAM(槽0)+DRAM(槽2 default)；原槽1外设桥退役——
//MMIO地址合法化，未命中SRAM/UART的一切地址（含MMIO外设区）default路由槽2走C++访存链；原定义注释保留以便回溯
`define XBAR_DEV0_BASE	32'h8000_0000	//槽0：SRAM（DPI vmem后端，零延迟：握手次拍即回）
`define XBAR_DEV0_END	32'h80FF_FFFF
`define XBAR_DEV1_BASE	32'h1000_0000	//槽1：UART（纯RTL仿真模型，$write字符输出，零延迟）
`define XBAR_DEV1_END	32'h1000_0FFF
//槽2：DEFAULT槽（DRAM+MMIO外设，随机延迟5-25拍）——未命中槽0/槽1的一切地址默认路由至此：
//含0x8100_0000+真DRAM段与0xA000_0000 MMIO外设区（经DPI走C++访存链is_io_device分发），无需登记地址
//修改（CLINT接入）：登记槽3 CLINT寄存器组（msip/mtimecmp/mtime，纯RTL设备，设备内未命中地址回DECERR）
`define XBAR_DEV3_BASE	32'h0200_0000	//槽3：CLINT（中断控制器：msip@0x0000/mtimecmp@0x4000/mtime@0xBFF8）
`define XBAR_DEV3_END	32'h0200_BFFF
//`define XBAR_DEV0_BASE	32'h8000_0000	//原槽0：主存（DPI内存模型）——已拆分为SRAM/DRAM，退役
//`define XBAR_DEV0_END	32'h87FF_FFFF
//`define XBAR_DEV1_BASE	32'hA000_0000	//原槽1：外设桥——MMIO改走default槽C++访存链，退役
//`define XBAR_DEV1_END	32'hB007_52FF
//`define XBAR_DEV2_BASE	32'h..........	//原槽2注册模板——槽2已转为DEFAULT槽（无条件例化），模板作废
//`define XBAR_DEV2_END	32'h..........



