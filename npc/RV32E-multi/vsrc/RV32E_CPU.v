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

	//IDU-RDU总线（ID_reg内容：控制信号+读地址）
	wire					id_valid;
	wire					id_ready;
	wire	[5:0]			id_exu_op;
	wire	[`RV32E_WIDTH-1:0]	id_imm;
	wire	[`RV32E_WIDTH-1:0]	id_pc;
	wire	[4:0]			id_rwrd;
	wire					id_reg_wen;
	wire					id_csr_wen;
	wire	[11:0]			id_csr_wrd;
	wire					id_trap;
	wire					id_mret;
	wire					id_uncon_jump;
	wire					id_mem_ren;
	wire	[4:0]			id_rs1_addr;
	wire	[4:0]			id_rs2_addr;
	wire					id_csr_ren;
	wire	[11:0]			id_csr_rrd;

	//RDU-EXU总线（READ_reg内容：操作数+控制信号）
	wire					read_valid;
	wire					read_ready;
	wire	[`RV32E_WIDTH-1:0]	rd_rs1_data;
	wire	[`RV32E_WIDTH-1:0]	rd_rs2_data;
	wire	[`RV32E_WIDTH-1:0]	rd_imm;
	wire	[`RV32E_WIDTH-1:0]	rd_pc;
	wire	[`RV32E_WIDTH-1:0]	rd_csr_rdata;
	wire	[5:0]			rd_exu_op;
	wire	[4:0]			rd_rwrd;
	wire					rd_reg_wen;
	wire					rd_csr_wen;
	wire	[11:0]			rd_csr_wrd;
	wire					rd_trap;
	wire					rd_mret;
	wire					rd_uncon_jump;
	wire					rd_mem_ren;

	//EXU-WBU总线（EX_reg内容）
	wire					ex_valid;
	wire					ex_mem_req;	//访存请求标志（load或store）
	wire					ex_mem_ren;	//load标志
	wire	[5:0]			ex_exu_op;	//锁存操作码（load格式化用）
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

	//寄存器堆读口（读取单元直出）
	wire	[4:0]			rs1_addr;
	wire	[4:0]			rs2_addr;
	wire	[`RV32E_WIDTH-1:0]	read_data_0;
	wire	[`RV32E_WIDTH-1:0]	read_data_1;

	//CSR读口（读取单元直出）
	wire					csr_ren;
	wire	[11:0]			csr_rrd;
	wire	[`RV32E_WIDTH-1:0]	csr_rdata;

	//访存请求总线（EXU→DSRAM，顶层路由：仅访存指令发请求）
	wire					dsram_req_valid;
	wire					dsram_req_ready;
	wire	[`RV32E_WIDTH-1:0]	dsram_req_addr;
	wire					dsram_req_ren;
	wire					dsram_req_wen;
	wire		[1:0]		dsram_req_wsize;	//写宽度：00字节 01半字 10字
	wire	[`RV32E_WIDTH-1:0]	dsram_req_wdata;
	//访存完成总线（DSRAM→WBU）
	wire					mem_done_valid;
	wire					mem_done_ready;
	wire	[`RV32E_WIDTH-1:0]	mem_done_rdata;
	//写回输入路由：访存指令等DSRAM完成，非访存指令旁路EX_reg
	wire					wbu_bypass_valid;
	wire					wbu_in_valid;	//WBU最终输入valid（csrc退休沿观察点）
	wire					wbu_ex_ready;
	wire					ex_ready_mux;
	wire	[`RV32E_WIDTH-1:0]	wbu_reg_data;
	reg		[`RV32E_WIDTH-1:0]	load_fmt_data;	//load读数据按op格式化

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
	//访存请求路由：访存指令在EX_reg有效拍向DSRAM发请求（请求拍），下一拍完成
	assign dsram_req_valid = ex_valid & ex_mem_req;
	assign dsram_req_addr  = ex_mem_addr;
	assign dsram_req_ren   = ex_mem_ren;
	assign dsram_req_wen   = ex_mem_word_wen | ex_mem_half_wen | ex_mem_byte_wen;
	assign dsram_req_wsize = ex_mem_byte_wen ? 2'b00 : ex_mem_half_wen ? 2'b01 : 2'b10;
	assign dsram_req_wdata = ex_mem_byte_wen ? {24'b0, ex_mem_byte_data} :
	                         ex_mem_half_wen ? {16'b0, ex_mem_half_data} : ex_mem_write_data;
	//写回输入路由：访存指令用DSRAM完成总线，非访存指令旁路EX_reg
	assign wbu_bypass_valid = ex_valid & ~ex_mem_req;
	assign wbu_in_valid     = ex_mem_req ? mem_done_valid : wbu_bypass_valid;
	assign wbu_reg_data     = ex_mem_ren ? load_fmt_data : ex_reg_write_data;
	assign mem_done_ready   = 1'b1;		//WBU写回拍恒可接收
	//EXU下游就绪：访存看DSRAM请求就绪，非访存看WBU
	assign ex_ready_mux     = ex_mem_req ? dsram_req_ready : wbu_ex_ready;

	//RAM观察端口（供csrc MMIO判断/踪迹）：请求拍呈现真实访存信号
	assign RAM_ADDR  = ex_mem_addr;
	assign RAM_REN   = dsram_req_valid & dsram_req_ren;
	assign RAM_WEN   = dsram_req_valid & dsram_req_wen;
	assign RAM_WDATA = dsram_req_wdata;

	//load写回数据格式化：DSRAM完成数据为整字，按锁存op做符号/零扩展
	always @(*) begin
		case (ex_exu_op)
			`LB:	load_fmt_data = {{24{mem_done_rdata[7]}}, mem_done_rdata[7:0]};
			`LBU:	load_fmt_data = {24'b0, mem_done_rdata[7:0]};
			`LH:	load_fmt_data = {{16{mem_done_rdata[15]}}, mem_done_rdata[15:0]};
			`LHU:	load_fmt_data = {16'b0, mem_done_rdata[15:0]};
			default:load_fmt_data = mem_done_rdata;
		endcase
	end

	//IFU-SRAM取指总线（IFU发读请求，SRAM延迟一拍返回指令）
	wire					sram_ren;
	wire	[`RV32E_WIDTH-1:0]	sram_addr;
	wire	[`RV32E_WIDTH-1:0]	sram_rdata;

	RV32E_IFU IFU(
		.clk			(clk),
		.rst			(rst),
		.finish			(finish),
		.jump_sig		(jump_sig),
		.jump_addr		(jump_addr),
		.if_ready		(if_ready),
		.if_valid		(if_valid),
		.INST			(INST),
		.pc_count		(programe_counter),
		.sram_ren		(sram_ren),
		.sram_addr		(sram_addr),
		.sram_rdata		(sram_rdata)
	);

	//取指SRAM：接收IFU读请求，内部经DPI-C读取，延迟一拍返回指令
	RV32E_SRAM SRAM_IF(
		.clk			(clk),
		.rst			(rst),
		.sram_ren		(sram_ren),
		.sram_addr		(sram_addr),
		.sram_rdata		(sram_rdata)
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
		.id_imm			(id_imm),
		.id_pc			(id_pc),
		.id_rwrd		(id_rwrd),
		.id_reg_wen		(id_reg_wen),
		.id_csr_wen		(id_csr_wen),
		.id_csr_wrd		(id_csr_wrd),
		.id_trap		(id_trap),
		.id_mret		(id_mret),
		.id_uncon_jump	(id_uncon_jump),
		.id_mem_ren		(id_mem_ren),
		.id_rs1_addr	(id_rs1_addr),
		.id_rs2_addr	(id_rs2_addr),
		.id_csr_ren		(id_csr_ren),
		.id_csr_rrd		(id_csr_rrd)
	);

	RV32E_RDU RDU(
		.clk			(clk),
		.rst			(rst),
		.id_valid		(id_valid),
		.id_ready		(id_ready),
		.id_exu_op		(id_exu_op),
		.id_imm			(id_imm),
		.id_pc			(id_pc),
		.id_rwrd		(id_rwrd),
		.id_reg_wen		(id_reg_wen),
		.id_csr_wen		(id_csr_wen),
		.id_csr_wrd		(id_csr_wrd),
		.id_trap		(id_trap),
		.id_mret		(id_mret),
		.id_uncon_jump	(id_uncon_jump),
		.id_mem_ren		(id_mem_ren),
		.id_rs1_addr	(id_rs1_addr),
		.id_rs2_addr	(id_rs2_addr),
		.id_csr_ren		(id_csr_ren),
		.id_csr_rrd		(id_csr_rrd),
		.rs1_addr		(rs1_addr),
		.rs2_addr		(rs2_addr),
		.read_data_1	(read_data_0),
		.read_data_2	(read_data_1),
		.csr_ren		(csr_ren),
		.csr_rrd		(csr_rrd),
		.csr_rdata		(csr_rdata),
		.read_ready		(read_ready),
		.read_valid		(read_valid),
		.rd_rs1_data	(rd_rs1_data),
		.rd_rs2_data	(rd_rs2_data),
		.rd_imm			(rd_imm),
		.rd_pc			(rd_pc),
		.rd_csr_rdata	(rd_csr_rdata),
		.rd_exu_op		(rd_exu_op),
		.rd_rwrd		(rd_rwrd),
		.rd_reg_wen		(rd_reg_wen),
		.rd_csr_wen		(rd_csr_wen),
		.rd_csr_wrd		(rd_csr_wrd),
		.rd_trap		(rd_trap),
		.rd_mret		(rd_mret),
		.rd_uncon_jump	(rd_uncon_jump),
		.rd_mem_ren		(rd_mem_ren)
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
		.rd_valid			(read_valid),
		.rd_ready			(read_ready),
		.rd_exu_op			(rd_exu_op),
		.rd_rs1_data		(rd_rs1_data),
		.rd_rs2_data		(rd_rs2_data),
		.rd_imm				(rd_imm),
		.rd_pc				(rd_pc),
		.rd_csr_rdata		(rd_csr_rdata),
		.rd_rwrd			(rd_rwrd),
		.rd_reg_wen			(rd_reg_wen),
		.rd_csr_wen			(rd_csr_wen),
		.rd_csr_wrd			(rd_csr_wrd),
		.rd_trap			(rd_trap),
		.rd_mret			(rd_mret),
		.rd_uncon_jump		(rd_uncon_jump),
		.rd_mem_ren			(rd_mem_ren),
		.ex_ready			(ex_ready_mux),
		.ex_valid			(ex_valid),
		.ex_mem_req			(ex_mem_req),
		.ex_mem_ren			(ex_mem_ren),
		.ex_exu_op			(ex_exu_op),
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
		.ex_valid			(wbu_in_valid),
		.ex_ready			(wbu_ex_ready),
		.ex_reg_write_data	(wbu_reg_data),
		.ex_rwrd			(ex_rwrd),
		.ex_reg_wen			(ex_reg_wen),
		.ex_csr_write_data	(ex_csr_write_data),
		.ex_csr_wrd			(ex_csr_wrd),
		.ex_csr_wen			(ex_csr_wen),
		.ex_trap			(ex_trap),
		.ex_pc				(ex_pc),
		.ex_jump_sig		(ex_jump_sig),
		.ex_jump_addr		(ex_jump_addr),
//		//修改（访存SRAM化）：WBU不再承担访存职责，以下连接注释保留以便回溯
//		.ex_mem_addr		(ex_mem_addr),
//		.ex_mem_write_data	(ex_mem_write_data),
//		.ex_mem_half_data	(ex_mem_half_data),
//		.ex_mem_byte_data	(ex_mem_byte_data),
//		.ex_mem_word_wen	(ex_mem_word_wen),
//		.ex_mem_half_wen	(ex_mem_half_wen),
//		.ex_mem_byte_wen	(ex_mem_byte_wen),
		.reg_wen			(reg_wen_wb),
		.reg_wrd			(reg_wrd_wb),
		.reg_write_data		(reg_write_data_wb),
		.csr_wen			(csr_wen_wb),
		.csr_wrd_out		(csr_wrd_wb),
		.csr_write_data		(csr_write_data_wb),
		.csr_trap_out		(csr_trap_wb),
		.csr_pc				(csr_pc_wb),
//		//修改（访存SRAM化）：WBU访存输出不再使用，以下连接注释保留以便回溯
//		.mem_wen			(wbu_mem_wen),
//		.mem_half_wen		(wbu_mem_half_wen),
//		.mem_byte_wen		(wbu_mem_byte_wen),
//		.mem_addr_out		(wbu_mem_addr),
//		.mem_write_data		(wbu_mem_write_data),
//		.mem_half_data		(wbu_mem_half_data),
//		.mem_byte_data		(wbu_mem_byte_data),
		.jump_sig			(jump_sig),
		.jump_addr_out		(jump_addr),
		.finish				(finish)
	);

	//数据访存单元：SRAM式时序访存，请求拍收地址与信号，下一拍(完成拍)返回数据/写完成
	RV32E_DSRAM DSRAM(
		.clk			(clk),
		.rst			(rst),
		.mem_req_valid	(dsram_req_valid),
		.mem_req_ready	(dsram_req_ready),
		.mem_req_addr	(dsram_req_addr),
		.mem_req_ren	(dsram_req_ren),
		.mem_req_wen	(dsram_req_wen),
		.mem_req_wsize	(dsram_req_wsize),
		.mem_req_wdata	(dsram_req_wdata),
		.mem_done_valid	(mem_done_valid),
		.mem_done_ready	(mem_done_ready),
		.mem_done_rdata	(mem_done_rdata)
	);

//	//修改（访存SRAM化）：原组合读+posedge写的MEM模块已被RV32E_DSRAM取代，实例注释保留以便回溯
//	RV32E_MEM MEM_IF(
//		.clk			(clk),
//		.write_en		(wbu_mem_wen),
//		.read_en		(mem_read_en),
//		.half_write		(wbu_mem_half_wen),
//		.byte_write		(wbu_mem_byte_wen),
//		.address		(wbu_mem_wen ? wbu_mem_addr : mem_addr_comb),
//		.write_data		(wbu_mem_write_data),
//		.half_data		(wbu_mem_half_data),
//		.byte_data		(wbu_mem_byte_data),
//		.read_data		(mem_read_data)
//	);

	//五阶段一拍一阶段串行执行：IF(取指)→ID(译码)→READ(读取)→EX(执行)→WB(写回)，
	//模块间以valid/ready总线握手；读取单元(RDU)用ID_reg的读地址读寄存器堆/CSR，
	//读出的操作数与控制信号锁存进READ_reg后交EXU执行
	//修改（SRAM取指改造）：IF扩为"请求拍+返回拍"两拍（经SRAM取指），全流程6拍/指令

endmodule
