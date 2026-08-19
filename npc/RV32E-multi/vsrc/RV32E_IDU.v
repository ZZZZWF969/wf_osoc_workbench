`include "RV32E.vh"

module RV32E_IDU(
	input	[`RV32E_WIDTH-1:0]	inst,
	output	reg				mem_wen,
	output	reg				mem_ren,
	output	reg				uncon_jump,
	output	reg				trap,
	output	reg				mret,
	output	reg				csr_wen,
	output	reg				csr_ren,
	output	reg		[11:0]	csr_wrd,
	output	reg		[11:0]	csr_rrd,
	output			[4:0]	rs1_addr,
	output			[4:0]	rs2_addr,
	output	reg				reg_wen,
	output			[4:0]	rwrd,
	output	reg	[`RV32E_WIDTH-1:0]	imm,
	output	reg [5:0]		EXU_OP			//magic number
);

	wire [`RV32E_WIDTH-1:0]   immI;
	wire [`RV32E_WIDTH-1:0]   immJ;
	wire [`RV32E_WIDTH-1:0]   immU;
	wire [`RV32E_WIDTH-1:0]   immS;
//	wire [`RV32E_WIDTH-1:0]   immR;
	wire [`RV32E_WIDTH-1:0]   immB;
    wire [2:0]          funct3;
	wire [6:0]			funct7;
    wire [6:0]          opcode;

    assign funct3 = inst[14:12];
	assign funct7 = inst[31:25];
    assign rs1_addr  = inst[19:15];
    assign rs2_addr  = inst[24:20];
    assign rwrd   = inst[11: 7];
    assign opcode = inst[6:0];

    assign immI = {{20{inst[31]}},{inst[31:20]}};	//I立即数
	assign immJ = {{12{inst[31]}},{inst[19:12]},{inst[20]},{inst[30:21]},1'b0};	//J立即数
	assign immU = {inst[31:12],12'b0};				//U立即数
	assign immS = {{20{inst[31]}},inst[31:25],inst[11:7]};	//S立即数
	assign immB = {{20{inst[31]}},inst[7],inst[30:25],inst[11:8],1'b0};	//B立即数


	import "DPI-C" function void sim_finish();

	always @(*) begin

		mem_wen = 0; mem_ren = 0; reg_wen = 0;			//default assignment to avoide latch
		EXU_OP = `EXU_DEFAULT; imm = 0;	uncon_jump = 0; trap = 0; mret = 0;
		csr_wen = 0; csr_ren = 0; csr_wrd = 0; csr_rrd = 0;

		// if(inst == 32'h0010_0073) begin
		// 	sim_finish();
		// end
		// if(inst == 32'h3020_0073) begin
		// 	EXU_OP = `MRET; mret = 1;
		// 	csr_rrd = `MEPC;
		// end

		//I_TYPE
		if(opcode == 7'b0010011) begin	
			imm = immI;	reg_wen = 1;
			case (funct3)
				3'b000: begin
					EXU_OP = `ADDI; 
				end 
				3'b011: begin
					EXU_OP = `SLTIU;
				end
				3'b001: begin
					if(immI[5] == 0) begin
						EXU_OP = `SLLI;
					end else begin
						$display("invalid slli, NPC choices to skip it");
						reg_wen = 0;
					end
				end
				3'b100: begin
					EXU_OP = `XORI;
				end
				3'b101: begin
					if(immI[5] == 0) begin
						reg_wen = 1; EXU_OP = funct7[5]? `SRAI : `SRLI;
					end else begin
						$display("invalid srli/srai, NPC choices to skip it");
						reg_wen = 0;
					end
				end
				3'b110: begin
					EXU_OP = `ORI;
				end
				3'b111: begin
					EXU_OP = `ANDI;
				end
				default: begin end
			endcase
		end
		if(opcode == 7'b1100111) begin
			imm = immI; reg_wen = 1;
			case (funct3)
				3'b000: begin
					EXU_OP = `JALR; uncon_jump = 1;
				end 
				default: begin end
			endcase
		end
		if(opcode == 7'b0000011) begin
			imm = immI;
			case (funct3)
				3'b000: begin
					mem_ren = 1; EXU_OP = `LB; reg_wen = 1;
				end
				3'b010: begin
					mem_ren = 1; EXU_OP = `LW; reg_wen = 1;
				end
				3'b100: begin
					reg_wen = 1; EXU_OP = `LBU; mem_ren = 1;
				end
				3'b001: begin
					EXU_OP = `LH; reg_wen = 1; mem_ren = 1;
				end
				3'b101: begin
					EXU_OP = `LHU; reg_wen = 1; mem_ren = 1;
				end
				default: begin end
			endcase
		end

		//CSR INST
		if(opcode == 7'b1110011) begin
			if(inst == 32'h0010_0073) begin
				sim_finish();
			end else if(inst == 32'h3020_0073) begin
				EXU_OP = `MRET; mret = 1;
				csr_rrd = `MEPC; csr_ren = 1;
			end else if(inst == 32'h0000_0073) begin
				EXU_OP = `ECALL; trap = 1; csr_rrd = `MTVEC; csr_ren = 1;
			end else if(funct3 == 3'b001) begin
				EXU_OP = `CSRRW; csr_wrd = inst[31:20]; csr_rrd = inst[31:20];
				csr_wen = 1; reg_wen = 1; csr_ren = 1;
			end else if(funct3 == 3'b010) begin
				EXU_OP = `CSRRS; csr_wrd = inst[31:20]; csr_rrd = inst[31:20];
				csr_wen = 1; reg_wen = 1; csr_ren = 1;
			end
			// case (funct3)
			// 	3'b000: begin
			// 		EXU_OP = `ECALL; trap = 1;
			// 	end 
			// 	3'b001: begin
			// 		EXU_OP = `CSRRW; csr_wrd = immI; csr_rrd = immI;
			// 		csr_wen = 1; reg_wen = 1;
			// 	end
			// 	3'b010: begin
			// 		EXU_OP = `CSRRS; csr_wrd = immI; csr_rrd = immI;
			// 		csr_wen = 1; reg_wen = 1;
			// 	end
			// 	default: begin end
			// endcase
		end

		//R_TYPE
		if(opcode == 7'b0110011) begin
			if(funct7 == 7'b0100000 && funct3 == 3'b000) begin
				EXU_OP = `SUB; reg_wen = 1;
			end else if(funct7 == 7'b0100000 && funct3 == 3'b101) begin
				EXU_OP = `SRA; reg_wen = 1;
			end
		end
		if(opcode == 7'b0110011) begin
			if(funct7 == 7'b000_0000 && funct3 == 3'b000) begin
				EXU_OP = `ADD; reg_wen = 1;
			end else if(funct7 == 7'b0000000 && funct3 == 3'b110) begin
				EXU_OP = `OR; reg_wen = 1;
			end else if(funct7 == 7'b0000000 && funct3 == 3'b100) begin
				EXU_OP = `XOR; reg_wen = 1;
			end else if(funct7 == 7'b0000000 && funct3 == 3'b011) begin
				reg_wen = 1; EXU_OP = `SLTU;
			end else if(funct7 == 7'b0000000 && funct3 == 3'b001) begin
				reg_wen = 1; EXU_OP = `SLL;
			end else if(funct7 == 7'b0000000 && funct3 == 3'b101) begin
				reg_wen = 1; EXU_OP = `SRL;
			end else if(funct7 == 7'b0000000 && funct3 == 3'b111) begin
				EXU_OP = `AND; reg_wen = 1;
			end else if(funct7 == 7'b0000000 && funct3 == 3'b010) begin
				reg_wen = 1; EXU_OP = `SLT;
			end
		end

		//U_TYPE
		if(opcode == 7'b0010111) begin
			imm = immU; EXU_OP = `AUIPC; reg_wen = 1;
		end
		if(opcode == 7'b0110111) begin
			imm = immU; reg_wen = 1; EXU_OP = `LUI;
		end

		//J_TYPE
		if(opcode == 7'b1101111) begin
			reg_wen = 1;
			imm = immJ; uncon_jump = 1; EXU_OP = `JAL;
		end

		//S_TYPE
		if(opcode == 7'b0100011) begin
			imm = immS;
			case (funct3)
				3'b010: begin
					EXU_OP = `SW; mem_wen = 1;
				end 
				3'b001: begin
					mem_wen = 1; EXU_OP = `SH;
				end
				3'b000: begin
					mem_wen = 1; EXU_OP = `SB;
				end
				default: begin end
			endcase
		end

		//B_TYPE
		if(opcode == 7'b1100011) begin
			imm = immB;
			case (funct3)
				3'b000: begin
					EXU_OP = `BEQ;
				end
				3'b001: begin
					EXU_OP = `BNE;
				end 
				3'b100: begin
					EXU_OP = `BLT;
				end
				3'b101: begin
					EXU_OP = `BGE;
				end
				3'b110: begin
					EXU_OP = `BLTU;
				end
				3'b111: begin
					EXU_OP = `BGEU;
				end
				default begin end
			endcase
		end

	end

endmodule
