local menu = {}
menu.__index = menu

menu.blackColor = {
    red = 0,
    green = 0,
    blue = 0,
    alpha = 1.0
}
menu.fillColor = {
    red = 1.0,
    green = 1.0,
    blue = 1.0,
    alpha = 0.3
}
menu.selectedColor = {
    red = .9,
    green = .9,
    blue = .9,
    alpha = 0.5
}
menu.strokeColor = {
    red = 0.0,
    green = 0.0,
    blue = 0.0,
    alpha = 0.7
}
menu.textColor = {
    red = 0.0,
    green = 0.0,
    blue = 0.0,
    alpha = 0.6
}

local function generateTabFrame(number, idx, heightPadding)
    local singleSize = math.floor(100 / number)
    local offset = math.floor((idx - 1) / number * 100)
    return {
        x = offset + 1,
        y = 0 + heightPadding,
        w = singleSize - 2,
        h = 100 - heightPadding * 2
    }
end

local function toPercentages(frame)
    return {
        x = tostring(frame.x) .. "%",
        y = tostring(frame.y) .. "%",
        w = tostring(frame.w) .. "%",
        h = tostring(frame.h) .. "%"
    }
end

function menu:destroy()
    for _, v in ipairs(self.table) do
        v:delete()
    end
    self.table = {}
    if self.canvas then
        self.canvas:delete()
        self.canvas = nil
    end
end

function menu:draw(opts)
    if not self.size then
        return
    end

    self:destroy()

    self.canvas = hs.canvas.new(self.size)
    self.canvas:appendElements({
        type = "rectangle",
        fillColor = menu.blackColor
    })

    for i, opt in pairs(opts) do
        local bg
        if opt.selected then
            bg = menu.selectedColor
        else
            bg = menu.fillColor
        end

        local tabFrame = generateTabFrame(#opts, i, 1)
        local textFrame = generateTabFrame(#opts, i, 15)

        self.canvas:appendElements({
            type = "rectangle",
            action = "fill",
            fillColor = bg,
            frame = toPercentages(tabFrame),
            trackMouseDown = true,
            id = i
        }):appendElements({
            type = "text",
            text = opt.title,
            textSize = self.size.h * 0.5,
            frame = toPercentages(textFrame),
            textAlignment = "center"
        })

        self.canvas:mouseCallback(function(_, _, idx)
            opts[idx].onClick()
        end)
    end

    self.canvas:level(100)
    self.canvas:show()
end

function menu:setSize(size)
    self.size = size
end

function menu.new()
    local m = setmetatable({}, menu)
    m.table = {}
    m.size = nil
    return m
end

return menu
