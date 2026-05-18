module test_four_bit_shift_register;
  reg d;
  reg clk;
  reg reset;
  wire [3:0]q;

  four_bit_shift_register r0(.d(d), .q(q), .clk(clk), .reset(reset));

  always #5 clk = ~clk;
  initial
    begin
      $dumpfile("test_four_bit_shift_register.vcd");
      $dumpvars(0, test_four_bit_shift_register);

      $monitor("Time=%0t | d=%b out=%b", $time, d, q);
      
        clk   = 1'b0;
        d     = 1'b0;
        reset = 1'b1; 
      
        #20 reset = 1'b0;

        #10 d = 1'b1;  
        #10 d = 1'b0;  
        #10 d = 1'b1;  
        #10 d = 1'b1;  

        #10 reset = 1'b1;  
        #10 reset = 1'b0;

        #10 d = 1'b1;
        #10 d = 1'b1;
        #10 d = 1'b1;
        #10 d = 1'b1; 

        #10 $finish;
    end
endmodule