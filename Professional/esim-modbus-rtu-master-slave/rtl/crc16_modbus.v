module crc16_modbus (
    input clk, reset, init, en,
    input [7:0]data_in,
    output reg [15:0]crc,
    output busy
);

reg [3:0] bit_count;
reg       running;      // byte is being shifted in

always @(posedge clk)
begin
    if (reset || init)
    begin
        crc       <= 16'hFFFF;
        bit_count <= 4'd0;
        running   <= 1'b0;
    end
    else if (en && running == 1'b0)
    begin
        crc       <= crc ^ {8'h00, data_in};   // xor byte into low byte
        bit_count <= 4'd0;
        running   <= 1'b1;
    end
    else if (running)
    begin
        if (crc[0])
            crc <= (crc >> 1) ^ 16'hA001;
        else
            crc <= crc >> 1;

        if (bit_count == 4'd7)
            running <= 1'b0;
        else
            bit_count <= bit_count + 4'd1;
    end
end

assign busy = running;

endmodule
