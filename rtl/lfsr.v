// -----------------------------------------------------------------------------
// lfsr.v  -  Generic Fibonacci LFSR (shift-left, feedback into bit 0)
//
//   TAPS : bit-mask of the tap positions (0-indexed). For a polynomial
//          x^n + x^a + x^b + ... + 1  set bits (n-1), (a-1), (b-1) ...
//          Values used in this project (maximal length, Xilinx XAPP052):
//            N=8  : x^8 +x^6 +x^5 +x^4 +1  -> 8'hB8
//            N=16 : x^16+x^15+x^13+x^4 +1  -> 16'hD008
//            N=23 : x^23+x^18+1            -> 23'h420000
//            N=29 : x^29+x^27+1            -> 29'h14000000
//            N=31 : x^31+x^28+1            -> 31'h48000000
//
//   DEBRUIJN = 1 : de Bruijn extension. The all-zero state is inserted into
//          the sequence, so the period becomes 2^N instead of 2^N - 1.
//          For the 8-bit data generator this means EVERY byte 0x00..0xFF is
//          transmitted once per period (a plain LFSR never produces 0x00).
//
//   The register can never lock up in the all-zero state: a zero seed is
//   replaced by 1, and in normal (non de Bruijn) mode 0 is unreachable.
// -----------------------------------------------------------------------------
module lfsr #(
    parameter N        = 8,
    parameter [N-1:0] TAPS = 8'hB8,
    parameter [N-1:0] SEED = 1,
    parameter DEBRUIJN = 0
)(
    input  wire         clk,
    input  wire         rst,      // synchronous, active high
    input  wire         en,       // advance one step
    output reg  [N-1:0] q
);
    wire fb_lfsr = ^(q & TAPS);
    // de Bruijn: invert feedback when bits [N-2:0] are all zero
    wire fb      = (DEBRUIJN != 0) ? (fb_lfsr ^ (q[N-2:0] == 0)) : fb_lfsr;

    always @(posedge clk) begin
        if (rst)
            q <= (SEED == 0) ? {{(N-1){1'b0}}, 1'b1} : SEED;
        else if (en)
            q <= {q[N-2:0], fb};
    end
endmodule
