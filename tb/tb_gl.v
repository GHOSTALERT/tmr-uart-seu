// tb_gl.v - gate-level testbench for uart_tmr_m2 (Genus netlist)
// Drives clk/rst/run only (data comes from the on-chip LFSR),
// decodes the tx line like a UART receiver and checks every byte.
`timescale 1ns/1ps
module tb_gl;
    localparam CPB    = 16;          // clocks per bit (as synthesised)
    localparam TCLK   = 10;          // 10 ns clock = 100 MHz
    localparam TBIT   = CPB*TCLK;    // one UART bit = 160 ns
    localparam NFRAME = 10;          // frames to check

    reg clk = 0, rst = 1, run = 0;
    wire tx, busy, start;
    wire [7:0] data;
    wire [2:0] fault_flag;

    uart_tmr_m2 dut (.clk(clk), .rst(rst), .run(run), .tx(tx), .busy(busy),
                     .start(start), .data(data), .fault_flag(fault_flag));

    always #(TCLK/2) clk = ~clk;

    // ---- remember each byte the transmitter starts sending ----
    reg [7:0] sent [0:255];
    integer nsent = 0;
    always @(posedge clk)
        if (!rst && start === 1'b1) begin
            sent[nsent % 256] = data;
            nsent = nsent + 1;
        end

    // ---- UART receiver model: decode the tx line ----
    reg [7:0] rx_byte;
    reg       rx_par, rx_stop;
    integer   i, nrx = 0, nok = 0, nbad = 0;

    always begin
        @(negedge tx);
        if (!rst) begin
            #(TBIT/2);                         // middle of start bit
            if (tx === 1'b0) begin
                for (i = 0; i < 8; i = i + 1) begin
                    #(TBIT); rx_byte[i] = tx;  // data bits, LSB first
                end
                #(TBIT); rx_par  = tx;         // parity bit
                #(TBIT); rx_stop = tx;         // stop bit
                if (rx_byte === sent[nrx % 256] && rx_par === ^rx_byte && rx_stop === 1'b1) begin
                    nok = nok + 1;
                    $display("%8d ns  frame %0d  sent %h  received %h  parity ok   OK",
                             $time, nrx, sent[nrx % 256], rx_byte);
                end else begin
                    nbad = nbad + 1;
                    $display("%8d ns  frame %0d  sent %h  received %h  par=%b stop=%b  ** ERROR **",
                             $time, nrx, sent[nrx % 256], rx_byte, rx_par, rx_stop);
                end
                nrx = nrx + 1;
            end
        end
    end

    // ---- stimulus ----
    initial begin
`ifdef __ICARUS__
        $dumpfile("waves.vcd");  $dumpvars(0, tb_gl);
`else
        $shm_open("waves.shm");  $shm_probe(tb_gl, "AS");
`endif
        repeat (5) @(posedge clk);
        rst = 0;
        repeat (3) @(posedge clk);
        run = 1;
        wait (nrx == NFRAME);
        #(2*TBIT);
        $display("==================================================");
        $display(" %0d frames received: %0d OK, %0d errors   -> %s",
                 nrx, nok, nbad, (nbad == 0 && nok == NFRAME) ? "PASS" : "FAIL");
        $display(" fault_flag at end = %b (000 = no disagreement)", fault_flag);
        $display("==================================================");
        $finish;
    end

    initial begin
        #(NFRAME*14*TBIT + 50000);
        $display("TIMEOUT: only %0d frames received", nrx);
        $finish;
    end
endmodule
