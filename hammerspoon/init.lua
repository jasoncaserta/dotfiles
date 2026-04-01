hs.ipc.cliInstall()

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

local function updateActiveWinKey()
    local client, _ = hs.execute(tmuxBin .. " list-clients -F '#{client_activity} #{client_name}' | sort -rn | head -1 | awk '{print $2}'")
    client = shellSanitize(client:gsub("%s+$", ""))
    if client == "" then activeWinKey = nil; return end
    local winId, _ = hs.execute(tmuxBin .. " display-message -c '" .. client .. "' -p '#{window_id}' 2>/dev/null")
    winId = winId:gsub("%s+$", "")
    activeWinKey = winId ~= "" and extractWinKey(winId) or nil
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
    local n = pendingNotifications[winKey]
    if n then
        n:withdraw()
        pendingNotifications[winKey] = nil
    end
end

-- Dismiss all pending notifications (e.g. on tmux detach)
function dismissAllNotify()
    for k, n in pairs(pendingNotifications) do
        n:withdraw()
        pendingNotifications[k] = nil
    end
end

local function hasPendingNotifications()
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
    if not hasPendingNotifications() then return false end
    hs.timer.doAfter(0.075, function()
        updateActiveWinKey()
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
    elseif event == hs.application.watcher.deactivated then
        keyTap:stop()
        clickTap:stop()
    end
end)
ghosttyWatcher:start()

-- If Ghostty is already frontmost when this config loads, start the watchers immediately
if hs.application.frontmostApplication():name() == "Ghostty" then
    updateActiveWinKey()
    keyTap:start()
    clickTap:start()
end

-- Notification helper called from ~/.notify.sh via:
--   hs -c "showNotify('title', 'message', 'windowId')"
function showNotify(title, message, windowId)
    local winKey = "__bare__"
    if windowId and windowId ~= "" then
        winKey = extractWinKey(windowId)
    end
    local n = hs.notify.new(function()
        pendingNotifications[winKey] = nil
        hs.application.launchOrFocus("Ghostty")
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
