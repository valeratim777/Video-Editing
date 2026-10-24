# Визуальный стиль + промпты для ChatGPT

Стиль описан по разбору скриншотов референса, **без упоминания его названия** — так нейросеть берёт приёмы, а не копирует чужую игру.

## Черты стиля

**Камера и масштаб**
- Вид сбоку, ортогональная камера, сильно отдалённая: герой занимает ~1/20 высоты экрана, видна большая часть арены.
- Базовое разрешение 640×360, увеличение x3 до 1080p. Персонажи ~16–24 px, тайлы 16 px.

**Форма**
- Округлые «пухлые» персонажи с крупной головой и простыми мордочками; глаза — белые с маленьким зрачком и прямым верхним веком (сонный, невозмутимый взгляд — источник юмора).
- Тёмный контур 1 px вокруг персонажей, предметов и иконок.

**Рельеф**
- Ступенчатые блочные формы по сетке 16 px.
- У открытых краёв — толстый яркий бортик 2–3 px (песок, пена, мох), внутри — тёмная заливка с едва заметным узором из кружков-камешков.

**Цвет**
- Каждый регион почти монохромный в своём оттенке: фон светлее и бледнее с расстоянием (2–3 слоя силуэтов для параллакса), передний план насыщенный и тёмный.
- Существа — контрастного акцентного цвета (розовые на зелёном, оранжевые на фиолетовом), поэтому их сразу видно.

**Свет и эффекты**
- Мягкие лучи света сверху, свечение (bloom) у снарядов и существ.
- Белые «пыхи» при попадании, частицы повсюду (у нас — пыльца и светлячки вместо пузырей).
- Маленькие полоски здоровья над целями, всплывающие числа, лёгкая тряска экрана, тонкая хроматическая аберрация, виньетка.

**Интерфейс**
- Внизу слева круглые индикаторы: портрет героя внутри кольца-шкалы, рядом кольца инструментов.
- Счётчики валют с иконками и сокращениями (84.7K, 32.7B). Внизу справа выбор инструмента и счётчик заряда «18/18».
- Пиксельный шрифт с тёмной обводкой; подсказки — тёмные панели с рамкой.

**Дерево навыков**
- Тёмно-синий фон с едва видным узором; узлы — иконки в рамках.
- Цвет рамки = состояние (неоновый зелёный / голубой / красный / радужный); связи — сплошные и пунктирные неоновые линии.

**Наше отличие:** ночь. Мир затемнён (`CanvasModulate`), главный источник света — фонарь ёжика (`PointLight2D`), существа светятся сами. Тёплый свет фонаря против холодного синего фона — основа «лампового» настроения.

Заглушки в игре уже сделаны в этом стиле: `tools/art_gen.py` → `docs/img/skill_icons.png`, `docs/img/sprites.png`.

## Как пользоваться промптами

1. Новый чат в ChatGPT. Первым сообщением — **Блок стиля** (ниже).
2. Дальше промпты по одному. Удачный результат прикладывайте к следующим запросам: `match the style and the hero of the attached image exactly`.
3. Не пишите название чужой игры и не прикладывайте её скриншоты — получится копия.
4. Если выходит «слишком детально / не пиксель-арт», добавьте: `fewer, bigger pixels; simpler shapes; flat colors; thick dark 1-pixel outline`.

## Блок стиля (отправить первым)

```
For every image in this chat use this exact art style:
- Modern indie pixel art, side view, orthographic 2D camera pulled far back: the hero is small (about 1/20 of the screen height) and we see a large part of the level.
- Low resolution look: as if drawn at 640x360 and scaled up 3x with crisp square pixels. Characters about 16-24 pixels tall, terrain on a 16-pixel grid.
- Chunky round cute characters with big heads and simple faces; eyes are white with a tiny pupil and a flat upper eyelid (sleepy, deadpan expression). 1-pixel dark outline around characters, objects and icons.
- Terrain made of stair-stepped blocky shapes; every exposed edge has a thick bright 2-3 pixel rim (moss, frost or glow), the inside is dark with a faint pebble pattern.
- Each region is almost monochrome in its own hue: background layers get lighter and paler with distance (2-3 parallax silhouette layers), foreground is dark and saturated. Creatures use a contrasting bright accent color so they pop.
- Night setting: the world is dark blue, the main warm light comes from the hero's lantern, creatures glow softly. Bloom on glowing things, soft light rays, floating glowing pollen particles, white puff effects on hits, small health bars above targets, floating numbers.
- Mobile game HUD: round gauges bottom-left (hero portrait inside a ring meter, tool rings next to it), currency counters with icons and short numbers like 84.7K top-left, tool button bottom-right with ammo counter like 18/18. Pixel font with dark outline. No other text.
Confirm and wait for my prompts.
```

