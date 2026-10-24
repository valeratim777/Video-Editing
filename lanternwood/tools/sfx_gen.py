#!/usr/bin/env python3
"""Procedural retro sound effects (placeholders until real sound design).

Run: python3 tools/sfx_gen.py  ->  game/assets/sfx/*.wav (22 kHz, mono, 16-bit)
"""
import math
import random
import struct
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SR = 22050
random.seed(7)


def osc(kind, phase):
    p = phase % 1.0
    if kind == "sine":
        return math.sin(2 * math.pi * p)
    if kind == "square":
        return 1.0 if p < 0.5 else -1.0
    if kind == "tri":
        return 4 * abs(p - 0.5) - 1
    if kind == "noise":
        return random.uniform(-1, 1)
    raise ValueError(kind)


def tone(dur, f0, f1=None, kind="square", vol=0.5, attack=0.005, decay_pow=1.5, vibrato=0.0):
    f1 = f0 if f1 is None else f1
    n = int(dur * SR)
    out, phase, held = [], 0.0, 0.0
    for i in range(n):
        t = i / n
        f = f0 * (f1 / f0) ** t
        if vibrato:
            f *= 1 + vibrato * math.sin(2 * math.pi * 7 * i / SR)
        phase += f / SR
        env = min(1.0, (i / SR) / attack) * (1 - t) ** decay_pow
        if kind == "noise":  # sample-and-hold noise gives a crunchier, pitched noise
            if int(phase) != int(phase - f / SR):
                held = random.uniform(-1, 1)
            s = held
        else:
            s = osc(kind, phase)
        out.append(s * env * vol)
    return out


def mix(*tracks):
    n = max(len(t) for t in tracks)
    return [sum(t[i] for t in tracks if i < len(t)) for i in range(n)]


def seq(*parts, gap=0.0):
    out = []
    for p in parts:
        out += p + [0.0] * int(gap * SR)
    return out


def note(name):
    names = {"C": -9, "D": -7, "E": -5, "F": -4, "G": -2, "A": 0, "B": 2}
    semis = names[name[0]] + (1 if "#" in name else 0) + 12 * (int(name[-1]) - 4)
    return 440.0 * 2 ** (semis / 12)


def arp(notes, step, kind="square", vol=0.35):
    return seq(*[tone(step, note(n), kind=kind, vol=vol, decay_pow=0.8) for n in notes])


def save(name, samples):
    out = ROOT / "game/assets/sfx"
    out.mkdir(parents=True, exist_ok=True)
    peak = max(1e-6, max(abs(s) for s in samples))
    scale = min(1.0, 0.9 / peak)
    with wave.open(str(out / f"{name}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s * scale)) * 32767)) for s in samples))


SOUNDS = {
    "throw": lambda: tone(0.09, 900, 420, "square", 0.35),
    "hit": lambda: mix(tone(0.07, 2500, 600, "noise", 0.35), tone(0.07, 220, 110, "tri", 0.6)),
    "catch": lambda: mix(arp(["C6", "E6", "G6", "C7"], 0.05, "square", 0.25), tone(0.25, 2093, 2093, "sine", 0.15)),
    "rare": lambda: arp(["E6", "G#6", "B6", "E7", "G#7", "B7"], 0.06, "tri", 0.4),
    "break": lambda: mix(tone(0.22, 1800, 200, "noise", 0.5, decay_pow=2), tone(0.18, 160, 60, "square", 0.25)),
    "spark": lambda: tone(0.12, 3000, 2200, "noise", 0.25, decay_pow=0.5),
    "pickup": lambda: tone(0.06, 700, 1400, "square", 0.25),
    "coin": lambda: seq(tone(0.06, note("B5"), kind="tri", vol=0.5, decay_pow=0.5),
                        tone(0.22, note("E6"), kind="tri", vol=0.5, decay_pow=1.2)),
    "buy": lambda: arp(["C5", "E5", "G5", "C6"], 0.07, "square", 0.3),
    "deny": lambda: tone(0.16, 150, 120, "square", 0.3, decay_pow=0.3),
    "low_oil": lambda: seq(tone(0.08, 880, kind="square", vol=0.3, decay_pow=0.2),
                           tone(0.08, 880, kind="square", vol=0.3, decay_pow=0.2), gap=0.06),
    "unlock": lambda: arp(["G4", "C5", "E5", "G5", "C6", "E6"], 0.08, "square", 0.3)
    + tone(0.4, note("G6"), kind="tri", vol=0.4, decay_pow=1.0, vibrato=0.01),
    "faint": lambda: tone(0.6, 400, 90, "tri", 0.5, decay_pow=1.0, vibrato=0.03),
    "tap": lambda: tone(0.03, 1200, 900, "square", 0.2),
    "sell": lambda: seq(tone(0.04, note("A5"), kind="square", vol=0.25), tone(0.08, note("E6"), kind="square", vol=0.25)),
}

if __name__ == "__main__":
    for name, fn in SOUNDS.items():
        save(name, fn())
    print(f"{len(SOUNDS)} sounds -> game/assets/sfx/")
