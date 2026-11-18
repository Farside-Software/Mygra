#!/usr/bin/env python3
"""make_jobs.py <shots.json> <jobs-out.json> [only-class]
Lays out each Mygra 3.0 store artboard (headline on top, framed device below) from the shots list
and writes the jobs build.js turns into Affinity artboards. Images must already be in the Desktop
images folder as <class>-<NN-slug>.png (Affinity can only read the Desktop)."""
import json, os, subprocess, sys
HERE = os.path.dirname(os.path.abspath(__file__))
DESK = os.path.expanduser("~/Desktop/Mygra 3.0 Store (Claude)")
FONT = "SFProRounded-Heavy"
INK, ACCENT = "#1E1A2E", "#6E60FF"
CLASSES = {  # canvas and row on the spread
    "iphone":    dict(w=1320, h=2868, row=0),
    "ipad":      dict(w=2064, h=2752, row=1),
    "duo-outer": dict(w=1398, h=2034, row=2),
    "duo-inner": dict(w=2853, h=2007, row=3),
    "watch":     dict(w=416, h=496, row=4),
}
ROW_Y = [0, 3300, 6500, 9000, 11400]
BG = {"duo-inner": "duo-unfolded-background.png"}

def size(path):
    out = subprocess.run(["sips", "-g", "pixelWidth", "-g", "pixelHeight", path], capture_output=True, text=True).stdout
    v = [int(l.split(":")[1]) for l in out.splitlines() if "pixel" in l]
    return v[0], v[1]

def widths(lines):  # advance width of each line at 100 pt, measured with CoreText
    out = subprocess.run([os.path.join(HERE, "measure"), FONT, *lines], capture_output=True, text=True, check=True).stdout
    return [float(x) / 100 for x in out.split()]

def main():
    data = json.load(open(sys.argv[1])); only = sys.argv[3] if len(sys.argv) > 3 else None
    jobs = []
    for cls, items in data["shots"].items():
        if only and cls != only: continue
        C = CLASSES[cls]; W, H = C["w"], C["h"]; portrait = H > W
        # one headline size per class: the widest line of the whole set fills 86% of the width
        widest = max(widths([l for s in items for l in s["caption"]]))
        fs = min(0.86 * W / widest, H * (0.064 if cls == "ipad" else 0.07 if cls == "watch" else 0.052 if portrait else 0.07))
        lead = fs * 1.12
        top = H * (0.06 if portrait else 0.065)
        for i, s in enumerate(items):
            slug = os.path.basename(s["framed"])
            img = f"{cls}-{slug}"
            fw, fh = size(os.path.join(DESK, "images", img))
            lines = [[[s["caption"][k], INK if c == "ink" else ACCENT]] for k, c in enumerate(s.get("captionColors", ["ink", "accent"]))]
            if not portrait:  # one line on landscape canvases
                lines = [[[lines[0][0][0] + " ", INK], [lines[1][0][0], ACCENT]]]
            block = fs * 0.75 + lead * (len(lines) - 1)
            dev_top = top + block + H * (0.045 if portrait else 0.05)
            avail_h = H - dev_top + (fh * 0 if portrait else 0)
            if portrait:  # the whole device shows, with clear space beneath it
                dw = min(W * 0.86, (H - dev_top - H * 0.04) * fw / fh); dh = dw * fh / fw
            else:
                dh = H - dev_top - H * 0.04; dw = dh * fw / fh
            dx = (W - dw) / 2; dy = dev_top
            n = s.get("n", i + 1)
            jobs.append(dict(name=f"{cls} {i + 1:02d}", out=f"{cls}-{i + 1:02d}", x=i * (W + 240), y=ROW_Y[C["row"]], w=W, h=H,
                             bg=BG.get(cls, f"{cls}-background.png"), images=[dict(file=img, x=dx, y=dy, w=dw, h=dh)],
                             lines=lines, font=FONT, fontSize=round(fs, 1), leading=round(lead, 1), top=top, tracking=-0.01))
    json.dump(jobs, open(sys.argv[2], "w"), indent=1)
    print(len(jobs), "jobs")

if __name__ == "__main__":
    main()
