module d_flip_flop(d, q, clk, reset);
  input d;
  input clk;
  input reset;
  output reg q;
  
  
  always @(posedge clk)
     begin
       if(reset)
         q<=1'b0;
       else
         q<=d;
     end
endmodule
