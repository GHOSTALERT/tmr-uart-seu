"""PPA comparison charts (Genus results) and post-route power breakdown."""
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib import font_manager as fm
from matplotlib.patches import FancyBboxPatch

for f in ["/usr/share/fonts/opentype/inter/Inter-Regular.otf", "/usr/share/fonts/opentype/inter/Inter-SemiBold.otf"]:
    fm.fontManager.addfont(f)
plt.rcParams.update({"font.family": "Inter", "font.size": 10})

INK, INK2, MUTED, GRID, SURF = "#0b0b0b", "#52514e", "#8a8984", "#e4e3df", "#ffffff"
C = ["#2a78d6", "#eb6834", "#1baf7a"]          # MODE 0, 1, 2 (fixed order)
MODES = ["MODE 0\nsimplex", "MODE 1\nTMR out-vote", "MODE 2\nTMR fb-vote"]
OUT = "/home/claude/report/figs/"

data = {
    "Cell area (µm²)": ([1345.77, 3593.76, 3789.04], "{:,.0f}", ["1.00×", "2.67×", "2.82×"]),
    "Total power (µW)": ([154.7, 365.8, 353.6], "{:.1f}", ["1.00×", "2.36×", "2.29×"]),
    "Critical path (ns)": ([2.006, 2.110, 2.304], "{:.2f}", ["≈498 MHz", "≈474 MHz", "≈434 MHz"]),
}

def rounded_bar(ax, x, h, w, color):
    # bar with 4px-ish rounded top, square baseline
    r = min(h * 0.04, w * 0.12)
    ax.add_patch(FancyBboxPatch((x - w / 2, 0), w, h, boxstyle=f"round,pad=0,rounding_size={r}",
                                fc=color, ec=SURF, lw=1.5, mutation_aspect=1))
    ax.add_patch(plt.Rectangle((x - w / 2, 0), w, min(h, r * 2), fc=color, ec="none"))

fig, axes = plt.subplots(1, 3, figsize=(11, 3.9))
fig.subplots_adjust(left=0.06, right=0.99, top=0.83, bottom=0.2, wspace=0.32)
for ax, (title, (vals, fmt, sub)) in zip(axes, data.items()):
    top = max(vals) * 1.22
    for i, v in enumerate(vals):
        ax.bar(i, v, width=0.62, color=C[i], edgecolor=SURF, linewidth=2, zorder=3)
        ax.text(i, v + top * 0.025, fmt.format(v), ha="center", va="bottom", fontsize=10.5, color=INK, fontweight=600)
        ax.text(i, v + top * 0.095, sub[i], ha="center", va="bottom", fontsize=8.5, color=INK2)
    ax.set_ylim(0, top)
    ax.set_xticks(range(3))
    ax.set_xticklabels(MODES, fontsize=9, color=INK2)
    ax.set_title(title, loc="left", fontsize=11.5, color=INK, fontweight=600, pad=10)
    for s in ("top", "right", "left"):
        ax.spines[s].set_visible(False)
    ax.spines["bottom"].set_color(GRID)
    ax.tick_params(axis="y", colors=MUTED, labelsize=8.5, length=0)
    ax.tick_params(axis="x", length=0)
    ax.grid(axis="y", color=GRID, lw=0.7, zorder=0)
fig.suptitle("Synthesis results — Genus 21.14, gpdk090 slow corner, 5 ns clock", x=0.06, ha="left", fontsize=12.5,
             fontweight=600, color=INK, y=0.98)
fig.savefig(OUT + "fig_ppa.png", dpi=220)

# ---- post-route power breakdown (single series -> one hue, no legend)
fig, ax = plt.subplots(figsize=(7.2, 2.6))
fig.subplots_adjust(left=0.24, right=0.86, top=0.8, bottom=0.12)
groups = ["Sequential (flip-flops)", "Combinational logic", "Clock tree"]
vals = [0.2826, 0.1830, 0.06167]
pct = [53.6, 34.7, 11.7]
y = range(len(groups))[::-1]
ax.barh(list(y), vals, height=0.56, color="#2a78d6", edgecolor=SURF, lw=2, zorder=3)
for yy, v, p in zip(y, vals, pct):
    ax.text(v + 0.006, yy, f"{v*1000:.0f} µW  ({p}%)", va="center", fontsize=10, color=INK)
ax.set_yticks(list(y)); ax.set_yticklabels(groups, fontsize=10, color=INK)
ax.set_xlim(0, 0.36)
ax.set_xticks([0, 0.1, 0.2, 0.3]); ax.set_xticklabels(["0", "100", "200", "300 µW"], fontsize=8.5, color=MUTED)
for s in ("top", "right", "left"):
    ax.spines[s].set_visible(False)
ax.spines["bottom"].set_color(GRID)
ax.tick_params(length=0)
ax.grid(axis="x", color=GRID, lw=0.7, zorder=0)
ax.set_title("Post-route power, MODE 2 — total 527 µW", loc="left",
             fontsize=11, fontweight=600, color=INK, pad=10)
fig.savefig(OUT + "fig_power_breakdown.png", dpi=220)

# ---- fault injection outcome (frames correct out of 5)
fig, ax = plt.subplots(figsize=(6.4, 2.7))
fig.subplots_adjust(left=0.3, right=0.95, top=0.8, bottom=0.17)
ok = [2, 4, 5]
names = ["MODE 0  simplex", "MODE 1  TMR out-vote", "MODE 2  TMR fb-vote"]
for i, v in enumerate(ok):
    yy = 2 - i
    ax.barh(yy, v, height=0.56, color=C[i], edgecolor=SURF, lw=2, zorder=3)
    ax.text(v + 0.06, yy, f"{v} / 5", va="center", fontsize=10.5, color=INK, fontweight=600)
ax.set_yticks([2, 1, 0]); ax.set_yticklabels(names, fontsize=10, color=INK)
ax.set_xlim(0, 5.6); ax.set_xticks(range(6)); ax.tick_params(axis="x", length=0, labelsize=8.5, colors=MUTED); ax.tick_params(axis="y", length=0)
for s in ("top", "right", "left"):
    ax.spines[s].set_visible(False)
ax.spines["bottom"].set_color(GRID)
ax.grid(axis="x", color=GRID, lw=0.7, zorder=0)
ax.set_title("Frames received correctly (same 5-frame SEU schedule)", loc="left", fontsize=11,
             fontweight=600, color=INK, pad=10)
fig.savefig(OUT + "fig_fi_outcome.png", dpi=220)
print("ok")
