# ==============================================================
# Tempus STA : TMR UART transmitter
#   Run from tmr_uart/sta :   tempus -files tempus_tmr.tcl
#   (or start tempus and type:  source tempus_tmr.tcl)
#
#   STAGE pre  = after Genus   (netlist + SDC, wire-load estimate)
#   STAGE post = after Innovus (routed netlist + SPEF parasitics)
# ==============================================================
set MODE   2            ;# 0 simplex | 1 TMR output voting | 2 TMR voted feedback
set STAGE  pre          ;# pre | post

set design  uart_tmr_m${MODE}
set LIB_DIR /home/cadence/install/FOUNDRY/digital/90nm/dig/lib
set rep_dir Report_${design}_${STAGE}
file mkdir $rep_dir

# ---- Library
read_lib $LIB_DIR/slow.lib

# ---- Netlist + constraints
if {$STAGE eq "post"} {
    read_verilog ../pnr/out/${design}_pnr.v
} else {
    read_verilog ../syn/Netlist/${design}_netlist.v
}
set_top_module $design
read_sdc ../syn/Netlist/${design}.sdc
if {$STAGE eq "post"} {
    read_spef ../pnr/out/${design}.spef
}

# ---- Checks
check_design -type timing -out_file $rep_dir/check_design.rpt
check_timing > $rep_dir/check_timing.rpt

# ---- Timing
update_timing -full
report_timing -late  -max_paths 10 > $rep_dir/setup.rpt
report_timing -early -max_paths 10 > $rep_dir/hold.rpt
catch {report_analysis_summary > $rep_dir/summary.rpt}

puts "======================================"
puts "STA done: $design ($STAGE)   reports in $rep_dir"
puts "Worst setup / hold paths:"
report_timing -late  -max_paths 1
report_timing -early -max_paths 1
puts "======================================"
