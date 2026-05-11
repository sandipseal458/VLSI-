module test_one_to_four_demux;
  reg [3:0]x;
  reg [1:0]sel;
  wire [3:0]out0;
  wire [3:0]out1;
  wire [3:0]out2;
  wire [3:0]out3;
  integer i;
  
  one_to_four_demux m0(.x(x), .sel(sel), .out0(out0), .out1(out1), .out2(out2), .out3(out3));
  
  initial
    begin
      $dumpfile("one_to_four_demux.vcd");
      $dumpvars(0, test_one_to_four_demux);
      x = 4'b1111;
      $display("--- 4-bit DEMUX Test ---");
      
      $monitor ("[%0t] sel=0x%0h input=0x%0h out0=0x%0h out1=0x%0h out2=0x%0h out3=0x%0h", $time, sel, x, out0, out1, out2, out3);
      
      for(i=0;i<4;i=i+1)
        begin
          #5 sel=i;
        end
      #5 x=4'b0000;
         sel=2'b00;
      #5 x=4'b1010;
         sel=2'b10;
      #5;
      $finish;
    end
endmodule