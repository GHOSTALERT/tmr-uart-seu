// IEEE-style two-column report for the TMR UART project (docx-js)
const fs = require("fs");
const path = require("path");
const {
  Document, Packer, Paragraph, TextRun, ImageRun, Table, TableRow, TableCell, WidthType, BorderStyle,
  AlignmentType, SectionType, TabStopType, Footer, PageNumber, LevelFormat, VerticalAlign, Tab,
} = require("docx");

const FIG = path.join(__dirname, "figs");
const dims = JSON.parse(fs.readFileSync(path.join(FIG, "dims.json")));
const FONT = "Times New Roman";

// ---- page geometry (IEEE A4: 14.32 mm side margins, 4.22 mm column gap)
const PAGE_W = 11906, PAGE_H = 16838, SIDE = 812, GAP = 239;
const TEXT_W = PAGE_W - 2 * SIDE;            // 10282 twips = 7.14 in
const COL_W = Math.floor((TEXT_W - GAP) / 2); // 5021 twips = 3.49 in
const tw2px = (t) => (t / 1440) * 96;

// ---- inline markup:  **bold**  *italic*  ^{sup}  _{sub}
function runs(text, base = {}) {
  const out = [];
  const re = /(\*\*[^*]+\*\*|\*[^*]+\*|\^\{[^}]+\}|_\{[^}]+\})/g;
  let last = 0, m;
  while ((m = re.exec(text)) !== null) {
    if (m.index > last) out.push(new TextRun({ text: text.slice(last, m.index), font: FONT, ...base }));
    const s = m[0];
    if (s.startsWith("**")) out.push(new TextRun({ text: s.slice(2, -2), bold: true, font: FONT, ...base }));
    else if (s.startsWith("*")) out.push(new TextRun({ text: s.slice(1, -1), italics: true, font: FONT, ...base }));
    else if (s.startsWith("^")) out.push(new TextRun({ text: s.slice(2, -1), superScript: true, font: FONT, ...base }));
    else out.push(new TextRun({ text: s.slice(2, -1), subScript: true, font: FONT, ...base }));
    last = m.index + s.length;
  }
  if (last < text.length) out.push(new TextRun({ text: text.slice(last), font: FONT, ...base }));
  return out;
}

const SZ = 20; // 10 pt body
const body = (text, opts = {}) => new Paragraph({
  children: runs(text, { size: SZ }),
  alignment: AlignmentType.JUSTIFIED,
  indent: opts.noIndent ? undefined : { firstLine: 202 },
  spacing: { after: 0, line: 240 },
  keepLines: false,
});

let secNo = 0, subNo = 0;
const ROMAN = ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X"];
function H1(title) {
  subNo = 0;
  const label = `${ROMAN[secNo++]}. `;
  return new Paragraph({
    children: [new TextRun({ text: label + title, smallCaps: true, font: FONT, size: SZ })],
    alignment: AlignmentType.CENTER, spacing: { before: 200, after: 90 }, keepNext: true,
  });
}
function H1u(title) { // unnumbered (Acknowledgment / References)
  return new Paragraph({
    children: [new TextRun({ text: title, smallCaps: true, font: FONT, size: SZ })],
    alignment: AlignmentType.CENTER, spacing: { before: 200, after: 90 }, keepNext: true,
  });
}
function H2(title) {
  const label = `${String.fromCharCode(65 + subNo++)}. `;
  return new Paragraph({
    children: [new TextRun({ text: label + title, italics: true, font: FONT, size: SZ })],
    spacing: { before: 120, after: 60 }, keepNext: true,
  });
}
function bullet(text) {
  return new Paragraph({
    children: runs(text, { size: SZ }), numbering: { reference: "bul", level: 0 },
    alignment: AlignmentType.JUSTIFIED, spacing: { after: 20, line: 240 },
  });
}
function eq(text, num) {
  return new Paragraph({
    children: [new TextRun({ children: [new Tab()], font: FONT, size: SZ }), ...runs(text, { size: SZ }),
               new TextRun({ children: [new Tab(), `(${num})`], font: FONT, size: SZ })],
    tabStops: [{ type: TabStopType.CENTER, position: Math.floor(COL_W / 2) }, { type: TabStopType.RIGHT, position: COL_W - 20 }],
    spacing: { before: 80, after: 80 },
  });
}

// ---- figures
const FIG_ORDER = ["fig_frame_col.png", "fig_block.png", "fig_modes.png", "fig_flow.png", "ss_sim_full.png", "ss_sim_zoom.png",
  "fig_fi_waveform.png", "fig_ppa.png", "ss_layout.png", "fig_power_breakdown.png", "fig_cmos_voter.png", "ss_cmos_schematic.png", "ss_cmos_waveform.png"];
const F = (file) => { const i = FIG_ORDER.indexOf(file); if (i < 0) throw new Error("no fig " + file); return i + 1; };
function figure(file, caption, widthTw, opts = {}) {
  const [pw, ph] = dims[file];
  const w = tw2px(widthTw);
  const h = w * ph / pw;
  const figNo = F(file);
  return [
    new Paragraph({
      children: [new ImageRun({ type: "png", data: fs.readFileSync(path.join(FIG, file)), transformation: { width: Math.round(w), height: Math.round(h) } })],
      alignment: AlignmentType.CENTER, spacing: { before: opts.before ?? 120, after: 40 }, keepNext: true,
    }),
    new Paragraph({
      children: [new TextRun({ text: `Fig. ${figNo}. `, font: FONT, size: 16 }), ...runs(caption, { size: 16 })],
      alignment: AlignmentType.JUSTIFIED, spacing: { after: opts.after ?? 160 },
    }),
  ];
}

