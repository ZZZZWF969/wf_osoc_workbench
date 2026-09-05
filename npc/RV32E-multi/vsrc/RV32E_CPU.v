`include "RV32E.vh"

module RV32E_CPU(
    input                   clk,
    input                   rst,
    output  [`RV32E_WIDTH-1:0]  RAM_WDATA,
    output  [`RV32E_WIDTH-1:0]  RAM_ADDR,
	output	[`RV32E_WIDTH-1:0]	PC,
    output                  RAM_WEN,
	output					RAM_REN
);

	//IFU-IDU总线
	wire					if_valid;
	wire					if_ready;
	wire	[`RV32E_WIDTH-1:0]	INST;
	wire	[`RV32E_WIDTH-1:0]	programe_counter;

	//IFU侧：写回完成与跳转信息（来自WBU）
	wire					finish;
	wire					jump_sig;
	wire	[`RV32E_WIDTH-1:0]	jump_addr;

	//IDU-EXU总线（ID_reg内容）
	wire					id_valid;
	wire					id_ready;
	wire	[5:0]			id_exu_op;
	wire	[`RV32E_WIDTH-1:0]	id_rs1_data;
	wire	[`RV32E_WIDTH-1:0]	id_rs2_data;
	wire	[`RV32E_WIDTH-1:0]	id_imm;
	wire	[`RV32E_WIDTH-1:0]	id_pc;
	wire	[`RV32E_WIDTH-1:0]	id_csr_rdata;
	wire	[4:0]			id_rwrd;
	wire					id_reg_wen;
	wire					id_csr_wen;
	wire	[11:0]			id_csr_wrd;
	wire					id_trap;
	wire					id_mret;
	wire					id_uncon_jump;
	wire					id_mem_ren;

	//EXU-WBU总线（EX_reg内容）
	wire					ex_valid;
	wire					ex_ready;
	wire	[`RV32E_WIDTH-1:0]	ex_reg_write_data;
	wire	[4:0]			ex_rwrd;
	wire					ex_reg_wen;
	wire	[`RV32E_WIDTH-1:0]	ex_csr_write_data;
	wire	[11:0]			ex_csr_wrd;
	wire					ex_csr_wen;
	wire					ex_trap;
	wire	[`RV32E_WIDTH-1:0]	ex_pc;
	wire					ex_jump_sig;
	wire	[`RV32E_WIDTH-1:0]	ex_jump_addr;
	wire	[`RV32E_WIDTH-1:0]	ex_mem_addr;
	wire	[`RV32E_WIDTH-1:0]	ex_mem_write_data;
	wire	[15:0]			ex_mem_half_data;
	wire	[7:0]			ex_mem_byte_data;
	wire					ex_mem_word_wen;
	wire					ex_mem_half_wen;
	wire					ex_mem_byte_wen;

	//寄存器堆读口
	wire	[4:0]			rs1_addr;
	wire	[4:0]			rs2_addr;
	wire	[`RV32E_WIDTH-1:0]	read_data_0;
	wire	[`RV32E_WIDTH-1:0]	read_data_1;

	//CSR读口
	wire					csr_ren;
	wire	[11:0]			csr_rrd;
	wire	[`RV32E_WIDTH-1:0]	csr_rdata;

	//内存侧
	wire	[`RV32E_WIDTH-1:0]	mem_addr_comb;	//EXU组合访存地址（执行拍）
	wire					mem_read_en;	//EXU执行拍读使能
	wire	[`RV32E_WIDTH-1:0]	mem_read_data;
	wire					wbu_mem_wen;	//WBU写回拍写使能（总）
	wire					wbu_mem_half_wen;
	wire					wbu_mem_byte_wen;
	wire	[`RV32E_WIDTH-1:0]	wbu_mem_addr;	//WBU锁存的写地址（写回拍）
	wire	[`RV32E_WIDTH-1:0]	wbu_mem_write_data;
	wire	[15:0]			wbu_mem_half_data;
	wire	[7:0]			wbu_mem_byte_data;

	//WBU写回输出（去寄存器堆/CSR）
	wire					reg_wen_wb;
	wire	[4:0]			reg_wrd_wb;
	wire	[`RV32E_WIDTH-1:0]	reg_write_data_wb;
	wire					csr_wen_wb;
	wire	[11:0]			csr_wrd_wb;
	wire	[`RV32E_WIDTH-1:0]	csr_write_data_wb;
	wire					csr_trap_wb;
	wire	[`RV32E_WIDTH-1:0]	csr_pc_wb;

	assign PC = programe_counter;
	assign RAM_ADDR = mem_addr_comb;
	assign RAM_WEN = wbu_mem_wen;
	assign RAM_REN = mem_read_en;
	//内存写地址：写回拍取WBU锁存地址，其余拍（读）取EXU组合地址
	assign RAM_WDATA = wbu_mem_write_data;

	RV32E_IFU IFU(
		.clk			(clk),
		.rst			(rst),
		.finish			(finish),
		.jump_sig		(jump_sig),
		.jump_addr		(jump_addr),
		.if_ready		(if_ready),
		.if_valid		(if_valid),
		.INST			(INST),
		.pc_count		(programe_counter)
	);

	RV32E_IDU IDU(
		.clk			(clk),
		.rst			(rst),
		.if_valid		(if_valid),
		.inst			(INST),
		.pc				(programe_counter),
		.if_ready		(if_ready),
		.id_ready		(id_ready),
		.id_valid		(id_valid),
		.id_exu_op		(id_exu_op),
		.id_rs1_data	(id_rs1_data),
		.id_rs2_data	(id_rs2_data),
		.id_imm			(id_imm),
		.id_pc			(id_pc),
		.id_csr_rdata	(id_csr_rdata),
		.id_rwrd		(id_rwrd),
		.id_reg_wen		(id_reg_wen),
		.id_csr_wen		(id_csr_wen),
		.id_csr_wrd		(id_csr_wrd),
		.id_trap		(id_trap),
		.id_mret		(id_mret),
		.id_uncon_jump	(id_uncon_jump),
		.id_mem_ren		(id_mem_ren),
		.rs1_addr		(rs1_addr),
		.rs2_addr		(rs2_addr),
		.read_data_1	(read_data_0),
		.read_data_2	(read_data_1),
		.csr_ren		(csr_ren),
		.csr_rrd		(csr_rrd),
		.csr_rdata		(csr_rdata)
	);

	RV32E_REG_ARRAY REG_ARR(
		.clk			(clk),
		.rst			(rst),
		.wen			(reg_wen_wb),
		.raddr1			(rs1_addr),
		.raddr2			(rs2_addr),
		.write_rd		(reg_wrd_wb),
		.write_data		(reg_write_data_wb),
		.read_data_1	(read_data_0),
		.read_data_2	(read_data_1)
	);

	RV32E_CSR CSR(
		.clk			(clk),
		.rst			(rst),
		.wen			(csr_wen_wb),
		.ren			(csr_ren),
		.trap			(csr_trap_wb),
		.csr_wrd		(csr_wrd_wb),
		.csr_rrd		(csr_rrd),
		.pc				(csr_pc_wb),
		.write_data		(csr_write_data_wb),
		.read_csr		(csr_rdata)
	);

	RV32E_EXU EXU(
		.clk				(clk),
		.rst				(rst),
		.id_valid			(id_valid),
		.id_ready			(id_ready),
		.id_exu_op			(id_exu_op),
		.id_rs1_data		(id_rs1_data),
		.id_rs2_data		(id_rs2_data),
		.id_imm				(id_imm),
		.id_pc				(id_pc),
		.id_csr_rdata		(id_csr_rdata),
		.id_rwrd			(id_rwrd),
		.id_reg_wen			(id_reg_wen),
		.id_csr_wen			(id_csr_wen),
		.id_csr_wrd			(id_csr_wrd),
		.id_trap			(id_trap),
		.id_mret			(id_mret),
		.id_uncon_jump		(id_uncon_jump),
		.id_mem_ren			(id_mem_ren),
		.mem_rdata			(mem_read_data),
		.mem_read_en		(mem_read_en),
		.mem_addr_comb		(mem_addr_comb),
		.ex_ready			(ex_ready),
		.ex_valid			(ex_valid),
		.ex_reg_write_data	(ex_reg_write_data),
		.ex_rwrd			(ex_rwrd),
		.ex_reg_wen			(ex_reg_wen),
		.ex_csr_write_data	(ex_csr_write_data),
		.ex_csr_wrd			(ex_csr_wrd),
		.ex_csr_wen			(ex_csr_wen),
		.ex_trap			(ex_trap),
		.ex_pc				(ex_pc),
		.ex_jump_sig		(ex_jump_sig),
		.ex_jump_addr		(ex_jump_addr),
		.ex_mem_addr		(ex_mem_addr),
		.ex_mem_write_data	(ex_mem_write_data),
		.ex_mem_half_data	(ex_mem_half_data),
		.ex_mem_byte_data	(ex_mem_byte_data),
		.ex_mem_word_wen	(ex_mem_word_wen),
		.ex_mem_half_wen	(ex_mem_half_wen),
		.ex_mem_byte_wen	(ex_mem_byte_wen)
	);

	RV32E_WBU WBU(
		.ex_valid			(ex_valid),
		.ex_ready			(ex_ready),
		.ex_reg_write_data	(ex_reg_write_data),
		.ex_rwrd			(ex_rwrd),
		.ex_reg_wen			(ex_reg_wen),
		.ex_csr_write_data	(ex_csr_write_data),
		.ex_csr_wrd			(ex_csr_wrd),
		.ex_csr_wen			(ex_csr_wen),
		.ex_trap			(ex_trap),
		.ex_pc				(ex_pc),
		.ex_jump_sig		(ex_jump_sig),
		.ex_jump_addr		(ex_jump_addr),
		.ex_mem_addr		(ex_mem_addr),
		.ex_mem_write_data	(ex_mem_write_data),
		.ex_mem_half_data	(ex_mem_half_data),
		.ex_mem_byte_data	(ex_mem_byte_data),
		.ex_mem_word_wen	(ex_mem_word_wen),
		.ex_mem_half_wen	(ex_mem_half_wen),
		.ex_mem_byte_wen	(ex_mem_byte_wen),
		.reg_wen			(reg_wen_wb),
		.reg_wrd			(reg_wrd_wb),
		.reg_write_data		(reg_write_data_wb),
		.csr_wen			(csr_wen_wb),
		.csr_wrd_out		(csr_wrd_wb),
		.csr_write_data		(csr_write_data_wb),
		.csr_trap_out		(csr_trap_wb),
		.csr_pc				(csr_pc_wb),
		.mem_wen			(wbu_mem_wen),
		.mem_half_wen		(wbu_mem_half_wen),
		.mem_byte_wen		(wbu_mem_byte_wen),
		.mem_addr_out		(wbu_mem_addr),
		.mem_write_data		(wbu_mem_write_data),
		.mem_half_data		(wbu_mem_half_data),
		.mem_byte_data		(wbu_mem_byte_data),
		.jump_sig			(jump_sig),
		.jump_addr_out		(jump_addr),
		.finish				(finish)
	);

	RV32E_MEM MEM_IF(
		.clk			(clk),
		.write_en		(wbu_mem_wen),
		.read_en		(mem_read_en),
		.half_write		(wbu_mem_half_wen),
		.byte_write		(wbu_mem_byte_wen),
		.address		(wbu_mem_wen ? wbu_mem_addr : mem_addr_comb),
		.write_data		(wbu_mem_write_data),
		.half_data		(wbu_mem_half_data),
		.byte_data		(wbu_mem_byte_data),
		.read_data		(mem_read_data)
	);

	//原顶层为组合jump_sig拼接+译码直连执行/写回的单周期结构，
	//重构后IF/ID/EX/WB四阶段一拍一阶段串行执行，模块间以valid/ready总线握手

endmodule
