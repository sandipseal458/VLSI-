module four_to_one_mux(x, y, z, w, sel, out);
  input [3:0]x;
  input [3:0]y;
  input [3:0]z;
  input [3:0]w;
  input [1:0]sel;
  output reg [3:0]out;
  
  always @(*)
    begin
      case (sel)
         2'b00:  out = x;
         2'b01:  out = y;
         2'b10:  out = z;
         2'b11:  out = w;
      default: out = 4'b0000;
      endcase
    end   
endmodule
           
        
