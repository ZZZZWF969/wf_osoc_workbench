`include "RV32E.vh"

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
	output	[1:0]			rresp,
	//写地址通道（主设备→LSU）
	input	[`RV32E_WIDTH-1:0]	awaddr,
	input					awvalid,
	output	reg				awready,
	//写数据通道（主设备→LSU）
	input	[`RV32E_WIDTH-1:0]	wdata,
	input	[3:0]			wmask,
	input					wvalid,
	output	reg				wready,
	//写响应通道（LSU→主设备）：AW&W握手后确认写完成
	output	reg				bvalid,
	input					bready,
	output	[1:0]			bresp
);

	import "DPI-C" function int unsigned mem_read(input int unsigned addr, input int len);
	import "DPI-C" function void mem_write(input int unsigned addr, input int len, input int unsigned data);
	import "DPI-C" function byte unsigned random_delay();

	//wmask尺寸编码转DPI写长度：0001→1字节 0011→2字节 其余→4字节
	wire	[31:0]		wmask_to_len = (wmask == 4'b0001) ? 32'd1 :
	                                  (wmask == 4'b0011) ? 32'd2 : 32'd4;

	//响应码恒OKAY：DPI内存模型无错误场景，resp为协议形态完整性预留（主设备检查非OKAY即报错停机）
	assign rresp = `AXI_RESP_OKAY;
	assign bresp = `AXI_RESP_OKAY;

	reg	[2:0]			state;
	localparam IDLE		= 3'd0;	//空闲，可接收读写请求
	localparam WAIT_R	= 3'd1;	//读延迟等待：随机延迟递减中
	localparam R_VALID	= 3'd2;	//读数据有效拍，等待上游接收
	localparam WAIT_B	= 3'd3;	//写延迟等待：随机延迟递减中
	localparam B_VALID	= 3'd4;	//写响应有效拍，等待上游接收bready

	//随机延迟寄存器（一字节）：读写握手时装载random_delay()∈[5,25]，逐拍递减到0完成访问
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
		end else begin
			case (state)
				IDLE: begin
					//读：AR握手拍装载随机延迟，转读延迟等待
					if(arvalid && arready) begin
						arready <= 0;
						awready <= 0;	//读进行中阻塞写通道
						wready <= 0;
						delay_cnt <= random_delay();
						state <= WAIT_R;
					end
					//写：AW&W同拍握手时装载随机延迟，转写延迟等待
					if(awvalid && awready && wvalid && wready) begin
						arready <= 0;
						awready <= 0;
						wready <= 0;
						delay_cnt <= random_delay();
						state <= WAIT_B;
					end
				end
				WAIT_R: begin
					//修改（随机延迟注入）：延迟递减到0的下一拍沿执行读取，随后置rvalid
					if(delay_cnt == 0) begin
						rdata <= mem_read(araddr, 4);
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
						//修改（B通道补全）：与IDLE读分支的忙期阻塞配对，恢复写通道就绪
						awready <= 1;
						wready <= 1;
						state <= IDLE;
					end
				end
				WAIT_B: begin
					//修改（随机延迟注入）：延迟递减到0的下一拍沿执行写入并置bvalid
					if(delay_cnt == 0) begin
						mem_write(awaddr, wmask_to_len, wdata);
						bvalid <= 1;
						state <= B_VALID;
					end else begin
						delay_cnt <= delay_cnt - 1;
					end
				end
				B_VALID: begin
					//修改（B通道补全）：写响应被上游接收后回空闲
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
