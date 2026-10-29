# ==============================================================
# Reference all-in-one flow. The lab run used the step-by-step scripts: init.tcl, step2.tcl, cts_cells.tcl, step3.tcl.
# Innovus place & route : TMR UART transmitter (gpdk090 / gsclib090)
#   Run from tmr_uart/pnr :   innovus -files innovus_tmr.tcl
#   (or start innovus and type:  source innovus_tmr.tcl)
#
#   Flow: init -> floorplan -> power -> place -> CTS -> route ->
#         post-route opt -> fillers -> verify -> reports -> outputs
#   A checkpoint is saved after every stage (restoreDesign <name>.dat <top>)
#   so you can reopen any stage in the GUI.
# ==============================================================
set MODE 2              ;# 0 simplex | 1 TMR output voting | 2 TMR voted feedback

set design   uart_tmr_m${MODE}
set FOUNDRY  /home/cadence/install/FOUNDRY/digital/90nm/dig
set LIB_DIR  $FOUNDRY/lib
set LEF_DIR  $FOUNDRY/lef
set out_dir  out
set rep_dir  Report_${design}
file mkdir $out_dir
file mkdir $rep_dir

# ------------------------------
# 1. MMMC (timing libraries, constraints, corners, views)
#    written to a file and handed to init_design (standard legacy flow)
# ------------------------------
set f [open mmmc_${design}.tcl w]
puts $f "create_library_set -name slow_lib    -timing \[list $LIB_DIR/slow.lib\]"
puts $f "create_library_set -name typical_lib -timing \[list $LIB_DIR/typical.lib\]"
puts $f "create_library_set -name fast_lib    -timing \[list $LIB_DIR/fast.lib\]"
puts $f "create_constraint_mode -name func_mode -sdc_files \[list ../syn/Netlist/${design}.sdc\]"
puts $f "create_rc_corner -name rc_typ"
puts $f "create_delay_corner -name slow_corner    -library_set slow_lib    -rc_corner rc_typ"
puts $f "create_delay_corner -name typical_corner -library_set typical_lib -rc_corner rc_typ"
puts $f "create_delay_corner -name fast_corner    -library_set fast_lib    -rc_corner rc_typ"
puts $f "create_analysis_view -name slow_view    -constraint_mode func_mode -delay_corner slow_corner"
puts $f "create_analysis_view -name typical_view -constraint_mode func_mode -delay_corner typical_corner"
puts $f "create_analysis_view -name fast_view    -constraint_mode func_mode -delay_corner fast_corner"
close $f

# ------------------------------
# 2. Initialise design
# ------------------------------
set init_lef_file  [list $LEF_DIR/gsclib090_translated.lef $LEF_DIR/gsclib090_tech.lef]
set init_verilog   ../syn/Netlist/${design}_netlist.v
set init_top_cell  $design
set init_pwr_net   VDD
set init_gnd_net   VSS
set init_mmmc_file mmmc_${design}.tcl

init_design -setup {slow_view} -hold {fast_view}
set_analysis_view -setup {slow_view} -hold {fast_view}

checkDesign -all
saveDesign 01_init

# ------------------------------
# 3. Floorplan
#    aspect ratio 1.0, 70 % core utilisation, 10 um core-to-boundary margin
# ------------------------------
floorPlan -r 1.0 0.7 10 10 10 10

# Connect cell power pins to the global nets
globalNetConnect VDD -type pgpin  -pin VDD -inst * -override
globalNetConnect VSS -type pgpin  -pin VSS -inst * -override
globalNetConnect VDD -type tiehi  -inst * -override
globalNetConnect VSS -type tielo  -inst * -override

# --- OPTIONAL TMR upgrade (later step): physically separate the replicas
# so one particle strike cannot hit two copies (multi-cell upset).
# Uncomment for MODE 1/2 after checking instance names with
#   dbGet top.insts.name *u_rep0*
# createInstGroup grp_rep0 -region 10 10 60 120
# addInstToInstGroup grp_rep0 {*u_rep0*}
# createInstGroup grp_rep1 -region 70 10 120 120
# addInstToInstGroup grp_rep1 {*u_rep1*}
# createInstGroup grp_rep2 -region 130 10 180 120
# addInstToInstGroup grp_rep2 {*u_rep2*}

