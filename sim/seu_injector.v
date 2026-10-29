// -----------------------------------------------------------------------------
// seu_injector.v  -  LFSR-driven random SEU (bit-flip) generator
//
// Synthesisable, so the same fault campaign can run in simulation AND on an
// FPGA (emulation-based fault injection).
//
// Each replica has its OWN LFSR (different primitive polynomials -> no
// correlation between replicas) and its own countdown timer:
//   * WHEN : gap to the next upset = random, uniform in 1 .. 2^rate
//            (mean ~ 2^(rate-1) clocks).  Same per-replica rate for every
//            design, i.e. the same upset rate per flip-flop - so TMR, having
//            3x the flip-flops, also receives 3x the upsets (physically fair).
//   * WHERE: which flip-flop of the replica = random, 0 .. SW-1
//   * WHAT : that bit is inverted for one clock edge (SEU model)
// -----------------------------------------------------------------------------
module seu_injector #(
    parameter NREP = 3,
    parameter SW   = 20,
    parameter SEED = 1
)(
    input  wire              clk,
    input  wire              rst,
    input  wire              en,
    input  wire [3:0]        rate,      // gap bits, 1..15
    output reg  [NREP*SW-1:0] fi_mask,
    output reg  [NREP-1:0]   inj         // 1 when replica i is hit this cycle
);
    genvar i;
    generate
    for (i = 0; i < NREP; i = i + 1) begin : g_rep
        wire [30:0] q;                     // LFSR state (zero-extended)
        if (i == 0) begin : g_l0
            wire [30:0] t;
            lfsr #(.N(31), .TAPS(31'h48000000), .SEED(31'h1234567 + SEED)) u_l
                (.clk(clk), .rst(rst), .en(1'b1), .q(t));
            assign q = t;
        end else if (i == 1) begin : g_l1
            wire [28:0] t;
            lfsr #(.N(29), .TAPS(29'h14000000), .SEED(29'h0ABCDEF + SEED)) u_l
                (.clk(clk), .rst(rst), .en(1'b1), .q(t));
            assign q = {2'b00, t};
        end else begin : g_l2
            wire [22:0] t;
            lfsr #(.N(23), .TAPS(23'h420000), .SEED(23'h05A5A5 + SEED)) u_l
                (.clk(clk), .rst(rst), .en(1'b1), .q(t));
            assign q = {8'h00, t};
        end

        reg  [15:0] gap;
        wire [15:0] gmask   = (16'h1 << rate) - 1'b1;
        wire [15:0] new_gap = (q[15:0] & gmask) + 1'b1;
        wire [7:0]  pick    = q[22:15];
        wire [7:0]  bitsel  = pick % SW;

        always @(posedge clk) begin
            if (rst || !en) begin
                gap                <= new_gap;
                fi_mask[i*SW +: SW] <= 0;
                inj[i]             <= 1'b0;
            end else if (gap == 1) begin
                gap                <= new_gap;
                fi_mask[i*SW +: SW] <= {{(SW-1){1'b0}}, 1'b1} << bitsel;
                inj[i]             <= 1'b1;
            end else begin
                gap                <= gap - 1'b1;
                fi_mask[i*SW +: SW] <= 0;
                inj[i]             <= 1'b0;
            end
        end
    end
    endgenerate
endmodule
