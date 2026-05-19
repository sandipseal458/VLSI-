module four_bit_up_down_counter(clk, ebl, reset, up_down, out);
  input clk;
  input ebl;
  input reset;
  input up_down;
  output reg [3:0]out;
  
  always @(posedge clk)
    begin
      if (reset)
          out <= 4'b0000;       
        else if (ebl) 
          begin      
            if (up_down)
                out <= out + 1;  
            else
                out <= out - 1;   
          end
    end
endmodule