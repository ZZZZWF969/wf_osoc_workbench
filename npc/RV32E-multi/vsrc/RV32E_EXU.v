`include "RV32E.vh"

module RV32E_EXU(
	input				clk,
	input				rst,
	//总线：与IDU握手
	input				id_valid,
	output	reg			id_ready,
	//ID_reg输入（IDU锁存输出，执行拍稳定）
	input	[5:0]		id_exu_op,
	input	[`RV32E_WIDTH-1:0]	id_rs1_data,
	input	[`RV32E_WIDTH-1:0]	id_rs2_data,
	input	[`RV32E_WIDTH-1:0]	id_imm,
	input	[`RV32E_WIDTH-1:0]	id_pc,
	input	[`RV32E_WIDTH-1:0]	id_csr_rdata,
	input	[4:0]		id_rwrd,
	input				id_reg_wen,
	input				id_csr_wen,
	input	[11:0]		id_csr_wrd,
	input				id_trap,
	input				id_mret,
	input				id_uncon_jump,
	input				id_mem_ren,		//load指令标志
	//内存读口（组合，执行拍有效）
	input	[`RV32E_WIDTH-1:0]	mem_rdata,
	output				mem_read_en,	//执行拍且为load
	output	reg	[`RV32E_WIDTH-1:0]	mem_addr_comb,	//组合访存地址（喂MEM读口与RAM_ADDR）
	//总线：与WBU握手
	input				ex_ready,
	output	reg			ex_valid,
	//EX_reg锁存输出（去往WBU，写回拍有效）
	output	reg	[`RV32E_WIDTH-1:0]	ex_reg_write_data,
	output	reg [4:0]	ex_rwrd,
	output	reg			ex_reg_wen,
	output	reg	[`RV32E_WIDTH-1:0]	ex_csr_write_data,
	output	reg [11:0]	ex_csr_wrd,
	output	reg			ex_csr_wen,
	output	reg			ex_trap,
	output	reg	[`RV32E_WIDTH-1:0]	ex_pc,		//当前指令地址，trap时写mepc用
	output	reg			ex_jump_sig,
	output	reg	[`RV32E_WIDTH-1:0]	ex_jump_addr,
	output	reg	[`RV32E_WIDTH-1:0]	ex_mem_addr,	//内存写地址
	output	reg	[`RV32E_WIDTH-1:0]	ex_mem_write_data,	//内存写数据(字)
	output	reg [15:0]	ex_mem_half_data,	//内存写数据(半字)
	output	reg [7:0]	ex_mem_byte_data,	//内存写数据(字节)
	output	reg			ex_mem_word_wen,	//按字写
	output	reg			ex_mem_half_wen,	//按半字写
	output	reg			ex_mem_byte_wen		//按字节写
);

	wire [31:0] word_align = 32'hFFFF_FFFC;
	wire [31:0] half_align = 32'hFFFF_FFFE;

	reg         use_pc_src1;
	reg         use_imm_src2;
	reg			use_csr_src2;
	reg         cmp_imm;
	reg  [3:0]  alu_op;

	wire [`RV32E_WIDTH-1:0] src1 = use_pc_src1 ? id_pc : id_rs1_data;
	wire [`RV32E_WIDTH-1:0] src2 = use_csr_src2 ? id_csr_rdata : use_imm_src2 ? id_imm : id_rs2_data;
	wire [`RV32E_WIDTH-1:0] cmp_src2 = cmp_imm ? id_imm : id_rs2_data;

	wire [`RV32E_WIDTH-1:0] alu_result;
	wire                    alu_zero;
	wire                    alu_slt;
	wire                    alu_sltu;

	RV32E_ALU alu(
		.src1     (src1),
		.src2     (src2),
		.cmp_src1 (id_rs1_data),
		.cmp_src2 (cmp_src2),
		.op       (alu_op),
		.result   (alu_result),
		.zero     (alu_zero),
		.slt      (alu_slt),
		.sltu     (alu_sltu)
	);

	//组合执行结果（锁存输入），默认赋值避免latch
	reg					deco_con_jump;
	reg	[`RV32E_WIDTH-1:0]	deco_jump_addr;
	reg	[`RV32E_WIDTH-1:0]	deco_reg_write_data;
	reg	[`RV32E_WIDTH-1:0]	deco_csr_write_data;
	reg	[`RV32E_WIDTH-1:0]	deco_mem_write_data;
	reg		[15:0]	deco_mem_half_data;
	reg		[7:0]	deco_mem_byte_data;
	reg					deco_mem_word_wen;
	reg					deco_mem_half_wen;
	reg					deco_mem_byte_wen;

	always @(*) begin
		mem_addr_comb = 0; deco_con_jump = 0; deco_jump_addr = 0;
		deco_reg_write_data = 0; deco_csr_write_data = 0; deco_mem_write_data = 0;
		deco_mem_half_data = 0; deco_mem_byte_data = 0;
		deco_mem_word_wen = 0; deco_mem_half_wen = 0; deco_mem_byte_wen = 0;
		use_pc_src1 = 0; use_imm_src2 = 0; cmp_imm = 0; use_csr_src2 = 0;
		alu_op = `ALU_ADD;

		case (id_exu_op)
			`ADD: deco_reg_write_data = alu_result;
			`ADDI: begin
				use_imm_src2 = 1;
				deco_reg_write_data = alu_result;
			end
			`AUIPC: begin
				use_pc_src1 = 1; use_imm_src2 = 1;
				deco_reg_write_data = alu_result;
			end
			`LUI: begin
				use_imm_src2 = 1;
				deco_reg_write_data = id_imm;
			end
			`JAL: begin
				use_pc_src1 = 1; use_imm_src2 = 1;
				deco_reg_write_data = id_pc + 4;
				mem_addr_comb = alu_result; deco_jump_addr = alu_result;
			end
			`JALR: begin
				use_imm_src2 = 1;
				mem_addr_comb = alu_result; deco_jump_addr = alu_result;
				deco_reg_write_data = id_pc + 4;
			end
			`SW: begin
				use_imm_src2 = 1;
				mem_addr_comb = alu_result & word_align;
				deco_mem_write_data = id_rs2_data; deco_mem_word_wen = 1;
			end
			`SH: begin
				use_imm_src2 = 1;
				mem_addr_comb = alu_result & half_align;
				deco_mem_half_data = id_rs2_data[15:0]; deco_mem_half_wen = 1;
			end
			`SB: begin
				use_imm_src2 = 1;
				mem_addr_comb = alu_result;
				deco_mem_byte_data = id_rs2_data[7:0]; deco_mem_byte_wen = 1;
			end
			`LW: begin
				use_imm_src2 = 1;
				deco_reg_write_data = mem_rdata;
				mem_addr_comb = alu_result & word_align;
			end
			`LH: begin
				use_imm_src2 = 1;
				mem_addr_comb = alu_result & half_align;
				deco_reg_write_data = {{16{mem_rdata[15]}},mem_rdata[15:0]};
			end
			`LHU: begin
				use_imm_src2 = 1;
				mem_addr_comb = alu_result & half_align;
				deco_reg_write_data = {16'h0000,mem_rdata[15:0]};
			end
			`LB: begin
				use_imm_src2 = 1;
				mem_addr_comb = alu_result;
				deco_reg_write_data = {{24{mem_rdata[7]}},mem_rdata[7:0]};
			end
			`LBU: begin
				use_imm_src2 = 1;
				mem_addr_comb = alu_result;
				deco_reg_write_data = {24'h000000,mem_rdata[7:0]};
			end
			`SUB: begin
				alu_op = `ALU_SUB;
				deco_reg_write_data = alu_result;
			end
			`SLT: begin
				alu_op = `ALU_SLT;
				deco_reg_write_data = alu_result;
			end
			`SLTU: begin
				alu_op = `ALU_SLTU;
				deco_reg_write_data = alu_result;
			end
			`SLTIU: begin
				cmp_imm = 1; alu_op = `ALU_SLTU;
				deco_reg_write_data = alu_result;
			end
			`BLT: begin
				use_pc_src1 = 1; use_imm_src2 = 1;
				if(alu_slt) begin
					deco_con_jump = 1; mem_addr_comb = alu_result; deco_jump_addr = alu_result;
				end
			end
			`BLTU: begin
				use_pc_src1 = 1; use_imm_src2 = 1;
				if(alu_sltu) begin
					deco_con_jump = 1; mem_addr_comb = alu_result; deco_jump_addr = alu_result;
				end
			end
			`BEQ: begin
				use_pc_src1 = 1; use_imm_src2 = 1;
				if(alu_zero) begin
					deco_con_jump = 1; mem_addr_comb = alu_result; deco_jump_addr = alu_result;
				end
			end
			`BNE: begin
				use_pc_src1 = 1; use_imm_src2 = 1;
				if(!alu_zero) begin
					deco_con_jump = 1; mem_addr_comb = alu_result; deco_jump_addr = alu_result;
				end
			end
			`BGE: begin
				use_pc_src1 = 1; use_imm_src2 = 1;
				if(!alu_slt) begin
					deco_con_jump = 1; mem_addr_comb = alu_result; deco_jump_addr = alu_result;
				end
			end
			`BGEU: begin
				use_pc_src1 = 1; use_imm_src2 = 1;
				if(!alu_sltu) begin
					deco_con_jump = 1; mem_addr_comb = alu_result; deco_jump_addr = alu_result;
				end
			end
			`OR: begin
				alu_op = `ALU_OR;
				deco_reg_write_data = alu_result;
			end
			`ORI: begin
				use_imm_src2 = 1; alu_op = `ALU_OR;
				deco_reg_write_data = alu_result;
			end
			`XOR: begin
				alu_op = `ALU_XOR;
				deco_reg_write_data = alu_result;
			end
			`XORI: begin
				use_imm_src2 = 1; alu_op = `ALU_XOR;
				deco_reg_write_data = alu_result;
			end
			`AND: begin
				alu_op = `ALU_AND;
				deco_reg_write_data = alu_result;
			end
			`ANDI: begin
				use_imm_src2 = 1; alu_op = `ALU_AND;
				deco_reg_write_data = alu_result;
			end
			`SLLI: begin
				use_imm_src2 = 1; alu_op = `ALU_SLL;
				deco_reg_write_data = alu_result;
			end
			`SLL: begin
				alu_op = `ALU_SLL;
				deco_reg_write_data = alu_result;
			end
			`SRLI: begin
				use_imm_src2 = 1; alu_op = `ALU_SRL;
				deco_reg_write_data = alu_result;
			end
			`SRL: begin
				alu_op = `ALU_SRL;
				deco_reg_write_data = alu_result;
			end
			`SRA: begin
				alu_op = `ALU_SRA;
				deco_reg_write_data = alu_result;
			end
			`SRAI: begin
				use_imm_src2 = 1; alu_op = `ALU_SRA;
				deco_reg_write_data = alu_result;
			end
			`CSRRW: begin
				deco_reg_write_data = id_csr_rdata;
				deco_csr_write_data = id_rs1_data;
			end
			`CSRRS: begin
				alu_op = `ALU_OR; use_csr_src2 = 1;
				deco_csr_write_data = alu_result;
				deco_reg_write_data = id_csr_rdata;
			end
			`MRET: begin
				deco_jump_addr = id_csr_rdata;
			end
			`ECALL: begin
				deco_jump_addr = id_csr_rdata;
			end

			default: begin end
		endcase
	end

	//执行拍读使能：仅执行握手拍且为load指令时有效一拍，避免IO设备被重复读取
	assign mem_read_en = id_valid & id_ready & id_mem_ren;

	//握手拍：执行结果与写控制一起锁存进EX_reg，下一拍交WBU写回
	always @(posedge clk) begin
		if(rst) begin
			id_ready <= 1;
			ex_valid <= 0;
			ex_reg_write_data <= 0; ex_rwrd <= 0; ex_reg_wen <= 0;
			ex_csr_write_data <= 0; ex_csr_wrd <= 0; ex_csr_wen <= 0;
			ex_trap <= 0; ex_pc <= 0;
			ex_jump_sig <= 0; ex_jump_addr <= 0;
			ex_mem_addr <= 0; ex_mem_write_data <= 0;
			ex_mem_half_data <= 0; ex_mem_byte_data <= 0;
			ex_mem_word_wen <= 0; ex_mem_half_wen <= 0; ex_mem_byte_wen <= 0;
		end else if(id_valid && id_ready) begin
			ex_reg_write_data <= deco_reg_write_data;
			ex_rwrd <= id_rwrd;
			ex_reg_wen <= id_reg_wen;
			ex_csr_write_data <= deco_csr_write_data;
			ex_csr_wrd <= id_csr_wrd;
			ex_csr_wen <= id_csr_wen;
			ex_trap <= id_trap;
			ex_pc <= id_pc;
			ex_jump_sig <= id_uncon_jump | deco_con_jump | id_trap | id_mret;
			ex_jump_addr <= deco_jump_addr;
			ex_mem_addr <= mem_addr_comb;
			ex_mem_write_data <= deco_mem_write_data;
			ex_mem_half_data <= deco_mem_half_data;
			ex_mem_byte_data <= deco_mem_byte_data;
			ex_mem_word_wen <= deco_mem_word_wen;
			ex_mem_half_wen <= deco_mem_half_wen;
			ex_mem_byte_wen <= deco_mem_byte_wen;
			ex_valid <= 1;
			id_ready <= 0;
		end else if(ex_valid && ex_ready) begin
			//WBU已接收EX_reg，恢复空闲
			ex_valid <= 0;
			id_ready <= 1;
		end
	end

	//原EXU为纯组合执行模块，结果直连写回目标；
	//多周期化后执行结果在握手拍锁存进EX_reg，MEM读使能改为执行拍单拍脉冲(mem_read_en)

endmodule
