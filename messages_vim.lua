-- messages_vim.lua — Invisible hotkeys for macOS Messages.app
-- No UI, no modes — just modifier-based shortcuts when Messages is focused.
--
-- Most actions forward to Messages' built-in shortcuts. The scroll engine
-- and AX-based focus_search/focus_input are the only custom behaviors.
--
-- Usage:
--   require("messages_vim").setup({})              -- defaults
--   require("messages_vim").setup({
--     mod  = "alt",                                -- change modifier
--     keys = { focus_input = "return" },           -- override individual keys
--   })
--
-- Set a key to `false` to disable it.

local M = {}

local ax       = require("hs.axuielement")
local eventtap = require("hs.eventtap")
local timer    = require("hs.timer")
local keycodes = require("hs.keycodes")
local log      = hs.logger.new("msgvim", "debug")

local BUNDLE_ID = "com.apple.MobileSMS"

-- ── Config ──────────────────────────────────────────────────────────

local cfg = {
    mod  = "ctrl",
    keys = {
        -- Navigation
        conv_down      = "j",       -- next conversation
        conv_up        = "k",       -- previous conversation
        focus_search   = "f",       -- focus search field
        focus_input    = "i",       -- focus message compose box
        scroll_up      = "u",       -- scroll messages up (hold to accelerate)
        scroll_down    = "d",       -- scroll messages down (hold to accelerate)

        -- Message actions (forwarded to built-in Messages shortcuts)
        tapback        = "t",       -- open tapback picker (then 1-6 to react)
        reply          = "r",       -- reply to last received message
        edit           = "e",       -- edit last sent message

        -- Conversation management
        info           = "g",       -- show conversation details
        mark_read      = "m",       -- toggle read/unread
        delete_conv    = "x",       -- delete conversation

        -- Window
        close          = "w",       -- close panel or hide app
        open_in_panel  = "space",   -- open conversation in separate window
    },
}

-- ── App Helpers ───────────────────────────────────────────────────

local function messagesApp()
    return hs.application.get(BUNDLE_ID)
end

local function isFrontmost()
    local app = hs.application.frontmostApplication()
    return app and app:bundleID() == BUNDLE_ID
end

-- ── AX Helpers ──────────────────────────────────────────────────────

local function axWindow()
    local app = messagesApp()
    if not app then return nil end
    local axApp = ax.applicationElement(app)
    if not axApp then return nil end
    return axApp:attributeValue("AXMainWindow")
        or axApp:attributeValue("AXFocusedWindow")
end

local function findByAttr(el, attr, value, depth)
    depth = depth or 12
    if depth <= 0 or not el then return nil end
    if el:attributeValue(attr) == value then return el end
    local kids = el:attributeValue("AXChildren")
    if not kids then return nil end
    for _, kid in ipairs(kids) do
        local hit = findByAttr(kid, attr, value, depth - 1)
        if hit then return hit end
    end
end

-- ── UI Element Accessors ────────────────────────────────────────────

local function conversationList()
    local win = axWindow()
    if not win then return nil end
    return findByAttr(win, "AXIdentifier", "ConversationList")
end

local function messageInput()
    local win = axWindow()
    if not win then return nil end
    return findByAttr(win, "AXIdentifier", "messageBodyField")
end

local function searchField()
    local win = axWindow()
    if not win then return nil end
    return findByAttr(win, "AXSubrole", "AXSearchField")
end

local function scrollTarget()
    local win = axWindow()
    if not win then return nil end
    return findByAttr(win, "AXDescription", "Search results")
        or findByAttr(win, "AXIdentifier", "TranscriptCollectionView")
end

-- ── Click Helper ────────────────────────────────────────────────────

local clickEventNum = 0
local function clickElement(el)
    if not el then return false end
    local pos  = el:attributeValue("AXPosition")
    local size = el:attributeValue("AXSize")
    if not pos or not size then return false end
    local pt = { x = pos.x + size.w / 2, y = pos.y + size.h / 2 }

    local orig = hs.mouse.absolutePosition()
    clickEventNum = clickEventNum + 1
    local down = eventtap.event.newMouseEvent(eventtap.event.types.leftMouseDown, pt)
    local up   = eventtap.event.newMouseEvent(eventtap.event.types.leftMouseUp, pt)
    down:setFlags({})
    up:setFlags({})
    down:setProperty(eventtap.event.properties.mouseEventClickState, 1)
    up:setProperty(eventtap.event.properties.mouseEventClickState, 1)
    down:setProperty(eventtap.event.properties.mouseEventNumber, clickEventNum)
    up:setProperty(eventtap.event.properties.mouseEventNumber, clickEventNum)
    down:post()
    up:post()
    hs.mouse.absolutePosition(orig)
    return true
