-- Event wiring and vault decisions. Use the game's shared namespace convention
-- rather than depending on a return value from require().
require "RainingZombies/Config"
require "RainingZombies/Obstacles"
require "RainingZombies/Falls"

local Config = RainingZombies.Config
local obstacles = RainingZombies.Obstacles.new()
local falls = RainingZombies.Falls.new()
local tick = 0
local stagger = 0
local COUNTER_LIMIT = 1000000
local VAULT_PUSH_DISTANCE = 0.6

local function onTick()
    obstacles.reset()
    tick = tick + 1
    if tick > COUNTER_LIMIT then tick = 0 end
    falls.update()
end

local function canVault(currentSquare, nextSquare)
    local window = obstacles.findWindow(currentSquare) or obstacles.findWindow(nextSquare)
    if window then
        if window:IsOpen() or window:isSmashed() then return true end
        if not Config.get("InstantGlassShatter") then return false end
        window:smashWindow(true)
        return true
    end

    if not nextSquare or not nextSquare:getFloor() then return true end

    -- Only scan sprites for fences when a window or ledge hasn't decided it.
    return obstacles.findFence(currentSquare) or obstacles.findFence(nextSquare)
end

local function onZombieUpdate(zombie)
    local height = zombie:getZ()
    if height == 0 then return end

    local throttle = math.max(1, Config.get("HordeThrottle"))
    stagger = stagger + 1
    if stagger > COUNTER_LIMIT then stagger = 0 end
    if (stagger + tick) % throttle ~= 0 then return end

    if falls.contains(zombie) or zombie:getVariableBoolean("ClimbWindow") then return end

    -- Do not reposition a zombie during a bite/grab attack. Proximity to an
    -- opening alone must not interrupt combat or repeatedly shove it outside.
    if zombie:isAttacking() then return end

    local currentSquare = zombie:getCurrentSquare()
    if not currentSquare or currentSquare:HasStairs() then return end

    local direction = zombie:getForwardDirection()
    local dx, dy = direction:getX(), direction:getY()
    local x, y = zombie:getX(), zombie:getY()
    local nextSquare = getCell():getGridSquare(math.floor(x + dx), math.floor(y + dy), height)

    -- A stair tile can lack a conventional floor; it is not an open ledge.
    if nextSquare and nextSquare:HasStairs() then return end
    if not canVault(currentSquare, nextSquare) then return end

    zombie:setX(x + dx * VAULT_PUSH_DISTANCE)
    zombie:setY(y + dy * VAULT_PUSH_DISTANCE)
    zombie:setFallOnFront(true)
    falls.start(zombie)
end

Events.OnTick.Add(onTick)
Events.OnZombieUpdate.Add(onZombieUpdate)
