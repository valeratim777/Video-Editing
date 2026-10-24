#!/usr/bin/env python3
"""Checks that the game's stat formulas (GDScript) match the simulator (Python).

Run the Godot tests first (they write parity.json), then:
    python3 tools/check_parity.py [path/to/parity.json]
"""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from economy_sim import compute_stats  # noqa: E402

path = Path(sys.argv[1] if len(sys.argv) > 1 else
            Path.home() / ".local/share/godot/app_userdata/Lanternwood/parity.json")
data = json.loads(path.read_text())
py = compute_stats({k: int(v) for k, v in data["levels"].items()})
bad = [(k, data["stats"][k], py[k]) for k in py if abs(float(data["stats"][k]) - py[k]) > 1e-6 * max(1.0, abs(py[k]))]
for k, g, p in bad:
    print(f"MISMATCH {k}: godot={g} python={p}")
print("PARITY OK" if not bad else f"PARITY FAILED ({len(bad)})")
sys.exit(1 if bad else 0)
