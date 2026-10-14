`include "RV32E.vh"

//CLINT中断控制器仿真模型（AXI4-Lite从设备，CLINT接入阶段新增，槽位专用）：
//msip[31:0]@0x0200_0000 / mtimecmp[63:0]@0x0200_4000 / mtime[63:0]@0x0200_BFF8，复位全0，mtime每clk自增（写优先）。
//读写均1拍响应，支持1/2/4字节访问：读按滑窗约定（从精确地址取4字节放低位），写按wmask尺寸掩码字节使能。
//设备内未命中三个寄存器的地址回DECERR（rresp/bresp=2'b11），主设备resp检查链路红字bus_error停机。
//副作用输出clint_msip/clint_mtip经XBAR端口引出接CSR的MSIP/MTIP位（本阶段仅锁存标志，中断响应为下一阶段）；
//mtime值走AXI读通道返回（0xBFF8/BFFC低/高字），不设独立输出端口。
//clint_hook为difftest兼容钩子（读写握手拍置skip标志，CLINT纯RTL不走vmem，NEMU无0x0200_0000注册）。
module RV32E_CLINT(
	input					clk,
	input					rst,
	//读地址通道（XBAR槽位→CLINT）
	/* verilator lint_off UNUSEDSIGNAL */
	//地址高位不参与设备内译码（槽3区间[0x0200_0000,0x0200_BFFF]由XBAR译码保证，仅低16位偏移译码）
	input	[`RV32E_WIDTH-1:0]	araddr,
	/* verilator lint_on UNUSEDSIGNAL */
	input					arvalid,
	/* verilator lint_off UNUSEDSIGNAL */
	//prot本模型不适用（无特权级区分）
	input	[2:0]			arprot,
	/* verilator lint_on UNUSEDSIGNAL */
	output	reg				arready,
	//读数据通道（CLINT→XBAR槽位）
	output	reg	[`RV32E_WIDTH-1:0]	rdata,
	output	reg				rvalid,
	input					rready,
	output	[1:0]			rresp,
	//写地址通道（XBAR槽位→CLINT）
	/* verilator lint_off UNUSEDSIGNAL */
	input	[`RV32E_WIDTH-1:0]	awaddr,
	/* verilator lint_on UNUSEDSIGNAL */
	input					awvalid,
	output	reg				awready,
	//写数据通道（XBAR槽位→CLINT）
	input	[`RV32E_WIDTH-1:0]	wdata,
	input	[3:0]			wmask,
	input					wvalid,
	output	reg				wready,
	//写响应通道（CLINT→XBAR槽位）
	output	reg				bvalid,
	input					bready,
	output	[1:0]			bresp,
	//CLINT副作用输出（非总线）：中断挂起标志，接CSR的MSIP/MTIP位
	output				clint_msip,	//msip寄存器bit0
	output				clint_mtip	//mtime >= mtimecmp
);

	import "DPI-C" function void clint_hook();

	//寄存器组（地址低16位偏移译码，槽3区间由XBAR译码保证）
	reg	[31:0]			msip;		//0x0200_0000：软件中断挂起
	reg	[63:0]			mtimecmp;	//0x0200_4000：定时器比较值
	reg	[63:0]			mtime;		//0x0200_BFF8：自由计数器（每clk自增）

	assign clint_msip	= msip[0];
	assign clint_mtip	= (mtime >= mtimecmp);

	//读译码：命中判定+滑窗数据（寄存器值右移偏移*8，低32位即返回数据，跨界高位自然补0）
	wire	[15:0]		rd_offset = araddr[15:0];
	wire			msip_rd_hit  = (rd_offset <= 16'h0003);
	wire			cmp_rd_hit   = (rd_offset >= 16'h4000) && (rd_offset <= 16'h4007);
	wire			mtime_rd_hit = (rd_offset >= 16'hBFF8) && (rd_offset <= 16'hBFFF);
	wire			clint_rd_hit = msip_rd_hit | cmp_rd_hit | mtime_rd_hit;

	/* verilator lint_off UNUSEDSIGNAL */
	//滑窗移位中转：高32位为移位语义自然冗余，仅低32位作返回数据
	wire	[63:0]		rd_window = msip_rd_hit  ? ({32'b0, msip} >> (araddr[1:0] * 8)) :
	                                     cmp_rd_hit   ? (mtimecmp >> (araddr[2:0] * 8)) :
	                                     mtime_rd_hit ? (mtime >> (araddr[2:0] * 8)) : 64'b0;
	/* verilator lint_on UNUSEDSIGNAL */

	//写译码：命中判定+字节使能（wmask尺寸编码按地址偏移展开到寄存器字节阵列）
	wire	[15:0]		wr_offset = awaddr[15:0];
	wire			msip_wr_hit  = (wr_offset <= 16'h0003);
	wire			cmp_wr_hit   = (wr_offset >= 16'h4000) && (wr_offset <= 16'h4007);
	wire			mtime_wr_hit = (wr_offset >= 16'hBFF8);

	wire	[7:0]		wr_bytes = {4'b0, wmask} << awaddr[2:0];	//64位寄存器视角字节使能
	wire			write_fire = awvalid && awready && wvalid && wready;

	//寄存器组写/mtime自增（写命中拍写优先于自增：mtime被写字节更新、未写字节保持，本拍不自增）
	integer			i;
	always @(posedge clk) begin
		if(rst) begin
			msip <= 32'b0;
			mtimecmp <= 64'b0;
			mtime <= 64'b0;
		end else if(write_fire) begin
			if(msip_wr_hit) begin
				for(i = 0; i < 4; i = i + 1)
					if(wr_bytes[i]) msip[i*8 +: 8] <= wdata[((i - {30'b0, awaddr[1:0]}) * 8) +: 8];
			end
			if(cmp_wr_hit) begin
				for(i = 0; i < 8; i = i + 1)
					if(wr_bytes[i]) mtimecmp[i*8 +: 8] <= wdata[((i - {29'b0, awaddr[2:0]}) * 8) +: 8];
			end
			if(mtime_wr_hit) begin
				for(i = 0; i < 8; i = i + 1)
					if(wr_bytes[i]) mtime[i*8 +: 8] <= wdata[((i - {29'b0, awaddr[2:0]}) * 8) +: 8];
			end else begin
				mtime <= mtime + 64'd1;
			end
		end else begin
			mtime <= mtime + 64'd1;
		end
	end

	//响应码：命中OKAY / 未命中DECERR（读按当拍译码锁存进rresp_r，写同理）
	reg	[1:0]			rresp_r;
	reg	[1:0]			bresp_r;
	assign rresp = rresp_r;
	assign bresp = bresp_r;

	//三态FSM：IDLE收请求（握手拍置valid并锁存数据/响应码）→R_DONE/B_DONE等握手完成回空闲
	reg	[1:0]			state;
	localparam IDLE		= 2'd0;	//空闲，可接收读写请求
	localparam R_DONE	= 2'd1;	//读数据有效拍，等待上游接收rready
	localparam B_DONE	= 2'd2;	//写响应有效拍，等待上游接收bready

	always @(posedge clk) begin
		if(rst) begin
			state <= IDLE;
			arready <= 1;
			rvalid <= 0;
			rdata <= 0;
			rresp_r <= 2'b00;
			awready <= 1;
			wready <= 1;
			bvalid <= 0;
			bresp_r <= 2'b00;
		end else begin
			case (state)
				IDLE: begin
					//读：AR握手拍锁存滑窗数据与响应码，次拍数据有效（1拍响应）
					if(arvalid && arready) begin
						clint_hook();	//difftest skip通知
						arready <= 0;
						awready <= 0;	//读进行中阻塞写通道
						wready <= 0;
						rdata <= rd_window[31:0];
						rresp_r <= clint_rd_hit ? `AXI_RESP_OKAY : `AXI_RESP_DECERR;
						rvalid <= 1;
						state <= R_DONE;
					end
					//写：AW&W握手拍锁存响应码（寄存器写在上块完成），次拍响应有效（1拍响应）
					if(write_fire) begin
						clint_hook();	//difftest skip通知
						arready <= 0;
						awready <= 0;
						wready <= 0;
						bresp_r <= (msip_wr_hit | cmp_wr_hit | mtime_wr_hit) ?
						           `AXI_RESP_OKAY : `AXI_RESP_DECERR;
						bvalid <= 1;
						state <= B_DONE;
					end
				end
				R_DONE: begin
					//读数据被上游接收后回空闲
					if(rvalid && rready) begin
						rvalid <= 0;
						arready <= 1;
						awready <= 1;
						wready <= 1;
						state <= IDLE;
					end
				end
				B_DONE: begin
					//写响应被上游接收后回空闲
					if(bvalid && bready) begin
						bvalid <= 0;
						arready <= 1;
						awready <= 1;
						wready <= 1;
						state <= IDLE;
					end
				end
				default: begin
					state <= IDLE;
				end
			endcase
		end
	end

endmodule
