module tb_uart_loop;
reg clk;
reg reset;
reg wt_enable;
reg rdy_clr;
reg [7:0]data_in;
wire line;
wire rdy, busy;
wire [7:0]data_out;

  uart_tx_top tx_dut(.clk(clk), .reset(reset), .wt_enable(wt_enable), .data_in(data_in), .tx(line), .busy(busy));
  uart_rx_top rx_dut(.clk(clk), .reset(reset), .rx(line), .rdy_clr(rdy_clr), .rdy(rdy), .data_out(data_out));

    always #5 clk = ~clk;

    task send_byte(input [7:0]din);
    begin
    @(negedge clk);
    wt_enable = 1'b1;
    data_in = din;
    @(negedge clk);
    wt_enable = 1'b0;

    end
    endtask

    task clear_ready;
    begin
    @(negedge clk);
    rdy_clr = 1'b1;
    @(negedge clk);
    rdy_clr = 1'b0;

    end
    endtask
initial begin
    $dumpfile("tb_uart_loop.vcd");
    $dumpvars(0, tb_uart_loop);
    {clk, reset, rdy_clr, wt_enable, data_in} = 1'b0;
    @(negedge clk);
    reset = 1'b1;
    @(negedge clk);
    reset = 1'b0;
    send_byte(8'h55);
    wait(!busy);
    wait(rdy);
    $display("received data is %h", data_out);
    clear_ready();
    send_byte(8'hAA);
    wait(!busy);
    wait(rdy);
    $display("received data is %h", data_out);
    clear_ready();
    send_byte(8'h00);
    wait(!busy);
    wait(rdy);
    $display("received data is %h", data_out);
    clear_ready();
    send_byte(8'hFF);
    wait(!busy);
    wait(rdy);
    $display("received data is %h", data_out);
    clear_ready();
#400 $finish;
end
endmodule
