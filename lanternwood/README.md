# Lanternwood (рабочее название)

Уютная инкрементальная экшен-игра для Android: ёжик с фонарём ловит светящихся существ в ночном лесу, продаёт их на рынке и прокачивает огромное дерево навыков. Движок — Godot 4.7.

## Структура

| Папка | Что внутри |
|---|---|
| `docs/` | Исследование (`RESEARCH.md`), дизайн-документ (`GDD.md`), экономика (`ECONOMY.md`, `ECONOMY_SIM.md`), навыки (`SKILLS.md`), стиль и промпты для ChatGPT (`ART_STYLE.md`), звук и промпты для Suno (`AUDIO.md`) |
| `data/` | Баланс и контент в JSON: `economy.json`, `regions.json`, `skills.json` — единый источник правды для игры и симулятора |
| `tools/` | `economy_sim.py` (симулятор прохождения), `art_gen.py` (пиксельные иконки и спрайты), `sfx_gen.py` (звуки), `gen_skill_docs.py` (справочник навыков) |
| `game/` | Проект Godot |

## Как запустить

1. Установить [Godot 4.7](https://godotengine.org/download) (обычная версия, не .NET).
2. Открыть `game/project.godot`, нажать F5.
3. ПК-управление: WASD/стрелки — движение, J или ЛКМ — рогатка, K или ПКМ — кирка, E — взаимодействие, Tab — дерево навыков. На телефоне — джойстик и кнопки на экране.

Данные из `data/` копируются в игру командой `python3 tools/sync_data.py` (делается автоматически перед коммитом; см. ниже).

## После изменения баланса

```bash
python3 tools/economy_sim.py --report   # проверить темп, обновить docs/ECONOMY_SIM.md
python3 tools/gen_skill_docs.py         # обновить docs/SKILLS.md
python3 tools/art_gen.py                # если менялись иконки или регионы
python3 tools/sync_data.py              # скопировать data/ в game/data/
```
