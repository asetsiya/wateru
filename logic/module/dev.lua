local saver = require("logic.module.saver")

local M = {}

saver.save("boomer_mode", false)

local dev_code_string = "0000"

function M.code(code)
    dev_code_string = string.sub(dev_code_string, 2, 4) .. tostring(code)
    if dev_code_string == "1312" then
        msg.post("detector", "gameover")
        print("1312 gameover triggered")
    elseif dev_code_string == "2313" then
        saver.save("boomer_mode", true)
        print("2313 boomer_mode true triggered")
    elseif dev_code_string == "2312" then
        saver.save("boomer_mode", false)
        print("2312 boomer_mode false triggered")
    end
end

return M