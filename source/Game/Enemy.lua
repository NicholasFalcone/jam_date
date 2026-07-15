class('Enemy').extends()

local gfx = playdate.graphics

local audioManager = AudioManager()

-- Set to true to draw enemy hitboxes for debugging
local DEBUG_HITBOX = false

local enemyFramesCacheByPath = {}
-- Cache for the explosion images so we only load them once
local explosionFramesCache = nil
local explosionSizesCache = nil
-- Ping-pong animation sequence: frame indices 1→2→3→2→1…
local ANIM_SEQUENCE = {1, 2, 3, 2}

local function getCachedEnemyFrames(spritePath)
    if not spritePath then return nil end
    if enemyFramesCacheByPath[spritePath] then
        return enemyFramesCacheByPath[spritePath]
    end
    local frames = {}
    for _, suffix in ipairs({"", "_01", "_02"}) do
        local img = gfx.image.new(spritePath .. suffix)
        if img then table.insert(frames, img) end
    end
    if #frames == 0 then frames = nil end
    enemyFramesCacheByPath[spritePath] = frames
    return frames
end

local function getCachedAttackFrames(spritePath)
    if not spritePath then return nil end
    local cacheKey = spritePath .. "_Attack"
    if enemyFramesCacheByPath[cacheKey] then
        return enemyFramesCacheByPath[cacheKey]
    end
    
    -- Extract sprite name (e.g., "Enemy_02" from "Sprites/Enemies/Enemy_02")
    local spriteName = spritePath:match("([^/]+)$") or ""
    if spriteName == "" then return nil end
    
    local frames = {}
    -- Load up to 20 frames sequentially
    for i = 1, 20 do
        local frameName = "Sprites/Enemies/AttackAnimations/" .. spriteName .. "_Attack_" .. string.format("%02d", i)
        local img = gfx.image.new(frameName)
        if img then
            table.insert(frames, img)
        else
            -- Check without format padding just in case
            local imgAlt = gfx.image.new("Sprites/Enemies/AttackAnimations/" .. spriteName .. "_Attack_" .. tostring(i))
            if imgAlt then
                table.insert(frames, imgAlt)
            else
                break
            end
        end
    end
    if #frames == 0 then frames = nil end
    enemyFramesCacheByPath[cacheKey] = frames
    return frames
end

function Enemy:init(enemyType, lane, speedMultiplier, spawnIndex, healthMultiplier)
    self:reset(enemyType, lane, speedMultiplier, spawnIndex, healthMultiplier)
end