end

-- ── Actions ─────────────────────────────────────────────────────────

local actions = {}

function actions.focus_search()
    if not clickElement(searchField()) then log.w("search field not found") end
end

function actions.focus_input()
    if not clickElement(messageInput()) then log.w("message input not found") end
end

function actions.conv_down()
    eventtap.keyStroke({"cmd", "shift"}, "]", 0)
end

function actions.conv_up()
    eventtap.keyStroke({"cmd", "shift"}, "[", 0)
end

function actions.tapback()
    eventtap.keyStroke({"cmd"}, "t", 0)
end

function actions.reply()
    eventtap.keyStroke({"cmd"}, "r", 0)
end

function actions.edit()
    eventtap.keyStroke({"cmd"}, "e", 0)
end

function actions.info()
    eventtap.keyStroke({"cmd", "alt"}, "i", 0)
end

function actions.mark_read()
    eventtap.keyStroke({"cmd", "shift"}, "u", 0)
end

function actions.delete_conv()
    eventtap.keyStroke({"cmd"}, "delete", 0)
end

-- ── Smooth Scroll Engine ────────────────────────────────────────────
-- Velocity-based: accelerates while held, decelerates with ease-out on release.

local scroll = {
    velocity  = 0,
    maxSpeed  = 32,
    accel     = 3.5,
    friction  = 0.88,
    direction = 0,
    holding   = false,
    ticker    = nil,
    scrollPt  = nil,
    origMouse = nil,
}

local function scrollTick()
    if scroll.holding then
        scroll.velocity = scroll.velocity + scroll.accel
        if scroll.velocity > scroll.maxSpeed then
            scroll.velocity = scroll.maxSpeed
        end
    else
        scroll.velocity = scroll.velocity * scroll.friction
        if scroll.velocity < 0.5 then
            scroll.velocity = 0
            scroll.direction = 0
            if scroll.ticker then scroll.ticker:stop(); scroll.ticker = nil end
            if scroll.origMouse then
                hs.mouse.absolutePosition(scroll.origMouse)
                scroll.origMouse = nil
            end
            return
        end
    end
    local px = math.floor(scroll.velocity * scroll.direction)
    if px ~= 0 and scroll.scrollPt then
        eventtap.event.newScrollEvent({ 0, px }, {}, "pixel"):post()
    end
end

local function scrollStart(direction)
    scroll.holding = true
    if scroll.direction == direction and scroll.ticker then return end
    scroll.direction = direction
    scroll.velocity = 4

    local area = scrollTarget()
    if not area then return end
    local pos  = area:attributeValue("AXPosition")
    local size = area:attributeValue("AXSize")
    if not pos or not size then return end

    scroll.scrollPt = { x = pos.x + size.w / 2, y = pos.y + size.h / 2 }
    scroll.origMouse = hs.mouse.absolutePosition()
    hs.mouse.absolutePosition(scroll.scrollPt)

    if not scroll.ticker then
        scroll.ticker = timer.doEvery(1 / 60, scrollTick)
    end
end

local function scrollStop()
    scroll.holding = false
end

function actions.scroll_up()
    scrollStart(1)
end

function actions.scroll_down()
    scrollStart(-1)
end

-- ── Window Actions ──────────────────────────────────────────────────

