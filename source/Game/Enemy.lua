class('Enemy').extends()

local gfx = playdate.graphics

local audioManager = AudioManager()

local enemySpritesCache = nil
-- Cache for the explosion images so we only load them once
local explosionFramesCache = nil

function Enemy:init(_health, _lane, _speed, _spawnIndex)
    -- lane: fraction in [-1, 1] representing relative position between the
    -- left and right edges of the road.  -1 = left edge, +1 = right edge.  we
    -- store this and use it to compute the X coordinate dynamically during
    -- draw/update so enemies always follow the curving road parallels.
    self.lane = (_lane ~= nil) and _lane or 0

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
    self.health = _health
    self.speed = _speed or 0.005
    self.spawnIndex = _spawnIndex
    self.SFX_Death = audioManager:loadSample("sounds/SFX_EnemyDeath")
    self.SFX_Hit = audioManager:loadSample("sounds/SFX_EnemyHit")
    self.enemyGoalPosition = -0.2

    if not enemySpritesCache then
        enemySpritesCache = {}
        for i = 1, 3 do
            local img = gfx.image.new("Sprites/Enemies/Enemy_0" .. tostring(i))
            if img then
                table.insert(enemySpritesCache, img)
            end
        end
    end

    if enemySpritesCache and #enemySpritesCache > 0 then
        self.sprite = enemySpritesCache[math.random(1, #enemySpritesCache)]
    else
        self.sprite = gfx.image.new("Sprites/Enemies/Enemy_01")
    end
    
    -- Flag to track if this enemy was hit in the current shot
    self.hitThisFrame = false

    -- Load explosion sequence (Frames 1 to 5)
    if not explosionFramesCache then
        explosionFramesCache = {}
        local basePath = "Sprites/Enemies/Explosion - "
        for i = 1, 5 do
            local img = gfx.image.new(basePath .. tostring(i))
            if img then
                table.insert(explosionFramesCache, img)
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
        self.distance -= (self.speed or 0.005)
        if self.distance <= self.enemyGoalPosition then
            if gameManager then
                gameManager:takeDamage(100)
            end
            self.isDead = true
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
    local ex = 200 + self.lane * w
    local ey = horizonY + sq * (groundY - horizonY)
    local size = 10 + scale * 80
    local ey_center = ey - size / 2
    
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
            local hitboxScale = 1
            if weapon and weapon.hitboxScale then
                hitboxScale = weapon.hitboxScale
            end
            local hitThresholdX = math.max(8, size * 0.5 * hitboxScale)
            local hitThresholdY = math.max(10, size * 0.6 * hitboxScale)
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
    local x = 200 + self.lane * w
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
                local sW, sH = img:getSize()
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
        if self.sprite and scale > 0 then
            local sw, sh = self.sprite:getSize()
            local scaledWidth = sw * scale
            local scaledHeight = sh * scale
            self.sprite:drawScaled(x - scaledWidth/2, y - scaledHeight, scale, scale)
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