`include "RV32E.vh"

module RV32E_CPU(
    input                   clk,
    input                   rst,
//	input   [`RV32E_WIDTH-1:0]	INST,
    output  [`RV32E_WIDTH-1:0]  RAM_WDATA,
    output  [`RV32E_WIDTH-1:0]  RAM_ADDR,
	output	[`RV32E_WIDTH-1:0]	PC,
    output                  RAM_WEN,
	output					RAM_REN
);

    wire    [4:0]   rs1_addr;
    wire    [4:0]   rs2_addr;
    wire    [4:0]   reg_rd;
    wire            reg_wen;
	wire    [`RV32E_WIDTH-1:0]  reg_write_data;
	wire [`RV32E_WIDTH-1:0] read_data_0;	//read form register
	wire [`RV32E_WIDTH-1:0] read_data_1;

//	wire			jump_sig;	//跳转信号已由WBU输出，此线废弃
	wire			unconditional_jump;
	wire			conditional_jump;

	wire			csr_wen;
	wire			csr_ren;
//	wire			csr_jump;	//跳转判断迁移至WBU，此线废弃
	wire			trap_sig;
	wire			mret_sig;
	wire	[11:0]	csr_wrd;
	wire	[11:0]	csr_rrd;
	wire	[`RV32E_WIDTH-1:0]	csr_read_data;
	wire	[`RV32E_WIDTH-1:0]	csr_write_data;

	wire			mem_write_half;
	wire			mem_write_byte;
	wire	[15:0]	mem_half_data;
	wire	[7:0]	mem_byte_data;
	wire    [`RV32E_WIDTH-1:0]  programe_counter;
	wire	[`RV32E_WIDTH-1:0]	mem_address;
	wire	[`RV32E_WIDTH-1:0]	RAM_RDATA;
	wire	[`RV32E_WIDTH-1:0]	INST;

	//WBU相关信号(带_wb后缀区别于IDU/EXU同名信号)
	wire	[`RV32E_WIDTH-1:0]	jump_addr_exu;	//EXU计算出的跳转目标
	wire	[`RV32E_WIDTH-1:0]	mem_write_data_exu;	//EXU算出的内存写数据
	wire			mem_wen_idu;	//IDU译码出的按字写内存
	wire			finish;			//WBU写回完成
	wire			jump_sig_wb;	//WBU输出的跳转信号
	wire	[`RV32E_WIDTH-1:0]	jump_addr_wb;	//WBU输出的跳转目标
	wire			reg_wen_wb;
	wire	[4:0]	reg_wrd_wb;
	wire	[`RV32E_WIDTH-1:0]	reg_write_data_wb;
	wire			csr_wen_wb;
	wire	[11:0]	csr_wrd_wb;
	wire	[`RV32E_WIDTH-1:0]	csr_write_data_wb;
	wire			csr_trap_wb;
	wire	[`RV32E_WIDTH-1:0]	csr_pc_wb;
	wire			mem_wen_wb;		//WBU输出的内存写使能(写回拍脉冲)
	wire			mem_half_wen_wb;	//WBU输出的半字写使能
	wire			mem_byte_wen_wb;	//WBU输出的字节写使能
	wire	[`RV32E_WIDTH-1:0]	mem_addr_wb;	//WBU锁存的写地址
	wire	[15:0]	mem_half_data_wb;	//WBU锁存的半字写数据
	wire	[7:0]	mem_byte_data_wb;	//WBU锁存的字节写数据
	
	assign PC = programe_counter;
	assign RAM_ADDR = mem_address;
	assign RAM_WEN = mem_wen_wb;
//	assign csr_jump = trap_sig | mret_sig;	//跳转信号迁移至WBU统一输出
//	assign jump_sig = unconditional_jump | conditional_jump | csr_jump;	//跳转信号迁移至WBU统一输出

	//取指总线信号
	wire if_ready;
	wire if_valid;

    RV32E_IFU IFU(
        .clk        (clk),
        .rst        (rst),
        .jump_sig   (jump_sig_wb),
        .jump_addr  (jump_addr_wb),
        .finish     (finish),
        .pc_count   (programe_counter),
		.INST		(INST),

		//总线接口
		.ready		(if_ready),
		.valid		(if_valid)
    );

	wire [5:0] exu_op;
	wire	[`RV32E_WIDTH-1:0]	imm_num;

    RV32E_IDU IDU(
//		.clk		(clk),
        .inst		(INST),
        .mem_wen	(mem_wen_idu),
		.mem_ren	(RAM_REN),
		.uncon_jump	(unconditional_jump),
		.trap		(trap_sig),
		.mret		(mret_sig),
		.csr_wen	(csr_wen),
		.csr_ren	(csr_ren),
		.csr_wrd	(csr_wrd),
		.csr_rrd	(csr_rrd),
        .rs1_addr	(rs1_addr),
        .rs2_addr   (rs2_addr),
        .reg_wen    (reg_wen),
        .rwrd		(reg_rd),
		.imm		(imm_num),
        .EXU_OP     (exu_op),
        
		//总线接口
		.valid		(if_valid),
		.ready		(if_ready)
    );

    RV32E_REG_ARRAY REG_ARR(
        .clk		(clk),
        .rst		(rst),
        .wen		(reg_wen_wb),
        .raddr1		(rs1_addr),
        .raddr2		(rs2_addr),
        .write_rd	(reg_wrd_wb),
        .write_data	(reg_write_data_wb),
        .read_data_1(read_data_0),
		.read_data_2(read_data_1)
    );

	RV32E_CSR CSR(
		.clk		(clk),
		.rst		(rst),
		.wen		(csr_wen_wb),
		.ren		(csr_ren),
		.trap		(csr_trap_wb),
		.csr_wrd	(csr_wrd_wb),
		.csr_rrd	(csr_rrd),
		.pc			(csr_pc_wb),
		.write_data	(csr_write_data_wb),
		.read_csr	(csr_read_data)
	);

    RV32E_EXU EXU(
        .reg_data_0		(read_data_0),
        .reg_data_1		(read_data_1),	
		.pc				(programe_counter),
		.imm			(imm_num),
		.mem_rdata		(RAM_RDATA),
		.csr_rdata		(csr_read_data),
        .op				(exu_op),
		.con_jump		(conditional_jump),
		.jump_addr		(jump_addr_exu),
		.half_write		(mem_write_half),
		.byte_write		(mem_write_byte),
		.mem_half_data	(mem_half_data),
		.mem_byte		(mem_byte_data),
		.mem_addr		(mem_address),
        .reg_write_data	(reg_write_data),
		.csr_write_data	(csr_write_data),
		.mem_write_data	(mem_write_data_exu)
    );

	RV32E_MEM MEM_IF(
		.clk		(clk),
		.write_en	(mem_wen_wb),
		.read_en	(RAM_REN),
		.half_write	(mem_half_wen_wb),
		.byte_write	(mem_byte_wen_wb),
		.address	(mem_wen_wb ? mem_addr_wb : mem_address),
		.write_data	(RAM_WDATA),
		.half_data	(mem_half_data_wb),
		.byte_data	(mem_byte_data_wb),
		.read_data	(RAM_RDATA)
	);

	RV32E_WBU WBU(
		.clk				(clk),
		.rst				(rst),
		.valid				(if_valid),
		//来自IDU
		.gpr_write			(reg_wen),
		.gpr_wrd			(reg_rd),
		.csr_write			(csr_wen),
		.csr_wrd			(csr_wrd),
		.csr_trap			(trap_sig),
		.mret				(mret_sig),
		.uncon_jump			(unconditional_jump),
		.mem_word_write		(mem_wen_idu),
		//来自EXU
		.wb_data			(reg_write_data),
		.csr_data			(csr_write_data),
		.mem_addr			(mem_address),
		.exu_mem_write_data	(mem_write_data_exu),
		.exu_mem_half_data	(mem_half_data),
		.exu_mem_byte_data	(mem_byte_data),
		.mem_half_write		(mem_write_half),
		.mem_byte_write		(mem_write_byte),
		.con_jump			(conditional_jump),
		.jump_addr			(jump_addr_exu),
		.pc					(programe_counter),
		//写回输出
		.reg_write_data		(reg_write_data_wb),
		.reg_wrd			(reg_wrd_wb),
		.reg_wen			(reg_wen_wb),
		.csr_write_data		(csr_write_data_wb),
		.csr_wrd_out		(csr_wrd_wb),
		.csr_wen			(csr_wen_wb),
		.csr_trap_out		(csr_trap_wb),
		.csr_pc				(csr_pc_wb),
		.mem_addr_out		(mem_addr_wb),
		.mem_write_data		(RAM_WDATA),
		.mem_half_data		(mem_half_data_wb),
		.mem_byte_data		(mem_byte_data_wb),
		.mem_wen			(mem_wen_wb),
		.mem_half_wen		(mem_half_wen_wb),
		.mem_byte_wen		(mem_byte_wen_wb),
		.jump_sig			(jump_sig_wb),
		.jump_addr_out		(jump_addr_wb),
		.finish				(finish)
	);

endmodule