// ---- tables (IEEE: caption above, horizontal rules only)
let tabNo = 0;
const NB = { style: BorderStyle.NONE, size: 0, color: "FFFFFF" };
function table(title, header, rows, widths, opts = {}) {
  tabNo++;
  const total = widths.reduce((a, b) => a + b, 0);
  const align = opts.align || widths.map((_, i) => (i === 0 ? AlignmentType.LEFT : AlignmentType.CENTER));
  const mkRow = (cells, isHeader, isLast, idx) => new TableRow({
    tableHeader: isHeader, cantSplit: true,
    children: cells.map((c, i) => new TableCell({
      width: { size: widths[i], type: WidthType.DXA },
      margins: { top: 30, bottom: 30, left: 60, right: 60 },
      verticalAlign: VerticalAlign.CENTER,
      borders: {
        top: isHeader ? { style: BorderStyle.SINGLE, size: 8, color: "000000" } : NB,
        bottom: isHeader ? { style: BorderStyle.SINGLE, size: 4, color: "000000" } : (isLast ? { style: BorderStyle.SINGLE, size: 8, color: "000000" } : NB),
        left: NB, right: NB,
      },
      children: [new Paragraph({
        children: runs(String(c), { size: 15, bold: isHeader && !String(c).includes("**") ? true : undefined }),
        alignment: align[i], spacing: { after: 0, line: 220 }, keepNext: !isLast, keepLines: true,
      })],
    })),
  });
  return [
    new Paragraph({ children: [new TextRun({ text: `TABLE ${ROMAN[tabNo - 1]}`, font: FONT, size: 16 })],
      alignment: AlignmentType.CENTER, spacing: { before: 160, after: 0 }, keepNext: true }),
    new Paragraph({ children: [new TextRun({ text: title, smallCaps: true, font: FONT, size: 16 })],
      alignment: AlignmentType.CENTER, spacing: { after: 60 }, keepNext: true }),
    new Table({
      width: { size: total, type: WidthType.DXA }, columnWidths: widths, alignment: AlignmentType.CENTER,
      borders: { top: NB, bottom: NB, left: NB, right: NB, insideHorizontal: NB, insideVertical: NB },
      rows: [mkRow(header, true, false, 0), ...rows.map((r, i) => mkRow(r, false, i === rows.length - 1, i + 1))],
    }),
    ...(opts.note ? [new Paragraph({ children: runs(opts.note, { size: 14 }), spacing: { before: 30, after: 160 }, alignment: AlignmentType.LEFT })]
                  : [new Paragraph({ children: [], spacing: { after: 120 } })]),
  ];
}

// =====================================================================================
//  CONTENT
// =====================================================================================
const titleBlock = [
  new Paragraph({
    children: [new TextRun({ text: "Design and Verification of an SEU-Tolerant UART Transmitter Using Triple Modular Redundancy with Voted State Feedback in 90-nm CMOS", font: FONT, size: 44 })],
    alignment: AlignmentType.CENTER, spacing: { before: 0, after: 240 },
  }),
];

function authorCell(name, reg) {
  const p = (t, o = {}) => new Paragraph({ children: [new TextRun({ text: t, font: FONT, ...o })], alignment: AlignmentType.CENTER, spacing: { after: 0 } });
  return new TableCell({
    width: { size: Math.floor(TEXT_W / 3), type: WidthType.DXA },
    borders: { top: NB, bottom: NB, left: NB, right: NB },
    children: [
      p(name, { size: 22 }),
      p(`Reg. No. ${reg}`, { size: 18, italics: true }),
      p("School of Electronics Engineering", { size: 18, italics: true }),
      p("Vellore Institute of Technology, India", { size: 18, italics: true }),
    ],
  });
}
const authors = new Table({
  width: { size: TEXT_W, type: WidthType.DXA }, columnWidths: [Math.floor(TEXT_W / 3), Math.floor(TEXT_W / 3), TEXT_W - 2 * Math.floor(TEXT_W / 3)],
  borders: { top: NB, bottom: NB, left: NB, right: NB, insideHorizontal: NB, insideVertical: NB },
  rows: [new TableRow({ children: [authorCell("Aditya Manoj", "24BVD0070"), authorCell("Arrnav Trisal", "24BVD0064"), authorCell("Ananya Bisht", "24BVD0035")] })],
});
const courseLine = new Paragraph({
  children: runs("Course project, BECE303L VLSI System Design (Fall Semester 2026–27). Faculty: Aarthy M.", { size: 18, italics: true }),
  alignment: AlignmentType.CENTER, spacing: { before: 160, after: 280 },
});

const abstract = new Paragraph({
  children: [
    new TextRun({ text: "Abstract", bold: true, italics: true, font: FONT, size: 18 }),
    new TextRun({ text: "—", bold: true, font: FONT, size: 18 }),
    ...runs("Single-event upsets (SEUs) flip the contents of storage elements and can corrupt serial links in space and safety-critical systems. This work designs, verifies and physically implements a UART transmitter protected by triple modular redundancy (TMR) in the Cadence GPDK090 90-nm technology. Three architectures are generated from one parameterised RTL description: an unprotected simplex transmitter, TMR with voting at the outputs only, and TMR whose voted state is fed back to every replica on each clock. An on-chip 8-bit de Bruijn LFSR supplies all frame data, so the design needs no externally applied data, and a fault-injection port can flip any of the 60 replica flip-flops. Under an identical upset schedule the simplex design delivered 2 of 5 frames correctly, output-only TMR 4 of 5 and voted-feedback TMR 5 of 5; only voted feedback survived two upsets that struck different replicas at different times. At the slow corner, voted-feedback TMR costs 2.82× the area and 2.29× the power of the simplex design, and only 5.4% more area than output-only TMR. The design passed logic equivalence checking (91 of 91 compare points), gate-level simulation and Innovus place and route with zero DRC violations, +2.076 ns setup slack and +0.062 ns hold slack at 200 MHz. A 14-transistor static CMOS majority voter was also designed and verified in Spectre.", { size: 18, bold: true }),
  ],
  alignment: AlignmentType.JUSTIFIED, spacing: { after: 120, line: 230 },
});
const indexTerms = new Paragraph({
  children: [
    new TextRun({ text: "Index Terms", bold: true, italics: true, font: FONT, size: 18 }),
    new TextRun({ text: "—", bold: true, font: FONT, size: 18 }),
    new TextRun({ text: "Single-event upset, triple modular redundancy, UART, majority voter, fault injection, LFSR, ASIC design flow, radiation hardening.", bold: true, font: FONT, size: 18 }),
  ],
  alignment: AlignmentType.JUSTIFIED, spacing: { after: 120, line: 230 },
});

