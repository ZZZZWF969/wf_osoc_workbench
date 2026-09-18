`include "RV32E.vh"

//数据访存单元（SRAM式时序访存）：与取指SRAM同构，读请求拍呈现地址与信号，
//posedge经DPI-C读取并锁存，下一拍才回复数据；写请求在请求拍posedge执行。
//对外仅为通用访存握手接口（请求valid/ready+完成valid/ready），不感知CPU内部语义，
//便于后续替换为真实SRAM/总线而不牵动CPU其余部分。
module RV32E_DSRAM(
	input					clk,
	input					rst,
	//访存请求总线（上游）：握手成功拍=请求拍，地址与读写信号在本拍有效
	input					mem_req_valid,
	output	reg				mem_req_ready,
	input	[`RV32E_WIDTH-1:0]	mem_req_addr,
	input					mem_req_ren,		//读请求
	input					mem_req_wen,		//写请求
	input		[1:0]		mem_req_wsize,		//写宽度：00字节 01半字 10字
	input	[`RV32E_WIDTH-1:0]	mem_req_wdata,		//写数据（低位对齐）
	//访存完成总线（下游）：完成拍返回读数据/写完成确认，握手后本模块回空闲
	output	reg				mem_done_valid,
	input					mem_done_ready,
	output	reg	[`RV32E_WIDTH-1:0]	mem_done_rdata
);

	import "DPI-C" function int unsigned mem_read(input int unsigned addr, input int len);
	import "DPI-C" function void mem_write(input int unsigned addr, input int len, input int unsigned data);

	reg state;
	localparam IDLE	= 1'd0;		//空闲，可接收请求
	localparam DONE	= 1'd1;		//完成拍：读数据有效/写已提交

	always @(posedge clk) begin
		if(rst) begin
			state <= IDLE;
			mem_req_ready <= 1;
			mem_done_valid <= 0;
			mem_done_rdata <= 0;
		end else begin
			case (state)
				IDLE: begin
					if(mem_req_valid && mem_req_ready) begin
						//请求拍：posedge执行读写；读数据锁存后下一拍(完成拍)有效
						if(mem_req_ren) begin
							mem_done_rdata <= mem_read(mem_req_addr, 4);
						end
						if(mem_req_wen) begin
							case (mem_req_wsize)
								2'b00:	mem_write(mem_req_addr, 1, {24'b0, mem_req_wdata[7:0]});
								2'b01:	mem_write(mem_req_addr, 2, {16'b0, mem_req_wdata[15:0]});
								default:mem_write(mem_req_addr, 4, mem_req_wdata);
							endcase
						end
						mem_req_ready <= 0;
						mem_done_valid <= 1;
						state <= DONE;
					end
				end
				DONE: begin
					//完成拍：下游接收后回空闲
					if(mem_done_ready) begin
						mem_done_valid <= 0;
						mem_req_ready <= 1;
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
