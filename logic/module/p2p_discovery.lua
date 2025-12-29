---@diagnostic disable: need-check-nil, undefined-field, undefined-global
--- Module to perform peer-to-peer discovery
local M = {}

local STATE_DISCONNECTED = "STATE_DISCONNECTED"
local STATE_ACTIVE = "STATE_ACTIVE"

local function starts_with(str, start)
    if str == nil or start == nil then return false end
    return str:sub(1, #start) == start
end

-- Subnet broadcast IP
local function get_broadcast_ip(ip)
    if not ip then return "255.255.255.255" end
    
    -- 192.168.x.y -> 192.168.x.255
    local parts = {}
    for part in string.gmatch(ip, "(%d+)") do
        table.insert(parts, tonumber(part))
    end
    
    if #parts == 4 then
        return string.format("%d.%d.%d.255", parts[1], parts[2], parts[3])
    end
    
    return "255.255.255.255"
end

function M.get_ip()
    local wifi_ip = nil
    local fallback_ip = nil
    
    for _, network_card in pairs(sys.get_ifaddrs()) do
        if network_card.up and network_card.address then
            local ip = network_card.address
            
            -- Skip loopback
            if ip ~= "127.0.0.1" then
                -- Prioritize common Wi-Fi ranges (including Wifi Direct)
                if ip:match("^192%.168%.") then
                    -- 192.168.x.x - includes Wifi Direct (192.168.49.x)
                    wifi_ip = ip
                    break
                elseif ip:match("^10%.0%.") or ip:match("^172%.16%.") then
                    -- Other private ranges
                    if not wifi_ip then
                        wifi_ip = ip
                    end
                elseif not fallback_ip then
                    -- Store any other valid IP as fallback
                    fallback_ip = ip
                end
            end
        end
    end
    
    local selected_ip = wifi_ip or fallback_ip
    if selected_ip then
        print("Selected IP for P2P:", selected_ip)
        return selected_ip
    end
    
    print("Warning: No suitable IP address found")
    return nil
end

--- Create a peer to peer discovery instance
function M.create(port)
    local instance = {}
    local state = STATE_DISCONNECTED
    port = port or 50000
    
    local listen_co
    local broadcast_co
    local last_broadcast_time = 0
    local broadcast_interval = 1.0
    
    local broadcaster
    local listener
    local local_ip
    local broadcast_ip
    
    --- Start both broadcasting and listening simultaneously
    function instance.start(broadcast_message, listen_message, callback)
        assert(broadcast_message, "You must provide a message to broadcast")
        assert(listen_message, "You must provide a message to listen for")
        assert(callback, "You must provide a callback function")
        
        -- Get local IP
        local_ip = M.get_ip()
        if not local_ip then
            return false, "No valid IP address found"
        end
        
        -- Calculate broadcast IP for subnet
        broadcast_ip = get_broadcast_ip(local_ip)
        print("Using broadcast IP:", broadcast_ip)
        
        -- Setup broadcaster
        local broadcast_ok, broadcast_err = pcall(function()
            broadcaster = socket.udp()
            assert(broadcaster:setsockname("*", 0))
            assert(broadcaster:setoption("broadcast", true))
            assert(broadcaster:setoption("dontroute", false))
            assert(broadcaster:settimeout(0))
        end)
        
        if not broadcast_ok or not broadcaster then
            print("Broadcaster Error:", broadcast_err)
            return false, broadcast_err
        end
        
        -- Setup listener
        local listen_ok, listen_err = pcall(function()
            listener = socket.udp()
            assert(listener:setsockname("*", port))
            assert(listener:setoption("reuseaddr", true))
            assert(listener:settimeout(0))
        end)
        
        if not listen_ok or not listener then
            print("Listener Error:", listen_err)
            if broadcaster then broadcaster:close() end
            return false, listen_err
        end
        
        print("Starting P2P discovery - Broadcasting: '" .. broadcast_message .. "' Listening for: '" .. listen_message .. "' on port " .. port)
        
        state = STATE_ACTIVE
        last_broadcast_time = socket.gettime()
        
        -- Create broadcast coroutine
        broadcast_co = coroutine.create(function()
            while state == STATE_ACTIVE do
                local current_time = socket.gettime()
                if current_time - last_broadcast_time >= broadcast_interval then
                    local ok, err = pcall(function()
                        broadcaster:sendto(broadcast_message, broadcast_ip, port)
                        
                        if not broadcast_ip:match("^192%.168%.49%.") then
                            broadcaster:sendto(broadcast_message, "192.168.49.255", port)
                        end
                        if not broadcast_ip:match("^192%.168%.43%.") then
                            -- Hotspot subnet
                            broadcaster:sendto(broadcast_message, "192.168.43.255", port)
                        end
                    end)
                    if err then
                        print("Broadcast error:", err)
                        state = STATE_DISCONNECTED
                    else
                        last_broadcast_time = current_time
                    end
                end
                coroutine.yield()
            end
        end)
        
        -- Create listen coroutine
        listen_co = coroutine.create(function()
            while state == STATE_ACTIVE do
                local data, peer_ip, peer_port = listener:receivefrom()
                if data and starts_with(data, listen_message) then
                    -- Filter out own broadcasts
                    if peer_ip ~= local_ip and peer_ip ~= "127.0.0.1" then
                        local payload = data:sub(#listen_message + 1)
                        print("P2P peer discovered from " .. peer_ip .. ":" .. peer_port .. " - payload: '" .. payload .. "'")
                        callback(peer_ip, peer_port, payload)
                    end
                end
                coroutine.yield()
            end
        end)
        
        -- Start both coroutines
        local broadcast_start = coroutine.resume(broadcast_co)
        local listen_start = coroutine.resume(listen_co)
        
        return broadcast_start and listen_start, nil
    end
    
    --- Legacy broadcast function (for backward compatibility)
    function instance.broadcast(message)
        return instance.start(message, message, function(ip, port, data)
            print("Discovered peer:", ip, port, data)
        end)
    end
    
    --- Legacy listen function (for backward compatibility)
    function instance.listen(message, callback)
        return instance.start("PEER_DISCOVERY", message, callback)
    end
    
    --- Stop broadcasting and listening
    function instance.stop()
        state = STATE_DISCONNECTED
        
        if broadcaster then
            broadcaster:close()
            broadcaster = nil
        end
        
        if listener then
            listener:close()
            listener = nil
        end
        
        broadcast_co = nil
        listen_co = nil
        
        print("P2P discovery stopped")
    end
    
    --- Check if currently active
    function instance.is_active()
        return state == STATE_ACTIVE
    end
    
    --- Update function - call this every frame
    function instance.update()
        if state == STATE_ACTIVE then
            -- Resume broadcast coroutine
            if broadcast_co and coroutine.status(broadcast_co) == "suspended" then
                coroutine.resume(broadcast_co)
            end
            
            -- Resume listen coroutine
            if listen_co and coroutine.status(listen_co) == "suspended" then
                coroutine.resume(listen_co)
            end
            
            -- Check if coroutines are dead
            if broadcast_co and coroutine.status(broadcast_co) == "dead" then
                broadcast_co = nil
            end
            if listen_co and coroutine.status(listen_co) == "dead" then
                listen_co = nil
            end
            
            -- If both coroutines are dead, stop
            if not broadcast_co and not listen_co then
                instance.stop()
            end
        end
    end
    
    return instance
end

return M