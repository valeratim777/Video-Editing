# Звук и музыка

## Направление

Уютный «ламповый» звук: мягкий чиптюн + тёплые синты, музыкальная шкатулка, калимба, лёгкий lo-fi бит. Громких резких звуков нет; каждое действие подтверждается коротким мелодичным звуком.

## Приёмы, которые делают звук «вкусным»

- **Поимка — арпеджио, высота растёт с серией** (каждое следующее существо подряд звучит на полтона выше, серия сбрасывается через 2 с). Уже в коде: `Audio.play("catch", pitch)`.
- **Редкое существо** — отдельный звонкий перелив + вспышка.
- **Монеты на рынке** — тихий «дзынь» на каждую продажу, чуть разная высота (±5 %), чтобы не надоедало.
- **Мало масла** — двойной писк + музыка уходит под фильтр (приглушается), фонарь мигает.
- **Покупка навыка** — восходящее арпеджио; максимальный уровень — короткие фанфары.
- Случайная высота ±3–8 % у частых звуков (бросок, удар, подбор).

## Заглушки

`tools/sfx_gen.py` синтезирует 15 эффектов в `game/assets/sfx/`: throw, hit, catch, rare, break, spark, pickup, coin, sell, buy, deny, low_oil, unlock, faint, tap. Потом заменить на настоящие (например, sfxr/ChipTone или звукорежиссёр).

## Музыка в игре

Сгенерировано через Suno (инструментал, ~3 мин, зацикливается в игре):
- `game/assets/music/village.mp3` — «Lantern Moss Village» (деревня)
- `game/assets/music/expedition.mp3` — «Moonlit Moss Path» (походы)
- Вторые варианты для сравнения — в `audio_alt/` (замените файл в `game/assets/music/`, если понравится больше).

Когда кончается свет, музыка уходит под фильтр (приглушается), в деревне — снова чистая.

## Музыка: промпты для Suno

**Деревня (основная тема)**
```
cozy night village theme for a pixel-art game, warm music box and kalimba melody over soft chiptune arpeggios, gentle lo-fi beat, crickets ambience, 85 bpm, loopable, instrumental, calm and nostalgic
```
**Поход, акт I**
```
gentle adventurous chiptune for exploring a glowing night forest, plucky square-wave lead, soft pads, light percussion, curious and cozy mood, 100 bpm, loopable, instrumental
```
**Поход, акт II**
```
dreamy underwater and mushroom forest chiptune, bubbly arpeggios, warm bass, airy pads, slightly mysterious but cozy, 105 bpm, loopable, instrumental
```
**Поход, акт III**
```
uplifting chiptune with autumn and winter mood, sparkling bells, driving soft beat, hopeful melody building energy, 115 bpm, loopable, instrumental
```
**Финал**
```
emotional ending theme for a cozy pixel game, music box and soft strings, the forest lights up again, lullaby that fades into sleep, instrumental
```
