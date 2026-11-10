module modbus_slave (
    input clk, reset, rx,
    output tx,
    output reg crc_ok, reg_hit
);

parameter SLAVE_ADDR = 8'h01;
parameter SILENCE = 1280;      // 40 bit times = 3.5 characters + 1.5 bits, 208320 for 50 MHz and 9600 baud

parameter
      S_WAIT = 4'd0,
      S_CHECK = 4'd1,
      S_DECODE = 4'd2,
      S_READ_REGS = 4'd3,
      S_CRC_INIT = 4'd4,
      S_CRC_FEED = 4'd5,
      S_CRC_W1 = 4'd6,
      S_CRC_W2 = 4'd7,
      S_CRC_ADD = 4'd8,
      S_SEND = 4'd9,
      S_SEND_W1 = 4'd10,
      S_SEND_W2 = 4'd11,
      S_DONE = 4'd12;

reg [3:0] state;

// register file of the slave (8 registers, 16 bit each)
reg [15:0] regs [0:7];

// frame buffers
reg [7:0] rx_buf [0:7];
reg [7:0] tx_buf [0:12];
reg [3:0] rx_count;
reg [3:0] tx_len;
reg [3:0] idx;
reg [3:0] qty;
reg [2:0] start_reg;

// silence timer
reg [17:0] silence_count;

// uart receiver side
wire rdy;
wire [7:0] rx_data;
reg rdy_clr;
reg rdy_prev;

// uart transmitter side
wire tx_busy;
reg wt_enable;
reg [7:0] tx_data;

// crc engines (one checks the request, one makes the reply crc)
reg rx_crc_init, rx_crc_en;
reg [7:0] rx_crc_data;
wire [15:0] rx_crc;
wire rx_crc_busy;

reg tx_crc_init, tx_crc_en;
reg [7:0] tx_crc_data;
wire [15:0] tx_crc;
wire tx_crc_busy;

uart_rx_top urx(.clk(clk), .reset(reset), .rx(rx), .rdy_clr(rdy_clr), .rdy(rdy), .data_out(rx_data));
uart_tx_top utx(.clk(clk), .reset(reset), .wt_enable(wt_enable), .data_in(tx_data), .tx(tx), .busy(tx_busy));
crc16_modbus rcrc(.clk(clk), .reset(reset), .init(rx_crc_init), .en(rx_crc_en), .data_in(rx_crc_data), .crc(rx_crc), .busy(rx_crc_busy));
crc16_modbus tcrc(.clk(clk), .reset(reset), .init(tx_crc_init), .en(tx_crc_en), .data_in(tx_crc_data), .crc(tx_crc), .busy(tx_crc_busy));

