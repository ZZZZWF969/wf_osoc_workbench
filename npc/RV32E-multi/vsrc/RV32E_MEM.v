`include "RV32E.vh"

//本模块已迁移退役（MEM_REMAKE收官·命名规范化）：
//①原"AXI4-Lite数据主设备"代码整体迁往 RV32E_LSU.v（module RV32E_MEM→RV32E_LSU，实例名 MEM_CTRL→LSU）；
//②原RV32E_LSU.v的统一从设备代码迁往 RV32E_AXI_XBAR.v（module RV32E_AXI_DEV）并新增互连fabric；
//③本文件仅作迁移记录保留，不再被顶层实例化。
//module RV32E_MEM(
//	input					clk,
//	input					rst,
//	//上游：EXU的EX_reg输出（请求拍有效，握手前保持稳定）
//	input					ex_valid,
//	input					ex_mem_req,
//	input					ex_mem_ren,
//	input	[`RV32E_WIDTH-1:0]	ex_mem_addr,
//	input					ex_mem_word_wen,
//	input					ex_mem_half_wen,
//	input					ex_mem_byte_wen,
//	input	[`RV32E_WIDTH-1:0]	ex_mem_write_data,
//	input	[15:0]			ex_mem_half_data,
//	input	[7:0]			ex_mem_byte_data,
//	input	[5:0]			ex_exu_op,
//	//下游：AXI4-Lite主口（经仲裁器发往LSU）
//	output	[`RV32E_WIDTH-1:0]	axi_araddr,
//	output					axi_arvalid,
//	input					axi_arready,
//	output	[2:0]			axi_arprot,
//	input	[`RV32E_WIDTH-1:0]	axi_rdata,
//	input					axi_rvalid,
//	output					axi_rready,
//	input	[1:0]			axi_rresp,
//	output	[`RV32E_WIDTH-1:0]	axi_awaddr,
//	output					axi_awvalid,
//	input					axi_awready,
//	output	[`RV32E_WIDTH-1:0]	axi_wdata,
//	output	[3:0]			axi_wmask,
//	output					axi_wvalid,
//	input					axi_wready,
//	input					axi_bvalid,
//	output					axi_bready,
//	input	[1:0]			axi_bresp,
//	output					mem_done_valid,
//	input					mem_done_ready,
//	output	reg	[`RV32E_WIDTH-1:0]	mem_done_rdata,
//	output					mem_ex_ready
//);
//
//	import "DPI-C" function void bus_error(input int unsigned resp);
//	import "DPI-C" function void bus_timeout(input int unsigned channel);
//
//	wire				req_wen = ex_mem_word_wen | ex_mem_half_wen | ex_mem_byte_wen;
//	wire				ar_handshake = axi_arvalid & axi_arready;
//	wire				write_handshake = axi_awvalid & axi_awready & axi_wvalid & axi_wready;
//
//	reg	[1:0]			state;
//	localparam IDLE		= 2'd0;
//	localparam READ_WAIT	= 2'd1;
//	localparam WRITE_WAIT	= 2'd2;
//
//	reg	[31:0]			watchdog_cnt;
//	localparam			AXI_WATCHDOG_LIMIT = 32'd1000;
//
//	（FSM/组合驱动/格式化逻辑与RV32E_LSU.v等价，详见迁移目标文件，此处不再展开注释保留）
//
//endmodule
