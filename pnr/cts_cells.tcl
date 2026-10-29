# Step 3a: CTS found no buffers/inverters by default; name gsclib090's explicitly
set bufs [dbGet head.libCells.name CLKBUF*]
if {$bufs eq "0x0"} { set bufs [dbGet head.libCells.name BUF*] }
set invs [dbGet head.libCells.name CLKINV*]
if {$invs eq "0x0"} { set invs [dbGet head.libCells.name INV*] }
puts "CTS buffers  : $bufs"
puts "CTS inverters: $invs"
foreach c [concat $bufs $invs] { setDontUse $c false }
set_ccopt_property buffer_cells   $bufs
set_ccopt_property inverter_cells $invs
