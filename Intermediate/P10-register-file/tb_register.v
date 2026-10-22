// -----------------------------------------------------------------------------
// tb_register.v
//
// Self-checking testbench for the 32 x 32-bit register file.
//
// The register file has one synchronous write port (wt_enable + w_add +
// w_data) and two asynchronous read ports (r_add1 / r_add2). The
// testbench keeps a golden model of all 32 words, applies every write on
// a real clock edge, and compares both read ports against the model.
//
// Covered scenarios
//   T1  synchronous reset clears every word to zero
//   T2  write then read back all 32 words through port 1
//   T3  port 2 reads a different address in the same cycle (true 2R1W)
//   T4  wt_enable low must not change the stored value
//   T5  both read ports pointed at the same address return the same word
//   T6  read-after-write on the same address sees the new value
//
// A watchdog turns a hang into a reported failure.
// -----------------------------------------------------------------------------

`timescale 1ns / 1ps

module tb_register;

  localparam CLK_PERIOD = 10;
  localparam WATCHDOG   = 100000;   // ns

  reg         clk;
  reg         reset;
  reg         wt_enable;
  reg  [4:0]  w_add, r_add1, r_add2;
  reg  [31:0] w_data;
  wire [31:0] r_data1, r_data2;

  // Golden model
  reg [31:0] exp_mem [0:31];
  integer i;
  integer errors = 0;
  integer tests  = 0;

  register dut (
      .clk      (clk),
      .reset    (reset),
      .wt_enable(wt_enable),
      .w_add    (w_add),
      .r_add1   (r_add1),
      .r_add2   (r_add2),
      .w_data   (w_data),
      .r_data1  (r_data1),
      .r_data2  (r_data2)
  );

  always #(CLK_PERIOD/2) clk = ~clk;

  // ---------------------------------------------------------------------
  // Helper tasks
  // ---------------------------------------------------------------------
  task check;
    input          condition;
    input [8*64:1] message;
    begin
      tests = tests + 1;
      if (condition === 1'b1)
        $display("[%0t] TB: PASS - %0s", $time, message);
      else begin
        errors = errors + 1;
        $display("[%0t] TB: FAIL - %0s", $time, message);
      end
    end
  endtask

  // One registered write, driven at the negedge so it is stable at posedge
  task write_reg;
    input [4:0]  addr;
    input [31:0] data;
    begin
      @(negedge clk);
      w_add     = addr;
      w_data    = data;
      wt_enable = 1'b1;
      @(negedge clk);
      wt_enable = 1'b0;
      exp_mem[addr] = data;
    end
  endtask

  // Point both read ports somewhere and let the asynchronous read settle
  task set_read_ports;
    input [4:0] addr1;
    input [4:0] addr2;
    begin
      r_add1 = addr1;
      r_add2 = addr2;
      #1;
    end
  endtask

  // ---------------------------------------------------------------------
  // Test sequence
  // ---------------------------------------------------------------------
  initial begin
    $dumpfile("tb_register.vcd");
    $dumpvars(0, tb_register);

    clk       = 1'b0;
    reset     = 1'b1;
    wt_enable = 1'b0;
    w_add     = 5'd0;
    r_add1    = 5'd0;
    r_add2    = 5'd0;
    w_data    = 32'h0000_0000;

    for (i = 0; i < 32; i = i + 1)
      exp_mem[i] = 32'h0000_0000;

    $display("");
    $display("=========================================================");
    $display(" 32 x 32 register file testbench");
    $display("=========================================================");

    // T1 - synchronous reset clears everything
    repeat (2) @(posedge clk);
    @(negedge clk);
    reset = 1'b0;
    #1;
    for (i = 0; i < 32; i = i + 1) begin
      set_read_ports(i[4:0], i[4:0]);
      if (r_data1 !== 32'h0000_0000 || r_data2 !== 32'h0000_0000) begin
        errors = errors + 1;
        $display("[%0t] TB: FAIL - T1 word %0d not cleared (p1=%h p2=%h)",
                 $time, i, r_data1, r_data2);
      end
    end
    tests = tests + 1;
    if (errors == 0)
      $display("[%0t] TB: PASS - T1 reset cleared all 32 words", $time);

    // T2 - write all 32 words, read them back on port 1
    $display("[%0t] TB: T2 - write and read back all 32 words", $time);
    for (i = 0; i < 32; i = i + 1)
      write_reg(i[4:0], {27'd0, i[4:0]} ^ 32'hDEAD_0000);

    for (i = 0; i < 32; i = i + 1) begin
      set_read_ports(i[4:0], 5'd0);
      if (r_data1 !== exp_mem[i]) begin
        errors = errors + 1;
        $display("[%0t] TB: FAIL - T2 word %0d = %h, expected %h",
                 $time, i, r_data1, exp_mem[i]);
      end
    end
    tests = tests + 1;
    $display("[%0t] TB: T2 done (%0d errors so far)", $time, errors);

    // T3 - both ports read different addresses in the same cycle
    $display("[%0t] TB: T3 - dual-port read of two different words", $time);
    set_read_ports(5'd3, 5'd29);
    check(r_data1 === exp_mem[3] && r_data2 === exp_mem[29],
          "T3 port1 and port2 return their own addresses");

    // T4 - wt_enable low must not write
    $display("[%0t] TB: T4 - write attempt with wt_enable low", $time);
    @(negedge clk);
    w_add     = 5'd7;
    w_data    = 32'hBAD0_BAD0;
    wt_enable = 1'b0;
    @(negedge clk);
    set_read_ports(5'd7, 5'd7);
    check(r_data1 === exp_mem[7], "T4 word 7 unchanged while wt_enable low");

    // T5 - both read ports on the same address
    $display("[%0t] TB: T5 - both read ports on the same address", $time);
    set_read_ports(5'd11, 5'd11);
    check(r_data1 === r_data2 && r_data1 === exp_mem[11],
          "T5 port1 and port2 agree on address 11");

    // T6 - read-after-write on the same address
    $display("[%0t] TB: T6 - read-after-write on address 0", $time);
    write_reg(5'd0, 32'hFEED_FACE);
    set_read_ports(5'd0, 5'd0);
    check(r_data1 === 32'hFEED_FACE, "T6 new value visible right after the write");

    // Summary
    $display("");
    $display("=========================================================");
    if (errors == 0)
      $display(" RESULT: PASSED  (%0d checks)", tests);
    else
      $display(" RESULT: FAILED  (%0d of %0d checks failed)", errors, tests);
    $display("=========================================================");
    $display("");

    if (errors != 0) begin
      $display("TB: %0d error(s) detected", errors);
      $stop;
    end
    $finish;
  end

  // Global watchdog
  initial begin
    #(WATCHDOG);
    $display("[%0t] TB: FAIL - watchdog expired, simulation hung", $time);
    $display(" RESULT: FAILED  (watchdog)");
    $stop;
  end

endmodule
