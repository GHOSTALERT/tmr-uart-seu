# Step 1: import + floorplan.  Run from pnr/:  innovus  ->  source init.tcl
# LEF order matters: gsclib090_translated.lef (defines the layers) BEFORE gsclib090_tech.lef
set init_lef_file {/home/cadence/install/FOUNDRY/digital/90nm/dig/lef/gsclib090_translated.lef /home/cadence/install/FOUNDRY/digital/90nm/dig/lef/gsclib090_tech.lef}
set init_verilog   ../syn/Netlist/uart_tmr_m2_netlist.v
set init_top_cell  uart_tmr_m2
set init_pwr_net   VDD
set init_gnd_net   VSS
set init_mmmc_file mmmc.tcl
init_design

floorPlan -r 1.0 0.7 10 10 10 10
globalNetConnect VDD -type pgpin -pin VDD -inst * -override
globalNetConnect VSS -type pgpin -pin VSS -inst * -override
globalNetConnect VDD -type tiehi -inst * -override
globalNetConnect VSS -type tielo -inst * -override

puts "LAYERS: [dbGet head.layers.name]"
saveDesign 01_floorplan
