`include "RV32E.vh"

//AXI总线互连（XBAR）：ARB下来的访存请求按RV32E.vh注册表译码，路由到各从设备槽位。
//修改（从设备现实化）：槽0=SRAM(零延迟)、槽1=UART(纯RTL仿真模型)、槽2=DEFAULT槽(DRAM+MMIO外设，随机延迟)——
//未命中槽0/槽1的一切地址（含0xA000_0000 MMIO外设区）default路由槽2，经DPI走C++访存链is_io_device分发，
//MMIO地址合法化（原内建DECERR引擎不可达，保留待删除指令；越界错误改由C++层处理：读返0/写assert）。
//新增设备两步：①.vh登记XBAR_DEVn_BASE/END（按槽0/1模式扩展）②如需非通用DPI从设备，在本文件内用真外设RTL替换对应槽位例化。
//路由结构：AR按当拍译码组合路由；R属主r_dev在AR握手拍锁存（总线outstanding=1，忙期无新握手）；
//AW按awaddr当拍译码，W无地址——AW&W同拍握手拍用当拍译码、其余拍用AW握手拍锁存的aw_dev；B按aw_dev路由。
//DMA预留：数据面=ARB新增m2主口；控制面=本注册表登记DMA寄存器段（详见MEM_REMAKE.md）。
module RV32E_AXI_XBAR(
	input					clk,
	input					rst,
	//主侧（接ARB的s侧，五通道+arprot，端口形态沿用原从设备）
	input	[`RV32E_WIDTH-1:0]	araddr,
	input					arvalid,
	input	[2:0]			arprot,
	output					arready,
	output	[`RV32E_WIDTH-1:0]	rdata,
	output					rvalid,
	input					rready,
	output	[1:0]			rresp,
	input	[`RV32E_WIDTH-1:0]	awaddr,
	input					awvalid,
	output					awready,
	input	[`RV32E_WIDTH-1:0]	wdata,
	input	[3:0]			wmask,
	input					wvalid,
	output					wready,
	output					bvalid,
	input					bready,
	output	[1:0]			bresp,
	//CLINT副作用输出（非总线，CLINT接入新增）：中断挂起标志引出，经CPU顶层接CSR的MSIP/MTIP位
	output					clint_msip,
	output					clint_mtip
);

	localparam			DEV_NONE = 3'd7;	//原未注册地址标记：default路由后不可达，DECERR引擎随之退役（保留待删除指令）

	//地址译码：按.vh注册表命中槽位（倒序判低槽位后写=低槽位优先）；修改（从设备现实化）：default改路由槽2
	//（DEFAULT槽：DRAM+MMIO外设，未命中已登记槽位的一切地址走C++访存链）；修改（CLINT接入）：登记槽3译码分支
	//（原DEV_NONE注释保留以便回溯）
	function [2:0] addr_decode;
		input [`RV32E_WIDTH-1:0] addr;
		begin
			//	addr_decode = DEV_NONE;
			addr_decode = 3'd2;
`ifdef XBAR_DEV3_BASE
			if(addr >= `XBAR_DEV3_BASE && addr <= `XBAR_DEV3_END) addr_decode = 3'd3;
`endif
`ifdef XBAR_DEV1_BASE
			if(addr >= `XBAR_DEV1_BASE && addr <= `XBAR_DEV1_END) addr_decode = 3'd1;
`endif
`ifdef XBAR_DEV0_BASE
			if(addr >= `XBAR_DEV0_BASE && addr <= `XBAR_DEV0_END) addr_decode = 3'd0;
`endif
		end
	endfunction

	//槽位设备总线（槽0 SRAM/槽1 UART/槽2 DRAM(DEFAULT)；地址类信号广播，就绪类信号按译码路由）
	wire	[`RV32E_WIDTH-1:0]	dev0_rdata, dev1_rdata;
	wire			dev0_arready, dev0_rvalid, dev0_awready, dev0_wready, dev0_bvalid;
	wire	[1:0]		dev0_rresp, dev0_bresp;
	wire			dev1_arready, dev1_rvalid, dev1_awready, dev1_wready, dev1_bvalid;
	wire	[1:0]		dev1_rresp, dev1_bresp;
	wire	[`RV32E_WIDTH-1:0]	dev2_rdata;
	wire			dev2_arready, dev2_rvalid, dev2_awready, dev2_wready, dev2_bvalid;
	wire	[1:0]		dev2_rresp, dev2_bresp;
