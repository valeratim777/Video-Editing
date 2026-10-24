#!/usr/bin/env python3
"""Writes docs/SKILLS.md (the full skill list) from data/skills.json.

Run: python3 tools/gen_skill_docs.py
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
S = json.loads((ROOT / "data/skills.json").read_text())
REG = {r["id"]: r for r in json.loads((ROOT / "data/regions.json").read_text())["regions"]}
CUR = {"amber": "янтарь", "wood": "дерево", "crystal": "кристаллы", "pollen": "пыльца"}


def effect(t, amount):
    fmt = t["fmt"]
    if fmt in ("none", "unlock"):
        return "открывает"
    if fmt in ("pct", "pct_neg"):
        return f"{abs(amount) * 100:g}%"
    if fmt == "chance":
        return f"{amount * 100:g}%"
    if fmt == "sec":
        return f"{amount:g} с"
    if fmt == "px":
        return f"{amount:g} px"
    if fmt == "mult":
        return f"x{amount:g}"
    return f"{amount:g}"


def main():
    nodes_by_branch = {}
    for n in S["nodes"]:
        t = S["types"][n["type"]]
        nodes_by_branch.setdefault(t["branch"], []).append(n)
    out = ["# Навыки", "",
           "Сгенерировано `tools/gen_skill_docs.py` из `data/skills.json`. Править данные, а не этот файл.", "",
           "Иконки: `docs/img/skill_icons.png`. Уровень узла показывается значками поверх иконки "
           "(точки I–III — ступень навыка, рамка — состояние: закрыт / доступен / куплен / максимум).", "",
           f"Всего узлов: **{len(S['nodes'])}**, типов навыков: **{len(S['types'])}**.", ""]
    order = ["root", "paths", "sling", "drill", "wild", "lantern", "econ"]
    titles = {"root": "Центр", **{k: f"{v['name_ru']} ({v['name_en']})" for k, v in S["branches"].items()}}
    for b in order:
        out += [f"## {titles[b]}", "",
                "| Узел | Название (EN / RU) | Иконка | Эффект за уровень | Макс. | Цена 1-го уровня | Рост цены |",
                "|---|---|---|---|---:|---|---:|"]
        for n in nodes_by_branch.get(b, []):
            t = S["types"][n["type"]]
            region = REG.get(n.get("region"), {})
            name_en = t["name_en"].replace("{region}", region.get("name_en", ""))
            name_ru = t["name_ru"].replace("{region}", region.get("name_ru", ""))
            cur, base, growth = n["cost"]
            desc = t["desc_ru"].replace("{v}", effect(t, n["amount"])).replace("{region}", region.get("name_ru", ""))
            out.append(f"| `{n['id']}` | {name_en} / {name_ru} | {t['icon']} | {desc} | {n['max']} | "
                       f"{base:,} {CUR[cur]} | x{growth:g} |".replace(",", " "))
        out.append("")
    (ROOT / "docs/SKILLS.md").write_text("\n".join(out))
    print("Wrote docs/SKILLS.md")


if __name__ == "__main__":
    main()
