local M = {}

local list = {
    gameover = false,
    score = 0,
    dropper_active = true,
}

function M.check(key)
    return list[key]
end

function M.set(key, value)
    list[key] = value
end

return M
