// -----------------------------------------------------------------------------
// uart_tmr_top.v  -  SYNTHESIS TOP (this is what goes to Genus -> Virtuoso)
//
//   8-bit de Bruijn LFSR  --(data + start)-->  TMR UART TX  --> tx
//
// No data is typed in by hand: after reset, while 'run' = 1, the LFSR
// supplies a new byte for every frame and the start pulse is generated
// automatically once the transmitter is idle again.
//
// Parameters
//   MODE      0 = simplex (no TMR)
//             1 = TMR, output voting only  (the original block diagram)
//             2 = TMR, voted state feedback (self-correcting)
//   CPB       clocks per bit = f_clk / baud   (e.g. 50 MHz / 115200 = 434)
//   PARITY_EN 1 = even parity bit in the frame
//   GAP       idle clocks between frames
//   FI_PORT   1 = keep the fi_mask SEU-injection port (gate-level fault
//                 injection demo; adds one XOR per flip-flop)
//             0 = port ignored, XORs optimised away (use this for PPA numbers)
// -----------------------------------------------------------------------------
module uart_tmr_top #(
    parameter MODE      = 1,
    parameter CPB       = 16,
    parameter PARITY_EN = 1,
    parameter GAP       = 8,
    parameter DATA_SEED = 8'h01,
    parameter FI_PORT   = 1,
    parameter CW        = (CPB > 1) ? $clog2(CPB) : 1,
    parameter SW        = 16 + CW,
    parameter NREP      = (MODE == 0) ? 1 : 3
)(
    input  wire               clk,
    input  wire               rst,          // synchronous, active high
    input  wire               run,          // 1 = keep sending LFSR frames
    input  wire [NREP*SW-1:0] fi_mask,      // SEU injection (see FI_PORT)
    output wire               tx,           // voted serial output
    output wire               busy,
    output wire               start,        // frame request (observability)
    output wire [7:0]         data,         // byte being sent (observability)
    output wire [2:0]         fault_flag    // replica i disagrees with others
);
    // ---------------- LFSR test-pattern generator ----------------------------
    reg       start_r;
    reg [7:0] idle_cnt;

    lfsr #(.N(8), .TAPS(8'hB8), .SEED(DATA_SEED), .DEBRUIJN(1)) u_tpg (
        .clk(clk), .rst(rst), .en(start_r), .q(data));

    always @(posedge clk) begin
        if (rst) begin
            start_r  <= 1'b0;
            idle_cnt <= 8'd0;
        end else begin
            start_r <= 1'b0;
            if (busy || start_r)        idle_cnt <= 8'd0;
            else if (idle_cnt != 8'hFF) idle_cnt <= idle_cnt + 1'b1;
            if (run && !busy && !start_r && idle_cnt >= GAP)
                start_r <= 1'b1;
        end
    end
    assign start = start_r;

    // ---------------- TMR UART transmitter ------------------------------------
    wire [NREP*SW-1:0] fi = (FI_PORT != 0) ? fi_mask : {NREP*SW{1'b0}};

    tmr_uart_tx #(.MODE(MODE), .CPB(CPB), .PARITY_EN(PARITY_EN), .CW(CW), .SW(SW)) u_tx (
        .clk(clk), .rst(rst), .start(start_r), .din(data), .fi_mask(fi),
        .tx(tx), .busy(busy), .fault_flag(fault_flag));
endmodule
