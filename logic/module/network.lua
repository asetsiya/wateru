---@diagnostic disable: need-check-nil
local M = {}

local saver = require("logic.module.saver")
local reg = require("logic.module.reg")
local prices = require("logic.module.prices")

local timer_url = "supabase_url"
local database_url = "supabase_url"
local update_url =
"supabase_url"
local price_url = "supabase_url"
local price_parameter = "?select=name,value"
local database_parameter = "?select=user_id,username,highscore,highscore_fix"
local register_url = "supabase_url"
local login_url = "supabase_url"
local api_key =
"supabase_api_key" -- i know this is wrong. but rls is active, no problem. i hope.

local is_android = sys.get_sys_info().system_name == "Android" and true or false
local game_name = "wateru" -- very important information for database sync

local function write_first_row(email, pass)
    if (not saver.load().password) or (not is_android) then -- if not logged in correctly, if not in android skip.
        print("not logged in correctly! (write first row)"); return
    end
    local function database_callback(self, id, response)
        --local response = json.decode(response.response)
        if response.status >= 200 and response.status <= 299 then
            print("HTTP Success, first row writed", response.status)
            saver.save("is_first_row_exists", true)
            M.read()
        else
            print("HTTP Error:(first row)", response.status, response.error)
        end
    end

    local headers = {
        ["Content-Type"] = "application/json",
        ["apikey"] = api_key,
        ["Authorization"] = "Bearer " .. saver.load().jwt_key
    }
    local post_data = json.encode({
        user_id = saver.load().user_id,
        device = is_android and (sys.get_sys_info().manufacturer .. " " .. sys.get_sys_info().device_model) or "not_android",
        username = saver.load().username,
        highscore = saver.load().highscore or 0,
        tricks = saver.load().timer_tricks or 0,
        online = saver.load().online_timer or 0,
        online_modes = json.encode(saver.load().online_modes_timer) or "",
        rival_names = json.encode(saver.load().rival_names_timer) or "",
        last_enter = saver.load().last_enter,
        email = email,
        pass = pass,
        game = game_name,
    })
    http.request(
        database_url,
        "POST",
        database_callback,
        headers,
        post_data
    )
end

local function write_timer(should_update, should_write_first_row, email, password)
    print("timer writing")
    if (not saver.load().password) then
        print("not logged in correctly! (write timer)"); return
    end -- if not logged in correctly, skip.
    local function database_callback(self, id, response)
        --local response = json.decode(response.response)
        if response.status >= 200 and response.status <= 299 then
            print("HTTP Success, (write timer)", response.status)
            if should_update then M.update() end -- if the update is requested, update.
            if should_write_first_row then write_first_row(email, password) end
        else
            print("HTTP Error:(write timer)", response.status, response.error)
        end
    end

    local headers = {
        ["Content-Type"] = "application/json",
        ["apikey"] = api_key,
        ["Authorization"] = "Bearer " .. saver.load().jwt_key
    }
    local post_data = json.encode({
        username = saver.load().username or "username",
        date = saver.load().last_enter,
        time = 0,
        total = saver.load().minute_log,
        highscore = saver.load().highscore or 0,
        device = is_android and (sys.get_sys_info().manufacturer .. " " .. sys.get_sys_info().device_model) or "not_android",
        game = game_name,
    })
    http.request(
        timer_url,
        "POST",
        database_callback,
        headers,
        post_data
    )
end

-- action:"register" or "login"
local function auth(action, username, email, password)
    -- callback function for auth
    local function auth_callback(self, id, response)
        if response.status >= 200 and response.status <= 299 then -- if request success
            local auth_data = json.decode(response.response)
            if auth_data.access_token then
                print("JWT Token:", auth_data.access_token)
                print("User ID:", auth_data.user.id)
                saver.save("jwt_key", auth_data.access_token)
                saver.save("user_id", auth_data.user.id)
                if username then saver.save("username", username) end
                print("pass", password)
                saver.save("password", password)
                print("email", email)
                saver.save("email", email)
                msg.post("gui", "login_success")
                if action == "register" then
                    write_timer(false, true, email, password) -- registered. so let's write the first row. (timer will do it)
                else
                    write_timer(true)                         -- timer function will start the update.
                end
            else
                print("Register Error:", auth_data.msg)
            end
        else
            print("HTTP Error:", response.status, response.error)
            pprint(response)
        end
    end

    -- register and login function. only difference is the url
    local headers = {
        ["Content-Type"] = "application/json",
        ["apikey"] = api_key
    }

    local post_data = json.encode({
        email = email,
        password = password
    })

    http.request(
        action == "register" and register_url or login_url, -- set register or login url
        "POST",
        auth_callback,
        headers,
        post_data
    )
