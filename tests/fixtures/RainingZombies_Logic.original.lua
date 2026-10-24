-- TODO FIX knock down toggle and check if you actually lose health

-- RainingZombies_Logic.lua

local ActiveJumpers = {}
local FrameCache = {    windowSquares = {},
                        fenceSquares = {}   }
local globalTick = 0
local globalStagger = 0

local function onTick()
    FrameCache.windowSquares = {}
    FrameCache.fenceSquares = {}
    globalTick = globalTick + 1
    if globalTick > 1000000 then globalTick = 0 end

    for zombie, data in pairs(ActiveJumpers) do
        if (globalTick - data.timestamp) > 300 then
            ActiveJumpers[zombie] = nil
        else
            local status, currentZ = pcall(function() return zombie:getZ() end)
            if status and currentZ then
                
                if currentZ < data.startFallZ then
                    
                    -- The Mid-Air Stutter Check
                    if math.abs(currentZ - data.lastZ) < 0.01 then
                        data.stuckFrames = (data.stuckFrames or 0) + 1
                    else
                        data.lastZ = currentZ
                        data.stuckFrames = 0
                    end
                    
                    if data.stuckFrames > 3 then
                        
                        -- THE LANDING FRAME
                        if not data.landedTick then
                            data.landedTick = globalTick
                            
                            -- Calculate total floors fallen once to share across all logic blocks
                            local fallHeight = math.max(1, data.startFallZ - currentZ)
                            
                            -- 1. Crawler Conversion
                            local allowCrawlers = true
                            if SandboxVars.RainingZombies and SandboxVars.RainingZombies.CrawlerConversion ~= nil then
                                allowCrawlers = SandboxVars.RainingZombies.CrawlerConversion
                            end
                            
                            if allowCrawlers and fallHeight >= 2 and zombie:isAlive() then
                                zombie:setBecomeCrawler(true)
                                zombie:setCrawler(true)
                                zombie:setFakeDead(false)
                            end

                            -- 2. Audio & Visual Polish
                            local allowGore = true
                            if SandboxVars.RainingZombies and SandboxVars.RainingZombies.AudioVisualPolish ~= nil then
                                allowGore = SandboxVars.RainingZombies.AudioVisualPolish
                            end

                            if allowGore and fallHeight >= 1 then
                                zombie:playSound("BreakBone")
                                zombie:playSound("BloodSplash")
                                
                                -- The higher they fall, the bigger the blood pool
                                for b = 1, fallHeight do
                                    zombie:splatBloodFloor()
                                end
                            end

                            -- 3. Collision Logic (Players and other Zombies)
                            local landSquare = zombie:getCurrentSquare()
                            if landSquare then
                                
                                local doChainReaction = true
                                if SandboxVars.RainingZombies and SandboxVars.RainingZombies.ZombieChainReaction ~= nil then
                                    doChainReaction = SandboxVars.RainingZombies.ZombieChainReaction
                                end
                                
                                for i = 0, landSquare:getMovingObjects():size() - 1 do
                                    local obj = landSquare:getMovingObjects():get(i)
                                    
                                    if instanceof(obj, "IsoPlayer") and obj:isAlive() then
                                        
                                        local doKnockdown = true
                                        if SandboxVars.RainingZombies and SandboxVars.RainingZombies.PlayerKnockdown ~= nil then
                                            doKnockdown = SandboxVars.RainingZombies.PlayerKnockdown
                                        end
                                        
                                        if doKnockdown then
                                            obj:setKnockedDown(true)
                                        end
                                        
                                        local baseDamage = 20
                                        if SandboxVars.RainingZombies and SandboxVars.RainingZombies.PlayerDamagePerFloor then
                                            baseDamage = SandboxVars.RainingZombies.PlayerDamagePerFloor
                                        end
                                        
                                        local finalDamage = baseDamage * fallHeight
                                        if finalDamage > 0 then
                                            obj:getBodyDamage():ReduceGeneralHealth(finalDamage)
                                        end

                                        local allowFractures = true
                                        if SandboxVars.RainingZombies and SandboxVars.RainingZombies.PlayerFractures ~= nil then
                                            allowFractures = SandboxVars.RainingZombies.PlayerFractures
                                        end

                                        if allowFractures and obj:isAlive() then
                                            local numFractures = math.floor((fallHeight)/2)
                                            if numFractures > 0 then
                                                local bodyDamage = obj:getBodyDamage()
                                                local bodyParts = bodyDamage:getBodyParts()
                                                
                                                for f = 1, numFractures do
                                                    local randomPartIndex = ZombRand(bodyParts:size())
                                                    local part = bodyParts:get(randomPartIndex)
                                                    part:setFractureTime(ZombRand(20, 80))
                                                end
                                            end
                                        end
                                    
                                    elseif instanceof(obj, "IsoZombie") and obj ~= zombie and obj:isAlive() then
                                        if doChainReaction then
                                            obj:setKnockedDown(true)
                                        end
                                    end
                                end
                            end

                        -- THE HEALING DELAY (30 frames later)
                        elseif (globalTick - data.landedTick) > 30 then
                            
                            local reductionSetting = 100
                            if SandboxVars.RainingZombies and SandboxVars.RainingZombies.FallDamageReduction then
                                reductionSetting = SandboxVars.RainingZombies.FallDamageReduction
                            end

                            local originalHealth = data.preFallHealth or 1.0 

                            if reductionSetting == 100 then
                                zombie:setHealth(originalHealth)
                            elseif reductionSetting > 0 then
                                local currentHealth = zombie:getHealth()
                                local damageTaken = originalHealth - currentHealth
                                if damageTaken > 0 then
                                    local healthToRestore = damageTaken * (reductionSetting / 100)
                                    zombie:setHealth(currentHealth + healthToRestore)
                                end
                            end
                            
                            ActiveJumpers[zombie] = nil
                        end
                    end
                else
                    data.lastZ = currentZ
                    data.stuckFrames = 0
                end
            else
                ActiveJumpers[zombie] = nil
            end
        end
    end
