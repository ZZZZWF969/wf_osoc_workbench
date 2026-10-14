`include "RV32E.vh"

//UART仿真模型（AXI4-Lite从设备，从设备现实化阶段新增，槽位专用）：
//写访问经$write仿真环境函数输出写入数据低8位作为字符（地址不区分寄存器，单输出语义）；
//读访问恒返回0+OKAY（本模型无寄存器语义）。零延迟——AR握手次拍rvalid、AW&W握手次拍bvalid（1拍响应）。
//uart_write_hook为difftest兼容钩子：写握手拍通知C++置skip标志，difftest下NEMU跳过该store执行
//（NEMU侧无0x1000_0000设备注册；字符输出仍由$write承担）。接真SoC时本模块整体被真UART控制器RTL替换。
module RV32E_UART(
	input					clk,
	input					rst,
	//读地址通道（XBAR槽位→UART）
	/* verilator lint_off UNUSEDSIGNAL */
	//地址/prot/掩码本模型不适用（单输出语义：任何写=输出字符，任何读=返回0）
	input	[`RV32E_WIDTH-1:0]	araddr,
	input					arvalid,
	input	[2:0]			arprot,
	/* verilator lint_on UNUSEDSIGNAL */
	output	reg				arready,
	//读数据通道（UART→XBAR槽位）
	output	reg	[`RV32E_WIDTH-1:0]	rdata,
	output	reg				rvalid,
	input					rready,
	output	[1:0]			rresp,
	//写地址通道（XBAR槽位→UART）
	/* verilator lint_off UNUSEDSIGNAL */
	input	[`RV32E_WIDTH-1:0]	awaddr,
	/* verilator lint_on UNUSEDSIGNAL */
	input					awvalid,
	output	reg				awready,
	//写数据通道（XBAR槽位→UART）
	/* verilator lint_off UNUSEDSIGNAL */
	//wdata仅低8位参与字符输出（低位对齐约定）；wmask本模型不适用（单字节输出语义）
	input	[`RV32E_WIDTH-1:0]	wdata,
	input	[3:0]			wmask,
	/* verilator lint_on UNUSEDSIGNAL */
	input					wvalid,
	output	reg				wready,
	//写响应通道（UART→XBAR槽位）
	output	reg				bvalid,
	input					bready,
	output	[1:0]			bresp
);

	import "DPI-C" function void uart_write_hook();

	//响应码恒OKAY：模型无错误场景（总线级错误由XBAR译码层负责）
	assign rresp = `AXI_RESP_OKAY;
	assign bresp = `AXI_RESP_OKAY;

	//三态FSM：IDLE收请求（握手拍置valid）→R_DONE/B_DONE等握手完成回空闲
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
			awready <= 1;
			wready <= 1;
			bvalid <= 0;
		end else begin
			case (state)
				IDLE: begin
					//读：AR握手拍置rvalid（rdata恒0），次拍数据有效（1拍响应）
					if(arvalid && arready) begin
						arready <= 0;
						awready <= 0;	//读进行中阻塞写通道
						wready <= 0;
						rvalid <= 1;
						state <= R_DONE;
					end
					//写：AW&W握手拍输出写入低8位字符并置bvalid，次拍响应有效（1拍响应）
					if(awvalid && awready && wvalid && wready) begin
						$write("%c", wdata[7:0]);
						uart_write_hook();
						arready <= 0;
						awready <= 0;
						wready <= 0;
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
