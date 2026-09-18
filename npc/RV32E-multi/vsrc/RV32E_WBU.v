`include "RV32E.vh"

//写回单元：输入valid有效的写回拍内组合驱动寄存器堆/CSR的写信号与跳转信息，
//拍末由各目标模块posedge完成提交，并发finish通知IFU。
//访存（读/写内存）已移交RV32E_DSRAM在请求拍执行，本模块不再承担访存职责。
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
//	//修改（访存SRAM化）：内存写移至DSRAM请求拍执行，以下访存输入端口不再使用，注释保留以便回溯
//	input	[`RV32E_WIDTH-1:0]	ex_mem_addr,
//	input	[`RV32E_WIDTH-1:0]	ex_mem_write_data,
//	input		[15:0]	ex_mem_half_data,
//	input		[7:0]	ex_mem_byte_data,
//	input					ex_mem_word_wen,
//	input					ex_mem_half_wen,
//	input					ex_mem_byte_wen,
	//写回输出（去往寄存器堆/CSR/IFU）
	output					reg_wen,
	output		[4:0]	reg_wrd,
	output	[`RV32E_WIDTH-1:0]	reg_write_data,
	output					csr_wen,
	output		[11:0]	csr_wrd_out,
	output	[`RV32E_WIDTH-1:0]	csr_write_data,
	output					csr_trap_out,
	output	[`RV32E_WIDTH-1:0]	csr_pc,
//	//修改（访存SRAM化）：访存输出端口不再使用，注释保留以便回溯
//	output					mem_wen,		//总写使能（字/半字/字节任一）
//	output					mem_half_wen,
//	output					mem_byte_wen,
//	output	[`RV32E_WIDTH-1:0]	mem_addr_out,
//	output	[`RV32E_WIDTH-1:0]	mem_write_data,
//	output		[15:0]	mem_half_data,
//	output		[7:0]	mem_byte_data,
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
//	//修改（访存SRAM化）：内存写使能移交DSRAM请求拍，注释保留以便回溯
//	assign mem_wen = ex_valid & (ex_mem_word_wen | ex_mem_half_wen | ex_mem_byte_wen);
//	assign mem_half_wen = ex_valid & ex_mem_half_wen;
//	assign mem_byte_wen = ex_valid & ex_mem_byte_wen;
	assign finish = ex_valid;

	assign reg_wrd = ex_rwrd;
	assign reg_write_data = ex_reg_write_data;
	assign csr_wrd_out = ex_csr_wrd;
	assign csr_write_data = ex_csr_write_data;
	assign csr_pc = ex_pc;
//	//修改（访存SRAM化）：访存输出移交DSRAM请求拍，注释保留以便回溯
//	assign mem_addr_out = ex_mem_addr;
//	assign mem_write_data = ex_mem_write_data;
//	assign mem_half_data = ex_mem_half_data;
//	assign mem_byte_data = ex_mem_byte_data;
	assign jump_sig = ex_jump_sig;
	assign jump_addr_out = ex_jump_addr;

	//原WBU为"执行结果锁存一拍再写回"的结构（内部busy/finish状态机），
	//重构后执行结果由EXU的EX_reg锁存，WBU退化为写回拍组合执行器，
	//锁存职责转移至EXU，见git f9a994e前的RV32E_WBU.v

endmodule
