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

	//RAM观察端口（供csrc踪迹）：请求拍呈现真实访存信号（取自LSU主口）
	assign RAM_ADDR  = ex_mem_addr;
	assign RAM_REN   = lsu_arvalid;
	assign RAM_WEN   = lsu_awvalid;
	assign RAM_WDATA = lsu_wdata;


	//IFU(取指master)↔ARB(仲裁器)的AXI4-Lite只读总线连线
	wire					ifu_arvalid;
	wire					ifu_arready;
	wire	[`RV32E_WIDTH-1:0]	ifu_araddr;
	wire	[2:0]			ifu_arprot;	//恒3'b100：bit2=1取指访问
	wire					ifu_rvalid;
	wire					ifu_rready;
	wire	[`RV32E_WIDTH-1:0]	ifu_rdata;
	wire	[1:0]			ifu_rresp;

	//修改（取指AXI化并入统一总线）：原IFU-SRAM取指总线注释保留以便回溯
//	wire					sram_ren;
//	wire	[`RV32E_WIDTH-1:0]	sram_addr;
//	wire	[`RV32E_WIDTH-1:0]	sram_rdata;

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
		.arvalid		(ifu_arvalid),
		.araddr			(ifu_araddr),
		.arprot			(ifu_arprot),
		.arready		(ifu_arready),
		.rdata			(ifu_rdata),
		.rvalid			(ifu_rvalid),
		.rready			(ifu_rready),
		.rresp			(ifu_rresp)
	);

	//修改（取指AXI化并入统一总线）：取指SRAM已由统一从设备LSU承担，实例注释保留以便回溯
