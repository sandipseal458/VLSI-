module tb_modbus_timing;
reg clk;
reg reset;
reg start;
wire m2s, s2m;
wire busy, done, m_crc_ok;
wire s_crc_ok, reg_hit;

  modbus_master mdut(.clk(clk), .reset(reset), .start(start), .rx(s2m), .tx(m2s), .busy(busy), .done(done), .crc_ok(m_crc_ok));
  modbus_slave  sdut(.clk(clk), .reset(reset), .rx(m2s), .tx(s2m), .crc_ok(s_crc_ok), .reg_hit(reg_hit));

    always #5 clk = ~clk;                // one clock = 10 time units

    integer t_byte1, t_byte2, n_byte;    // when the slave uart gets byte 1 and byte 2
    integer t_req_stop, t_reply_start, t_reply_rise;
    integer bit_clk, char_clk, gap_clk;

    initial
    begin
        t_byte1 = 0; t_byte2 = 0; n_byte = 0;
        t_req_stop = 0; t_reply_start = 0; t_reply_rise = 0;
    end

    // character time : two bytes of the request come out of the slave uart one character apart
    always @(posedge sdut.rdy)
    begin
        n_byte = n_byte + 1;
        if (n_byte == 1) t_byte1 = $time;
        if (n_byte == 2) t_byte2 = $time;
    end

    // last rising edge of the request line = the stop bits of the last request byte begin
    always @(posedge m2s)
        if (t_reply_start == 0) t_req_stop = $time;

    // reply starts with a falling edge, first reply byte is 01 so the low pulse is exactly one bit
    always @(negedge s2m)
        if (t_reply_start == 0) t_reply_start = $time;

    always @(posedge s2m)
        if (t_reply_start != 0 && t_reply_rise == 0) t_reply_rise = $time;

initial begin
    $dumpfile("tb_modbus_timing.vcd");
    $dumpvars(0, tb_modbus_timing);
    {clk, reset, start} = 1'b0;
    @(negedge clk);
    reset = 1'b1;
    @(negedge clk);
    reset = 1'b0;
    #1000;
    @(negedge clk);
    start = 1'b1;
    @(negedge clk);
    start = 1'b0;
    wait(busy);
    wait(done);
    #1000;

    bit_clk  = (t_reply_rise - t_reply_start) / 10;
    char_clk = (t_byte2 - t_byte1) / 10;
    gap_clk  = (t_reply_start - t_req_stop) / 10 - 2 * bit_clk;      // remove the 2 stop bits

    $display("one bit              : %0d clocks", bit_clk);
    $display("one character (11 bits, start + 8 data + 2 stop) = %0d clocks", 11 * bit_clk);
    $display("start to start of two bytes = %0d clocks = %0d bit times (the uart waits 1 extra bit)", char_clk, char_clk / bit_clk);
    $display("silent gap before reply     = %0d clocks = %0d bit times", gap_clk, gap_clk / bit_clk);

    // modbus rules : gap of at least 3.5 characters, gap between two bytes of a frame less than 1.5 characters
    if (gap_clk * 2 >= 77 * bit_clk)                 // 3.5 characters = 38.5 bits = 77 / 2 bits
        $display("   PASS : gap is more than 3.5 characters (%0d clocks needed)", 77 * bit_clk / 2);
    else
        $display("   FAIL : gap is too short");
    if ((char_clk - 11 * bit_clk) * 2 < 33 * bit_clk)   // 1.5 characters = 16.5 bits = 33 / 2 bits
        $display("   PASS : extra space between bytes of a frame is less than 1.5 characters (%0d clocks)", 33 * bit_clk / 2);
    else
        $display("   FAIL : bytes of a frame are too far apart");

    // with 32 clocks per bit, a clock of 307200 Hz gives exactly 9600 baud
    $display("at 307200 Hz clock (9600 baud) : bit = %0.2f us, character = %0.3f ms, gap = %0.3f ms",
             bit_clk * 1000000.0 / 307200.0, 11 * bit_clk * 1000.0 / 307200.0, gap_clk * 1000.0 / 307200.0);
    $finish;
end
endmodule
