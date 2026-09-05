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
    output			[`RV32E_WIDTH-1:0]	pc_count
);

	import "DPI-C" function void halt();
	import "DPI-C" function int unsigned mem_read(input int unsigned addr, input int len);

	reg [`RV32E_WIDTH-1:0] pc;
	reg	[`RV32E_WIDTH-1:0] ir_pc;

	reg [1:0] state;
	localparam IDLE		= 2'd0;		//等finish（其余阶段进行中）
	localparam FETCH	= 2'd1;		//取指拍：拍末INST就绪
	localparam SEND		= 2'd2;		//发valid拍：IDU本拍译码

	assign pc_count = ir_pc;

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
					//退役点：pc每条指令只在此更新一次；此时pc仍为当前指令地址，
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
						state <= FETCH;
					end
				end
				FETCH: begin
					//取指一拍：INST与ir_pc在拍末就绪，valid同步拉高供IDU下一拍译码
					INST <= mem_read(pc, 4);
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

	//原状态机为"IDLE取指轮询+WAIT呈现指令+退役更新pc"约5~6拍/指令，已重构为
	//本版"等finish(退役更新pc)+FETCH取指+SEND发valid"三态，与ID/EX/WB各一拍组成
	//IF(1)+ID(1)+EX(1)+WB(1)=4拍/指令的串行多周期。完整旧实现见git f9a994e。

endmodule
