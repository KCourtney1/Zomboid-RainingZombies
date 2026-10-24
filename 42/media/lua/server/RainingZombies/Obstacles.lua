RainingZombies = RainingZombies or {}

local Obstacles = {}

local function isHoppable(object)
    local sprite = object:getSprite()
    local properties = sprite and sprite:getProperties()
    if not properties then return false end

    -- Preserve both property APIs supported by the original implementation.
    if type(properties.is) == "function" then
        return properties:is(IsoFlagType.HoppableW) or properties:is(IsoFlagType.HoppableN)
    elseif type(properties.Is) == "function" then
        return properties:Is(IsoFlagType.HoppableW) or properties:Is(IsoFlagType.HoppableN)
    end
    return false
end

function Obstacles.new()
    local windowSquares = {}
    local fenceSquares = {}
    local cache = {}

    function cache.reset()
        -- Keep square references for one frame only; obstacles can change,
        -- and longer-lived caches could retain unloaded world objects.
        windowSquares = {}
        fenceSquares = {}
    end

    function cache.findWindow(square)
        if not square then return nil end
        if windowSquares[square] ~= nil then return windowSquares[square] end

        local objects = square:getObjects()
        for i = 0, objects:size() - 1 do
            local object = objects:get(i)
            if instanceof(object, "IsoWindow") and not object:isBarricaded() then
                windowSquares[square] = object
                return object
            end
        end
        windowSquares[square] = false
        return nil
    end

    function cache.findFence(square)
        if not square then return nil end
        if fenceSquares[square] ~= nil then return fenceSquares[square] end

        local objects = square:getObjects()
        for i = 0, objects:size() - 1 do
            local object = objects:get(i)
            if isHoppable(object) then
                fenceSquares[square] = object
                return object
            end
        end
        fenceSquares[square] = false
        return nil
    end

    return cache
end

RainingZombies.Obstacles = Obstacles
