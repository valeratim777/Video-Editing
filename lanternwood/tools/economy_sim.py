#!/usr/bin/env python3
"""Economy simulator for Lanternwood.

Plays the whole game with a simple "sensible player" policy, using the same
data files and formulas as the game (data/*.json), and reports how long each
milestone takes. Use it after every balance change:

    python3 tools/economy_sim.py            # prints a summary
    python3 tools/economy_sim.py --report   # also writes docs/ECONOMY_SIM.md
"""
import json
import math
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ECON = json.loads((ROOT / "data/economy.json").read_text())
REGIONS = json.loads((ROOT / "data/regions.json").read_text())
SKILLS = json.loads((ROOT / "data/skills.json").read_text())

BASE = ECON["base_stats"]
FLOOR = ECON["stat_floor"]
RAR = ECON["rarity"]
SCALE = ECON["region_scaling"]
PACE = ECON["pacing"]
NODES = {n["id"]: n for n in SKILLS["nodes"]}
TYPES = SKILLS["types"]
REG = REGIONS["regions"]
ACT_RES = [a["resource"] for a in REGIONS["acts"]]


def node_cost(node, level):
    cur, base, growth = node["cost"]
    return cur, round(base * growth ** level)


def compute_stats(levels):
    add = {k: 0.0 for k in BASE}
    pct = {k: 0.0 for k in BASE}
    for nid, lvl in levels.items():
        if lvl <= 0:
            continue
        node = NODES[nid]
        t = TYPES[node["type"]]
        stat = t.get("stat")
        if not stat:
            continue
        (add if t["mode"] == "add" else pct)[stat] += node["amount"] * lvl
    out = {}
    for k, b in BASE.items():
        v = (b + add[k]) * max(0.0, 1.0 + pct[k])
        if k in FLOOR:
            v = max(v, FLOOR[k] * b)
        out[k] = v
    return out


def region_numbers(r):
    s = SCALE
    return {
        "value": s["creature_value"]["base"] * s["creature_value"]["growth"] ** r,
        "hp": s["creature_hp"]["base"] * s["creature_hp"]["growth"] ** r,
        "block_hp": s["block_hp"]["base"] * s["block_hp"]["growth"] ** r,
        "res_per_block": s["resource_per_block"][r % 3],
        "resource": ACT_RES[REG[r]["act"]],
    }


def simulate_run(st, r, mining_share):
    """Expected haul of one expedition into region r."""
    rn = region_numbers(r)
    reg = REG[r]
    run_time = st["oil_max"] / (st["oil_drain"] * reg["oil_drain_mult"])
    if st["camp_refill"] >= 1:
        run_time *= 1.3
    move = st["move_speed"] / BASE["move_speed"]

    # Catching: damage per second with ammo/reload cycle, crits, extra jars, helpers.
    cycle = st["sling_ammo"] / st["sling_fire_rate"] + st["sling_reload_time"]
    shots_per_s = st["sling_ammo"] / cycle
    accuracy = min(0.95, 0.6 + 0.15 * st["sling_proj_speed"] / BASE["sling_proj_speed"])
    if st["sling_homing"] >= 1:
        accuracy = 0.97
    crit = 1 + st["sling_crit_chance"] * (st["sling_crit_mult"] - 1)
    dps = st["sling_damage"] * shots_per_s * accuracy * crit * (1 + st["sling_multi_chance"])
    dps += st["helper_moths"] * 0.5 * st["sling_damage"] * st["helper_damage"]
    t_catch = rn["hp"] / dps + PACE["catch_overhead_seconds"] / move

    capacity = int(st["inv_slots"]) * int(st["slot_capacity"])
    caught = 0.0
    for _ in range(2):  # oil_per_catch extends the run; two passes are enough
        t = run_time + caught * st["oil_per_catch"]
        available = st["creature_cap"] + st["spawn_rate"] * t
        caught = min(capacity, available, (1 - mining_share) * t / t_catch)
    t = run_time + caught * st["oil_per_catch"]

    rarity_ev = (1 + st["silver_chance"] * (RAR["silver"]["mult"] - 1)
                 + st["gold_chance"] * (RAR["gold"]["mult"] - 1)
                 + st["rainbow_chance"] * (RAR["rainbow"]["mult"] - 1))
    value_each = rn["value"] * st["value_mult"] * rarity_ev * (1 + st["double_catch"])

    # Mining.
    mdps = st["drill_dps"] * (1 + 0.5 * st["drill_chain"]) * (1 + 1.5 * st["drill_burst_chance"])
    mdps += st["helper_beetles"] * 0.5 * st["drill_dps"] * st["helper_damage"]
    t_block = rn["block_hp"] / mdps + PACE["mine_overhead_seconds"] / move
    blocks_avail = st["block_cap"] + st["block_spawn_rate"] * t
    blocks = min(blocks_avail, mining_share * t / t_block)
    res = blocks * rn["res_per_block"] * st["resource_mult"]
    return {"time": t, "caught": caught, "value_each": value_each, "resource": rn["resource"], "res": res}