## Промпты

**1. Скриншот геймплея (главный референс)**
```
Gameplay screenshot of a cozy mobile game, landscape 16:9. Night magical forest arena, side view: a small hedgehog explorer with a glowing lantern on a little backpack floats in the middle, throwing a glass jar-net with a slingshot at a group of round glowing firefly creatures with sleepy eyes; one golden creature among them. A mossy blocky tree-stump block on the right is cracking from an electric spark coming from the hedgehog's pick. A campfire at the top-left on a ledge is the return point. Terrain: dark blocky ledges with bright moss rims. HUD as described in the style.
```

**2. Лист персонажа**
```
Character reference sheet on a plain dark-blue background: the hedgehog explorer — round brown spiky body, beige face with a deadpan sleepy eye, goggles on the forehead, small scarf, a lantern on a pole fixed to a tiny backpack. Views: side, front, back. Poses: idle float, moving, throwing with the slingshot, using the spark pick, swimming with a bubble helmet, curled up into a ball (out of light). Same proportions everywhere, about 20 pixels tall.
```

**3. Существа 9 регионов**
```
Creature sheet on a plain dark background, 3x3 grid, one creature per cell, each glowing in its own accent color with sleepy deadpan eyes: firefly (yellow), hummingbird-moth (pink), glowworm (cyan), glowing fish (mint), spore fairy (magenta), dragonfly (teal), maple leaf spirit (orange), snow moth (pale blue), fire beetle (amber). Below: one firefly in normal, silver, gold and rainbow variants, identical shape.
```

**4. Регионы (по одному на картинку, меняйте название и описание)**
```
Wide gameplay arena for the region "Cloud Forest": misty mountain forest, moss and orchids, thick fog where only the lantern circle is clear. Blocky dark ledges with pale-green rims, 2-3 pale parallax layers behind. Hedgehog for scale, a few pink hummingbird-moth creatures, two tree-stump blocks, a campfire on a ledge. No HUD.
```

**5. Деревня-хаб**
```
Very wide side-view panorama of a cozy treehouse village built into a giant tree at night: warm glowing windows, rope bridges, a market stall with a merchant, a big skill-tree shrine, a campfire with a path down into the dark forest. Some houses are still dark and boarded up (not restored yet). Villagers are small round animals with deadpan eyes.
```

**6. Экран дерева навыков**
```
Skill tree screen, landscape 16:9: dark navy background with a faint wood-ring pattern. A glowing sapling in the center; six branches radiate outward like cracks in a tree-trunk cross-section. Nodes are small pixel icons in round frames; frame colors show state: dim grey (locked), cyan (available), neon green (bought), rainbow (maxed). Solid and dotted glowing connection lines. A dark tooltip panel with a frame on the right: icon, level "Lvl 3/10", a two-line description and a green buy button with an amber price. Currency counters top-left.
```

**7. Набор иконок навыков (для замены заглушек)**
```
Sheet of 30 pixel-art skill icons, 16x16 style scaled up, each with a 1-pixel dark outline, on a plain dark background in a grid: lantern, slingshot, glass jar, two jars, target, dice, spark pick, lightning bolt, chain, burst, crystal, log, star (white, silver, gold, rainbow), firefly, moth, wind-up beetle, oil drop, boot, backpack, amber coin, clock, market stall, magnet, curled-up hedgehog, campfire, flower, crescent moon, footprints, small tree.
```

**8. Иконка приложения**
```
Mobile app icon, square: close-up of the hedgehog explorer's face lit by its lantern, a golden glowing firefly nearby, dark blue night background, bold simple pixel shapes readable at small size, no text.
```
