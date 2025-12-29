
local saver = require("logic.module.saver")

local M = {}

local prices = {
    "price_boom",
}
-- prices
if not saver.load().price_boom then
    saver.save("price_boom", 150)
end

function M.update()
    for _, value in ipairs(prices) do
        msg.post("gui", "change_text", {node = "node_"..value, text = saver.load()[value]})
    end
end

return M