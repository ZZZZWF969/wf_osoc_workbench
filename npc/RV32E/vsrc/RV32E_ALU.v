`include "RV32E.vh"

module RV32E_ALU(
    input   [`RV32E_WIDTH-1:0]	src1,
    input   [`RV32E_WIDTH-1:0]	src2,
    input   [`RV32E_WIDTH-1:0]	cmp_src1,
    input   [`RV32E_WIDTH-1:0]	cmp_src2,
    input   [3:0]				op,
    output  reg [`RV32E_WIDTH-1:0]	result,
    output  					zero,
    output  					slt,
    output  					sltu
);

    wire [`RV32E_WIDTH-1:0] diff = cmp_src1 - cmp_src2;

    assign zero = (diff == 0);
    assign slt  = $signed(cmp_src1) < $signed(cmp_src2);
    assign sltu = (cmp_src1 < cmp_src2);

    always @(*) begin
        case (op)
            `ALU_ADD:  result = src1 + src2;
            `ALU_SUB:  result = src1 - src2;
            `ALU_SLT:  result = {31'b0, slt};
            `ALU_SLTU: result = {31'b0, sltu};
            `ALU_AND:  result = src1 & src2;
            `ALU_OR:   result = src1 | src2;
            `ALU_XOR:  result = src1 ^ src2;
            `ALU_SLL:  result = src1 << src2[4:0];
            `ALU_SRL:  result = src1 >> src2[4:0];
            `ALU_SRA:  result = $signed(src1) >>> src2[4:0];
            default:   result = 0;
        endcase
    end

endmodule
