# Step 2: power plan + placement
addRing -nets {VDD VSS} -type core_rings -follow core \
        -layer {top Metal9 bottom Metal9 left Metal8 right Metal8} \
        -width 2 -spacing 1 -offset 1
addStripe -nets {VDD VSS} -layer Metal8 -direction vertical \
          -width 1 -spacing 1 -set_to_set_distance 25 \
          -start_from left -start_offset 12
sroute -connect {corePin} -nets {VDD VSS}
saveDesign 02_power

setPlaceMode -place_global_place_io_pins true
place_opt_design
saveDesign 03_place
timeDesign -preCTS
