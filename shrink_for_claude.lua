-- shrink_for_claude: keep images small enough for Claude (and other AI chats) on macOS.
--
-- Claude refuses images over 2000 px on the long side once a conversation holds many images
-- ("image dimensions exceed max allowed size for many-image requests: 2000 pixels"), and
-- Retina screenshots are routinely 3000+ px. This Hammerspoon module shrinks them for you:
--
--   1. paste hook:  on ⌘V, if the clipboard holds a large image, shrink it, then paste;
--   2. watcher:     shrink large clipboard images in the background (apps that read the
--                   clipboard without ⌘V, drag and drop from a preview);
--   3. screenshots: shrink new screenshot files in your screenshot folder.
--
-- Sizes are measured with `sips` in real pixels: on Retina, hs.image:size() reports points,
-- i.e. half the real size, and would miss most oversized images.
--
-- Usage in ~/.hammerspoon/init.lua:
--   shrink = require("shrink_for_claude")
--   shrink.start()                                   -- all three, 2000 px
--   shrink.start({ maxPixels = 1568, screenshots = false })

local M = {}

M.config = {
    maxPixels = 2000,     -- longest side after shrinking
    pasteHook = true,
    watcher = true,
    screenshots = true,
    screenshotDir = nil,  -- nil = the folder macOS saves screenshots to
    log = false,          -- true: log to ~/.hammerspoon/shrink_for_claude.log
}

-- Screenshot file names in a few macOS languages, plus CleanShot.
local SCREENSHOT_PREFIXES = {
    "Screenshot", "Снимок экрана", "Bildschirmfoto", "Capture d’écran", "Capture d'écran",
    "Captura de pantalla", "Captura de Tela", "Istantanea", "Schermafbeelding", "Zrzut ekranu",
    "Skärmavbild", "スクリーンショット", "截屏", "스크린샷", "CleanShot",
}

local IMAGE_TYPES = {
    ["public.png"] = true, ["public.tiff"] = true, ["public.jpeg"] = true,
    ["com.compuserve.gif"] = true, ["public.heic"] = true,
}

local function log(msg)
    if not M.config.log then return end
    local f = io.open(os.getenv("HOME") .. "/.hammerspoon/shrink_for_claude.log", "a")
    if f then
        f:write(os.date("[%Y-%m-%d %H:%M:%S] ") .. msg .. "\n")
        f:close()
    end
end

local function pixelSize(path)
    local out, ok = hs.execute(string.format("/usr/bin/sips -g pixelWidth -g pixelHeight %q", path))
    if not ok or not out then return nil end
    local w = tonumber(out:match("pixelWidth:%s*(%d+)"))
    local h = tonumber(out:match("pixelHeight:%s*(%d+)"))
    if not w or not h then return nil end
    return w, h
end

-- Shrinks the file in place if its long side is over the limit. Returns w, h when it did.
function M.shrinkFile(path)
    local w, h = pixelSize(path)
    if not w or math.max(w, h) <= M.config.maxPixels then return nil end
    local _, ok = hs.execute(string.format("/usr/bin/sips -Z %d %q >/dev/null 2>&1", M.config.maxPixels, path))
    if not ok then
        log("sips failed for " .. path)
        return nil
    end
    return w, h
end

local function clipboardHasImage()
    local types = hs.pasteboard.contentTypes()
    if not types then return false end
    for _, t in ipairs(types) do
        -- An image copied on an iPhone (Universal Clipboard) still lives on the phone, and
        -- reading it pulls it over the air inside the ⌘V handler. A slow transfer makes macOS
        -- disable the key tap and the paste fails, so leave those alone.
        if t == "com.apple.is-remote-clipboard" then return false end
    end
    for _, t in ipairs(types) do
        if IMAGE_TYPES[t] then return true end
    end
    return false
end

