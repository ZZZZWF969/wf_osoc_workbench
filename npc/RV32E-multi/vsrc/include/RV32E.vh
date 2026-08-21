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



