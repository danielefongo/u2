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

-- siblings

function layout:leftSibling()
    if self.parent then
        return self:searchSibling(MODE.horizontal, -1, self.parent.leftSibling)
    end
end

function layout:rightSibling()
    if self.parent then
        return self:searchSibling(MODE.horizontal, 1, self.parent.rightSibling)
    end
end

function layout:upperSibling()
    if self.parent then
        return self:searchSibling(MODE.vertical, -1, self.parent.upperSibling)
    end
end

function layout:lowerSibling()
    if self.parent then
        return self:searchSibling(MODE.vertical, 1, self.parent.lowerSibling)
    end
end

function layout:searchSibling(mode, offset, parentSearchFun)
    local idx = self.parent:matchingLayout(self)
    if self.parent.mode == mode and self.parent.layouts[idx + offset] then
        return self.parent.layouts[idx + offset]
    else
        return parentSearchFun(self.parent)
    end
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

    self:draw()
    self:focus()
end

-- drawing utilities

function layout:drawTiled(axis, dimension)
    local offset = 0
    for _, l in pairs(self.layouts) do
        local length = (self.unit[dimension] / #self.layouts * l.scale[dimension])

        l.unit = hs.geometry.copy(self.unit)
        l.unit[axis] = l.unit[axis] + offset
        l.unit[dimension] = length
        l:draw()

        offset = offset + length
    end
end

function layout:draw()
    if self:isLeaf() then
        self.window:moveToScreen(self.screen)
        self.window:moveToUnit(self.unit)
        self.window:raise()
    elseif self:isNode() then
        if self.mode == MODE.horizontal then
            self:drawTiled(AXIS.x, DIMENSION.width)
        elseif self.mode == MODE.vertical then
            self:drawTiled(AXIS.y, DIMENSION.height)
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
        self.windowFilter:unsubscribeAll()
        local leafLayout = layout.leaf(self.screen, win, self)
        self.window = nil
        table.insert(self.layouts, leafLayout)
    end
end

function layout:split(window)
    self:toNode()
    local newLayout = layout.leaf(self.screen, window, self)
    self:add(newLayout)
end

-- editing

function layout:unlock()
    if self.parent then
        self.parent:remove(self)
        self = nil
    end
end

function layout:add(layout)
    self.cursor = self.cursor + 1
    table.insert(self.layouts, layout)
    layout:setFocus()
end

function layout:replace(layout)
    self.parent = layout.parent
    self.parentName = layout.parent.name

    local idx = self.parent:matchingLayout(layout)
    layout.parent.cursor = idx
    layout.parent.layouts[idx] = self
    layout.parent.layouts[idx].scale = layout.scale
    self:setFocus()
end

function layout:swap(layout)
    local selfData = {
        scale = self.scale,
        idx = self.parent:matchingLayout(self),
        parent = self.parent
    }
    local layoutData = {
        scale = layout.scale,
        idx = layout.parent:matchingLayout(layout),
        parent = layout.parent
    }

    self.parent = layoutData.parent
    layoutData.parent.cursor = layoutData.idx
    layoutData.parent.layouts[layoutData.idx] = self
    layoutData.parent.layouts[layoutData.idx].scale = layoutData.scale

    layout.parent = selfData.parent
    selfData.parent.cursor = selfData.idx
    selfData.parent.layouts[selfData.idx] = layout
    selfData.parent.layouts[selfData.idx].scale = selfData.scale

    self:setFocus()
    layout.parent:draw()
    self.parent:draw()
    self.handler:focus()
end

function layout:remove(layout)
    local idx = self:matchingLayout(layout)

    table.remove(self.layouts, idx)
    self.cursor = math.max(idx - 1, 0)
    if self.parent then
        if #self.layouts > 1 then
            self.layouts[self.cursor]:setFocus()
        elseif #self.layouts == 1 then
            self.layouts[1]:replace(self)
            self:draw()
        elseif #self.layouts == 0 then
            self.parent:remove(self)
        end
    else
        self.handler:noFocusedLayout()
        self:draw()
    end
end

-- focus

function layout:setFocus()
    if self.parent then
        self.parent:focusChild(self)
        self.parent:setFocus()
    end
end

function layout:focusChild(layout)
    self.cursor = self:matchingLayout(layout)
end

function layout:focus()
    if self:isLeaf() then
        self.window:focus()
    elseif self:isNode() then
        self.layouts[self.cursor]:focus()
    end
end

function layout:focusLeft()
    self:focusSibling(self.leftSibling)
end

function layout:focusRight()
    self:focusSibling(self.rightSibling)
end

function layout:focusUp()
    self:focusSibling(self.upperSibling)
end

function layout:focusDown()
    self:focusSibling(self.lowerSibling)
end

function layout:focusSibling(finder)
    local sibling = finder(self)
    if sibling then
        sibling:setFocus()
        self.handler:focus()
    end
end

-- swap

function layout:swapLeft()
    self:swapSibling(self.leftSibling)
end

function layout:swapRight()
    self:swapSibling(self.rightSibling)
end

function layout:swapUp()
    self:swapSibling(self.upperSibling)
end

function layout:swapDown()
    self:swapSibling(self.lowerSibling)
end

function layout:swapSibling(finder)
    local sibling = finder(self)
    if sibling then
        self:swap(sibling)
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
        self:setFocus()
    end)
    self.windowFilter:subscribe(wf.windowDestroyed, function()
        self.parent:remove(self)
    end)
end

-- constructors

function layout.empty(screen, handler)
    local l = setmetatable({}, layout)
    l.screen = screen
    l.cursor = 0
    l.unit = hs.layout.maximized
    l.scale = {
        [DIMENSION.width] = 1,
        [DIMENSION.height] = 1
    }
    l.parent = nil
    l.name = uid.next()
    l.handler = handler
    l.layouts = {}
    l.window = nil
    l.handler:setFocusedLayout(l)
    l:horizontalMode()
    return l
end

function layout.leaf(screen, window, parent)
    local l = setmetatable({}, layout)
    l.screen = screen
    l.cursor = 0
    l.unit = hs.layout.maximized
    l.scale = {
        [DIMENSION.width] = 1,
        [DIMENSION.height] = 1
    }
    l.parent = parent
    l.name = uid.next()
    l.handler = parent.handler
    l.layouts = {}
    l.window = window
    l.handler:setFocusedLayout(l)
    l:generateHandlers(window)
    l:horizontalMode()
    return l
end

return layout
