`include "RV32E.vh"

//通用AXI4-Lite DPI从设备（原RV32E_LSU统一从设备逻辑迁移至此）：五通道+操作数锁存+
//ARPROT[2]分派DPI（取指inst_fetch不进mtrace捕获区/数据mem_read）+参数化响应延迟。
//延迟档（从设备现实化·延迟参数化）：DELAY_MIN=DELAY_MAX=0为零延迟档（SRAM行为：握手拍当拍完成DPI访问，
//次拍数据/响应有效，不调random_delay）；非零为随机延迟档（DRAM行为：[MIN,MAX]闭区间随机延迟走WAIT等待）。
//RV32E_AXI_XBAR各槽位共用本模块；接真外设RTL时按槽位替换例化即可。
module RV32E_AXI_DEV#(
	parameter [7:0]		DELAY_MIN = 8'd0,	//响应延迟下限（拍）
	parameter [7:0]		DELAY_MAX = 8'd0	//响应延迟上限（拍）；MIN=MAX=0即零延迟档
)(
	input					clk,
	input					rst,
	//读地址通道（XBAR槽位→DEV）
	input	[`RV32E_WIDTH-1:0]	araddr,
	input					arvalid,
	/* verilator lint_off UNUSEDSIGNAL */
	//ARPROT低两位（特权/安全域）本模型不适用，仅bit2（取指/数据）被使用
	input	[2:0]			arprot,
	/* verilator lint_on UNUSEDSIGNAL */
	output	reg				arready,
	//读数据通道（DEV→XBAR槽位）
	output	reg	[`RV32E_WIDTH-1:0]	rdata,
	output	reg				rvalid,
	input					rready,
	output	[1:0]			rresp,
	//写地址通道（XBAR槽位→DEV）
	input	[`RV32E_WIDTH-1:0]	awaddr,
	input					awvalid,
	output	reg				awready,
	//写数据通道（XBAR槽位→DEV）
	input	[`RV32E_WIDTH-1:0]	wdata,
	input	[3:0]			wmask,
	input					wvalid,
	output	reg				wready,
	//写响应通道（DEV→XBAR槽位）
	output	reg				bvalid,
	input					bready,
	output	[1:0]			bresp
);

	import "DPI-C" function int unsigned mem_read(input int unsigned addr, input int len);
	import "DPI-C" function void mem_write(input int unsigned addr, input int len, input int unsigned data);
	import "DPI-C" function int unsigned inst_fetch(input int unsigned addr, input int len);
	//修改（延迟参数化）：原按is_fetch分档取延迟改为闭区间参数化，延迟档由调用方实例参数传入
	//	import "DPI-C" function byte unsigned random_delay(input int unsigned is_fetch);
	import "DPI-C" function byte unsigned random_delay(input int unsigned min, input int unsigned max);

	//锁存的请求操作数（AR/AW&W握手拍采样，延迟等待期间总线活线可能被其他请求切换）
	reg	[`RV32E_WIDTH-1:0]	req_addr;	//请求地址
	reg				req_isfetch;	//取指访问标志（ARPROT[2]握手拍采样）
	reg	[`RV32E_WIDTH-1:0]	req_wdata;	//写数据（低位对齐）
	reg	[3:0]			req_wmask;	//写掩码（尺寸编码0001/0011/1111）

	//锁存写掩码尺寸编码转DPI写长度：0001→1字节 0011→2字节 其余→4字节
	wire	[31:0]		wmask_to_len = (req_wmask == 4'b0001) ? 32'd1 :
	                                  (req_wmask == 4'b0011) ? 32'd2 : 32'd4;
	//当拍写掩码转DPI写长度（零延迟档用）：零延迟写不经锁存，直接按当拍wmask转换
	wire	[31:0]		wmask_len_now = (wmask == 4'b0001) ? 32'd1 :
	                                  (wmask == 4'b0011) ? 32'd2 : 32'd4;

	//响应码恒OKAY：DPI模型无错误场景，总线级错误由XBAR的DECERR引擎产生
	assign rresp = `AXI_RESP_OKAY;
	assign bresp = `AXI_RESP_OKAY;

	reg	[2:0]			state;
	localparam IDLE		= 3'd0;	//空闲，可接收读写请求
	localparam WAIT_R	= 3'd1;	//读延迟等待：随机延迟递减中
	localparam R_VALID	= 3'd2;	//读数据有效拍，等待上游接收
	localparam WAIT_B	= 3'd3;	//写延迟等待：随机延迟递减中
	localparam B_VALID	= 3'd4;	//写响应有效拍，等待上游接收bready

	//随机延迟寄存器（一字节）：读写握手时装载延迟档随机延迟，逐拍递减到0完成访问
	reg	[7:0]			delay_cnt;

	//零延迟档标志（elab期常量）：IDLE握手拍据此走直通路径（零延迟档）或WAIT等待路径（随机延迟档）
	localparam			ZERO_DELAY = (DELAY_MIN == 8'd0) && (DELAY_MAX == 8'd0);

	//延迟装载（generate常量分支）：零延迟档不依赖随机数源，随机档按[DELAY_MIN,DELAY_MAX]闭区间取随机延迟
	wire	[7:0]		delay_load;
	generate
		if(ZERO_DELAY) begin : gen_zero_delay
			assign delay_load = 8'd0;
		end else begin : gen_rand_delay
			assign delay_load = random_delay({24'b0, DELAY_MIN}, {24'b0, DELAY_MAX});
		end
	endgenerate

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
					//读：AR握手拍锁存操作数并装载延迟档随机延迟，转读延迟等待
					if(arvalid && arready) begin
						arready <= 0;
						awready <= 0;	//读进行中阻塞写通道
						wready <= 0;
						//修改（延迟参数化）：零延迟档握手拍当拍完成DPI读取并置rvalid，次拍数据有效（SRAM 1拍读行为）
						if(ZERO_DELAY) begin
							rdata <= arprot[2] ? inst_fetch(araddr, 4) : mem_read(araddr, 4);
							rvalid <= 1;
							state <= R_VALID;
						end else begin
							req_addr <= araddr;
							req_isfetch <= arprot[2];
							//修改（延迟参数化）：原分档随机延迟装载改经delay_load（generate常量分支）
							//	delay_cnt <= random_delay({31'b0, arprot[2]});
							delay_cnt <= delay_load;
							state <= WAIT_R;
						end
					end
					//写：AW&W同拍握手拍锁存操作数并装载延迟（写恒为数据访问），转写延迟等待
					if(awvalid && awready && wvalid && wready) begin
						arready <= 0;
						awready <= 0;
						wready <= 0;
						//修改（延迟参数化）：零延迟档握手拍当拍执行DPI写入并置bvalid，次拍响应有效（SRAM 1拍写行为）
						if(ZERO_DELAY) begin
							mem_write(awaddr, wmask_len_now, wdata);
							bvalid <= 1;
							state <= B_VALID;
						end else begin
							req_addr <= awaddr;
							req_wdata <= wdata;
							req_wmask <= wmask;
							//修改（延迟参数化）：原分档随机延迟装载改经delay_load（写恒数据访问档）
							//	delay_cnt <= random_delay(32'd0);
							delay_cnt <= delay_load;
							state <= WAIT_B;
						end
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
