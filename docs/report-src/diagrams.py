"""Generate SVG diagrams for the TMR UART report, render to PNG with Playwright."""
import os, asyncio
OUT = os.path.dirname(os.path.abspath(__file__))

INK = "#0b0b0b"; INK2 = "#52514e"; MUTED = "#8a8984"
BLUE = "#2a78d6"; ORANGE = "#eb6834"; AQUA = "#1baf7a"; RED = "#e34948"
BLUE_BG = "#eaf2fc"; ORANGE_BG = "#fdeee7"; AQUA_BG = "#e6f6f0"; GRAY_BG = "#f3f3f1"
FONT = "Inter, DejaVu Sans, Arial, sans-serif"

def svg(w, h, body):
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}"
 font-family="{FONT}" font-size="14" fill="{INK}">
<defs>
 <marker id="arr" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse">
  <path d="M0,0 L10,5 L0,10 z" fill="{INK2}"/></marker>
 <marker id="arrO" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse">
  <path d="M0,0 L10,5 L0,10 z" fill="{ORANGE}"/></marker>
</defs>
<rect width="{w}" height="{h}" fill="#ffffff"/>
{body}
</svg>'''

def box(x, y, w, h, title, lines=(), stroke=INK2, fill=GRAY_BG, tsize=15, lsize=12.5, rx=8):
    s = f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{rx}" fill="{fill}" stroke="{stroke}" stroke-width="1.6"/>'
    n = 1 + len(lines)
    total = tsize + len(lines) * (lsize + 5)
    ty = y + h / 2 - total / 2 + tsize - 2
    s += f'<text x="{x + w/2}" y="{ty}" text-anchor="middle" font-weight="600" font-size="{tsize}">{title}</text>'
    for i, l in enumerate(lines):
        s += f'<text x="{x + w/2}" y="{ty + (i+1)*(lsize+5)}" text-anchor="middle" font-size="{lsize}" fill="{INK2}">{l}</text>'
    return s

def line(pts, color=INK2, w=1.6, arrow=True, dash=None, marker="arr"):
    d = " ".join(f"{'M' if i == 0 else 'L'}{x},{y}" for i, (x, y) in enumerate(pts))
    a = f' marker-end="url(#{marker})"' if arrow else ""
    ds = f' stroke-dasharray="{dash}"' if dash else ""
    return f'<path d="{d}" fill="none" stroke="{color}" stroke-width="{w}"{a}{ds}/>'

def label(x, y, t, size=12, color=INK2, anchor="middle", weight="400", italic=False):
    st = ' font-style="italic"' if italic else ""
    return f'<text x="{x}" y="{y}" text-anchor="{anchor}" font-size="{size}" fill="{color}" font-weight="{weight}"{st}>{t}</text>'

def dot(x, y, c=INK2):
    return f'<circle cx="{x}" cy="{y}" r="3.2" fill="{c}"/>'

# ---------------------------------------------------------------- block diagram
def block_diagram():
    b = ""
    # inputs
    b += label(20, 175, "clk, rst, run", 12.5, INK2, "start")
    b += line([(20, 185), (40, 185), (40, 220), (52, 220)])
    b += box(52, 200, 175, 112, "LFSR pattern gen.", ["8-bit de Bruijn", "x⁸+x⁶+x⁵+x⁴+1", "all 256 bytes"], AQUA, AQUA_BG)
    b += box(52, 340, 175, 82, "Start generator", ["8-bit idle counter", "1-clk start pulse"], AQUA, AQUA_BG)
    b += line([(140, 312), (140, 340)], arrow=False)
    # data/start bus
    b += line([(227, 256), (262, 256)], arrow=False)
    b += line([(227, 381), (262, 381), (262, 256)], arrow=False)
    b += label(254, 140, "data[7:0]", 11.5, INK2, "end")
    b += label(244, 400, "start", 11.5)
    b += dot(262, 256)
    reps = [(300, 70), (300, 245), (300, 420)]
    # bus vertical
    b += line([(262, 110), (262, 460)], arrow=False)
    for i, (x, y) in enumerate(reps):
        b += line([(262, y + 40), (x, y + 40)])
        b += f'<rect x="{x}" y="{y}" width="250" height="125" rx="8" fill="{BLUE_BG}" stroke="{BLUE}" stroke-width="1.6"/>'
        b += label(x + 125, y + 20, f"TX copy {i+1}  (u_rep{i})", 14, INK, weight="600")
        b += box(x + 14, y + 32, 132, 80, "Next-state", ["logic (FSM, baud,", "bit cnt, shift reg,", "parity)"], BLUE, "#ffffff", 13, 11)
        b += box(x + 160, y + 32, 76, 80, "State", ["register", "20 FF"], BLUE, "#ffffff", 13, 11)
        b += line([(x + 146, y + 72), (x + 160, y + 72)])
        b += line([(x + 236, y + 72), (590, y + 72)], BLUE, 2)
        b += label(x + 262, y + 64, f"s{i}", 12, BLUE, weight="600")
        # feedback input at lower-left
        b += line([(278, y + 98), (x + 14, y + 98)], ORANGE, 1.8, marker="arrO")
    # bus collect
    b += line([(590, 142), (590, 492)], BLUE, 2, arrow=False)
    for yy in (142, 317, 492):
        b += dot(590, yy, BLUE)
    # feedback voters
    b += f'<rect x="640" y="40" width="190" height="120" rx="8" fill="{ORANGE_BG}" stroke="{ORANGE}" stroke-width="1.6"/>'
    b += label(735, 72, "Feedback voters", 15, INK, weight="600")
    b += label(735, 92, "3 × MAJ, 20-bit", 12.5, INK2)
    b += label(735, 110, "(one per copy)", 12.5, INK2)
    b += label(735, 140, "MODE 2 only", 12.5, ORANGE, weight="600")
    b += line([(590, 100), (640, 100)], BLUE, 2)
    b += dot(590, 100, BLUE)
    b += line([(590, 100), (590, 142)], BLUE, 2, arrow=False)
    # voted state back
    b += line([(735, 40), (735, 22), (278, 22), (278, 518)], ORANGE, 1.8, arrow=False)
    b += label(500, 16, "voted state  →  every copy (scrubs an upset on the next clock)", 12, ORANGE)
    # output voter
    b += box(640, 240, 190, 105, "Output voter", ["MAJ(tx₀, tx₁, tx₂)", "MAJ(busy₀, busy₁, busy₂)"], ORANGE, ORANGE_BG)
    b += line([(590, 292), (640, 292)], BLUE, 2)
    b += dot(590, 292, BLUE)
    b += line([(830, 270), (905, 270)])
    b += label(912, 274, "tx", 15, INK, "start", "600")
    b += line([(830, 318), (905, 318)])
    b += label(912, 322, "busy", 15, INK, "start", "600")
    # detector
    b += box(640, 410, 190, 100, "Disagreement", ["detector", "copy i ≠ both others"], INK2, GRAY_BG)
    b += line([(590, 460), (640, 460)], BLUE, 2)
    b += dot(590, 460, BLUE)
    b += line([(830, 460), (905, 460)])
    b += label(912, 464, "fault_flag[2:0]", 15, INK, "start", "600")
    b += label(735, 540, "77 flip-flops = 3 × 20 + 17 shared", 12, MUTED, "middle", italic=True)
    return svg(1040, 560, b)

# ---------------------------------------------------------------- three architectures
def modes_diagram():
    b = ""
    def tx(x, y, n, own=True):
        s = f'<rect x="{x}" y="{y}" width="92" height="46" rx="6" fill="{BLUE_BG}" stroke="{BLUE}" stroke-width="1.5"/>'
        s += label(x + 46, y + 28, f"TX {n}", 13, INK, weight="600")
        if own:  # self loop
            s += line([(x + 92, y + 34), (x + 104, y + 34), (x + 104, y + 56), (x + 46, y + 56), (x + 46, y + 46)], INK2, 1.3)
        return s
    # panel titles
    titles = [("MODE 0 — Simplex", "no protection"), ("MODE 1 — TMR, output voting", "each copy feeds back its own state"),
              ("MODE 2 — TMR, voted state feedback", "every copy feeds back the voted state")]
    xs = [20, 300, 640]
    for (t, st), x in zip(titles, xs):
        b += label(x, 30, t, 15, INK, "start", "600")
        b += label(x, 50, st, 12, INK2, "start")
    # mode 0
    b += tx(40, 140, "")
    b += line([(132, 163), (230, 163)])
    b += label(240, 167, "tx", 14, INK, "start", "600")
    # mode 1
    for i, y in enumerate((80, 150, 220)):
        b += tx(320, y, i + 1)
        b += line([(412, y + 23), (470, y + 23), (470, 173), (490, 173)] if i != 1 else [(412, y + 23), (490, y + 23)])
    b += f'<path d="M490,140 L540,140 Q575,173 540,206 L490,206 Z" fill="{ORANGE_BG}" stroke="{ORANGE}" stroke-width="1.5"/>'
    b += label(522, 178, "MAJ", 12.5, INK, weight="600")
    b += line([(565, 173), (600, 173)])
    b += label(606, 177, "tx", 14, INK, "start", "600")
    # mode 2
    for i, y in enumerate((80, 150, 220)):
        b += tx(660, y, i + 1, own=False)
        b += line([(752, y + 23), (800, y + 23)])
    b += f'<rect x="800" y="80" width="60" height="186" rx="6" fill="{ORANGE_BG}" stroke="{ORANGE}" stroke-width="1.5"/>'
    b += label(830, 165, "MAJ", 12.5, INK, weight="600")
    b += label(830, 182, "×3", 12, INK2)
    b += line([(830, 266), (830, 292), (645, 292), (645, 103), (660, 103)], ORANGE, 1.6, marker="arrO")
    b += line([(645, 173), (660, 173)], ORANGE, 1.6, marker="arrO")
    b += line([(645, 243), (660, 243)], ORANGE, 1.6, marker="arrO")
    b += label(752, 310, "voted state fed back to all copies", 11.5, ORANGE)
    b += line([(860, 173), (900, 173)])
    b += label(906, 177, "tx", 14, INK, "start", "600")
    # outcome strip
    outs = [("1 upset  →  frame corrupted", RED), ("1 upset masked;  2 upsets at", INK2), ("upsets scrubbed each clock;", INK2)]
    outs2 = [("", INK2), ("different times  →  corrupted", RED), ("2 upsets at different times masked", AQUA)]
    for (t, c), (t2, c2), x in zip(outs, outs2, xs):
        b += label(x, 345, t, 12.5, c, "start", "600")
        b += label(x, 363, t2, 12.5, c2, "start", "600")
    return svg(960, 380, b)

# ---------------------------------------------------------------- design flow
def flow_diagram():
    b = ""
    steps = [("RTL design", ["Verilog-2001", "6 modules"]),
             ("RTL sim + SEU", ["Xcelium / Icarus", "fault injection"]),
             ("Synthesis", ["Genus 21.14", "gsclib090 slow"]),
             ("Equivalence", ["Conformal LEC", "91/91 equiv."]),
             ("Gate-level sim", ["Xcelium 24.09", "10/10 frames"]),
             ("Place & route", ["Innovus 21.15", "DRC 0, STA met"])]
    x = 20
    for i, (t, ls) in enumerate(steps):
        b += box(x, 40, 150, 92, t, ls, BLUE if i % 2 == 0 else BLUE, BLUE_BG, 14.5, 12)
        if i < len(steps) - 1:
            b += line([(x + 150, 86), (x + 172, 86)])
        x += 172
    b += box(20, 170, 320, 80, "Fault-injection comparison", ["MODE 0 vs 1 vs 2, same upset schedule"], AQUA, AQUA_BG, 14.5, 12)
    b += box(372, 170, 300, 80, "Transistor-level voter", ["Virtuoso + Spectre", "gpdk090, 14T static CMOS"], ORANGE, ORANGE_BG, 14.5, 12)
    b += box(704, 170, 320, 80, "Sign-off reports", ["area · power · setup / hold timing", "DRC · connectivity"], INK2, GRAY_BG, 14.5, 12)
    b += line([(267, 132), (267, 170)])
    b += line([(959, 132), (959, 170)])
    return svg(1050, 270, b)

# ---------------------------------------------------------------- UART frame
def frame_diagram():
    b = ""
    bits = ["idle", "Start", "D0", "D1", "D2", "D3", "D4", "D5", "D6", "D7", "Parity", "Stop", "idle"]
    vals = [1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1]  # byte 0x01, even parity = 1
    x0, w, yh, yl = 40, 72, 60, 120
    pts = []
    for i, v in enumerate(vals):
        y = yh if v else yl
        pts += [(x0 + i * w, y), (x0 + (i + 1) * w, y)]
    d = " ".join(f"{'M' if i == 0 else 'L'}{x},{y}" for i, (x, y) in enumerate(pts))
    b += f'<path d="{d}" fill="none" stroke="{BLUE}" stroke-width="2.4"/>'
    for i, t in enumerate(bits):
        cx = x0 + i * w + w / 2
        b += f'<line x1="{x0 + i*w}" y1="40" x2="{x0 + i*w}" y2="140" stroke="#dcdbd7" stroke-width="1"/>'
        b += label(cx, 165, t, 12.5, INK if t not in ("idle",) else MUTED, weight="600" if t in ("Start", "Parity", "Stop") else "400")
        b += label(cx, 185, str(vals[i]), 12, INK2)
    b += label(18, 64, "1", 12, INK2); b += label(18, 124, "0", 12, INK2)
    b += label(40 + 6.5 * w, 215, "Example byte 0x01, LSB first, even parity = 1   ·   1 bit = 16 clocks (CPB) = 160 ns at 100 MHz   ·   frame = 11 bits", 12.5, INK2)
    return svg(1020, 230, b)

# ---------------------------------------------------------------- 14T CMOS majority voter
def mos(x, y, gate, ptype, name, wl):
    """Vertical MOSFET: drain top (x,y-30), source bottom (x,y+30), gate on the left."""
    c = BLUE if ptype else INK
    s = f'<line x1="{x}" y1="{y-30}" x2="{x}" y2="{y-14}" stroke="{c}" stroke-width="1.8"/>'
    s += f'<line x1="{x}" y1="{y+14}" x2="{x}" y2="{y+30}" stroke="{c}" stroke-width="1.8"/>'
    s += f'<line x1="{x}" y1="{y-14}" x2="{x-12}" y2="{y-14}" stroke="{c}" stroke-width="1.8"/>'
    s += f'<line x1="{x}" y1="{y+14}" x2="{x-12}" y2="{y+14}" stroke="{c}" stroke-width="1.8"/>'
    s += f'<line x1="{x-12}" y1="{y-18}" x2="{x-12}" y2="{y+18}" stroke="{c}" stroke-width="2.4"/>'
    s += f'<line x1="{x-19}" y1="{y-16}" x2="{x-19}" y2="{y+16}" stroke="{c}" stroke-width="1.8"/>'
    if ptype:
        s += f'<circle cx="{x-24}" cy="{y}" r="4" fill="#fff" stroke="{c}" stroke-width="1.6"/>'
        s += f'<line x1="{x-28}" y1="{y}" x2="{x-44}" y2="{y}" stroke="{c}" stroke-width="1.8"/>'
    else:
        s += f'<line x1="{x-19}" y1="{y}" x2="{x-44}" y2="{y}" stroke="{c}" stroke-width="1.8"/>'
    s += label(x - 50, y + 5, gate, 15, INK, "end", "700")
    s += label(x + 7, y - 2, name, 11, INK2, "start")
    s += label(x + 7, y + 12, wl, 10.5, MUTED, "start")
    return s

def wire(pts, c=INK):
    return line(pts, c, 1.6, arrow=False)

def cmos_voter():
    b = ""
    P, N = "720n/100n", "240n/100n"
    VDD, GND = 40, 610
    b += wire([(80, VDD), (520, VDD)]); b += label(300, VDD - 10, "VDD (1 V)", 13, INK, weight="600")
    b += wire([(80, GND), (700, GND)]); b += label(390, GND + 22, "GND", 13, INK, weight="600")
    # pull-up: three parallel pairs in series. pair columns at x=200 and 330
    pairs = [("A", "B"), ("B", "C"), ("A", "C")]
    ys = [100, 190, 280]
    top = VDD
    names = iter(["P1", "P2", "P3", "P4", "P5", "P6"])
    for (g1, g2), y in zip(pairs, ys):
        b += wire([(200, y - 30), (200, y - 40), (330, y - 40), (330, y - 30)])
        b += wire([(200, y + 30), (200, y + 40), (330, y + 40), (330, y + 30)])
        b += wire([(265, top), (265, y - 40)])
        b += dot(265, y - 40, INK)
        b += mos(200, y, g1, True, next(names), P)
        b += mos(330, y, g2, True, next(names), P)
        top = y + 40
        b += dot(265, top, INK)
    X = 360
    b += wire([(265, top), (265, X)])
    b += dot(265, X, INK)
    b += label(258, X - 6, "X = NOT(AB+BC+CA)", 12.5, ORANGE, "end", "600")
    # pull-down: three branches in parallel, each 2 series NMOS
    br = [("A", "B", 140), ("B", "C", 265), ("A", "C", 390)]
    b += wire([(140, X), (390, X)])
    names = iter(["N1", "N2", "N3", "N4", "N5", "N6"])
    for g1, g2, x in br:
        b += wire([(x, X), (x, 400)])
        b += mos(x, 430, g1, False, next(names), N)
        b += wire([(x, 460), (x, 490)])
        b += mos(x, 520, g2, False, next(names), N)
        b += wire([(x, 550), (x, GND)])
        b += dot(x, GND, INK)
    for x in (140, 390):
        b += dot(x, X, INK)
    # inverter
    IX = 600
    b += wire([(390, X), (556, X)], ORANGE)
    b += wire([(480, X), (480, 470), (556, 470)], ORANGE)
    b += dot(480, 360, ORANGE)
    b += wire([(IX, VDD), (IX, 330)])
    b += mos(IX, 360, "", True, "P7", "480n/100n")
    b += wire([(IX, 390), (IX, 440)])
    b += mos(IX, 470, "", False, "N7", "240n/100n")
    b += wire([(IX, 500), (IX, GND)])
    b += wire([(520, VDD), (IX, VDD)])
    b += dot(IX, 415, INK)
    b += wire([(IX, 415), (760, 415)])
    b += label(770, 420, "Y = AB + BC + CA", 15, INK, "start", "700")
    # load cap
    b += wire([(700, 415), (700, 470)])
    b += wire([(684, 470), (716, 470)]); b += wire([(684, 480), (716, 480)])
    b += wire([(700, 480), (700, GND)])
    b += dot(700, 415, INK)
    b += label(722, 480, "C_L = 10 fF", 12, INK2, "start")
    b += label(560, 560, "Inverter", 12, INK2, "middle", italic=True)
    b += label(60, 330, "Pull-up", 12, BLUE, "middle", "600")
    b += label(60, 346, "(PMOS)", 12, BLUE, "middle")
    b += label(60, 580, "Pull-down", 12, INK, "middle", "600")
    b += label(60, 596, "(NMOS)", 12, INK, "middle")
    return svg(930, 650, b)

async def render(name, svgtext, scale=2):
    from playwright.async_api import async_playwright
    p = os.path.join(OUT, name + ".svg")
    open(p, "w").write(svgtext)
    async with async_playwright() as pw:
        br = await pw.chromium.launch()
        pg = await br.new_page(device_scale_factor=scale)
        await pg.set_content(f"<html><body style='margin:0'>{svgtext}</body></html>")
        el = await pg.query_selector("svg")
        await el.screenshot(path=os.path.join(OUT, name + ".png"))
        await br.close()

async def main():
    for n, f in [("fig_block", block_diagram), ("fig_modes", modes_diagram), ("fig_flow", flow_diagram),
                 ("fig_frame", frame_diagram), ("fig_cmos_voter", cmos_voter)]:
        await render(n, f())
        print("wrote", n)

asyncio.run(main())

def frame_col():
    b = ""
    bits = ["idle", "S", "D0", "D1", "D2", "D3", "D4", "D5", "D6", "D7", "P", "Stop", "idle"]
    vals = [1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1]
    x0, w, yh, yl = 30, 46, 30, 80
    pts = []
    for i, v in enumerate(vals):
        y = yh if v else yl
        pts += [(x0 + i * w, y), (x0 + (i + 1) * w, y)]
    d = " ".join(f"{'M' if i == 0 else 'L'}{x},{y}" for i, (x, y) in enumerate(pts))
    for i, t in enumerate(bits):
        b += f'<line x1="{x0 + i*w}" y1="18" x2="{x0 + i*w}" y2="92" stroke="#dcdbd7" stroke-width="1"/>'
        cx = x0 + i * w + w / 2
        b += label(cx, 114, t, 14, MUTED if t == "idle" else INK, weight="600" if t in ("S", "P", "Stop") else "400")
        b += label(cx, 134, str(vals[i]), 13, INK2)
    b += f'<path d="{d}" fill="none" stroke="{BLUE}" stroke-width="3"/>'
    b += label(14, 35, "1", 13, INK2); b += label(14, 85, "0", 13, INK2)
    return svg(640, 145, b)

asyncio.run(render("fig_frame_col", frame_col(), 3))
print("frame_col")
