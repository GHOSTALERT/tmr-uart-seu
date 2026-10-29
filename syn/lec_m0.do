// Conformal LEC (classic dofile syntax): RTL vs Genus netlist, MODE 0
// Run from syn/ after genus_tmr.tcl:   lec -XL -nogui -dofile lec_m0.do
set log file lec_m0.log -replace
read library -liberty slow.lib -both
read design ../rtl/lfsr.v ../rtl/uart_tx_core.v ../rtl/tx_replica.v ../rtl/maj3.v ../rtl/tmr_uart_tx.v ../rtl/uart_tmr_top.v ../rtl/uart_tmr_m0.v -systemverilog -golden
set root module uart_tmr_m0 -golden
read design Netlist/uart_tmr_m0_netlist.v -verilog -revised
set root module uart_tmr_m0 -revised
set flatten model -seq_constant
set system mode lec
add compared points -all
compare
report verification
