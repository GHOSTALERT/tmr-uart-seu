// -----------------------------------------------------------------------------
// uart_tmr_m1.v  -  Synthesis wrapper, MODE = 1 : TMR, output voting only
//   Fixes the parameters so Genus needs no parameter overrides.
//   FI_PORT = 0 : no fault-injection pins -> clean netlist for PPA / Virtuoso.
// -----------------------------------------------------------------------------
module uart_tmr_m1 (
    input  wire       clk,
    input  wire       rst,
    input  wire       run,
    output wire       tx,
    output wire       busy,
    output wire       start,
    output wire [7:0] data,
    output wire [2:0] fault_flag
);
    uart_tmr_top #(.MODE(1), .CPB(16), .PARITY_EN(1), .GAP(8), .FI_PORT(0)) u_top (
        .clk(clk), .rst(rst), .run(run), .fi_mask({60{1'b0}}),
        .tx(tx), .busy(busy), .start(start), .data(data), .fault_flag(fault_flag));
endmodule
