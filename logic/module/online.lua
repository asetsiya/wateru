local p2p_discovery = require("logic.module.p2p_discovery")
local udp = require("logic.module.udp")

local M = {}

-- constants
local P2P_PORT = 5848
local UDP_PORT = 5849
local ACK_TIMEOUT = 2.0
local MAX_RETRIES = 3
local PING_INTERVAL = 3.0  -- send ping every 3 seconds
local PING_TIMEOUT = 6.0   -- mark disconnected if no pong in 6 seconds

-- variables
local p2p = nil
local udp_server = nil
local udp_clients = {}
local udp_connections = {}
local connection_status = {} -- {ip = {status="connected", last_pong=time, ping_timer=handle}}
local message_handler = nil
local disconnect_callback = nil
local message_id_counter = 1
local pending_acks = {}

-- parse incoming message
local function parse_message(data)
    local parts = {}
    for part in string.gmatch(data, "([^|]+)") do
        table.insert(parts, part)
    end
    if #parts < 2 then return nil end
    local msg_type = parts[1]
    local msg_id = tonumber(parts[2])

    if msg_type == "ack" then
        return { type = "ack", msg_id = msg_id }
    elseif (msg_type == "req_ack" or msg_type == "no_ack") and #parts >= 3 then
        return { type = msg_type, msg_id = msg_id, content = table.concat(parts, "|", 3) }
    end
    return nil
end

-- create outgoing message
local function create_message(content, require_ack)
    local msg_type = require_ack and "req_ack" or "no_ack"
    local msg_id = message_id_counter
    message_id_counter = message_id_counter + 1
    return string.format("%s|%d|%s", msg_type, msg_id, content), msg_id
end

-- send ping to a peer
local function send_ping(ip)
    local connection = udp_connections[ip]
    if connection then
        local ping_msg = create_message("ping", false)
        connection.send(ping_msg)
    end
end

-- check if connection to a peer is still alive
local function check_connection_status(ip)
    local status = connection_status[ip]
    if not status then return end
    local current_time = socket.gettime()
    if current_time - status.last_pong > PING_TIMEOUT then
        if status.status == "connected" then
            status.status = "disconnected"
            print("connection lost:", ip)
            if disconnect_callback then
                disconnect_callback(ip)
            end
        end
    end
end

-- start ping loop for a peer
local function start_ping_loop(ip)
    local function ping_loop()
        if not connection_status[ip] then return end
        send_ping(ip)
        check_connection_status(ip)
        connection_status[ip].ping_timer = timer.delay(PING_INTERVAL, false, ping_loop)
    end
    ping_loop()
end

-- handle incoming udp data
local function handle_incoming_udp(data, ip, port)
    local parsed = parse_message(data)
    if not parsed then return end

    if parsed.type == "ack" then
        local pending = pending_acks[parsed.msg_id]
        if pending then
            if pending.timer_handle then timer.cancel(pending.timer_handle) end
            pending_acks[parsed.msg_id] = nil
            if pending.success_callback then pending.success_callback() end
        end
    elseif parsed.content == "ping" then
        local connection = udp_connections[ip]
        if connection then
            local pong_msg = create_message("pong", false)
            connection.send(pong_msg)
        end
    elseif parsed.content == "pong" then
        local status = connection_status[ip]
        if status then
            status.last_pong = socket.gettime()
            if status.status == "disconnected" then
                status.status = "connected"
                print("connection restored:", ip)
            end
        end
    elseif parsed.type == "req_ack" then
        local connection = udp_connections[ip]
        if connection then
            local ack_msg = string.format("ack|%d", parsed.msg_id)
            connection.send(ack_msg)
        end
        if message_handler and parsed.content ~= "ping" and parsed.content ~= "pong" then
            message_handler(parsed.content, ip, port)
        end
    elseif parsed.type == "no_ack" then
        if message_handler and parsed.content ~= "ping" and parsed.content ~= "pong" then
            message_handler(parsed.content, ip, port)
        end
    end