`ifdef XBAR_DEV3_BASE
	//槽3：CLINT连线组（含副作用输出线，.vh登记XBAR_DEV3_BASE后生效）
	wire	[`RV32E_WIDTH-1:0]	dev3_rdata;
	wire			dev3_arready, dev3_rvalid, dev3_awready, dev3_wready, dev3_bvalid;
	wire	[1:0]		dev3_rresp, dev3_bresp;
	wire			dev3_clint_msip, dev3_clint_mtip;
	assign clint_msip = dev3_clint_msip;
	assign clint_mtip = dev3_clint_mtip;
`else
	assign clint_msip = 1'b0;	//槽3未登记时副作用输出恒0
	assign clint_mtip = 1'b0;
`endif

	//AR路由：当拍译码组合选择（default槽2常在；DECERR引擎default路由后不可达，逻辑保留待删除指令）
	wire	[2:0]		ar_dev = addr_decode(araddr);

	reg	[2:0]			r_dev;		//R属主：AR握手拍锁存
	reg				decerr_r_pending;	//DECERR读响应在飞行（不可达：ar_dev恒为0/1/2）

	always @(posedge clk) begin
		if(rst) begin
			r_dev <= DEV_NONE;
			decerr_r_pending <= 0;
		end else begin
			if(arvalid && arready) begin
				r_dev <= ar_dev;
				if(ar_dev == DEV_NONE) decerr_r_pending <= 1;
			end else if(decerr_r_pending && rready) begin
				decerr_r_pending <= 0;
			end
		end
	end

	assign arready	= (ar_dev == 3'd0) ? dev0_arready :
	                  (ar_dev == 3'd1) ? dev1_arready :
//`ifdef XBAR_DEV2_BASE	//修改（从设备现实化）：槽2转DEFAULT槽无条件例化，条件编译解除
	                  (ar_dev == 3'd2) ? dev2_arready :
//`endif
`ifdef XBAR_DEV3_BASE
	                  (ar_dev == 3'd3) ? dev3_arready :
`endif
	                  ~decerr_r_pending;
	assign rvalid	= (r_dev == 3'd0) ? dev0_rvalid :
	                  (r_dev == 3'd1) ? dev1_rvalid :
//`ifdef XBAR_DEV2_BASE
	                  (r_dev == 3'd2) ? dev2_rvalid :
//`endif
`ifdef XBAR_DEV3_BASE
	                  (r_dev == 3'd3) ? dev3_rvalid :
`endif
	                  decerr_r_pending;
	assign rdata	= (r_dev == 3'd0) ? dev0_rdata :
	                  (r_dev == 3'd1) ? dev1_rdata :
//`ifdef XBAR_DEV2_BASE
	                  (r_dev == 3'd2) ? dev2_rdata :
//`endif
`ifdef XBAR_DEV3_BASE
	                  (r_dev == 3'd3) ? dev3_rdata :
`endif
	                  {`RV32E_WIDTH{1'b0}};
	assign rresp	= (r_dev == 3'd0) ? dev0_rresp :
	                  (r_dev == 3'd1) ? dev1_rresp :
//`ifdef XBAR_DEV2_BASE
	                  (r_dev == 3'd2) ? dev2_rresp :
//`endif
`ifdef XBAR_DEV3_BASE
	                  (r_dev == 3'd3) ? dev3_rresp :
`endif
	                  `AXI_RESP_DECERR;

	//AW/W/B路由：AW按awaddr当拍译码；W无地址，握手拍用当拍译码、其余拍用锁存值；B按锁存值
	//（DECERR写引擎同AR侧不可达，逻辑保留待删除指令）
	wire	[2:0]		aw_dev = addr_decode(awaddr);
	reg	[2:0]			aw_dev_latch;		//AW握手拍锁存（W/B路由用）
	reg				decerr_b_pending;	//DECERR写响应在飞行（不可达：aw_dev恒为0/1/2）

	always @(posedge clk) begin
		if(rst) begin
			aw_dev_latch <= DEV_NONE;
			decerr_b_pending <= 0;
		end else begin
			if(awvalid && awready) begin
				aw_dev_latch <= aw_dev;
				if(aw_dev == DEV_NONE && wvalid && wready) decerr_b_pending <= 1;
			end else if(decerr_b_pending && bready) begin
				decerr_b_pending <= 0;
			end
		end
	end

	wire	[2:0]		w_route = (awvalid && awready) ? aw_dev : aw_dev_latch;

	assign awready	= (aw_dev == 3'd0) ? dev0_awready :
	                  (aw_dev == 3'd1) ? dev1_awready :
//`ifdef XBAR_DEV2_BASE	//修改（从设备现实化）：槽2转DEFAULT槽无条件例化，条件编译解除
	                  (aw_dev == 3'd2) ? dev2_awready :
//`endif
`ifdef XBAR_DEV3_BASE
	                  (aw_dev == 3'd3) ? dev3_awready :
`endif
	                  ~decerr_b_pending;
	assign wready	= (w_route == 3'd0) ? dev0_wready :
	                  (w_route == 3'd1) ? dev1_wready :
//`ifdef XBAR_DEV2_BASE
	                  (w_route == 3'd2) ? dev2_wready :
//`endif
`ifdef XBAR_DEV3_BASE
	                  (w_route == 3'd3) ? dev3_wready :
`endif
	                  ~decerr_b_pending;
	assign bvalid	= (aw_dev_latch == 3'd0) ? dev0_bvalid :
	                  (aw_dev_latch == 3'd1) ? dev1_bvalid :
//`ifdef XBAR_DEV2_BASE
	                  (aw_dev_latch == 3'd2) ? dev2_bvalid :
//`endif
`ifdef XBAR_DEV3_BASE
	                  (aw_dev_latch == 3'd3) ? dev3_bvalid :
`endif
	                  decerr_b_pending;
	assign bresp	= (aw_dev_latch == 3'd0) ? dev0_bresp :
	                  (aw_dev_latch == 3'd1) ? dev1_bresp :
//`ifdef XBAR_DEV2_BASE
	                  (aw_dev_latch == 3'd2) ? dev2_bresp :
//`endif
`ifdef XBAR_DEV3_BASE
	                  (aw_dev_latch == 3'd3) ? dev3_bresp :
`endif
	                  `AXI_RESP_DECERR;

	//槽位例化：通用DPI从设备（地址/数据/掩码/prot广播，valid按译码门控，ready/valid回路由）
	//槽0：SRAM（零延迟档：握手次拍即回；取指与数据访问，ARPROT[2]分派inst_fetch/mem_read）——DPI vmem后端
	//修改（从设备现实化）：原主存MEM_DEV零参例化改SRAM零延迟档参数化例化，原行注释保留以便回溯
	//	RV32E_AXI_DEV MEM_DEV(
	RV32E_AXI_DEV #(.DELAY_MIN(8'd0), .DELAY_MAX(8'd0)) SRAM_DEV(
		.clk			(clk),
		.rst			(rst),
		.araddr			(araddr),
		.arvalid		(arvalid && (ar_dev == 3'd0)),
		.arprot			(arprot),
		.arready		(dev0_arready),
		.rdata			(dev0_rdata),
		.rvalid			(dev0_rvalid),
		.rready			(rready && (r_dev == 3'd0)),
		.rresp			(dev0_rresp),
		.awaddr			(awaddr),
		.awvalid		(awvalid && (aw_dev == 3'd0)),
		.awready		(dev0_awready),
		.wdata			(wdata),
		.wmask			(wmask),
		.wvalid			(wvalid && (w_route == 3'd0)),
		.wready			(dev0_wready),
		.bvalid			(dev0_bvalid),
		.bready			(bready && (aw_dev_latch == 3'd0)),
		.bresp			(dev0_bresp)
	);

	//槽1：UART仿真模型（纯RTL，$write字符输出，零延迟；写=输出低8位、读=返0+OKAY）
	//修改（从设备现实化）：原槽1外设桥PERI_DEV(AXI_DEV)退役——MMIO改由槽2 DEFAULT经C++访存链is_io_device
	//分发（serial/rtc/kbd/vgactl/fb原地复活），原例化注释保留以便回溯
	RV32E_UART UART_DEV(
		.clk			(clk),
		.rst			(rst),
		.araddr			(araddr),
		.arvalid		(arvalid && (ar_dev == 3'd1)),
		.arprot			(arprot),
		.arready		(dev1_arready),
		.rdata			(dev1_rdata),
		.rvalid			(dev1_rvalid),
		.rready			(rready && (r_dev == 3'd1)),
		.rresp			(dev1_rresp),
		.awaddr			(awaddr),
		.awvalid		(awvalid && (aw_dev == 3'd1)),
		.awready		(dev1_awready),
		.wdata			(wdata),
		.wmask			(wmask),
		.wvalid			(wvalid && (w_route == 3'd1)),
		.wready			(dev1_wready),
		.bvalid			(dev1_bvalid),
		.bready			(bready && (aw_dev_latch == 3'd1)),
		.bresp			(dev1_bresp)
	);
//	RV32E_AXI_DEV PERI_DEV(
//		.clk			(clk),
//		.rst			(rst),
//		.araddr			(araddr),
//		.arvalid		(arvalid && (ar_dev == 3'd1)),
//		.arprot			(arprot),
//		.arready		(dev1_arready),
//		.rdata			(dev1_rdata),
//		.rvalid			(dev1_rvalid),
//		.rready			(rready && (r_dev == 3'd1)),
//		.rresp			(dev1_rresp),
//		.awaddr			(awaddr),
//		.awvalid		(awvalid && (aw_dev == 3'd1)),
//		.awready		(dev1_awready),
//		.wdata			(wdata),
//		.wmask			(wmask),
//		.wvalid			(wvalid && (w_route == 3'd1)),
//		.wready			(dev1_wready),
//		.bvalid			(dev1_bvalid),
//		.bready			(bready && (aw_dev_latch == 3'd1)),
//		.bresp			(dev1_bresp)
//	);

	//槽2：DEFAULT槽=DRAM+MMIO外设（随机延迟档5-25拍，DPI vmem后端→C++访存链is_io_device分发外设）：
	//未命中槽0/槽1的一切地址（0x8100_0000+真DRAM段、0xA000_0000 MMIO外设区）默认路由至此
	//修改（从设备现实化）：原预布线休眠槽2（ifdef XBAR_DEV2_BASE门控）转DEFAULT槽无条件例化+随机延迟参数
//`ifdef XBAR_DEV2_BASE
	//槽2：休眠预布线（.vh登记XBAR_DEV2_BASE/END后自动生效，设备类型按需替换AXI_DEV）
//	RV32E_AXI_DEV DEV2_DEV(
	RV32E_AXI_DEV #(.DELAY_MIN(8'd5), .DELAY_MAX(8'd25)) DRAM_DEV(
		.clk			(clk),
		.rst			(rst),
		.araddr			(araddr),
		.arvalid		(arvalid && (ar_dev == 3'd2)),
		.arprot			(arprot),
		.arready		(dev2_arready),
		.rdata			(dev2_rdata),
		.rvalid			(dev2_rvalid),
		.rready			(rready && (r_dev == 3'd2)),
		.rresp			(dev2_rresp),
		.awaddr			(awaddr),
		.awvalid		(awvalid && (aw_dev == 3'd2)),
		.awready		(dev2_awready),
		.wdata			(wdata),
		.wmask			(wmask),
		.wvalid			(wvalid && (w_route == 3'd2)),
		.wready			(dev2_wready),
		.bvalid			(dev2_bvalid),
		.bready			(bready && (aw_dev_latch == 3'd2)),
		.bresp			(dev2_bresp)
	);
//`endif

`ifdef XBAR_DEV3_BASE
	//槽3：CLINT中断控制器（msip/mtimecmp/mtime寄存器组，设备内未命中回DECERR，1拍响应）
	//副作用输出clint_msip/clint_mtip经本模块端口引出（接CPU顶层→CSR的MSIP/MTIP位）
	RV32E_CLINT CLINT_DEV(
		.clk			(clk),
		.rst			(rst),
		.araddr			(araddr),
		.arvalid		(arvalid && (ar_dev == 3'd3)),
		.arprot			(arprot),
		.arready		(dev3_arready),
		.rdata			(dev3_rdata),
		.rvalid			(dev3_rvalid),
		.rready			(rready && (r_dev == 3'd3)),
		.rresp			(dev3_rresp),
		.awaddr			(awaddr),
		.awvalid		(awvalid && (aw_dev == 3'd3)),
		.awready		(dev3_awready),
		.wdata			(wdata),
		.wmask			(wmask),
		.wvalid			(wvalid && (w_route == 3'd3)),
		.wready			(dev3_wready),
		.bvalid			(dev3_bvalid),
		.bready			(bready && (aw_dev_latch == 3'd3)),
		.bresp			(dev3_bresp),
		.clint_msip		(dev3_clint_msip),
		.clint_mtip		(dev3_clint_mtip)
	);
`endif

endmodule
