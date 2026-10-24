#!/usr/bin/env python3
"""Copies data/*.json into the Godot project (game/data/), which can only read files inside itself."""
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
dst = ROOT / "game/data"
dst.mkdir(parents=True, exist_ok=True)
for f in sorted((ROOT / "data").glob("*.json")):
    shutil.copy2(f, dst / f.name)
    print("synced", f.name)
