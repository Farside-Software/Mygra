#!/usr/bin/env python3
"""Mygra preview score, option B "Soft mallets": kalimba arpeggio, marimba melody, airy pad, low sine bass.
F major with A-minor colour, 86.4 BPM straight (9 bars from 3.0 s land the final chord at 28.0 s). Written from scratch;
all additive synthesis in numpy/scipy. Writes "Mygra score B soft mallets.wav" beside this file."""
import numpy as np, wave, os
from scipy import signal
SR = 48000; DUR = 30.0; N = int(SR * DUR); TWO_PI = 2 * np.pi
OUT = os.path.dirname(os.path.abspath(__file__))
rng = np.random.default_rng(11)
def mtof(m): return 440.0 * 2 ** ((np.asarray(m, float) - 69) / 12)
def T(n): return np.arange(n) / SR
def lp(x, fc, order=2): return signal.sosfilt(signal.butter(order, fc, 'low', fs=SR, output='sos'), x, axis=0)
def hp(x, fc, order=2): return signal.sosfilt(signal.butter(order, fc, 'high', fs=SR, output='sos'), x, axis=0)
def bp(x, a, b, order=2): return signal.sosfilt(signal.butter(order, [a, b], 'band', fs=SR, output='sos'), x, axis=0)
def fade_end(x, ms=60):
    n = min(len(x), int(ms * SR / 1000)); x = x.copy(); x[-n:] *= np.linspace(1, 0, n); return x
def panned(x, p):
    th = (p + 1) * np.pi / 4; return np.stack([x * np.cos(th), x * np.sin(th)], 1)
def add(buf, t0, seg, g=1.0, p=0.0):
    i = int(round(t0 * SR))
    if i >= len(buf) or i < 0: return
    s = panned(seg, p) if seg.ndim == 1 else seg
    n = min(len(s), len(buf) - i); buf[i:i + n] += s[:n] * g
def ir(rt60, seed, dark=2600, pre=0.02):
    r = np.random.default_rng(seed); n = int((rt60 * 1.15 + pre) * SR); t = T(n); out = np.zeros((n, 2))
    for c in range(2):
        a = r.standard_normal(n); w = np.clip(t / (rt60 * 0.7), 0, 1)
        y = (1 - w) * lp(a, dark) + w * lp(a, dark / 3)
        y *= np.exp(-6.9 * t / rt60) * np.clip(t / 0.03, 0, 1)
        d = int(pre * SR); out[:, c] = np.concatenate([np.zeros(d), y[:n - d]])
    return out / np.sqrt((out ** 2).sum(0).mean())
def reverb(x, h): return np.stack([signal.fftconvolve(x[:, c], h[:, c])[:len(x)] for c in range(2)], 1)
def piano(f, vel=0.7, dur=4.0, felt=3200):
    n = int(dur * SR); t = T(n); y = np.zeros(n)
    tau = 3.2 * (220.0 / f) ** 0.35; B = 0.0003
    for k in range(1, 13):
        fk = f * k * np.sqrt(1 + B * k * k)
        if fk > 12000: break
        a = k ** -1.2 * np.exp(-t / (tau / (1 + 0.45 * (k - 1))))
        y += a * 0.5 * (np.sin(TWO_PI * fk * t) + np.sin(TWO_PI * fk * 1.0008 * t + 1.3))
    y *= (1 - np.exp(-t / 0.004))
    nz = bp(rng.standard_normal(n), 600, 2500) * np.exp(-t / 0.018) * 0.06
    y = lp(y + nz, felt) * vel
    return fade_end(y, 120)
def bell(f, vel=0.4, dur=4.0):
    n = int(dur * SR); t = T(n); y = np.zeros(n)
    for r, a, d in [(1, 1, 2.2), (2.76, .5, 1.3), (5.4, .25, .7), (8.93, .12, .4)]:
        y += a * np.sin(TWO_PI * f * r * t) * np.exp(-t / d)
    return fade_end(y * (1 - np.exp(-t / 0.002)) * vel, 150)
