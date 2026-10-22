// -----------------------------------------------------------------------------
// I2C_slave.v
//
// Simple I2C slave (receiver / transmitter) used together with I2C_master.v.
//
// Protocol handling:
//   * START  : SDA pulled low while SCL is high
//   * STOP   : SDA released high while SCL is high
//   * ADDRESS: 7-bit slave address followed by one R/W bit, MSB first
//   * ACK    : slave pulls SDA low during the 9th clock of every byte
//
// The slave latches the address, compares it with its own and either
// accepts the byte (ACK) or ignores the transaction. When the master
// writes, the received byte appears on data_out with data_valid asserted
// for one clock. When the master reads, data_in is shifted out on SDA.
//
// Open-drain convention: driving the line means pulling it LOW, releasing
// it means letting the pull-up resistor take it HIGH.
// -----------------------------------------------------------------------------

module I2C_slave (
    input clk,
    input reset,
    input [6:0] slave_addr,
    input [7:0] data_in,
    output reg [7:0] data_out,
    output reg data_valid,
    inout sda,
    input scl
);

parameter IDLE       = 4'd1,
          SLAVE_ADD  = 4'd2,
          ACK        = 4'd3,
          WRITE_DATA = 4'd4,
          ACK_WAIT   = 4'd5,
          READ_DATA  = 4'd6,
          STOP       = 4'd7;

reg [3:0] state, next_state;
reg [7:0] data_reg;
reg [7:0] slave_address_reg;
reg [2:0] bit_count;
reg sda_drive;
reg shift_bit;
reg rw_bit;
reg bit_armed;          // set once the first bit of a byte has been sampled

reg prev_scl;
reg prev_sda;
wire scl_rise  = ~prev_scl && scl;
wire scl_fall = prev_scl && ~scl;
wire sda_fall = prev_sda && ~sda;
wire sda_rise = ~prev_sda && sda;

// Simple START & STOP condition logic
wire start_cond = scl && sda_fall; // SDA falls while SCL is HIGH
wire stop_cond  = scl && sda_rise; // SDA rises while SCL is HIGH

// Tri-state buffer for Open-Drain SDA (sda_drive = 1 pulls line LOW)
assign sda = sda_drive ? 1'b0 : 1'bz;

// State machine sequential logic
always @(posedge clk or posedge reset) begin
    if (reset) begin
        state             <= IDLE;
        slave_address_reg <= 8'd0;
        data_reg          <= 8'd0;
        data_out          <= 8'd0;
        data_valid        <= 1'b0;
        bit_count         <= 3'd7;
        bit_armed         <= 1'b0;
        rw_bit            <= 1'b0;
        prev_scl          <= 1'b1;
        prev_sda          <= 1'b1;
    end else begin
        state      <= next_state;
        prev_scl   <= scl;
        prev_sda   <= sda;
        data_valid <= 1'b0;

        if (start_cond) begin
            state             <= SLAVE_ADD;
            bit_count         <= 3'd7;
            bit_armed         <= 1'b0;
            slave_address_reg <= 8'd0;
        end else if (stop_cond) begin
            state <= IDLE;
        end else begin
            // The bit counter is advanced on the falling edge of SCL, but only
            // once a bit has actually been sampled. Otherwise the falling edge
            // that terminates the START condition would be counted as a bit
            // and the address would be shifted by one position.
            if (shift_bit && bit_armed)
                bit_count <= bit_count - 1'b1;

            // Address phase: sample the address MSB first, the 8th bit is R/W
            if (state == SLAVE_ADD && scl_rise) begin
                slave_address_reg[bit_count] <= sda;
                bit_armed <= 1'b1;

                if (bit_count == 3'd0)
                    rw_bit <= sda;            // 8th bit is R/W
            end

            // Write phase: sample the data byte MSB first
            if (state == WRITE_DATA && scl_rise) begin
                data_reg[bit_count] <= sda;

                if (bit_count == 3'd0) begin
                    data_out   <= {data_reg[7:1], sda};
                    data_valid <= 1'b1;
                end
            end

            if ((state == ACK || state == ACK_WAIT) && scl_fall)
                bit_count <= 3'd7;
        end
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
            next_state = IDLE;
        end

        SLAVE_ADD: begin
            sda_drive = 1'b0; // Release SDA to read address from Master
            if (scl_fall) begin
                if (bit_count == 3'd0) begin
                    if (slave_address_reg[7:1] == slave_addr)
                        next_state = ACK;
                    else
                        next_state = IDLE; // Address mismatch
                end else begin
                    shift_bit = 1'b1;
                end
            end
        end

        ACK: begin
            sda_drive = 1'b1; // Send ACK (pull SDA LOW) to Master
            if (scl_fall) begin
                if (rw_bit == 1'b1)
                    next_state = READ_DATA;  // Master wants to READ
                else
                    next_state = WRITE_DATA; // Master wants to WRITE
            end
        end

        WRITE_DATA: begin
            sda_drive = 1'b0; // Release SDA to read data from Master
            if (scl_fall) begin
                if (bit_count == 3'd0)
                    next_state = ACK_WAIT;
                else
                    shift_bit = 1'b1;
            end
        end

        ACK_WAIT: begin
            sda_drive = 1'b1; // Send ACK (pull SDA LOW) for data byte
            if (scl_fall)
                next_state = WRITE_DATA;
        end

        READ_DATA: begin
            sda_drive = ~data_in[bit_count]; // Drive data_in bit onto SDA
            if (scl_fall) begin
                if (bit_count == 3'd0)
                    next_state = STOP;
                else
                    shift_bit = 1'b1;
            end
        end

        STOP: begin
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
