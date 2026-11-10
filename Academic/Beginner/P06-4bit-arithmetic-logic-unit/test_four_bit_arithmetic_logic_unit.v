module test_four_bit_arithmetic_logic_unit; 
  reg [3:0]a;
  reg [3:0]b;
  reg [2:0]opcode;
  reg [23:0]op;
  wire [3:0]result;
  wire zflag, cflag, nflag, oflag;
  
  four_bit_arithmetic_logic_unit a0(.a(a),
    .b(b),
    .opcode(opcode),
    .result(result),
    .zflag(zflag),
    .cflag(cflag),
    .oflag(oflag),
    .nflag(nflag));
  
  initial 
    begin
    $dumpfile("test_four_bit_arithmetic_logic_unit.vcd");
    $dumpvars(0, test_four_bit_arithmetic_logic_unit);
    
    $display("-----------------------------------------------------------------------------");
      $display(" Time |  a  |  b  | Operation | Opcode | Result | Z | C | O | N |");
    $display("-----------------------------------------------------------------------------");
     
      $monitor(" %0t   | %b | %b |    %s   |   %b  |  %b  | %b | %b | %b | %b |", $time, a, b, op, opcode, result, zflag, cflag, oflag, nflag);
    
    // 1. ADDITION TESTS
    $display("--- ADD (000) ---");
    opcode = 3'b000;
    // Case 1: Normal addition (2 + 3 = 5). No flags set.
    a = 4'b0010;
    b = 4'b0011;
    op = "ADD";
    // Case 2: Positive Overflow (5 + 4 = 9). Should set Overflow (O) and Negative (N).
 #5 a = 4'b0101;
    b = 4'b0100;
    op = "ADD";
    // Case 3: Negative Overflow (-6 + -3 = -9). Should set Overflow (O) and Carry (C).
 #5 a = 4'b1010;
    b = 4'b1101;
    op = "ADD";

    // 2. SUBTRACTION TESTS
    $display("--- SUB (001) ---");
    opcode = 3'b001;
    // Case 1: Normal subtraction (5 - 2 = 3). No flags set.
 #5 a = 4'b0101;
    b = 4'b0010; 
    op = "SUB";
    // Case 2: Subtraction yielding negative (2 - 5 = -3). Should set Negative (N).
 #5 a = 4'b0010;
    b = 4'b0101;
    op = "SUB";
    // Case 3: Subtraction causing Overflow (7 - (-2) = 9). Should set Overflow (O) and Negative (N).
 #5 a = 4'b0111;
    b = 4'b1110;
    op = "SUB";

    // 3. LOGICAL AND TESTS
    $display("--- AND (010) ---");
    opcode = 3'b010;
    // Case 1: Mixed bits
 #5 a = 4'b1100;
    b = 4'b1010;
    op = "AND";
    // Case 2: Resulting in zero. Should set Zero (Z).
 #5 a = 4'b1111;
    b = 4'b0000;
    op = "AND";
    // Case 3: Identical bits, negative result. Should set Negative (N).
 #5 a = 4'b1001;
    b = 4'b1001;
    op = "AND";

    // 4. LOGICAL OR TESTS
    $display("--- OR (011) ---");
    opcode = 3'b011;
    // Case 1: Mixed bits
 #5 a = 4'b1100;
    b = 4'b1010;
    op = "OR";
    // Case 2: All zeros. Should set Zero (Z).
 #5 a = 4'b0000;
    b = 4'b0000;
    op = "OR";
    // Case 3: Setting all bits. Should set Negative (N).
 #5 a = 4'b0101;
    b = 4'b1010;
    op = "OR";

    // 5. LOGICAL XOR TESTS
    $display("--- XOR (100) ---");
    opcode = 3'b100;
    // Case 1: Mixed bits
 #5 a = 4'b1100;
    b = 4'b1010;
    op = "XOR";
    // Case 2: Identical bits (XOR zeroes out). Should set Zero (Z).
 #5 a = 4'b1111;
    b = 4'b1111;
    op = "XOR";
    // Case 3: Inverted bits. Should set Negative (N).
 #5 a = 4'b0101;
    b = 4'b1010;
    op = "XOR";

    // 6. LOGICAL NOT TESTS
    $display("--- NOT (101) ---");
    opcode = 3'b101;
    // Case 1: Invert positive to negative. Should set Negative (N).
 #5 a = 4'b0101;
    b = 4'b0000;
    op = "NOT"; // B is ignored in your NOT logic
    // Case 2: Invert all ones to all zeros. Should set Zero (Z).
 #5 a = 4'b1111;
    b = 4'b0000;
    op = "NOT";
    // Case 3: Invert all zeros to all ones. Should set Negative (N).
 #5 a = 4'b0000;
    b = 4'b0000;
    op = "NOT";

    // 7. SHIFT LEFT LOGICAL (SLL) TESTS
    $display("--- SLL (110) ---");
    opcode = 3'b110;
    // Case 1: Normal shift (0011 << 1 = 0110).
 #5 a = 4'b0011;
    b = 4'b0000;
    op = "SLL";
    // Case 2: Shift pushing 1 into the sign bit. Should set Negative (N).
 #5 a = 4'b0111;
    b = 4'b0000;
    op = "SLL";
    // Case 3: Shift pushing only 1 out, leaving zeros. Should set Zero (Z).
 #5 a = 4'b1000;
    b = 4'b0000;
    op = "SLL";

    // 8. SHIFT RIGHT LOGICAL (SRL) TESTS
    $display("--- SRL (111) ---");
    opcode = 3'b111;
    // Case 1: Normal shift (0110 >> 1 = 0011).
 #5 a = 4'b0110;
    b = 4'b0000; 
    op = "SRL";
    // Case 2: Shift right a negative number (turns positive).
 #5 a = 4'b1000;
    b = 4'b0000;
    op = "SRL";
    // Case 3: Shift right a single 1. Should set Zero (Z).
 #5 a = 4'b0001;
    b = 4'b0000;
    op = "SRL";

 #5 $display("-----------------------------------------------------------------");
    $display("All test cases completed.");
   
 #5 $finish;
  end
endmodule