module I2C_master (
    input clk,
    input reset,
    input start,
    input rw,                  // 0 = Write, 1 = Read
    input [6:0] slave_addr,
    input [7:0] data_in,       // Data byte to write to slave
    output reg [7:0] data_out, // Data byte read from slave
    inout sda,
    output reg sclk
);
parameter IDLE       = 4'd1,
          START      = 4'd2,
          SLAVE_ADD  = 4'd3,
          ACK        = 4'd4,
          WRITE_DATA = 4'd5,
          READ_DATA  = 4'd6,
          ACK_WAIT   = 4'd7,
          STOP       = 4'd8,
          DONE       = 4'd9;

reg [3:0] state, next_state;
reg [7:0] data_reg;
reg [7:0] slave_address_reg; // 7-bit address + 1-bit R/W
reg [2:0] bit_count;
reg sda_drive;
reg ack_received;
reg shift_bit;
reg prev_sclk;
wire sclk_pos;
wire sclk_fall;
reg [9:0] sclk_counter;

// Clock generation for SCLK
always @(posedge clk or posedge reset) begin
    if (reset) begin
        sclk_counter <= 10'd0;
        sclk         <= 1'b0;
    end else if (sclk_counter == 10'd9) begin
        sclk_counter <= 10'd0;
        sclk         <= ~sclk;
    end else begin
        sclk_counter <= sclk_counter + 1'b1;
    end
end

// Tri-state buffer for Open-Drain SDA (sda_drive = 1 pulls line LOW)
assign sda       = sda_drive ? 1'b0 : 1'bz;
assign sclk_rise = ~prev_sclk && sclk;
assign sclk_fall = prev_sclk && ~sclk;

// State machine sequential logic
always @(posedge clk or posedge reset) begin
    if (reset) begin
        state             <= IDLE;
        slave_address_reg <= 8'd0;
        data_reg          <= 8'd0;
        data_out          <= 8'd0;
        bit_count         <= 3'd7;
        ack_received      <= 1'b0;
        prev_sclk         <= 1'b0;
    end else begin
        state     <= next_state;
        prev_sclk <= sclk;

        if (state == IDLE) begin
            slave_address_reg <= {slave_addr, rw}; // Combine 7-bit addr + R/W bit input
            data_reg          <= data_in;
            bit_count         <= 3'd7;
            ack_received      <= 1'b0;
        end

        if (shift_bit)
            bit_count <= bit_count - 1'b1;

        if (state == READ_DATA && sclk_rise)
            data_out[bit_count] <= sda; // Sample read data from slave

        if ((state == ACK || state == ACK_WAIT) && sclk)
            ack_received <= ~sda; // ACK is active LOW (sda == 0)

        if ((state == ACK || state == ACK_WAIT) && sclk_fall)
            bit_count <= 3'd7;
    end
end

// State machine combinational logic
always @(*) begin
    next_state = state;
    sda_drive  = 1'b0;
    shift_bit  = 1'b0;

    case (state)
        IDLE: begin
            sda_drive  = 1'b0;
            // Begin a transaction only while SCL is HIGH: SDA falling while
            // SCL is high is what the slave detects as a valid START condition.
            next_state = (start && sclk) ? START : IDLE;
        end

        START: begin
            sda_drive = 1'b1; // Drive SDA low for START condition
            if (sclk_fall)
                next_state = SLAVE_ADD;
        end

        SLAVE_ADD: begin
            sda_drive = ~slave_address_reg[bit_count]; // Drive address bit + R/W bit
            if (sclk_fall) begin
                if (bit_count == 3'd0)
                    next_state = ACK;
                else
                    shift_bit = 1'b1;
            end
        end

        ACK: begin
            sda_drive = 1'b0; // Release SDA to read ACK
            if (sclk_fall) begin
                if (ack_received) begin
                    if (slave_address_reg[0] == 1'b1)
                        next_state = READ_DATA;  // R/W = 1 -> Read mode
                    else
                        next_state = WRITE_DATA; // R/W = 0 -> Write mode
                end else begin
                    next_state = STOP; // NACK received
                end
            end
        end

        WRITE_DATA: begin
            sda_drive = ~data_reg[bit_count]; // Drive data byte to slave
            if (sclk_fall) begin
                if (bit_count == 3'd0)
                    next_state = ACK_WAIT;
                else
                    shift_bit = 1'b1;
            end
        end

        READ_DATA: begin
            sda_drive = 1'b0; // Release SDA to read data byte from slave
            if (sclk_fall) begin
                if (bit_count == 3'd0)
                    next_state = ACK_WAIT; // Master sends ACK/NACK
                else
                    shift_bit = 1'b1;
            end
        end

        ACK_WAIT: begin
            if (slave_address_reg[0] == 1'b1)
                sda_drive = 1'b0; // Send NACK (release SDA) after reading byte
            else
                sda_drive = 1'b0; // Release SDA to read slave ACK after writing byte

            if (sclk_fall)
                next_state = STOP;
        end

        STOP: begin
            sda_drive = 1'b1; // Pull SDA LOW
            if (sclk) begin
                sda_drive  = 1'b0; // Release SDA HIGH while SCLK is HIGH -> STOP
                next_state = DONE;
            end
        end

        DONE: begin
            sda_drive  = 1'b0;
            next_state = IDLE;
        end

        default: begin
            next_state = IDLE;
            sda_drive  = 1'b0;
        end
    endcase
end

endmodule