// ---------------- I. Introduction
const sec1 = [
  H1("Introduction"),
  body("Radiation-induced soft errors are a leading reliability concern in modern CMOS. A particle strike deposits charge in a sensitive node and can flip the value held in a latch, flip-flop or memory cell without damaging the device [1], [2]. Such single-event upsets (SEUs) are routine in space and avionics, and systems built for these environments rely on mitigation techniques such as triple modular redundancy, error-correcting codes and configuration scrubbing [3]."),
  body("Triple modular redundancy (TMR), introduced by Lyons and Vanderkulk [4], replicates a module three times and passes the 2-out-of-3 majority of the three outputs, so that any single faulty module is masked. The universal asynchronous receiver/transmitter (UART) is a small but ubiquitous block in SoCs and controllers. An upset in its frame state machine, bit counter or shift register corrupts the frame in flight, and earlier work has protected a UART with a combination of TMR, Hamming coding and parity storing [5]."),
  body("The simplest way to apply TMR to a UART is to triplicate the whole transmitter and vote only its serial output. A recent analysis of TMR for finite state machines (FSMs) shows that this arrangement has no self-correcting capacity: an upset inside one replica stays there, and a second upset in another replica can later defeat the vote [6]. Voting the state itself, inside the feedback loop, removes this weakness [6], [7]. This project implements and compares both arrangements through a complete ASIC flow. Its contributions are:"),
  bullet("One parameterised RTL description that produces a simplex, an output-voted TMR and a voted-feedback TMR UART transmitter, with flags that identify a disagreeing replica."),
  bullet("Automatic stimulus: an on-chip 8-bit de Bruijn LFSR generates every frame and covers all 256 byte values, so no data is applied by hand."),
  bullet("A fault-injection port and a five-frame SEU schedule that expose error accumulation, the key difference between the two TMR styles."),
  bullet("Implementation in GPDK090: Genus synthesis, Conformal equivalence checking, gate-level simulation, Innovus place and route with sign-off timing, and a transistor-level static CMOS majority voter simulated in Spectre."),
];

// ---------------- II. Background
const sec2 = [
  H1("Background and Related Work"),
  H2("Single-Event Upsets"),
  body("When the charge collected at a struck node exceeds its critical charge, the node changes state; in a storage element the wrong value then persists until it is overwritten [2]. Scaling has lowered critical charge, which makes logic as well as memory susceptible [1]. At the register-transfer level an SEU is therefore modelled as the inversion of one flip-flop for one clock edge, which is the fault model used in this work. Liu *et al.* review radiation effects and mitigation in FPGAs, including TMR, scrubbing and ECC [3]."),
  H2("TMR and Voter Placement"),
  body("Lyons and Vanderkulk showed that TMR improves reliability only when the modules are already reliable, and that imperfect voters limit the achievable gain [4]. Kastensmidt *et al.* injected faults into several TMR versions of a digital filter and found that voters at the final output alone are not sufficient; the share of upsets that caused an error ranged from 4.03% to 0.98% depending on the number and placement of voters [8]. Johnson and Wirthlin introduced synchronization voters placed in feedback paths so that a repaired replica resynchronises with the others; placing voters after every flip-flop gave the best timing, at a 9.8% increase in critical path over TMR without such voters [7]."),
  body("Kubica and Czerwinski compared four ways of applying TMR to an FSM [6]. Triplicating the whole FSM and voting only the outputs is the simplest, but the machine cannot self-correct and errors can accumulate until a reset. Placing the voter on the state register outputs, in the feedback path, returns a faulty replica to the correct state cycle; their LUT overheads ranged from 1.41× to 3.08× of the unprotected design. At circuit level, Schrape *et al.* built radiation-hardened TMR flip-flops with low-overhead self-correction for space applications [9], the same repair-the-minority principle implemented inside a single cell."),
  H2("Fault Injection"),
  body("Emulation-based fault injection flips bits in a running design. Siecha *et al.* injected up to three million upsets into the configuration memory of an FPGA time-to-digital converter and observed integral non-linearity degrading by 8.8% as upsets accumulated, concluding that accumulated errors must be detected and corrected [10]. Grignani *et al.* characterised a RISC-V SoC hardened with TMR and Hamming ECC under proton irradiation [11]. For a UART, Razmkhah injected about 1000 single-bit and 1000 multiple-bit errors into a VHDL model and corrected all single-bit errors at 152% area and 81% power overhead [5]. This project applies the same idea in simulation through a dedicated fault-injection port."),
];

// ---------------- III. Design
const stateTable = table("Per-Replica State Vector (20 Bits)", ["Field", "Bits", "Function"], [
  ["tx_q", "1", "Registered serial output (glitch-free)"],
  ["par", "1", "Even parity of loaded byte"],
  ["shreg", "8", "Data shift register"],
  ["bit_idx", "3", "Data-bit counter, 0–7"],
  ["baud", "4", "Clocks-per-bit counter (CPB = 16)"],
  ["fsm", "3", "IDLE, START, DATA, PARITY, STOP, RECOVER"],
], [1000, 600, 3400], { align: [AlignmentType.LEFT, AlignmentType.CENTER, AlignmentType.LEFT] });

