module tb_i2c;
  reg clk, reset, start, rw;
  reg [6:0] master_addr;
  reg [7:0] master_wdata;
  reg [6:0] slave_addr;
  reg [7:0] slave_rdata;
  wire [7:0] master_rdata, slave_wdata;
  wire slave_data_valid;
  wire sda, sclk;

  I2C_master u_master(.clk(clk), .reset(reset), .start(start), .rw(rw),
    .slave_addr(master_addr), .data_in(master_wdata), .data_out(master_rdata),
    .sda(sda), .sclk(sclk));

  I2C_slave u_slave(.clk(clk), .reset(reset), .slave_addr(slave_addr),
    .data_in(slave_rdata), .data_out(slave_wdata), .data_valid(slave_data_valid),
    .sda(sda), .scl(sclk));

  pullup p_up (sda);   // bus pull-up for open drain SDA

  always #5 clk = ~clk;

  initial
    begin
      $dumpfile("tb_i2c.vcd");
      $dumpvars(0, tb_i2c);

      $monitor(" Time = %0t, valid = %b | slave_wdata = %0h | master_rdata = %0h", $time, slave_data_valid, slave_wdata, master_rdata);

      clk = 1'b0;
      reset = 1'b1;
      start = 1'b0;
      rw = 1'b0;
      master_addr = 7'h28;
      slave_addr  = 7'h28;
      master_wdata = 8'hA5;
      slave_rdata  = 8'hC3;
  #10 reset = 1'b0;

  // write 0xA5 to the slave
  #10 start = 1'b1;
  #200 start = 1'b0;   // hold start until the master samples it (sclk must be high)
  #4500 $display("slave received = %0h", slave_wdata);

  // read back from the slave
  #10 rw = 1'b1;
  #10 start = 1'b1;
  #200 start = 1'b0;
  #4500 $display("master read = %0h", master_rdata);

  #10 $finish;
    end
endmodule
