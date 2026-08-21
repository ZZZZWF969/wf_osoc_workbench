`include "RV32E.vh"

module RV32E_CSR(
	input			clk,
	input			rst,
	input			wen,
	input			ren,
	input			trap,
	input	[11:0]	csr_wrd,
	input	[11:0]	csr_rrd,
	input	[`RV32E_WIDTH-1:0]	pc,
	input	[`RV32E_WIDTH-1:0]	write_data,
	output	[`RV32E_WIDTH-1:0]	read_csr
);

	import "DPI-C" function void halt();

	reg [`RV32E_WIDTH-1:0]	csr_rdata;

	reg	[`RV32E_WIDTH-1:0]	mcause;
	reg	[`RV32E_WIDTH-1:0]	mepc;
	reg	[`RV32E_WIDTH-1:0]	mstatus;
	reg	[`RV32E_WIDTH-1:0]	mtvec;

	assign read_csr = csr_rdata;

	always @(*) begin
		if(ren) begin
			case (csr_rrd)
				`MCAUSE:	csr_rdata = mcause;
				`MEPC:		csr_rdata = mepc;
				`MSTATUS:	csr_rdata = mstatus;
				`MTVEC:		csr_rdata = mtvec;
				default: begin
					$display("invalid CSR read");
					halt();
				end
			endcase
		end else begin
			csr_rdata = 0;
		end
	end

	always @(posedge clk) begin
		if(rst)begin
			mcause <= 32'h0b; mstatus <= 32'h1800;	//set initial value
			mepc <= 0; mtvec <= 0;		//assign initial value during startup
		end else begin
			if(trap)begin
				mepc <= pc;
//				$display("mepc: %x", mepc);
//				$display("mstatus: %x", mstatus);
			end else if(wen) begin
				case (csr_wrd)
					`MCAUSE:	mcause	<= 	write_data;
					`MEPC:		mepc	<=	write_data;
					`MTVEC:		mtvec	<=	write_data;
					`MSTATUS:	mstatus	<=	write_data; 
					default: begin
						$display("invalid CSR write");
						halt();
					end
				endcase
			end
		end
	end

endmodule

