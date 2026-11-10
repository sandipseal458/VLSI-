module tb_modbus_system;
reg clk;
reg reset;
reg start;
wire m2s, s2m;
wire busy, done, m_crc_ok;
wire s_crc_ok, reg_hit;

  modbus_master mdut(.clk(clk), .reset(reset), .start(start), .rx(s2m), .tx(m2s), .busy(busy), .done(done), .crc_ok(m_crc_ok));
  modbus_slave  sdut(.clk(clk), .reset(reset), .rx(m2s), .tx(s2m), .crc_ok(s_crc_ok), .reg_hit(reg_hit));

    always #5 clk = ~clk;

    integer i;

    task send_request;
    begin
    @(negedge clk);
    start = 1'b1;
    @(negedge clk);
    start = 1'b0;
    wait(busy);
    wait(done);
    $display("   master : reply bytes %0d  crc_ok = %b   slave : crc_ok = %b  reg_hit = %b", mdut.rx_count, m_crc_ok, s_crc_ok, reg_hit);
    if (mdut.rx_count != 0)
    begin
        $write("   reply  :");
        for (i = 0; i < mdut.rx_count; i = i + 1)
            $write(" %h", mdut.rx_buf[i]);
        $write("\n");
    end
    #20000;
    end
    endtask
initial begin
    $dumpfile("tb_modbus_system.vcd");
    $dumpvars(0, tb_modbus_system);
    {clk, reset, start} = 1'b0;
    @(negedge clk);
    reset = 1'b1;
    @(negedge clk);
    reset = 1'b0;
    #1000;
    $display("request 0 : read 2 registers from 0");
    send_request;
    $display("request 1 : write 0003 in register 1");
    send_request;
    $display("request 2 : read again");
    send_request;
    $display("request 3 : read with damaged crc, slave must stay silent");
    send_request;
    $display("request 4 : read from slave 02, nobody answers");
    send_request;
    $display("request 5 : read 2 registers again (the list started again)");
    send_request;
$finish;
end
endmodule
