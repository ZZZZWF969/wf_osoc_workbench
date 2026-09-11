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
	//修改（SRAM取指改造）：mem_read的声明与调用移入RV32E_SRAM，IFU改为经SRAM总线取指
	//import "DPI-C" function int unsigned mem_read(input int unsigned addr, input int len);

	reg [`RV32E_WIDTH-1:0] pc;
	reg	[`RV32E_WIDTH-1:0] ir_pc;

	reg [1:0] state;
	localparam IDLE		= 2'd0;		//等finish（其余阶段进行中）
	localparam FETCH	= 2'd1;		//仅复位后首条指令使用（后续由退休拍预取直达WAIT）
	localparam SEND		= 2'd2;		//发valid拍：IDU本拍译码
	localparam WAIT		= 2'd3;		//SRAM返回拍：拍末INST就绪

	assign pc_count = ir_pc;

	//修改（退休拍预取）：IDLE等finish期间取指通路闲置，退休拍next_pc已确定（jump_sig/jump_addr在手上），
	//该拍提前发读请求把FETCH拍藏进退休拍，全流程减一拍；FETCH态仅复位后首条指令使用
	//assign sram_ren		= (state == FETCH);
	//assign sram_addr	= pc;
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
						//修改（退休拍预取）：请求已在退休拍发出（见上方assign），直接进WAIT收返回
						//state <= FETCH;
						state <= WAIT;
					end
				end
				FETCH: begin
					//取指请求拍：sram_ren/sram_addr组合呈现请求（见上方assign），本拍不锁存
					//修改（SRAM取指改造）：原DPI-C直接取指一拍完成；改为SRAM延迟一拍返回，
					//INST锁存与valid拉高整体移入WAIT拍
					//INST <= mem_read(pc, 4);
					//ir_pc <= pc;
					//if_valid <= 1;
					//state <= SEND;
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

	//原状态机为"IDLE取指轮询+WAIT呈现指令+退役更新pc"约5~6拍/指令，已重构为
	//本版"等finish(退役更新pc)+FETCH取指+SEND发valid"三态，与ID/EX/WB各一拍组成
	//IF(1)+ID(1)+EX(1)+WB(1)=4拍/指令的串行多周期。完整旧实现见git f9a994e。
	//修改（SRAM取指改造）：FETCH拆为"FETCH发请求+WAIT收返回"两拍（经SRAM取指），全流程6拍/指令
	//修改（退休拍预取）：FETCH藏进退休拍（IDLE&&finish即发请求直达WAIT），全流程5拍/指令

endmodule
