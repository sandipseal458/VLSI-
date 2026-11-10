module tx_baud_generator (
    input clk,
    output tx_enable);

    reg [12:0] tx_count = 13'd0;

    always @(posedge clk)
    begin
        if(tx_count == 31)           // 5208 for 50 MHz clock and 9600 baud
          tx_count <= 0;
        else
          tx_count <= tx_count + 13'd1;
    end

    assign tx_enable = (tx_count == 0) ? 1'b1 : 1'b0;
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
      IDLE = 3'd0,
      START = 3'd1,
      DATA_IN = 3'd2,
      STOP1 = 3'd3,
      STOP2 = 3'd4;

reg [2:0] state;
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
                        tx    <= 1'b1;          // first stop bit
                        state <= STOP1;
                    end
                    else
                    begin
                        data_count <= data_count + 3'd1;
                        tx         <= data_reg[data_count + 3'd1];
                    end
                end

                STOP1:
                begin
                    tx    <= 1'b1;              // second stop bit
                    state <= STOP2;
                end

                STOP2:
                begin
                    tx    <= 1'b1;
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

module uart_tx_top(
    input clk, reset, wt_enable,
    input [7:0]data_in,
    output tx, busy
    );

wire tx_clk_enable;
tx_baud_generator tbg(.clk(clk), .tx_enable(tx_clk_enable));
transmitter tx_inst(.clk(clk), .reset(reset), .wt_enable(wt_enable), .enable(tx_clk_enable), .data_in(data_in), .tx(tx), .busy(busy));

endmodule
