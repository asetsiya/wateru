local M = {}

local current_proxy = nil
local pending_load = nil

function M.switch(from_proxy, to_proxy)
    if from_proxy then
        pending_load = to_proxy
        msg.post(from_proxy, "unload")
    else
        msg.post(to_proxy, "load")
        current_proxy = to_proxy
    end
end

function M.load(proxy_url)
    msg.post(proxy_url, "load")
    current_proxy = proxy_url
end

function M.unload(proxy_url)
    msg.post(proxy_url, "unload")
    if current_proxy == proxy_url then
        current_proxy = nil
    end
end

function M.handle_message(message_id, message, sender)
    if message_id == hash("proxy_loaded") then
        msg.post(sender, "enable")
    elseif message_id == hash("proxy_unloaded") then
        if pending_load then
            msg.post(pending_load, "load")
            current_proxy = pending_load
            pending_load = nil
        end
    end
end

return M