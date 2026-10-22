module register (
    input clk, reset,
    input wt_enable,
    input [4:0] w_add, r_add1, r_add2,
    input [31:0] w_data,
    output [31:0] r_data1, r_data2
);
    reg [31:0] memory [0:31];
    integer i;

    always @(posedge clk)
    begin
        if (reset) begin
            for(i = 0; i < 32; i = i + 1) begin
                memory[i] <= 0;
            end
        end else if (wt_enable) begin
            memory[w_add] <= w_data;
        end
    end
    assign r_data1 = memory[r_add1]; 
    assign r_data2 = memory[r_add2]; 
endmodule
