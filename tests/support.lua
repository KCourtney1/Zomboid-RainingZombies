-- Small engine doubles: exercise event behavior without claiming to simulate PZ physics.
log = {}
scans = 0
movingLookups = 0
frame = 0

function record(name, value)
    log[#log + 1] = frame .. ":" .. name .. ":" .. tostring(value)
end

local function event()
    local callbacks = {}
    return {
        Add = function(callback) callbacks[#callbacks + 1] = callback end,
        fire = function(...)
            for _, callback in ipairs(callbacks) do callback(...) end
        end,
        count = function() return #callbacks end,
    }
end
Events = { OnTick = event(), OnZombieUpdate = event() }
SandboxVars = { RainingZombies = { HordeThrottle = 1 } }
IsoFlagType = { HoppableW = "W", HoppableN = "N" }

function instanceof(object, class) return object.class == class end
function ZombRand(first, last) return last and first or 0 end
function list(items)
    return {
        size = function() return #items end,
        get = function(_, index) return items[index + 1] end,
    }
end

function square(objects, hasFloor, stairs)
    local result = { objects = objects or {}, occupants = {}, stairs = stairs }
    function result:getObjects() scans = scans + 1; return list(self.objects) end
    function result:getMovingObjects()
        movingLookups = movingLookups + 1
        return list(self.occupants)
    end
    function result:getFloor() return hasFloor and {} or nil end
    function result:HasStairs() return self.stairs or false end
    return result
end

function window(open, smashed, barricaded)
    local result = { class = "IsoWindow", open = open, smashed = smashed, barricaded = barricaded }
    function result:IsOpen() return self.open end
    function result:isSmashed() return self.smashed end
    function result:isBarricaded() return self.barricaded end
    function result:smashWindow() self.smashed = true; record("smash", true) end
    function result:getSprite() return nil end
    return result
end

function fence(api)
    local properties = {}
    properties[api or "is"] = function(_, flag) return flag == "W" end
    return { class = "IsoObject", getSprite = function()
        return { getProperties = function() return properties end }
    end }
end

function character(name, class, height, health)
    local result = { name = name, class = class, z = height, health = health, x = 10.2, y = 10.2 }
    function result:getZ()
        if self.invalid then error("world object removed") end
        return self.z
    end
    function result:getX() return self.x end
    function result:getY() return self.y end
    function result:getHealth() return self.health end
    function result:isAlive() return self.health > 0 end
    function result:isAttacking() return self.attacking or false end
    function result:getCurrentSquare() return self.square end
    function result:getVariableBoolean() return self.climbing or false end
    function result:getForwardDirection()
        return { getX = function() return 1 end, getY = function() return 0 end }
    end
    local mutations = {
        setX = "x", setY = "y", setHealth = "health", setKnockedDown = "knockedDown",
        setBecomeCrawler = "becomeCrawler", setCrawler = "crawler",
        setFakeDead = "fakeDead", setFallOnFront = "fallOnFront",
    }
    for method, field in pairs(mutations) do
        local property = field
        result[method] = function(self, value)
            self[property] = value
            record(name .. "." .. property, value)
        end
    end
    function result:playSound(sound) record(name .. ".sound", sound) end
    function result:splatBloodFloor() record(name .. ".blood", true) end
    local body = {}
    function body:ReduceGeneralHealth(damage)
        result.health = result.health - damage
        record(name .. ".damage", damage)
    end
    function body:getBodyParts()
        return list({ { setFractureTime = function(_, duration) record(name .. ".fracture", duration) end } })
    end
    function result:getBodyDamage() return body end
    return result
end

origin = square({}, true)
ahead = square({}, false)
landing = square({}, true)
zombie = character("zombie", "IsoZombie", 3, 1)
player = character("player", "IsoPlayer", 0, 100)
neighbor = character("neighbor", "IsoZombie", 0, 1)
zombie.square = origin
landing.occupants = { zombie, player, neighbor }
function getCell() return { getGridSquare = function() return ahead end } end

function ticks(count)
    for i = 1, count do
        frame = frame + 1
        Events.OnTick.fire()
    end
end

function land(height, count)
    zombie.z = height or 0
    zombie.square = landing
    zombie.health = 0.25
    ticks(count or 40)
end

function trace() return table.concat(log, "\n") end
