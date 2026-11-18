#!/usr/bin/env python3
"""make_assets.py <jobs-out.json>: the App Store header (3840x1646) and search results (3840x2560) artboards.
Headline on one line at the top of Apple's art safe area, three framed iPhones fanned below it
(Calendar, Dashboard in front, Detail). Framed iPhone images are 1470x3000."""
import json, subprocess, os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
FONT = "SFProRounded-Heavy"; INK, ACCENT = "#1E1A2E", "#6E60FF"
L1, L2 = "Your migraines, ", "at a glance."
def width100(s): return float(subprocess.run([os.path.join(HERE, "measure"), FONT, s], capture_output=True, text=True).stdout) / 100
EMW = width100(L1 + L2)
PH = 3000 / 1470
def job(name, out, y0, W, H, safe, fs, top, cw, ctop, sw, stop, off):
    sx, sy, sW, sH = safe
    cx = W / 2
    imgs = [dict(file="iphone-03-calendar.png", x=cx - off - sw / 2, y=stop, w=sw, h=sw * PH),
            dict(file="iphone-04-migraine-detail.png", x=cx + off - sw / 2, y=stop, w=sw, h=sw * PH),
            dict(file="iphone-01-dashboard.png", x=cx - cw / 2, y=ctop, w=cw, h=cw * PH)]
    return dict(name=name, out=out, x=0, y=y0, w=W, h=H, bg=f"{out}-background.png", images=imgs,
                lines=[[[L1, INK], [L2, ACCENT]]], font=FONT, fontSize=fs, leading=fs * 1.12, top=top, tracking=-0.01)
jobs = [
    # header: safe area 1646x661 at (1097, 493)
    job("header 21x9", "header", 12000, 3840, 1646, (1097, 493, 1646, 661), 1500 / EMW, 520, 560, 700, 470, 800, 560),
    # search results: safe area 2168x1030 at (836, 765)
    job("search 3x2", "search", 14000, 3840, 2560, (836, 765, 2168, 1030), 1900 / EMW, 800, 640, 1010, 540, 1110, 640),
]
json.dump(jobs, open(sys.argv[1], "w"), indent=1); print(len(jobs), "jobs; headline em width", round(EMW, 2))
