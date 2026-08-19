`include "RV32E.vh"

module RV32E_EXU(
    input	[`RV32E_WIDTH-1:0]	reg_data_0,
    input	[`RV32E_WIDTH-1:0]	reg_data_1,
	input	[`RV32E_WIDTH-1:0]	pc,
	input	[`RV32E_WIDTH-1:0]	imm,
	input	[`RV32E_WIDTH-1:0]	mem_rdata,
	input	[`RV32E_WIDTH-1:0]	csr_rdata,
    input   [5:0]       op,
	output	reg			con_jump,
	output	reg			half_write,
	output	reg			byte_write,
	output	reg	[15:0]	mem_half_data,
	output	reg	[7:0]	mem_byte,
	output	reg	[`RV32E_WIDTH-1:0]	mem_addr,
    output  reg [`RV32E_WIDTH-1:0]  reg_write_data,
	output	reg	[`RV32E_WIDTH-1:0]	csr_write_data,
	output	reg [`RV32E_WIDTH-1:0]	mem_write_data
);

	wire [31:0] word_align = 32'hFFFF_FFFC;
	wire [31:0] half_align = 32'hFFFF_FFFE;

	reg         use_pc_src1;
	reg         use_imm_src2;
	reg			use_csr_src2;
	reg         cmp_imm;
	reg  [3:0]  alu_op;

	wire [`RV32E_WIDTH-1:0] src1 = use_pc_src1 ? pc : reg_data_0;
	wire [`RV32E_WIDTH-1:0] src2 = use_csr_src2 ? csr_rdata : use_imm_src2 ? imm : reg_data_1;
	wire [`RV32E_WIDTH-1:0] cmp_src2 = cmp_imm ? imm : reg_data_1;

	wire [`RV32E_WIDTH-1:0] alu_result;
	wire                    alu_zero;
	wire                    alu_slt;
	wire                    alu_sltu;

	RV32E_ALU alu(
		.src1     (src1),
		.src2     (src2),
		.cmp_src1 (reg_data_0),
		.cmp_src2 (cmp_src2),
		.op       (alu_op),
		.result   (alu_result),
		.zero     (alu_zero),
		.slt      (alu_slt),
		.sltu     (alu_sltu)
	);

	always @(*) begin

		mem_addr = 0; reg_write_data = 0; mem_write_data = 0; csr_write_data = 0;
		mem_half_data = 0; half_write = 0; byte_write = 0; mem_byte = 0; con_jump = 0;
		use_pc_src1 = 0; use_imm_src2 = 0; cmp_imm = 0; use_csr_src2 = 0;
		alu_op = `ALU_ADD;

		case (op)
			`ADD: reg_write_data = alu_result;
			`ADDI: begin
				use_imm_src2 = 1;
				reg_write_data = alu_result;
			end
			`AUIPC: begin
				use_pc_src1 = 1; use_imm_src2 = 1;
				reg_write_data = alu_result;
			end
			`LUI: begin
				use_imm_src2 = 1;
				reg_write_data = imm;
			end
			`JAL: begin
				use_pc_src1 = 1; use_imm_src2 = 1;
				reg_write_data = pc + 4;
				mem_addr = alu_result;
			end
			`JALR: begin
				use_imm_src2 = 1;
				mem_addr = alu_result;
				reg_write_data = pc + 4;
			end
			`SW: begin
				use_imm_src2 = 1;
				mem_addr = alu_result & word_align;
				mem_write_data = reg_data_1;
			end
			`SH: begin
				use_imm_src2 = 1;
				mem_addr = alu_result & half_align;
				mem_half_data = reg_data_1[15:0];
				half_write = 1;
			end
			`SB: begin
				use_imm_src2 = 1;
				mem_addr = alu_result;
				mem_byte = reg_data_1[7:0];
				byte_write = 1;
			end
			`LW: begin
				use_imm_src2 = 1;
				reg_write_data = mem_rdata;
				mem_addr = alu_result & word_align;
			end
			`LH: begin
				use_imm_src2 = 1;
				mem_addr = alu_result & half_align;
				reg_write_data = {{16{mem_rdata[15]}},mem_rdata[15:0]};
			end
			`LHU: begin
				use_imm_src2 = 1;
				mem_addr = alu_result & half_align;
				reg_write_data = {16'h0000,mem_rdata[15:0]};
			end
			`LB: begin
				use_imm_src2 = 1;
				mem_addr = alu_result;
				reg_write_data = {{24{mem_rdata[7]}},mem_rdata[7:0]};
			end
			`LBU: begin
				use_imm_src2 = 1;
				mem_addr = alu_result;
				reg_write_data = {24'h000000,mem_rdata[7:0]};
			end
			`SUB: begin
				alu_op = `ALU_SUB;
				reg_write_data = alu_result;
			end
			`SLT: begin
				alu_op = `ALU_SLT;
				reg_write_data = alu_result;
			end
			`SLTU: begin
				alu_op = `ALU_SLTU;
				reg_write_data = alu_result;
			end
			`SLTIU: begin
				cmp_imm = 1; alu_op = `ALU_SLTU;
				reg_write_data = alu_result;
			end
			`BLT: begin
				use_pc_src1 = 1; use_imm_src2 = 1;
				if(alu_slt) begin
					con_jump = 1; mem_addr = alu_result;
				end
			end
			`BLTU: begin
				use_pc_src1 = 1; use_imm_src2 = 1;
				if(alu_sltu) begin
					con_jump = 1; mem_addr = alu_result;
				end
			end
			`BEQ: begin
				use_pc_src1 = 1; use_imm_src2 = 1;
				if(alu_zero) begin
					con_jump = 1; mem_addr = alu_result;
				end
			end
			`BNE: begin
				use_pc_src1 = 1; use_imm_src2 = 1;
				if(!alu_zero) begin
					con_jump = 1; mem_addr = alu_result;
				end
			end
			`BGE: begin
				use_pc_src1 = 1; use_imm_src2 = 1;
				if(!alu_slt) begin
					con_jump = 1; mem_addr = alu_result;
				end
			end
			`BGEU: begin
				use_pc_src1 = 1; use_imm_src2 = 1;
				if(!alu_sltu) begin
					con_jump = 1; mem_addr = alu_result;
				end
			end
			`OR: begin
				alu_op = `ALU_OR;
				reg_write_data = alu_result;
			end
			`ORI: begin
				use_imm_src2 = 1; alu_op = `ALU_OR;
				reg_write_data = alu_result;
			end
			`XOR: begin
				alu_op = `ALU_XOR;
				reg_write_data = alu_result;
			end
			`XORI: begin
				use_imm_src2 = 1; alu_op = `ALU_XOR;
				reg_write_data = alu_result;
			end
			`AND: begin
				alu_op = `ALU_AND;
				reg_write_data = alu_result;
			end
			`ANDI: begin
				use_imm_src2 = 1; alu_op = `ALU_AND;
				reg_write_data = alu_result;
			end
			`SLLI: begin
				use_imm_src2 = 1; alu_op = `ALU_SLL;
				reg_write_data = alu_result;
			end
			`SLL: begin
				alu_op = `ALU_SLL;
				reg_write_data = alu_result;
			end
			`SRLI: begin
				use_imm_src2 = 1; alu_op = `ALU_SRL;
				reg_write_data = alu_result;
			end
			`SRL: begin
				alu_op = `ALU_SRL;
				reg_write_data = alu_result;
			end
			`SRA: begin
				alu_op = `ALU_SRA;
				reg_write_data = alu_result;
			end
			`SRAI: begin
				use_imm_src2 = 1; alu_op = `ALU_SRA;
				reg_write_data = alu_result;
			end
			//TODO
			`CSRRW: begin
				reg_write_data = csr_rdata;
				csr_write_data = reg_data_0;
			end
			`CSRRS: begin
				alu_op = `ALU_OR; use_csr_src2 = 1;
				csr_write_data = alu_result;
				reg_write_data = csr_rdata;
			end
			`MRET: begin
				mem_addr = csr_rdata;
			end
			`ECALL: begin
				mem_addr = csr_rdata;
			end

			default: begin end
		endcase
	end

endmodule