const sec3a = [
  H1("Design"),
  H2("UART Frame"),
  body(`Each frame carries a start bit, eight data bits sent least-significant bit first, an even-parity bit and a stop bit, 11 bits in total (Fig. ${F("fig_frame_col.png")}). One bit lasts CPB clock cycles; with CPB = 16 and a 100-MHz simulation clock, one bit takes 160 ns. The serial output is driven from a register so that it is free of glitches.`),
  ...figure("fig_frame_col.png", "UART frame for byte 0x01: start bit, data bits D0–D7 (LSB first), even parity (1) and stop bit.", COL_W - 100),
];
const sec3a2 = [
  H2("State-Vector Architecture"),
  body(`The complete state of one transmitter is packed into a single 20-bit vector (Table I). The next-state logic is a purely combinational function *s*' = *f*(*s*, start, din) in module uart_tx_core, and a replica is *f* plus a 20-bit register (tx_replica). Because the core does not know whether its input state is its own or a voted copy, the same core serves all three architectures, and the fault-injection port can reach every flip-flop of every replica.`),
  ...stateTable,
  H2("Three Architectures"),
  body(`A parameter MODE selects the architecture (Fig. ${F("fig_modes.png")}). MODE 0 is a single replica with no protection. MODE 1 triplicates the transmitter; each replica updates from its own state, *s*_{i} ← *f*(*s*_{i}), and only tx and busy are voted. This corresponds to whole-FSM TMR with output voters in [6]. MODE 2 updates every replica from the voted state, *s*_{i} ← *f*(MAJ(*s*_{0}, *s*_{1}, *s*_{2})), using three 20-bit voters, one per replica (Fig. ${F("fig_block.png")}). This corresponds to voting in the feedback loop [6], [7]. The majority function, applied bitwise, is`),
  eq("MAJ(*a*, *b*, *c*) = *ab* + *bc* + *ca*", 1),
  body("In MODE 2, if replica *k* is upset, at the next clock edge every replica computes from a majority that excludes the flipped bit, so the error disappears after one cycle and a later upset in another replica meets a clean state. In MODE 1 the flipped value remains in replica *k* until normal operation overwrites it, for example when the bit is shifted out or a new byte is loaded. Two upsets in different replicas within that window out-vote the healthy replica."),
  H2("Fault Detection"),
  body("A disagreement detector compares the three state vectors and raises"),
  eq("flag_{i} = (*s*_{i} ≠ *s*_{j}) ∧ (*s*_{i} ≠ *s*_{k})", 2),
  body("for the replica that differs from both others, which identifies the faulty module (fault_flag[2:0] = 001, 010 or 100)."),
];

const sec3b = [
  H2("LFSR Pattern Generator"),
  body("Frame data come from an 8-bit Fibonacci LFSR with the maximal-length polynomial *x*^{8} + *x*^{6} + *x*^{5} + *x*^{4} + 1, i.e. taps 8, 6, 5, 4 [12]. A plain maximal-length LFSR cycles through 255 states and never produces 0x00. The de Bruijn extension inverts the feedback when the lower seven bits are zero, which inserts the all-zero state and gives a period of 256, so every byte value is transmitted once in 256 frames. The LFSR advances on each start pulse; a start generator issues a one-clock start pulse when the transmitter has been idle for eight clocks and the input run is high. The only inputs are therefore clk, rst and run. Together with the receiver and signature register of the testbench, this forms a built-in self-test arrangement of pattern generator, circuit under test and response analyser [13]."),
  H2("Robustness Details"),
  body("Illegal FSM codes (6 and 7) lead to a RECOVER state that holds the line idle for ten bit times, so a receiver that was mid-frame finishes it and resynchronises. The baud counter terminates on ≥ CPB − 1 rather than equality, so an upset that pushes it past the terminal count cannot make it run for 2^{4} cycles. The replica and voter modules carry keep_hierarchy attributes, and the Genus script disables flip-flop merging, so that synthesis cannot collapse the identical replicas into one."),
];

// ---------------- IV. Verification methodology
const tcTable = table("Directed Test Cases", ["Test", "Condition", "Expected result"], [
  ["TC1", "Reset", "Line idle (1), not busy"],
  ["TC2", "300 fault-free frames", "All received; MISR = golden"],
  ["TC3–5", "One SEU in TX1, TX2, TX3", "Masked; faulty copy flagged"],
  ["TC6a", "SEU in FSM state of TX2", "Masked"],
  ["TC6b", "Same bit, same clock, 2 copies", "Defeats TMR (expected)"],
  ["TC6c", "2 copies, 5 clocks apart", "MODE 1 fails; MODE 2 masks"],
  ["TC7", "LFSR data sweep", "All 256 byte values sent"],
  ["TC8", "Illegal FSM code", "Recovers; link resynchronises"],
], [700, 2150, 2150], { align: [AlignmentType.LEFT, AlignmentType.LEFT, AlignmentType.LEFT] });

