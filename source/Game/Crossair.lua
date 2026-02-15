class('Crossair').extends()

local gfx = playdate.graphics

function Crossair:init()
    self.x = 400 / 2
    self.y = 240 / 2
    self.hitRadius = 0  -- Default no radius, will be set by weapon type
    self.shotgunReticle = gfx.image.new("Sprites/Crossair_shotgun")
    self.normalReticle = gfx.image.new("Sprites/Crossair")
end

function Crossair:move(x, y)
    self.x += x
    self.y += y
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