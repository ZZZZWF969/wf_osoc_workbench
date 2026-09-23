`include "RV32E.vh"

//修改（LSU重做AXI化）：原"组合读+posedge直写DPI"的MEM模块整体注释保留以便回溯，
//本文件已改造为AXI4-Lite主设备（顶层实例名从MEM_IF改为MEM_CTRL），经AXI通道访问LSU从设备。
//module RV32E_MEM(
//	input				clk,
//	input				write_en,
//	input				read_en,
//	input				half_write,
//	input				byte_write,
//	input		[`RV32E_WIDTH-1:0]	address,
//	input		[`RV32E_WIDTH-1:0]	write_data,
//	input		[15:0]	half_data,
//	input		[7:0]	byte_data,
//	output	reg	[`RV32E_WIDTH-1:0]	read_data
//);
//
//	import "DPI-C" function int unsigned mem_read(input int unsigned addr, input int len);
//	import "DPI-C" function void mem_write(input int unsigned addr, input int len, input int unsigned data);
//
//	always @(*) begin
//		read_data = 0;
//		if(read_en)begin
//			read_data = mem_read(address, 4);
//		end
//	end
//
//	always @(posedge clk) begin
//		if(write_en) begin
//			if(half_write) begin
//				mem_write(address, 2, {16'b0,half_data});
//			end else if(byte_write)begin
//				mem_write(address, 1, {24'b0,byte_data});
//			end else begin
//				mem_write(address, 4, write_data);
//			end
//		end
//	end
//
//endmodule

//访存控制单元（AXI4-Lite主设备，无B通道）：接收EXU的访存请求，经AXI通道发往LSU。
//IDLE拍组合驱动valid（只依赖请求存在，不依赖对侧ready，AXI合规）；
//读请求AR握手后进READ_WAIT等rvalid，R握手拍即退休拍；写请求AW&W握手拍即完成（无B通道）。
//操作数不锁存：EX_reg保持至退休是既有契约（原DSRAM设计同依赖），组合派生自ex_*信号。
module RV32E_MEM(
	input					clk,
	input					rst,
	//上游：EXU的EX_reg输出（请求拍有效，握手前保持稳定）
	input					ex_valid,
	input					ex_mem_req,
	input					ex_mem_ren,
	input	[`RV32E_WIDTH-1:0]	ex_mem_addr,
	input					ex_mem_word_wen,
	input					ex_mem_half_wen,
	input					ex_mem_byte_wen,
	input	[`RV32E_WIDTH-1:0]	ex_mem_write_data,
	input	[15:0]			ex_mem_half_data,
	input	[7:0]			ex_mem_byte_data,
	input	[5:0]			ex_exu_op,
	//下游：AXI4-Lite主口（无B通道，发往LSU）
	output	[`RV32E_WIDTH-1:0]	axi_araddr,
	output					axi_arvalid,
	input					axi_arready,
	input	[`RV32E_WIDTH-1:0]	axi_rdata,
	input					axi_rvalid,
	output					axi_rready,
	output	[`RV32E_WIDTH-1:0]	axi_awaddr,
	output					axi_awvalid,
	input					axi_awready,
	output	[`RV32E_WIDTH-1:0]	axi_wdata,
	output	[3:0]			axi_wmask,
	output					axi_wvalid,
	input					axi_wready,
	//对WBU：访存完成（读=R握手拍，写=AW&W握手拍）
	output					mem_done_valid,
	input					mem_done_ready,
	output	reg	[`RV32E_WIDTH-1:0]	mem_done_rdata,
	//对EXU：请求握手完成（读=AR握手，写=AW&W握手）
	output					mem_ex_ready
);

	//请求与握手信号
	wire				req_wen = ex_mem_word_wen | ex_mem_half_wen | ex_mem_byte_wen;
	wire				ar_handshake = axi_arvalid & axi_arready;
	wire				write_handshake = axi_awvalid & axi_awready & axi_wvalid & axi_wready;

	reg state;
	localparam IDLE		= 1'd0;	//空闲：可发起新的访存请求
	localparam READ_WAIT	= 1'd1;	//读等待：AR已握手，等LSU返回rvalid

	always @(posedge clk) begin
		if(rst) begin
			state <= IDLE;
		end else begin
			case (state)
				IDLE: begin
					if(ar_handshake) begin
						state <= READ_WAIT;
					end
				end
				READ_WAIT: begin
					if(axi_rvalid && axi_rready) begin
						state <= IDLE;
					end
				end
				default: begin
					state <= IDLE;
				end
			endcase
		end
	end

	//AXI主口组合驱动：请求出现拍即可能握手，valid不依赖对侧ready
	assign axi_arvalid = ex_valid & ex_mem_req & ex_mem_ren;
	assign axi_araddr  = ex_mem_addr;
	assign axi_awvalid = ex_valid & ex_mem_req & req_wen;
	assign axi_awaddr  = ex_mem_addr;
	assign axi_wvalid  = axi_awvalid;
	//wmask为尺寸编码，wdata低位对齐（LSU转回len写在精确地址）
	assign axi_wmask   = ex_mem_byte_wen ? 4'b0001 : ex_mem_half_wen ? 4'b0011 : 4'b1111;
	assign axi_wdata   = ex_mem_byte_wen ? {24'b0, ex_mem_byte_data} :
	                     ex_mem_half_wen ? {16'b0, ex_mem_half_data} : ex_mem_write_data;

	//读数据接收就绪：读等待拍且WBU可接收完成数据
	assign axi_rready = (state == READ_WAIT) & mem_done_ready;

	//访存完成：写=AW&W握手拍，读=R握手拍（该拍即WBU退休拍）
	assign mem_done_valid = write_handshake | (axi_rvalid & axi_rready);
	//EXU释放：请求握手完成（读=AR握手后交由READ_WAIT跟踪，写=AW&W握手即完成）
	assign mem_ex_ready = ar_handshake | write_handshake;

	//load写回数据格式化：LSU返回地址处整字滑窗，按锁存op取低位做符号/零扩展
	always @(*) begin
		case (ex_exu_op)
			`LB:	mem_done_rdata = {{24{axi_rdata[7]}}, axi_rdata[7:0]};
			`LBU:	mem_done_rdata = {24'b0, axi_rdata[7:0]};
			`LH:	mem_done_rdata = {{16{axi_rdata[15]}}, axi_rdata[15:0]};
			`LHU:	mem_done_rdata = {16'b0, axi_rdata[15:0]};
			default:mem_done_rdata = axi_rdata;
		endcase
	end

endmodule
