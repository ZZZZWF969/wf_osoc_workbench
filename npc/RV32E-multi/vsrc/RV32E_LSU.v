`include "RV32E.vh"

//修改（随机延迟注入）：读写请求握手后装载random_delay()返回的[5,25]随机延迟拍数（一字节寄存器），
//逐拍递减到0的下一拍沿才执行DPI-C访问并置valid——模拟慢速存储器，实测总线等待语义
//（master的READ_WAIT/WRITE_WAIT天然等待任意拍；看门狗阈值1000远大于25，不误触发）。
//修改（B通道补全）：下行头注释"无B通道"表述已过时，注释保留；本模块现为完整五通道——
//AW&W同拍握手经DPI-C写入后，下一拍bvalid+bresp(恒OKAY)确认写响应，bready握手后回空闲。
//LSU访存单元（AXI4-Lite从设备，无B通道）：接收主设备MEM_CTRL的读写通道握手。
//AR握手拍经DPI-C读取整字并锁存，下一拍rvalid返回；AW&W同拍握手时按wmask转len经DPI-C写入。
//wmask为尺寸编码(0001字节/0011半字/1111字)，数据低位对齐写在精确地址上，支持非对齐访问。
//修改（B通道补全）：下行"R_VALID(忙)期间三者拉低"原仅靠主设备不并发保证（代码未做），本次真正实现并扩展到B_VALID
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

	//修改（随机延迟注入）：三态扩为五态（新增读/写延迟等待态），state再扩为3位
//	reg state;
//	reg	[1:0]			state;
	reg	[2:0]			state;
//	localparam IDLE		= 1'd0;	//空闲，可接收读写请求
//	localparam R_VALID	= 1'd1;	//读数据有效拍，等待上游接收
//	localparam IDLE		= 2'd0;	//空闲，可接收读写请求
//	localparam R_VALID	= 2'd1;	//读数据有效拍，等待上游接收
//	localparam B_VALID	= 2'd2;	//写响应有效拍，等待上游接收bready
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
					//修改（随机延迟注入）：读写握手后先装载随机延迟转入等待态，原"握手拍即访问"逻辑注释保留
//					//读：AR握手拍经DPI-C读取整字，下一拍rvalid返回
//					if(arvalid && arready) begin
//						rdata <= mem_read(araddr, 4);
//						rvalid <= 1;
//						arready <= 0;
//						//修改（B通道补全）：读进行中阻塞写通道（原忙期awready/wready仍高，仅靠主设备不并发保证）
//						awready <= 0;
//						wready <= 0;
//						state <= R_VALID;
//					end
					//读：AR握手拍装载随机延迟，转读延迟等待
					if(arvalid && arready) begin
						arready <= 0;
						awready <= 0;	//读进行中阻塞写通道
						wready <= 0;
						delay_cnt <= random_delay();
						state <= WAIT_R;
					end
//					//写：AW与W同拍握手时经DPI-C写入
//					if(awvalid && awready && wvalid && wready) begin
//						mem_write(awaddr, wmask_to_len, wdata);
//						//修改（B通道补全）：数据已在W握手拍提交，转入写响应态，下一拍bvalid确认
//						bvalid <= 1;
//						arready <= 0;
//						awready <= 0;
//						wready <= 0;
//						state <= B_VALID;
//					end
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
