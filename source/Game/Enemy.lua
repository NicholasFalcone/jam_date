class('Enemy').extends()

local gfx = playdate.graphics

local audioManager = AudioManager()

-- Cache for the explosion images so we only load them once
local explosionFramesCache = nil

function Enemy:init(_health, _angle, _speed, _spawnIndex)
    self.angle = _angle or math.random(-15, 15)
    self.distance = 1.0
    self.isDead = false
    self.isHitted = false
    self.hitTimer = 0  -- Timer per l'effetto hit
    self.deathTimer = 0
    self.health = _health
    self.speed = _speed or 0.005
    self.spawnIndex = _spawnIndex
    self.SFX_Death = audioManager:loadSample("sounds/SFX_EnemyDeath")
    self.SFX_Hit = audioManager:loadSample("sounds/SFX_EnemyHit")
    self.enemyGoalPosition = -0.2
    self.sprite = gfx.image.new("Sprites/Enemies/Enemy_01")
    
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
        self.distance -= 0.005
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
    local relAngle = (self.angle - playerRotation)
    local ex = 200 + relAngle * 6
    local scale = 1.0 - self.distance
    local ey = horizonY + (scale * scale) * (groundY - horizonY)
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
            local hitThresholdX = math.max(12, size * 0.5)
            local hitThresholdY = math.max(16, size * 0.6)
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
        print("Enemy HIT! Health remaining: " .. self.health)
        if self.health <= 0 then
            self.isDead = true
            
            -- Set death timer based on how many explosion frames we have (2 ticks per frame)
            local totalFrames = (explosionFramesCache and #explosionFramesCache > 0) and #explosionFramesCache or 5
            self.deathTimer = totalFrames * 2
            
            if self.SFX_Death then
                pcall(function() self.SFX_Death:play(1) end)
            end
            print("Enemy DIED")
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

    local relAngle = (self.angle - (playerRotation or 0))
    local x = 200 + relAngle * 6
    local scale = 1.0 - self.distance
    local y = horizonY + (scale * scale) * (groundY - horizonY)
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
            
            if img then
                local scaledImage = img:scaledImage(scale)
                if scaledImage then
                    local sW, sH = scaledImage:getSize()
                    -- Center the explosion on the enemy's body center point
                    scaledImage:draw(x - sW/2, (y - size/2) - sH/2)
                end
            end
        else
            -- Fallback in case images didn't load properly
            gfx.setColor(gfx.kColorBlack)
            gfx.fillCircleAtPoint(x, y - size/2, size * 1.5)
            gfx.setColor(gfx.kColorWhite)
            gfx.fillCircleAtPoint(x, y - size/2, size)
        end
    else
        if self.sprite then
            local sw, sh = self.sprite:getSize()
            local scaledWidth = math.floor(sw * scale)
            local scaledHeight = math.floor(sh * scale)
            local scaledImage = self.sprite:scaledImage(scale)
            scaledImage:draw(x - scaledWidth/2, y - scaledHeight)
        end
        
        if self.isHitted then
            gfx.setColor(gfx.kColorWhite)
            for i = 0, 7 do
                local angle = math.rad(i * 45 + math.random(-10, 10))
                local len = size * 0.3 + math.random(0, math.max(1, math.floor(size * 0.2)))
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