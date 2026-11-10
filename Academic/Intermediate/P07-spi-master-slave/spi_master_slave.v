module SPI_Master(clk, load, tx_data, rx_data, sclk, MOSI, MISO, CS);
  input [7:0] tx_data;
  input load, clk, MISO;
  output reg [7:0] rx_data;
  output reg sclk, MOSI, CS;

  reg [7:0] shift_data;
  reg [1:0] count;
  reg [3:0] bit_count;
  reg prev_sclk;
  reg active;

  always @(posedge clk) begin
    if (load) begin
      shift_data <= tx_data;
      count      <= 2'd0;
      bit_count  <= 4'd0;
      sclk       <= 1'b0;
      prev_sclk  <= 1'b0;
      CS         <= 1'b0;
      active     <= 1'b1;
      MOSI       <= tx_data[7];
    end else if (active) begin
      count     <= count + 2'd1;
      sclk      <= count[1];
      prev_sclk <= sclk;

      // Rising edge of sclk: Sample MISO
      if (sclk == 1'b1 && prev_sclk == 1'b0) begin
        shift_data <= {shift_data[6:0], MISO};
        if (bit_count < 4'd7) begin
          bit_count <= bit_count + 4'd1;
        end else begin
          rx_data <= {shift_data[6:0], MISO};
          CS      <= 1'b1;
          active  <= 1'b0;
        end
      end

      // Falling edge of sclk: Shift out next MOSI bit
      if (sclk == 1'b0 && prev_sclk == 1'b1) begin
        MOSI <= shift_data[7];
      end
    end else begin
      sclk      <= 1'b0;
      prev_sclk <= 1'b0;
    end
  end
endmodule

module SPI_Slave(tx_data, rx_data, sclk, MOSI, MISO, CS);
  input sclk, CS, MOSI;
  input [7:0] tx_data;
  output reg [7:0] rx_data;
  output reg MISO;

  reg [3:0] bit_count;
  reg [7:0] shift_data;

  // Load tx_data on CS falling edge
  always @(negedge CS) begin
    shift_data <= tx_data;
    MISO       <= tx_data[7];
    bit_count  <= 4'd0;
  end

  // Sample MOSI on posedge sclk
  always @(posedge sclk) begin
    if (!CS) begin
      if (bit_count < 4'd7) begin
        shift_data <= {shift_data[6:0], MOSI};
        bit_count  <= bit_count + 4'd1;
      end else begin
        rx_data <= {shift_data[6:0], MOSI};
      end
    end
  end

  // Drive MISO on negedge sclk
  always @(negedge sclk) begin
    if (!CS) begin
      MISO <= shift_data[7];
    end
  end
endmodule
