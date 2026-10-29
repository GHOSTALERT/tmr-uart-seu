// -----------------------------------------------------------------------------
// tb_env.v  -  Verification environment around the synthesis top
//              (simulation only - NOT synthesised)
//
//   uart_tmr_top (DUT) --tx--> uart_rx --> scoreboard + 16-bit MISR
//          ^ fi_mask
//          +-- seu_injector (random, LFSR-driven)  |  ext_fi_mask (directed)
// -----------------------------------------------------------------------------
module tb_env #(
    parameter MODE      = 2,
    parameter CPB       = 16,
    parameter PARITY_EN = 1,
    parameter GAP       = 8,
    parameter INJ_SEED  = 1,
    parameter CW        = (CPB > 1) ? $clog2(CPB) : 1,
    parameter SW        = 16 + CW,
    parameter NREP      = (MODE == 0) ? 1 : 3
)(
    input  wire               clk,
    input  wire               rst,
    input  wire               run,
    input  wire [15:0]        n_frames,     // 0 = forever
    input  wire               inj_en,
    input  wire [3:0]         inj_rate,
    input  wire [NREP*SW-1:0] ext_fi_mask,
    output wire               tx,
    output wire               busy,
    output wire [2:0]         fault_flag,
    output reg  [2:0]         fault_status, // sticky
    output reg  [15:0]        frames_sent,
    output reg  [15:0]        frames_ok,
    output reg  [15:0]        frames_bad,   // wrong byte / parity / framing
    output reg  [15:0]        frames_lost,  // nothing received for a frame
    output reg  [15:0]        frames_spur,  // frame received that was never sent
    output reg  [31:0]        seu_count,
    output reg  [15:0]        detect_cnt,
    output reg  [15:0]        misr,
    output wire               done
);
    assign done = (n_frames != 0) && (frames_sent == n_frames);

    wire [NREP*SW-1:0] rnd_mask;
    wire [NREP-1:0]    inj;
    wire               start;
    wire [7:0]         data;

    seu_injector #(.NREP(NREP), .SW(SW), .SEED(INJ_SEED)) u_inj (
        .clk(clk), .rst(rst), .en(inj_en), .rate(inj_rate),
        .fi_mask(rnd_mask), .inj(inj));

`ifdef GATE_LEVEL   // synthesised netlist: parameters are already fixed
    uart_tmr_top u_dut (
`else
    uart_tmr_top #(.MODE(MODE), .CPB(CPB), .PARITY_EN(PARITY_EN), .GAP(GAP),
                   .FI_PORT(1), .CW(CW), .SW(SW)) u_dut (
`endif
        .clk(clk), .rst(rst), .run(run && !done), .fi_mask(rnd_mask | ext_fi_mask),
        .tx(tx), .busy(busy), .start(start), .data(data), .fault_flag(fault_flag));

    wire [7:0] rx_data;
    wire       rx_valid, rx_perr, rx_ferr;
    uart_rx #(.CPB(CPB), .PARITY_EN(PARITY_EN), .CW(CW)) u_rx (
        .clk(clk), .rst(rst), .rx(tx), .data(rx_data), .valid(rx_valid),
        .parity_err(rx_perr), .frame_err(rx_ferr));

    // ---------------- scoreboard ----------------------------------------------
    reg  [7:0] expected;
    reg        pending;
    reg  [2:0] flag_d;
    integer    k;
    reg  [7:0] inj_now;
    always @* begin
        inj_now = 0;
        for (k = 0; k < NREP; k = k + 1)    inj_now = inj_now + inj[k];
        for (k = 0; k < NREP*SW; k = k + 1) inj_now = inj_now + ext_fi_mask[k];
    end

    always @(posedge clk) begin
        if (rst) begin
            expected <= 0;  pending <= 0;  flag_d <= 0;  fault_status <= 0;
            frames_sent <= 0;  frames_ok <= 0;  frames_bad <= 0;
            frames_lost <= 0;  frames_spur <= 0;  seu_count <= 0;
            detect_cnt <= 0;  misr <= 16'hFFFF;
        end else begin
            seu_count    <= seu_count + inj_now;
            flag_d       <= fault_flag;
            fault_status <= fault_status | fault_flag;
            if (|(fault_flag & ~flag_d)) detect_cnt <= detect_cnt + 1'b1;

            if (start) begin
                frames_sent <= frames_sent + 1'b1;
                expected    <= data;
                pending     <= 1'b1;
                if (pending && !rx_valid) frames_lost <= frames_lost + 1'b1;
            end
            if (rx_valid) begin
                misr <= {misr[14:0], ^(misr & 16'hD008)} ^ {8'h00, rx_data};
                if (!pending)
                    frames_spur <= frames_spur + 1'b1;
                else if (rx_data == expected && !rx_perr && !rx_ferr)
                    frames_ok   <= frames_ok + 1'b1;
                else
                    frames_bad  <= frames_bad + 1'b1;
                if (!start) pending <= 1'b0;
            end
        end
    end
endmodule
