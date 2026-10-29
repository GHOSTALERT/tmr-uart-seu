// -----------------------------------------------------------------------------
// maj3.v  -  Bitwise 2-out-of-3 majority voter
//            y = (a & b) | (b & c) | (a & c)
// -----------------------------------------------------------------------------
(* keep_hierarchy *)
module maj3 #(parameter W = 1) (
    input  wire [W-1:0] a, b, c,
    output wire [W-1:0] y
);
    assign y = (a & b) | (b & c) | (a & c);
endmodule
