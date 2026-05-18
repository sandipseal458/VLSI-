 module four_bit_shift_register(d, q, clk, reset);
  input d;
  input clk;
  input reset;
  output reg [3:0]q;
   
  always @(posedge clk)
    begin
    if(reset)
      q <= 4'b0000;
    else
      q <= {q[2:0], d};
    end
endmodule   