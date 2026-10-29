// -----------------------------------------------------------------------------
// tb_directed.v  -  Directed test cases TC1..TC8 (self-checking)
//   iverilog -g2005 -P tb_directed.MODE=2 -o sim.vvp rtl/*.v sim/*.v tb/tb_directed.v
// -----------------------------------------------------------------------------
`timescale 1ns/1ps
module tb_directed;
    parameter MODE = 2;
    parameter CPB  = 16;
    localparam CW   = $clog2(CPB);
    localparam SW   = 16 + CW;
    localparam NREP = (MODE == 0) ? 1 : 3;
    // bit positions inside the state vector (see uart_tx_core.v)
    localparam B_TX = 0, B_SH1 = 3, B_SH3 = 5, B_BAUD2 = 15, B_FSM0 = SW-3, B_FSM2 = SW-1;

    reg clk = 0, rst = 1, run = 0, inj_en = 0;
    reg [15:0] n_frames = 0;
    reg [3:0]  inj_rate = 8;
    reg [NREP*SW-1:0] ext = 0;

    wire tx, done;
    wire [2:0] flag, fstat;
    wire [15:0] sent, ok, bad, lost, spur, det, misr;
    wire [31:0] seus;

    tb_env #(.MODE(MODE), .CPB(CPB)) dut (
        .clk(clk), .rst(rst), .run(run), .n_frames(n_frames), .inj_en(inj_en),
        .inj_rate(inj_rate), .ext_fi_mask(ext), .tx(tx), .fault_flag(flag),
        .fault_status(fstat), .frames_sent(sent), .frames_ok(ok), .frames_bad(bad),
        .frames_lost(lost), .frames_spur(spur), .seu_count(seus), .detect_cnt(det),
        .misr(misr), .done(done));

    always #5 clk = ~clk;   // 100 MHz

    integer pass = 0, fail = 0;
    task check(input cond, input [8*72-1:0] name);
        begin
            if (cond) begin pass = pass + 1; $display("  PASS  %0s", name); end
            else      begin fail = fail + 1; $display("  FAIL  %0s", name); end
        end
    endtask

    task do_reset; begin rst = 1; run = 0; ext = 0; repeat (5) @(posedge clk); rst = 0; end endtask

    // run n frames, return when transmitter + receiver are quiet again
    task run_frames(input [15:0] n);
        begin
            n_frames = n;  run = 1;
            wait (done);
            repeat (CPB*14) @(posedge clk);
            run = 0;
        end
    endtask

    // flip bit 'b' of replica 'r' once, 'dly' clocks after the next frame start
    task automatic seu(input integer r, input integer b, input integer dly);
        begin
            @(posedge clk);
            while (!dut.start) @(posedge clk);
            repeat (dly) @(posedge clk);
            ext[r*SW + b] = 1'b1;  @(posedge clk);  #1 ext = 0;
        end
    endtask

    // ---- reference model of the pattern generator + MISR (for TC2) ----------
    function [7:0] tpg_next(input [7:0] q);
        reg fb;
        begin
            fb = ^(q & 8'hB8) ^ (q[6:0] == 0);
            tpg_next = {q[6:0], fb};
        end
    endfunction
    function [15:0] misr_next(input [15:0] m, input [7:0] d);
        misr_next = {m[14:0], ^(m & 16'hD008)} ^ {8'h00, d};
    endfunction

    reg  [255:0] seen;
    always @(posedge clk) if (dut.rx_valid) seen[dut.rx_data] <= 1'b1;

    reg [7:0]  q;   reg [15:0] gold;   integer i;
    reg        flagged;
    always @(posedge clk) if (|flag) flagged <= 1'b1;

    initial begin
        $dumpfile(MODE == 0 ? "wave_mode0.vcd" : MODE == 1 ? "wave_mode1.vcd" : "wave_mode2.vcd");
        $dumpvars(0, tb_directed);
        if (MODE == 0)      $display("=== Directed tests, MODE=0 (SIMPLEX) ===");
        else if (MODE == 1) $display("=== Directed tests, MODE=1 (TMR, output voting) ===");
        else                $display("=== Directed tests, MODE=2 (TMR, voted state feedback) ===");

        // TC1 reset
        do_reset;  @(posedge clk);
        check(tx === 1'b1 && dut.busy === 1'b0, "TC1 reset -> line idle (1), not busy");

        // TC2 + TC7 : 300 LFSR frames, no faults, all 256 byte values
        seen = 0;
        run_frames(300);
        q = 8'h01;  gold = 16'hFFFF;
        for (i = 0; i < 300; i = i + 1) begin gold = misr_next(gold, q); q = tpg_next(q); end
        check(ok == 300 && bad == 0 && lost == 0 && spur == 0, "TC2 300 frames received correctly");
        check(misr == gold, "TC2 MISR signature == golden");
        check(&seen, "TC7 all 256 byte values (0x00..0xFF) sent");
        $display("        signature = %h (golden %h)", misr, gold);

        if (MODE != 0) begin
            // TC3..TC5 : single SEU in each replica (shift register, mid frame)
            for (i = 0; i < 3; i = i + 1) begin
                do_reset;  flagged = 0;
                fork run_frames(2); seu(i, B_SH3, 3*CPB + 5); join
                check(ok == 2 && bad == 0 && lost == 0 && spur == 0 && fstat == (3'b001 << i),
                      i == 0 ? "TC3 SEU in TX1 masked + localised" :
                      i == 1 ? "TC4 SEU in TX2 masked + localised" :
                               "TC5 SEU in TX3 masked + localised");
            end
            // TC6a : SEU in FSM state register of TX2
            do_reset;
            fork run_frames(2); seu(1, B_FSM0, 4*CPB); join
            check(ok == 2 && bad == 0, "TC6a SEU in FSM state of TX2 masked");
            // TC6b : same bit, same cycle, two replicas -> beyond TMR (expected fail)
            do_reset;
            fork run_frames(1);
                 begin @(posedge clk); while (!dut.start) @(posedge clk); repeat (2*CPB+3) @(posedge clk);
                       ext[0*SW + B_TX] = 1; ext[1*SW + B_TX] = 1; @(posedge clk); #1 ext = 0; end
            join
            check(ok == 0, "TC6b same-bit SEU in 2 replicas defeats TMR (expected)");
            // TC6c : error ACCUMULATION - TX1 and TX2 are hit at DIFFERENT
            //        times (same stored data bit, 5 clocks apart, during the
            //        start bit). Each upset alone is harmless, but they stay
            //        latent in the shift registers until data bit 1 goes out.
            do_reset;
            fork run_frames(1);
                 seu(0, B_SH1, CPB/2);
                 seu(1, B_SH1, CPB/2 + 5);
            join
            if (MODE == 1)
                check(ok == 0, "TC6c 2 upsets at different times -> output-voted TMR FAILS");
            else
                check(ok == 1 && bad == 0, "TC6c 2 upsets at different times -> scrubbed, frame OK");
        end else begin
            // simplex: a single SEU corrupts the frame
            do_reset;
            fork run_frames(1); seu(0, B_SH3, 3*CPB + 5); join
            check(ok == 0, "TC3 simplex: single SEU corrupts the frame (expected)");
        end

        // TC8 : illegal FSM code is recovered to IDLE
        do_reset;
        fork run_frames(10); seu(0, B_FSM2, 2*CPB); join  // DATA(010)->110 illegal
        $display("        TC8: %0d of %0d frames received OK", ok, sent);
        check(ok >= 9 && dut.busy === 1'b0,
              "TC8 illegal FSM code -> safe recovery, link re-syncs");

        $display("=== MODE %0d: %0d passed, %0d failed ===", MODE, pass, fail);
        $finish;
    end

    initial begin #50_000_000; $display("TIMEOUT"); $finish; end
endmodule
