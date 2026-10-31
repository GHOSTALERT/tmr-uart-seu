# ####################################################################

#  Created by Genus(TM) Synthesis Solution 21.14-s082_1 on Thu Oct 29 10:08:15 IST 2026

# ####################################################################

set sdc_version 2.0

set_units -capacitance 1000fF
set_units -time 1000ps

# Set the current design
current_design uart_tmr_m2

create_clock -name "clk" -period 5.0 -waveform {0.0 2.5} [get_ports clk]
set_load -pin_load 0.005 [get_ports tx]
set_load -pin_load 0.005 [get_ports busy]
set_load -pin_load 0.005 [get_ports start]
set_load -pin_load 0.005 [get_ports {data[7]}]
set_load -pin_load 0.005 [get_ports {data[6]}]
set_load -pin_load 0.005 [get_ports {data[5]}]
set_load -pin_load 0.005 [get_ports {data[4]}]
set_load -pin_load 0.005 [get_ports {data[3]}]
set_load -pin_load 0.005 [get_ports {data[2]}]
set_load -pin_load 0.005 [get_ports {data[1]}]
set_load -pin_load 0.005 [get_ports {data[0]}]
set_load -pin_load 0.005 [get_ports {fault_flag[2]}]
set_load -pin_load 0.005 [get_ports {fault_flag[1]}]
set_load -pin_load 0.005 [get_ports {fault_flag[0]}]
set_clock_gating_check -setup 0.0 
set_input_delay -clock [get_clocks clk] -add_delay 0.01 [get_ports rst]
set_input_delay -clock [get_clocks clk] -add_delay 0.01 [get_ports run]
set_output_delay -clock [get_clocks clk] -add_delay 0.01 [get_ports tx]
set_output_delay -clock [get_clocks clk] -add_delay 0.01 [get_ports busy]
set_output_delay -clock [get_clocks clk] -add_delay 0.01 [get_ports start]
set_output_delay -clock [get_clocks clk] -add_delay 0.01 [get_ports {data[7]}]
set_output_delay -clock [get_clocks clk] -add_delay 0.01 [get_ports {data[6]}]
set_output_delay -clock [get_clocks clk] -add_delay 0.01 [get_ports {data[5]}]
set_output_delay -clock [get_clocks clk] -add_delay 0.01 [get_ports {data[4]}]
set_output_delay -clock [get_clocks clk] -add_delay 0.01 [get_ports {data[3]}]
set_output_delay -clock [get_clocks clk] -add_delay 0.01 [get_ports {data[2]}]
set_output_delay -clock [get_clocks clk] -add_delay 0.01 [get_ports {data[1]}]
set_output_delay -clock [get_clocks clk] -add_delay 0.01 [get_ports {data[0]}]
set_output_delay -clock [get_clocks clk] -add_delay 0.01 [get_ports {fault_flag[2]}]
set_output_delay -clock [get_clocks clk] -add_delay 0.01 [get_ports {fault_flag[1]}]
set_output_delay -clock [get_clocks clk] -add_delay 0.01 [get_ports {fault_flag[0]}]
set_input_transition 0.02 [get_ports clk]
set_input_transition 0.02 [get_ports rst]
set_input_transition 0.02 [get_ports run]
set_wire_load_mode "enclosed"
