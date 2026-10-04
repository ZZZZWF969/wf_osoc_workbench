`include "RV32E.vh"

//统一访存从设备（AXI4-Lite，五通道）：IFU(取指)与MEM_CTRL(数据)经仲裁器RV32E_ARB共用本模块。
//按ARPROT[2]区分访问类型并分派DPI（取指走inst_fetch不进mtrace捕获区，数据走mem_read/mem_write）与延迟档位
//（取指5-10拍，数据5-25拍）；读写握手拍锁存请求操作数并装载随机延迟，递减到0的下一拍沿执行DPI-C访问并置valid。
//操作数必须握手拍锁存：经仲裁器后总线地址是组合授权选择，延迟等待期间其他主设备的请求会切换活线地址，
//到期使用锁存值才正确（直连时代靠EX_reg稳定性成立，经仲裁后不成立）。
module RV32E_LSU(
	input					clk,
	input					rst,
	//读地址通道（仲裁器→LSU）
	input	[`RV32E_WIDTH-1:0]	araddr,
	input					arvalid,
	/* verilator lint_off UNUSEDSIGNAL */
	//ARPROT低两位（特权/安全域）本模型不适用，仅bit2（取指/数据）被使用
	input	[2:0]			arprot,
	/* verilator lint_on UNUSEDSIGNAL */
	output	reg				arready,
	//读数据通道（LSU→仲裁器）
	output	reg	[`RV32E_WIDTH-1:0]	rdata,
	output	reg				rvalid,
	input					rready,
	output	[1:0]			rresp,
	//写地址通道（仲裁器→LSU）
	input	[`RV32E_WIDTH-1:0]	awaddr,
	input					awvalid,
	output	reg				awready,
	//写数据通道（仲裁器→LSU）
	input	[`RV32E_WIDTH-1:0]	wdata,
	input	[3:0]			wmask,
	input					wvalid,
	output	reg				wready,
	//写响应通道（LSU→仲裁器）：AW&W握手后确认写完成
	output	reg				bvalid,
	input					bready,
	output	[1:0]			bresp
);

	import "DPI-C" function int unsigned mem_read(input int unsigned addr, input int len);
	import "DPI-C" function void mem_write(input int unsigned addr, input int len, input int unsigned data);
	import "DPI-C" function int unsigned inst_fetch(input int unsigned addr, input int len);
	import "DPI-C" function byte unsigned random_delay(input int unsigned is_fetch);

	//锁存的请求操作数（AR/AW&W握手拍采样，延迟等待期间总线活线可能被其他主设备切换）
	reg	[`RV32E_WIDTH-1:0]	req_addr;	//请求地址
	reg				req_isfetch;	//取指访问标志（ARPROT[2]握手拍采样）
	reg	[`RV32E_WIDTH-1:0]	req_wdata;	//写数据（低位对齐）
	reg	[3:0]			req_wmask;	//写掩码（尺寸编码0001/0011/1111）

	//锁存写掩码尺寸编码转DPI写长度：0001→1字节 0011→2字节 其余→4字节
	wire	[31:0]		wmask_to_len = (req_wmask == 4'b0001) ? 32'd1 :
	                                  (req_wmask == 4'b0011) ? 32'd2 : 32'd4;

	//响应码恒OKAY：DPI内存模型无错误场景，resp为协议形态完整性预留（主设备检查非OKAY即报错停机）
	assign rresp = `AXI_RESP_OKAY;
	assign bresp = `AXI_RESP_OKAY;

	reg	[2:0]			state;
	localparam IDLE		= 3'd0;	//空闲，可接收读写请求
	localparam WAIT_R	= 3'd1;	//读延迟等待：随机延迟递减中
	localparam R_VALID	= 3'd2;	//读数据有效拍，等待上游接收
	localparam WAIT_B	= 3'd3;	//写延迟等待：随机延迟递减中
	localparam B_VALID	= 3'd4;	//写响应有效拍，等待上游接收bready

	//随机延迟寄存器（一字节）：读写握手时装载分档随机延迟（取指5-10/数据5-25），逐拍递减到0完成访问
	reg	[7:0]			delay_cnt;

	always @(posedge clk) begin
		if(rst) begin
			state <= IDLE;
			arready <= 1;
			rvalid <= 0;
			rdata <= 0;
			awready <= 1;
			wready <= 1;
			bvalid <= 0;
			delay_cnt <= 0;
			req_addr <= 0;
			req_isfetch <= 0;
			req_wdata <= 0;
			req_wmask <= 0;
		end else begin
			case (state)
				IDLE: begin
					//读：AR握手拍锁存操作数并装载分档延迟，转读延迟等待
					if(arvalid && arready) begin
						req_addr <= araddr;
						req_isfetch <= arprot[2];
						arready <= 0;
						awready <= 0;	//读进行中阻塞写通道
						wready <= 0;
						delay_cnt <= random_delay({31'b0, arprot[2]});
						state <= WAIT_R;
					end
					//写：AW&W同拍握手拍锁存操作数并装载延迟（写恒为数据访问），转写延迟等待
					if(awvalid && awready && wvalid && wready) begin
						req_addr <= awaddr;
						req_wdata <= wdata;
						req_wmask <= wmask;
						arready <= 0;
						awready <= 0;
						wready <= 0;
						delay_cnt <= random_delay(32'd0);
						state <= WAIT_B;
					end
				end
				WAIT_R: begin
					//延迟递减到0的下一拍沿按访问类型分派DPI读取，随后置rvalid
					if(delay_cnt == 0) begin
						rdata <= req_isfetch ? inst_fetch(req_addr, 4) : mem_read(req_addr, 4);
						rvalid <= 1;
						state <= R_VALID;
					end else begin
						delay_cnt <= delay_cnt - 1;
					end
				end
				R_VALID: begin
					//读数据被上游接收后回空闲
					if(rvalid && rready) begin
						rvalid <= 0;
						arready <= 1;
						awready <= 1;
						wready <= 1;
						state <= IDLE;
					end
				end
				WAIT_B: begin
					//延迟递减到0的下一拍沿执行写入并置bvalid
					if(delay_cnt == 0) begin
						mem_write(req_addr, wmask_to_len, req_wdata);
						bvalid <= 1;
						state <= B_VALID;
					end else begin
						delay_cnt <= delay_cnt - 1;
					end
				end
				B_VALID: begin
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
