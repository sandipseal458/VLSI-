module fsm_sequence_detector_moore_overlap(in, clk, reset, out_moore);
  input in;
  input clk;
  input reset;
  output out_moore;

  reg [2:0] curr_state, next_state;

  parameter S = 0,
            S1 = 1,
            S10 = 2,
            S101 = 3,
            S1011 = 4;

  assign out_moore = (curr_state == S1011) ? 1 : 0;

  always @(posedge clk)
    begin
      if(reset)
         curr_state <= S;
      else
         curr_state <= next_state;
    end

  always @(*)
    begin
      case(curr_state)

        S: begin
          if(in)
            next_state = S1;
          else
            next_state = S;
        end
        S1: begin
          if(in)
            next_state = S1;
          else
            next_state = S10;
        end
        S10: begin
          if(in)
            next_state = S101;
          else
            next_state = S;
        end
        S101: begin
          if(in)
            next_state = S1011;
          else
            next_state = S10;
        end
        S1011: begin
          if(in)
            next_state = S1;
          else
            next_state = S10;
        end
          default:
          next_state = S;
      endcase
    end
endmodule