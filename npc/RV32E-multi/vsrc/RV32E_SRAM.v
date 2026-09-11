`include "RV32E.vh"

module RV32E_SRAM(
	input					clk,
	input					rst,
	//与IFU的取指总线：ren为读请求（请求拍有效），rdata在请求的下一拍返回指令
	input					sram_ren,
	input	[`RV32E_WIDTH-1:0]	sram_addr,
	output	reg	[`RV32E_WIDTH-1:0]	sram_rdata
);

	//修改（退休拍预取）：改调取指专用DPI，不进mtrace捕获区，避免预取读污染load踪迹
	//import "DPI-C" function int unsigned mem_read(input int unsigned addr, input int len);
	import "DPI-C" function int unsigned inst_fetch(input int unsigned addr, input int len);

	//同步读口：请求拍呈现ren/addr，拍末DPI-C读取并锁存，下一拍rdata有效（一拍延迟）
	always @(posedge clk) begin
		if(rst) begin
			sram_rdata <= 0;
		end else begin
			if(sram_ren) begin
				//修改（退休拍预取）：随DPI声明一并切换为inst_fetch
				//sram_rdata <= mem_read(sram_addr, 4);
				sram_rdata <= inst_fetch(sram_addr, 4);
			end
		end
	end

endmodule