def pad(notes, dur, vel=0.25, seed=0, att=1.0, rel=1.4):
    n = int(dur * SR); t = T(n); y = np.zeros(n); r = np.random.default_rng(seed)
    for m in notes:
        f = mtof(m)
        for det in (-7, 0, 6):
            fd = f * 2 ** (det / 1200); ph = r.uniform(0, 6.28)
            for k in range(1, 7):
                lfo = 0.5 + 0.5 * np.sin(TWO_PI * (0.07 + 0.03 * k) * t + ph + k)
                y += (k ** -1.3) * (0.35 + 0.65 * lfo if k > 1 else 1.0) * np.sin(TWO_PI * fd * k * t + ph * k)
    y = lp(y, 2400)
    e = np.minimum(1, t / att) * np.minimum(1, (dur - t) / rel)
    return y * e * vel / max(1, len(notes)) * 2.2
def sine_bass(f, dur, vel=0.5):
    n = int(dur * SR); t = T(n); y = np.sin(TWO_PI * f * t) + 0.18 * np.sin(TWO_PI * 2 * f * t)
    e = np.minimum(1, t / 0.02) * np.exp(-t / (dur * 1.2)) * np.minimum(1, (dur - t) / 0.08).clip(0, 1)
    return y * e * vel
def shaker(vel=0.3):
    n = int(0.12 * SR); t = T(n)
    return bp(rng.standard_normal(n), 4500, 10000) * np.exp(-t / 0.03) * (1 - np.exp(-t / 0.012)) * vel
def save(mix, name):
    pk = np.abs(mix).max(); mix = mix * (10 ** (-3 / 20) / pk)
    fn = int(0.4 * SR); mix[-fn:] *= np.cos(0.5 * np.pi * np.arange(fn) / fn)[:, None]
    pcm = np.round(np.clip(mix, -1, 1) * 32767).astype('<i2')
    with wave.open(os.path.join(OUT, name), 'wb') as w:
        w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR); w.writeframes(pcm.tobytes())
    x = pcm / 32768.0
    print(name, 'dur', len(x) / SR, 'peak dBFS %.2f' % (20 * np.log10(np.abs(x).max())), 'rms dB %.1f' % (20 * np.log10(np.sqrt((x ** 2).mean()))))

# ---- Option B: soft mallets. F major with A-minor colour, 86.4 BPM straight, 9 bars from 3.0 s land the final chord at 28.0 s
def kalimba(f, vel=0.5, dur=1.8):
    n = int(dur * SR); t = T(n)
    y = np.sin(TWO_PI * f * t) * np.exp(-t / 0.9) + 0.22 * np.sin(TWO_PI * 5.4 * f * t) * np.exp(-t / 0.07) + 0.1 * np.sin(TWO_PI * 2 * f * t) * np.exp(-t / 0.3)
    y = y * (1 - np.exp(-t / 0.002)) + bp(rng.standard_normal(n), 900, 3000) * np.exp(-t / 0.01) * 0.04
    return fade_end(lp(y, 5200) * vel, 100)
def marimba(f, vel=0.5, dur=1.6):
    n = int(dur * SR); t = T(n)
    y = np.sin(TWO_PI * f * t) * np.exp(-t / 0.55) + 0.35 * np.sin(TWO_PI * 4 * f * t) * np.exp(-t / 0.12) + 0.1 * np.sin(TWO_PI * 10 * f * t) * np.exp(-t / 0.04)
    return fade_end(lp(y * (1 - np.exp(-t / 0.002)), 4500) * vel, 100)
O = 3.0; END = 28.0; BPM = 60.0 * 36 / (END - O); B = 60.0 / BPM; BAR = 4 * B
def bt(bar, beat=0.0): return O + bar * BAR + beat * B
dry = np.zeros((N, 2)); send = np.zeros((N, 2))
def play(t0, seg, g=1.0, p=0.0, w=0.4):
    add(dry, t0, seg, g, p); add(send, t0, seg, g * w, p)
for i, m in enumerate([65, 67, 69, 72, 74, 77, 79, 81]):
    play(0.3 + 0.31 * i, kalimba(mtof(m), 0.34 + 0.03 * i, 2.2), 1.0, -0.5 + 0.14 * i, 0.55)