function Enemy:reset(enemyType, lane, speedMultiplier, spawnIndex, healthMultiplier)
    -- lane: fraction in [-1, 1] representing relative position between the
    -- left and right edges of the road.  -1 = left edge, +1 = right edge.  we
    -- store this and use it to compute the X coordinate dynamically during
    -- draw/update so enemies always follow the curving road parallels.
    local resolvedType = enemyType or EnemyTypes.getAll()[1]
    local resolvedHealthMultiplier = healthMultiplier or 1

    self.enemyType = resolvedType
    self.enemyTypeId = resolvedType.id or "enemy"
    self.enemyTypeName = resolvedType.name or self.enemyTypeId
    self.lane = (lane ~= nil) and lane or 0

    -- keep the old angle property around in case some legacy code still
    -- accesses it (e.g. hit calculations based on relAngle).  compute a rough
    -- equivalent for compatibility, though it isn’t used by the new movement
    -- logic.
    self.spawnAngle = self.lane * 40 -- 40° was previous max angle
    self.angle = self.spawnAngle

    -- start a little forward of the horizon so the sprite isn't
    -- completely squashed to zero scale and disappears under the road line
    self.distance = 0.85
    self.isDead = false
    self.isHitted = false
    self.hitTimer = 0  -- Timer per l'effetto hit
    self.deathTimer = 0
    self.killedByPlayer = false
    self.scoreAwarded = false
    self.baseHealth = resolvedType.health or 100
    self.health = math.max(1, math.floor(self.baseHealth * resolvedHealthMultiplier + 0.5))
    self.baseSpeed = resolvedType.speed or 0.005
    self.speedMultiplier = speedMultiplier or 1
    self.speed = self.baseSpeed * self.speedMultiplier
    self.spawnIndex = spawnIndex
    if not self.SFX_Death then
        self.SFX_Death = audioManager:loadSample("sounds/SFX_EnemyDeath")
    end
    if not self.SFX_Hit then
        self.SFX_Hit = audioManager:loadSample("sounds/SFX_EnemyHit")
    end
    self.enemyGoalPosition = -0.2

    self.isAttacking = false
    self.attackAnimFrameIndex = 1
    self.attackTick = 0
    self.attackFrames = getCachedAttackFrames(resolvedType.spritePath)
    if not self.SFX_ReachPlayer then
        self.SFX_ReachPlayer = audioManager:loadSample("sounds/SFX_EnemyReachesPlayer")
    end

    local frames = getCachedEnemyFrames(resolvedType.spritePath) or getCachedEnemyFrames("Sprites/Enemies/Enemy_01")
    self.animFrames = frames
    self.sprite = frames and frames[1]  -- kept for hitbox size calculations

    -- Cache sprite dimensions to avoid per-frame getSize() queries
    if self.sprite then
        self.spriteWidth, self.spriteHeight = self.sprite:getSize()
    else
        self.spriteWidth, self.spriteHeight = 0, 0
    end

    -- Animation state (ping-pong: 1→2→3→2→1…)
    self.animPhase = 1
    self.animTick  = 0
    self.animSpeed = resolvedType.animSpeed or 8

    -- Flag to track if this enemy was hit in the current shot
    self.hitThisFrame = false

    -- Oscillazione orizzontale (per nemici come il raider)
    self.oscillationEnabled = resolvedType.oscillationEnabled or false
    self.oscillationAmplitude = resolvedType.oscillationAmplitude or 0
    self.oscillationFrequency = resolvedType.oscillationFrequency or 1
    self.oscillationTime = math.random() * math.pi * 2  -- Inizia da un punto casuale nel ciclo
    self.oscillationOffset = 0

    -- Center pull: raider moves toward a fixed screen X (sections 2/3/4)
    self.centerPullEnabled = resolvedType.centerPullEnabled or false
    if self.centerPullEnabled then
        -- Pick randomly among section centers: 120 (sec2), 200 (sec3), 280 (sec4)
        local targets = {120, 200, 280}
        self.centerPullTargetX = targets[math.random(1, #targets)]
    else
        self.centerPullTargetX = nil
    end

    self._isPooled = false

    -- Load explosion sequence (Frames 1 to 5) and cache dimensions
    if not explosionFramesCache then
        explosionFramesCache = {}
        explosionSizesCache = {}
        local basePath = "Sprites/Enemies/Explosion - "
        for i = 1, 5 do
            local img = gfx.image.new(basePath .. tostring(i))
            if img then
                table.insert(explosionFramesCache, img)
                local w, h = img:getSize()
                table.insert(explosionSizesCache, {w = w, h = h})
            end
        end
    end
end

function Enemy:update(playerRotation, crossX, crossY, weapon, gameManager)
    if self.hitTimer > 0 then
        self.hitTimer -= 1
        if self.hitTimer <= 0 then
            self.isHitted = false
        end
    end

    if not self.isDead then
        if self.isAttacking then
            self.attackTick += 1
            if self.attackFrames then
                -- Dedicated attack animation
                if self.attackTick >= 2 then -- 2 ticks per frame
                    self.attackTick = 0
                    self.attackAnimFrameIndex += 1
                    if self.attackAnimFrameIndex > #self.attackFrames then
                        -- Attack completed! Deal damage and die
                        if gameManager then
                            gameManager:takeDamage(100)
                        end
                        if self.SFX_ReachPlayer then
                            pcall(function() self.SFX_ReachPlayer:play(1) end)
                        end
                        self.isDead = true
                        self.isAttacking = false
                    end
                end
            else
                -- Fallback attack: stay in-place and run regular walk animation for 22 ticks
                self.animTick += 1
                if self.animTick >= self.animSpeed then
                    self.animTick = 0
                    self.animPhase = (self.animPhase % #ANIM_SEQUENCE) + 1
                end
                
                if self.attackTick >= 22 then
                    -- Attack completed! Deal damage and die
                    if gameManager then
                        gameManager:takeDamage(100)
                    end
                    if self.SFX_ReachPlayer then
                        pcall(function() self.SFX_ReachPlayer:play(1) end)
                    end
                    self.isDead = true
                    self.isAttacking = false
                end
            end
        else
            local spawnDist  = 0.85          -- matches self.distance initial value
            local goalDist   = self.enemyGoalPosition  -- -0.2
            local t = 1.0 - ((self.distance - goalDist) / (spawnDist - goalDist))
            t = math.max(0, math.min(1, t))  -- clamp 0→1
            local currentSpeed = self.speed * (1.0 - t * 0.5)
            self.distance -= currentSpeed
            -- Advance ping-pong animation
            self.animTick += 1
            if self.animTick >= self.animSpeed then
                self.animTick = 0
                self.animPhase = (self.animPhase % #ANIM_SEQUENCE) + 1
            end

            -- Aggiorna l'oscillazione se abilitata
            if self.oscillationEnabled then
                self.oscillationTime += self.oscillationFrequency * 0.05
                self.oscillationOffset = math.sin(self.oscillationTime) * self.oscillationAmplitude
            end

            -- Center pull: keep raider on a fixed screen-X target by back-calculating
            -- the required lane fraction from the current road width each frame.
            -- targetX is chosen at spawn from sections 2/3/4 (x=120,200,280).
            if self.centerPullEnabled and self.centerPullTargetX then
                local horizonY2 = 112
                local groundY2  = 240
                local scale2 = 1.0 - self.distance
                local sq2    = scale2 * scale2
                local topW2  = 30
                local botW2  = 300
                local w2 = topW2 + sq2 * (botW2 - topW2)
                if w2 > 0 then
                    self.lane = (self.centerPullTargetX - 200) / w2
                end
            end
            
            if self.distance <= self.enemyGoalPosition then
                self.isAttacking = true
                self.attackAnimFrameIndex = 1
                self.attackTick = 0
            end
        end
    else
        if self.deathTimer > 0 then
            self.deathTimer -= 1
        end
    end
end

-- Reset hit tracking at the start of a new shot
function Enemy:resetHitTracking()
    self.hitThisFrame = false
end

-- Check if this enemy is hit by the current shot
function Enemy:checkHit(playerRotation, crossX, crossY, weapon)
    if self.isDead or self.hitThisFrame then return false end
    
    local horizonY = 112
    local groundY = 240
    -- calculate relative angle for fallback checks and any future camera
    -- rotation logic.  this value does *not* affect the horizontal position
    -- used below when the crosshair coordinates are available.
    local relAngle = self.spawnAngle - (playerRotation or 0)

    -- compute horizontal position using lane fraction and road half-width
    -- at the current depth; this mirrors the calculation in draw().
    local scale = 1.0 - self.distance
    local sq = scale * scale
    local topW = 30
    local botW = 300
    local w = topW + sq * (botW - topW)
    
    -- Applica oscillazione alla posizione orizzontale (stesso calcolo del draw)
    local effectiveLane = self.lane + (self.oscillationOffset or 0)
    local ex = 200 + effectiveLane * w
    
    local ey = horizonY + sq * (groundY - horizonY)

    local typeHitboxScale   = (self.enemyType and self.enemyType.hitboxScale)   or 1.0
    local typeHitboxScaleX  = (self.enemyType and self.enemyType.hitboxScaleX)  or 1.0
    local typeHitboxOffsetY = (self.enemyType and self.enemyType.hitboxOffsetY) or 0

    local sw, sh
    if self.isAttacking and self.attackFrames and self.attackFrames[self.attackAnimFrameIndex] then
        sw, sh = self.attackFrames[self.attackAnimFrameIndex]:getSize()
    else
        sw, sh = self.spriteWidth, self.spriteHeight
    end
    local scaledWidth  = sw * scale * typeHitboxScale * typeHitboxScaleX
    local scaledHeight = sh * scale * typeHitboxScale
    local ey_center    = ey - (sh * scale) / 2 + typeHitboxOffsetY * scale

    if crossX and crossY then
        local dx = math.abs(ex - crossX)
        local dy = math.abs(ey_center - crossY)

        local hitRadius = 0
        if weapon.crosshair and weapon.crosshair.hitRadius then
            hitRadius = weapon.crosshair.hitRadius
        end

        if hitRadius > 0 then
            -- SHOTGUN: Scaled hit radius with enemy distance
            local scaledHitRadius = hitRadius * (1.0 + scale * 3)
            local distance = math.sqrt(dx * dx + dy * dy)
            return distance <= scaledHitRadius
        else
            -- REVOLVER/MINIGUN: Rectangular hitbox that scales with enemy
            local weaponHitboxScale = 1
            if weapon and weapon.hitboxScale then
                weaponHitboxScale = weapon.hitboxScale
            end
            local hitThresholdX = math.max(8,  scaledWidth  * 0.5 * weaponHitboxScale)
            local hitThresholdY = math.max(10, scaledHeight * 0.5 * weaponHitboxScale)
            return dx <= hitThresholdX and dy <= hitThresholdY
        end
    else
        -- fallback to angle-based check
        return math.abs(relAngle) < 5
    end
end

-- Apply hit to this enemy
function Enemy:applyHit(dmg)
    if not self.isHitted and not self.hitThisFrame then
        self.hitThisFrame = true
        self.isHitted = true
        self.hitTimer = 3
        self.health -= dmg
        if self.SFX_Hit then
            pcall(function() self.SFX_Hit:play(1) end)
        end
		
        if self.health <= 0 then
            self.isDead = true
            self.isAttacking = false
            self.killedByPlayer = true
            
            -- Set death timer based on how many explosion frames we have (2 ticks per frame)
            local totalFrames = (explosionFramesCache and #explosionFramesCache > 0) and #explosionFramesCache or 5
            self.deathTimer = totalFrames * 2
            
            if self.SFX_Death then
                pcall(function() self.SFX_Death:play(1) end)
            end
			
        end
        return true
    end
    return false
end

function Enemy:die()
    -- placeholder for any death logic (sound, particles)
end

function Enemy:draw(playerRotation)
    local horizonY = 112
    local groundY = 240

    -- compute road half‑width at current depth and place enemy on the
    -- appropriate parallel line according to lane fraction.
    local scale = 1.0 - self.distance
    local sq = scale * scale
    local topW = 30
    local botW = 300
    local w = topW + sq * (botW - topW)
    
    -- Applica oscillazione alla posizione orizzontale
    local effectiveLane = self.lane + (self.oscillationOffset or 0)
    local x = 200 + effectiveLane * w
    
    local y = horizonY + sq * (groundY - horizonY)
    local size = 10 + scale * 80

    if self.isDead then
        if explosionFramesCache and #explosionFramesCache > 0 and scale > 0 then
            -- Animation calculation (same logic used for weapons)
            local totalFrames = #explosionFramesCache
            local totalTicks = totalFrames * 2
            
            -- Calculate current frame index (1 to totalFrames)
            local currentFrame = math.floor((totalTicks - self.deathTimer) / 2) + 1
            local frameIndex = math.max(1, math.min(totalFrames, currentFrame))
            
            local img = explosionFramesCache[frameIndex]
            
            if img and scale > 0 then
                local sizeCache = explosionSizesCache[frameIndex]
                local sW, sH = sizeCache.w, sizeCache.h
                local scaledW = sW * scale
                local scaledH = sH * scale
                -- Center the explosion on the enemy's body center point
                img:drawScaled(x - scaledW/2, (y - size/2) - scaledH/2, scale, scale)
            end
        else
            -- Fallback in case images didn't load properly
            gfx.setColor(gfx.kColorBlack)
            gfx.fillCircleAtPoint(x, y - size/2, size * 1.5)
            gfx.setColor(gfx.kColorWhite)
            gfx.fillCircleAtPoint(x, y - size/2, size)
        end
    else
        local drawFrame
        if self.isAttacking and self.attackFrames then
            drawFrame = self.attackFrames[self.attackAnimFrameIndex]
        else
            local frameIdx = ANIM_SEQUENCE[self.animPhase] or 1
            drawFrame = (self.animFrames and self.animFrames[frameIdx]) or self.sprite
        end

        if drawFrame and scale > 0 then
            local sw, sh = drawFrame:getSize()
            local scaledWidth = sw * scale
            local scaledHeight = sh * scale
            drawFrame:drawScaled(x - scaledWidth/2, y - scaledHeight, scale, scale)
        end
        
        if self.isHitted then
            gfx.setColor(gfx.kColorWhite)
            for i = 0, 7 do
                local angle = math.rad(i * 45 + math.random(-10, 10))
                local len = size * 0.5 + math.random(0, math.max(1, math.floor(size * 0.2)))
                local startX = x + math.cos(angle) * size * 0.3
                local startY = (y - size/2) + math.sin(angle) * size * 0.3
                local endX = startX + math.cos(angle) * len
                local endY = startY + math.sin(angle) * len
                gfx.drawLine(startX, startY, endX, endY)
            end
            for i = 1, 5 do
                local maxOffset = math.max(1, math.floor(size/2))
                local dropX = x + math.random(-maxOffset, maxOffset)
                local dropY = (y - size/2) + math.random(-maxOffset, maxOffset)
                gfx.fillCircleAtPoint(dropX, dropY, 1 + math.random(0, 2))
            end
        end
    end
end

function Enemy:drawDebugHitbox()
    if not DEBUG_HITBOX then return end

    local horizonY = 112
    local groundY = 240

    local scale = 1.0 - self.distance
    local sq = scale * scale
    local topW = 30
    local botW = 300
    local w = topW + sq * (botW - topW)
    local effectiveLane = self.lane + (self.oscillationOffset or 0)
    local ex = 200 + effectiveLane * w
    local ey = horizonY + sq * (groundY - horizonY)
    local typeHitboxScale   = (self.enemyType and self.enemyType.hitboxScale)   or 1.0
    local typeHitboxScaleX  = (self.enemyType and self.enemyType.hitboxScaleX)  or 1.0
    local typeHitboxOffsetY = (self.enemyType and self.enemyType.hitboxOffsetY) or 0

    local sw, sh = self.spriteWidth, self.spriteHeight
    local scaledWidth  = sw * scale * typeHitboxScale * typeHitboxScaleX
    local scaledHeight = sh * scale * typeHitboxScale
    local ey_center    = ey - (sh * scale) / 2 + typeHitboxOffsetY * scale

    -- Mirror the hitbox thresholds from checkHit() (no weapon ref here)
    local hitThresholdX = math.max(8,  scaledWidth  * 0.5)
    local hitThresholdY = math.max(10, scaledHeight * 0.5)

    local rectX = math.floor(ex - hitThresholdX)
    local rectY = math.floor(ey_center - hitThresholdY)
    local rectW = math.floor(hitThresholdX * 2)
    local rectH = math.floor(hitThresholdY * 2)

    -- Draw in XOR so it's visible on any background
    gfx.setImageDrawMode(gfx.kDrawModeXOR)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawRect(rectX, rectY, rectW, rectH)
    -- Small crosshair at the hitbox center
    gfx.drawLine(ex - 3, ey_center, ex + 3, ey_center)
    gfx.drawLine(ex, ey_center - 3, ex, ey_center + 3)
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
end

function Enemy:setSpeedMultiplier(speedMultiplier)
    self.speedMultiplier = speedMultiplier or 1
    self.speed = self.baseSpeed * self.speedMultiplier
end

-- Object Pooling Implementation
local enemyPool = {}

function Enemy.get(enemyType, lane, speedMultiplier, spawnIndex, healthMultiplier)
    local e
    if #enemyPool > 0 then
        e = table.remove(enemyPool)
        e:reset(enemyType, lane, speedMultiplier, spawnIndex, healthMultiplier)
    else
        e = Enemy(enemyType, lane, speedMultiplier, spawnIndex, healthMultiplier)
    end
    return e
end

function Enemy.release(e)
    if e and not e._isPooled then
        e._isPooled = true
        table.insert(enemyPool, e)
    end
end