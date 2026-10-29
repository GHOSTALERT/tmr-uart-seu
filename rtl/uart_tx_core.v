// -----------------------------------------------------------------------------
// uart_tx_core.v  -  UART transmitter NEXT-STATE logic (purely combinational)
//
// Frame : 1 start bit (0) | 8 data bits, LSB first | even parity (optional) |
//         1 stop bit (1)
//
// The complete state of the transmitter is packed into ONE vector st[SW-1:0].
// Keeping the state as a single vector lets the same core be used for:
//   * a plain (simplex) transmitter,
//   * module-level TMR       (each replica feeds back its OWN state),
//   * TMR with voted feedback (each replica feeds back the VOTED state,
//                              so a flipped bit is scrubbed on the next clock),
// and lets the fault injector hit ANY flip-flop (FSM, counters, shift reg...).
//
// State vector layout (LSB first):
//   [0]                tx_q      registered serial output (glitch free)
//   [1]                par       parity bit of the loaded byte
//   [9:2]              shreg     data shift register
//   [12:10]            bit_idx   data bit counter 0..7
//   [13+CW-1:13]       baud      clocks-per-bit counter
//   [SW-1:SW-3]        fsm       IDLE/START/DATA/PARITY/STOP/RECOVER
// -----------------------------------------------------------------------------
module uart_tx_core #(
    parameter CPB       = 16,                 // clocks per bit (clk / baud)
    parameter PARITY_EN = 1,
    parameter CW        = (CPB > 1) ? $clog2(CPB) : 1,
    parameter SW        = 16 + CW             // total state bits
)(
    input  wire [SW-1:0] st,       // current state (own or voted)
    input  wire          start,    // 1-cycle request, sampled in IDLE
    input  wire [7:0]    din,
    output reg  [SW-1:0] st_next,
    output wire          tx,
    output wire          busy
);
    localparam [2:0] S_IDLE = 3'd0, S_START = 3'd1, S_DATA = 3'd2,
                     S_PAR  = 3'd3, S_STOP  = 3'd4, S_RECOV = 3'd5;

    // ---- unpack --------------------------------------------------------------
    wire          tx_q    = st[0];
    wire          par     = st[1];
    wire [7:0]    shreg   = st[9:2];
    wire [2:0]    bit_idx = st[12:10];
    wire [CW-1:0] baud    = st[13+CW-1:13];
    wire [2:0]    fsm     = st[SW-1:SW-3];

    reg           tx_n, par_n;
    reg  [7:0]    sh_n;
    reg  [2:0]    bit_n, fsm_n;
    reg  [CW-1:0] baud_n;

    // ">=" (not "==") so that an upset which pushes the counter past its
    // terminal value cannot make it run away for 2^CW cycles.
    wire bit_end = (baud >= CPB - 1);

    always @* begin
        // default: hold
        tx_n = tx_q;  par_n = par;  sh_n = shreg;
        bit_n = bit_idx;  baud_n = baud;  fsm_n = fsm;

        case (fsm)
        S_IDLE: begin
            tx_n = 1'b1;  baud_n = 0;  bit_n = 0;
            if (start) begin
                sh_n  = din;
                par_n = ^din;              // even parity
                tx_n  = 1'b0;              // start bit
                fsm_n = S_START;
            end
        end
        S_START: begin
            if (bit_end) begin
                baud_n = 0;  tx_n = shreg[0];  fsm_n = S_DATA;
            end else baud_n = baud + 1'b1;
        end
        S_DATA: begin
            if (bit_end) begin
                baud_n = 0;
                sh_n   = {1'b0, shreg[7:1]};
                if (bit_idx == 3'd7) begin
                    bit_n = 0;
                    if (PARITY_EN) begin tx_n = par;  fsm_n = S_PAR;  end
                    else           begin tx_n = 1'b1; fsm_n = S_STOP; end
                end else begin
                    bit_n = bit_idx + 1'b1;
                    tx_n  = shreg[1];
                end
            end else baud_n = baud + 1'b1;
        end
        S_PAR: begin
            if (bit_end) begin
                baud_n = 0;  tx_n = 1'b1;  fsm_n = S_STOP;
            end else baud_n = baud + 1'b1;
        end
        S_STOP: begin
            if (bit_end) begin
                baud_n = 0;  tx_n = 1'b1;  fsm_n = S_IDLE;
            end else baud_n = baud + 1'b1;
        end
        S_RECOV: begin                     // line held idle (1) for 8 bit
            tx_n = 1'b1;                   // times, then PAR + STOP (tx=1)
            if (bit_end) begin             // = 10 idle bit times in total, so
                baud_n = 0;                // the far-end receiver finishes the
                if (bit_idx == 3'd7) begin // broken frame and re-synchronises
                    bit_n = 0;  fsm_n = S_PAR;
                end else bit_n = bit_idx + 1'b1;
            end else baud_n = baud + 1'b1;
        end
        default: begin                     // illegal code (6,7) after an upset
            fsm_n = S_RECOV;               // -> abort frame, safe recovery
            tx_n  = 1'b1;  baud_n = 0;  bit_n = 0;
        end
        endcase

        st_next = {fsm_n, baud_n, bit_n, sh_n, par_n, tx_n};
    end

    assign tx   = tx_q;
    assign busy = (fsm != S_IDLE);
endmodule
