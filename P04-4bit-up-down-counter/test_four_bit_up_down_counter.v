module test_four_bit_up_down_counter;
  reg clk;
  reg ebl;
  reg reset;
  reg up_down;
  wire [3:0]out;
  
  four_bit_up_down_counter c0(.clk(clk), .ebl(ebl), .up_down(up_down), .reset(reset), .out(out));
  
  always #5 clk = ~clk;
  
  initial
    begin
      $dumpfile("test_four_bit_up_down_counter.vcd");
      $dumpvars(0, test_four_bit_up_down_counter);
      
      $monitor(" Time = %0t | enable = %b, reset = %b, up-down = %b output = %b (%0d)", $time, ebl, reset, up_down, out, out);
      
        clk     = 0;
        reset   = 1;   
        up_down = 1;  
        ebl     = 1;  

        #20 reset = 0;
        #50;
        #10 ebl = 0;
        #20;           
        #10 ebl = 1;
        #20;           
        #10 reset = 1;
        #10 reset = 0;
        #10 up_down = 0;
        #40;
        #10 reset = 1;
        #10 reset = 0;
        #20 $finish;
    end
endmodule
      
      
      