local function doubleClickElement(el)
    if not el then return false end
    local pos  = el:attributeValue("AXPosition")
    local size = el:attributeValue("AXSize")
    if not pos or not size then return false end
    local pt = { x = pos.x + size.w / 2, y = pos.y + size.h / 2 }
    local down1 = eventtap.event.newMouseEvent(eventtap.event.types.leftMouseDown, pt)
    local up1   = eventtap.event.newMouseEvent(eventtap.event.types.leftMouseUp, pt)
    down1:setFlags({})
    up1:setFlags({})
    down1:setProperty(eventtap.event.properties.mouseEventClickState, 1)
    up1:setProperty(eventtap.event.properties.mouseEventClickState, 1)
    down1:post()
    up1:post()
    timer.doAfter(0.05, function()
        local down2 = eventtap.event.newMouseEvent(eventtap.event.types.leftMouseDown, pt)
        local up2   = eventtap.event.newMouseEvent(eventtap.event.types.leftMouseUp, pt)
        down2:setFlags({})
        up2:setFlags({})
        down2:setProperty(eventtap.event.properties.mouseEventClickState, 2)
        up2:setProperty(eventtap.event.properties.mouseEventClickState, 2)
        down2:post()
        up2:post()
    end)
    return true
end

function actions.open_in_panel()
    local list = conversationList()
    if not list then log.w("conversation list not found"); return end
    local kids = list:attributeValue("AXChildren")
    if not kids or #kids == 0 then return end
    for _, kid in ipairs(kids) do
        if kid:attributeValue("AXSelected") then
            doubleClickElement(kid)
            return
        end
    end
    log.w("open_in_panel: no conversation selected")
end

function actions.close()
    local app = messagesApp()
    if not app then return end
    local win = app:focusedWindow()
    if not win then app:hide(); return end
    local axWin = ax.windowElement(win)
    if findByAttr(axWin, "AXIdentifier", "ConversationList") then
        app:hide()
    else
        win:close()
    end
end

-- ── Key Handler ─────────────────────────────────────────────────────

local keyTap = nil
local bindings = nil
local scrollKeycodes = {}

local function buildKeyMap()
    bindings = {}
    scrollKeycodes = {}
    for action, key in pairs(cfg.keys) do
        if key == false then goto continue end
        local mod, keyName
        if type(key) == "table" then
            mod     = key.mod
            keyName = key.key
        else
            mod     = cfg.mod
            keyName = key
        end
        local code = keycodes.map[keyName]
        if code then
            bindings[#bindings + 1] = { keycode = code, mod = mod, action = action }
            if action == "scroll_up" or action == "scroll_down" then
                scrollKeycodes[code] = true
            end
            log.i("mapped " .. mod .. "+" .. keyName .. " -> " .. action)
        else
            log.w("unknown key: " .. keyName .. " for action: " .. action)
        end
        ::continue::
    end
end

local function hasExactMod(flags, mod)
    if not flags[mod] then return false end
    for _, m in ipairs({ "cmd", "alt", "ctrl", "shift", "fn" }) do
        if m ~= mod and flags[m] then return false end
    end
    return true
end

local function keyHandler(evt)
    if not isFrontmost() then
        if scroll.holding then scrollStop() end
        return false
    end

    local evtType = evt:getType()

    -- Stop scrolling on keyUp or modifier change
    if evtType == eventtap.event.types.keyUp
       or evtType == eventtap.event.types.flagsChanged then
        if scroll.holding then scrollStop() end
        return false
    end

    local flags = evt:getFlags()
    local code  = evt:getKeyCode()

    if scroll.holding and not scrollKeycodes[code] then
        scrollStop()
    end

    for _, b in ipairs(bindings) do
        if b.keycode == code and hasExactMod(flags, b.mod) then
            log.i("action: " .. b.action)
            local fn = actions[b.action]
            if fn then
                local ok, err = pcall(fn)
                if not ok then log.e(b.action .. " error: " .. tostring(err)) end
                return true
            end
        end
    end

    return false
end

-- ── Lifecycle ───────────────────────────────────────────────────────

function M.setup(opts)
    opts = opts or {}

    if opts.mod then cfg.mod = opts.mod end
    if opts.keys then
        for k, v in pairs(opts.keys) do
            cfg.keys[k] = v
        end
    end

    buildKeyMap()

    if keyTap then keyTap:stop() end
    keyTap = eventtap.new({
        eventtap.event.types.keyDown,
        eventtap.event.types.keyUp,
        eventtap.event.types.flagsChanged,
    }, keyHandler)
    keyTap:start()

    log.i("ready (mod=" .. cfg.mod .. ")")
    return M
end

function M.stop()
    if keyTap then keyTap:stop(); keyTap = nil end
end

M.actions = actions

return M
