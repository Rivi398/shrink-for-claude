# shrink-for-claude

**Вставляй любой скриншот в Claude без ошибки «image dimensions exceed max allowed size».**

Модуль для [Hammerspoon](https://www.hammerspoon.org) на macOS: держит картинки не больше 2000
пикселей по длинной стороне, чтобы их принимал Claude (Claude Code, claude.ai, API и другие
ИИ-чаты). [English](README.md) · MIT

## Проблема

Скриншот с Retina-экрана шире 3000 пикселей. Как только в разговоре с Claude набирается
несколько картинок, каждая должна укладываться в 2000 пикселей, и Claude Code останавливается:

```
image dimensions exceed max allowed size for many-image requests: 2000 pixels
```

Уменьшать каждый скриншот руками быстро надоедает.

## Что делает

1. **Перехват ⌘V.** Если при вставке в буфере большая картинка, модуль сначала уменьшает её,
   потом вставляет. Со стороны это обычная вставка.
2. **Сторож буфера.** Уменьшает большие картинки в буфере в фоне, для программ, которые
   читают буфер без ⌘V.
3. **Папка скриншотов.** Новые файлы скриншотов (`Снимок экрана …`, `Screenshot …`, CleanShot
   и названия на других языках) в папке, куда macOS сохраняет скриншоты, уменьшаются на месте.

Картинки, которые уже влезают в лимит, не трогаются. Размер меряется в настоящих пикселях через
`sips` (собственный `image:size()` у Hammerspoon на Retina отдаёт точки, то есть вдвое меньше).
Картинки, скопированные на айфоне через универсальный буфер, пропускаются: чтение внутри
перехвата вставки тянет их по воздуху и может сорвать вставку.

## Установка

1. Поставь Hammerspoon: `brew install --cask hammerspoon`, запусти и разреши ему
   «Универсальный доступ», когда спросит (нужно для перехвата ⌘V).
2. Скачай модуль:
   ```bash
   curl -fsSL https://raw.githubusercontent.com/Rivi398/shrink-for-claude/main/shrink_for_claude.lua \
     -o ~/.hammerspoon/shrink_for_claude.lua
   ```
3. Добавь в `~/.hammerspoon/init.lua`:
   ```lua
   shrink = require("shrink_for_claude")
   shrink.start()
   ```
4. Меню Hammerspoon → **Reload Config**.

## Настройки

```lua
shrink.start({
  maxPixels = 2000,      -- длинная сторона после уменьшения (сам Claude ужимает до 1568)
  pasteHook = true,      -- перехват ⌘V
  watcher = true,        -- сторож буфера
  screenshots = true,    -- уменьшать новые файлы скриншотов
  screenshotDir = nil,   -- по умолчанию папка скриншотов macOS
  log = false,           -- журнал в ~/.hammerspoon/shrink_for_claude.log
})
```

`shrink.stop()` выключает всё. `shrink.shrinkFile(path)` уменьшает один файл.

Учти: файлы скриншотов уменьшаются на месте. Если хранишь скриншоты в полном размере,
поставь `screenshots = false`.

## Лицензия

MIT © 2026 Сергей Чеберко. Не связано с Anthropic.
