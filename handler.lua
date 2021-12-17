local handler = {}
handler.__index = handler

local wf = require("hs.window.filter")
local layout = require("i3.layout")

function handler.new()
    local w = setmetatable({}, handler)
    w.selectedLayout = nil
    w.screen = hs.screen.mainScreen()
    w.wf = wf.new():subscribe(wf.windowCreated, function(win)
        if win:isVisible() then
            if (w.selectedLayout) then
                w.selectedLayout:split(win)
            else
                w.rootLayout:split(win)
            end
        end
        w:draw()
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
    self.rootLayout = layout.empty(self)
end

function handler:draw()
    self.rootLayout:draw(self.screen)
end

return handler
