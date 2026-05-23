module test_fsm_sequence_detector_overlap;
  reg in;
  reg clk;
  reg reset;
  wire out_moore;
  wire out_mealy;

  // Instantiate both the Moore and Mealy FSMs

  fsm_sequence_detector_moore_overlap f0(.clk(clk), .in(in), .reset(reset), .out_moore(out_moore));

  fsm_sequence_detector_mealy_overlap f1(.clk(clk), .in(in), .reset(reset), .out_mealy(out_mealy));

  always #10 clk = ~clk;

  initial
    begin
      $dumpfile("test_fsm_sequence_detector_overlap.vcd");

      $dumpvars(0, test_fsm_sequence_detector_overlap);

      $monitor(" Time = %0t | input = %b, reset = %b, out_moore = %b, out_mealy = %b", $time, in, reset, out_moore, out_mealy);

      clk = 0;
      reset = 1;
      in = 0;

      repeat (3) @ (posedge clk);
       reset = 0;

       // Test 1: Classic overlapping stream

        @(posedge clk) in <= 1;
        @(posedge clk) in <= 0;
        @(posedge clk) in <= 1;
        @(posedge clk) in <= 1;
        @(posedge clk) in <= 0;
        @(posedge clk) in <= 1;
        @(posedge clk) in <= 1;
        @(posedge clk) in <= 0;

        // Test 2: Triple overlapping

        @(posedge clk) in <= 1;
        @(posedge clk) in <= 0;
        @(posedge clk) in <= 1;
        @(posedge clk) in <= 1;
        @(posedge clk) in <= 1;
        @(posedge clk) in <= 0;
        @(posedge clk) in <= 1;
        @(posedge clk) in <= 1;
        @(posedge clk) in <= 0;

        // Test 3: False overlap - partial match after detection

        @(posedge clk) in <= 1;
        @(posedge clk) in <= 0;
        @(posedge clk) in <= 1;
        @(posedge clk) in <= 1;
        @(posedge clk) in <= 1;
        @(posedge clk) in <= 0;
        @(posedge clk) in <= 1;
        @(posedge clk) in <= 0;

        // TEST 4: Reset mid-overlap

        @(posedge clk) in <= 1;
        @(posedge clk) in <= 0;
        @(posedge clk) in <= 1;
        @(posedge clk) in <= 1;
        @(posedge clk) in <= 1;
        reset = 1;
        @(posedge clk);
        reset = 0;
        @(posedge clk) in <= 0;
        @(posedge clk) in <= 1;
        @(posedge clk) in <= 1;

        #50 $finish;
    end

endmodule