always @(posedge clk)
begin
    if (reset)
    begin
        state         <= S_WAIT;
        crc_ok        <= 1'b0;
        reg_hit       <= 1'b0;
        rx_count      <= 4'd0;
        tx_len        <= 4'd0;
        idx           <= 4'd0;
        qty           <= 4'd0;
        start_reg     <= 3'd0;
        silence_count <= 18'd0;
        rdy_clr       <= 1'b0;
        rdy_prev      <= 1'b0;
        wt_enable     <= 1'b0;
        tx_data       <= 8'd0;
        rx_crc_init   <= 1'b1;
        rx_crc_en     <= 1'b0;
        rx_crc_data   <= 8'd0;
        tx_crc_init   <= 1'b0;
        tx_crc_en     <= 1'b0;
        tx_crc_data   <= 8'd0;
        regs[0] <= 16'h000A;
        regs[1] <= 16'h0102;
        regs[2] <= 16'h0304;
        regs[3] <= 16'h0506;
        regs[4] <= 16'h0000;
        regs[5] <= 16'h0000;
        regs[6] <= 16'h0000;
        regs[7] <= 16'h0000;
    end
    else
    begin
        // these are one clock pulses
        rdy_clr     <= 1'b0;
        wt_enable   <= 1'b0;
        rx_crc_init <= 1'b0;
        rx_crc_en   <= 1'b0;
        tx_crc_init <= 1'b0;
        tx_crc_en   <= 1'b0;
        rdy_prev    <= rdy;

        case (state)
            S_WAIT:
            begin
                // a new byte came from the uart
                if (rdy && !rdy_prev)
                begin
                    if (rx_count < 8)
                        rx_buf[rx_count] <= rx_data;
                    if (rx_count < 15)
                        rx_count <= rx_count + 4'd1;
                    rx_crc_data   <= rx_data;
                    rx_crc_en     <= 1'b1;
                    rdy_clr       <= 1'b1;
                    silence_count <= 18'd0;
                end
                else if (silence_count < SILENCE)
                    silence_count <= silence_count + 18'd1;
                else if (rx_count != 0)      // line was silent long enough, frame is over
                    state <= S_CHECK;
            end

            S_CHECK:
            begin
                // crc of the whole frame (with its crc bytes) must come out as 0000
                if (rx_crc_busy == 1'b0)
                begin
                    reg_hit <= 1'b0;
                    if (rx_count >= 4 && rx_crc == 16'h0000)
                    begin
                        crc_ok <= 1'b1;
                        if (rx_buf[0] == SLAVE_ADDR)
                            state <= S_DECODE;
                        else
                            state <= S_DONE;     // frame for some other slave
                    end
                    else
                    begin
                        crc_ok <= 1'b0;
                        state  <= S_DONE;        // bad crc, no reply
                    end
                end
            end

            S_DECODE:
            begin
                reg_hit    <= 1'b1;
                tx_buf[0]  <= SLAVE_ADDR;
                if (rx_buf[1] == 8'h03 && rx_count == 8)
                begin
                    // read holding registers
                    qty       <= rx_buf[5][3:0];
                    start_reg <= rx_buf[3][2:0];
                    if (rx_buf[4] != 8'd0 || rx_buf[5] == 8'd0 || rx_buf[5] > 8'd4)
                    begin
                        tx_buf[1] <= 8'h83;
                        tx_buf[2] <= 8'h03;      // illegal data value
                        tx_len    <= 4'd3;
                        state     <= S_CRC_INIT;
                    end
                    else if (rx_buf[2] != 8'd0 || rx_buf[3] > 8'd7 || (rx_buf[3] + rx_buf[5]) > 8'd8)
                    begin
                        tx_buf[1] <= 8'h83;
                        tx_buf[2] <= 8'h02;      // illegal data address
                        tx_len    <= 4'd3;
                        state     <= S_CRC_INIT;
                    end
                    else
                    begin
                        tx_buf[1] <= 8'h03;
                        tx_buf[2] <= {3'd0, rx_buf[5][3:0], 1'b0};   // byte count = 2 x qty
                        tx_len    <= 4'd3 + {rx_buf[5][2:0], 1'b0};
                        idx       <= 4'd0;
                        state     <= S_READ_REGS;
                    end
                end
                else if (rx_buf[1] == 8'h06 && rx_count == 8)
                begin
                    // write single register
                    if (rx_buf[2] != 8'd0 || rx_buf[3] > 8'd7)
                    begin
                        tx_buf[1] <= 8'h86;
                        tx_buf[2] <= 8'h02;      // illegal data address
                        tx_len    <= 4'd3;
                    end
                    else
                    begin
                        regs[rx_buf[3][2:0]] <= {rx_buf[4], rx_buf[5]};
                        tx_buf[1] <= 8'h06;      // reply is the same as the request
                        tx_buf[2] <= rx_buf[2];
                        tx_buf[3] <= rx_buf[3];
                        tx_buf[4] <= rx_buf[4];
                        tx_buf[5] <= rx_buf[5];
                        tx_len    <= 4'd6;
                    end
                    state <= S_CRC_INIT;
                end
                else
                begin
                    tx_buf[1] <= rx_buf[1] | 8'h80;
                    tx_buf[2] <= 8'h01;          // illegal function
                    tx_len    <= 4'd3;
                    state     <= S_CRC_INIT;
                end
            end

            S_READ_REGS:
            begin
                tx_buf[3 + {idx[2:0], 1'b0}] <= regs[start_reg + idx[2:0]][15:8];
                tx_buf[4 + {idx[2:0], 1'b0}] <= regs[start_reg + idx[2:0]][7:0];
                if (idx == qty - 4'd1)
                    state <= S_CRC_INIT;
                else
                    idx <= idx + 4'd1;
            end

            S_CRC_INIT:
            begin
                tx_crc_init <= 1'b1;
                idx         <= 4'd0;
                state       <= S_CRC_FEED;
            end

            S_CRC_FEED:
            begin
                if (idx == tx_len)
                    state <= S_CRC_ADD;
                else
                begin
                    tx_crc_data <= tx_buf[idx];
                    tx_crc_en   <= 1'b1;
                    idx         <= idx + 4'd1;
                    state       <= S_CRC_W1;
                end
            end

            S_CRC_W1: state <= S_CRC_W2;         // give the crc block one clock to start

            S_CRC_W2:
            begin
                if (tx_crc_busy == 1'b0)
                    state <= S_CRC_FEED;
            end

            S_CRC_ADD:
            begin
                tx_buf[tx_len]     <= tx_crc[7:0];     // low byte first
                tx_buf[tx_len + 1] <= tx_crc[15:8];
                tx_len             <= tx_len + 4'd2;
                idx                <= 4'd0;
                state              <= S_SEND;
            end

            S_SEND:
            begin
                if (idx == tx_len)
                    state <= S_DONE;
                else if (tx_busy == 1'b0)
                begin
                    tx_data   <= tx_buf[idx];
                    wt_enable <= 1'b1;
                    idx       <= idx + 4'd1;
                    state     <= S_SEND_W1;
                end
            end

            S_SEND_W1: state <= S_SEND_W2;       // give the uart one clock to become busy

            S_SEND_W2:
            begin
                if (tx_busy == 1'b0)
                    state <= S_SEND;
            end

            S_DONE:
            begin
                rx_count      <= 4'd0;
                silence_count <= 18'd0;
                rx_crc_init   <= 1'b1;
                state         <= S_WAIT;
            end

            default: state <= S_WAIT;
        endcase
    end
end

endmodule