end

local is_highscore_fix_reset = false
local should_highscore_write = false
local update_called = false

local function handle_database(score_data)
    table.sort(score_data, function(a, b)
        if type(a.highscore) ~= "number" or type(b.highscore) ~= "number" then
            return false
        end
        return a.highscore > b.highscore -- sort from highest to lowest
    end)

    local rank = 1
    local previous_score = nil

    for i, user in ipairs(score_data) do
        if previous_score ~= user.highscore then
            rank = i -- update rank if the score changes
            previous_score = user.highscore
        end
        user.rank = rank -- add rank to the user
    end

    for _, value in ipairs(score_data) do
        if saver.load().user_id == value.user_id then
            -- username finder
            saver.save("username", value.username)
            print("username found.", value.username)
            -- highscore_fix finder
            if value.highscore_fix and value.highscore_fix > 0 then
                saver.save("highscore", value.highscore_fix)
                print("highscore_fix found", value.highscore_fix)
                msg.post("gui", "update_highscore")
                if not is_highscore_fix_reset then
                    is_highscore_fix_reset = true
                    M.update(true)
                end
                -- highscore finder
            elseif value.highscore > 0 then
                if not saver.load().highscore or saver.load().highscore < value.highscore then
                    print("highscore found:", value.highscore)
                    saver.save("highscore", value.highscore)
                    msg.post("gui", "update_highscore")
                end
            end
            break
        end
        should_highscore_write = true                            -- set the variable, for highscore update on the server.
        if not is_highscore_fix_reset and not update_called then -- block the infinity loop.
            M.update()
            update_called = true
        end
    end

    saver.save("score_data", score_data)
    msg.post("gui", "updated")
end

local function handle_update(response)
    if not response[1] then return end -- nil check
    local current_version = tonumber(string.sub(saver.load().version, 2))
    local latest_version = tonumber(response[1].ver)
    local url = response[1].url
    if current_version < latest_version then
        print("update found", current_version, latest_version)
        reg.set("url", url)
        reg.set("current_version", current_version)
        reg.set("latest_version", latest_version)
        msg.post("gui", "update_found")
    end
end

local function check_update()
    if saver.load().boomer_mode then return end -- if boomer_mode activated, skip the update
    local function database_callback(self, id, response)
        if response.status >= 200 and response.status <= 299 then
            print("HTTP Success!(check_update)", response.status)
            handle_update(json.decode(response.response))
        else
            print("HTTP Error:(check_update)", response.status, response.error)
        end
    end

    local headers = {
        ["Content-Type"] = "application/json",
        ["apikey"] = api_key,
        --["Authorization"] = "Bearer " .. saver.load().jwt_key
    }

    http.request(
        update_url,
        "GET",
        database_callback,
        headers
    )
end

local function handle_price(response)
    --pprint("FF24F482",response)
    for _, row in ipairs(response) do
        if row.name == "price_boom" then
            print("price_boom:", row.value)
            saver.save("price_boom", row.value)
        end
    end
end

local function price_read()
    local function database_callback(self, id, response)
        --local response = json.decode(response.response)
        if response.status >= 200 and response.status <= 299 then
            print("HTTP Success!(price_read)", response.status)
            handle_price(json.decode(response.response))
            prices.update()
        else
            print("HTTP Error:(read)", response.status, response.error)
            pprint(response)
        end
    end

    local headers = {
        ["Content-Type"] = "application/json",
        ["apikey"] = api_key,
        --["Authorization"] = "Bearer " .. saver.load().jwt_key
    }

    http.request(
        price_url .. "?game=eq." .. game_name,
        "GET",
        database_callback,
        headers
    )
end

function M.register(username, email, password)
    auth("register", username, email, password)
end

function M.login(email, password)
    auth("login", nil, email, password)
