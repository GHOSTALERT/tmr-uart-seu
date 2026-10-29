"""Plot frame F3 (two upsets at different times) for MODE 1 vs MODE 2 from tb_fi VCDs."""
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib import font_manager as fm
from vcdvcd import VCDVCD

for f in ["/usr/share/fonts/opentype/inter/Inter-Regular.otf", "/usr/share/fonts/opentype/inter/Inter-SemiBold.otf"]:
    fm.fontManager.addfont(f)
plt.rcParams.update({"font.family": "Inter", "font.size": 10})

INK, INK2, MUTED, GRID = "#0b0b0b", "#52514e", "#8a8984", "#e4e3df"
BLUE, ORANGE, RED, AQUA = "#2a78d6", "#eb6834", "#e34948", "#1baf7a"
OUT = "/home/claude/report/figs/"

T0 = 13385000   # frame F3 start pulse (ps)
T1 = T0 + 1900000

def steps(tv, conv=lambda s: s):
    """Return list of (t_ns, value) clipped to window."""
    pts, last = [], None
    for t, val in tv:
        if t <= T0:
            last = val
            continue
        if t > T1:
            break
        if not pts:
            pts.append((0.0, conv(last)))
        pts.append(((t - T0) / 1000.0, conv(val)))
    if not pts:
        pts.append((0.0, conv(last)))
    pts.append(((T1 - T0) / 1000.0, pts[-1][1]))
    return pts

def bit(s):
    return 1 if s == "1" else 0

def draw_bit(ax, y, pts, color, lw=1.8, h=0.62, ls="-"):
    xs, ys = [], []
    for i, (t, v) in enumerate(pts[:-1]):
        xs += [t, pts[i + 1][0]]
        ys += [y + v * h, y + v * h]
    ax.plot(xs, ys, color=color, lw=lw, ls=ls, solid_joinstyle="miter", drawstyle="default")
    # verticals
    for i in range(1, len(pts) - 1):
        if pts[i][1] != pts[i - 1][1]:
            ax.plot([pts[i][0]] * 2, [y, y + h], color=color, lw=lw, ls=ls)

def draw_bus(ax, y, pts, color=INK2, h=0.62):
    for i, (t, v) in enumerate(pts[:-1]):
        t2 = pts[i + 1][0]
        nz = v not in ("0", "000", 0)
        fc = "#fdeee7" if nz else "none"
        ax.add_patch(plt.Polygon([(t, y + h / 2), (t + 3, y), (t2 - 3, y), (t2, y + h / 2), (t2 - 3, y + h), (t + 3, y + h)],
                                 closed=True, fc=fc, ec=ORANGE if nz else color, lw=1.2))
        if t2 - t > 60:
            ax.text((t + t2) / 2, y + h / 2, v if isinstance(v, str) else str(v), ha="center", va="center",
                    fontsize=8.5, color=INK if nz else MUTED)

def expected_tx():
    # byte 0x08: start, D0..D7 (LSB first), parity(even)=1, stop
    byte = 0x08
    bits = [0] + [(byte >> i) & 1 for i in range(8)] + [bin(byte).count("1") & 1, 1]
    t_first = 10.0          # tx_q goes low one clock after start pulse
    pts = [(0.0, 1)]
    for i, b in enumerate(bits):
        pts.append((t_first + i * 160.0, b))
    pts.append((t_first + len(bits) * 160.0, 1))
    pts.append(((T1 - T0) / 1000.0, 1))
    # merge duplicates
    out = [pts[0]]
    for p in pts[1:]:
        if p[1] != out[-1][1] or p is pts[-1]:
            out.append(p)
    return out

