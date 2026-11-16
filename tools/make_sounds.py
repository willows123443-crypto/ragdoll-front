#!/usr/bin/env python3
"""Makes every sound in the game and packs them into sounds/sounds.pak.

    python3 tools/make_sounds.py [--wav DIR]

The game used to build its sounds in GDScript at start-up: one-pole filtered noise with a sine under
it for a gun, a sawtooth through two resonances for a voice, sine chords for the music, all at 22 kHz
and most of them clipped. Here they are made offline with proper filters, layered and given the
reflections a real sound has out of doors, and the game only loads them.

The pack: 4 bytes "THS1", a 4-byte little-endian length, that many bytes of JSON
{name: [offset, bytes, rate, loop]}, then the 16-bit mono samples one sound after another.
"""
import json, struct, sys, os, wave
import numpy as np
import scipy.signal as sg

SR = 32000          # effects
MR = 22050          # music
rng = np.random.default_rng(1917)
OUT = {}            # name -> (samples float, rate, loop)


# ------------------------------------------------------------------ tools
def noise(n):
    return rng.standard_normal(n)

def lp(x, f, order=2, sr=SR):
    b, a = sg.butter(order, min(0.99, f / (sr / 2)))
    return sg.lfilter(b, a, x)

def hp(x, f, order=2, sr=SR):
    b, a = sg.butter(order, min(0.99, f / (sr / 2)), btype="high")
    return sg.lfilter(b, a, x)

def bp(x, f0, f1, order=2, sr=SR):
    b, a = sg.butter(order, [f0 / (sr / 2), min(0.99, f1 / (sr / 2))], btype="band")
    return sg.lfilter(b, a, x)

def rms(x):
    return float(np.sqrt(np.mean(x * x)) + 1e-12)

def unit(x):
    """scaled to unit RMS over its loud part"""
    e = np.abs(x)
    m = e > e.max() * 0.05
    return x / (np.sqrt(np.mean(x[m] ** 2)) + 1e-12)

def tvec(dur, sr=SR):
    return np.arange(int(dur * sr)) / sr

def soft(x, drive=1.5):
    return np.tanh(x * drive) / np.tanh(drive)

def fade(x, sr=SR, a=0.0, r=0.02):
    x = x.copy()
    na, nr = int(a * sr), int(r * sr)
    if na > 1:
        x[:na] *= np.linspace(0, 1, na)
    if nr > 1:
        x[-nr:] *= np.linspace(1, 0, nr)
    return x

def norm(x, peak=0.9):
    return x * (peak / (np.abs(x).max() + 1e-12))

def room(dur, tau, dark=2500.0, sr=SR, pre=0.012, early=6, seed=0):
    """An impulse response for sound out of doors or in a hall: a few separate reflections, then a
    wash that dies away, the top of it faster than the bottom."""
    r = np.random.default_rng(1000 + seed)
    n = int(dur * sr)
    t = np.arange(n) / sr
    w = r.standard_normal(n)
    lo = lp(w, dark * 0.35, 2, sr) * np.exp(-t / tau) * 1.2
    mid = bp(w, dark * 0.35, dark, 2, sr) * np.exp(-t / (tau * 0.6))
    hi = hp(w, dark, 2, sr) * np.exp(-t / (tau * 0.22)) * 0.5
    ir = (lo + mid + hi) * (1 - np.exp(-t / 0.02))
    for k in range(early):
        d = int((pre + r.uniform(0.01, 0.11)) * sr)
        if d < n:
            ir[d] += r.uniform(0.5, 1.0) * (0.75 ** k) * 6.0 * r.choice([-1, 1])
    ir = np.concatenate([np.zeros(int(pre * sr)), ir])[:n]
    return ir / np.sqrt(np.sum(ir ** 2))

def wet(x, ir, amount, tail=True):
    y = sg.fftconvolve(x, ir)
    if not tail:
        y = y[:len(x)]
    out = np.zeros(len(y))
    out[:len(x)] = x
    return out + y * amount * rms(x) / rms(y[:len(x)] if len(y) > len(x) else y) if amount > 0 else out

def put(name, x, rate=SR, loop=False, peak=0.9):
    x = norm(np.asarray(x, dtype=np.float64), peak)
    if not loop:
        # cut the silence off the end (a reverb tail is mostly nothing), with a short fade; a gun's
        # sooner, since they are played by the dozen and each holds a player while it lasts
        loud = np.nonzero(np.abs(x) > (0.006 if name.startswith("gun_") else 0.0015))[0]
        end = min(len(x), (loud[-1] if len(loud) else 0) + int(0.03 * rate))
        x = x[:end].copy()
        k = min(len(x), int(0.03 * rate))
        x[-k:] *= np.linspace(1, 0, k)
    OUT[name] = (x, rate, loop)


# ------------------------------------------------------------------ guns
IR_FIELD = room(1.6, 0.38, 3800.0, seed=1)
IR_FIELD_LONG = room(2.4, 0.7, 2800.0, seed=2)
IR_SMALL = room(0.5, 0.12, 3500.0, seed=3, pre=0.004, early=4)

