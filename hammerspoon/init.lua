hs.ipc.cliInstall()

-- Notification helper called from ~/.notify.sh via:
--   hs -c "showNotify('title', 'message', 'windowId')"
function showNotify(title, message, windowId)
    local n = hs.notify.new(function()
        hs.application.launchOrFocus("Ghostty")
        if windowId and windowId ~= "" then
            hs.timer.doAfter(0.2, function()
                local tmux = "/usr/bin/tmux"
                for _, p in ipairs({"/opt/homebrew/bin/tmux", "/usr/local/bin/tmux"}) do
                    if hs.fs.attributes(p) then tmux = p; break end
                end
                local client, _ = hs.execute(tmux .. " list-clients -F '#{client_activity} #{client_name}' | sort -rn | head -1 | awk '{print $2}'")
                client = client:gsub("%s+$", "")
                hs.execute(tmux .. " switch-client -c '" .. client .. "' -t '" .. windowId .. "' 2>/dev/null")
            end)
        end
    end, {
        title = title,
        informativeText = message,
        soundName = "Glass",
        hasActionButton = false,
    })
    n:send()
end