const sec4 = [
  H1("Verification Methodology"),
  H2("Self-Checking Test Environment"),
  body("The testbench decodes the tx line with a UART receiver model that synchronises the input with two flip-flops, re-checks the start bit at its midpoint and samples every bit at mid-bit, reporting parity and framing errors. A scoreboard compares each received byte with the byte the LFSR supplied, and a 16-bit multiple-input signature register (MISR, *x*^{16} + *x*^{15} + *x*^{13} + *x*^{4} + 1) compresses all received data into one signature that is compared with a golden value [13]."),
  H2("Directed Tests"),
  body("Table II lists the directed tests. All modes run TC1, TC2, TC7 and TC8; the TMR modes add the replica-specific cases TC3–TC6."),
  ...tcTable,
  H2("Fault Injection"),
  body("Each replica register is written as *s* ← *s*' ⊕ fi_mask, so every 1 in the 60-bit fi_mask flips the corresponding flip-flop at that clock edge. With the parameter FI_PORT = 0 the port is tied to zero and the XOR gates are removed by synthesis, so the reported area, power and timing are not affected. The comparison uses a five-frame schedule, identical for all three modes: no fault (F0); an upset in the shift register of copy 2 (F1); an upset in the FSM state register of copy 3 (F2); an upset in copy 1 followed five clocks later by an upset in the same stored bit of copy 2 (F3); and no fault (F4). For later emulation on an FPGA [10], a synthesisable injector with three independent LFSRs (31, 29 and 23 bits) chooses random upset times and locations."),
  H2("Tool Flow"),
  body(`Fig. ${F("fig_flow.png")} summarises the flow. RTL was simulated with Icarus Verilog and Cadence Xcelium 24.09. Synthesis used Genus 21.14 with the gsclib090 slow library and a 5-ns clock, identical for all three modes. Conformal LEC 21.10 compared the RTL with the netlist, and Xcelium simulated the netlist with the gsclib090 cell models. Innovus 21.15 performed place and route with a slow-corner setup view and a typical-corner hold view, and its power analysis gave post-route power. The majority voter was drawn in Virtuoso 6.1.8 and simulated with Spectre.`),
];

// ---------------- V. Results
const fiTable = table("Fault-Injection Results (Received Byte)", ["Frame / fault", "MODE 0", "MODE 1", "MODE 2"], [
  ["F0  none", "01 ✓", "01 ✓", "01 ✓"],
  ["F1  copy 2 shift reg.", "**22 ✗**", "02 ✓", "02 ✓"],
  ["F2  copy 3 FSM", "**F4 ✗**", "04 ✓", "04 ✓"],
  ["F3  copy 1, then copy 2", "**0A ✗**", "**0A ✗**", "08 ✓"],
  ["F4  none", "11 ✓", "11 ✓", "11 ✓"],
  ["**Frames correct**", "**2 / 5**", "**4 / 5**", "**5 / 5**"],
], [1900, 1030, 1030, 1040], { note: "Sent bytes F0–F4: 01, 02, 04, 08, 11. In MODE 0 every upset falls in its single copy. ✓ correct, ✗ corrupted." });

const synTable = table("Synthesis Results (Genus, Slow Corner, 5-ns Clock)", ["Metric", "MODE 0", "MODE 1", "MODE 2"], [
  ["Worst slack (ps)", "+2993.8", "+2889.8", "+2696.3"],
  ["Critical path (ns)", "2.006", "2.110", "2.304"],
  ["Approx. *f*_{max} (MHz)", "498", "474", "434"],
  ["Cell area (µm^{2})", "1345.77", "3593.76", "3789.04"],
  ["Area vs. MODE 0", "1.00×", "2.67×", "2.82×"],
  ["Cells (flip-flops)", "207 (37)", "576 (77)", "591 (77)"],
  ["Leakage (µW)", "6.8", "18.0", "19.3"],
  ["Internal (µW)", "127.1", "292.1", "281.4"],
  ["Switching (µW)", "20.8", "55.7", "52.9"],
  ["Total power (µW)", "154.7", "365.8", "353.6"],
  ["Power vs. MODE 0", "1.00×", "2.36×", "2.29×"],
], [1700, 1100, 1100, 1100], { note: "Critical path = 5000 ps − worst slack; f_max ≈ 1 / critical path. Power is Genus vectorless estimate." });

const pdTable = table("Physical Design Summary (MODE 2, Innovus)", ["Metric", "Value"], [
  ["Core size", "74.24 × 73.08 µm"],
  ["Instances / cell area", "593 / 3826.89 µm^{2}"],
  ["Density (with fillers)", "70.54% (100%)"],
  ["Setup WNS / TNS (slow)", "+2.076 ns / 0"],
  ["Hold WNS / TNS (typical)", "+0.062 ns / 0"],
  ["Violating / total paths", "0 / 91"],
  ["DRC violations", "0"],
  ["Connectivity", "No problems or warnings"],
  ["Total power (0.9 V, 200 MHz)", "527.3 µW"],
  ["  internal / switching / leakage", "397.4 / 110.2 / 19.6 µW"],
], [2700, 2300], { note: "Power from Innovus report_power with default activity 0.2; clock-tree buffers CLKBUFX16." });

const areaTable = table("Post-Route Area by Block (MODE 2)", ["Block", "Cells", "Area (µm^{2})"], [
  ["LFSR pattern generator", "32", "245.99"],
  ["Start generator, idle counter", "44", "323.95"],
  ["TX replica 0 / 1 / 2", "127 / 127 / 128", "799.29 / 799.29 / 801.56"],
  ["Feedback voter (merged)", "40", "203.61"],
  ["Output voter", "4", "19.68"],
  ["Disagreement detector", "90", "628.99"],
  ["Top-level glue", "1", "4.54"],
  ["**Total**", "**593**", "**3826.89**"],
], [2100, 1200, 1700]);

const ttTable = table("Majority Voter Truth Table from Spectre", ["Time (ns)", "A B C", "Expected Y", "Simulated Y"], [
  ["0–5", "1 1 1", "1", "1"], ["5–10", "1 1 0", "1", "1"], ["10–15", "1 0 1", "1", "1"], ["15–20", "1 0 0", "0", "0"],
  ["20–25", "0 1 1", "1", "1"], ["25–30", "0 1 0", "0", "0"], ["30–35", "0 0 1", "0", "0"], ["35–40", "0 0 0", "0", "0"],
], [1100, 1300, 1300, 1300], { note: "The pattern repeats from 40 to 80 ns with the same result." });