def gun(dur, body_tau, band, thump_f, thump_tau, thump=0.28, crack=1.0, tail=0.2, ir=None, top=11000.0, boom=0.2, mech=0.0, sizzle=0.75):
    """A shot: the blast wave off the muzzle (a spike and its suck-back), a burst of gas noise in the
    middle of the range with a hiss on top of it, a low thump under it that is noise too and not a
    tone, and what comes back off the ground and the trees."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    T = 0.0011
    fr = (1 - t / T) * np.exp(-t / T)
    fr[t > 10 * T] = 0
    blast = fr * 2.0 + unit(hp(noise(n), 1800)) * np.exp(-t / 0.0022)
    body = unit(bp(noise(n), band[0], band[1])) * np.exp(-t / body_tau)
    hiss = unit(hp(noise(n), 2800)) * np.exp(-t / (body_tau * 0.45)) * sizzle
    gas = unit(lp(noise(n), 700)) * np.exp(-t / (body_tau * 2.0)) * boom
    th = unit(lp(noise(n), thump_f, 4)) * np.exp(-t / thump_tau) * (1 - np.exp(-t / 0.003))
    x = crack * blast + body + hiss + gas + thump * th
    if mech > 0:
        # the action working: two small clicks a moment after
        for d, f in ((0.045, 3200.0), (0.075, 2300.0)):
            k = int(d * SR)
            m = int(0.02 * SR)
            x[k:k + m] += unit(bp(noise(m), f * 0.7, f * 1.4)) * np.exp(-np.arange(m) / SR / 0.004) * mech
    x = soft(x * 1.1, 2.2)
    x = wet(x, IR_FIELD if ir is None else ir, tail)
    x = hp(lp(x, top, 2), 45, 2)
    return fade(x, r=0.05)

def make_guns():
    put("gun_rifle", gun(0.9, 0.034, (300, 5200), 120, 0.045, mech=0.05))
    put("gun_shot", gun(0.9, 0.036, (280, 5000), 115, 0.045))
    put("gun_carbine", gun(0.8, 0.028, (380, 5600), 140, 0.035, thump=0.25, mech=0.05))
    put("gun_bar", gun(1.0, 0.04, (240, 4600), 100, 0.055, thump=0.45, boom=0.3))
    put("gun_lmg", gun(0.85, 0.038, (230, 4400), 100, 0.05, thump=0.38, boom=0.25))
    put("gun_hmg", gun(1.0, 0.048, (160, 3600), 70, 0.08, thump=0.7, boom=0.45, sizzle=0.4, tail=0.25))
    put("gun_dmr", gun(1.2, 0.044, (240, 4800), 95, 0.06, thump=0.45, tail=0.3, ir=IR_FIELD_LONG))
    put("gun_sniper", gun(1.9, 0.058, (190, 4600), 78, 0.08, thump=0.6, boom=0.35, tail=0.38, ir=IR_FIELD_LONG))
    put("gun_atrifle", gun(2.2, 0.08, (120, 3800), 55, 0.11, thump=0.85, boom=0.5, tail=0.4, ir=IR_FIELD_LONG, sizzle=0.4))
    put("gun_shotgun", gun(1.3, 0.065, (140, 3400), 72, 0.09, thump=0.7, boom=0.5, crack=0.8, tail=0.28, top=8500.0, sizzle=0.35))
    put("gun_smg", gun(0.5, 0.022, (420, 5800), 170, 0.025, thump=0.12, boom=0.12, tail=0.16, mech=0.08))
    put("gun_pistol", gun(0.55, 0.018, (460, 6200), 180, 0.024, thump=0.18, boom=0.12, tail=0.2))
    # silenced: the gas let out slowly and the slide going back
    n = int(0.3 * SR)
    t = np.arange(n) / SR
    x = unit(bp(noise(n), 500, 3500)) * np.exp(-t / 0.02) * (1 - np.exp(-t / 0.002))
    k = int(0.03 * SR)
    m = int(0.03 * SR)
    x[k:k + m] += unit(bp(noise(m), 1800, 4500)) * np.exp(-np.arange(m) / SR / 0.005) * 0.6
    put("gun_silenced", fade(wet(x, IR_SMALL, 0.15), r=0.03), peak=0.5)
    # a long way off: all the top gone, a thump that rolls
    n = int(1.8 * SR)
    t = np.arange(n) / SR
    x = unit(lp(noise(n), 420, 4)) * np.exp(-t / 0.11) * (1 - np.exp(-t / 0.012))
    put("gun_distant", fade(lp(wet(x, IR_FIELD_LONG, 0.7), 900, 2), r=0.2))
    # the crack of a round going past faster than sound: over almost before it starts
    n = int(0.09 * SR)
    t = np.arange(n) / SR
    T = 0.0005
    nw = (1 - t / T) * np.exp(-t / T)
    nw[t > 8 * T] = 0
    x = nw + unit(hp(noise(n), 2500)) * np.exp(-t / 0.0016) * 0.7 + unit(bp(noise(n), 900, 5000)) * np.exp(-t / 0.012) * 0.12
    put("crack", fade(x, r=0.02))
    # what comes back off a wall
    n = int(0.35 * SR)
    t = np.arange(n) / SR
    x = unit(bp(noise(n), 280, 2600)) * np.exp(-t / 0.045) * (1 - np.exp(-t / 0.004))
    put("slap", fade(x, r=0.05))


# ------------------------------------------------------------------ blasts and things in the air
def make_blasts():
    # a shell or a grenade: the crack, the body of the blast, a thump you feel, earth and bits coming
    # down, and a long roll after it
    n = int(3.0 * SR)
    t = np.arange(n) / SR
    crack = unit(hp(noise(n), 1200)) * np.exp(-t / 0.004)
    mid = unit(bp(noise(n), 90, 1700)) * np.exp(-t / 0.16) * (1 - np.exp(-t / 0.002))
    low = unit(lp(noise(n), 95, 4)) * np.exp(-t / 0.3) * (1 - np.exp(-t / 0.01))
    deb = np.zeros(n)
    for _ in range(46):
        k = int(rng.uniform(0.12, 1.5) * SR)
        m = int(rng.uniform(0.01, 0.05) * SR)
        f = rng.uniform(300, 2600)
        deb[k:k + m] += unit(bp(noise(m), f, f * 2.2)) * np.exp(-np.arange(m) / SR / 0.012) * rng.uniform(0.05, 0.22) * np.exp(-k / SR / 0.7)
    upper = unit(bp(noise(n), 600, 4500)) * np.exp(-t / 0.06) * 0.8
    x = soft(1.2 * crack + mid * 1.3 + upper + low * 0.55, 1.6) + deb * 1.5
    x = wet(x, IR_FIELD_LONG, 0.4)
    put("boom", fade(hp(lp(x, 9000), 35), r=0.4))
    # far off: only the bottom of it arrives
    n = int(3.0 * SR)
    t = np.arange(n) / SR
    x = unit(lp(noise(n), 140, 4)) * np.exp(-t / 0.5) * (1 - np.exp(-t / 0.05))
    x += np.roll(x, int(0.23 * SR)) * 0.5
    put("far_boom", fade(lp(wet(x, IR_FIELD_LONG, 0.6), 400, 2), a=0.02, r=0.6))
    # something very heavy hitting the ground
    n = int(1.3 * SR)
    t = np.arange(n) / SR
    x = unit(lp(noise(n), 80, 4)) * np.exp(-t / 0.22) * 0.7 + unit(bp(noise(n), 90, 1200)) * np.exp(-t / 0.08) + unit(bp(noise(n), 800, 3500)) * np.exp(-t / 0.02) * 0.5
    put("slam", fade(hp(wet(soft(x, 1.4), IR_FIELD, 0.3), 35), r=0.2))
    # a rocket leaving: a rush that builds and tears away
    n = int(1.0 * SR)
    t = np.arange(n) / SR
    e = (1 - np.exp(-t / 0.03)) * np.exp(-t / 0.33)
    x = unit(bp(noise(n), 180, 3200)) * e + unit(lp(noise(n), 160, 4)) * e * 0.8
    x *= 1 + 0.25 * lp(noise(n), 40) / 0.05
    put("rocket", fade(wet(x, IR_FIELD, 0.25), r=0.15))

def moving_band(dur, f0, f1, width, shape=1.0, sr=SR):
    """hiss in a narrow band whose pitch moves from f0 to f1: what a thing in the air sounds like,
    where a pure falling tone sounds like a toy"""
    n = int(dur * sr)
    k = np.arange(n) / n
    f = f0 * (f1 / f0) ** (k ** shape)
    ph = 2 * np.pi * np.cumsum(f) / sr
    a = lp(noise(n), width, 2, sr)
    b = lp(noise(n), width, 2, sr)
    return unit(a * np.cos(ph) + b * np.sin(ph))

def make_air():
    # a round going by
    x = moving_band(0.16, 5200, 1700, 500) * np.hanning(int(0.16 * SR))
    put("whizz", x, peak=0.7)
    # a round glancing off: the smack, then a short uneven whine that dies
    n = int(0.42 * SR)
    t = np.arange(n) / SR
    smack = unit(bp(noise(n), 1500, 7000)) * np.exp(-t / 0.004)
    wh = moving_band(0.42, 3900, 1500, 90, 0.7) * np.exp(-t / 0.11) * (1 + 0.5 * np.sin(2 * np.pi * 31 * t + 1.0))
    wh2 = moving_band(0.42, 6100, 2600, 140, 0.7) * np.exp(-t / 0.07) * 0.4
    put("rico", fade(smack * 0.9 + wh * 0.5 + wh2, r=0.05), peak=0.7)
    # a shell coming in: a tearing rush that drops and swells
    n = int(1.25 * SR)
    t = np.arange(n) / SR
    x = moving_band(1.25, 1900, 520, 160, 1.4) + moving_band(1.25, 3600, 900, 400, 1.4) * 0.5 + unit(bp(noise(n), 300, 2500)) * 0.25
    x *= (0.15 + 0.85 * (t / 1.25) ** 2)
    put("whistle", fade(x, a=0.05, r=0.03), peak=0.8)


# ------------------------------------------------------------------ knocks, steps, small things
def modes(n, freqs, taus, gains, sr=SR):
    t = np.arange(n) / sr
    x = np.zeros(n)
    for f, ta, g in zip(freqs, taus, gains):
        x += np.sin(2 * np.pi * f * t + rng.uniform(0, 6.28)) * np.exp(-t / ta) * g
    return x

def click(dur, band, tau, sr=SR):
    n = int(dur * sr)
    t = np.arange(n) / sr
    return unit(bp(noise(n), band[0], band[1])) * np.exp(-t / tau)

def at(x, y, when, gain=1.0, sr=SR):
    k = int(when * sr)
    m = min(len(y), len(x) - k)
    if m > 0:
        x[k:k + m] += y[:m] * gain

def make_small():
    # footfalls: earth, road, boards
    n = int(0.12 * SR)
    t = np.arange(n) / SR
    put("step", fade(unit(lp(noise(n), 700, 2)) * np.exp(-t / 0.022) * (1 - np.exp(-t / 0.003)) + click(0.12, (900, 3500), 0.01) * 0.15), peak=0.6)
    put("step_road", fade(click(0.1, (700, 4200), 0.012) * 0.7 + unit(lp(noise(int(0.1 * SR)), 500)) * np.exp(-tvec(0.1) / 0.018)), peak=0.6)
    n = int(0.2 * SR)
    put("step_floor", fade(modes(n, [140, 215, 330], [0.045, 0.03, 0.02], [1.0, 0.6, 0.3]) * 0.6 + click(0.2, (300, 2500), 0.012)), peak=0.6)
    # into water
    n = int(0.5 * SR)
    t = np.arange(n) / SR
    x = unit(bp(noise(n), 350, 6500)) * np.exp(-t / 0.11) * (1 - np.exp(-t / 0.012))
    x += unit(lp(noise(n), 500)) * np.exp(-t / 0.07) * 0.8
    put("splash", fade(x, r=0.1), peak=0.7)
    # a hit of yours going home: a dull knock, not a bleep
    n = int(0.09 * SR)
    put("hit", fade(modes(n, [620, 940], [0.014, 0.009], [1.0, 0.5]) + click(0.09, (500, 2500), 0.006) * 0.7), peak=0.6)
    # a hammer on a nail through a board
    n = int(0.22 * SR)
    put("hammer", fade(modes(n, [410, 730, 1280, 2150], [0.04, 0.03, 0.02, 0.012], [0.8, 1.0, 0.6, 0.4]) + click(0.22, (1500, 6000), 0.004) * 1.4 + unit(lp(noise(n), 160)) * np.exp(-tvec(0.22) / 0.03) * 0.8))
    # a boot against a door
    n = int(0.5 * SR)
    t = np.arange(n) / SR
    x = unit(lp(noise(n), 220, 4)) * np.exp(-t / 0.05) * 0.6 + click(0.5, (400, 3600), 0.02) * 1.5 + modes(n, [118, 190, 310, 540], [0.07, 0.05, 0.035, 0.02], [0.6, 0.7, 0.5, 0.3]) * 0.6
    put("kick", fade(wet(x, IR_SMALL, 0.25), r=0.08))
    # a door shut
    x = modes(int(0.35 * SR), [110, 172, 290, 470], [0.06, 0.045, 0.03, 0.02], [0.6, 0.6, 0.4, 0.25]) * 0.6 + click(0.35, (300, 3200), 0.012) * 1.6
    put("door", fade(wet(x, IR_SMALL, 0.3), r=0.06), peak=0.8)
    # a plank wrenched off: it creaks, cracks and comes
    n = int(0.42 * SR)
    x = np.zeros(n)
    tt = 0.0
    while tt < 0.3:
        f = rng.uniform(500, 1900)
        at(x, modes(int(0.03 * SR), [f, f * 1.7], [0.006, 0.004], [1.0, 0.5]) + click(0.03, (f, f * 3), 0.003), tt, rng.uniform(0.3, 0.9))
        tt += rng.uniform(0.006, 0.03) * (1.0 - tt)
    at(x, click(0.1, (700, 6000), 0.012) * 2.0 + modes(int(0.1 * SR), [330, 520], [0.03, 0.02], [1.0, 0.6]), 0.3)
    put("tear", fade(x, r=0.03), peak=0.8)
    # a window going in: the smack, then the pieces falling
    n = int(0.9 * SR)
    x = np.zeros(n)
    at(x, click(0.06, (1800, 9000), 0.006) * 3.0, 0.0)
    for _ in range(60):
        f = rng.uniform(2800, 9500)
        m = int(rng.uniform(0.02, 0.12) * SR)
        at(x, modes(m, [f, f * 1.47, f * 2.09], [0.02, 0.012, 0.008], [1.0, 0.5, 0.3]), rng.uniform(0.0, 0.6) ** 1.5 * 0.9 + 0.01, rng.uniform(0.1, 0.5))
    put("glass", fade(x, r=0.1), peak=0.8)
    # a magazine out and in, and the bolt run forward
    n = int(0.8 * SR)
    x = np.zeros(n)
    at(x, click(0.04, (1800, 6500), 0.004) + modes(int(0.04 * SR), [2400, 3900], [0.006, 0.004], [0.6, 0.4]), 0.0, 0.7)
    at(x, click(0.06, (700, 3500), 0.008) + modes(int(0.06 * SR), [900, 1500], [0.012, 0.008], [0.8, 0.4]), 0.3, 0.9)
    at(x, click(0.03, (2000, 7000), 0.003), 0.52, 0.7)
    at(x, click(0.07, (600, 4000), 0.009) + modes(int(0.07 * SR), [1100, 2600], [0.012, 0.006], [0.8, 0.5]), 0.58, 1.0)
    put("reload", x, peak=0.7)
    # the pin out of a grenade and the lever flying off
    n = int(0.32 * SR)
    x = np.zeros(n)
    at(x, modes(int(0.12 * SR), [3350, 5100, 7300], [0.03, 0.02, 0.01], [0.6, 0.4, 0.2]) + click(0.12, (3000, 9000), 0.003), 0.0)
    at(x, click(0.04, (1500, 6000), 0.004) + modes(int(0.04 * SR), [2100, 4300], [0.01, 0.006], [0.6, 0.3]), 0.17, 0.8)
    put("pin", x, peak=0.6)
    # your ears after a blast: not one clean tone, a thin band that wavers and thins out
    n = int(2.6 * SR)
    t = np.arange(n) / SR
    x = (np.sin(2 * np.pi * 3650 * t) + 0.6 * np.sin(2 * np.pi * 3718 * t + 1.0) + 0.35 * np.sin(2 * np.pi * 5480 * t)) * np.exp(-t / 0.8)
    x += moving_band(2.6, 3600, 3600, 60) * 0.5 * np.exp(-t / 0.5)
    put("ring", fade(x, a=0.04, r=0.3), peak=0.35)
    # the net opening: a breath of static and the key click, no tone
    n = int(0.28 * SR)
    t = np.arange(n) / SR
    st = unit(bp(noise(n), 500, 2800)) * (0.55 + 0.45 * (lp(noise(n), 30) > 0)) * np.exp(-np.maximum(0, t - 0.18) / 0.03)
    x = st * 0.5
    at(x, click(0.02, (1200, 4000), 0.003) * 3.0, 0.0)
    at(x, click(0.02, (900, 3000), 0.003) * 2.0, 0.21)
    put("radio", fade(x, r=0.02), peak=0.5)
    # an order marked on the ground: two soft taps on wood
    n = int(0.14 * SR)
    x = np.zeros(n)
    at(x, modes(int(0.06 * SR), [540, 880], [0.012, 0.008], [1.0, 0.5]) + click(0.06, (600, 2400), 0.004) * 0.6, 0.0)
    at(x, modes(int(0.06 * SR), [720, 1170], [0.012, 0.008], [1.0, 0.5]) + click(0.06, (800, 3000), 0.004) * 0.6, 0.055)
    put("tick", x, peak=0.45)


# ------------------------------------------------------------------ voices
VOW = {
    "a": (730, 1090, 2440, 3400), "ae": (660, 1720, 2410, 3400), "e": (530, 1840, 2480, 3500),
    "i": (300, 2250, 2950, 3500), "o": (570, 840, 2410, 3300), "u": (320, 870, 2240, 3300),
    "uh": (640, 1190, 2390, 3350), "er": (490, 1350, 1690, 3300),
}
BW = (90, 110, 150, 200)

def voice(dur, f0s, vowels, breath=0.25, rough=0.2, press=1.0, wob=0.02, sr=SR, low=1.0, ar=(0.02, 0.09)):
    """A throat and a mouth. The throat: a pulse for every opening of the cords, no two quite the same
    length or strength (and when it's forced, every other one weaker: the growl), with breath let
    through as well. The mouth: four resonances that slide from one vowel to the next. f0s: the pitch
    at evenly spaced points through the sound; vowels: likewise."""
    n = int(dur * sr)
    t = np.arange(n) / sr
    k = t / dur
    f0 = np.interp(k, np.linspace(0, 1, len(f0s)), f0s)
    f0 *= 1 + wob * lp(noise(n), 9, 2, sr) / 0.02 * 0.02 + 0.004 * np.sin(2 * np.pi * 5.3 * t)
    ph = np.cumsum(f0) / sr
    cyc = np.floor(ph).astype(int)
    ncyc = cyc.max() + 2
    jit = rng.normal(0, 1, ncyc)
    amp = 1 + 0.25 * rough * jit[cyc]
    amp *= np.where(cyc % 2 == 0, 1.0, 1.0 - 0.55 * rough)        # every other pulse weaker
    p = ph - cyc
    # the cords: open slowly, shut fast (the harder they're pressed the faster the shut and the brighter)
    oq = 0.62 - 0.12 * min(press, 1.5)
    g = np.where(p < oq, 0.5 * (1 - np.cos(np.pi * p / oq)), np.where(p < oq + 0.12 / press, np.cos(np.pi * 0.5 * (p - oq) / (0.12 / press)), 0.0))
    src = np.diff(g * amp, prepend=0.0) * sr / 400.0
    asp = hp(noise(n), 900, 2, sr) * breath * (0.5 + 0.5 * g)
    src = unit(src)
    src = src + np.diff(src, prepend=0.0) * (0.6 + 1.2 * press)        # pressed hard, a voice has an edge
    src = unit(src) + asp * 0.9
    # the mouth, in 4 ms pieces so the vowels can move
    blk = int(0.004 * sr)
    out = np.zeros(n)
    idx = np.linspace(0, 1, len(vowels))
    F = np.array([VOW[v] for v in vowels], dtype=float) * low
    gains = (1.0, 0.9 + 0.5 * press, 0.5 + 0.6 * press, 0.3 + 0.4 * press)
    for j in range(4):
        zi = np.zeros(2)
        y = np.zeros(n)
        for s in range(0, n, blk):
            kk = (s + blk / 2) / n
            fc = np.interp(kk, idx, F[:, j])
            bw = BW[j] * (1.0 + 0.6 * press)
            r = np.exp(-np.pi * bw / sr)
            a = [1.0, -2 * r * np.cos(2 * np.pi * fc / sr), r * r]
            b = [1 - r]
            y[s:s + blk], zi = sg.lfilter(b, a, src[s:s + blk], zi=zi)
        out += y * gains[j]
    e = np.minimum(1, t / ar[0]) * np.minimum(1, (dur - t) / ar[1])
    return unit(out) * e

def make_voices():
    # effort: a short grunt on the breath
    put("grunt0", wet(voice(0.16, [138, 112], ["uh", "o"], breath=0.5, rough=0.35, press=0.8), IR_SMALL, 0.12), peak=0.55)
    put("grunt1", wet(voice(0.2, [150, 118], ["a", "uh"], breath=0.45, rough=0.4, press=0.9), IR_SMALL, 0.12), peak=0.55)
    put("grunt2", wet(voice(0.14, [160, 124], ["o", "u"], breath=0.55, rough=0.3, press=0.7), IR_SMALL, 0.12), peak=0.55)
    # hit and still on his feet
    put("pain0", wet(voice(0.4, [255, 285, 205, 160], ["a", "a", "uh"], breath=0.3, rough=0.45, press=1.2), IR_SMALL, 0.15), peak=0.7)
    put("pain1", wet(voice(0.3, [300, 250, 195], ["ae", "e", "uh"], breath=0.3, rough=0.5, press=1.2), IR_SMALL, 0.15), peak=0.7)
    put("pain2", wet(voice(0.36, [230, 250, 165, 140], ["uh", "o", "u"], breath=0.4, rough=0.5, press=1.0), IR_SMALL, 0.15), peak=0.7)
    # going down
    put("scream0", wet(voice(0.8, [330, 370, 340, 250, 210], ["a", "ae", "a", "uh"], breath=0.25, rough=0.55, press=1.4, wob=0.05), IR_FIELD, 0.2), peak=0.75)
    put("scream1", wet(voice(1.0, [360, 395, 380, 300, 190], ["a", "a", "ae", "uh"], breath=0.25, rough=0.6, press=1.5, wob=0.06), IR_FIELD, 0.2), peak=0.75)
    put("scream2", wet(voice(0.62, [300, 330, 240, 175], ["e", "ae", "a"], breath=0.3, rough=0.6, press=1.3, wob=0.05), IR_FIELD, 0.2), peak=0.75)
    # the dead: low, slow, torn
    for i, (d, f, vs) in enumerate([(1.3, [78, 92, 84, 70], ["o", "uh", "u"]), (1.7, [96, 88, 104, 80], ["uh", "a", "o"]), (2.0, [112, 98, 90, 74], ["a", "o", "u"])]):
        put("groan%d" % i, wet(voice(d, f, vs, breath=0.5, rough=0.95, press=0.7, wob=0.09, low=0.88, ar=(0.12, 0.35)), IR_FIELD, 0.2), peak=0.7)
    put("snarl", wet(voice(0.6, [150, 132, 104], ["a", "ae", "uh"], breath=0.7, rough=1.0, press=1.5, wob=0.1, low=0.9, ar=(0.03, 0.15)), IR_FIELD, 0.15), peak=0.8)
    put("screech", wet(voice(0.75, [290, 345, 300, 240], ["ae", "e", "a"], breath=0.6, rough=1.0, press=1.6, wob=0.12, ar=(0.03, 0.15)), IR_FIELD, 0.2), peak=0.8)
    # a crowd of them, to loop: fourteen voices over one another
    L = 7.0
    n = int(L * SR)
    bed = np.zeros(n)
    for _ in range(14):
        d = rng.uniform(1.2, 2.4)
        f = rng.uniform(68, 125)
        g = voice(d, [f, f * rng.uniform(0.85, 1.15), f * rng.uniform(0.8, 1.0)], [rng.choice(["o", "uh", "a", "u"]) for _ in range(3)], breath=0.5, rough=rng.uniform(0.6, 1.0), press=0.7, wob=0.08, low=0.88, ar=(0.2, 0.5))
        k = rng.integers(0, n)
        idx = (k + np.arange(len(g))) % n
        bed[idx] += g * rng.uniform(0.4, 1.0)
    y = sg.fftconvolve(bed, IR_FIELD_LONG)
    y[:len(y) - n] += y[n:]            # the tail folded round so the loop has no join
    put("horde", lp(bed + y[:n] * 0.6 * rms(bed) / rms(y[:n]), 3500), loop=True, peak=0.8)


# ------------------------------------------------------------------ music
IR_HALL = room(3.2, 1.3, 3200.0, sr=MR, pre=0.025, early=8, seed=9)

def midi(m):
    return 440.0 * 2 ** ((m - 69) / 12.0)

def strings(n, notes, attack=0.35, release=0.5, bright=2600.0, sr=MR):
    """a section of strings: for every note several players a few cents apart, each with his own
    slow vibrato, the bow taking a moment to bite. notes: (midi, start s, length s, loudness)"""
    out = np.zeros(n)
    for m, st, ln, vel in notes:
        k0 = int(st * sr)
        L = int((ln + release) * sr)
        t = np.arange(L) / sr
        e = np.minimum(1, t / attack) * np.where(t < ln, 1.0, np.exp(-(t - ln) / (release * 0.35)))
        note = np.zeros(L)
        f = midi(m)
        nh = int(min(24, (sr * 0.45) / f))
        for cents in (-11, -4, 3, 9):
            fv = f * 2 ** (cents / 1200) * (1 + 0.0035 * np.sin(2 * np.pi * rng.uniform(4.8, 6.0) * t + rng.uniform(0, 6)) * np.minimum(1, t / 0.5))
            ph = 2 * np.pi * np.cumsum(fv) / sr + rng.uniform(0, 6)
            for h in range(1, nh + 1):
                note += np.sin(h * ph) / h * (0.25 if h % 2 == 0 else 0.3) * np.exp(-h * f / 5200.0)
        note += lp(noise(L), 3000, 2, sr) * 0.012          # the hair on the string
        seg = note * e * vel
        m2 = min(L, n - k0)
        if m2 > 0:
            out[k0:k0 + m2] += seg[:m2]
    out = lp(out, bright, 2, sr)
    return out + bp(out, 250, 500, 1, sr) * 0.4

def horn(n, notes, sr=MR, vib=0.004, tone=1.0):
    """a horn: the louder the note the more top it has, the pitch comes up to the note from just
    under, and the waver arrives late"""
    out = np.zeros(n)
    for m, st, ln, vel in notes:
        k0 = int(st * sr)
        L = int((ln + 0.25) * sr)
        t = np.arange(L) / sr
        e = np.minimum(1, t / 0.07) * (0.82 + 0.18 * np.exp(-t / 0.35)) * np.where(t < ln, 1.0, np.exp(-(t - ln) / 0.07))
        f = midi(m) * (1 - 0.012 * np.exp(-t / 0.035)) * (1 + vib * np.sin(2 * np.pi * 5.1 * t) * np.clip((t - 0.35) / 0.4, 0, 1))
        ph = 2 * np.pi * np.cumsum(f) / sr
        note = np.zeros(L)
        nh = int(min(18, (sr * 0.45) / midi(m)))
        for h in range(1, nh + 1):
            note += np.sin(h * ph) * np.exp(-(h - 1) / (1.6 + 3.2 * e * vel * tone)) / (1 + 0.15 * h)
        note += bp(noise(L), 400, 2500, 1, sr) * 0.02 * np.exp(-t / 0.05)    # the breath at the start
        m2 = min(L, n - k0)
        if m2 > 0:
            out[k0:k0 + m2] += (note * e * vel)[:m2]
    return out

def timp(n, hits, sr=MR):
    """a kettledrum: (midi, time, loudness)"""
    out = np.zeros(n)
    for m, st, vel in hits:
        L = int(1.6 * sr)
        t = np.arange(L) / sr
        f = midi(m) * (1 + 0.03 * np.exp(-t / 0.05))
        ph = 2 * np.pi * np.cumsum(f) / sr
        x = np.zeros(L)
        for ratio, ta, g in ((1.0, 0.7, 1.0), (1.5, 0.45, 0.55), (1.98, 0.3, 0.35), (2.44, 0.2, 0.2), (2.89, 0.15, 0.12)):
            x += np.sin(ratio * ph + rng.uniform(0, 6)) * np.exp(-t / ta) * g
        x += lp(noise(L), 900, 2, sr) * np.exp(-t / 0.015) * 2.5
        k0 = int(st * sr)
        m2 = min(L, n - k0)
        if m2 > 0:
            out[k0:k0 + m2] += (x * vel)[:m2]
    return out

def bass_drum(n, hits, sr=MR):
    out = np.zeros(n)
    for st, vel in hits:
        L = int(1.2 * sr)
        t = np.arange(L) / sr
        x = np.sin(2 * np.pi * 47 * t * (1 + 0.25 * np.exp(-t / 0.03))) * np.exp(-t / 0.3) + lp(noise(L), 110, 4, sr) * np.exp(-t / 0.2) * 14 + lp(noise(L), 600, 2, sr) * np.exp(-t / 0.012) * 2
        k0 = int(st * sr)
        m2 = min(L, n - k0)
        if m2 > 0:
            out[k0:k0 + m2] += (x * vel)[:m2]
    return out

def snare(n, hits, sr=MR):
    out = np.zeros(n)
    for st, vel in hits:
        L = int(0.3 * sr)
        t = np.arange(L) / sr
        x = bp(noise(L), 900, 7000, 2, sr) * np.exp(-t / 0.07) * 1.2 + bp(noise(L), 180, 900, 2, sr) * np.exp(-t / 0.03) * 2.0
        x += (np.sin(2 * np.pi * 186 * t) + 0.5 * np.sin(2 * np.pi * 331 * t)) * np.exp(-t / 0.04) * 0.5
        k0 = int(st * sr)
        m2 = min(L, n - k0)
        if m2 > 0:
            out[k0:k0 + m2] += (x * vel * (1 - np.exp(-t / 0.001)))[:m2]
    return out

def roll(start, end, v0, v1, rate=22.0):
    """a drum roll as a list of taps getting louder or softer"""
    hits = []
    tt = start
    while tt < end:
        k = (tt - start) / max(1e-6, end - start)
        hits.append((tt + rng.uniform(-0.004, 0.004), (v0 + (v1 - v0) * k) * rng.uniform(0.8, 1.1)))
        tt += 1.0 / rate
    return hits

def hall(x, amount, n, loop=True):
    """reverb; for a loop the tail that runs past the end is folded back onto the start"""
    y = sg.fftconvolve(x, IR_HALL)
    if loop:
        over = y[n:]
        y = y[:n].copy()
        m = min(len(over), n)
        y[:m] += over[:m]
        base = x[:n]
    else:
        base = np.concatenate([x, np.zeros(len(y) - len(x))])
    return base + y[:len(base)] * amount * rms(x) / rms(y)

def make_menu_music():
    # The title: a slow march in D minor, twelve bars at 66 to the minute. Low strings hold the
    # chords; a muffled drum on the first beat of the bar and a side drum under it, far off; a horn
    # enters in the third bar with a plain tune, a second joins a third below for the last four bars.
    bpm = 66.0
    beat = 60.0 / bpm
    bars = 12
    n = int(bars * 4 * beat * MR)
    B = lambda bar, b=0.0: (bar * 4 + b) * beat
    # D2 38, F2 41, G2 43, A2 45, Bb1 34, C#3 49 ...
    chords = [(38, 45, 50, 53), (38, 45, 50, 53), (34, 46, 50, 53), (41, 48, 53, 57), (43, 50, 55, 58), (38, 45, 50, 57),
              (33, 45, 49, 52), (33, 45, 52, 55), (38, 45, 50, 53), (34, 46, 53, 58), (43, 50, 55, 58), (38, 45, 50, 53)]
    sn = []
    for bar, ch in enumerate(chords):
        if bar == 10:
            for m in (43, 50, 55, 58):
                sn.append((m, B(bar), 2 * beat, 0.5))
            for m in (33, 45, 49, 52):
                sn.append((m, B(bar, 2), 2 * beat, 0.5))
        else:
            for j, m in enumerate(ch):
                sn.append((m, B(bar), 4 * beat, 0.55 if j == 0 else 0.42))
    st = strings(n + MR, sn, attack=0.5, release=0.9)[:n + MR]
    tune = [(2, 0, 62, 2), (2, 2, 65, 1), (2, 3, 70, 1), (3, 0, 69, 3), (3, 3, 65, 1), (4, 0, 67, 2), (4, 2, 70, 1), (4, 3, 74, 1),
            (5, 0, 69, 4), (6, 0, 69, 1.5), (6, 1.5, 67, 0.5), (6, 2, 64, 1), (6, 3, 61, 1), (7, 0, 64, 4),
            (8, 0, 62, 1), (8, 1, 65, 1), (8, 2, 69, 2), (9, 0, 70, 1.5), (9, 1.5, 69, 0.5), (9, 2, 67, 1), (9, 3, 65, 1),
            (10, 0, 67, 2), (10, 2, 64, 2), (11, 0, 62, 4)]
    hn = horn(n + MR, [(m, B(bar, b), ln * beat * 0.96, 0.8) for bar, b, m, ln in tune])
    second = [(8, 0, 57, 2), (8, 2, 65, 2), (9, 0, 65, 2), (9, 2, 62, 2), (10, 0, 62, 2), (10, 2, 61, 2), (11, 0, 57, 4)]
    hn += horn(n + MR, [(m, B(bar, b), ln * beat * 0.96, 0.5) for bar, b, m, ln in second]) * 0.7
    bd = bass_drum(n + MR, [(B(bar), 0.9 if bar % 2 == 0 else 0.7) for bar in range(bars)] + [(B(7, 2), 0.5), (B(11, 2), 0.5)])
    sh = []
    for bar in range(2, bars):
        for b, v in ((0, 0.5), (1, 0.3), (2, 0.42), (2.5, 0.22), (3, 0.3), (3.5, 0.22), (3.75, 0.22)):
            sh.append((B(bar, b) + rng.uniform(-0.006, 0.006), v))
    sh += roll(B(1, 2), B(2), 0.05, 0.4) + roll(B(7, 2), B(8), 0.1, 0.5) + roll(B(11, 3), B(12) - 0.02, 0.3, 0.08)
    sd = snare(n + MR, sh)
    tp = timp(n + MR, [(38, B(0), 0.6), (38, B(4), 0.5), (33, B(6), 0.6), (38, B(8), 0.8), (33, B(10, 2), 0.6), (38, B(11), 0.7)] + [(33, x, v * 0.5) for x, v in roll(B(7, 2), B(8), 0.2, 0.9, 14.0)])
    mix = unit(st) * 0.5 + unit(hn) * 0.42 + unit(bd) * 0.16 + unit(sd) * 0.05 + unit(tp) * 0.13
    y = hall(mix, 0.55, n)
    put("menu", lp(y, 7000, 2, MR), MR, True, peak=0.85)

def make_battle_music():
    # Three layers that play together, eight bars at 96 to the minute (the same length and bar lines
    # as before, so the game brings them in and out as it always did): low strings and a low horn
    # holding the ground; kettledrums and a side drum marching; strings sawing short notes over it.
    bpm = 96.0
    beat = 60.0 / bpm
    bars = 8
    n = int(bars * 4 * beat * MR)
    B = lambda bar, b=0.0: (bar * 4 + b) * beat
    roots = [38, 38, 41, 36, 38, 38, 34, 36]            # D D F C D D Bb C
    dn = []
    for bar, r in enumerate(roots):
        dn += [(r, B(bar), 4 * beat, 0.6), (r + 7, B(bar), 4 * beat, 0.4), (r + 12, B(bar), 4 * beat, 0.3)]
    drone = unit(strings(n + MR, dn, attack=0.6, release=0.9, bright=1500.0)) + unit(horn(n + MR, [(r, B(bar), 4 * beat * 0.98, 0.5) for bar, r in enumerate(roots)], vib=0.0, tone=0.5)) * 0.5
    drone *= 0.8 + 0.2 * np.sin(2 * np.pi * np.arange(len(drone)) / MR / (8 * beat))
    th, sh, bh = [], [], []
    for bar, r in enumerate(roots):
        th += [(r, B(bar), 0.9), (r + 7, B(bar, 2), 0.7), (r, B(bar, 3.5), 0.4)]
        bh += [(B(bar), 0.7)]
        for b, v in ((1, 0.6), (1.75, 0.25), (3, 0.6), (3.5, 0.3)):
            sh.append((B(bar, b) + rng.uniform(-0.004, 0.004), v))
        if bar % 4 == 3:
            sh += roll(B(bar, 2), B(bar + 1) - 0.02, 0.2, 0.75, 16.0)
            th += [(r + 7, B(bar, 3), 0.6), (r + 5, B(bar, 3.5), 0.7)]
    drums = hp(unit(timp(n + MR, th)) * 0.6 + unit(snare(n + MR, sh)) * 0.6 + unit(bass_drum(n + MR, bh)) * 0.25, 40, 2, MR)
    pat = [0, 0, 7, 0, 3, 0, 7, 10]
    sn = []
    for e in range(bars * 8):
        r = roots[e // 8] + 12 + pat[e % 8]
        v = 0.9 if e % 4 == 0 else 0.6
        sn += [(r, e * beat * 0.5, beat * 0.5 * 0.55, v), (r + 12, e * beat * 0.5, beat * 0.5 * 0.5, v * 0.5)]
    stg = strings(n + MR, sn, attack=0.018, release=0.12, bright=3600.0)
    layers = []
    for name, x, pk, rv in (("music_drone", drone, 0.38, 0.5), ("music_drums", drums, 0.9, 0.3), ("music_strings", stg, 0.4, 0.4)):
        y = lp(hall(x, rv, n), 7000, 2, MR)
        put(name, y, MR, True, peak=pk)
        layers.append(OUT[name][0])
    # the browser plays one finished mix at a time: calm, tense, hot
    for i, wts in enumerate([[0.32, 0.0, 0.0], [0.5, 0.34, 0.0], [0.6, 0.68, 0.55]]):
        m = sum(l * w for l, w in zip(layers, wts))
        OUT["music_mix%d" % i] = (np.clip(m, -1, 1), MR, True)

def make_stings():
    beat = 0.5
    # won: two horns rising a fourth and a third apart, a drum under the last note
    n = int(4.2 * MR)
    seq = [(62, 0.0, 0.3), (66, 0.32, 0.3), (69, 0.64, 0.3), (74, 0.96, 1.9)]
    hn = horn(n, [(m, st, ln, 0.9) for m, st, ln in seq]) + horn(n, [(m - 5 if m != 74 else 69, st, ln, 0.7) for m, st, ln in seq]) * 0.7
    x = unit(hn) * 0.6 + unit(timp(n, [(38, 0.96, 1.0), (38, 0.0, 0.5)])) * 0.25 + unit(strings(n, [(50, 0.96, 1.8, 0.5), (57, 0.96, 1.8, 0.5), (62, 0.96, 1.8, 0.4)], attack=0.2)) * 0.3
    put("win", fade(hall(x, 0.45, n, False), sr=MR, r=0.5), MR, False, peak=0.85)
    # lost: one horn coming down, strings dark under it
    n = int(5.0 * MR)
    seq = [(69, 0.0, 0.6), (67, 0.62, 0.6), (65, 1.24, 0.6), (62, 1.86, 2.0)]
    x = unit(horn(n, [(m, st, ln, 0.7) for m, st, ln in seq], tone=0.7)) * 0.5 + unit(strings(n, [(38, 0.0, 3.9, 0.6), (45, 0.0, 3.9, 0.4), (53, 1.86, 2.0, 0.4)], attack=0.5, bright=1400)) * 0.45 + unit(bass_drum(n, [(1.86, 1.0)])) * 0.2
    put("lose", fade(hall(x, 0.5, n, False), sr=MR, r=0.6), MR, False, peak=0.85)


# ------------------------------------------------------------------ out
def main():
    make_guns()
    make_blasts()
    make_air()
    make_small()
    make_voices()
    make_menu_music()
    make_battle_music()
    make_stings()
    root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
    os.makedirs(os.path.join(root, "sounds"), exist_ok=True)
    index = {}
    blob = bytearray()
    for name, (x, rate, loop) in OUT.items():
        pcm = (np.clip(x, -1, 1) * 32000).astype("<i2").tobytes()
        index[name] = [len(blob), len(pcm), rate, 1 if loop else 0]
        blob += pcm
    js = json.dumps(index).encode()
    with open(os.path.join(root, "sounds", "sounds.pak"), "wb") as f:
        f.write(b"THS1" + struct.pack("<I", len(js)) + js + bytes(blob))
    print("%d sounds, %.1f MB" % (len(index), (len(blob) + len(js) + 8) / 1e6))
    if "--wav" in sys.argv:
        d = sys.argv[sys.argv.index("--wav") + 1]
        os.makedirs(d, exist_ok=True)
        for name, (x, rate, loop) in OUT.items():
            w = wave.open(os.path.join(d, name + ".wav"), "wb")
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(rate)
            w.writeframes((np.clip(x, -1, 1) * 32000).astype("<i2").tobytes())
            w.close()

if __name__ == "__main__":
    main()
