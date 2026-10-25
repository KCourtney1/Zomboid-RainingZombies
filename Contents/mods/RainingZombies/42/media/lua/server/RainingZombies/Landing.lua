require "RainingZombies/Config"

local Config = RainingZombies.Config
local Landing = {}

local function applyPlayerImpact(player, fallHeight)
    if Config.get("PlayerKnockdown") then
        player:setKnockedDown(true)
    end

    local damage = Config.get("PlayerDamagePerFloor") * fallHeight
    if damage > 0 then
        player:getBodyDamage():ReduceGeneralHealth(damage)
    end

    if not Config.get("PlayerFractures") or not player:isAlive() then return end
    local fractureCount = math.floor(fallHeight / 2)
    if fractureCount == 0 then return end

    local bodyParts = player:getBodyDamage():getBodyParts()
    for i = 1, fractureCount do
        local part = bodyParts:get(ZombRand(bodyParts:size()))
        part:setFractureTime(ZombRand(20, 80))
    end
end

local function applyCollisions(zombie, fallHeight)
    local square = zombie:getCurrentSquare()
    if not square then return end

    local chainReaction = Config.get("ZombieChainReaction")
    local objects = square:getMovingObjects()
    for i = 0, objects:size() - 1 do
        local object = objects:get(i)
        if instanceof(object, "IsoPlayer") and object:isAlive() then
            applyPlayerImpact(object, fallHeight)
        elseif chainReaction and object ~= zombie
            and instanceof(object, "IsoZombie") and object:isAlive() then
            object:setKnockedDown(true)
        end
    end
end

function Landing.apply(zombie, fallHeight)
    if Config.get("CrawlerConversion") and fallHeight >= 2 and zombie:isAlive() then
        zombie:setBecomeCrawler(true)
        zombie:setCrawler(true)
        zombie:setFakeDead(false)
    end

    if Config.get("AudioVisualPolish") and fallHeight >= 1 then
        zombie:playSound("BreakBone")
        zombie:playSound("BloodSplash")
        for i = 1, fallHeight do
            zombie:splatBloodFloor()
        end
    end

    applyCollisions(zombie, fallHeight)
end

function Landing.restoreHealth(zombie, originalHealth)
    local reduction = Config.get("FallDamageReduction")
    if reduction == 100 then
        zombie:setHealth(originalHealth)
    elseif reduction > 0 then
        local currentHealth = zombie:getHealth()
        local damageTaken = originalHealth - currentHealth
        if damageTaken > 0 then
            zombie:setHealth(currentHealth + damageTaken * reduction / 100)
        end
    end
end

RainingZombies.Landing = Landing
