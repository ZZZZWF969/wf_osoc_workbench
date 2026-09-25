`include "RV32E.vh"

module RV32E_IFU(
    input				clk,
    input				rst,
    //来自WBU：写回完成信号，IFU收到后才退役并取指
    input				finish,
    //跳转信号与目标地址（来自WBU，写回拍有效）
    input				jump_sig,
    input		[`RV32E_WIDTH-1:0]	jump_addr,
    //与IDU的总线握手：valid发指令，ready由IDU空闲指示
    input				if_ready,
    output	reg			if_valid,
    output	reg	[`RV32E_WIDTH-1:0]	INST,
    output			[`RV32E_WIDTH-1:0]	pc_count,
	//与SRAM的取指总线：FETCH拍发读请求（ren/addr），rdata下一拍返回指令
	output				sram_ren,
	output		[`RV32E_WIDTH-1:0]	sram_addr,
	input		[`RV32E_WIDTH-1:0]	sram_rdata
);

	import "DPI-C" function void halt();

	reg [`RV32E_WIDTH-1:0] pc;
	reg	[`RV32E_WIDTH-1:0] ir_pc;

	reg [1:0] state;
	localparam IDLE		= 2'd0;		//等finish（其余阶段进行中）
	localparam FETCH	= 2'd1;		//仅复位后首条指令使用（后续由退休拍预取直达WAIT）
	localparam SEND		= 2'd2;		//发valid拍：IDU本拍译码
	localparam WAIT		= 2'd3;		//SRAM返回拍：拍末INST就绪

	assign pc_count = ir_pc;

	assign sram_ren		= (state == FETCH) || (state == IDLE && finish);
	assign sram_addr	= (state == IDLE && finish) ? (jump_sig ? jump_addr : pc + 32'h0000_0004) : pc;

	always @(posedge clk) begin
		if(rst) begin
			pc <= `RV32E_MEMBASE;
			ir_pc <= 0;
			INST <= 0;
			if_valid <= 0;
			state <= FETCH;		//复位后无上一指令的finish可等，直接取第一条
		end else begin
			case (state)
				IDLE: begin
					//jump_addr==pc即"跳转到自身"的自循环，停机
					if(finish) begin
						if(jump_sig) begin
							if(jump_addr == pc) begin
								halt();
							end
							pc <= jump_addr;
						end else begin
							pc <= pc + 32'h0000_0004;
						end
						state <= WAIT;
					end
				end
				FETCH: begin
					state <= WAIT;
				end
				WAIT: begin
					//SRAM返回拍：rdata本拍有效，拍末锁存INST并拉高valid，供IDU下一拍译码
					INST <= sram_rdata;
					ir_pc <= pc;
					if_valid <= 1;
					state <= SEND;
				end
				SEND: begin
					//valid保持到握手成功（IDU空闲接收）后撤销
					if(if_ready) begin
						if_valid <= 0;
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
