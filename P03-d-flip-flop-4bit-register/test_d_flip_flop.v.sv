module test_d_flip_flop;
  reg d;
  reg clk;
  reg reset;
  wire q;
  
  d_flip_flop d0( .d(d), .clk(clk), .reset(reset), .q(q));
  
  always #5 clk = ~clk;
  initial
    begin
      $dumpfile("test_d_flip_flop.vcd");
      $dumpvars(0, test_d_flip_flop);
      
      $monitor("Time = %0t | d = %b q = %b", $time, d, q);
      
        clk = 0;
        reset = 0;
        d = 0;
      
    #10 reset = 1;
      
    #10 reset = 0;
      
    #5  d = 1;
    #10;

    #2; 
        reset = 1;
    #3; 
     
    #5; 
      
        d = 0;
      
    #10 d = 1;
      
    #10 reset = 0;
        d = 1;
      
    #10 d = 0;
      
    #10; 
      
    #10 $finish;
    end
endmodule