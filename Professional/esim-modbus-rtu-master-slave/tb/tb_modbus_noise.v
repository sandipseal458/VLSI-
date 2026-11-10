module tb_modbus_noise;
reg clk;
reg reset;
reg start;
reg flip;
wire m2s_raw, m2s, s2m;
wire busy, done, m_crc_ok;
wire s_crc_ok, reg_hit;

// noise on the request line : flip = 1 inverts the line
assign m2s = m2s_raw ^ flip;

  modbus_master mdut(.clk(clk), .reset(reset), .start(start), .rx(s2m), .tx(m2s_raw), .busy(busy), .done(done), .crc_ok(m_crc_ok));
  modbus_slave  sdut(.clk(clk), .reset(reset), .rx(m2s), .tx(s2m), .crc_ok(s_crc_ok), .reg_hit(reg_hit));

    always #5 clk = ~clk;

    integer i;

    task show_result;
    begin
    $display("   master : reply bytes %0d  crc_ok = %b   slave : crc_ok = %b  reg_hit = %b", mdut.rx_count, m_crc_ok, s_crc_ok, reg_hit);
    if (mdut.rx_count != 0)
    begin
        $write("   reply  :");
        for (i = 0; i < mdut.rx_count; i = i + 1)
            $write(" %h", mdut.rx_buf[i]);
        $write("\n");
    end
    end
    endtask

    // normal request, no noise
    task send_request;
    begin
    @(negedge clk);
    start = 1'b1;
    @(negedge clk);
    start = 1'b0;
    wait(busy);
    wait(done);
    show_result();
    #20000;
    end
    endtask

    // request with one bit flipped on the line
    // one character is 12 bit times = 384 clocks, one bit is 32 clocks
    // data bit n of byte b starts 384*b + 32*(n+1) clocks after the first start bit
    task send_request_flip(input integer byte_no, input integer bit_no);
    begin
    @(negedge clk);
    start = 1'b1;
    @(negedge clk);
    start = 1'b0;
    @(negedge m2s_raw);                              // start bit of the first byte
    repeat (384*byte_no + 32*(bit_no + 1) + 8) @(negedge clk);
    flip = 1'b1;                                     // noise for half a bit, around the sample point
    repeat (16) @(negedge clk);
    flip = 1'b0;
    wait(busy);
    wait(done);
    $display("   slave got byte %0d as %h (it should have been 00)", byte_no, sdut.rx_buf[byte_no]);
    show_result();
    #20000;
    end
    endtask
initial begin
    $dumpfile("tb_modbus_noise.vcd");
    $dumpvars(0, tb_modbus_noise);
    {clk, reset, start, flip} = 1'b0;
    @(negedge clk);
    reset = 1'b1;
    @(negedge clk);
    reset = 1'b0;
    #1000;
    $display("request 0 : read 2 registers from 0, no noise");
    send_request;
    $display("request 1 : write 0003 in register 1, bit 3 of byte 2 is flipped on the line");
    send_request_flip(2, 3);
    $display("   register 1 is %h (still 0102, the damaged write was ignored)", sdut.regs[1]);
    $display("request 2 : read again, register 1 must still be 0102");
    send_request;
    $finish;
end
endmodule