end

function M.update(should_highscore_fix_reset)
    if (not saver.load().password) then -- if not logged in correctly, if not in android skip.
        print("not logged in correctly! (update)")
        return
    end
    local function database_callback(self, id, response)
        --local response = json.decode(response.response)
        if response.status >= 200 and response.status <= 299 then
            print("HTTP Success!(update)", response.status)
            M.read()
        else
            print("HTTP Error:(update)", response.status, pprint(response))
        end
    end

    local headers = {
        ["Content-Type"] = "application/json",
        ["apikey"] = api_key,
        ["Authorization"] = "Bearer " .. saver.load().jwt_key
    }
    local post_data = json.encode({
        user_id = saver.load().user_id,
        device = is_android and (sys.get_sys_info().manufacturer .. " " .. sys.get_sys_info().device_model) or "not_android",
        --username = saver.load().username, -- no need for update
        highscore = should_highscore_write and (saver.load().highscore or 0) or nil, -- first, "read" needed
        highscore_fix = should_highscore_fix_reset and 0 or nil,
        tricks = saver.load().timer_tricks or 0,
        online = saver.load().online_timer or 0,
        online_modes = json.encode(saver.load().online_modes_timer) or "",
        rival_names = json.encode(saver.load().rival_names_timer) or "",
        last_enter = saver.load().last_enter,
        ver = saver.load().version or "0"
    })
    http.request(
        database_url .. "?user_id=eq." .. saver.load().user_id .. "&game=eq." .. game_name,
        "PATCH",
        database_callback,
        headers,
        post_data
    )
end

function M.read()
    local function database_callback(self, id, response)
        --local response = json.decode(response.response)
        if response.status >= 200 and response.status <= 299 then
            print("HTTP Success!(read)", response.status)
            check_update() -- check update
            price_read()
            handle_database(json.decode(response.response))
        else
            print("HTTP Error:(read)", response.status, response.error)
            pprint(response)
        end
    end

    local headers = {
        ["Content-Type"] = "application/json",
        ["apikey"] = api_key,
        --["Authorization"] = "Bearer " .. saver.load().jwt_key
    }

    http.request(
        database_url .. database_parameter .. "&game=eq." .. game_name,
        "GET",
        database_callback,
        headers
    )
end

function M.timer_update()
    --if (not saver.load().password) then
    --    print("not logged in correctly! (timer_update)")
    --    return
    --end
    local function database_callback(self, id, response)
        --local response = json.decode(response.response)
        if response.status >= 200 and response.status <= 299 then
            print("HTTP Success!(timer_update)", response.status)
        else
            print("HTTP Error:(timer_update)", response.status, response.error)
        end
    end

    local headers = {
        ["Content-Type"] = "application/json",
        ["apikey"] = api_key,
        --["Authorization"] = "Bearer " .. saver.load().jwt_key
    }
    local post_data = json.encode({
        --username = saver.load().username or "username",
        --date = saver.load().last_enter,
        time = reg.check("last_time"),
        total = saver.load().minute_log,
        highscore = saver.load().highscore or 0,
    })
    http.request(
        timer_url .. "?date=eq." .. saver.load().last_enter,
        "PATCH",
        database_callback,
        headers,
        post_data
    )
end

function M.write_fugitive()
    --print("fugitive writing")
    local function database_callback(self, id, response)
        --local response = json.decode(response.response)
        if response.status >= 200 and response.status <= 299 then
            print("HTTP Success, (fugitive writing)", response.status)
        else
            print("HTTP Error:(fugitive writing)", response.status, response.error)
            pprint(response)
        end
    end
    local headers = {
        ["Content-Type"] = "application/json",
        ["apikey"] = api_key,
        --["Authorization"] = "Bearer " .. saver.load().jwt_key
    }
    local post_data = json.encode({
        username = "0afugitive",
        date = saver.load().last_enter,
        time = 0,
        total = saver.load().minute_log,
        highscore = saver.load().highscore or 0,
        device = is_android and (sys.get_sys_info().manufacturer .. " " .. sys.get_sys_info().device_model) or "not_android",
        game = game_name,
    })
    http.request(
        timer_url,
        "POST",
        database_callback,
        headers,
        post_data
    )
end

return M
