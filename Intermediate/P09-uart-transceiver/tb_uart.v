// -----------------------------------------------------------------------------
// tb_uart.v
//
// Self-checking testbench for the UART loopback (uart_top).
//
// uart_top wires its own transmitter output back into its receiver input,
// so every byte pushed in must come out again on data_out. The testbench
// drives four representative bytes through the loopback, waits for the
// receiver to assert rdy (with a timeout so a hang is reported instead of
// freezing the run), and compares the received byte against what was sent.
//
// Covered scenarios
//   T1  alternating pattern 0x55  (0101_0101 - toggles every bit)
//   T2  alternating pattern 0xAA  (1010_1010 - the complement of T1)
//   T3  all-zero byte       0x00  (longest low run, checks the stop bit)
//   T4  all-ones byte       0xFF  (line idles high through the data field)
//
// Each test reports PASS/FAIL, and a final summary prints the total number
// of failed checks. A watchdog turns an infinite wait into a reported fail.
// -----------------------------------------------------------------------------

`timescale 1ns / 1ps

module tb_uart;

  localparam CLK_PERIOD = 10;      // 100 MHz simulation clock
  localparam RDY_TIMEOUT = 120000; // clock cycles: one byte takes ~57500 cycles
  localparam WATCHDOG    = 10000000; // ns: whole-simulation watchdog

  reg        clk;
  reg        reset;
  reg        wt_enable;
  reg        rdy_clr;
  reg  [7:0] data_in;

  wire        rdy;
  wire        busy;
  wire  [7:0] data_out;

  integer errors = 0;
  integer tests  = 0;

  uart_top dut (
      .clk       (clk),
      .reset     (reset),
      .wt_enable (wt_enable),
      .rdy_clr   (rdy_clr),
      .data_in   (data_in),
      .rdy       (rdy),
      .busy      (busy),
      .data_out  (data_out)
  );

  always #(CLK_PERIOD/2) clk = ~clk;

  // ---------------------------------------------------------------------
  // Helper tasks (Verilog-2001 style, no SystemVerilog needed)
  // ---------------------------------------------------------------------
  task check;
    input            condition;
    input [8*64:1]   message;
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

  task send_byte;
    input [7:0] din;
    begin
      @(negedge clk);
      wt_enable = 1'b1;
      data_in   = din;
      @(negedge clk);
      wt_enable = 1'b0;
    end
  endtask

  task clear_ready;
    begin
      @(negedge clk);
      rdy_clr = 1'b1;
      @(negedge clk);
      rdy_clr = 1'b0;
    end
  endtask

  // Wait until the transmitter is free again (bounded, so a dead FSM
  // shows up as a FAIL instead of a frozen simulation).
  task wait_busy_clear;
    integer guard;
    begin
      guard = 0;
      while (busy === 1'b1 && guard < RDY_TIMEOUT) begin
        @(posedge clk);
        guard = guard + 1;
      end
      check(busy === 1'b0, "transmitter released busy");
    end
  endtask

  // Wait for the receiver to present the byte (bounded).
  task wait_byte;
    input [7:0] expected;
    integer     guard;
    begin
      guard = 0;
      while (rdy !== 1'b1 && guard < RDY_TIMEOUT) begin
        @(posedge clk);
        guard = guard + 1;
      end
      check(rdy === 1'b1, "receiver asserted rdy");
      if (rdy === 1'b1)
        check(data_out === expected, "loopback byte matches what was sent");
      clear_ready;
    end
  endtask

  // ---------------------------------------------------------------------
  // Test sequence
  // ---------------------------------------------------------------------
  initial begin
    $dumpfile("tb_uart.vcd");
    $dumpvars(0, tb_uart);

    clk       = 1'b0;
    reset     = 1'b1;
    wt_enable = 1'b0;
    rdy_clr   = 1'b0;
    data_in   = 8'h00;

    repeat (5) @(posedge clk);
    reset = 1'b0;
    repeat (5) @(posedge clk);

    $display("");
    $display("=========================================================");
    $display(" UART loopback testbench (baud rate generator + TX + RX)");
    $display("=========================================================");

    // T1 - 0x55
    $display("[%0t] TB: T1 - send 0x55", $time);
    send_byte(8'h55);
    wait_busy_clear;
    wait_byte(8'h55);

    // T2 - 0xAA
    $display("[%0t] TB: T2 - send 0xAA", $time);
    send_byte(8'hAA);
    wait_busy_clear;
    wait_byte(8'hAA);

    // T3 - 0x00
    $display("[%0t] TB: T3 - send 0x00", $time);
    send_byte(8'h00);
    wait_busy_clear;
    wait_byte(8'h00);

    // T4 - 0xFF
    $display("[%0t] TB: T4 - send 0xFF", $time);
    send_byte(8'hFF);
    wait_busy_clear;
    wait_byte(8'hFF);

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
