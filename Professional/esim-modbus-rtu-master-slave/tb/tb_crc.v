module tb_crc;
reg clk;
reg reset;
reg init;
reg en;
reg [7:0]data_in;
wire busy;
wire [15:0]crc;

  crc16_modbus dut(.clk(clk), .reset(reset), .init(init), .en(en), .data_in(data_in), .crc(crc), .busy(busy));

    always #5 clk = ~clk;

    task send_byte(input [7:0]din);
    begin
    @(negedge clk);
    en = 1'b1;
    data_in = din;
    @(negedge clk);
    en = 1'b0;
    wait(!busy);

    end
    endtask

    task restart_crc;
    begin
    @(negedge clk);
    init = 1'b1;
    @(negedge clk);
    init = 1'b0;

    end
    endtask
initial begin
    $dumpfile("tb_crc.vcd");
    $dumpvars(0, tb_crc);
    {clk, reset, init, en, data_in} = 1'b0;
    @(negedge clk);
    reset = 1'b1;
    @(negedge clk);
    reset = 1'b0;

    // frame 1 : 01 03 00 00 00 02   crc should be 0bc4 (sent as c4 0b)
    restart_crc();
    send_byte(8'h01);
    send_byte(8'h03);
    send_byte(8'h00);
    send_byte(8'h00);
    send_byte(8'h00);
    send_byte(8'h02);
    $display("frame 1 crc is %h", crc);

    // frame 2 : 01 06 00 01 00 03   crc should be 0b98 (sent as 98 0b)
    restart_crc();
    send_byte(8'h01);
    send_byte(8'h06);
    send_byte(8'h00);
    send_byte(8'h01);
    send_byte(8'h00);
    send_byte(8'h03);
    $display("frame 2 crc is %h", crc);
#100 $finish;
end
endmodule
