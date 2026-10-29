// =============================================================================
// tb_fi.v - SEU fault-injection demo (waveforms for the report)
//
//   Run once per MODE:   0 = simplex, 1 = TMR output voting, 2 = TMR voted feedback
//   xrun -64bit -access +rwc -top tb_fi -defparam tb_fi.MODE=2 tb_fi.v ../rtl/*.v
//
//   5 frames, each with a different fault scenario:
//     F0  no fault                                   (reference)
//     F1  single SEU in TX2 shift register, mid-frame
//     F2  single SEU in TX3 FSM state register
//     F3  SEU in TX1, then SEU in TX2 5 clocks later (same data bit)
//           -> output-voted TMR fails, voted-feedback TMR scrubs it
//     F4  no fault                                   (recovery check)
//   (simplex has one copy, so every upset goes into that copy; F3 = one upset)
// =============================================================================
`timescale 1ns/1ps
module tb_fi;
    parameter MODE = 2;
    localparam CPB  = 16;
    localparam TCLK = 10;
    localparam TBIT = CPB*TCLK;
    localparam SW   = 20;                       // state bits per copy
    localparam NREP = (MODE == 0) ? 1 : 3;
    localparam NFR  = 5;
    // bit positions in a copy's state vector
    localparam B_SH1 = 3, B_SH3 = 5, B_FSM0 = SW-3;

    reg clk = 0, rst = 1, run = 0;
    reg [NREP*SW-1:0] fi_mask = 0;
    wire tx, busy, start;
    wire [7:0] data;
    wire [2:0] fault_flag;

    uart_tmr_top #(.MODE(MODE), .CPB(CPB), .GAP(200), .FI_PORT(1)) dut (   // long gap: receiver re-syncs after a broken frame
        .clk(clk), .rst(rst), .run(run), .fi_mask(fi_mask),
        .tx(tx), .busy(busy), .start(start), .data(data), .fault_flag(fault_flag));

    always #(TCLK/2) clk = ~clk;

    // ---- signals for the waveform window ----------------------------------
    wire tx_copy1, tx_copy2, tx_copy3;          // each copy's own tx output
    generate
        if (MODE == 0) begin : g_s
            assign tx_copy1 = dut.u_tx.g_simplex.s0[0];
            assign tx_copy2 = 1'bz;
            assign tx_copy3 = 1'bz;
        end else begin : g_t
            assign tx_copy1 = dut.u_tx.g_tmr.s0[0];
            assign tx_copy2 = dut.u_tx.g_tmr.s1[0];
            assign tx_copy3 = dut.u_tx.g_tmr.s2[0];
        end
    endgenerate
    reg [2:0] seu_hit = 0;                      // which copy is hit this cycle
    reg [2:0] fault_status = 0;                 // sticky version of fault_flag
    reg [2:0] frame_no = 0;
    reg       frame_err = 0;                    // 1 while a wrong frame is reported
    always @(posedge clk) fault_status <= rst ? 3'b0 : (fault_status | fault_flag);

    // ---- one SEU: flip bit 'b' of copy 'r' for exactly one clock edge -----
    task seu(input integer r, input integer b);
        begin
            @(negedge clk);
            fi_mask[r*SW + b] = 1'b1;  seu_hit[r] = 1'b1;
            @(negedge clk);
            fi_mask = 0;               seu_hit = 0;
        end
    endtask
    function integer rep(input integer r);      // simplex: always copy 0
        rep = (MODE == 0) ? 0 : r;
    endfunction

    // ---- fault schedule ----------------------------------------------------
    initial begin
        @(negedge rst);
        // F0: no fault
        @(posedge start); frame_no = 0;
        // F1: TX2 shift register, during data bit 2
        @(posedge start); frame_no = 1;
        repeat (3*CPB + 5) @(posedge clk);  seu(rep(1), B_SH3);
        // F2: TX3 FSM state register, during data bit 3
        @(posedge start); frame_no = 2;
        repeat (4*CPB) @(posedge clk);      seu(rep(2), B_FSM0);
        // F3: TX1 then TX2, same stored bit, 5 clocks apart, during start bit
        @(posedge start); frame_no = 3;
        repeat (CPB/2) @(posedge clk);      seu(rep(0), B_SH1);
        if (MODE != 0) begin repeat (4) @(posedge clk); seu(rep(1), B_SH1); end
        // F4: no fault
        @(posedge start); frame_no = 4;
    end

    // ---- remember each byte sent -------------------------------------------
    reg [7:0] sent [0:15];
    integer nsent = 0;
    always @(posedge clk)
        if (!rst && start === 1'b1) begin sent[nsent] = data; nsent = nsent + 1; end

    // ---- UART receiver model -----------------------------------------------
    reg [7:0] rx_byte;  reg rx_par, rx_stop;
    integer   i, nrx = 0, nok = 0, nbad = 0;
    reg [8*40-1:0] what;
    always begin
        @(negedge tx);
        if (!rst) begin
            #(TBIT/2);
            if (tx === 1'b0) begin
                for (i = 0; i < 8; i = i + 1) begin #(TBIT); rx_byte[i] = tx; end
                #(TBIT); rx_par  = tx;
                #(TBIT); rx_stop = tx;
                case (nrx)
                    0: what = "no fault";
                    1: what = (MODE == 0) ? "SEU in shift reg" : "SEU in TX2 shift reg";
                    2: what = (MODE == 0) ? "SEU in FSM"       : "SEU in TX3 FSM";
                    3: what = (MODE == 0) ? "SEU in shift reg" : "SEU TX1 + SEU TX2 (5 clk later)";
                    default: what = "no fault (recovery)";
                endcase
                if (rx_byte === sent[nrx] && rx_par === ^rx_byte && rx_stop === 1'b1) begin
                    nok = nok + 1;
                    $display("  F%0d %-32s sent %h  received %h   OK", nrx, what, sent[nrx], rx_byte);
                end else begin
                    nbad = nbad + 1;  frame_err = 1;
                    $display("  F%0d %-32s sent %h  received %h   ** CORRUPTED **", nrx, what, sent[nrx], rx_byte);
                    #(TBIT) frame_err = 0;
                end
                nrx = nrx + 1;
            end
        end
    end

    // ---- run -----------------------------------------------------------------
    initial begin
`ifdef __ICARUS__
        $dumpfile("fi.vcd");  $dumpvars(0, tb_fi);
`else
        if (MODE == 0)      $shm_open("fi_m0.shm");
        else if (MODE == 1) $shm_open("fi_m1.shm");
        else                $shm_open("fi_m2.shm");
        $shm_probe(tb_fi, "AS");
`endif
        if (MODE == 0)      $display("=== Fault injection, MODE 0: simplex (no TMR) ===");
        else if (MODE == 1) $display("=== Fault injection, MODE 1: TMR, output voting only ===");
        else                $display("=== Fault injection, MODE 2: TMR, voted state feedback ===");
        repeat (5) @(posedge clk);  rst = 0;
        repeat (3) @(posedge clk);  run = 1;
        wait (nrx == NFR);
        run = 0;
        #(2*TBIT);
        $display("  ------------------------------------------------------------");
        $display("  %0d frames: %0d OK, %0d corrupted.  Copies ever flagged (fault_status) = %b",
                 nrx, nok, nbad, fault_status);
        $finish;
    end
    initial begin #(NFR*16*TBIT + 20000); $display("TIMEOUT"); $finish; end
endmodule
