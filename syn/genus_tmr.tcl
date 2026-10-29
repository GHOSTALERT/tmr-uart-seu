# ==============================
# Cadence Genus Synthesis Script
# Design: TMR UART transmitter (uart_tmr_m0 / m1 / m2)
#
# Run from the folder that holds this script, with the RTL in ../rtl :
#   genus -f genus_tmr.tcl                         (MODE 2, default)
#   genus -execute "set MODE 0" -f genus_tmr.tcl   (simplex)
#   genus -execute "set MODE 1" -f genus_tmr.tcl   (TMR, output voting)
#
#   MODE 0 = simplex (no TMR)          -> top module uart_tmr_m0
#   MODE 1 = TMR, output voting only   -> top module uart_tmr_m1
#   MODE 2 = TMR, voted state feedback -> top module uart_tmr_m2
# ==============================

# ------------------------------
# Variables
# ------------------------------
if {![info exists MODE]} { set MODE 2 }
set design  uart_tmr_m${MODE}
set rtl_dir ../rtl
set net_dir Netlist
set rep_dir Report
set rtl_files [list \
    $rtl_dir/lfsr.v \
    $rtl_dir/uart_tx_core.v \
    $rtl_dir/tx_replica.v \
    $rtl_dir/maj3.v \
    $rtl_dir/tmr_uart_tx.v \
    $rtl_dir/uart_tmr_top.v \
    $rtl_dir/${design}.v ]

# ------------------------------
# Create output directories
# ------------------------------
file mkdir $net_dir
file mkdir $rep_dir

# ------------------------------
# Debug check
# ------------------------------
puts "======================================"
puts "MODE        = $MODE"
puts "DESIGN      = $design"
puts "RTL FILES   = $rtl_files"
puts "NETLIST DIR = $net_dir"
puts "REPORT DIR  = $rep_dir"
puts "======================================"

# ------------------------------
# Read RTL and Technology Library
# ------------------------------
set LIB_DIR /home/cadence/install/FOUNDRY/digital/90nm/dig/lib
if {[file exists slow.lib]} { read_libs slow.lib } else { read_libs $LIB_DIR/slow.lib }
read_hdl -sv $rtl_files

# ------------------------------
# Elaborate Design
# ------------------------------
elaborate $design
current_design $design
check_design -unresolved

# ------------------------------
# KEEP THE REDUNDANCY  (MODE 1 and 2)
# The three replicas are identical logic. These settings stop Genus from
# flattening them and merging them (or their flip-flops) into one copy,
# which would silently delete the TMR.
# ------------------------------
foreach {attr val} {auto_ungroup none optimize_merge_flops false optimize_merge_latches false} {
    if {[catch {set_db $attr $val} e]} { puts "WARNING $attr: $e" }
}
foreach h [get_db hinsts] {
    set n [get_db $h .name]
    if {[string match "*u_rep*" $n] || [string match "*u_v*" $n]} {
        if {[catch {set_db $h .ungroup_ok false} e]}   { puts "WARNING ungroup_ok: $e" }
        if {[catch {set_db $h .boundary_opt false} e]} { puts "WARNING boundary_opt: $e" }
        puts "KEEPING hierarchy: $n"
    }
}

# ------------------------------
# Timing Constraints
# Same constraints for all three modes so the comparison is fair.
# 5 ns = 200 MHz. If slack is positive, reduce the period to find the
# maximum frequency (do the same for every MODE).
# ------------------------------
create_clock -name clk -period 5.0 [get_ports clk]

set_input_delay  0.01 -clock [get_clocks clk] [all_inputs]
set_output_delay 0.01 -clock [get_clocks clk] [all_outputs]
set_input_transition 0.02 [all_inputs]
set_load 0.005 [all_outputs]

# ------------------------------
# Synthesis Effort
# ------------------------------
set_db syn_generic_effort high
set_db syn_map_effort high
set_db syn_opt_effort high

# ------------------------------
# Generic Synthesis
# ------------------------------
syn_generic
write_hdl > ./${net_dir}/${design}_generic_netlist.v

# ------------------------------
# Technology Mapping
# ------------------------------
syn_map
write_hdl > ./${net_dir}/${design}_mapped_netlist.v

# ------------------------------
# Optimization
# ------------------------------
syn_opt

# ------------------------------
# Final netlist + constraints (+ SDF for gate-level simulation)
# ------------------------------
write_hdl > ./${net_dir}/${design}_netlist.v
write_sdc > ./${net_dir}/${design}.sdc
write_sdf > ./${net_dir}/${design}.sdf

# ------------------------------
# Reports
# ------------------------------
report_area   > ./${rep_dir}/${design}_area.rpt
report_gates  > ./${rep_dir}/${design}_gates.rpt
report_power  > ./${rep_dir}/${design}_power.rpt
report_timing > ./${rep_dir}/${design}_timing.rpt
report_qor    > ./${rep_dir}/${design}_qor.rpt

# Redundancy check: flip-flop count should be 37 (MODE 0) or 77 (MODE 1/2)
if {[catch {llength [get_db insts -if {.is_sequential}]} n_ff]} {
    set n_ff "see the Sequential line in ${rep_dir}/${design}_gates.rpt"
}
puts "======================================"
puts "SYNTHESIS COMPLETED: $design"
puts "Flip-flops in netlist : $n_ff   (expected 37 for MODE 0, 77 for MODE 1/2)"
puts "Netlists are in : $net_dir"
puts "Reports are in  : $rep_dir"
puts "======================================"
