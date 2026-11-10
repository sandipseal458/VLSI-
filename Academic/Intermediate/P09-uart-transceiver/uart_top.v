module baud_rate_generator (
    input clk, 
    output tx_enable, rx_enable);

   reg [12:0] tx_count = 13'd0;
    reg [8:0] rx_count = 9'd0;

    always @(posedge clk)
    begin
        if(tx_count == 5208)
          tx_count <= 0;
        else
          tx_count <= tx_count + 13'd1;
    end

    always @(posedge clk)
    begin
        if(rx_count == 325)
          rx_count <= 0;
        else
          rx_count <= rx_count + 9'd1;
    end

    assign tx_enable = (tx_count == 0) ? 1'b1 : 1'b0;
    assign rx_enable = (rx_count == 0) ? 1'b1 : 1'b0;   
endmodule
module transmitter (
    input clk,
    input reset,
    input [7:0]data_in,
    input wt_enable, enable,
    output reg tx,
    output busy
);
parameter 
      IDLE = 2'd0,
      START = 2'd1,
      DATA_IN = 2'd2,
      STOP = 2'd3;

reg [1:0] state;
reg [7:0] data_reg;
reg [2:0] data_count;
reg       pending;      // byte waiting to be sent

always @(posedge clk)
begin
    if (reset)
    begin
        state      <= IDLE;
        tx         <= 1'b1;
        data_reg   <= 8'd0;
        data_count <= 3'd0;
        pending    <= 1'b0;
    end
    else
    begin
        if (wt_enable && state == IDLE && pending == 1'b0)
        begin
            data_reg <= data_in;
            pending  <= 1'b1;
        end

        if (enable)
        begin
            case (state)
                IDLE:
                begin
                    if (pending)
                    begin
                        pending <= 1'b0;
                        tx      <= 1'b0;   // start bit
                        state   <= START;
                    end
                    else
                        tx <= 1'b1;        // line stays idle high
                end

                START:
                begin
                    tx         <= data_reg[0];  // first data bit
                    data_count <= 3'd0;
                    state      <= DATA_IN;
                end

                DATA_IN:
                begin
                    if (data_count == 3'd7)
                    begin
                        tx    <= 1'b1;          // stop bit
                        state <= STOP;
                    end
                    else
                    begin
                        data_count <= data_count + 3'd1;
                        tx         <= data_reg[data_count + 3'd1];
                    end
                end

                STOP:
                begin
                    tx    <= 1'b1;              // stop bit finished
                    state <= IDLE;
                end

                default:
                begin
                    tx    <= 1'b1;
                    state <= IDLE;
                end
            endcase
        end
    end
end

assign busy = (state != IDLE) | pending;

endmodule

module receiver(
    input clk, reset, rx, rdy_clr, clk_en,
    output reg rdy,
    output reg [7:0]data_out
);

parameter 
      START = 2'd1,
      DATA_OUT = 2'd2,
      STOP = 2'd3;

reg [1:0] state;
reg [7:0] data_reg;
reg [2:0] data_count;
reg [3:0] data_sample;
reg       armed;      // start-bit falling edge seen
reg       prev_rx;

always @(posedge clk)
begin
    if (reset)
    begin
        state       <= START;
        rdy         <= 1'b0;
        data_out    <= 8'd0;
        data_reg    <= 8'd0;
        data_count  <= 3'd0;
        data_sample <= 4'd0;
        armed       <= 1'b0;
        prev_rx     <= 1'b1;
    end
    else
    begin
        if (rdy_clr)
            rdy <= 1'b0;

        if (clk_en)
        begin
            prev_rx <= rx;

            case (state)
                START:
                begin
                    if (armed == 1'b0)
                    begin
                        if (prev_rx && !rx)       // falling edge -> start bit
                        begin
                            armed       <= 1'b1;
                            data_sample <= 4'd0;
                        end
                    end
                    else if (rx == 1'b1)          // false start, resync
                    begin
                        armed       <= 1'b0;
                        data_sample <= 4'd0;
                    end
                    else if (data_sample == 4'd7) // middle of start bit
                    begin
                        armed       <= 1'b0;
                        data_sample <= 4'd0;
                        data_count  <= 3'd0;
                        data_reg    <= 8'd0;
                        state       <= DATA_OUT;
                    end
                    else
                        data_sample <= data_sample + 4'd1;
                end

                DATA_OUT:
                begin
                    if (data_sample == 4'd15)
                    begin
                        data_sample <= 4'd0;
                        data_reg[data_count] <= rx;
                        if (data_count == 3'd7)
                        begin
                            data_count <= 3'd0;
                            state      <= STOP;
                        end
                        else
                            data_count <= data_count + 3'd1;
                    end
                    else
                        data_sample <= data_sample + 4'd1;
                end

                STOP:
                begin
                    if (data_sample == 4'd15)
                    begin
                        data_sample <= 4'd0;
                        if (rx == 1'b1)
                        begin
                            data_out <= data_reg;
                            rdy      <= 1'b1;
                        end
                        state <= START;
                    end
                    else
                        data_sample <= data_sample + 4'd1;
                end

                default:
                begin
                    state <= START;
                end
            endcase
        end
    end
end

endmodule
module uart_top(
    input clk, reset, wt_enable, rdy_clr,
    input [7:0]data_in,
    output rdy, busy,
    output[7:0]data_out
    );

wire tx_clk_enable, rx_clk_enable;
wire tx_temp;
baud_rate_generator brg(.clk(clk), .tx_enable(tx_clk_enable), .rx_enable(rx_clk_enable));
transmitter tx_inst(.clk(clk), .reset(reset), .wt_enable(wt_enable), .enable(tx_clk_enable), .data_in(data_in), .tx(tx_temp), .busy(busy));
  receiver rx_inst(.clk(clk), .reset(reset), .rx(tx_temp), .rdy_clr(rdy_clr), .clk_en(rx_clk_enable), .rdy(rdy), .data_out(data_out));

endmodule



 