class('Crossair').extends()

local gfx = playdate.graphics

function Crossair:init()
    self.x = 400 / 2
    self.y = 240 / 2
    self.hitRadius = 0  -- Default no radius, will be set by weapon type
    self.reticleScale = 1
    self.shotgunReticle = gfx.image.new("Sprites/Crossair_shotgun")
    self.normalReticle = gfx.image.new("Sprites/Crossair")
    
    -- Store reticle dimensions for boundary clamping
    local rw, rh = self.normalReticle:getSize()
    self.reticleWidth = rw
    self.reticleHeight = rh
end

function Crossair:getActiveReticle()
    local reticle = (self.hitRadius and self.hitRadius > 0) and self.shotgunReticle or self.normalReticle
    return reticle, self.reticleScale or 1
end

function Crossair:getActiveReticleSize()
    local reticle, scale = self:getActiveReticle()
    if reticle then
        local rw, rh = reticle:getSize()
        return rw * scale, rh * scale
    end
    return self.reticleWidth, self.reticleHeight
end

function Crossair:move(x, y)
    self.x += x
    self.y += y
    
    -- Clamp to screen boundaries considering reticle size
    local activeWidth, activeHeight = self:getActiveReticleSize()
    local minX = activeWidth / 2
    local maxX = 400 - activeWidth / 2
    local minY = activeHeight / 2
    local maxY = 240 - activeHeight / 2
    
    self.x = math.max(minX, math.min(self.x, maxX))
    self.y = math.max(minY, math.min(self.y, maxY))
end

function Crossair:resetToCenter()
    self.x = 400 / 2
    self.y = 240 / 2
end

function Crossair:draw()
    local gfx = playdate.graphics

    -- Choose reticle image based on hitRadius: shotgun if radius > 0, otherwise normal
    local reticle, scale = self:getActiveReticle()
    if reticle then
        local rw, rh = reticle:getSize()
        local scaledWidth = rw * scale
        local scaledHeight = rh * scale
        local dx = math.floor(self.x - (scaledWidth / 2) + 0.5)
        local dy = math.floor(self.y - (scaledHeight / 2) + 0.5)
        if scale ~= 1 and reticle.drawScaled then
            reticle:drawScaled(dx, dy, scale, scale)
        else
            reticle:draw(dx, dy)
        end
    end

    -- Draw small central dot (pallino)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillCircleAtPoint(self.x, self.y, 2)
end