module SPI_testbench;
  reg clk, load;
  reg [7:0] master_tx_data, slave_tx_data;
  
  wire [7:0] master_rx_data, slave_rx_data;
  wire sclk, MOSI, MISO, CS;
  
  SPI_Master m0(.clk(clk), .load(load), .tx_data(master_tx_data), .rx_data(master_rx_data), .sclk(sclk), .MOSI(MOSI), .MISO(MISO), .CS(CS));
  
  SPI_Slave s0(.tx_data(slave_tx_data), .rx_data(slave_rx_data), .sclk(sclk), .MOSI(MOSI), .MISO(MISO), .CS(CS));
  
  always #5 clk = ~clk;
  
  initial
    begin
      $dumpfile("SPI_testbench.vcd");
      $dumpvars(0, SPI_testbench);
      
      $monitor(" Time = %0t, CS = %b | master_tx_data = %0x, master_rx_data = %0x | slave_tx_data = %0x, slave_rx_data = %0x ", $time, CS, master_tx_data, master_rx_data, slave_tx_data, slave_rx_data );
      
      clk = 1'b0;
      load = 1'b0;
      master_tx_data = 8'hA5;
      slave_tx_data = 8'h3C;
  #10 load = 1'b1;
  #10 load = 1'b0;              
      
  #400 $finish;
    end
endmodule