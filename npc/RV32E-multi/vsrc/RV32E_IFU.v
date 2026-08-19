`include "RV32E.vh"

module RV32E_IFU(
    input               clk,
    input               rst,
    input               jump_sig,
    input   [`RV32E_WIDTH-1:0]  jump_addr,
    output  [`RV32E_WIDTH-1:0]  pc_count,
	output	[`RV32E_WIDTH-1:0]	INST
);

    reg [`RV32E_WIDTH-1:0] pc;
	reg	[`RV32E_WIDTH-1:0] instruction;

	import "DPI-C" function void halt();
	import "DPI-C" function int unsigned mem_read(input int unsigned addr, input int len);

    always @(posedge clk) begin
        if (rst) begin
            pc <= `RV32E_MEMBASE;
			instruction <= 0;
        end else begin
            if (jump_sig) begin
				if(jump_addr == pc) begin
					halt();
					$display("stop simulation by DPI-C");
				end
                pc <= jump_addr;
            end else begin
                pc <= pc + `RV32E_WIDTH'h0000_0004;
            end
        end
    end

    assign pc_count = pc;

endmodule