const sec5a = [
  H1("Results"),
  H2("Functional Verification"),
  body("All directed tests passed in RTL simulation: 6 of 6 checks for MODE 0 and 11 of 11 for MODE 1 and MODE 2. The MISR signature matched its golden value after 300 frames, and all 256 byte values were sent. TC6c separated the two TMR styles as intended: two upsets in different copies at different times corrupted MODE 1 but not MODE 2."),
  body(`The synthesised MODE 2 netlist (591 gsclib090 cells) was simulated in Xcelium with only clk, rst and run applied. Ten consecutive frames were decoded correctly with valid parity, carrying the LFSR sequence 01, 02, 04, 08, 11, 23, 47, 8E, 1C, 38, and fault_flag stayed at 000 (Figs. ${F("ss_sim_full.png")} and ${F("ss_sim_zoom.png")}). Because the LFSR advances on the same edge that loads the transmitter, the data bus shows the *next* byte while the current one is being sent.`),
];

const sec5b = [
  H2("Fault Injection"),
  body(`Table III gives the received byte for every frame of the schedule. The simplex design was corrupted by every upset. Output-voted TMR masked the single upsets of F1 and F2 but failed on F3, delivering 0x0A instead of 0x08, exactly as the simplex design did. Voted-feedback TMR delivered all five frames correctly. In every TMR run the sticky fault status reached 111, so each upset was detected and attributed to its copy.`),
  ...fiTable,
  body(`Fig. ${F("fig_fi_waveform.png")} shows frame F3 in detail. In MODE 1 the upset in copy 1 remains in its shift register; when copy 2 is hit 50 ns later, copies 1 and 2 agree on the wrong value of bit D1 and out-vote copy 3. The detector then reports 100, blaming the healthy copy, because a disagreement detector can only localise a single fault. In MODE 2 each upset raises fault_flag for one 10-ns clock and is overwritten on the next edge, so bit D1 is transmitted correctly.`),
];

const sec5c = [
  H2("Synthesis"),
  body(`Table IV and Fig. ${F("fig_ppa.png")} compare the three modes under identical constraints. TMR raised area by 2.67× (MODE 1) and 2.82× (MODE 2) rather than 3×, because the LFSR and start generator (17 of the 77 flip-flops) are shared, while voters and the detector add logic. This is within the 2.6× to 3.1× range that Kubica and Czerwinski report for their fully triplicated FSM models, although they count LUTs rather than silicon area [6]. Power rose by 2.36× and 2.29×; the difference between the two TMR modes is within the uncertainty of a vectorless estimate. The output voter added 0.10 ns to the critical path, and voted feedback added a further 0.19 ns (+9.2% over MODE 1), close to the 9.8% that Johnson and Wirthlin report for voters after every flip-flop [7]. Even MODE 2 meets the 200-MHz target with 2.7 ns of slack.`),
  ...synTable,
  body("The post-synthesis hierarchy contains only one 20-bit feedback voter instead of three. The three voters have identical inputs and identical logic, so Genus merged them. The replicas themselves were preserved (77 flip-flops), but the remaining voter is a single point of failure in the netlist. Setting the preserve attribute on the voter instances before synthesis avoids this, at the cost of about two more voters' area (roughly 400 µm^{2})."),
  H2("Equivalence Checking"),
  body("Conformal LEC compared the RTL (golden) with the Genus netlist (revised) for MODE 2. All 91 compare points, the 14 primary outputs and the 77 flip-flops, were equivalent, with every flip-flop mapped one-to-one. The fault-injection results obtained on RTL therefore apply to the gate-level netlist as well."),
  H2("Physical Design"),
  body(`The MODE 2 netlist was placed and routed in Innovus with a VDD/VSS core ring on Metal9/Metal8, vertical Metal8 stripes and a target utilisation of 70% (Fig. ${F("ss_layout.png")}). Clock-tree synthesis required the clock buffers and inverters to be named explicitly. Table V summarises the result: zero DRC violations, a clean connectivity report and positive setup and hold slack on all 91 paths. Table VI breaks the area down by block. The disagreement detector, which compares three 20-bit vectors, costs 629 µm^{2}, more than all voters together.`),
  ...figure("ss_layout.png", "Routed MODE 2 layout in Innovus: VDD/VSS ring and stripes, standard-cell rows and the replica flip-flops (labels reg[…]).", COL_W - 200),
  ...pdTable,
  ...areaTable,
  body(`Post-route power was 527.3 µW (Fig. ${F("fig_power_breakdown.png")}), higher than the Genus estimate of 353.6 µW because it includes the clock tree and the extracted wire load. Flip-flops account for 53.6% of it, as expected for a design whose registers are triplicated.`),
  ...figure("fig_power_breakdown.png", "Post-route power of MODE 2 by group (Innovus, 0.9 V, 200 MHz, default activity 0.2).", COL_W - 100),
  H2("Transistor-Level Majority Voter"),
  body(`To examine the voter at device level, a static CMOS majority gate was drawn in Virtuoso with gpdk090 transistors (Figs. ${F("fig_cmos_voter.png")} and ${F("ss_cmos_schematic.png")}). A 12-transistor complementary stage computes *X* = NOT(*AB* + *BC* + *CA*). Its pull-down network places the series pairs A–B, B–C and A–C in parallel, and its pull-up network places the parallel pairs (A∥B), (B∥C) and (A∥C) in series. A 2-transistor inverter restores *Y* = *AB* + *BC* + *CA*. The pull-up network has three PMOS devices in series and the pull-down network two NMOS devices in series, so the devices were sized at 720 nm and 240 nm respectively, with a 480/240-nm inverter, L = 100 nm, VDD = 1 V and a 10-fF load [14].`),
  ...figure("fig_cmos_voter.png", "14-transistor static CMOS majority voter (complementary stage plus output inverter).", COL_W - 100),
  ...figure("ss_cmos_schematic.png", "Voter schematic in Virtuoso with gpdk090 nmos1v/pmos1v devices, pulse sources and load capacitor.", COL_W - 60),
  body(`Inputs A, B and C were driven by 0–1 V pulses with periods of 40, 20 and 10 ns, which steps through all eight input combinations every 40 ns. A Spectre transient analysis over 80 ns (Fig. ${F("ss_cmos_waveform.png")}) matched the expected truth table in every interval (Table VII). Whenever exactly one input disagrees with the other two, for example A = B = 1 and C = 0 between 5 and 10 ns, the output follows the majority, which is the masking behaviour TMR relies on.`),
  ...figure("ss_cmos_waveform.png", "Spectre transient response of the voter: output Y and inputs C, B, A over 0–80 ns.", COL_W - 60),
  ...ttTable,
];

