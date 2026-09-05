`include "RV32E.vh"

module RV32E_IDU(
	input					clk,
	input					rst,
	//总线：与IFU握手（inst为IFU的IR输出，组合有效）
	input					if_valid,
	input	[`RV32E_WIDTH-1:0]	inst,
	input	[`RV32E_WIDTH-1:0]	pc,			//ir_pc，当前指令地址
	output	reg				if_ready,
	//总线：与EXU握手
	input					id_ready,
	output	reg				id_valid,
	//ID_reg锁存输出（去往EXU）
	output	reg [5:0]		id_exu_op,
	output	reg	[`RV32E_WIDTH-1:0]	id_rs1_data,
	output	reg	[`RV32E_WIDTH-1:0]	id_rs2_data,
	output	reg	[`RV32E_WIDTH-1:0]	id_imm,
	output	reg	[`RV32E_WIDTH-1:0]	id_pc,
	output	reg	[`RV32E_WIDTH-1:0]	id_csr_rdata,
	output	reg [4:0]		id_rwrd,
	output	reg				id_reg_wen,
	output	reg				id_csr_wen,
	output	reg [11:0]		id_csr_wrd,
	output	reg				id_trap,
	output	reg				id_mret,
	output	reg				id_uncon_jump,
	output	reg				id_mem_ren,		//load指令
	//寄存器堆读口（组合直出，译码拍有效）
	output		[4:0]	rs1_addr,
	output		[4:0]	rs2_addr,
	input	[`RV32E_WIDTH-1:0]	read_data_1,
	input	[`RV32E_WIDTH-1:0]	read_data_2,
	//CSR读口（组合直出，译码拍读）
	output	reg				csr_ren,
	output	reg [11:0]		csr_rrd,
	input	[`RV32E_WIDTH-1:0]	csr_rdata
);

	import "DPI-C" function void sim_finish();

	//译码组合结果（供锁存），默认赋值避免latch
	reg [5:0]			deco_exu_op;
	reg	[`RV32E_WIDTH-1:0]	deco_imm;
	reg					deco_reg_wen;
	reg					deco_csr_wen;
	reg [11:0]			deco_csr_wrd;
	reg					deco_csr_ren;
	reg [11:0]			deco_csr_rrd;
	reg					deco_trap;
	reg					deco_mret;
	reg					deco_uncon_jump;
	reg					deco_mem_ren;
	reg					deco_ebreak;

	assign rs1_addr = inst[19:15];
	assign rs2_addr = inst[24:20];

	wire [2:0]  funct3;
	wire [6:0]  funct7;
	wire [6:0]  opcode;

	assign funct3 = inst[14:12];
	assign funct7 = inst[31:25];
	assign opcode = inst[6:0];

	wire [`RV32E_WIDTH-1:0]   immI;
	wire [`RV32E_WIDTH-1:0]   immJ;
	wire [`RV32E_WIDTH-1:0]   immU;
	wire [`RV32E_WIDTH-1:0]   immS;
	wire [`RV32E_WIDTH-1:0]   immB;

	assign immI = {{20{inst[31]}},{inst[31:20]}};	//I立即数
	assign immJ = {{12{inst[31]}},{inst[19:12]},{inst[20]},{inst[30:21]},1'b0};	//J立即数
	assign immU = {inst[31:12],12'b0};				//U立即数
	assign immS = {{20{inst[31]}},inst[31:25],inst[11:7]};	//S立即数
	assign immB = {{20{inst[31]}},inst[7],inst[30:25],inst[11:8],1'b0};	//B立即数

	always @(*) begin
		deco_exu_op = `EXU_DEFAULT; deco_imm = 0; deco_reg_wen = 0;
		deco_csr_wen = 0; deco_csr_wrd = 0; deco_csr_ren = 0; deco_csr_rrd = 0;
		deco_trap = 0; deco_mret = 0; deco_uncon_jump = 0;
		deco_mem_ren = 0; deco_ebreak = 0;

		//I_TYPE
		if(opcode == 7'b0010011) begin	
			deco_imm = immI;	deco_reg_wen = 1;
			case (funct3)
				3'b000: begin
					deco_exu_op = `ADDI; 
				end 
				3'b011: begin
					deco_exu_op = `SLTIU;
				end
				3'b001: begin
					if(immI[5] == 0) begin
						deco_exu_op = `SLLI;
					end else begin
						$display("invalid slli, NPC choices to skip it");
						deco_reg_wen = 0;
					end
				end
				3'b100: begin
					deco_exu_op = `XORI;
				end
				3'b101: begin
					if(immI[5] == 0) begin
						deco_reg_wen = 1; deco_exu_op = funct7[5]? `SRAI : `SRLI;
					end else begin
						$display("invalid srli/srai, NPC choices to skip it");
						deco_reg_wen = 0;
					end
				end
				3'b110: begin
					deco_exu_op = `ORI;
				end
				3'b111: begin
					deco_exu_op = `ANDI;
				end
				default: begin end
			endcase
		end
		if(opcode == 7'b1100111) begin
			deco_imm = immI; deco_reg_wen = 1;
			case (funct3)
				3'b000: begin
					deco_exu_op = `JALR; deco_uncon_jump = 1;
				end 
				default: begin end
			endcase
		end
		if(opcode == 7'b0000011) begin
			deco_imm = immI;
			case (funct3)
				3'b000: begin
					deco_mem_ren = 1; deco_exu_op = `LB; deco_reg_wen = 1;
				end
				3'b010: begin
					deco_mem_ren = 1; deco_exu_op = `LW; deco_reg_wen = 1;
				end
				3'b100: begin
					deco_reg_wen = 1; deco_exu_op = `LBU; deco_mem_ren = 1;
				end
				3'b001: begin
					deco_exu_op = `LH; deco_reg_wen = 1; deco_mem_ren = 1;
				end
				3'b101: begin
					deco_exu_op = `LHU; deco_reg_wen = 1; deco_mem_ren = 1;
				end
				default: begin end
			endcase
		end

		//CSR INST
		if(opcode == 7'b1110011) begin
			if(inst == 32'h0010_0073) begin
				deco_ebreak = 1;
			end else if(inst == 32'h3020_0073) begin
				deco_exu_op = `MRET; deco_mret = 1;
				deco_csr_rrd = `MEPC; deco_csr_ren = 1;
			end else if(inst == 32'h0000_0073) begin
				deco_exu_op = `ECALL; deco_trap = 1; deco_csr_rrd = `MTVEC; deco_csr_ren = 1;
			end else if(funct3 == 3'b001) begin
				deco_exu_op = `CSRRW; deco_csr_wrd = inst[31:20]; deco_csr_rrd = inst[31:20];
				deco_csr_wen = 1; deco_reg_wen = 1; deco_csr_ren = 1;
			end else if(funct3 == 3'b010) begin
				deco_exu_op = `CSRRS; deco_csr_wrd = inst[31:20]; deco_csr_rrd = inst[31:20];
				deco_csr_wen = 1; deco_reg_wen = 1; deco_csr_ren = 1;
			end
		end

		//R_TYPE
		if(opcode == 7'b0110011) begin
			if(funct7 == 7'b0100000 && funct3 == 3'b000) begin
				deco_exu_op = `SUB; deco_reg_wen = 1;
			end else if(funct7 == 7'b0100000 && funct3 == 3'b101) begin
				deco_exu_op = `SRA; deco_reg_wen = 1;
			end
		end
		if(opcode == 7'b0110011) begin
			if(funct7 == 7'b000_0000 && funct3 == 3'b000) begin
				deco_exu_op = `ADD; deco_reg_wen = 1;
			end else if(funct7 == 7'b0000000 && funct3 == 3'b110) begin
				deco_exu_op = `OR; deco_reg_wen = 1;
			end else if(funct7 == 7'b0000000 && funct3 == 3'b100) begin
				deco_exu_op = `XOR; deco_reg_wen = 1;
			end else if(funct7 == 7'b0000000 && funct3 == 3'b011) begin
				deco_reg_wen = 1; deco_exu_op = `SLTU;
			end else if(funct7 == 7'b0000000 && funct3 == 3'b001) begin
				deco_reg_wen = 1; deco_exu_op = `SLL;
			end else if(funct7 == 7'b0000000 && funct3 == 3'b101) begin
				deco_reg_wen = 1; deco_exu_op = `SRL;
			end else if(funct7 == 7'b0000000 && funct3 == 3'b111) begin
				deco_exu_op = `AND; deco_reg_wen = 1;
			end else if(funct7 == 7'b0000000 && funct3 == 3'b010) begin
				deco_reg_wen = 1; deco_exu_op = `SLT;
			end
		end

		//U_TYPE
		if(opcode == 7'b0010111) begin
			deco_imm = immU; deco_exu_op = `AUIPC; deco_reg_wen = 1;
		end
		if(opcode == 7'b0110111) begin
			deco_imm = immU; deco_reg_wen = 1; deco_exu_op = `LUI;
		end

		//J_TYPE
		if(opcode == 7'b1101111) begin
			deco_reg_wen = 1;
			deco_imm = immJ; deco_uncon_jump = 1; deco_exu_op = `JAL;
		end

		//S_TYPE
		if(opcode == 7'b0100011) begin
			deco_imm = immS;
			case (funct3)
				3'b010: begin
					deco_exu_op = `SW;
				end 
				3'b001: begin
					deco_exu_op = `SH;
				end
				3'b000: begin
					deco_exu_op = `SB;
				end
				default: begin end
			endcase
		end

		//B_TYPE
		if(opcode == 7'b1100011) begin
			deco_imm = immB;
			case (funct3)
				3'b000: begin
					deco_exu_op = `BEQ;
				end
				3'b001: begin
					deco_exu_op = `BNE;
				end 
				3'b100: begin
					deco_exu_op = `BLT;
				end
				3'b101: begin
					deco_exu_op = `BGE;
				end
				3'b110: begin
					deco_exu_op = `BLTU;
				end
				3'b111: begin
					deco_exu_op = `BGEU;
				end
				default: begin end
			endcase
		end

		//CSR读口直出：与译码结果同源
		csr_ren = deco_csr_ren;
		csr_rrd = deco_csr_rrd;
	end

	//握手拍：if_valid与if_ready同时有效时，组合译码结果与读出的寄存器/CSR数据一起锁存进ID_reg
	always @(posedge clk) begin
		if(rst) begin
			if_ready <= 1;
			id_valid <= 0;
			id_exu_op <= `EXU_DEFAULT;
			id_rs1_data <= 0; id_rs2_data <= 0;
			id_imm <= 0; id_pc <= 0; id_csr_rdata <= 0;
			id_rwrd <= 0;
			id_reg_wen <= 0; id_csr_wen <= 0; id_csr_wrd <= 0;
			id_trap <= 0; id_mret <= 0; id_uncon_jump <= 0;
			id_mem_ren <= 0;
		end else if(if_valid && if_ready) begin
			if(deco_ebreak) begin
				sim_finish();
			end
			id_exu_op <= deco_exu_op;
			id_rs1_data <= read_data_1;
			id_rs2_data <= read_data_2;
			id_imm <= deco_imm;
			id_pc <= pc;
			id_csr_rdata <= csr_rdata;
			id_rwrd <= inst[11:7];
			id_reg_wen <= deco_reg_wen;
			id_csr_wen <= deco_csr_wen;
			id_csr_wrd <= deco_csr_wrd;
			id_trap <= deco_trap;
			id_mret <= deco_mret;
			id_uncon_jump <= deco_uncon_jump;
			id_mem_ren <= deco_mem_ren;
			id_valid <= 1;
			if_ready <= 0;
		end else if(id_valid && id_ready) begin
			//EXU已接收ID_reg，恢复空闲
			id_valid <= 0;
			if_ready <= 1;
		end
	end

	//原译码输出直连各执行/写回模块，译码与执行处于同一周期；
	//多周期化后译码结果统一在握手拍锁存进ID_reg，下一拍交EXU执行，
	//sim_finish(ebreak)亦由组合调用改为握手拍时序调用一次

endmodule
