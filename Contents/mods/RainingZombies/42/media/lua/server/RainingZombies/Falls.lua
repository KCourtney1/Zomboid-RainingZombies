require "RainingZombies/Landing"

local Landing = RainingZombies.Landing
local Falls = {}

local MAX_TRACKING_TICKS = 300
local SETTLE_TICKS = 4
local HEIGHT_TOLERANCE = 0.01
local HEAL_DELAY_TICKS = 30
local MIN_IMPACT_HEIGHT = 1

local function readHeight(zombie)
    return zombie:getZ()
end

local function updateFall(zombie, fall)
    -- Per-fall elapsed ticks do not break when the scheduling counter wraps.
    fall.age = fall.age + 1
    if fall.age > MAX_TRACKING_TICKS then return false end

    -- Reuse a function instead of allocating a closure per zombie per tick.
    local ok, height = pcall(readHeight, zombie)
    if not ok or not height then return false end

    if height >= fall.startZ then
        fall.lastZ = height
        fall.settledTicks = 0
        return true
    end

    if math.abs(height - fall.lastZ) < HEIGHT_TOLERANCE then
        fall.settledTicks = fall.settledTicks + 1
    else
        fall.lastZ = height
        fall.settledTicks = 0
    end
    if fall.settledTicks < SETTLE_TICKS then return true end

    if not fall.landedAge then
        local fallHeight = fall.startZ - height
        -- Stair movement and small height changes are not a one-floor impact.
        if fallHeight < MIN_IMPACT_HEIGHT then return true end
        fall.landedAge = fall.age
        Landing.apply(zombie, fallHeight)
    elseif fall.age - fall.landedAge > HEAL_DELAY_TICKS then
        Landing.restoreHealth(zombie, fall.preFallHealth)
        return false
    end
    return true
end

function Falls.new()
    local active = {}
    local tracker = {}

    function tracker.contains(zombie)
        return active[zombie] ~= nil
    end

    function tracker.start(zombie)
        local height = zombie:getZ()
        active[zombie] = {
            startZ = height,
            lastZ = height,
            preFallHealth = zombie:getHealth(),
            age = 0,
            settledTicks = 0,
        }
    end

    function tracker.update()
        for zombie, fall in pairs(active) do
            if not updateFall(zombie, fall) then
                active[zombie] = nil
            end
        end
    end

    return tracker
end

RainingZombies.Falls = Falls
