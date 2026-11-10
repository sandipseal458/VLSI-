module tb_modbus_slave;
reg clk;
reg reset;
reg wt_enable;
reg rdy_clr;
reg [7:0]data_in;
wire m2s, s2m;
wire busy;
wire rdy;
wire [7:0]data_out;
wire crc_ok, reg_hit;

  // fake master : its own uart transmitter and receiver
  uart_tx_top mtx(.clk(clk), .reset(reset), .wt_enable(wt_enable), .data_in(data_in), .tx(m2s), .busy(busy));
  uart_rx_top mrx(.clk(clk), .reset(reset), .rx(s2m), .rdy_clr(rdy_clr), .rdy(rdy), .data_out(data_out));
  // slave under test
  modbus_slave dut(.clk(clk), .reset(reset), .rx(m2s), .tx(s2m), .crc_ok(crc_ok), .reg_hit(reg_hit));

    always #5 clk = ~clk;

    task send_byte(input [7:0]din);
    begin
    @(negedge clk);
    wt_enable = 1'b1;
    data_in = din;
    @(negedge clk);
    wt_enable = 1'b0;
    wait(!busy);
    end
    endtask

    // print every byte that comes back from the slave
    always @(posedge rdy)
    begin
        $display("   reply byte is %h", data_out);
        @(negedge clk);
        rdy_clr = 1'b1;
        @(negedge clk);
        rdy_clr = 1'b0;
    end

initial begin
    $dumpfile("tb_modbus_slave.vcd");
    $dumpvars(0, tb_modbus_slave);
    {clk, reset, rdy_clr, wt_enable, data_in} = 1'b0;
    @(negedge clk);
    reset = 1'b1;
    @(negedge clk);
    reset = 1'b0;
    #1000;

    $display("frame 1 : read 2 registers from 0");
    send_byte(8'h01); send_byte(8'h03); send_byte(8'h00); send_byte(8'h00);
    send_byte(8'h00); send_byte(8'h02); send_byte(8'hC4); send_byte(8'h0B);
    #100000;
    $display("   crc_ok = %b  reg_hit = %b", crc_ok, reg_hit);

    $display("frame 2 : write 0003 in register 1");
    send_byte(8'h01); send_byte(8'h06); send_byte(8'h00); send_byte(8'h01);
    send_byte(8'h00); send_byte(8'h03); send_byte(8'h98); send_byte(8'h0B);
    #100000;
    $display("   crc_ok = %b  reg_hit = %b", crc_ok, reg_hit);

    $display("frame 3 : read again, register 1 should be 0003 now");
    send_byte(8'h01); send_byte(8'h03); send_byte(8'h00); send_byte(8'h00);
    send_byte(8'h00); send_byte(8'h02); send_byte(8'hC4); send_byte(8'h0B);
    #100000;

    $display("frame 4 : bad crc (c5 instead of c4), no reply expected");
    send_byte(8'h01); send_byte(8'h03); send_byte(8'h00); send_byte(8'h00);
    send_byte(8'h00); send_byte(8'h02); send_byte(8'hC5); send_byte(8'h0B);
    #100000;
    $display("   crc_ok = %b  reg_hit = %b", crc_ok, reg_hit);

    $display("frame 5 : wrong address 02, no reply expected");
    send_byte(8'h02); send_byte(8'h03); send_byte(8'h00); send_byte(8'h00);
    send_byte(8'h00); send_byte(8'h02); send_byte(8'hC4); send_byte(8'h38);
    #100000;
    $display("   crc_ok = %b  reg_hit = %b", crc_ok, reg_hit);

    $display("frame 6 : read register 8, does not exist, exception expected");
    send_byte(8'h01); send_byte(8'h03); send_byte(8'h00); send_byte(8'h08);
    send_byte(8'h00); send_byte(8'h01); send_byte(8'h05); send_byte(8'hC8);
    #100000;
    $display("   crc_ok = %b  reg_hit = %b", crc_ok, reg_hit);
$finish;
end
endmodule
