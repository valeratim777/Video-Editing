# Сборка APK для Android

Предустановка экспорта уже есть: `game/export_presets.cfg` (пакет `com.lanternwood.game`, arm64 + armv7, полноэкранный режим, альбомная ориентация).

## Один раз

1. Установить **Godot 4.7.2** (обычный, не .NET).
2. В Godot: **Editor → Manage Export Templates → Download and Install** (шаблоны экспорта 4.7.2).
3. Установить **JDK 17** (например, Adoptium Temurin 17) и **Android SDK** (проще всего — Android Studio; нужны *platform-tools*, *build-tools 34+*, *platform 34+*).
4. В Godot: **Editor → Editor Settings → Export → Android**: указать путь к Java SDK и к Android SDK.
5. Debug-ключ Godot создаёт сам. Для публикации в Google Play — создать release-ключ (`keytool -genkey ...`) и указать его в настройках экспорта.

## Сборка

1. Открыть `game/project.godot`.
2. **Project → Export → Android → Export Project** → сохранить `lanternwood.apk`.
3. Установить на телефон: включить «Отладку по USB» и выполнить `adb install -r lanternwood.apk` — или просто скопировать APK на телефон и открыть.

Быстрый тест без сборки: в Godot включить **Remote Debug → One-click deploy** — значок Android появится в правом верхнем углу редактора, если телефон подключён по USB.

## Что проверить на телефоне

- Джойстик (левая половина экрана) и кнопки рогатки/кирки работают одновременно (мультитач).
- Дерево навыков: перетаскивание одним пальцем, масштаб двумя пальцами, тап по узлу.
- После сворачивания и возврата игра продолжает с того же места; рынок досчитывает продажи «пока ты спал».
- 60 FPS в походе (если меньше — уменьшить `amount` у фоновых частиц в `expedition.gd`).
