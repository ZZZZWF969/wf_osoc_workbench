`include "RV32E.vh"

module RV32E_CPU(
    input                   clk,
    input                   rst,
	input   [`RV32E_WIDTH-1:0]	INST,
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

	wire			jump_sig;
	wire			unconditional_jump;
	wire			conditional_jump;

	wire			csr_wen;
	wire			csr_ren;
	wire			csr_jump;
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
	
	assign PC = programe_counter;
	assign RAM_ADDR = mem_address;
	assign csr_jump = trap_sig | mret_sig;
	assign jump_sig = unconditional_jump | conditional_jump | csr_jump ;

    RV32E_IFU IFU(
        .clk        (clk),
        .rst        (rst),
        .jump_sig   (jump_sig),
        .jump_addr  (mem_address),
        .pc_count   (programe_counter)
    );

	wire [5:0]  exu_op;

	wire	[`RV32E_WIDTH-1:0]	imm_num;

    RV32E_IDU IDU(
        .inst		(INST),
        .mem_wen	(RAM_WEN),
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
        .EXU_OP     (exu_op)
        //more IO ports
    );

    RV32E_REG_ARRAY REG_ARR(
        .clk		(clk),
        .rst		(rst),
        .wen		(reg_wen),
        .raddr1		(rs1_addr),
        .raddr2		(rs2_addr),
        .write_rd	(reg_rd),
        .write_data	(reg_write_data),
        .read_data_1(read_data_0),
		.read_data_2(read_data_1)
    );

	RV32E_CSR CSR(
		.clk		(clk),
		.rst		(rst),
		.wen		(csr_wen),
		.ren		(csr_ren),
		.trap		(trap_sig),
		.csr_wrd	(csr_wrd),
		.csr_rrd	(csr_rrd),
		.pc			(programe_counter),
		.write_data	(csr_write_data),
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
		.half_write		(mem_write_half),
		.byte_write		(mem_write_byte),
		.mem_half_data	(mem_half_data),
		.mem_byte		(mem_byte_data),
		.mem_addr		(mem_address),
        .reg_write_data	(reg_write_data),
		.csr_write_data	(csr_write_data),
		.mem_write_data	(RAM_WDATA)
    );

	RV32E_MEM MEM_IF(
		.clk		(clk),
		.write_en	(RAM_WEN),
		.read_en	(RAM_REN),
		.half_write	(mem_write_half),
		.byte_write	(mem_write_byte),
		.address	(mem_address),
		.write_data	(RAM_WDATA),
		.half_data	(mem_half_data),
		.byte_data	(mem_byte_data),
		.read_data	(RAM_RDATA)
	);

endmodule
