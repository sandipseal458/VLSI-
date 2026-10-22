module fsm_sequence_detector_mealy_nonoverlap(in, clk, reset, out_mealy);
  input in;
  input clk;
  input reset;
  output reg out_mealy;

  reg [2:0] curr_state, next_state;

  parameter S = 0,
            S1 = 1,
            S10 = 2,
            S101 = 3;

  always @(posedge clk)
    begin
      if(reset)
         curr_state <= S;
      else
         curr_state <= next_state;
    end

  always @(*)
    begin
        out_mealy = 0;
        next_state = curr_state;
      case(curr_state)

        S: begin
          if(in)
            next_state = S1;
          else
            next_state = S;
          out_mealy = 0;
        end
        S1: begin
          if(in)
            next_state = S;
          else
            next_state = S10;
          out_mealy = 0;
        end
        S10: begin
          if(in)
            next_state = S101;
          else
            next_state = S;
          out_mealy = 0;
        end
        S101: begin
          if(in)
            out_mealy = 1;
          else
            out_mealy = 0;
          next_state = S;
        end
        default: begin
          next_state = S;
          out_mealy = 0;
        end
      endcase
    end
endmodule