# How to run

```sh
git clone https://github.com/GHOSTALERT/tmr-uart-seu.git
cd tmr-uart-seu
```

The RTL tests need only [Icarus Verilog](https://steveicarus.github.io/iverilog/). Everything else needs the Cadence tools (Xcelium, Genus, Conformal, Innovus) and the GPDK090 / gsclib090 kit.

The PDK files (`slow.lib`, `typical.lib`, LEFs, cell Verilog models) are not included; copy `slow.lib` and `typical.lib` from your gsclib090 install into `syn/`.

```sh
# RTL directed tests for all three modes (Icarus Verilog)
./run_sim.sh

# Fault-injection comparison (Xcelium), from syn/
xrun -64bit -access +rwc -top tb_fi -defparam tb_fi.MODE=2 ../tb/tb_fi.v ../rtl/*.v

# Synthesis, from syn/ (MODE 0, 1 or 2)
genus            # then:  set MODE 2 ; source genus_tmr.tcl
lec -XL -nogui -dofile lec_m2.do

# Gate-level simulation, from syn/
xrun -64bit -access +rwc -timescale 1ns/1ps ../tb/tb_gl.v Netlist/uart_tmr_m2_netlist.v \
     -v /home/cadence/install/FOUNDRY/digital/90nm/dig/vlog/gsclib090.v

# Place and route, from pnr/
innovus          # then:  source init.tcl ; source step2.tcl ; source cts_cells.tcl ; source step3.tcl
```

## Lab notes (Cadence)

- In Innovus, `gsclib090_translated.lef` must be read before `gsclib090_tech.lef`; the translated LEF defines the metal layers.
- Clock-tree synthesis found no buffers until the gsclib090 `CLKBUF*` / `CLKINV*` cells were named explicitly (`pnr/cts_cells.tcl`).
- Conformal LEC 21.10 runs dofiles in classic syntax (`read library`, not `read_library`).
- Virtuoso Verilog In could not launch the Xcelium parser on the lab server, so the circuit is shown through SimVision, the Innovus layout and a hand-drawn transistor-level voter.
