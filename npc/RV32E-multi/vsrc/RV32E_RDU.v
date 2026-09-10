`include "RV32E.vh"

//读取单元：多周期新增的读取周期。
//译码拍结束(ID_reg就绪)后，本模块用ID_reg中的读地址组合驱动寄存器堆/CSR读口，
//在读取拍把读出的操作数与控制信号一起锁存进READ_reg，下一拍交EXU执行。
//无论指令是否需要读数据，都必须经过本周期，不可越过。
module RV32E_RDU(
	input					clk,
	input					rst,
	//总线：与IDU握手
	input					id_valid,
	output	reg				id_ready,
	//ID_reg输入（IDU锁存输出，读取拍稳定）
	input	[5:0]			id_exu_op,
	input	[`RV32E_WIDTH-1:0]	id_imm,
	input	[`RV32E_WIDTH-1:0]	id_pc,
	input	[4:0]			id_rwrd,
	input					id_reg_wen,
	input					id_csr_wen,
	input	[11:0]			id_csr_wrd,
	input					id_trap,
	input					id_mret,
	input					id_uncon_jump,
	input					id_mem_ren,		//load指令
	input	[4:0]			id_rs1_addr,
	input	[4:0]			id_rs2_addr,
	input					id_csr_ren,
	input	[11:0]			id_csr_rrd,
	//寄存器堆读口（组合直出，读取拍有效）
	output		[4:0]		rs1_addr,
	output		[4:0]		rs2_addr,
	input	[`RV32E_WIDTH-1:0]	read_data_1,
	input	[`RV32E_WIDTH-1:0]	read_data_2,
	//CSR读口（组合直出，读取拍读）
	output					csr_ren,
	output	[11:0]			csr_rrd,
	input	[`RV32E_WIDTH-1:0]	csr_rdata,
	//总线：与EXU握手
	input					read_ready,
	output	reg				read_valid,
	//READ_reg锁存输出（去往EXU）
	output	reg	[`RV32E_WIDTH-1:0]	rd_rs1_data,
	output	reg	[`RV32E_WIDTH-1:0]	rd_rs2_data,
	output	reg	[`RV32E_WIDTH-1:0]	rd_imm,
	output	reg	[`RV32E_WIDTH-1:0]	rd_pc,
	output	reg	[`RV32E_WIDTH-1:0]	rd_csr_rdata,
	output	reg [5:0]		rd_exu_op,
	output	reg [4:0]		rd_rwrd,
	output	reg				rd_reg_wen,
	output	reg				rd_csr_wen,
	output	reg [11:0]		rd_csr_wrd,
	output	reg				rd_trap,
	output	reg				rd_mret,
	output	reg				rd_uncon_jump,
	output	reg				rd_mem_ren
);

	//读口直出：地址来自锁存的ID_reg，非读取拍挂旧值组合读无害（不锁存）
	assign rs1_addr = id_rs1_addr;
	assign rs2_addr = id_rs2_addr;
	assign csr_ren = id_csr_ren;
	assign csr_rrd = id_csr_rrd;

	//握手拍：读出的操作数与控制信号一起锁存进READ_reg
	always @(posedge clk) begin
		if(rst) begin
			id_ready <= 1;
			read_valid <= 0;
			rd_rs1_data <= 0; rd_rs2_data <= 0;
			rd_imm <= 0; rd_pc <= 0; rd_csr_rdata <= 0;
			rd_exu_op <= `EXU_DEFAULT; rd_rwrd <= 0;
			rd_reg_wen <= 0; rd_csr_wen <= 0; rd_csr_wrd <= 0;
			rd_trap <= 0; rd_mret <= 0; rd_uncon_jump <= 0;
			rd_mem_ren <= 0;
		end else if(id_valid && id_ready) begin
			rd_rs1_data <= read_data_1;
			rd_rs2_data <= read_data_2;
			rd_csr_rdata <= csr_rdata;
			rd_imm <= id_imm;
			rd_pc <= id_pc;
			rd_exu_op <= id_exu_op;
			rd_rwrd <= id_rwrd;
			rd_reg_wen <= id_reg_wen;
			rd_csr_wen <= id_csr_wen;
			rd_csr_wrd <= id_csr_wrd;
			rd_trap <= id_trap;
			rd_mret <= id_mret;
			rd_uncon_jump <= id_uncon_jump;
			rd_mem_ren <= id_mem_ren;
			read_valid <= 1;
			id_ready <= 0;
		end else if(read_valid && read_ready) begin
			//EXU已接收READ_reg，恢复空闲
			read_valid <= 0;
			id_ready <= 1;
		end
	end

endmodule
