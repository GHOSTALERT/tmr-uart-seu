#!/bin/sh
# Directed self-checking tests for all three versions.
#   Icarus Verilog (free):   ./run_sim.sh
#   Cadence Xcelium (lab):   xrun -sv rtl/*.v sim/*.v tb/tb_directed.v -defparam tb_directed.MODE=2 -access +r
#   Gate-level (after Genus): add +define+GATE_LEVEL, replace rtl/*.v with
#                             syn/out/uart_tmr_top_netlist.v + rtl/lfsr.v + the
#                             standard-cell Verilog models of your PDK
mkdir -p out
for m in 0 1 2; do
  iverilog -g2005 -P tb_directed.MODE=$m -o out/sim_mode$m.vvp rtl/lfsr.v rtl/uart_tx_core.v rtl/tx_replica.v rtl/maj3.v rtl/tmr_uart_tx.v rtl/uart_tmr_top.v sim/*.v tb/tb_directed.v || exit 1
  (cd out && vvp -n sim_mode$m.vvp | grep -v "VCD info")
done
