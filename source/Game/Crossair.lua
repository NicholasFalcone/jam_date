class('Crossair').extends()

local gfx = playdate.graphics

function Crossair:init()
    self.x = 400 / 2
    self.y = 240 / 2
    self.hitRadius = 0  -- Default no radius, will be set by weapon type
    self.shotgunReticle = gfx.image.new("Sprites/Crossair_shotgun")
    self.normalReticle = gfx.image.new("Sprites/Crossair")
    
    -- Store reticle dimensions for boundary clamping
    local rw, rh = self.normalReticle:getSize()
    self.reticleWidth = rw
    self.reticleHeight = rh
end

function Crossair:move(x, y)
    self.x += x
    self.y += y
    
    -- Clamp to screen boundaries considering reticle size
    local minX = self.reticleWidth / 2
    local maxX = 400 - self.reticleWidth / 2
    local minY = self.reticleHeight / 2
    local maxY = 240 - self.reticleHeight / 2
    
    self.x = math.max(minX, math.min(self.x, maxX))
    self.y = math.max(minY, math.min(self.y, maxY))
end

function Crossair:draw()
    local gfx = playdate.graphics

    -- Choose reticle image based on hitRadius: shotgun if radius > 0, otherwise normal
    local reticle = (self.hitRadius and self.hitRadius > 0) and self.shotgunReticle or self.normalReticle
    if reticle then
        local rw, rh = reticle:getSize()
        local dx = math.floor(self.x - (rw / 2) + 0.5)
        local dy = math.floor(self.y - (rh / 2) + 0.5)
        reticle:draw(dx, dy)
    end

    -- Draw small central dot (pallino)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillCircleAtPoint(self.x, self.y, 2)
end