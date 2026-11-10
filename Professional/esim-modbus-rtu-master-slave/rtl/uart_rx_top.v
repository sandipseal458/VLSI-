module rx_baud_generator (
    input clk,
    output rx_enable);

    reg [8:0] rx_count = 9'd0;

    always @(posedge clk)
    begin
        if(rx_count == 1)            // 325 for 50 MHz clock and 9600 baud
          rx_count <= 0;
        else
          rx_count <= rx_count + 9'd1;
    end

    assign rx_enable = (rx_count == 0) ? 1'b1 : 1'b0;
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

module uart_rx_top(
    input clk, reset, rx, rdy_clr,
    output rdy,
    output [7:0]data_out
    );

wire rx_clk_enable;
rx_baud_generator rbg(.clk(clk), .rx_enable(rx_clk_enable));
receiver rx_inst(.clk(clk), .reset(reset), .rx(rx), .rdy_clr(rdy_clr), .clk_en(rx_clk_enable), .rdy(rdy), .data_out(data_out));

endmodule
