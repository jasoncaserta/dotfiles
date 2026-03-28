hs.ipc.cliInstall()

local pendingNotifications = {}

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

-- Key watcher: on first keystroke in Ghostty, dismiss the active tmux window's notification.
-- Only active while Ghostty is the frontmost app (started/stopped by ghosttyWatcher).
local keyTap = hs.eventtap.new({hs.eventtap.event.types.keyDown}, function(_event)
    local hasPending = false
    for _ in pairs(pendingNotifications) do hasPending = true; break end
    if not hasPending then return false end
    local tmux = "/usr/bin/tmux"
    for _, p in ipairs({"/opt/homebrew/bin/tmux", "/usr/local/bin/tmux"}) do
        if hs.fs.attributes(p) then tmux = p; break end
    end
    local client, _ = hs.execute(tmux .. " list-clients -F '#{client_activity} #{client_name}' | sort -rn | head -1 | awk '{print $2}'")
    client = client:gsub("%s+$", "")
    if client == "" then return false end
    local winId, _ = hs.execute(tmux .. " display-message -c '" .. client .. "' -p '#{window_id}' 2>/dev/null")
    winId = winId:gsub("%s+$", "")
    if winId == "" then return false end
    local winKey = winId:match("(@%w+)$") or winId
    if pendingNotifications[winKey] then
        dismissNotify(winKey)
        hs.execute(tmux .. " set-option -wuq -t '" .. winKey .. "' @needs_attention 2>/dev/null; " .. tmux .. " refresh-client -S 2>/dev/null")
    end
    return false
end)

-- App watcher: dismiss active window's notification when Ghostty gains focus;
-- start/stop keyTap so it only runs while Ghostty is in front.
local ghosttyWatcher = hs.application.watcher.new(function(name, event, _app)
    if name ~= "Ghostty" then return end
    if event == hs.application.watcher.activated then
        local tmux = "/usr/bin/tmux"
        for _, p in ipairs({"/opt/homebrew/bin/tmux", "/usr/local/bin/tmux"}) do
            if hs.fs.attributes(p) then tmux = p; break end
        end
        local client, _ = hs.execute(tmux .. " list-clients -F '#{client_activity} #{client_name}' | sort -rn | head -1 | awk '{print $2}'")
        client = client:gsub("%s+$", "")
        if client ~= "" then
            local winId, _ = hs.execute(tmux .. " display-message -c '" .. client .. "' -p '#{window_id}' 2>/dev/null")
            winId = winId:gsub("%s+$", "")
            if winId ~= "" then
                local winKey = winId:match("(@%w+)$") or winId
                if pendingNotifications[winKey] then
                    dismissNotify(winKey)
                    hs.execute(tmux .. " set-option -wuq -t '" .. winKey .. "' @needs_attention 2>/dev/null; " .. tmux .. " refresh-client -S 2>/dev/null")
                end
            end
        end
        keyTap:start()
    elseif event == hs.application.watcher.deactivated then
        keyTap:stop()
    end
end)
ghosttyWatcher:start()

-- If Ghostty is already frontmost when this config loads, start the key watcher immediately
if hs.application.frontmostApplication():name() == "Ghostty" then
    keyTap:start()
end

-- Notification helper called from ~/.notify.sh via:
--   hs -c "showNotify('title', 'message', 'windowId')"
function showNotify(title, message, windowId)
    local winKey = ""
    if windowId and windowId ~= "" then
        winKey = windowId:match("(@%w+)$") or windowId
    end
    local n = hs.notify.new(function()
        if winKey ~= "" then
            pendingNotifications[winKey] = nil
        end
        hs.application.launchOrFocus("Ghostty")
        if windowId and windowId ~= "" then
            hs.timer.doAfter(0.2, function()
                local tmux = "/usr/bin/tmux"
                for _, p in ipairs({"/opt/homebrew/bin/tmux", "/usr/local/bin/tmux"}) do
                    if hs.fs.attributes(p) then tmux = p; break end
                end
                local client, _ = hs.execute(tmux .. " list-clients -F '#{client_activity} #{client_name}' | sort -rn | head -1 | awk '{print $2}'")
                client = client:gsub("%s+$", "")
                if client ~= "" then
                    hs.execute(tmux .. " switch-client -c '" .. client .. "' -t '" .. windowId .. "' 2>/dev/null")
                end
                if winKey ~= "" then
                    hs.execute(tmux .. " set-option -wuq -t '" .. winKey .. "' @needs_attention 2>/dev/null; " .. tmux .. " refresh-client -S 2>/dev/null")
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
    if winKey ~= "" then
        if pendingNotifications[winKey] then
            pendingNotifications[winKey]:withdraw()
        end
        pendingNotifications[winKey] = n
    end
    n:send()
end
