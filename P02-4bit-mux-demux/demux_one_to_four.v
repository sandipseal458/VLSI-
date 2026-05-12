module one_to_four_demux(x, sel, out0, out1, out2, out3);
  input [3:0]x;
  input [1:0]sel;
  output reg [3:0]out0;
  output reg [3:0]out1;
  output reg [3:0]out2;
  output reg [3:0]out3;
  
  always @(*)
    begin
      case (sel)
         2'b00:  out0 = x;
         2'b01:  out1 = x;
         2'b10:  out2 = x;
         2'b11:  out3 = x;
      default: 
        begin
                 out0 = 4'b0000;
                 out1 = 4'b0000;
                 out2 = 4'b0000;
                 out3 = 4'b0000;
        end
      endcase
    end   
endmodule
           
        