end

-- public functions
function M.get_ip()
    return p2p_discovery.get_ip()
end

function M.p2p_start(broadcast_message, listen_message, callback)
    if not p2p then
        p2p = p2p_discovery.create(P2P_PORT)
    end
    p2p.start(broadcast_message, listen_message, callback)
end

function M.p2p_stop()
    if p2p then
        p2p.stop()
    end
end

function M.start_listening(handler_function, disconnect_handler)
    if udp_server then
        print("udp already listening")
        return udp_server
    end
    message_handler = handler_function
    disconnect_callback = disconnect_handler
    udp_server = udp.create(handle_incoming_udp, UDP_PORT)
    return udp_server
end

function M.connect_to_peer(ip, callback)
    if udp_connections[ip] then
        if callback then callback(true, ip) end
        return udp_connections[ip]
    end
    local client = udp.create(handle_incoming_udp, nil, ip, UDP_PORT)
    if client then
        udp_connections[ip] = client
        table.insert(udp_clients, client)
        connection_status[ip] = { status = "connected", last_pong = socket.gettime(), ping_timer = nil }
        start_ping_loop(ip)
        if callback then callback(true, ip) end
        return client
    else
        if callback then callback(false, ip) end
        return nil
    end
end

function M.send_message(target_ip, message, require_ack, success_callback, fail_callback)
    local connection = udp_connections[target_ip]
    if not connection then
        if fail_callback then fail_callback("no connection: " .. target_ip) end
        return false
    end
    local formatted_msg, msg_id = create_message(message, require_ack)
    if require_ack then
        local retry_count = 0
        local function send_with_retry()
            retry_count = retry_count + 1
            connection.send(formatted_msg)
            if retry_count >= MAX_RETRIES then
                pending_acks[msg_id] = nil
                if fail_callback then fail_callback("max retries reached") end
                return
            end
            local timer_handle = timer.delay(ACK_TIMEOUT, false, send_with_retry)
            pending_acks[msg_id] = { success_callback = success_callback, fail_callback = fail_callback, retry_count = retry_count, timer_handle = timer_handle }
        end
        send_with_retry()
    else
        connection.send(formatted_msg)
        if success_callback then success_callback() end
    end
    return true
end

-- handler_function(message, ip, port)
function M.set_message_handler(handler_function)
    message_handler = handler_function
end

function M.update()
    if p2p then p2p.update() end
    if udp_server then udp_server.update() end
    for i = 1, #udp_clients do
        if udp_clients[i] then udp_clients[i].update() end
    end
end

function M.stop()
    for _, pending in pairs(pending_acks) do
        if pending.timer_handle then timer.cancel(pending.timer_handle) end
    end
    pending_acks = {}
    for _, status in pairs(connection_status) do
        if status.ping_timer then timer.cancel(status.ping_timer) end
    end
    connection_status = {}
    if p2p then p2p.stop(); p2p = nil end
    if udp_server then udp_server.destroy(); udp_server = nil end
    for i = 1, #udp_clients do
        if udp_clients[i] then udp_clients[i].destroy() end
    end
    udp_clients = {}
    udp_connections = {}
    message_handler = nil
    disconnect_callback = nil
    message_id_counter = 1
end

function M.get_connected_peers()
    local peers = {}
    for ip in pairs(udp_connections) do
        table.insert(peers, ip)
    end
    return peers
end

function M.get_connection_status(ip)
    local status = connection_status[ip]
    return status and status.status or "not_connected"
end

function M.disconnect_peer(ip)
    local connection = udp_connections[ip]
    if connection then
        connection.destroy()
        udp_connections[ip] = nil
        for i = #udp_clients, 1, -1 do
            if udp_clients[i] == connection then
                table.remove(udp_clients, i)
                break
            end
        end
    end
    local status = connection_status[ip]
    if status and status.ping_timer then timer.cancel(status.ping_timer) end
    connection_status[ip] = nil
end

return M