play(0.0, pad([53, 60, 65, 69, 72], 3.6, 0.7, 2, att=2.2, rel=0.8), 1.0, 0, 0.5)
play(2.55, bell(mtof(89), 0.2, 3.2), 1.0, 0.3, 0.8)
CH = [([53, 60, 65, 69, 72], 41, [65, 69, 72, 77]), ([52, 57, 60, 64, 69], 45, [64, 69, 72, 76]), ([50, 57, 62, 65, 69], 38, [62, 65, 69, 74]),
      ([46, 58, 62, 65, 69], 46, [62, 65, 70, 74]), ([53, 60, 65, 69, 72], 41, [65, 69, 72, 77]), ([52, 57, 60, 64, 69], 45, [64, 69, 72, 76]),
      ([50, 57, 62, 65, 69], 38, [62, 65, 69, 74]), ([46, 58, 62, 65, 70], 46, [65, 70, 72, 74]), ([48, 55, 60, 64, 67], 48, [64, 67, 72, 76])]
PAT = [0, 2, 1, 3, 2, 1, 3, 2]; ACC = [1.0, .55, .7, .9, .55, .7, .95, .5]
for k, (padn, root, arp) in enumerate(CH):
    last = (k == 8)
    play(bt(k) - 0.3, pad(padn, BAR + (0.0 if last else 0.7), 0.6, k + 4, att=0.8, rel=0.5 if last else 1.2), 1.0, 0, 0.5)
    play(bt(k), sine_bass(mtof(root), 1.5 * B, 0.55), 1.0, 0, 0.1); play(bt(k, 2.5), sine_bass(mtof(root), 1.0 * B, 0.4), 1.0, 0, 0.1)
    for e in range(8):
        v = 0.3 * ACC[e] * (0.8 if k < 2 else 1.0)
        play(bt(k, e * 0.5), kalimba(mtof(arp[PAT[e]]), v, 1.8), 1.0, -0.3 + 0.08 * e, 0.4)
MEL = [(2, 0, 81, 1.5, .4), (2, 2, 79, 2, .38), (3, 0, 77, 2, .4), (3, 2, 74, 2, .36), (4, 0, 81, 1.5, .42), (4, 2, 84, 2, .4),
       (5, 0, 81, 2, .4), (5, 2, 76, 2, .36), (6, 0, 77, 1.5, .42), (6, 2, 74, 2, .38), (7, 0, 74, 1, .4), (7, 1, 77, 1, .4), (7, 2, 81, 2, .42),
       (8, 0, 79, 2, .4), (8, 2, 76, 2, .36)]
for bar, beat, m, ln, v in MEL:
    play(bt(bar, beat), marimba(mtof(m), v, 1.4 + ln * B * 0.5), 1.0, 0.25, 0.45)
for bar, beat, m, v in [(1, 3, 89, .16), (3, 3, 93, .15), (5, 3, 89, .16), (7, 3, 93, .15)]:
    play(bt(bar, beat), bell(mtof(m), v, 3.2), 1.0, 0.4, 0.8)
for m, v in [(41, .5), (53, .45), (60, .4), (65, .4), (69, .38), (72, .36)]:
    play(END + 0.005 * (m % 4), kalimba(mtof(m), v, 2.9), 1.0, (m - 60) / 40, 0.7)
play(END, sine_bass(mtof(41), 2.5, 0.6), 1.0, 0, 0.1)
play(END, marimba(mtof(77), 0.45, 1.6), 1.0, 0.2, 0.7); play(END, bell(mtof(89), 0.3, 2.0), 1.0, 0.1, 0.9)
play(END - 0.15, pad([53, 60, 65, 69, 72, 77], 2.4, 0.9, 9, att=0.35, rel=1.6), 1.0, 0, 0.6)
mix = dry + reverb(send, ir(2.4, 8, 3200)) * 0.75
mix = lp(hp(mix, 35), 9500)
save(mix, 'Mygra score B soft mallets.wav')
