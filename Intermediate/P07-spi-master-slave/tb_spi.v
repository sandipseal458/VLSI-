// -----------------------------------------------------------------------------
// tb_spi.v
//
// Self-checking testbench for the SPI master / slave pair (Mode 0 style:
// data sampled on the rising edge of sclk, shifted out on the falling edge).
//
// The testbench fires several byte exchanges through the bus and checks
// both directions of the full-duplex link every time:
//
//   master_tx -> MOSI -> slave_rx
//   slave_tx  -> MISO -> master_rx
//
// It also checks that the chip-select line behaves like a frame boundary:
// low while a byte is in flight, high again once the byte is complete.
//
// Covered scenarios
//   T1  first exchange  (0xA5 / 0x3C)
//   T2  second exchange with the values swapped
//   T3  boundary bytes  (0x00 / 0xFF)
//   T4  chip-select is low during the frame and high again after it
//
// A watchdog turns a hung transaction into a reported failure.
// -----------------------------------------------------------------------------

`timescale 1ns / 1ps

module tb_spi;

  localparam CLK_PERIOD = 10;
  localparam FRAME_TIME = 1000;    // ns, one 8-bit frame at this sclk rate
  localparam WATCHDOG   = 100000;  // ns

  reg        clk;
  reg        load;
  reg  [7:0] master_tx_data;
  reg  [7:0] slave_tx_data;

  wire [7:0] master_rx_data;
  wire [7:0] slave_rx_data;
  wire       sclk;
  wire       MOSI;
  wire       MISO;
  wire       CS;

  integer errors = 0;
  integer tests  = 0;

  SPI_Master u_master (
      .clk     (clk),
      .load    (load),
      .tx_data (master_tx_data),
      .rx_data (master_rx_data),
      .sclk    (sclk),
      .MOSI    (MOSI),
      .MISO    (MISO),
      .CS      (CS)
  );

  SPI_Slave u_slave (
      .tx_data (slave_tx_data),
      .rx_data (slave_rx_data),
      .sclk    (sclk),
      .MOSI    (MOSI),
      .MISO    (MISO),
      .CS      (CS)
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

  // Start one 8-bit full-duplex frame and check the bus while it runs
  task exchange;
    input [7:0] m_tx;
    input [7:0] s_tx;
    begin
      @(negedge clk);
      master_tx_data = m_tx;
      slave_tx_data  = s_tx;
      load           = 1'b1;
      @(negedge clk);
      load = 1'b0;

      // CS must be low while the frame is in flight
      #(FRAME_TIME / 4);
      check(CS === 1'b0, "CS is low while the frame is in flight");

      // Wait for the master to finish the frame (CS returns high)
      begin : wait_frame
        integer guard;
        guard = 0;
        while (CS !== 1'b1 && guard < FRAME_TIME) begin
          @(posedge clk);
          guard = guard + 1;
        end
      end
      check(CS === 1'b1, "CS returns high after the frame");
    end
  endtask

  // ---------------------------------------------------------------------
  // Test sequence
  // ---------------------------------------------------------------------
  initial begin
    $dumpfile("tb_spi.vcd");
    $dumpvars(0, tb_spi);

    clk            = 1'b0;
    load           = 1'b0;
    master_tx_data = 8'h00;
    slave_tx_data  = 8'h00;

    $display("");
    $display("=========================================================");
    $display(" SPI master / slave full-duplex testbench");
    $display("=========================================================");

    // T1 - first exchange
    $display("[%0t] TB: T1 - exchange 0xA5 <-> 0x3C", $time);
    exchange(8'hA5, 8'h3C);
    check(master_rx_data === 8'h3C, "T1 master received the slave byte 0x3C");
    check(slave_rx_data  === 8'hA5, "T1 slave received the master byte 0xA5");

    // T2 - values swapped
    $display("[%0t] TB: T2 - exchange 0x3C <-> 0xA5", $time);
    exchange(8'h3C, 8'hA5);
    check(master_rx_data === 8'hA5, "T2 master received the slave byte 0xA5");
    check(slave_rx_data  === 8'h3C, "T2 slave received the master byte 0x3C");

    // T3 - boundary bytes
    $display("[%0t] TB: T3 - exchange 0x00 <-> 0xFF", $time);
    exchange(8'h00, 8'hFF);
    check(master_rx_data === 8'hFF, "T3 master received 0xFF");
    check(slave_rx_data  === 8'h00, "T3 slave received 0x00");

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
