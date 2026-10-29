// -----------------------------------------------------------------------------
// uart_rx.v  -  UART receiver (same frame format as uart_tx_core)
//   * 2-flop synchroniser on rx
//   * start bit re-checked at its mid-point (rejects glitches)
//   * every bit sampled at mid-bit
//   * reports parity error and framing error (stop bit = 0)
// -----------------------------------------------------------------------------
module uart_rx #(
    parameter CPB       = 16,
    parameter PARITY_EN = 1,
    parameter CW        = (CPB > 1) ? $clog2(CPB) : 1
)(
    input  wire       clk,
    input  wire       rst,
    input  wire       rx,
    output reg  [7:0] data,
    output reg        valid,       // 1-cycle pulse when a frame is complete
    output reg        parity_err,
    output reg        frame_err
);
    localparam [2:0] R_IDLE = 0, R_START = 1, R_DATA = 2, R_PAR = 3, R_STOP = 4;

    reg [1:0]    sync;
    wire         rxs = sync[1];
    reg [2:0]    st;
    reg [CW-1:0] cnt;
    reg [2:0]    idx;
    reg [7:0]    sh;
    reg          par_bit;

    always @(posedge clk) begin
        if (rst) begin
            sync <= 2'b11;  st <= R_IDLE;  cnt <= 0;  idx <= 0;  sh <= 0;
            par_bit <= 0;  data <= 0;  valid <= 0;  parity_err <= 0;  frame_err <= 0;
        end else begin
            sync  <= {sync[0], rx};
            valid <= 1'b0;
            case (st)
            R_IDLE: begin
                cnt <= 0;  idx <= 0;
                if (!rxs) st <= R_START;
            end
            R_START: begin                         // go to middle of start bit
                if (cnt == (CPB/2) - 1) begin
                    cnt <= 0;
                    st  <= rxs ? R_IDLE : R_DATA;  // glitch -> back to idle
                end else cnt <= cnt + 1'b1;
            end
            R_DATA: begin
                if (cnt == CPB - 1) begin
                    cnt <= 0;
                    sh  <= {rxs, sh[7:1]};
                    if (idx == 3'd7) st <= PARITY_EN ? R_PAR : R_STOP;
                    idx <= idx + 1'b1;
                end else cnt <= cnt + 1'b1;
            end
            R_PAR: begin
                if (cnt == CPB - 1) begin
                    cnt <= 0;  par_bit <= rxs;  st <= R_STOP;
                end else cnt <= cnt + 1'b1;
            end
            R_STOP: begin
                if (cnt == CPB - 1) begin
                    cnt        <= 0;
                    st         <= R_IDLE;
                    data       <= sh;
                    valid      <= 1'b1;
                    frame_err  <= ~rxs;
                    parity_err <= PARITY_EN ? (par_bit ^ (^sh)) : 1'b0;
                end else cnt <= cnt + 1'b1;
            end
            default: st <= R_IDLE;
            endcase
        end
    end
endmodule
