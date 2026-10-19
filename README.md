# shrink-for-claude

**Paste any screenshot into Claude without "image dimensions exceed max allowed size".**

A [Hammerspoon](https://www.hammerspoon.org) module for macOS that keeps images at or under
2000 px on the long side, so Claude (Claude Code, claude.ai, the API, other AI chats) takes them.
[По-русски](README.ru.md) · MIT

## The problem

Retina screenshots are 3000+ px wide. Once a Claude conversation holds several images, every
image must fit in 2000 px, and Claude Code stops with:

```
image dimensions exceed max allowed size for many-image requests: 2000 pixels
```

Resizing each screenshot by hand gets old fast.

## What it does

1. **⌘V hook.** When you paste and the clipboard holds a large image, it shrinks it first,
   then pastes. You see nothing but a normal paste.
2. **Clipboard watcher.** Shrinks large clipboard images in the background, for apps that read
   the clipboard without ⌘V.
3. **Screenshot folder.** New screenshot files (`Screenshot …`, `Снимок экрана …`, CleanShot and
   other languages) in the folder macOS saves screenshots to get shrunk in place.

Images already under the limit are never touched. Sizes are measured in real pixels with `sips`
(Hammerspoon's own `image:size()` reports Retina points, half the real size). Images copied on an
iPhone via Universal Clipboard are skipped: reading them inside the paste hook pulls them over the
air and can break the paste.

## Install

1. Install Hammerspoon: `brew install --cask hammerspoon`, start it, and allow Accessibility
   when asked (needed for the ⌘V hook).
2. Copy the module:
   ```bash
   curl -fsSL https://raw.githubusercontent.com/Rivi398/shrink-for-claude/main/shrink_for_claude.lua \
     -o ~/.hammerspoon/shrink_for_claude.lua
   ```
3. Add to `~/.hammerspoon/init.lua`:
   ```lua
   shrink = require("shrink_for_claude")
   shrink.start()
   ```
4. Hammerspoon menu → **Reload Config**.

## Options

```lua
shrink.start({
  maxPixels = 2000,      -- long side after shrinking (1568 is what Claude itself downsizes to)
  pasteHook = true,      -- ⌘V hook
  watcher = true,        -- background clipboard watcher
  screenshots = true,    -- shrink new screenshot files
  screenshotDir = nil,   -- default: where macOS saves screenshots
  log = false,           -- log to ~/.hammerspoon/shrink_for_claude.log
})
```

`shrink.stop()` turns everything off. `shrink.shrinkFile(path)` shrinks one file.

Note: shrinking screenshot files changes them in place. If you keep full-size screenshots,
set `screenshots = false`.

## License

MIT © 2026 Sergey Cheberko. Not affiliated with Anthropic.