const sec6 = [
  H1("Discussion and Limitations"),
  body("The experiments confirm the central claim of [6] and [7] on a complete ASIC implementation. Output voting masks any single upset but lets a corrupted state persist inside its replica, so upsets spread over time across replicas eventually win the vote. Voting the state every clock bounds the lifetime of an upset to one cycle, for about 5% more area and 0.19 ns more delay than output voting. The study has the following limitations."),
  bullet("Synthesis merged the three feedback voters into one, which leaves a single point of failure; the voters should be preserved explicitly."),
  bullet("The disagreement detector can localise a single faulty copy but misattributes a double fault, as seen in F3 of MODE 1."),
  bullet("Power figures are vectorless; simulation-based switching activity would make the MODE 1 and MODE 2 power comparison exact."),
  bullet("Faults were injected at register-transfer level, which is valid for the netlist because LEC proved equivalence. Multiple-cell upsets were not modelled, and the replicas were not physically separated in the floorplan."),
  bullet("The transistor-level voter was verified functionally; its delay, power and layout were not characterised in this work."),
];

const sec7 = [
  H1("Conclusion"),
  body("A UART transmitter with three reliability levels was built from one RTL description, stimulated entirely by an on-chip de Bruijn LFSR and carried through synthesis, equivalence checking, gate-level simulation and place and route in GPDK090. Under the same upset schedule the simplex, output-voted and voted-feedback designs delivered 2, 4 and 5 of 5 frames correctly. Voted-feedback TMR was the only design to survive upsets that struck two replicas at different times, at 2.82× the area and 2.29× the power of the simplex design. The final layout met timing at 200 MHz with no DRC violations, and a 14-transistor CMOS majority voter was verified in Spectre."),
  body("Future work includes preserving three independent feedback voters, separating the replicas into distinct placement regions to reduce multiple-cell upsets, adding Hamming ECC to the data path as in [5] and [11], protecting a UART receiver in the same way, and running random fault campaigns on an FPGA with the synthesisable LFSR-driven injector [10]."),
];

const ack = [
  H1u("Acknowledgment"),
  body("The authors thank Aarthy M, faculty for BECE303L VLSI System Design, for her guidance, and the School of Electronics Engineering, Vellore Institute of Technology, for access to the Cadence design tools."),
];

const REFS = [
  "R. C. Baumann, “Radiation-induced soft errors in advanced semiconductor technologies,” *IEEE Trans. Device Mater. Rel.*, vol. 5, no. 3, pp. 305–316, Sep. 2005, doi: 10.1109/TDMR.2005.853449.",
  "P. E. Dodd and L. W. Massengill, “Basic mechanisms and modeling of single-event upset in digital microelectronics,” *IEEE Trans. Nucl. Sci.*, vol. 50, no. 3, pp. 583–602, Jun. 2003.",
  "Z. Liu, Z. Lu, L. Huang, Z. Yao, Z. Lu, and J. Zhang, “Recent advances on reliability of FPGAs in a radiation environment,” *Microelectron. J.*, vol. 148, Art. no. 106176, 2024.",
  "R. E. Lyons and W. Vanderkulk, “The use of triple-modular redundancy to improve computer reliability,” *IBM J. Res. Develop.*, vol. 6, no. 2, pp. 200–209, Apr. 1962.",
  "M. H. Razmkhah, “A micro-FT-UART for safety-critical SoC-based applications,” in *Proc. Int. Conf. Availability, Reliability and Security (ARES)*, Fukuoka, Japan, 2009, pp. 316–321, doi: 10.1109/ARES.2009.43.",
  "M. Kubica and R. Czerwinski, “Error mitigation methods for FSM using triple modular redundancy,” *Appl. Sci.*, vol. 15, no. 12, Art. no. 6726, Jun. 2025, doi: 10.3390/app15126726.",
  "J. M. Johnson and M. J. Wirthlin, “Voter insertion algorithms for FPGA designs using triple modular redundancy,” in *Proc. 18th ACM/SIGDA Int. Symp. Field-Programmable Gate Arrays (FPGA)*, Monterey, CA, USA, 2010, pp. 249–258, doi: 10.1145/1723112.1723154.",
  "F. L. Kastensmidt, L. Sterpone, L. Carro, and M. Sonza Reorda, “On the optimal design of triple modular redundancy logic for SRAM-based FPGAs,” in *Proc. Design, Automation and Test in Europe (DATE)*, Munich, Germany, 2005.",
  "O. Schrape, A. Breitenreiter, L. Lu, M. Andjelković, E. Pun-Garcia, M. López-Vallejo, and M. Krstić, “Low overhead self-correction in radiation-hardening-by-design triple modular redundancy flip-flops for space applications,” in *Proc. IEEE Int. Symp. Defect and Fault Tolerance in VLSI and Nanotechnology Systems (DFT)*, Barcelona, Spain, 2025, pp. 1–6, doi: 10.1109/DFT66274.2025.11257570.",
  "R. T. Siecha, G. Alemu, J. Prinzie, and P. Leroux, “Analysis of the SEU tolerance of an FPGA-based time-to-digital converter using emulation-based fault injection,” *Electronics*, vol. 14, no. 11, Art. no. 2176, May 2025, doi: 10.3390/electronics14112176.",
  "W. Grignani, D. A. Santos, C. Imianosky, D. R. Melo, F. Wrobel, and L. Dilillo, “Characterization of a fault-tolerant RISC-V SoC in an SRAM-based FPGA under proton irradiation,” in *Proc. 27th IEEE Latin American Test Symp. (LATS)*, Florianópolis, Brazil, 2026.",
  "P. Alfke, “Efficient shift registers, LFSR counters, and long pseudo-random sequence generators,” Xilinx, San Jose, CA, USA, Appl. Note XAPP052, v1.1, Jul. 1996.",
  "M. L. Bushnell and V. D. Agrawal, *Essentials of Electronic Testing for Digital, Memory and Mixed-Signal VLSI Circuits*. Boston, MA, USA: Kluwer Academic, 2000.",
  "N. H. E. Weste and D. M. Harris, *CMOS VLSI Design: A Circuits and Systems Perspective*, 4th ed. Boston, MA, USA: Addison-Wesley, 2011.",
];
const refs = [H1u("References"), ...REFS.map((r, i) => new Paragraph({
  children: [new TextRun({ text: `[${i + 1}]`, font: FONT, size: 16 }), new TextRun({ children: [new Tab()], font: FONT, size: 16 }), ...runs(r, { size: 16 })],
  tabStops: [{ type: TabStopType.LEFT, position: 400 }],
  indent: { left: 400, hanging: 400 }, alignment: AlignmentType.JUSTIFIED, spacing: { after: 40, line: 220 },
}))];

