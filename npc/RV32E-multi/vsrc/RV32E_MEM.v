`include "RV32E.vh"

module RV32E_MEM(
	input				clk,
	input				write_en,
	input				read_en,
	input				half_write,
	input				byte_write,
	input		[`RV32E_WIDTH-1:0]	address,
	input		[`RV32E_WIDTH-1:0]	write_data,
	input		[15:0]	half_data,
	input		[7:0]	byte_data,
	output	reg	[`RV32E_WIDTH-1:0]	read_data
);

	import "DPI-C" function int unsigned mem_read(input int unsigned addr, input int len);
	import "DPI-C" function void mem_write(input int unsigned addr, input int len, input int unsigned data);

	always @(*) begin
		read_data = 0;
		if(read_en)begin
			read_data = mem_read(address, 4);
		end
	end

	always @(posedge clk) begin
		if(write_en) begin
			if(half_write) begin 
				mem_write(address, 2, {16'b0,half_data});
			end else if(byte_write)begin
				mem_write(address, 1, {24'b0,byte_data});
			end else begin
				mem_write(address, 4, write_data);
			end
		end
	end

endmodule
