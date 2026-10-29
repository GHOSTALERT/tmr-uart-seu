// -----------------------------------------------------------------------------
// tx_replica.v  -  One UART-TX replica = next-state core + state register
//
//   st_fb   : state used to compute the next state.
//             module-level TMR  -> st_fb = own st_q
//             voted-feedback TMR -> st_fb = voted state  (self-correcting)
//   fi_mask : SEU injection. Every '1' bit flips the corresponding flip-flop
//             at this clock edge (st_q <= st_next ^ fi_mask). Tie to 0 for
//             synthesis - the XOR is then optimised away.
//
// keep_hierarchy stops synthesis (Yosys / Vivado) from merging the three
// identical replicas back into one - otherwise the redundancy disappears.
// In Vivado also add  set_property DONT_TOUCH true [get_cells u_rep*]
// -----------------------------------------------------------------------------
(* keep_hierarchy *)
module tx_replica #(
    parameter CPB       = 16,
    parameter PARITY_EN = 1,
    parameter CW        = (CPB > 1) ? $clog2(CPB) : 1,
    parameter SW        = 16 + CW
)(
    input  wire          clk,
    input  wire          rst,
    input  wire [SW-1:0] st_fb,
    input  wire          start,
    input  wire [7:0]    din,
    input  wire [SW-1:0] fi_mask,
    output reg  [SW-1:0] st_q
);
    wire [SW-1:0] st_next;

    uart_tx_core #(.CPB(CPB), .PARITY_EN(PARITY_EN), .CW(CW), .SW(SW)) u_core (
        .st(st_fb), .start(start), .din(din),
        .st_next(st_next), .tx(), .busy()
    );

    // reset value: IDLE, line high
    localparam [SW-1:0] RST_ST = {{(SW-1){1'b0}}, 1'b1};

    always @(posedge clk) begin
        if (rst) st_q <= RST_ST;
        else     st_q <= st_next ^ fi_mask;
    end
endmodule