def panel(ax, mode):
    v = VCDVCD(f"/home/claude/report/sim/fi_m{mode}.vcd", store_tvs=True)
    seu = v["tb_fi.seu_hit[2:0]"].tv
    ff = steps(v["tb_fi.fault_flag[2:0]"].tv, lambda s: s.zfill(3) if s not in ("x",) else "000")
    lanes = [
        ("tx copy 1", steps(v["tb_fi.tx_copy1"].tv, bit), BLUE),
        ("tx copy 2", steps(v["tb_fi.tx_copy2"].tv, bit), BLUE),
        ("tx copy 3", steps(v["tb_fi.tx_copy3"].tv, bit), BLUE),
        ("tx (voted)", steps(v["tb_fi.tx"].tv, bit), INK),
    ]
    n = len(lanes) + 1
    ys = {}
    for i, (name, pts, c) in enumerate(lanes):
        y = n - i
        ys[name] = y
        draw_bit(ax, y, pts, c, lw=2.0 if name.startswith("tx (") else 1.6)
        ax.text(-30, y + 0.31, name, ha="right", va="center", fontsize=10, color=INK, fontweight=600 if name.startswith("tx (") else 400)
    # expected overlay on voted lane
    draw_bit(ax, ys["tx (voted)"], expected_tx(), MUTED, lw=1.2, ls=(0, (3, 2)))
    ax.text(-30, 0.31 + 1, "fault_flag", ha="right", va="center", fontsize=10, color=INK)
    draw_bus(ax, 1, ff)
    # SEU markers
    k = 0
    for t, val in seu:
        if T0 < t < T1 and val not in ("0", "x"):
            x = (t - T0) / 1000.0
            copy = {"1": 1, "10": 2, "100": 3}[val]
            ax.plot([x, x], [0.8, n + 1.0], color=RED, lw=0.9, ls=(0, (2, 2)))
            ax.text(x, n + 1.12, str(copy), ha="center", va="bottom", fontsize=8.5, color=RED, fontweight=600)
            k += 1
    ax.text(175, n + 1.18, "← SEU in copy 1 (85 ns), then copy 2 (135 ns), same stored bit", ha="left", va="center", fontsize=8.5, color=RED)
    ax.text((T1 - T0) / 1000.0, n + 1.18, "dashed grey = correct tx", ha="right", va="center", fontsize=8.5, color=MUTED)
    # D1 window highlight
    d1a, d1b = 10 + 2 * 160, 10 + 3 * 160
    ax.axvspan(d1a, d1b, color="#f3f3f1", zorder=0)
    # bit labels (below the lanes)
    labels = ["Start", "D0", "D1", "D2", "D3", "D4", "D5", "D6", "D7", "Parity", "Stop"]
    for i, l in enumerate(labels):
        ax.text(10 + i * 160 + 80, 0.5, l, ha="center", va="center", fontsize=8.5,
                color=INK if l == "D1" else MUTED, fontweight=600 if l == "D1" else 400)
    ax.set_xlim(-5, (T1 - T0) / 1000.0)
    ax.set_ylim(0.2, n + 1.4)
    ax.set_yticks([])
    for s in ("left", "right", "top"):
        ax.spines[s].set_visible(False)
    ax.spines["bottom"].set_color(GRID)
    ax.tick_params(axis="x", colors=INK2, labelsize=9, length=3, color=GRID)
    ax.set_xlabel("time from frame start (ns)", fontsize=9.5, color=INK2)
    for x in range(0, 1901, 160):
        ax.axvline(x + 10, color=GRID, lw=0.6, zorder=0)
    return v

fig, axes = plt.subplots(2, 1, figsize=(10.5, 7.6))
fig.subplots_adjust(left=0.12, right=0.985, top=0.93, bottom=0.07, hspace=0.38)
panel(axes[0], 1)
axes[0].set_title("MODE 1 — TMR, output voting:  received 0x0A instead of 0x08  (frame corrupted)",
                  loc="left", fontsize=11.5, color=INK, fontweight=600, pad=14)
panel(axes[1], 2)
axes[1].set_title("MODE 2 — TMR, voted state feedback:  received 0x08  (both upsets scrubbed after one clock)",
                  loc="left", fontsize=11.5, color=INK, fontweight=600, pad=14)
fig.savefig(OUT + "fig_fi_waveform.png", dpi=220)
print("ok")

for mode, title in [(1, "MODE 1 — output voting:  received 0x0A instead of 0x08"),
                    (2, "MODE 2 — voted state feedback:  received 0x08")]:
    fig, ax = plt.subplots(figsize=(10.5, 3.9))
    fig.subplots_adjust(left=0.12, right=0.985, top=0.86, bottom=0.14)
    panel(ax, mode)
    ax.set_title(title, loc="left", fontsize=12, color=INK, fontweight=600, pad=12)
    fig.savefig(OUT + f"fig_fi_m{mode}.png", dpi=200)
print("panels")
