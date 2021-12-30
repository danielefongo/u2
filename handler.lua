local handler = {}
handler.__index = handler

local wf = require("hs.window.filter")
local layout = require("i3.layout")
local BORDER = {
    type = "rectangle",
    action = "stroke",
    strokeWidth = 5.0,
    strokeColor = {
        white = 1.0
    }
}

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
    self:removeHighlight()
    self.selectedLayout = layout
    self:highlight()
end

function handler:noFocusedLayout()
    self:removeHighlight()
    self.selectedLayout = nil
end

function handler:setRoot()
    self.rootLayout = layout.empty(self.screen, self)
end

function handler:draw()
    self:removeHighlight()
    self.rootLayout:draw()
    self:highlight()
end

function handler:highlight()
    self:removeHighlight()
    if not self:selected() then
        return
    end
    if self:selected():isRoot() then
        return
    end

    local geo = hs.geometry.new(self:selected().unit):fromUnitRect(self.screen:frame()):floor()

    self.border = hs.canvas.new(geo):appendElements(BORDER):show()
end

function handler:removeHighlight()
    if self.border then
        self.border:delete()
        self.border = nil
    end
end

function handler:focus()
    self:removeHighlight()
    self.rootLayout:focus()
    self:highlight()
end

function handler:selected()
    if self.selectedLayout then
        return self.selectedLayout
    else
        return self.rootLayout
    end
end

return handler