class Game:
    def __init__(self):
        self.levels = {nid: 0 for nid in NODES}
        self.levels["first_light"] = 1
        self.wallet = {c: 0.0 for c in ECON["currencies"]}
        self.queue = []  # creature values waiting at the market
        self.clock = 0.0
        self.runs = 0
        self.milestones = []
        self.curve = []
        self.unlocked = {0}

    def available_nodes(self):
        for nid, node in NODES.items():
            lvl = self.levels[nid]
            if lvl >= node["max"]:
                continue
            p = node["parent"]
            if p is not None and self.levels[p] <= 0:
                continue
            yield nid, node, lvl

    def cheapest_need(self):
        need = {}
        for nid, node, lvl in self.available_nodes():
            cur, cost = node_cost(node, lvl)
            if cost > 0:
                need[cur] = min(need.get(cur, math.inf), cost)
        return need

    def pick_region(self, st):
        need = self.cheapest_need()
        best, best_score, best_run = 0, -1, None
        for r in sorted(self.unlocked):
            res = region_numbers(r)["resource"]
            share = PACE["mining_share_when_needed"] if res in need else 0.1
            run = simulate_run(st, r, share)
            amber = run["caught"] * run["value_each"]
            score = amber / need.get("amber", math.inf) + run["res"] / need.get(res, math.inf)
            score /= run["time"] + PACE["village_seconds"] + PACE["transition_seconds"]
            if score > best_score:
                best, best_score, best_run = r, score, run
        return best, best_run

    def sell(self, seconds, st):
        per_s = st["market_slots"] / st["market_sell_time"]
        n = min(len(self.queue), int(per_s * seconds))
        bonus = 1 + st["market_extra_chance"]
        self.wallet["amber"] += sum(self.queue[:n]) * bonus
        del self.queue[:n]

    def buy_all(self):
        bought = True
        while bought:
            bought = False
            income = {c: 1.0 for c in self.wallet}
            options = []
            for nid, node, lvl in self.available_nodes():
                cur, cost = node_cost(node, lvl)
                if self.wallet[cur] >= cost:
                    prio = 0 if node["type"].startswith("path") else 1
                    options.append((prio, cost / income[cur], nid, cur, cost))
            if options:
                options.sort()
                _, _, nid, cur, cost = options[0]
                self.wallet[cur] -= cost
                self.levels[nid] += 1
                bought = True
                node = NODES[nid]
                if node["type"] == "path":
                    r = next(i for i, reg in enumerate(REG) if reg["id"] == node["region"])
                    self.unlocked.add(r)
                    self.milestones.append((self.clock, self.runs, f"Unlock {REG[r]['name_en']}"))
                elif node["type"] == "path_final":
                    self.milestones.append((self.clock, self.runs, "FINALE: World Tree"))
                    return True
        return False

    def play(self, max_runs=6000):
        next_sample = 0.0
        while self.runs < max_runs:
            st = compute_stats(self.levels)
            r, run = self.pick_region(st)
            self.runs += 1
            self.clock += run["time"]
            self.sell(run["time"] * st["night_shift"], st)
            n = int(round(run["caught"]))
            self.queue.extend([run["value_each"]] * n)
            self.wallet[run["resource"]] += run["res"]
            self.clock += PACE["village_seconds"] + PACE["transition_seconds"]
            self.sell(PACE["village_seconds"], st)
            if self.clock >= next_sample:
                self.curve.append((self.clock, self.runs, REG[r]["name_en"], n * run["value_each"], run["time"]))
                next_sample += 1800
            if self.buy_all():
                return True
        return False


def fmt_num(x):
    for unit, div in (("B", 1e9), ("M", 1e6), ("K", 1e3)):
        if abs(x) >= div:
            return f"{x / div:.1f}{unit}"
    return f"{x:.0f}"


def main():
    g = Game()
    done = g.play()
    lines = ["| Minute | Runs | Milestone |", "|---:|---:|---|"]
    for t, runs, name in g.milestones:
        lines.append(f"| {t / 60:.0f} | {runs} | {name} |")
    curve = ["| Minute | Runs | Best region | Amber per run | Run length, s |", "|---:|---:|---|---:|---:|"]
    for t, runs, reg, amber, rt in g.curve:
        curve.append(f"| {t / 60:.0f} | {runs} | {reg} | {fmt_num(amber)} | {rt:.0f} |")
    unbought = [nid for nid, lvl in g.levels.items() if lvl == 0]
    partial = [f"{nid} {lvl}/{NODES[nid]['max']}" for nid, lvl in g.levels.items() if 0 < lvl < NODES[nid]["max"]]
    summary = "\n".join(lines)
    print(summary)
    print(f"\nFinished: {done}; total {g.clock / 3600:.1f} h, {g.runs} runs")
    print("Never bought:", ", ".join(unbought) or "-")
    print("Partly bought at the end:", ", ".join(partial) or "-")
    if "--report" in sys.argv:
        targets = PACE["targets_minutes"]
        report = [
            "# Economy simulation report",
            "",
            "Generated by `tools/economy_sim.py --report` from `data/*.json`. Do not edit by hand.",
            "",
            f"**Result:** {'finale reached' if done else 'finale NOT reached'} after "
            f"**{g.clock / 3600:.1f} h** of play ({g.runs} expeditions).",
            "",
            f"Targets: second region at ~{targets['region_2']} min, Act II at ~{targets['act_2']} min, "
            f"Act III at ~{targets['act_3']} min, finale at ~{targets['finale']} min.",
            "",
            "## Milestones",
            "",
            summary,
            "",
            "## Income curve (sampled every 30 minutes)",
            "",
            "\n".join(curve),
            "",
            "## Unused content",
            "",
            "Never bought: " + (", ".join(unbought) or "none"),
            "",
            "Partly bought at the end: " + (", ".join(partial) or "none"),
            "",
        ]
        (ROOT / "docs/ECONOMY_SIM.md").write_text("\n".join(report))
        print("Wrote docs/ECONOMY_SIM.md")


if __name__ == "__main__":
    main()
