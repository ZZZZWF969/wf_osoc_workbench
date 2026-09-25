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

	//访存完成总线（MEM_CTRL→WBU）
	wire					mem_done_valid;
	wire					mem_done_ready;
	wire	[`RV32E_WIDTH-1:0]	mem_done_rdata;
	//写回输入路由：访存指令等DSRAM完成，非访存指令旁路EX_reg
	wire					wbu_bypass_valid;
	wire					wbu_in_valid;	//WBU最终输入valid（csrc退休沿观察点）
	wire					wbu_ex_ready;
	wire					ex_ready_mux;
	wire	[`RV32E_WIDTH-1:0]	wbu_reg_data;

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
	//写回输入路由：访存指令用MEM_CTRL完成信号，非访存指令旁路EX_reg
	assign wbu_bypass_valid = ex_valid & ~ex_mem_req;
	assign wbu_in_valid     = ex_mem_req ? mem_done_valid : wbu_bypass_valid;
	assign wbu_reg_data     = ex_mem_ren ? mem_done_rdata : ex_reg_write_data;
	assign mem_done_ready   = 1'b1;		//WBU写回拍恒可接收
	//EXU下游就绪：访存看MEM_CTRL请求握手完成，非访存看WBU
	assign ex_ready_mux     = ex_mem_req ? mem_ex_ready : wbu_ex_ready;

	//RAM观察端口（供csrc踪迹）：请求拍呈现真实访存信号（取自AXI主口）
	assign RAM_ADDR  = ex_mem_addr;
	assign RAM_REN   = axi_arvalid;
	assign RAM_WEN   = axi_awvalid;
	assign RAM_WDATA = axi_wdata;


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
		.reg_wen			(reg_wen_wb),
		.reg_wrd			(reg_wrd_wb),
		.reg_write_data		(reg_write_data_wb),
		.csr_wen			(csr_wen_wb),
		.csr_wrd_out		(csr_wrd_wb),
		.csr_write_data		(csr_write_data_wb),
		.csr_trap_out		(csr_trap_wb),
		.csr_pc				(csr_pc_wb),
		.jump_sig			(jump_sig),
		.jump_addr_out		(jump_addr),
		.finish				(finish)
	);
	//MEM_CTRL(LSU主设备)↔LSU(从设备)的AXI4-Lite总线连线（完整五通道）
	wire					axi_arvalid;
	wire					axi_arready;
	wire	[`RV32E_WIDTH-1:0]	axi_araddr;
	wire					axi_rvalid;
	wire					axi_rready;
	wire	[`RV32E_WIDTH-1:0]	axi_rdata;
	wire	[1:0]			axi_rresp;	//读响应码（恒OKAY，非OKAY即bus_error停机）
	wire					axi_awvalid;
	wire					axi_awready;
	wire	[`RV32E_WIDTH-1:0]	axi_awaddr;
	wire					axi_wvalid;
	wire					axi_wready;
	wire	[`RV32E_WIDTH-1:0]	axi_wdata;
	wire	[3:0]			axi_wmask;	//写掩码：尺寸编码0001/0011/1111
	//写响应通道（LSU→MEM_CTRL）
	wire					axi_bvalid;
	wire					axi_bready;
	wire	[1:0]			axi_bresp;	//写响应码（恒OKAY）
	wire					mem_ex_ready;	//MEM_CTRL反馈EXU：请求握手完成

	//访存控制单元（AXI4-Lite主设备）：EXU访存请求经AXI通道发往LSU，load数据格式化后送WBU
	RV32E_MEM MEM_CTRL(
		.clk				(clk),
		.rst				(rst),
		.ex_valid			(ex_valid),
		.ex_mem_req			(ex_mem_req),
		.ex_mem_ren			(ex_mem_ren),
		.ex_mem_addr			(ex_mem_addr),
		.ex_mem_word_wen		(ex_mem_word_wen),
		.ex_mem_half_wen		(ex_mem_half_wen),
		.ex_mem_byte_wen		(ex_mem_byte_wen),
		.ex_mem_write_data		(ex_mem_write_data),
		.ex_mem_half_data		(ex_mem_half_data),
		.ex_mem_byte_data		(ex_mem_byte_data),
		.ex_exu_op			(ex_exu_op),
		.axi_araddr			(axi_araddr),
		.axi_arvalid			(axi_arvalid),
		.axi_arready			(axi_arready),
		.axi_rdata			(axi_rdata),
		.axi_rvalid			(axi_rvalid),
		.axi_rready			(axi_rready),
		.axi_rresp			(axi_rresp),
		.axi_awaddr			(axi_awaddr),
		.axi_awvalid			(axi_awvalid),
		.axi_awready			(axi_awready),
		.axi_wdata			(axi_wdata),
		.axi_wmask			(axi_wmask),
		.axi_wvalid			(axi_wvalid),
		.axi_wready			(axi_wready),
		.axi_bvalid			(axi_bvalid),
		.axi_bready			(axi_bready),
		.axi_bresp			(axi_bresp),
		.mem_done_valid			(mem_done_valid),
		.mem_done_ready			(mem_done_ready),
		.mem_done_rdata			(mem_done_rdata),
		.mem_ex_ready			(mem_ex_ready)
	);

	//LSU访存单元（AXI4-Lite从设备）：经DPI-C完成实际读写
	RV32E_LSU LSU(
		.clk			(clk),
		.rst			(rst),
		.araddr			(axi_araddr),
		.arvalid		(axi_arvalid),
		.arready		(axi_arready),
		.rdata			(axi_rdata),
		.rvalid			(axi_rvalid),
		.rready			(axi_rready),
		.rresp			(axi_rresp),
		.awaddr			(axi_awaddr),
		.awvalid		(axi_awvalid),
		.awready		(axi_awready),
		.wdata			(axi_wdata),
		.wmask			(axi_wmask),
		.wvalid			(axi_wvalid),
		.wready			(axi_wready),
		.bvalid			(axi_bvalid),
		.bready			(axi_bready),
		.bresp			(axi_bresp)
	);

endmodule
