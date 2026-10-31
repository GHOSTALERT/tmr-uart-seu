# Tool outputs (lab server run)

The raw reports and logs behind every number in the main README and the report. They are copied unchanged from the VIT Cadence server run of 27–29 Oct 2026. The only edits: licence-server addresses are replaced with `<license-server>`, and the gzipped Innovus timing reports are unzipped. The PDK files (`.lib`, `.lef`), the layout DEF and the waveform databases are not included.

| Folder | What | Key result |
|---|---|---|
| `syn/reports/` | Genus area, gates, power, timing and QoR reports for MODE 0, 1, 2 | MODE 2: 3789.04 µm², 353.6 µW, 2.304 ns critical path |
| `syn/netlist/` | Mapped gate-level netlists (gsclib090), SDC constraints and SDF delays for each mode | Input to `tb/tb_gl.v` and Innovus |
| `syn/logs/` | Full Genus session logs (`genus_m0/m1/m2.log`) | |
| `lec/lec_m2.log` | Conformal LEC, RTL vs MODE 2 netlist | 91 / 91 compare points equivalent, PASS |
| `sim/xrun_fi_m2.log` | Xcelium run of `tb_fi.v`, MODE 2 | 5 frames: 5 OK, 0 corrupted |
| `pnr/` | Innovus area, power, DRC and connectivity reports, the post-route netlist `uart_tmr_m2_pnr.v`, and the full `innovus.log` | 593 cells, 3826.89 µm², 0 DRC violations, connectivity clean |
| `pnr/timing/` | `timeDesign` summaries (pre-CTS, post-CTS, post-route, setup and hold) and the post-route reg2reg path reports | Setup WNS +2.076 ns at 5 ns, hold WNS +0.062 ns |
| `cmos_voter/` | Spectre netlist of the 14-transistor majority gate, the `spectre.out` log, and the schematic thumbnail | 0 errors |

To re-run the gate-level test against the committed netlist without re-synthesising (this needs the gsclib090 cell models, so it only runs on a machine with the kit):

```sh
xrun -64bit -access +rwc -timescale 1ns/1ps tb/tb_gl.v results/syn/netlist/uart_tmr_m2_netlist.v \
     -v /home/cadence/install/FOUNDRY/digital/90nm/dig/vlog/gsclib090.v
```
