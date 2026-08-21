`include "../vcode/include/RV32E.vh"

module ysyx_25060166_REG_ARRAY(
    input               clk,
    input               rst,
    input               wen,
    input   [4:0]       raddr1,
    input   [4:0]       raddr2,
    input   [4:0]       write_rd,
    input   [`ysyx_25060166_WIDTH-1:0]  write_data,
    output  [`ysyx_25060166_WIDTH-1:0]  read_data_1,
    output  [`ysyx_25060166_WIDTH-1:0]  read_data_2
);

    reg [`ysyx_25060166_WIDTH-1:0]  rs1_data;
    reg [`ysyx_25060166_WIDTH-1:0]  rs2_data;

    assign read_data_1 = rs1_data;
    assign read_data_2 = rs2_data;

    reg [`ysyx_25060166_WIDTH-1:0] reg_array [0:`ysyx_25060166_REG_NUM-1];

    always @(*) begin
        rs1_data = reg_array[raddr1];
        rs2_data = reg_array[raddr2];
    end

    always @(posedge clk) begin
        if(rst) begin
            integer i;
            for (i = 0; i < `ysyx_25060166_WIDTH; i = i + 1) begin
                reg_array[i] <= 0;
            end
        end else begin
            if (wen) begin
                if (write_rd != 0) begin
                    reg_array[write_rd] <= write_data;
                end else begin
                    reg_array[write_rd] <= 0;
                end
            end
        end
    end



endmodule
