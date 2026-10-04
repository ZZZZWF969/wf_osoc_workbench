`include "RV32E.vh"

//AXI总线仲裁器（骨架）：IFU(只读m0)与MEM_CTRL(m1)两主设备经本模块访问统一从设备(LSU)。
//AR通道固定优先级m0(IFU)>m1（串行CPU下两主设备无竞争，行为零变化）；R通道属主在AR握手拍锁存后路由，
//从设备忙期(outstanding=1)s_arready=0，未获授权主设备保持valid自然背压。
//AW/W/B通道仅m1使用，直通。流水线化时的升级点（只改本模块）：轮询仲裁、多outstanding、按地址译码多从设备。
module RV32E_ARB(
	input					clk,
	input					rst,
	//主设备m0：IFU（只读，AR/R通道）
	input	[`RV32E_WIDTH-1:0]	m0_araddr,
	input					m0_arvalid,
	input	[2:0]			m0_arprot,	//bit2=1取指访问
	output					m0_arready,
	input					m0_rready,
	output	[`RV32E_WIDTH-1:0]	m0_rdata,
	output					m0_rvalid,
	output	[1:0]			m0_rresp,
	//主设备m1：MEM_CTRL（五通道）
	input	[`RV32E_WIDTH-1:0]	m1_araddr,
	input					m1_arvalid,
	input	[2:0]			m1_arprot,
	output					m1_arready,
	input					m1_rready,
	output	[`RV32E_WIDTH-1:0]	m1_rdata,
	output					m1_rvalid,
	output	[1:0]			m1_rresp,
	input	[`RV32E_WIDTH-1:0]	m1_awaddr,
	input					m1_awvalid,
	output					m1_awready,
	input	[`RV32E_WIDTH-1:0]	m1_wdata,
	input	[3:0]			m1_wmask,
	input					m1_wvalid,
	output					m1_wready,
	output					m1_bvalid,
	input					m1_bready,
	output	[1:0]			m1_bresp,
	//从设备侧s（五通道+arprot，发往统一从设备LSU）
	output	[`RV32E_WIDTH-1:0]	s_araddr,
	output					s_arvalid,
	output	[2:0]			s_arprot,
	input					s_arready,
	input	[`RV32E_WIDTH-1:0]	s_rdata,
	input					s_rvalid,
	output					s_rready,
	input	[1:0]			s_rresp,
	output	[`RV32E_WIDTH-1:0]	s_awaddr,
	output					s_awvalid,
	input					s_awready,
	output	[`RV32E_WIDTH-1:0]	s_wdata,
	output	[3:0]			s_wmask,
	output					s_wvalid,
	input					s_wready,
	input					s_bvalid,
	output					s_bready,
	input	[1:0]			s_bresp
);
	//AR通道固定优先级仲裁：m0(IFU)优先，组合授权（master保持valid至握手，授权在握手前稳定）
	wire				grant_m0 = m0_arvalid;

	assign s_arvalid	= m0_arvalid | m1_arvalid;
	assign s_araddr		= grant_m0 ? m0_araddr : m1_araddr;
	assign s_arprot		= grant_m0 ? m0_arprot : m1_arprot;
	assign m0_arready	= grant_m0 & s_arready;
	assign m1_arready	= ~grant_m0 & s_arready;

	//R通道属主：AR握手拍锁存（从设备忙期无新AR握手，属主对未决请求稳定），按属主路由响应
	reg				r_owner;		//0=m0(IFU) 1=m1(MEM_CTRL)
	localparam			OWNER_M0 = 1'd0;
	localparam			OWNER_M1 = 1'd1;

	always @(posedge clk) begin
		if(rst) begin
			r_owner <= OWNER_M0;
		end else begin
			if(s_arvalid && s_arready) begin
				r_owner <= grant_m0 ? OWNER_M0 : OWNER_M1;
			end
		end
	end

	assign m0_rvalid	= (r_owner == OWNER_M0) & s_rvalid;
	assign m1_rvalid	= (r_owner == OWNER_M1) & s_rvalid;
	assign m0_rdata		= s_rdata;
	assign m1_rdata		= s_rdata;
	assign m0_rresp		= s_rresp;
	assign m1_rresp		= s_rresp;
	assign s_rready		= (r_owner == OWNER_M0) ? m0_rready : m1_rready;

	//AW/W/B通道：仅m1(MEM_CTRL)使用，直通
	assign s_awaddr		= m1_awaddr;
	assign s_awvalid	= m1_awvalid;
	assign m1_awready	= s_awready;
	assign s_wdata		= m1_wdata;
	assign s_wmask		= m1_wmask;
	assign s_wvalid		= m1_wvalid;
	assign m1_wready	= s_wready;
	assign m1_bvalid	= s_bvalid;
	assign s_bready		= m1_bready;
	assign m1_bresp		= s_bresp;

endmodule
