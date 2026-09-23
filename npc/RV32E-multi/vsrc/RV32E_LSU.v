`include "RV32E.vh"

//LSU访存单元（AXI4-Lite从设备，无B通道）：接收主设备MEM_CTRL的读写通道握手。
//AR握手拍经DPI-C读取整字并锁存，下一拍rvalid返回；AW&W同拍握手时按wmask转len经DPI-C写入。
//wmask为尺寸编码(0001字节/0011半字/1111字)，数据低位对齐写在精确地址上，支持非对齐访问。
//空闲时arready/awready/wready恒高，R_VALID(忙)期间三者拉低；一次仅服务一个请求(outstanding=1)。
module RV32E_LSU(
	input					clk,
	input					rst,
	//读地址通道（主设备→LSU）
	input	[`RV32E_WIDTH-1:0]	araddr,
	input					arvalid,
	output	reg				arready,
	//读数据通道（LSU→主设备）
	output	reg	[`RV32E_WIDTH-1:0]	rdata,
	output	reg				rvalid,
	input					rready,
	//写地址通道（主设备→LSU）
	input	[`RV32E_WIDTH-1:0]	awaddr,
	input					awvalid,
	output	reg				awready,
	//写数据通道（主设备→LSU）
	input	[`RV32E_WIDTH-1:0]	wdata,
	input	[3:0]			wmask,
	input					wvalid,
	output	reg				wready
);

	import "DPI-C" function int unsigned mem_read(input int unsigned addr, input int len);
	import "DPI-C" function void mem_write(input int unsigned addr, input int len, input int unsigned data);

	//wmask尺寸编码转DPI写长度：0001→1字节 0011→2字节 其余→4字节
	wire	[31:0]		wmask_to_len = (wmask == 4'b0001) ? 32'd1 :
	                                  (wmask == 4'b0011) ? 32'd2 : 32'd4;

	reg state;
	localparam IDLE		= 1'd0;	//空闲，可接收读写请求
	localparam R_VALID	= 1'd1;	//读数据有效拍，等待上游接收

	always @(posedge clk) begin
		if(rst) begin
			state <= IDLE;
			arready <= 1;
			rvalid <= 0;
			rdata <= 0;
			awready <= 1;
			wready <= 1;
		end else begin
			case (state)
				IDLE: begin
					//读：AR握手拍经DPI-C读取整字，下一拍rvalid返回
					if(arvalid && arready) begin
						rdata <= mem_read(araddr, 4);
						rvalid <= 1;
						arready <= 0;
						state <= R_VALID;
					end
					//写：AW与W同拍握手时经DPI-C写入
					if(awvalid && awready && wvalid && wready) begin
						mem_write(awaddr, wmask_to_len, wdata);
					end
				end
				R_VALID: begin
					//读数据被上游接收后回空闲
					if(rvalid && rready) begin
						rvalid <= 0;
						arready <= 1;
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