-- Returns true if the clipboard image was replaced with a smaller one.
function M.shrinkClipboard()
    if not clipboardHasImage() then return false end
    local img = hs.pasteboard.readImage()
    if not img then return false end

    local tmp = string.format("%s/shrink_for_claude_%d.png", os.getenv("TMPDIR") or "/tmp", hs.timer.absoluteTime())
    if not img:saveToFile(tmp) then return false end
    local w, h = M.shrinkFile(tmp)
    local resized = w and hs.image.imageFromPath(tmp)
    os.remove(tmp)
    if not resized then return false end

    if hs.pasteboard.writeObjects(resized) then
        log(string.format("clipboard %dx%d -> max %d px", w, h, M.config.maxPixels))
        return true
    end
    return false
end

local function startPasteHook()
    local reentry = false  -- our own re-sent ⌘V must pass through
    M.tap = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, function(event)
        -- 9 is the physical V key: hs.keycodes.map.v follows the active layout and breaks on e.g. Russian.
        if reentry or event:getKeyCode() ~= 9 then return false end
        local f = event:getFlags()
        if not f.cmd or f.shift or f.alt or f.ctrl or f.fn then return false end
        if not clipboardHasImage() then return false end

        local ok, changed = pcall(M.shrinkClipboard)
        if not ok then
            log("paste hook error: " .. tostring(changed))
            return false
        end
        if not changed then return false end

        -- Swallow this ⌘V and send a fresh one, so the app reads the shrunk image.
        reentry = true
        hs.timer.doAfter(0.02, function()
            hs.eventtap.keyStroke({ "cmd" }, "v", 0)
            hs.timer.doAfter(0.15, function() reentry = false end)
        end)
        return true
    end)
    M.tap:start()
end

local function startWatcher()
    hs.pasteboard.watcher.interval(0.1)
    M.watcher = hs.pasteboard.watcher.new(function()
        local ok, err = pcall(M.shrinkClipboard)
        if not ok then log("watcher error: " .. tostring(err)) end
    end)
    M.watcher:start()
end

local function screenshotDir()
    if M.config.screenshotDir then return M.config.screenshotDir end
    local out, ok = hs.execute("/usr/bin/defaults read com.apple.screencapture location 2>/dev/null")
    local dir = ok and out and out:gsub("%s+$", "") or ""
    if dir == "" then return os.getenv("HOME") .. "/Desktop" end
    return (dir:gsub("^~", os.getenv("HOME")))
end

local function isScreenshot(path)
    local name = path:match("([^/]+)$")
    if not name or not name:lower():match("%.png$") then return false end
    for _, prefix in ipairs(SCREENSHOT_PREFIXES) do
        if name:sub(1, #prefix) == prefix then return true end
    end
    return false
end

local function startScreenshots()
    local dir = screenshotDir()
    M.pathwatcher = hs.pathwatcher.new(dir, function(paths, flags)
        for i, p in ipairs(paths) do
            local fl = flags[i] or {}
            if fl.itemIsFile and (fl.itemCreated or fl.itemModified or fl.itemRenamed) and isScreenshot(p) then
                -- Give screencapture a moment to finish writing.
                hs.timer.doAfter(0.2, function()
                    local w, h = M.shrinkFile(p)
                    if w then log(string.format("screenshot %s %dx%d -> max %d px", p, w, h, M.config.maxPixels)) end
                end)
            end
        end
    end)
    M.pathwatcher:start()
    return dir
end

function M.start(opts)
    M.stop()
    for k, v in pairs(opts or {}) do M.config[k] = v end
    if M.config.pasteHook then startPasteHook() end
    if M.config.watcher then startWatcher() end
    local dir = M.config.screenshots and startScreenshots()
    log(string.format("started: max %d px, paste hook %s, watcher %s, screenshots %s",
        M.config.maxPixels, tostring(M.config.pasteHook), tostring(M.config.watcher), dir or "off"))
    return M
end

function M.stop()
    for _, key in ipairs({ "tap", "watcher", "pathwatcher" }) do
        if M[key] then
            M[key]:stop()
            M[key] = nil
        end
    end
end

-- Exposed for tests.
M._isScreenshot = isScreenshot
M._screenshotDir = screenshotDir

return M
