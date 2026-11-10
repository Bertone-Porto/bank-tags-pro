-- util.lua
-- Small helpers shared by every module: console logging, safe property reads and
-- an error guard for event handlers.

local Config = require("src/config")

local Util = {}

-- Prints a diagnostic line, only when Config.DEBUG is on.
function Util.debugLog(...)
    if Config.DEBUG then
        print(Config.LOG_PREFIX, ...)
    end
end

-- Prints a normal line (always shown), prefixed with the plugin name.
function Util.say(message)
    print(Config.LOG_PREFIX .. message)
end

-- Reads object[name] without raising an error if the property does not exist.
function Util.readProp(object, name)
    local ok, value = pcall(function() return object[name] end)
    if ok then
        return value
    end
    return nil
end

-- Wraps an event handler so a Lua error is printed once per distinct message
-- instead of once per tick (the menu event fires about 50 times per second).
local lastError = nil
function Util.guarded(name, handler)
    return function(event)
        local ok, err = pcall(handler, event)
        if not ok and err ~= lastError then
            lastError = err
            print(Config.LOG_PREFIX .. "ERROR in " .. name .. " handler: " .. tostring(err))
        end
    end
end

return Util
