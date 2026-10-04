`include "RV32E.vh"

//取指单元（AXI4-Lite只读master）：经仲裁器RV32E_ARB访问统一从设备LSU，ARPROT[2]=1标记取指访问。
//四态FSM保留：IDLE等finish→（预取AR握手）→WAIT等rvalid锁存INST→SEND交IDU；FETCH仅复位后首条使用。
//预取挂起标志prefetch_pending：finish首拍登记请求（自跳转停机与pc更新仅执行一次），AR握手拍清除——
//arvalid生命周期与finish电平持续时间解耦（AXI语义：valid一经发出保持到握手，从设备忙期自然背压）。
//带取指看门狗：等arready/等rvalid超阈值即报超时停机（与MEM_CTRL同款，channel 3/4）。
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
	output		[`RV32E_WIDTH-1:0]	pc_count,
	//AXI4-Lite只读master口（经仲裁器访问统一从设备）
	output				arvalid,
	output		[`RV32E_WIDTH-1:0]	araddr,
	output		[2:0]			arprot,		//恒3'b100：bit2=1取指访问
	input				arready,
	input		[`RV32E_WIDTH-1:0]	rdata,
	input				rvalid,
	output				rready,
	input		[1:0]			rresp
);
//修改（取指AXI化）：原SRAM直连取指口（sram_ren/addr/rdata）已并入统一总线，注释保留以便回溯
//	output				sram_ren,
//	output		[`RV32E_WIDTH-1:0]	sram_addr,
//	input		[`RV32E_WIDTH-1:0]	sram_rdata

	import "DPI-C" function void halt();
	import "DPI-C" function void bus_error(input int unsigned resp);
	import "DPI-C" function void bus_timeout(input int unsigned channel);

	reg [`RV32E_WIDTH-1:0] pc;
	reg	[`RV32E_WIDTH-1:0] ir_pc;
	reg				prefetch_pending;	//取指请求挂起：finish首拍置位，AR握手拍清除

	reg [1:0] state;
	localparam IDLE		= 2'd0;		//等finish（其余阶段进行中）
	localparam FETCH	= 2'd1;		//仅复位后首条指令使用（后续由退休拍预取直达WAIT）
	localparam SEND		= 2'd2;		//发valid拍：IDU本拍译码
	localparam WAIT		= 2'd3;		//取指返回等待拍：rvalid拍末INST就绪

	assign pc_count = ir_pc;

	//AR请求：FETCH拍（复位首条）、finish拍（退休拍预取）与挂起期间发出；
	//地址：finish首拍给下一pc（pc尚未更新），其余拍给已更新的pc（数值一致，保持稳定）
	assign arvalid	= (state == FETCH) || prefetch_pending || (state == IDLE && finish);
	assign araddr	= (state == IDLE && finish && !prefetch_pending) ? (jump_sig ? jump_addr : pc + 32'h0000_0004) : pc;
	assign arprot	= 3'b100;
	assign rready	= (state == WAIT);	//WAIT拍可接收取指数据

	//取指看门狗：等待拍计数，超阈值判定无响应，调DPI报超时停机
	reg	[31:0]			watchdog_cnt;
	localparam			AXI_WATCHDOG_LIMIT = 32'd1000;	//远大于取指延迟上限10拍

	always @(posedge clk) begin
		if(rst) begin
			pc <= `RV32E_MEMBASE;
			ir_pc <= 0;
			INST <= 0;
			if_valid <= 0;
			prefetch_pending <= 0;
			state <= FETCH;		//复位后无上一指令的finish可等，直接取第一条
			watchdog_cnt <= 0;
		end else begin
			case (state)
				IDLE: begin
					//首次finish拍登记预取请求（自跳转停机与pc更新仅执行一次）；本拍即握手则无需挂起
					if(finish && !prefetch_pending) begin
						if(!(arvalid && arready)) begin
							prefetch_pending <= 1;
						end
						//jump_addr==pc即"跳转到自身"的自循环，停机
						if(jump_sig) begin
							if(jump_addr == pc) begin
								halt();
							end
							pc <= jump_addr;
						end else begin
							pc <= pc + 32'h0000_0004;
						end
					end
					//AR握手成功：撤销挂起并转WAIT
					if(arvalid && arready) begin
						prefetch_pending <= 0;
						state <= WAIT;
						watchdog_cnt <= 0;
					end else if(arvalid) begin
						//看门狗：AR已发未握手计数
						if(watchdog_cnt >= AXI_WATCHDOG_LIMIT - 1) begin
							bus_timeout(32'd4);
						end else begin
							watchdog_cnt <= watchdog_cnt + 1;
						end
					end
				end
				FETCH: begin
					//复位首条：AR握手成功才转WAIT（arvalid=FETCH拍有效）
					if(arready) begin
						state <= WAIT;
						watchdog_cnt <= 0;
					end else begin
						if(watchdog_cnt >= AXI_WATCHDOG_LIMIT - 1) begin
							bus_timeout(32'd4);
						end else begin
							watchdog_cnt <= watchdog_cnt + 1;
						end
					end
				end
				WAIT: begin
					//取指数据返回拍：锁存INST并拉高valid，供IDU下一拍译码；resp非OKAY报错停机
					if(rvalid && rready) begin
						INST <= rdata;
						ir_pc <= pc;
						if_valid <= 1;
						state <= SEND;
						if(rresp != `AXI_RESP_OKAY) begin
							bus_error({30'b0, rresp});
						end
						watchdog_cnt <= 0;
					end else begin
						//看门狗：等rvalid计数
						if(watchdog_cnt >= AXI_WATCHDOG_LIMIT - 1) begin
							bus_timeout(32'd3);
						end else begin
							watchdog_cnt <= watchdog_cnt + 1;
						end
					end
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
