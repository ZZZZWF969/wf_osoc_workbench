`include "RV32E.vh"

module RV32E_IFU(
    input				clk,
    input				rst,
    input				jump_sig,
    input		[`RV32E_WIDTH-1:0]	jump_addr,
    input				finish,		//来自WBU：写回完成，允许退役并取指
    output		[`RV32E_WIDTH-1:0]	pc_count,
	output	reg	[`RV32E_WIDTH-1:0]	INST,

	//总线信号
	input				ready,
	output		reg		valid
);

    reg [`RV32E_WIDTH-1:0] pc;
	reg	[`RV32E_WIDTH-1:0] ir_pc;
	reg	[`RV32E_WIDTH-1:0] instruction;

	reg [1:0] state;
	localparam IDLE = 2'b00;
	localparam WAIT = 2'b01;

	import "DPI-C" function void halt();
	import "DPI-C" function int unsigned mem_read(input int unsigned addr, input int len);

	always @(posedge clk) begin
		if(rst) begin
			pc <= `RV32E_MEMBASE;
			ir_pc <= 0;		//0表示尚无指令退役，首条取指读pc本身
			state <= IDLE;
			valid <= 0;
		end else begin
			case (state)
				IDLE: begin
					//退役点：WBU写回完成(finish)后更新pc并取指；
					//valid脉冲期间(刚呈现的指令尚未被WBU锁存)不动作，避免用旧跳转信息退役
					if(finish && !valid) begin
						if(instruction == 0) begin
							//pc更新与取指绑定且仅当无待呈现指令时执行，保证每条指令只推进一次pc；
							//此时pc恒为正在退役指令的地址，jump_addr==pc即"跳转到自身"的自循环
							if(ir_pc != 0) begin
								if(jump_sig) begin
									if(jump_addr == pc) begin
										halt();
									end
									pc <= jump_addr;
								end else begin
									pc <= pc + 32'h0000_0004;
								end
							end
							//取指读更新后的pc：跳转取目标地址，非跳转取pc+4，首条指令取pc
							instruction <= mem_read(jump_sig ? jump_addr : (ir_pc != 0 ? pc + 32'h0000_0004 : pc), 4);
						end
						if(instruction != 0) begin
							//有指令且写回完成，进入WAIT呈现指令
							state <= WAIT;
						end else begin
							state <= IDLE;
						end
					end else begin
						valid <= 0;
					end
				end 
				WAIT: begin
					if(ready) begin
						INST <= instruction;
						instruction <= `RV32E_WIDTH'h0000_0000;
						ir_pc <= pc;
						valid <= 1;		//执行周期脉冲，WBU在下一拍锁存执行结果
						state <= IDLE;
					end else begin
						state <= WAIT;
					end
				end
				default: begin
					state <= IDLE;
					valid <= 0;
					instruction <= `RV32E_WIDTH'h0000_0000;
				end
			endcase
		end
	end

	//原IDLE/WAIT逻辑注释说明：多周期化后取指时机改为"写回完成(finish)才退役取指"，
	//pc更新从WAIT移至退役点(上方)，取指用组合选择读更新后的pc，避免投机取指在跳转指令上取错指令
//	always @(posedge clk) begin
//		if(rst) begin
//			pc <= `RV32E_MEMBASE;
//			state <= IDLE;
//			valid <= 0;
//		end else begin
//			case (state)
//				IDLE: begin
//					instruction <= mem_read(pc, 4);
//					if(instruction != 0) begin	//应该等WB返回信号之后才可以跳状态
//						valid <= 1;
//						state <= WAIT;
//					end else begin
//						state <= IDLE;
//						valid <= 0;
//					end
//				end 
//				WAIT: begin
//					if(ready) begin
//						INST <= instruction;
//						instruction <= `RV32E_WIDTH'h0000_0000;
//						ir_pc <= pc;
//						if(jump_sig) begin
//							if(jump_addr == pc) begin
//								halt();
//							end
//							pc <= jump_addr;
//						end else begin
//							pc <= pc + 32'h0000_0004;
//						end
//						state <= IDLE;
//					end else begin
//						state <= WAIT;
//					end
//				end
//				default: begin
//					state <= IDLE;
//					valid <= 0;
//					instruction <= `RV32E_WIDTH'h0000_0000;
//				end
//			endcase
//		end
//	end

//     always @(posedge clk) begin
//         if (rst) begin
//             pc <= `RV32E_MEMBASE;
//         end else begin
//             if (jump_sig) begin
// 				if(jump_addr == pc) begin
// 					halt();
// 					$display("stop simulation by DPI-C");
// 				end
//                 pc <= jump_addr;
// //				instruction <= 0;
//             end else begin
//                 pc <= pc + `RV32E_WIDTH'h0000_0004;
// //				instruction <= mem_read(pc, 4);
// 			end
// //			ir_pc <= pc;
//         end
//     end

// 	always @(*) begin
// 		instruction = mem_read(pc, 4);
// 	end

	assign pc_count = ir_pc;
//	assign pc_count = pc;
//	assign INST = instruction;

endmodule
