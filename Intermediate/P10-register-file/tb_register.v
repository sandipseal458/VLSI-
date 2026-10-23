module tb_register;
    reg clk;
    reg reset;
    reg wt_enable;
    reg [4:0] w_add, r_add1, r_add2;
    reg [31:0] w_data;
    wire [31:0] r_data1, r_data2;

    register uut (
        .clk(clk),
        .reset(reset),
        .wt_enable(wt_enable),
        .w_add(w_add),
        .r_add1(r_add1),
        .r_add2(r_add2),
        .w_data(w_data),
        .r_data1(r_data1),
        .r_data2(r_data2)
    );

    always #5 clk = ~clk;

    initial 
    begin
        $dumpfile("tb_register.vcd");
        $dumpvars(0, tb_register);
        clk = 0;
        reset = 1;
        wt_enable = 0;
        w_add = 0;
        r_add1 = 0;
        r_add2 = 0;
        w_data = 0;

        #5 reset = 0; // Deassert reset
    end

    initial
    begin
       #7
       for (integer i = 0; i < 32; i = i + 1)
        begin
            wt_enable = 1;
            w_add = i;
            w_data = i * 10; // Write some data
            #10; // one write per clock, otherwise all 32 writes land at the same edge
        end
       #20
       for (integer i = 0; i < 32; i = i + 1)
        begin
            r_add1 = i;
            r_add2 = i + 1;
            #1; // let the read value settle before printing
            $display("Read data1 at address %h: %h , Read data2 at address %h: %h", r_add1, r_data1, r_add2, r_data2); 
        end
#2000   $finish;
    end
endmodule