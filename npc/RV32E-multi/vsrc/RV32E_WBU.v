`include "RV32E.vh"

module RV32E_WBU(
	input				clk,
	input				rst,
	//来自IFU：执行周期脉冲
	input				valid,
	//来自IDU的译码控制信号
	input				gpr_write,		//寄存器写使能
	input		[4:0]	gpr_wrd,		//寄存器写地址
	input				csr_write,		//CSR写使能
	input		[11:0]	csr_wrd,		//CSR写地址
	input				csr_trap,		//trap信号，写mepc
	input				mret,			//mret信号
	input				uncon_jump,		//无条件跳转
	input				mem_word_write,	//按字写内存
	//来自EXU的执行结果
	input	[`RV32E_WIDTH-1:0]	wb_data,			//寄存器写数据
	input	[`RV32E_WIDTH-1:0]	csr_data,			//CSR写数据
	input	[`RV32E_WIDTH-1:0]	mem_addr,			//内存访问地址
	input	[`RV32E_WIDTH-1:0]	exu_mem_write_data,	//内存写数据(字)
	input			[15:0]	exu_mem_half_data,	//内存写数据(半字)
	input			[7:0]	exu_mem_byte_data,	//内存写数据(字节)
	input				mem_half_write,	//按半字写内存
	input				mem_byte_write,	//按字节写内存
	input				con_jump,		//条件跳转
	input	[`RV32E_WIDTH-1:0]	jump_addr,	//跳转目标地址
	input	[`RV32E_WIDTH-1:0]	pc,			//当前指令地址，trap时写mepc用
	//写回输出信号
	output	[`RV32E_WIDTH-1:0]	reg_write_data,		//去往寄存器堆：写数据
	output			[4:0]	reg_wrd,		//去往寄存器堆：写地址
	output					reg_wen,		//去往寄存器堆：写使能
	output	[`RV32E_WIDTH-1:0]	csr_write_data,		//去往CSR：写数据
	output			[11:0]	csr_wrd_out,	//去往CSR：写地址
	output					csr_wen,		//去往CSR：写使能
	output					csr_trap_out,	//去往CSR：trap信号
	output	[`RV32E_WIDTH-1:0]	csr_pc,			//去往CSR：trap时写入mepc的pc
	output	[`RV32E_WIDTH-1:0]	mem_addr_out,	//去往MEM：写地址
	output	[`RV32E_WIDTH-1:0]	mem_write_data,	//去往MEM：写数据(字)
	output			[15:0]	mem_half_data,	//去往MEM：写数据(半字)
	output			[7:0]	mem_byte_data,	//去往MEM：写数据(字节)
	output					mem_wen,		//去往MEM：写使能(仅写回拍为高)
	output					mem_half_wen,	//去往MEM：按半字写使能(仅写回拍为高)
	output					mem_byte_wen,	//去往MEM：按字节写使能(仅写回拍为高)
	output					jump_sig,		//去往IFU：跳转信号
	output	[`RV32E_WIDTH-1:0]	jump_addr_out,	//去往IFU：跳转目标地址
	output	reg					finish			//去往IFU：写回完成，允许退役取指
);

	reg				busy;			//写回拍标志，高电平时正在写回
	reg	[`RV32E_WIDTH-1:0]	pc_reg;			//锁存的当前指令pc

	//锁存寄存器：执行结果与控制信号一起在锁存拍打入
	reg	[`RV32E_WIDTH-1:0]	reg_wr_data;	//锁存：寄存器写数据
	reg			[4:0]	reg_wr_addr;	//锁存：寄存器写地址
	reg					reg_wr_en;		//锁存：寄存器写使能
	reg	[`RV32E_WIDTH-1:0]	csr_wr_data;	//锁存：CSR写数据
	reg			[11:0]	csr_wr_addr;	//锁存：CSR写地址
	reg					csr_wr_en;		//锁存：CSR写使能
	reg					trap_reg;		//锁存：trap信号
	reg	[`RV32E_WIDTH-1:0]	mem_wr_addr;	//锁存：内存写地址
	reg	[`RV32E_WIDTH-1:0]	mem_wr_data;	//锁存：内存写数据(字)
	reg			[15:0]	mem_wr_half;	//锁存：内存写数据(半字)
	reg			[7:0]	mem_wr_byte;	//锁存：内存写数据(字节)
	reg					mem_wr_word;	//锁存：按字写
	reg					mem_wr_half_en;	//锁存：按半字写
	reg					mem_wr_byte_en;	//锁存：按字节写
	reg					uncon_jump_reg;	//锁存：无条件跳转
	reg					con_jump_reg;	//锁存：条件跳转
	reg					trap_jump_reg;	//锁存：trap跳转
	reg					mret_jump_reg;	//锁存：mret跳转
	reg	[`RV32E_WIDTH-1:0]	jump_addr_reg;	//锁存：跳转目标地址

	//写使能只在写回拍(busy)有效，避免IO设备等被重复写入
	assign reg_wen = busy & reg_wr_en;
	assign csr_wen = busy & csr_wr_en;
	assign csr_trap_out = busy & trap_reg;
	assign mem_wen = busy & (mem_wr_word | mem_wr_half_en | mem_wr_byte_en);
	assign mem_half_wen = busy & mem_wr_half_en;
	assign mem_byte_wen = busy & mem_wr_byte_en;
	//跳转信号：由锁存的各类跳转位或出
	assign jump_sig = uncon_jump_reg | con_jump_reg | trap_jump_reg | mret_jump_reg;

	assign reg_write_data = reg_wr_data;
	assign reg_wrd = reg_wr_addr;
	assign csr_write_data = csr_wr_data;
	assign csr_wrd_out = csr_wr_addr;
	assign csr_pc = pc_reg;
	assign mem_addr_out = mem_wr_addr;
	assign mem_write_data = mem_wr_data;
	assign mem_half_data = mem_wr_half;
	assign mem_byte_data = mem_wr_byte;
	assign jump_addr_out = jump_addr_reg;

	//锁存执行结果与控制信号，写回拍为锁存后的下一拍
	always @(posedge clk) begin
		if(rst) begin
			busy <= 0;
			finish <= 1;	//复位时无指令在写回，finish为高允许取指
			pc_reg <= 0;
			reg_wr_data <= 0; reg_wr_addr <= 0; reg_wr_en <= 0;
			csr_wr_data <= 0; csr_wr_addr <= 0; csr_wr_en <= 0;
			trap_reg <= 0;
			mem_wr_addr <= 0; mem_wr_data <= 0; mem_wr_half <= 0; mem_wr_byte <= 0;
			mem_wr_word <= 0; mem_wr_half_en <= 0; mem_wr_byte_en <= 0;
			uncon_jump_reg <= 0; con_jump_reg <= 0;
			trap_jump_reg <= 0; mret_jump_reg <= 0;
			jump_addr_reg <= 0;
		end else if(valid && !busy) begin
			//锁存拍：执行结果与控制信号一起锁存
			busy <= 1;
			finish <= 0;
			pc_reg <= pc;
			reg_wr_data <= wb_data;
			reg_wr_addr <= gpr_wrd;
			reg_wr_en <= gpr_write;
			csr_wr_data <= csr_data;
			csr_wr_addr <= csr_wrd;
			csr_wr_en <= csr_write;
			trap_reg <= csr_trap;
			mem_wr_addr <= mem_addr;
			mem_wr_data <= exu_mem_write_data;
			mem_wr_half <= exu_mem_half_data;
			mem_wr_byte <= exu_mem_byte_data;
			mem_wr_word <= mem_word_write;
			mem_wr_half_en <= mem_half_write;
			mem_wr_byte_en <= mem_byte_write;
			uncon_jump_reg <= uncon_jump;
			con_jump_reg <= con_jump;
			trap_jump_reg <= csr_trap;
			mret_jump_reg <= mret;
			jump_addr_reg <= jump_addr;
		end else if(busy) begin
			//写回拍结束：写使能已持续一拍，写回完成
			busy <= 0;
			finish <= 1;
		end
	end

	//内存写由RV32E_MEM执行，本模块只负责在写回拍输出写数据/使能/地址给MEM
//	always @(posedge clk) begin
//		if(mem_wen) begin
//			if(mem_wr_half_en) begin
//				mem_write(mem_wr_addr, 2, {16'b0, mem_wr_half});
//			end else if(mem_wr_byte_en) begin
//				mem_write(mem_wr_addr, 1, {24'b0, mem_wr_byte});
//			end else begin
//				mem_write(mem_wr_addr, 4, mem_wr_data);
//			end
//		end
//	end

endmodule
