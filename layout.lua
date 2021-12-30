local wf = require("hs.window.filter")
local uid = require("u2.uid")
local menu = require("u2.menu")
local watcher = require("hs.uielement.watcher")
local fnutils = require("hs.fnutils")
local layout = {}
layout.__index = layout

hs.window.animationDuration = 0

local MODE = {
    horizontal = "horizontal",
    vertical = "vertical",
    tabbed = "tabbed"
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
    self:draw()
end

function layout:verticalMode()
    self.mode = MODE.vertical
    self:draw()
end

function layout:tabbedMode()
    self.mode = MODE.tabbed
    self:draw()
end

-- siblings

function layout:leftSibling()
    if self.parent then
        return self:searchSibling({MODE.horizontal, MODE.tabbed}, -1, self.parent.leftSibling)
    end
end

function layout:rightSibling()
    if self.parent then
        return self:searchSibling({MODE.horizontal, MODE.tabbed}, 1, self.parent.rightSibling)
    end
end

function layout:upperSibling()
    if self.parent then
        return self:searchSibling({MODE.vertical}, -1, self.parent.upperSibling)
    end
end

function layout:lowerSibling()
    if self.parent then
        return self:searchSibling({MODE.vertical}, 1, self.parent.lowerSibling)
    end
end

function layout:searchSibling(modes, offset, parentSearchFun)
    local found = fnutils.some(modes, function(mode)
        return mode == self.parent.mode
    end)

    local idx = self.parent:matchingLayout(self)
    if found and self.parent.layouts[idx + offset] then
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

    self.handler:draw()
    self.handler:focus()
end

-- menu

function layout:setMenu(enabled)
    self.tabMenu:destroy()

    if not enabled then
        return
    end

    local menu = {}
    local unit = hs.geometry.copy(self.unit)
    local menuFrame = hs.geometry.new(unit):fromUnitRect(self.screen:frame()):floor()
    menuFrame[DIMENSION.height] = 20

    for _, l in pairs(self.layouts) do
        table.insert(menu, {
            title = l:title(),
            selected = l == self.layouts[self.cursor],
            onClick = function()
                l:setFocus()
                l:raise()
                l.handler:focus()
            end
        })
    end

    self.tabMenu:setSize(menuFrame)
    self.tabMenu:draw(menu)
end

function layout:menuLeaf()
    self:setMenu(false)
end

function layout:menuTiled(show)
    self:setMenu(false)
    for _, l in pairs(self.layouts) do
        l:menu(show)
    end
end

function layout:menuTabbed(show)
    self:setMenu(show)
    for _, l in pairs(self.layouts) do
        l:menu(show and l == self.layouts[self.cursor])
    end
end

function layout:menu(show)
    if self:isLeaf() then
        self:menuLeaf()
    elseif self:isNode() then
        if self.mode == MODE.tabbed then
            self:menuTabbed(show)
        else
            self:menuTiled(show)
        end
    end
end

-- drawing utilities

function layout:drawLeaf()
    self.window:moveToScreen(self.screen)
    self.window:moveToUnit(self.unit)
    self.window:raise()
end

function layout:drawTiled(axis, dimension)
    local offset = 0
    for _, l in pairs(self.layouts) do
        local length = (self.unit[dimension] / #self.layouts * l.scale[dimension])

        local unit = hs.geometry.copy(self.unit)
        unit[axis] = unit[axis] + offset
        unit[dimension] = length

        if l:isLeaf() and l.unit ~= unit and l:ancestorFocused() then
            l.moving = true
        end
        l.unit = unit
        l:draw()

        offset = offset + length
    end
end

function layout:drawTabbed()
    for _, l in pairs(self.layouts) do
        local offsetFrame = hs.geometry.new(self.unit):fromUnitRect(self.screen:frame()):floor()
        offsetFrame[AXIS.y] = offsetFrame[AXIS.y] + 21
        offsetFrame[DIMENSION.height] = offsetFrame[DIMENSION.height] - 21
        l.unit = offsetFrame:toUnitRect(self.screen:frame())
        l:draw()
    end
    self.layouts[self.cursor]:draw()
end

function layout:draw()
    if self:isLeaf() then
        self:drawLeaf()
    elseif self:isNode() then
        if self.mode == MODE.horizontal then
            self:drawTiled(AXIS.x, DIMENSION.width)
        elseif self.mode == MODE.vertical then
            self:drawTiled(AXIS.y, DIMENSION.height)
        elseif self.mode == MODE.tabbed then
            self:drawTabbed()
        end
    end
end

function layout:raise()
    if self:isLeaf() then
        self.window:raise()
    elseif self:isNode() then
        for _, l in pairs(self.layouts) do
            l:raise()
        end
        self.layouts[self.cursor]:raise()
    end
end

-- layout types

function layout:isLeaf()
    return (self.window ~= nil)
end

function layout:isNode()
    return (self.window == nil and self.layouts ~= {})
end

function layout:isRoot()
    return (self.parent == nil)
end

function layout:toNode()
    if self:isLeaf() then
        local win = self.window
        self.handler.callbacks:unset(self)
        local leafLayout = layout.leaf(self.screen, win, self)
        self.window = nil
        table.insert(self.layouts, leafLayout)
    end
end

-- editing

function layout:split(window)
    self:toNode()
    local newLayout = layout.leaf(self.screen, window, self)
    self:add(newLayout)
end

function layout:unlock()
    if self.parent then
        self.parent:remove(self)
        self = nil
    end
end

function layout:add(layout)
    self.cursor = self.cursor + 1
    table.insert(self.layouts, layout)
    self.handler:setFocusedLayout(layout)
    layout:setFocus()
    self.handler:draw()
    self.handler:focus()
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

    self.handler:setFocusedLayout(self)
    self:setFocus()
    self.handler:draw()
    self.handler:focus()
end

function layout:remove(layout)
    local idx = self:matchingLayout(layout)

    table.remove(self.layouts, idx)
    self.cursor = math.max(idx - 1, 0)
    if self.parent then
        if #self.layouts > 1 then
            self.handler:setFocusedLayout(self.layouts[self.cursor])
            self.layouts[self.cursor]:setFocus()
        elseif #self.layouts == 1 then
            self.handler:setFocusedLayout(self.layouts[1])
            self:setMenu(false)
            self.mode = MODE.horizontal
            self.layouts[1]:replace(self)
        elseif #self.layouts == 0 then
            self.parent:remove(self)
            return
        end
    else
        self.handler:noFocusedLayout()
    end
    self.handler:draw()
    self.handler:focus()
end

-- focus

function layout:setFocus()
    if self.parent then
        self.parent:setFocusedChild(self)
        self.parent:setFocus()
    end
end

function layout:setFocusedChild(layout)
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
        sibling:raise()
        self.handler:focus()
    end
end

function layout:focusParent()
    if self.parent then
        self.handler:setFocusedLayout(self.parent)
    end
end

function layout:focusChild()
    if self:isNode() then
        self.handler:setFocusedLayout(self.layouts[self.cursor])
    end
end

function layout:ancestorFocused()
    if self == self.handler:selected() then
        return true
    elseif self.parent then
        return self.parent:ancestorFocused()
    else
        return false
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

local focusedCallback = function(layout)
    local ancestorFocused = layout:ancestorFocused()
    if layout.moving == false and not ancestorFocused then
        layout.handler:menu()
        layout.handler:setFocusedLayout(layout)
    elseif ancestorFocused then
        layout.handler:menu()
        layout:setFocus()
    end
    layout.moving = false
end

local movedCallback = function(layout)
    layout.moving = false
end

local destroyedCallback = function(layout)
    layout.handler.callbacks:unset(layout)
    layout.parent:remove(layout)
end

local titleCallback = function(layout)
    layout.handler:menu()
end

local matchWindow = function(referredWindow, window)
    return referredWindow == window
end

function layout:generateHandlers(window)
    if self:isNode() then
        return
    end

    self.handler.callbacks:set(self, focusedCallback, movedCallback, destroyedCallback, titleCallback)
end

-- title

function layout:title()
    if self:isRoot() then
        return "Root"
    elseif self:isLeaf() then
        return self.window:application():name() .. " - " .. self.window:title()
    else
        return ""
    end
end

-- constructors

function layout.empty(screen, handler)
    local l = setmetatable({}, layout)
    l.screen = screen
    l.moving = false
    l.cursor = 0
    l.unit = hs.layout.maximized
    l.scale = {
        [DIMENSION.width] = 1,
        [DIMENSION.height] = 1
    }
    l.parent = nil
    l.name = uid.next()
    l.handler = handler
    l.tabMenu = menu.new()
    l.layouts = {}
    l.window = nil
    l.mode = MODE.horizontal
    return l
end

function layout.leaf(screen, window, parent)
    local l = setmetatable({}, layout)
    l.screen = screen
    l.moving = false
    l.cursor = 0
    l.unit = hs.layout.maximized
    l.scale = {
        [DIMENSION.width] = 1,
        [DIMENSION.height] = 1
    }
    l.parent = parent
    l.name = uid.next()
    l.handler = parent.handler
    l.tabMenu = menu.new()
    l.layouts = {}
    l.window = window
    l:generateHandlers(window)
    l.mode = MODE.horizontal
    return l
end

return layout
