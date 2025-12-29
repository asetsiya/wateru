local M = {}

local online_balls = {}

function M.add_ball(ball)
    table.insert(online_balls, ball)
end

function M.remove_ball(ball)
    for i = #online_balls, 1, -1 do
        if online_balls[i] == ball then
            table.remove(online_balls, i)
            break
        end
    end
end

function M.get()
    return online_balls
end

function M.reset()
    online_balls = {}
end

return M
