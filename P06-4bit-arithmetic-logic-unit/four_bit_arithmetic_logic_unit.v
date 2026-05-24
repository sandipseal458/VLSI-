module four_bit_arithmetic_logic_unit(a, b, opcode, result, zflag, cflag, oflag, nflag);
  input [3:0]a;
  input [3:0]b;
  input [2:0]opcode;
  output reg [3:0]result;
  output reg zflag, cflag, nflag, oflag;
  
  always @(*)
    begin
      result = 4'b0000;
        cflag  = 1'b0;
        oflag  = 1'b0;
      case(opcode)
        3'b000: begin
          {cflag, result} = a + b;          
          oflag = (~a[3] & ~b[3] & result[3]) | (a[3] & b[3] & ~result[3]);
        end
        3'b001: begin
          {cflag, result} = a - b;     
          oflag = (a[3] ^ b[3]) & (a[3] ^ result[3]);
        end
        3'b010:  result = a & b;
        3'b011:  result = a | b;
        3'b100:  result = a ^ b;
        3'b101:  result = ~a;
        3'b110:  result = a << 1;
        3'b111:  result = a >> 1;
        default: result = 4'b0000;
        endcase
        zflag = (result == 4'b0000) ? 1'b1 : 1'b0;
        nflag = result[3];
    end
endmodule
       
          