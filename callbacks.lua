local watcher = require("hs.uielement.watcher")

local callbacks = {}
callbacks.__index = callbacks

local TITLE_EVENTS = {watcher.titleChanged}
local DESTROY_EVENTS = {watcher.elementDestroyed}
local MOVE_EVENTS = {watcher.windowMoved}
local FOCUS_EVENTS = {watcher.applicationActivated, watcher.mainWindowChanged}

function callbacks:unset(layout)
    local window = layout.window
    local windowId = window:id()

    if self.winCallbacks[windowId] then
        self.winCallbacks[windowId].destroyedWatcher:stop()
        self.winCallbacks[windowId].moveWatcher:stop()
        self.winCallbacks[windowId].titleWatcher:stop()
        self.winCallbacks[windowId] = nil
        self.layouts[windowId] = nil
    end
end

function callbacks:set(layout, focusedCallback, movedCallback, destroyedCallback, titleCallback)
    local window = layout.window
    local windowId = window:id()
    local application = window:application()
    local applicationName = application:name()

    if not self.winCallbacks[windowId] then
        self.winCallbacks[windowId] = {}
        self.layouts[windowId] = layout
    end

    self.winCallbacks[windowId].destroyedWatcher = window:newWatcher(hs.fnutils.partial(destroyedCallback, layout))
        :start(DESTROY_EVENTS)
    self.winCallbacks[windowId].moveWatcher = window:newWatcher(hs.fnutils.partial(movedCallback, layout)):start(
        MOVE_EVENTS)
    self.winCallbacks[windowId].titleWatcher = window:newWatcher(hs.fnutils.partial(titleCallback, layout)):start(
        TITLE_EVENTS)

    if not self.appFocusCallbacks[applicationName] then
        self.appFocusCallbacks[applicationName] = application:newWatcher(function(win, evt)
            local focusedWindowId = hs.window.focusedWindow():id()
            local appFocusedWindowId
            if evt == watcher.applicationActivated then
                appFocusedWindowId = application:focusedWindow():id()
            else
                appFocusedWindowId = win:id()
            end

            if self.layouts[focusedWindowId] and focusedWindowId == appFocusedWindowId then
                focusedCallback(self.layouts[focusedWindowId])
            end
        end):start(FOCUS_EVENTS)
    end
end

function callbacks.new()
    local w = setmetatable({}, callbacks)
    w.winCallbacks = {}
    w.layouts = {}
    w.appFocusCallbacks = {}
    return w
end

return callbacks
