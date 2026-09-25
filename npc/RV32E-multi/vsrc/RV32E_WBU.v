`include "RV32E.vh"

module RV32E_WBU(
	//总线：与上游写回路由握手
	input					ex_valid,
	output					ex_ready,
	//写回数据输入（写回拍内稳定）
	input	[`RV32E_WIDTH-1:0]	ex_reg_write_data,
	input		[4:0]	ex_rwrd,
	input					ex_reg_wen,
	input	[`RV32E_WIDTH-1:0]	ex_csr_write_data,
	input		[11:0]	ex_csr_wrd,
	input					ex_csr_wen,
	input					ex_trap,
	input	[`RV32E_WIDTH-1:0]	ex_pc,
	input					ex_jump_sig,
	input	[`RV32E_WIDTH-1:0]	ex_jump_addr,
	//写回输出（去往寄存器堆/CSR/IFU）
	output					reg_wen,
	output		[4:0]	reg_wrd,
	output	[`RV32E_WIDTH-1:0]	reg_write_data,
	output					csr_wen,
	output		[11:0]	csr_wrd_out,
	output	[`RV32E_WIDTH-1:0]	csr_write_data,
	output					csr_trap_out,
	output	[`RV32E_WIDTH-1:0]	csr_pc,
	output					jump_sig,
	output	[`RV32E_WIDTH-1:0]	jump_addr_out,
	output					finish			//去往IFU：写回完成，允许退役取指
);

	//本模块一拍即完成写回，无内部状态，恒可接收
	assign ex_ready = 1'b1;
	//写使能仅在ex_valid（写回拍）内有效，保证各目标只写入一次
	assign reg_wen = ex_valid & ex_reg_wen;
	assign csr_wen = ex_valid & ex_csr_wen;
	assign csr_trap_out = ex_valid & ex_trap;
	assign finish = ex_valid;

	assign reg_wrd = ex_rwrd;
	assign reg_write_data = ex_reg_write_data;
	assign csr_wrd_out = ex_csr_wrd;
	assign csr_write_data = ex_csr_write_data;
	assign csr_pc = ex_pc;
	assign jump_sig = ex_jump_sig;
	assign jump_addr_out = ex_jump_addr;

endmodule