saveDesign 02_floorplan

# ------------------------------
# 4. Power plan: core ring + vertical stripes + standard-cell rails
# ------------------------------
addRing -nets {VDD VSS} -type core_rings \
        -layer {top Metal5 bottom Metal5 left Metal6 right Metal6} \
        -width 2 -spacing 1 -offset 1

addStripe -nets {VDD VSS} -layer Metal6 -direction vertical \
          -width 1 -spacing 1 -set_to_set_distance 40 \
          -start_from left -start_offset 20

sroute -connect {corePin} -nets {VDD VSS}

saveDesign 03_power

# ------------------------------
# 5. Placement (+ pre-CTS optimisation)
# ------------------------------
setPlaceMode -place_global_place_io_pins true
place_opt_design
catch { setTieHiLoMode -maxFanout 8 ; addTieHiLo }
saveDesign 04_place
timeDesign -preCTS -outDir $rep_dir/timing_preCTS

# ------------------------------
# 6. Clock tree synthesis
# ------------------------------
source cts_cells.tcl   ;# CTS needs gsclib090 clock buffers named explicitly
ccopt_design
optDesign -postCTS -hold
saveDesign 05_cts
timeDesign -postCTS -outDir $rep_dir/timing_postCTS
timeDesign -postCTS -hold -outDir $rep_dir/timing_postCTS

# ------------------------------
# 7. Routing (+ post-route optimisation)
# ------------------------------
setNanoRouteMode -routeWithTimingDriven true
routeDesign
setAnalysisMode -analysisType onChipVariation
optDesign -postRoute -setup -hold
saveDesign 06_route

# ------------------------------
# 8. Filler cells (names taken from the library, e.g. FILL1..FILL64)
# ------------------------------
set fillers [dbGet [dbGet -p head.libCells.name FILL*].name]
if {$fillers ne "0x0" && $fillers ne ""} {
    addFiller -cell $fillers -prefix FILLER
} else {
    puts "WARNING: no FILL* cells found in the library - fillers skipped"
}

# ------------------------------
# 9. Physical verification
# ------------------------------
verifyConnectivity -report $rep_dir/connectivity.rpt
verify_drc         -report $rep_dir/drc.rpt
catch { verifyProcessAntenna -report $rep_dir/antenna.rpt }

# ------------------------------
# 10. Final reports
# ------------------------------
timeDesign -postRoute       -outDir $rep_dir/timing_postRoute
timeDesign -postRoute -hold -outDir $rep_dir/timing_postRoute
report_area  > $rep_dir/area.rpt
report_power > $rep_dir/power.rpt
summaryReport -noHtml -outfile $rep_dir/summary.rpt

# ------------------------------
# 11. Outputs
#   _pnr.v      netlist for post-layout STA (Tempus STAGE=post) / LEC
#   _pnr_pg.v   netlist WITH power pins (for LVS in Virtuoso)
#   .spef       parasitics for Tempus
#   .def        placement + routing (DEF In to Virtuoso)
#   .gds        layout (Stream In to Virtuoso) - needs the gpdk090 map file
#               and std-cell GDS; set the two paths below once you find them
# ------------------------------
saveNetlist $out_dir/${design}_pnr.v
saveNetlist -includePowerGround $out_dir/${design}_pnr_pg.v
extractRC
rcOut -spef $out_dir/${design}.spef
write_sdf   $out_dir/${design}.sdf
defOut -floorplan -netlist -routing $out_dir/${design}.def

set GDS_MAP   ""     ;# e.g. <gpdk090 install>/.../streamOut.map   <-- set when known
set CELL_GDS  ""     ;# e.g. $FOUNDRY/gds/gsclib090.gds             <-- set when known
if {[file exists $GDS_MAP] && [file exists $CELL_GDS]} {
    streamOut $out_dir/${design}.gds -mapFile $GDS_MAP -merge $CELL_GDS \
              -libName DesignLib -units 2000 -mode ALL
} else {
    puts "NOTE: GDS not written - set GDS_MAP and CELL_GDS (see section 11)"
}

saveDesign 07_final
puts "======================================"
puts "INNOVUS FLOW COMPLETE: $design"
puts "Reports : $rep_dir     Outputs : $out_dir"
puts "======================================"
