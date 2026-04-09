-- Clear any stale notifications from previous Hammerspoon sessions.
local _delivered = hs.notify.deliveredNotifications()
print("[reload] deliveredNotifications count=" .. tostring(#_delivered))
for _, n in ipairs(_delivered) do n:withdraw() end
hs.notify.withdrawAll()

local pendingNotifications = {}

-- Resolve tmux binary once at load time
local tmuxBin = "/usr/bin/tmux"
for _, p in ipairs({"/opt/homebrew/bin/tmux", "/usr/local/bin/tmux"}) do
    if hs.fs.attributes(p) then tmuxBin = p; break end
end

-- Strip characters that are unsafe in single-quoted shell arguments
local function shellSanitize(s)
    return s:gsub("[^%w@/._:-]", "")
end

-- Extract the tmux window key (e.g. "@116") from a raw window ID or session:window string
local function extractWinKey(id)
    return id:match("(@%w+)$") or id
end

-- Cached window key for the currently active tmux window in Ghostty.
-- Updated when Ghostty is activated; used by keyTap/clickTap to avoid per-keystroke shell calls.
local activeWinKey = nil

local quickTerminalKeycode = hs.keycodes.map.grave or 50

local function sendQuickTerminalToggle()
    hs.eventtap.event.newKeyEvent({"cmd"}, quickTerminalKeycode, true):post()
    hs.eventtap.event.newKeyEvent({"cmd"}, quickTerminalKeycode, false):post()
end

local function openGhosttyQuickTerminal()
    local ghostty = hs.application.get("Ghostty")
    if ghostty and ghostty:isFrontmost() then
        return
    end

    if ghostty then
        sendQuickTerminalToggle()
        return
    end

    local launched = hs.application.launchOrFocus("Ghostty")
    if not launched then
        return
    end

    local attemptsRemaining = 20
    local function waitForGhosttyAndToggle()
        local app = hs.application.get("Ghostty")
        if app and app:isFrontmost() then
            sendQuickTerminalToggle()
            return
        end
        attemptsRemaining = attemptsRemaining - 1
        if attemptsRemaining <= 0 then
            hs.application.launchOrFocus("Ghostty")
            return
        end
        hs.timer.doAfter(0.1, waitForGhosttyAndToggle)
    end

    hs.timer.doAfter(0.1, function()
        waitForGhosttyAndToggle()
    end)
end

local function updateActiveWinKey()
    -- Get all client names sorted by most-recently-active first.
    local out, _ = hs.execute(tmuxBin .. " list-clients -F '#{client_activity} #{client_name}' 2>/dev/null | sort -rn")
    if not out or out:gsub("%s+", "") == "" then return end
    local clients = {}
    for line in out:gmatch("[^\n]+") do
        local client = line:match("^%d+ (.+)$")
        if client then
            client = shellSanitize(client:gsub("%s+$", ""))
            if client ~= "" then clients[#clients+1] = client end
        end
    end
    if #clients == 0 then return end
    -- When notifications are pending, scan all clients to find one showing the
    -- pending window. Clicking a Ghostty tab does not update client_activity, so
    -- the most-active client may not be the one the user just switched to.
    if hasPendingNotifications() then
        for _, client in ipairs(clients) do
            local winId, _ = hs.execute(tmuxBin .. " display-message -c '" .. client .. "' -p '#{window_id}' 2>/dev/null")
            winId = winId:gsub("%s+$", "")
            local wk = extractWinKey(winId)
            print("[updateActiveWinKey] client=" .. client .. " wk=" .. wk .. " pending=" .. tostring(pendingNotifications[wk] ~= nil))
            if wk ~= "" and pendingNotifications[wk] then
                activeWinKey = wk
                print("[updateActiveWinKey] matched pending, activeWinKey=" .. wk)
                return
            end
        end
    end
    -- Fall back to most-active client's current window.
    local winId, _ = hs.execute(tmuxBin .. " display-message -c '" .. clients[1] .. "' -p '#{window_id}' 2>/dev/null")
    winId = winId:gsub("%s+$", "")
    if winId ~= "" then
        activeWinKey = extractWinKey(winId)
        print("[updateActiveWinKey] fallback activeWinKey=" .. activeWinKey)
    end
end

local function dismissActiveIfPending()
    if activeWinKey and pendingNotifications[activeWinKey] then
        dismissNotify(activeWinKey)
        hs.execute(tmuxBin .. " set-option -wuq -t '" .. activeWinKey .. "' @needs_attention 2>/dev/null; " .. tmuxBin .. " refresh-client -S 2>/dev/null")
    end
    if pendingNotifications["__bare__"] then
        dismissNotify("__bare__")
    end
end

-- Dismiss a pending notification by window key (e.g. "@116")
function dismissNotify(winKey)
    print("[dismissNotify] called with winKey=" .. tostring(winKey))
    local n = pendingNotifications[winKey]
    if n then
        print("[dismissNotify] found and withdrawing")
        n:withdraw()
        pendingNotifications[winKey] = nil
    else
        print("[dismissNotify] no match, keys=" .. (function()
            local ks = {}
            for k in pairs(pendingNotifications) do ks[#ks+1] = k end
            return table.concat(ks, ",")
        end)())
    end
end

-- Dismiss any pending notifications whose window is currently visible to
-- some tmux client. Useful when invoked from tmux hooks where the hook's
-- window_id may not match the pending key (e.g. Ghostty tab switches don't
-- update tmux client_activity).
function dismissVisiblePending()
    if not hasPendingNotifications() then return end
    local out, _ = hs.execute(tmuxBin .. " list-clients -F '#{client_name}' 2>/dev/null")
    if not out then return end
    for client in out:gmatch("[^\n]+") do
        client = shellSanitize(client:gsub("%s+$", ""))
        if client ~= "" then
            local winId, _ = hs.execute(tmuxBin .. " display-message -c '" .. client .. "' -p '#{window_id}' 2>/dev/null")
            winId = winId:gsub("%s+$", "")
            local wk = extractWinKey(winId)
            print("[dismissVisiblePending] client=" .. client .. " wk=" .. wk .. " pending=" .. tostring(pendingNotifications[wk] ~= nil))
            if wk ~= "" and pendingNotifications[wk] then
                dismissNotify(wk)
                hs.execute(tmuxBin .. " set-option -wuq -t '" .. wk .. "' @needs_attention 2>/dev/null; " .. tmuxBin .. " refresh-client -S 2>/dev/null")
            end
        end
    end
end

-- Dismiss all pending notifications (e.g. on tmux detach)
function dismissAllNotify()
    for k, n in pairs(pendingNotifications) do
        n:withdraw()
        pendingNotifications[k] = nil
    end
end

function hasPendingNotifications()
    for _ in pairs(pendingNotifications) do
        return true
    end
    return false
end

-- Key watcher: on first keystroke in Ghostty, dismiss the active tmux window's notification.
-- Re-resolves the active tmux window when any notification is pending so keyboard-driven
-- window switches clear the correct tab on the next typed key.
-- Only active while Ghostty is the frontmost app (started/stopped by ghosttyWatcher).
local keyTap = hs.eventtap.new({hs.eventtap.event.types.keyDown}, function(_event)
    if not hasPendingNotifications() then return false end
    updateActiveWinKey()
    dismissActiveIfPending()
    return false
end)

-- Mouse click watcher: catches status-bar tab clicks that switch the tmux window.
-- After a brief delay (to let tmux process the click first), re-queries the active
-- window and dismisses its notification if pending. Avoids relying on hs CLI IPC.
local clickTap = hs.eventtap.new({hs.eventtap.event.types.leftMouseUp}, function(_event)
    print("[clickTap] fired, pending=" .. tostring(hasPendingNotifications()) .. " activeWinKey=" .. tostring(activeWinKey))
    if not hasPendingNotifications() then return false end
    hs.timer.doAfter(0.075, function()
        local before = activeWinKey
        updateActiveWinKey()
        print("[clickTap] after update: activeWinKey=" .. tostring(activeWinKey) .. " (was " .. tostring(before) .. ")")
        for k, _ in pairs(pendingNotifications) do
            print("[clickTap] pending: " .. tostring(k))
        end
        dismissActiveIfPending()
    end)
    return false
end)

-- App watcher: dismiss active window's notification when Ghostty gains focus;
-- start/stop keyTap and clickTap so they only run while Ghostty is in front.
local ghosttyWatcher = hs.application.watcher.new(function(name, event, _app)
    if name ~= "Ghostty" then return end
    if event == hs.application.watcher.activated then
        updateActiveWinKey()
        dismissActiveIfPending()
        keyTap:start()
        clickTap:start()
        print("[ghosttyWatcher] activated, clickTap started")
    elseif event == hs.application.watcher.deactivated then
        keyTap:stop()
        clickTap:stop()
        print("[ghosttyWatcher] deactivated, clickTap stopped")
    end
end)
ghosttyWatcher:start()

-- If Ghostty is already frontmost when this config loads, start the watchers immediately
if hs.application.frontmostApplication():name() == "Ghostty" then
    updateActiveWinKey()
    keyTap:start()
    clickTap:start()
    print("[init] Ghostty already frontmost, clickTap started")
end

-- Notification helper called from ~/.notify.sh via:
--   hs -c "showNotify('title', 'message', 'windowId')"
function showNotify(title, message, windowId)
    local winKey = "__bare__"
    if windowId and windowId ~= "" then
        winKey = extractWinKey(windowId)
    end
    print("[showNotify] title=" .. tostring(title) .. " winKey=" .. tostring(winKey))
    -- Track which window has an active notification so keyTap can dismiss
    -- it without querying tmux first (handles the case where activeWinKey
    -- was not set yet, e.g. on first load before Ghostty was activated).
    if winKey ~= "__bare__" then activeWinKey = winKey end
    local n = hs.notify.new(function()
        pendingNotifications[winKey] = nil
        openGhosttyQuickTerminal()
        if windowId and windowId ~= "" then
            hs.timer.doAfter(0.2, function()
                local safeWindowId = shellSanitize(windowId)
                local safeWinKey = shellSanitize(winKey)
                local client, _ = hs.execute(tmuxBin .. " list-clients -F '#{client_activity} #{client_name}' | sort -rn | head -1 | awk '{print $2}'")
                client = shellSanitize(client:gsub("%s+$", ""))
                if client ~= "" then
                    hs.execute(tmuxBin .. " switch-client -c '" .. client .. "' -t '" .. safeWindowId .. "' 2>/dev/null")
                end
                if safeWinKey ~= "" then
                    hs.execute(tmuxBin .. " set-option -wuq -t '" .. safeWinKey .. "' @needs_attention 2>/dev/null; " .. tmuxBin .. " refresh-client -S 2>/dev/null")
                end
            end)
        end
    end, {
        title = title,
        informativeText = message,
        soundName = "Glass",
        hasActionButton = false,
        withdrawAfter = 0,
    })
    if pendingNotifications[winKey] then
        pendingNotifications[winKey]:withdraw()
    end
    pendingNotifications[winKey] = n
    n:send()
end

-- URL event handlers. Shell scripts invoke these via `open -g hammerspoon://<action>?...`.
-- Using hs.urlEvent instead of hs.ipc because hs.ipc's CFMessagePort IPC crashes
-- Hammerspoon 1.1.1 on macOS 26 with a PAC signature trap.
local function b64decode(s)
    if not s or s == "" then return "" end
    return hs.base64.decode(s) or ""
end

local urlEvent = require("hs.urlEvent")
require("hs.base64")

urlEvent.bind("shownotify", function(_, params)
    local title = b64decode(params.title)
    local message = b64decode(params.message)
    local target = b64decode(params.target)
    showNotify(title, message, target)
end)

urlEvent.bind("dismissnotify", function(_, params)
    if params.winKey and params.winKey ~= "" then
        dismissNotify(params.winKey)
    end
end)

urlEvent.bind("dismissvisiblepending", function()
    dismissVisiblePending()
end)

urlEvent.bind("dismissallnotify", function()
    dismissAllNotify()
end)
