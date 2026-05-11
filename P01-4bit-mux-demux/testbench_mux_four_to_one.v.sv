module test_four_to_one_mux;
  reg [3:0]x;
  reg [3:0]y;
  reg [3:0]z;
  reg [3:0]w;
  reg [1:0]sel;
  wire [3:0]out;
  integer i;
  
  four_to_one_mux m0(.x(x), .y(y), .z(z), .w(w), .sel(sel), .out(out));
  
  initial
    begin
      $dumpfile("four_to_one_mux.vcd");
      $dumpvars(0, test_four_to_one_mux);
      x = 4'b0101;
      y = 4'b1010;
      z = 4'b1100;
      w = 4'b0011;
      
      $display("--- 4-bit MUX Test ---");
      
      $monitor ("[%0t] sel=0x%0h a=0x%0h b=0x%0h c=0x%0h d=0x%0h out=0x%0h", $time, sel, x, y, z, w, out);
      
      for(i=0;i<4;i=i+1)
        begin
          #5 sel=i;
        end
      #5;
      $finish;
    end
endmodule