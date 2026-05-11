module test_four_bit_adder;
  reg [3:0]x;
  reg [3:0]y;
  reg carryin;
  wire [3:0]sum;
  wire carryout;


four_bit_Adder a0 ( .x(x), .y(y), .sum(sum), .carryin(carryin), .carryout(carryout));

initial
  begin 
    $dumpfile("four_bit_adder.vcd");
    $dumpvars(0, test_four_bit_adder);
    carryin=0;
    x=4;
    y=3;
    $monitor ("x=0x%0h y=0x%0h carryin=0x%0h carryout=0x%0h sum=0x%0h", x, y, carryin, carryout, sum);
#5  x=7;
    y=8;
#5 x=15;
    y=1;
#5;
  end
endmodule
