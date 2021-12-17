local wf = require("hs.window.filter")
local uid = require("i3.uid")
local layout = {}
layout.__index = layout

hs.window.animationDuration = 0
local MODE = {
    horizontal = "horizontal",
    vertical = "vertical"
}
local AXIS = {
    x = "x",
    y = "y"
}
local DIMENSION = {
    width = "w",
    height = "h"
}
local MODE_DIMENSION = {
    [MODE.horizontal] = DIMENSION.width,
    [MODE.vertical] = DIMENSION.height
}
local MIN_SCALE = 0.33
local RESIZE_RATIO = 0.2

function layout:matchingLayout(layout)
    for i, v in pairs(self.layouts) do
        if v == layout then
            return i
        end
    end
    return nil
end

-- modes

function layout:horizontalMode()
    self.mode = MODE.horizontal
end

function layout:verticalMode()
    self.mode = MODE.vertical
end

-- resize utilities

function layout:wider()
    if self.parent then
        self.parent:resize(self, DIMENSION.width, RESIZE_RATIO)
    end
end

function layout:thinner()
    if self.parent then
        self.parent:resize(self, DIMENSION.width, -RESIZE_RATIO)
    end
end

function layout:taller()
    if self.parent then
        self.parent:resize(self, DIMENSION.height, RESIZE_RATIO)
    end
end

function layout:shorter()
    if self.parent then
        self.parent:resize(self, DIMENSION.height, -RESIZE_RATIO)
    end
end

function layout:resize(layout, dimension, ratio)
    if MODE_DIMENSION[self.mode] ~= dimension then
        if self.parent then
            self.parent:resize(self, dimension, ratio)
        end
        return
    end

    local resize = true
    local othersRatio = -(ratio / (#self.layouts - 1))

    for _, l in pairs(self.layouts) do
        if l == layout and l.scale[dimension] + ratio < MIN_SCALE then
            resize = false
            break
        elseif l ~= layout and l.scale[dimension] + othersRatio < MIN_SCALE then
            resize = false
            break
        end
    end

    if not resize then
        return
    end

    for _, l in pairs(self.layouts) do
        if l == layout then
            l.scale[dimension] = l.scale[dimension] + ratio
        else
            l.scale[dimension] = l.scale[dimension] + othersRatio
        end
    end

    self.handler:draw()
end

-- drawing utilities

function layout:drawTiled(screen, axis, dimension)
    local offset = 0
    for _, l in pairs(self.layouts) do
        local length = (self.unit[dimension] / #self.layouts * l.scale[dimension])

        l.unit = hs.geometry.copy(self.unit)
        l.unit[axis] = l.unit[axis] + offset
        l.unit[dimension] = length
        l:draw(screen)

        offset = offset + length
    end
end

function layout:draw(screen)
    if self:isLeaf() then
        self.window:moveToScreen(screen)
        self.window:moveToUnit(self.unit)
        self.window:raise()
    elseif self:isNode() then
        if self.mode == MODE.horizontal then
            self:drawTiled(screen, AXIS.x, DIMENSION.width)
        elseif self.mode == MODE.vertical then
            self:drawTiled(screen, AXIS.y, DIMENSION.height)
        end
    end
end

-- layout types

function layout:isLeaf()
    return (self.window ~= nil)
end

function layout:isNode()
    return (self.window == nil and self.layouts ~= {})
end

function layout:toNode()
    if self:isLeaf() then
        local win = self.window
        local leafLayout = layout.leaf(win, self)
        leafLayout:generateHandlers(win)
        self.windowFilter:unsubscribeAll()
        self.window = nil
        table.insert(self.layouts, leafLayout)
    end
end

function layout:split(window)
    self:toNode()
    local newLayout = layout.leaf(window, self)
    newLayout:generateHandlers(window)
    self:add(newLayout)
end

-- editing

function layout:unlock()
    if self.parent then
        self.parent:remove(self)
        self.handler:draw()
        self = nil
    end
end

function layout:add(layout)
    self.cursor = self.cursor + 1
    table.insert(self.layouts, layout)
end

function layout:replace(layout)
    self.parent = layout.parent
    self.parentName = layout.parent.name

    local idx = self.parent:matchingLayout(layout)
    layout.parent.cursor = idx - 1
    layout.parent.layouts[idx] = self
    layout.parent.layouts[idx].scale = layout.scale
end

function layout:remove(layout)
    local idx = self:matchingLayout(layout)

    table.remove(self.layouts, idx)
    self.cursor = idx - 1
    if self.parent then
        if #self.layouts == 1 then
            self.layouts[1]:replace(self)
        elseif #self.layouts == 0 then
            self.parent:remove(self)
        end
    else
        self.handler:noFocusedLayout()
    end
end

function layout:setFocus(layout)
    self.cursor = self:matchingLayout(layout)
    if self.parent then
        self.parent:setFocus(self)
    end
end

-- window handlers

function layout:generateHandlers(window)
    if self:isNode() then
        return
    end

    self.windowFilter = wf.new(function(w)
        return w == window
    end)
    self.windowFilter:subscribe(wf.windowFocused, function()
        self.handler:setFocusedLayout(self)
        if self.parent then
            self.parent:setFocus(self)
        end
    end)
    self.windowFilter:subscribe(wf.windowDestroyed, function()
        self.parent:remove(self)
        self.handler:draw()
    end)
end

-- constructors

function layout.empty(handler)
    local l = setmetatable({}, layout)
    l.cursor = 0
    l.unit = hs.layout.maximized
    l.scale = {
        [DIMENSION.width] = 1,
        [DIMENSION.height] = 1
    }
    l.parent = nil
    l.parentName = nil
    l.name = uid.next()
    l.handler = handler
    l.layouts = {}
    l.window = nil
    l.handler:setFocusedLayout(l)
    l:horizontalMode()
    return l
end

function layout.leaf(window, parent)
    local l = setmetatable({}, layout)
    l.cursor = 0
    l.unit = hs.layout.maximized
    l.scale = {
        [DIMENSION.width] = 1,
        [DIMENSION.height] = 1
    }
    l.parent = parent
    l.parentName = parent.name
    l.name = uid.next()
    l.handler = parent.handler
    l.layouts = {}
    l.window = window
    l.handler:setFocusedLayout(l)
    l:horizontalMode()
    return l
end

return layout
