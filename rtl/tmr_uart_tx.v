// -----------------------------------------------------------------------------
// tmr_uart_tx.v  -  UART transmitter in three reliability flavours
//
//   MODE = 0  SIMPLEX   : one transmitter, no protection (baseline)
//   MODE = 1  TMR-OUT   : three independent transmitters, only the TX / BUSY
//                         outputs are voted (this is the "classic" block
//                         diagram: 3 x UART -> majority voter -> TX).
//                         A flipped bit stays wrong inside its replica until
//                         that replica happens to re-synchronise (next frame),
//                         so upsets ACCUMULATE.
//   MODE = 2  TMR-FB    : three transmitters whose STATE is voted every clock
//                         and fed back (triplicated voters, one per replica).
//                         A flipped bit is out-voted and overwritten on the
//                         very next clock edge -> self-correcting / scrubbing.
//
//   fault_flag[i] (DETECT=1, MODE 1/2): replica i disagrees with BOTH other
//   replicas this cycle -> identifies the faulty module (FAULT_STATUS).
// -----------------------------------------------------------------------------
module tmr_uart_tx #(
    parameter MODE      = 2,
    parameter DETECT    = 1,
    parameter CPB       = 16,
    parameter PARITY_EN = 1,
    parameter CW        = (CPB > 1) ? $clog2(CPB) : 1,
    parameter SW        = 16 + CW,
    parameter NREP      = (MODE == 0) ? 1 : 3
)(
    input  wire              clk,
    input  wire              rst,
    input  wire              start,
    input  wire [7:0]        din,
    input  wire [NREP*SW-1:0] fi_mask,     // SEU injection, one slice per replica
    output wire              tx,
    output wire              busy,
    output wire [2:0]        fault_flag
);
    function is_busy(input [SW-1:0] s);
        is_busy = (s[SW-1:SW-3] != 3'd0);
    endfunction

    generate
    if (MODE == 0) begin : g_simplex
        wire [SW-1:0] s0;
        tx_replica #(.CPB(CPB), .PARITY_EN(PARITY_EN), .CW(CW), .SW(SW)) u_rep0 (
            .clk(clk), .rst(rst), .st_fb(s0), .start(start), .din(din),
            .fi_mask(fi_mask[SW-1:0]), .st_q(s0));
        assign tx         = s0[0];
        assign busy       = is_busy(s0);
        assign fault_flag = 3'b000;
    end else begin : g_tmr
        wire [SW-1:0] s0, s1, s2;          // replica states
        wire [SW-1:0] fb0, fb1, fb2;       // feedback seen by each replica

        if (MODE == 2) begin : g_fb_vote   // triplicated feedback voters
            maj3 #(.W(SW)) u_v0 (.a(s0), .b(s1), .c(s2), .y(fb0));
            maj3 #(.W(SW)) u_v1 (.a(s0), .b(s1), .c(s2), .y(fb1));
            maj3 #(.W(SW)) u_v2 (.a(s0), .b(s1), .c(s2), .y(fb2));
        end else begin : g_own_fb
            assign fb0 = s0;  assign fb1 = s1;  assign fb2 = s2;
        end

        tx_replica #(.CPB(CPB), .PARITY_EN(PARITY_EN), .CW(CW), .SW(SW)) u_rep0 (
            .clk(clk), .rst(rst), .st_fb(fb0), .start(start), .din(din),
            .fi_mask(fi_mask[0*SW +: SW]), .st_q(s0));
        tx_replica #(.CPB(CPB), .PARITY_EN(PARITY_EN), .CW(CW), .SW(SW)) u_rep1 (
            .clk(clk), .rst(rst), .st_fb(fb1), .start(start), .din(din),
            .fi_mask(fi_mask[1*SW +: SW]), .st_q(s1));
        tx_replica #(.CPB(CPB), .PARITY_EN(PARITY_EN), .CW(CW), .SW(SW)) u_rep2 (
            .clk(clk), .rst(rst), .st_fb(fb2), .start(start), .din(din),
            .fi_mask(fi_mask[2*SW +: SW]), .st_q(s2));

        // output voter on {busy, tx}
        wire [1:0] out_v;
        maj3 #(.W(2)) u_vout (
            .a({is_busy(s0), s0[0]}), .b({is_busy(s1), s1[0]}),
            .c({is_busy(s2), s2[0]}), .y(out_v));
        assign tx   = out_v[0];
        assign busy = out_v[1];

        // fault detection / localisation
        if (DETECT) begin : g_det
            wire d01 = (s0 != s1), d02 = (s0 != s2), d12 = (s1 != s2);
            assign fault_flag = {d02 & d12, d01 & d12, d01 & d02};
        end else begin : g_nodet
            assign fault_flag = 3'b000;
        end
    end
    endgenerate
endmodule
