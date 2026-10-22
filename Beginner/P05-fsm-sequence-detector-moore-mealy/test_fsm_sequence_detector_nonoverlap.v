module test_fsm_sequence_detector_nonoverlap;
  reg in;
  reg clk;
  reg reset;
  wire out_moore;
  wire out_mealy;

  // Instantiate both the Moore and Mealy FSMs
  fsm_sequence_detector_moore_nonoverlap f0(.clk(clk), .in(in), .reset(reset), .out_moore(out_moore));
  fsm_sequence_detector_mealy_nonoverlap f1(.clk(clk), .in(in), .reset(reset), .out_mealy(out_mealy));

  always #10 clk = ~clk;

  initial
    begin
      $dumpfile("test_fsm_sequence_detector_nonoverlap.vcd");
      $dumpvars(0, test_fsm_sequence_detector_nonoverlap);
      $monitor(" Time = %0t | input = %b, reset = %b, out_moore = %b, out_mealy = %b", $time, in, reset, out_moore, out_mealy);

      clk = 0;
      reset = 1;
      in = 0;

      repeat (5) @ (posedge clk);
       reset = 0;
      // Test 1
      @(posedge clk) in <= 0;
      @(posedge clk) in <= 1;
      @(posedge clk) in <= 1;
      @(posedge clk) in <= 0;
      @(posedge clk) in <= 1;
      @(posedge clk) in <= 0;
      @(posedge clk) in <= 1;
      @(posedge clk) in <= 1;
      @(posedge clk) in <= 0;
      @(posedge clk) in <= 1;
      @(posedge clk) in <= 0;
      @(posedge clk) in <= 1;
      @(posedge clk) in <= 1;

      // Test 2

      @(posedge clk) in <= 1;
      @(posedge clk) in <= 0;
      @(posedge clk) in <= 1;
      @(posedge clk) in <= 0;

      // Test 3
      @(posedge clk) in <= 1;
      @(posedge clk) in <= 0;
      @(posedge clk) in <= 1;
      reset = 1;
      @(posedge clk);
      reset = 0;
      // Test 4
      @(posedge clk) in <= 1;
      @(posedge clk) in <= 0;
      @(posedge clk) in <= 1;
      @(posedge clk) in <= 1;

      #50 $finish;
    end
endmodule