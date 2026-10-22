// -----------------------------------------------------------------------------
// tb_i2c.v
//
// Self-checking testbench for the I2C master / slave pair.
//
// The testbench is written at protocol level: it drives the master through
// its normal handshake, monitors the bus, and checks the outcome of every
// transaction against an expected value. Nothing is poked into the DUT
// internals, so the same testbench keeps working if the RTL is refactored.
//
// Covered scenarios
//   T1  single byte write   : master -> slave, byte checked on the slave
//   T2  second byte write   : back-to-back write, checks the bus can be reused
//   T3  single byte read    : slave -> master, byte checked on the master
//   T4  address mismatch    : slave must not ACK and must not latch data
//   T5  write then read     : two transactions in a row on the same bus
//   T6  reset recovery      : reset in the middle, bus works again after
//
// Every transaction is bounded by a timeout, and a global watchdog reports
// a hang instead of letting the simulation run forever.
// -----------------------------------------------------------------------------

`timescale 1ns / 1ps

module tb_i2c;

  // ---------------------------------------------------------------------
  // Clock and reset
  // ---------------------------------------------------------------------
  localparam CLK_PERIOD   = 10;      // 100 MHz simulation clock
  localparam TX_TIMEOUT   = 5000;    // ns, budget for one I2C transaction
  localparam WATCHDOG     = 200000;  // ns, whole-simulation watchdog

  reg clk = 1'b0;
  reg reset = 1'b1;

  always #(CLK_PERIOD/2) clk = ~clk;

  // ---------------------------------------------------------------------
  // DUT connections
  // ---------------------------------------------------------------------
  reg        start = 1'b0;
  reg        rw = 1'b0;             // 0 = write, 1 = read
  reg  [6:0] master_addr = 7'h28;
  reg  [7:0] master_wdata = 8'h00;
  reg  [6:0] slave_addr = 7'h28;    // address the slave answers to
  reg  [7:0] slave_rdata = 8'hC3;   // byte the slave returns on a read

  wire [7:0] master_rdata;
  wire [7:0] slave_wdata;
  wire       slave_data_valid;
  wire       sclk;
  wire       sda;

  I2C_master u_master (
      .clk      (clk),
      .reset    (reset),
      .start    (start),
      .rw       (rw),
      .slave_addr(master_addr),
      .data_in  (master_wdata),
      .data_out (master_rdata),
      .sda      (sda),
      .sclk     (sclk)
  );

  I2C_slave u_slave (
      .clk        (clk),
      .reset      (reset),
      .slave_addr (slave_addr),
      .data_in    (slave_rdata),
      .data_out   (slave_wdata),
      .data_valid (slave_data_valid),
      .sda        (sda),
      .scl        (sclk)
  );

  // I2C is an open-drain bus: the pull-up resistor is what makes the line
  // read HIGH when nobody drives it.
  pullup p_up (sda);

  // ---------------------------------------------------------------------
  // Verification bookkeeping
  // ---------------------------------------------------------------------
  integer errors = 0;
  integer tests  = 0;

  reg [7:0] rx_log [0:15];   // bytes actually latched by the slave
  integer  rx_count = 0;

  // The slave pulses data_valid for one clock when it has latched a byte.
  always @(posedge clk) begin
    if (slave_data_valid) begin
      rx_log[rx_count] = slave_wdata;
      rx_count         = rx_count + 1;
      $display("[%0t] TB: slave latched 0x%02h", $time, slave_wdata);
    end
  end

  // SCL edge counter, used to follow the progress of a transaction
  integer scl_rise_cnt = 0;
  always @(posedge sclk) scl_rise_cnt = scl_rise_cnt + 1;

  // ---------------------------------------------------------------------
  // Helper tasks
  // ---------------------------------------------------------------------
  task check;
    input        condition;
    input [8*64:1] message;
    begin
      tests = tests + 1;
      if (condition) begin
        $display("[%0t] TB: PASS - %0s", $time, message);
      end else begin
        errors = errors + 1;
        $display("[%0t] TB: FAIL - %0s", $time, message);
      end
    end
  endtask

  // Release the bus and wait until the master has finished the transaction.
  // A transaction is 18 SCL edges: 8 address + ACK + 8 data + ACK.
  task wait_transaction;
    input integer expected_edges;
    integer    base_cnt;
    integer    guard;
    begin
      base_cnt = scl_rise_cnt;
      guard    = 0;
      while ((scl_rise_cnt - base_cnt) < expected_edges && guard < (TX_TIMEOUT/CLK_PERIOD)) begin
        @(posedge clk);
        guard = guard + 1;
      end
      // let the STOP condition settle on the bus
      repeat (20) @(posedge clk);
    end
  endtask

  // Master write transaction: address + data byte.
  task i2c_write;
    input [6:0] addr;
    input [7:0] data;
    begin
      @(negedge clk);
      master_addr  = addr;
      master_wdata = data;
      rw           = 1'b0;
      start        = 1'b1;
      // The master needs `start` until it actually drives the START
      // condition, so hold it until SDA falls.
      @(negedge sda);
      @(negedge clk);
      start = 1'b0;
      wait_transaction(18);
    end
  endtask

  // Master read transaction: address only, the slave returns one byte.
  task i2c_read;
    input [6:0] addr;
    begin
      @(negedge clk);
      master_addr = addr;
      rw          = 1'b1;
      start       = 1'b1;
      @(negedge sda);
      @(negedge clk);
      start = 1'b0;
      wait_transaction(18);
    end
  endtask

  // ---------------------------------------------------------------------
  // Test sequence
  // ---------------------------------------------------------------------
  integer before_count;

  initial begin
    $dumpfile("tb_i2c.vcd");
    $dumpvars(0, tb_i2c);

    // reset
    reset = 1'b1;
    repeat (5) @(posedge clk);
    reset = 1'b0;
    repeat (5) @(posedge clk);

    $display("");
    $display("=========================================================");
    $display(" I2C master / slave testbench");
    $display("=========================================================");

    // ---------------------------------------------------------------
    // T1 - single byte write
    // ---------------------------------------------------------------
    $display("[%0t] TB: T1 - write 0xA5 to slave 0x28", $time);
    before_count = rx_count;
    i2c_write(7'h28, 8'hA5);
    check(rx_count == before_count + 1, "T1 slave latched exactly one byte");
    check(rx_log[before_count] == 8'hA5, "T1 written data is 0xA5");

    // ---------------------------------------------------------------
    // T2 - second write on the same bus
    // ---------------------------------------------------------------
    $display("[%0t] TB: T2 - write 0x5A to slave 0x28", $time);
    before_count = rx_count;
    i2c_write(7'h28, 8'h5A);
    check(rx_count == before_count + 1, "T2 slave latched exactly one byte");
    check(rx_log[before_count] == 8'h5A, "T2 written data is 0x5A");

    // ---------------------------------------------------------------
    // T3 - single byte read
    // ---------------------------------------------------------------
    $display("[%0t] TB: T3 - read from slave 0x28", $time);
    i2c_read(7'h28);
    check(master_rdata == 8'hC3, "T3 master read back 0xC3");

    // ---------------------------------------------------------------
    // T4 - address mismatch, the slave must not ACK and must not latch
    // ---------------------------------------------------------------
    $display("[%0t] TB: T4 - write to address 0x29 (slave is 0x28)", $time);
    before_count = rx_count;
    i2c_write(7'h29, 8'h77);
    check(rx_count == before_count, "T4 slave ignored the data byte");

    // ---------------------------------------------------------------
    // T5 - write followed immediately by a read
    // ---------------------------------------------------------------
    $display("[%0t] TB: T5 - write 0x11 then read 0x22", $time);
    before_count = rx_count;
    i2c_write(7'h28, 8'h11);
    check(rx_log[before_count] == 8'h11, "T5 first transaction wrote 0x11");
    slave_rdata = 8'h22;
    i2c_read(7'h28);
    check(master_rdata == 8'h22, "T5 second transaction read 0x22");

    // ---------------------------------------------------------------
    // T6 - reset in the middle of the session
    // ---------------------------------------------------------------
    $display("[%0t] TB: T6 - reset recovery", $time);
    reset = 1'b1;
    repeat (5) @(posedge clk);
    reset = 1'b0;
    repeat (5) @(posedge clk);
    before_count = rx_count;
    i2c_write(7'h28, 8'h99);
    check(rx_count == before_count + 1, "T6 slave latched a byte after reset");
    check(rx_log[before_count] == 8'h99, "T6 written data is 0x99 after reset");

    // ---------------------------------------------------------------
    // Summary
    // ---------------------------------------------------------------
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

  // ---------------------------------------------------------------------
  // Global watchdog
  // ---------------------------------------------------------------------
  initial begin
    #(WATCHDOG);
    $display("[%0t] TB: FAIL - watchdog expired, simulation hung", $time);
    $display(" RESULT: FAILED  (watchdog)");
    $stop;
  end

endmodule
