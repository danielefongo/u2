local handler = require("i3.handler")
local layout = require("i3.layout")

mainHandler = handler.new()

hs.hotkey.bind({"cmd", "alt", "ctrl"}, ",", function()
    mainHandler:setRoot()
end)