end
Events.OnTick.Add(onTick)

local function findWindowOnSquare(square)
    if not square then return nil end
    if FrameCache.windowSquares[square] ~= nil then return FrameCache.windowSquares[square] end

    local objects = square:getObjects()
    for i = 0, objects:size() - 1 do
        local obj = objects:get(i)
        if instanceof(obj, "IsoWindow") and not obj:isBarricaded() then
            FrameCache.windowSquares[square] = obj
            return obj
        end
    end
    
    FrameCache.windowSquares[square] = false
    return nil
end

local function findFenceOnSquare(square)
    if not square then return nil end
    if FrameCache.fenceSquares[square] ~= nil then return FrameCache.fenceSquares[square] end

    local objects = square:getObjects()
    for i = 0, objects:size() - 1 do
        local obj = objects:get(i)
        
        local sprite = obj:getSprite()
        if sprite then
            local props = sprite:getProperties()
            if props then
                local isHoppable = false
                
                -- BULLETPROOF API CHECK: Support both Build 42 (is) and Build 41 (Is)
                if type(props.is) == "function" then
                    isHoppable = props:is(IsoFlagType.HoppableW) or props:is(IsoFlagType.HoppableN)
                elseif type(props.Is) == "function" then
                    isHoppable = props:Is(IsoFlagType.HoppableW) or props:Is(IsoFlagType.HoppableN)
                end
                
                if isHoppable then
                    FrameCache.fenceSquares[square] = obj
                    return obj
                end
            end
        end
    end
    
    FrameCache.fenceSquares[square] = false
    return nil
end

local function handleZombieWindowVault(zombie)
    if zombie:getZ() == 0 then return end

    local currentThrottle = 15
    if SandboxVars.RainingZombies and SandboxVars.RainingZombies.HordeThrottle then
        currentThrottle = SandboxVars.RainingZombies.HordeThrottle
    end
    if currentThrottle < 1 then currentThrottle = 1 end

    -- The Round-Robin Stagger: Shift the stagger by globalTick so static hordes don't fall into a synchronized loop
    globalStagger = globalStagger + 1
    if globalStagger > 1000000 then globalStagger = 0 end

    if (globalStagger + globalTick) % currentThrottle ~= 0 then return end

    if ActiveJumpers[zombie] or zombie:getVariableBoolean("ClimbWindow") then return end

    local currentSquare = zombie:getCurrentSquare()
    
    -- Get the exact direction the zombie is facing, completely ignoring target Line-of-Sight
    local dir = zombie:getForwardDirection()
    local dx = dir:getX()
    local dy = dir:getY()
    
    -- Calculate the tile directly in front of them based on where they are looking
    local nx = math.floor(zombie:getX() + dx)
    local ny = math.floor(zombie:getY() + dy)
    local nextSquare = getCell():getGridSquare(nx, ny, zombie:getZ())
    
    local windowToVault = findWindowOnSquare(currentSquare)
    if not windowToVault then
        windowToVault = findWindowOnSquare(nextSquare)
    end
    
    local fenceToVault = findFenceOnSquare(currentSquare)
    if not fenceToVault then
        fenceToVault = findFenceOnSquare(nextSquare)
    end
    
    -- If the square in front of them doesn't have a floor, it's a drop!
    local isLedgeDrop = false
    if not nextSquare then 
        isLedgeDrop = true 
    elseif not nextSquare:getFloor() then 
        isLedgeDrop = true 
    end
    
    local isWindowClear = false
    local isBlockedByGlass = false
    local isFenceClear = false
    
    if windowToVault then
        if windowToVault:IsOpen() or windowToVault:isSmashed() then
            isWindowClear = true
        else
            local allowInstantShatter = false
            if SandboxVars.RainingZombies and SandboxVars.RainingZombies.InstantGlassShatter ~= nil then
                allowInstantShatter = SandboxVars.RainingZombies.InstantGlassShatter
            end

            if allowInstantShatter then
                windowToVault:smashWindow(true)
                isWindowClear = true
            else
                isBlockedByGlass = true
            end
        end
    end
    
    if fenceToVault then
        isFenceClear = true
    end
    
    -- If they are facing an open drop, an open window, or a fence, shove them over!
    if not isBlockedByGlass and (isWindowClear or isFenceClear or isLedgeDrop) then
        zombie:setX(zombie:getX() + (dx * 0.6))
        zombie:setY(zombie:getY() + (dy * 0.6))

        zombie:setFallOnFront(true)
        
        ActiveJumpers[zombie] = {
            startFallZ = zombie:getZ(),
            lastZ = zombie:getZ(),
            preFallHealth = zombie:getHealth(),
            timestamp = globalTick
        }
    end
end
Events.OnZombieUpdate.Add(handleZombieWindowVault)