// ---------------- full-width figure bands
const band = (items) => items;
const bandBlock = figure("fig_block.png", "Architecture of the MODE 2 design. An on-chip LFSR and start generator drive three transmitter replicas; three feedback voters return the voted 20-bit state to every replica, an output voter drives tx and busy, and a detector names any disagreeing copy.", TEXT_W - 1400, { before: 0 });
const bandModes = figure("fig_modes.png", "The three architectures generated from one RTL description by the MODE parameter, and their behaviour under upsets.", TEXT_W - 2000, { before: 0 });
const bandFlow = figure("fig_flow.png", "Design and verification flow used in this project (tools and key outcomes).", TEXT_W - 400, { before: 0 });
const bandGL = [...figure("ss_sim_full.png", "Gate-level simulation of the MODE 2 netlist in SimVision (Xcelium 24.09), 0–18.9 µs: ten LFSR frames (data 02 → 71 shown on the bus while the previous byte is transmitted) and fault_flag = 0.", TEXT_W - 200, { before: 0 }),
                ...figure("ss_sim_zoom.png", "Zoom on the first frame: rst released, run asserted, one-clock start pulse, busy rises and tx drops for the 160-ns start bit.", TEXT_W - 200)];
const bandFI = figure("fig_fi_waveform.png", "Frame F3 (byte 0x08) with upsets in copy 1 at 85 ns and copy 2 at 135 ns in the same stored bit. Top: MODE 1 keeps both upsets, outputs 1 for bit D1 and the detector blames copy 3 (100). Bottom: MODE 2 overwrites each upset after one clock, and tx matches the correct waveform (dashed).", TEXT_W - 1000, { before: 0 });
const bandPPA = figure("fig_ppa.png", "Synthesis comparison of the three modes: cell area, total power and critical path (labels give the ratio to MODE 0 or the corresponding maximum frequency).", TEXT_W - 200, { before: 0 });

// ---------------- sections
const pageProps = (cols, first = false) => ({
  type: first ? undefined : SectionType.CONTINUOUS,
  page: { size: { width: PAGE_W, height: PAGE_H }, margin: { top: 1077, bottom: 1250, left: SIDE, right: SIDE, footer: 500 } },
  column: cols === 2 ? { count: 2, space: GAP, equalWidth: true } : { count: 1 },
});
const footer = { default: new Footer({ children: [new Paragraph({ alignment: AlignmentType.CENTER, children: [new TextRun({ children: [PageNumber.CURRENT], font: FONT, size: 16 })] })] }) };

const sections = [
  { properties: pageProps(1, true), footers: footer, children: [...titleBlock, authors, courseLine] },
  { properties: pageProps(2), footers: footer, children: [abstract, indexTerms, ...sec1, ...sec2, ...sec3a] },
  { properties: pageProps(1), footers: footer, children: bandBlock },
  { properties: pageProps(2), footers: footer, children: [...sec3a2, ...sec3b] },
  { properties: pageProps(1), footers: footer, children: [...bandModes, ...bandFlow] },
  { properties: pageProps(2), footers: footer, children: [...sec4, ...sec5a] },
  { properties: pageProps(1), footers: footer, children: [...bandGL] },
  { properties: pageProps(2), footers: footer, children: [...sec5b] },
  { properties: pageProps(1), footers: footer, children: [...bandFI, ...bandPPA] },
  { properties: pageProps(2), footers: footer, children: [...sec5c, ...sec6, ...sec7, ...ack, ...refs] },
  { properties: pageProps(1), footers: footer, children: [new Paragraph({ children: [] })] },
];

const doc = new Document({
  creator: "Aditya Manoj, Arrnav Trisal, Ananya Bisht",
  title: "SEU-Tolerant UART Transmitter Using TMR with Voted State Feedback",
  styles: { default: { document: { run: { font: FONT, size: SZ } } } },
  numbering: { config: [{ reference: "bul", levels: [{ level: 0, format: LevelFormat.BULLET, text: "•", alignment: AlignmentType.LEFT,
    style: { paragraph: { indent: { left: 300, hanging: 200 } } } }] }] },
  sections,
});

Packer.toBuffer(doc).then((buf) => {
  fs.writeFileSync(path.join(__dirname, "out", "TMR_UART_Report.docx"), buf);
  console.log("written");
});
