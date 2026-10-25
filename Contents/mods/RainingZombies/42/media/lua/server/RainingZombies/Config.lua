RainingZombies = RainingZombies or {}

local Config = {}
local defaults = {
    FallDamageReduction = 100,
    InstantGlassShatter = false,
    HordeThrottle = 15,
    PlayerKnockdown = true,
    PlayerDamagePerFloor = 20,
    PlayerFractures = true,
    CrawlerConversion = true,
    ZombieChainReaction = true,
    AudioVisualPolish = true,
}

-- Read on demand so changing sandbox settings during a game still works.
-- False and zero are settings, not missing values.
function Config.get(name)
    local settings = SandboxVars and SandboxVars.RainingZombies
    if settings and settings[name] ~= nil then
        return settings[name]
    end
    return defaults[name]
end

RainingZombies.Config = Config
