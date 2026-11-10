module modbus_master (
    input clk, reset, start, rx,
    output tx,
    output reg busy, done, crc_ok
);

parameter SILENCE = 1280;      // 208320 for 50 MHz clock and 9600 baud
parameter TIMEOUT = 4000;      // waiting time for the first reply byte

parameter
      S_IDLE = 3'd0,
      S_SEND = 3'd1,
      S_SEND_W = 3'd2,
      S_REPLY = 3'd3,
      S_CHECK = 3'd4;

reg [2:0] state;
reg [2:0] req;                 // which request is sent now, goes 0 to 4 and repeats
reg [3:0] idx;
reg [3:0] rx_count;
reg [7:0] rx_buf [0:8];        // reply bytes
reg [17:0] timer;
reg start_prev, rdy_prev;

wire rdy, tx_busy, crc_busy;
wire [7:0] rx_data;
wire [15:0] crc;
reg rdy_clr, wt_enable, crc_init, crc_en;
reg [7:0] tx_data;

uart_rx_top urx(.clk(clk), .reset(reset), .rx(rx), .rdy_clr(rdy_clr), .rdy(rdy), .data_out(rx_data));
uart_tx_top utx(.clk(clk), .reset(reset), .wt_enable(wt_enable), .data_in(tx_data), .tx(tx), .busy(tx_busy));
crc16_modbus mcrc(.clk(clk), .reset(reset), .init(crc_init), .en(crc_en), .data_in(tx_data), .crc(crc), .busy(crc_busy));

// request 0 : read 2 registers      request 1 : write 0003 in register 1
// request 2 : read again            request 3 : read with a damaged crc
// request 4 : read from slave 02 (nobody there)
reg [7:0] next_byte;
always @(*)
begin
    case (idx)
        4'd0: next_byte = (req == 3'd4) ? 8'h02 : 8'h01;
        4'd1: next_byte = (req == 3'd1) ? 8'h06 : 8'h03;
        4'd3: next_byte = (req == 3'd1) ? 8'h01 : 8'h00;
        4'd5: next_byte = (req == 3'd1) ? 8'h03 : 8'h02;
        4'd6: next_byte = (req == 3'd3) ? (crc[7:0] ^ 8'h01) : crc[7:0];   // crc low byte first
        4'd7: next_byte = crc[15:8];
        default: next_byte = 8'h00;
    endcase
end

always @(posedge clk)
begin
    if (reset)
    begin
        state <= S_IDLE;
        req <= 3'd0;
        idx <= 4'd0;
        rx_count <= 4'd0;
        timer <= 18'd0;
        busy <= 1'b0;
        done <= 1'b0;
        crc_ok <= 1'b0;
        start_prev <= 1'b0;
        rdy_prev <= 1'b0;
        rdy_clr <= 1'b0;
        wt_enable <= 1'b0;
        crc_init <= 1'b1;
        crc_en <= 1'b0;
        tx_data <= 8'd0;
    end
    else
    begin
        rdy_clr <= 1'b0;       // one clock pulses
        wt_enable <= 1'b0;
        crc_init <= 1'b0;
        crc_en <= 1'b0;
        start_prev <= start;
        rdy_prev <= rdy;

        case (state)
            S_IDLE:
            begin
                if (start && !start_prev)
                begin
                    busy <= 1'b1;
                    done <= 1'b0;
                    idx <= 4'd0;
                    crc_init <= 1'b1;
                    state <= S_SEND;
                end
            end

            S_SEND:
            begin
                if (tx_busy == 1'b0 && crc_busy == 1'b0)
                begin
                    if (idx == 4'd8)               // request is sent, now listen
                    begin
                        rx_count <= 4'd0;
                        timer <= 18'd0;
                        crc_init <= 1'b1;
                        state <= S_REPLY;
                    end
                    else
                    begin
                        tx_data <= next_byte;
                        wt_enable <= 1'b1;
                        if (idx < 4'd6)
                            crc_en <= 1'b1;        // crc of the request bytes
                        idx <= idx + 4'd1;
                        state <= S_SEND_W;
                    end
                end
            end

            S_SEND_W: state <= S_SEND;             // wait one clock so uart shows busy

            S_REPLY:
            begin
                if (rdy && !rdy_prev)              // reply byte came
                begin
                    if (rx_count < 9)
                        rx_buf[rx_count] <= rx_data;
                    if (rx_count < 15)
                        rx_count <= rx_count + 4'd1;
                    tx_data <= rx_data;            // crc block checks the reply bytes
                    crc_en <= 1'b1;
                    rdy_clr <= 1'b1;
                    timer <= 18'd0;
                end
                else if ((rx_count == 0 && timer == TIMEOUT) || (rx_count != 0 && timer == SILENCE))
                    state <= S_CHECK;              // reply is over, or no reply at all
                else
                    timer <= timer + 18'd1;
            end

            S_CHECK:
            begin
                if (crc_busy == 1'b0)
                begin
                    crc_ok <= (rx_count >= 4) && (crc == 16'h0000);
                    busy <= 1'b0;
                    done <= 1'b1;
                    req <= (req == 3'd4) ? 3'd0 : req + 3'd1;
                    state <= S_IDLE;
                end
            end

            default: state <= S_IDLE;
        endcase
    end
end

endmodule
