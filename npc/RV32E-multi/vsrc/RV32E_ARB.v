`include "RV32E.vh"

//AXI总线仲裁器：IFU(只读m0)与MEM_CTRL(m1)两主设备经本模块访问统一从设备(LSU)。
//AR通道轮询仲裁（RR，last_grant复位置M1保证上电首竞争授权IFU取指先行）；R通道属主复用last_grant路由，
//从设备忙期(outstanding=1)s_arready=0，未获授权主设备保持valid自然背压（无饿死：RR交替授权）。
//AW/W/B通道仅m1使用，直通。流水线化时的升级点（只改本模块）：多outstanding属主队列、第二写主、按地址译码多从设备。
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
	//AR通道轮询仲裁（RR）：last_grant记上次AR握手授权者，双请求同时有效时授权非上次者——
	//任何请求最多等对端1笔事务，无饿死；授权=f(last_grant寄存器,当前valids)，两输入握手前不变→授权稳定。
	//修改（仲裁完整化）：原固定优先级m0(IFU)优先的骨架逻辑注释保留以便回溯
//	wire				grant_m0 = m0_arvalid;
	wire				grant_m0 = m0_arvalid & (~m1_arvalid | (last_grant == OWNER_M1));
	wire				grant_m1 = m1_arvalid & (~m0_arvalid | (last_grant == OWNER_M0));

	assign s_arvalid	= m0_arvalid | m1_arvalid;
	assign s_araddr		= grant_m0 ? m0_araddr : m1_araddr;
	assign s_arprot		= grant_m0 ? m0_arprot : m1_arprot;
	assign m0_arready	= grant_m0 & s_arready;
//	assign m1_arready	= ~grant_m0 & s_arready;
	assign m1_arready	= grant_m1 & s_arready;

	//上次AR握手授权者（一寄存器两用：轮询依据 + R通道属主路由——读响应在飞行中时本寄存器必已
	//更新为该读事务的属主，且从设备outstanding=1忙期无新AR握手，属主对未决请求稳定）。
	//修改（仲裁完整化）：复位置M1——轮询规则下上电后首个双请求窗口必然授权m0(IFU)，保证复位/
	//重新上电后取指先行；原独立r_owner寄存器并入本寄存器，注释保留以便回溯
	reg				last_grant;		//0=m0(IFU) 1=m1(MEM_CTRL)
//	reg				r_owner;		//0=m0(IFU) 1=m1(MEM_CTRL)
	localparam			OWNER_M0 = 1'd0;
	localparam			OWNER_M1 = 1'd1;

	always @(posedge clk) begin
		if(rst) begin
			last_grant <= OWNER_M1;
//			r_owner <= OWNER_M0;
		end else begin
			if(s_arvalid && s_arready) begin
				last_grant <= grant_m0 ? OWNER_M0 : OWNER_M1;
//				r_owner <= grant_m0 ? OWNER_M0 : OWNER_M1;
			end
		end
	end

	assign m0_rvalid	= (last_grant == OWNER_M0) & s_rvalid;
	assign m1_rvalid	= (last_grant == OWNER_M1) & s_rvalid;
	assign m0_rdata		= s_rdata;
	assign m1_rdata		= s_rdata;
	assign m0_rresp		= s_rresp;
	assign m1_rresp		= s_rresp;
	assign s_rready		= (last_grant == OWNER_M0) ? m0_rready : m1_rready;

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