//	RV32E_SRAM SRAM_IF(
//		.clk			(clk),
//		.rst			(rst),
//		.sram_ren		(sram_ren),
//		.sram_addr		(sram_addr),
//		.sram_rdata		(sram_rdata)
//	);

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
		.read_csr		(csr_rdata),
		.clint_msip		(clint_msip),
		.clint_mtip		(clint_mtip)
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
	//LSU(数据master)↔ARB(仲裁器)的AXI4-Lite总线连线（m1侧，完整五通道）
	//修改（MEM_REMAKE收官·命名规范化）：原MEM_CTRL实例更名LSU（module RV32E_LSU），axi_*连线随之更名lsu_*
	wire					lsu_arvalid;
	wire					lsu_arready;
	wire	[`RV32E_WIDTH-1:0]	lsu_araddr;
	wire	[2:0]			lsu_arprot;	//恒3'b000：数据访问
	wire					lsu_rvalid;
	wire					lsu_rready;
	wire	[`RV32E_WIDTH-1:0]	lsu_rdata;
	wire	[1:0]			lsu_rresp;	//读响应码（非OKAY即bus_error停机；DECERR=未注册地址）
	wire					lsu_awvalid;
	wire					lsu_awready;
	wire	[`RV32E_WIDTH-1:0]	lsu_awaddr;
	wire					lsu_wvalid;
	wire					lsu_wready;
	wire	[`RV32E_WIDTH-1:0]	lsu_wdata;
	wire	[3:0]			lsu_wmask;	//写掩码：尺寸编码0001/0011/1111
	//写响应通道（XBAR→LSU）
	wire					lsu_bvalid;
	wire					lsu_bready;
	wire	[1:0]			lsu_bresp;	//写响应码
	wire					mem_ex_ready;	//LSU反馈EXU：请求握手完成

	//LSU数据访存单元（AXI4-Lite五通道主设备，原MEM_CTRL/RV32E_MEM迁移）：
	//EXU访存请求经仲裁器发往XBAR，load数据格式化后送WBU；resp检查与总线看门狗内建
	RV32E_LSU LSU(
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
		.araddr				(lsu_araddr),
		.arvalid			(lsu_arvalid),
		.arready			(lsu_arready),
		.arprot				(lsu_arprot),
		.rdata				(lsu_rdata),
		.rvalid				(lsu_rvalid),
		.rready				(lsu_rready),
		.rresp				(lsu_rresp),
		.awaddr				(lsu_awaddr),
		.awvalid			(lsu_awvalid),
		.awready			(lsu_awready),
		.wdata				(lsu_wdata),
		.wmask				(lsu_wmask),
		.wvalid				(lsu_wvalid),
		.wready				(lsu_wready),
		.bvalid				(lsu_bvalid),
		.bready				(lsu_bready),
		.bresp				(lsu_bresp),
		.mem_done_valid			(mem_done_valid),
		.mem_done_ready			(mem_done_ready),
		.mem_done_rdata			(mem_done_rdata),
		.mem_ex_ready			(mem_ex_ready)
	);

	//ARB(仲裁器)↔AXI_XBAR(互连)的AXI4-Lite总线连线（互连主侧，五通道+arprot）
	wire					s_arvalid;
	wire					s_arready;
	wire	[`RV32E_WIDTH-1:0]	s_araddr;
	wire	[2:0]			s_arprot;
	wire					s_rvalid;
	wire					s_rready;
	wire	[`RV32E_WIDTH-1:0]	s_rdata;
	wire	[1:0]			s_rresp;
	wire					s_awvalid;
	wire					s_awready;
	wire	[`RV32E_WIDTH-1:0]	s_awaddr;
	wire					s_wvalid;
	wire					s_wready;
	wire	[`RV32E_WIDTH-1:0]	s_wdata;
	wire	[3:0]			s_wmask;
	wire					s_bvalid;
	wire					s_bready;
	wire	[1:0]			s_bresp;

	//AXI总线仲裁器：IFU(m0,只读)与LSU(m1,数据)经此访问AXI_XBAR（轮询，复位偏IFU）
	RV32E_ARB ARB(
		.clk			(clk),
		.rst			(rst),
		.m0_araddr		(ifu_araddr),
		.m0_arvalid		(ifu_arvalid),
		.m0_arprot		(ifu_arprot),
		.m0_arready		(ifu_arready),
		.m0_rready		(ifu_rready),
		.m0_rdata		(ifu_rdata),
		.m0_rvalid		(ifu_rvalid),
		.m0_rresp		(ifu_rresp),
		.m1_araddr		(lsu_araddr),
		.m1_arvalid		(lsu_arvalid),
		.m1_arprot		(lsu_arprot),
		.m1_arready		(lsu_arready),
		.m1_rready		(lsu_rready),
		.m1_rdata		(lsu_rdata),
		.m1_rvalid		(lsu_rvalid),
		.m1_rresp		(lsu_rresp),
		.m1_awaddr		(lsu_awaddr),
		.m1_awvalid		(lsu_awvalid),
		.m1_awready		(lsu_awready),
		.m1_wdata		(lsu_wdata),
		.m1_wmask		(lsu_wmask),
		.m1_wvalid		(lsu_wvalid),
		.m1_wready		(lsu_wready),
		.m1_bvalid		(lsu_bvalid),
		.m1_bready		(lsu_bready),
		.m1_bresp		(lsu_bresp),
		.s_araddr		(s_araddr),
		.s_arvalid		(s_arvalid),
		.s_arprot		(s_arprot),
		.s_arready		(s_arready),
		.s_rdata		(s_rdata),
		.s_rvalid		(s_rvalid),
		.s_rready		(s_rready),
		.s_rresp		(s_rresp),
		.s_awaddr		(s_awaddr),
		.s_awvalid		(s_awvalid),
		.s_awready		(s_awready),
		.s_wdata		(s_wdata),
		.s_wmask		(s_wmask),
		.s_wvalid		(s_wvalid),
		.s_wready		(s_wready),
		.s_bvalid		(s_bvalid),
		.s_bready		(s_bready),
		.s_bresp		(s_bresp)
	);

	//CLINT中断挂起标志连线（XBAR→CSR专用，CLINT接入新增）：CLINT的msip/mtip经XBAR端口引出接CSR位标志
	wire					clint_msip;
	wire					clint_mtip;

	//AXI总线互连（XBAR，原统一从设备LSU演进）：按.vh注册表译码路由到各设备槽位，未注册地址回DECERR
	//（内含槽0主存/槽1外设桥两个通用DPI从设备RV32E_AXI_DEV；新增设备=.vh登记+本文件内占用槽位）
	RV32E_AXI_XBAR AXI_XBAR(
		.clk			(clk),
		.rst			(rst),
		.araddr		(s_araddr),
		.arvalid		(s_arvalid),
		.arprot		(s_arprot),
		.arready		(s_arready),
		.rdata			(s_rdata),
		.rvalid		(s_rvalid),
		.rready		(s_rready),
		.rresp			(s_rresp),
		.awaddr		(s_awaddr),
		.awvalid		(s_awvalid),
		.awready		(s_awready),
		.wdata			(s_wdata),
		.wmask			(s_wmask),
		.wvalid		(s_wvalid),
		.wready		(s_wready),
		.bvalid		(s_bvalid),
		.bready		(s_bready),
		.bresp			(s_bresp),
		.clint_msip		(clint_msip),
		.clint_mtip		(clint_mtip)
	);

endmodule
