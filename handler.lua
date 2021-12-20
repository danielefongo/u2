local handler = {}
handler.__index = handler

local wf = require("hs.window.filter")
local layout = require("i3.layout")

function handler.new()
    local w = setmetatable({}, handler)
    w.selectedLayout = nil
    w.screen = hs.screen.mainScreen()
    w.wf = wf.new(function(win)
        return win:isStandard() and win:role() ~= "AXScrollArea"
    end):subscribe(wf.windowCreated, function(win)
        w:selected():split(win)
    end)
    return w
end

function handler:setFocusedLayout(layout)
    self.selectedLayout = layout
end

function handler:noFocusedLayout()
    self.selectedLayout = nil
end

function handler:setRoot()
    self.rootLayout = layout.empty(self.screen, self)
end

function handler:draw()
    self.rootLayout:draw()
end

function handler:focus()
    self.rootLayout:focus()
end

return handler
