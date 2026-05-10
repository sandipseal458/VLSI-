module fourbitAdder( x, y, sum, carryin, carryout);
  input [3:0]x;
  input [3:0]y;
  input carryin;
  output reg [3:0]sum;
  output reg carryout;
  
  always @(x or y or carryin)
    begin
      {carryout,sum} = x + y + carryin;
    end
endmodule
