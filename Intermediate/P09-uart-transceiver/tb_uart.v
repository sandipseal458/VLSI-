module tb_uart;
reg clk;
reg reset;
reg wt_enable;
reg rdy_clr;
reg [7:0]data_in;
wire rdy, busy;
wire [7:0]data_out;

  uart_top dut(.clk(clk), .reset(reset), .wt_enable(wt_enable), .rdy_clr(rdy_clr), .data_in(data_in), .rdy(rdy), .busy(busy), .data_out(data_out));

    always #5 clk = ~clk;

    task send_byte(input [7:0]din);
 
    @(negedge clk);
    wt_enable = 1'b1;
    data_in = din;
    @(negedge clk);
    wt_enable = 1'b0;

    endtask

    task clear_ready;
 
    @(negedge clk);
    rdy_clr = 1'b1;
    @(negedge clk);
    rdy_clr = 1'b0;

    endtask
initial begin
    $dumpfile("tb_uart.vcd");
    $dumpvars(0, tb_uart);
    {clk, reset, rdy_clr, data_in} = 1'b0;
    @(negedge clk);
    reset = 1'b1;
    @(negedge clk);
    reset = 1'b0;
    send_byte(8'h55);
    wait(!busy);
    wait(rdy);
  $display("recieved data is %h", data_out);
    clear_ready();
    send_byte(8'hAA);
    wait(!busy);
    wait(rdy);
  $display("recieved data is %h", data_out);
    clear_ready();
#400 $finish;    
end
endmodule
