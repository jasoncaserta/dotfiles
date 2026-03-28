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
