class('UI').extends()

import "Core/AudioManager"

local gfx = playdate.graphics

function UI:init()
    -- IMPORTANT: gameplay UI() instances should default to HUD
    self.screen = "hud" -- "menu" | "howto" | "credits" | "hud" | "hidden"

    -- Main menu
    self.menuOptions = { "Play", "How to play", "Credits" }
    self.menuIndex = 1

    -- How-to pages
    self.howtoPages = {
        { key="basics1" },
        { key="basics2" },
        { key="revolver" },
        { key="minigun" },
        { key="shotgun" }
    }
    self.howtoIndex = 1

    -- Credits pages
    self.creditPages = {
        { key="credits1" },
        { key="credits2" }
    }
    self.creditIndex = 1

    -- Crank navigation
    self.crankAccum = 0
    self.crankStepDegMenu = 18
    self.crankStepDegHowto = 25

    -- Load page change sound
    local audioManager = AudioManager()
    self.SFX_ChangePage = audioManager:loadSample("sounds/SFX_Ui_ChangePage")

    -- Assets
    self.imgBasics1Page  = self:loadImage("images/howto/BASICS_1-dithered")
    self.imgBasics2Page  = self:loadImage("images/howto/BASICS2_1-dithered")
    self.imgRevolverPage = self:loadImage("images/howto/REVOLVER_1-dithered")
    self.imgMinigunPage  = self:loadImage("images/howto/MINIGUN_1-dithered")
    self.imgShotgunPage  = self:loadImage("images/howto/SHOTGUN_1-dithered")
    self.imgCredits1Page = self:loadImage("images/credits/CREDITS_2-dithered")
    self.imgCredits2Page = self:loadImage("images/credits/CREDITS_1-dithered")
    self.imgRevolverGun = self:loadImage("images/howto/revolver_gun")
    self.imgMinigunGun  = self:loadImage("images/howto/minigun_gun")
    self.imgShotgunGun  = self:loadImage("images/howto/shotgun_gun")
    self.imgBulletShotgun  = self:loadImage("images/ui/Bullet_Shotgun")
    self.imgBulletRevolver = self:loadImage("images/ui/Bullet_Revolver")
    self.imgBulletMinigun  = self:loadImage("images/ui/Bullet_Minigun")

    self.hudWeaponType = nil
    self.hudMaxAmmo = 0
    self.bulletPosCache = {}
end

function UI:loadImage(pathNoExt)
    return gfx.image.new(pathNoExt)
end

function UI:setScreen(name)
    self.screen = name
    self.crankAccum = 0
    if name == "howto" then
        self.howtoIndex = 1
    elseif name == "credits" then
        self.creditIndex = 1
    end
end

function UI:canStart()
    return self.screen == "menu" and self.menuIndex == 1
end

local function wrapIndex(i, count)
    if i < 1 then return count end
    if i > count then return 1 end
    return i
end

local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

function UI:howtoMove(dir)
    local oldIndex = self.howtoIndex
    self.howtoIndex = clamp(self.howtoIndex + dir, 1, #self.howtoPages)
    if self.howtoIndex ~= oldIndex and self.SFX_ChangePage then
        pcall(function() self.SFX_ChangePage:play(1) end)
    end
end

function UI:creditsMove(dir)
    local oldIndex = self.creditIndex
    self.creditIndex = clamp(self.creditIndex + dir, 1, #self.creditPages)
    if self.creditIndex ~= oldIndex and self.SFX_ChangePage then
        pcall(function() self.SFX_ChangePage:play(1) end)
    end
end

function UI:update()
    if self.screen == "hidden" or self.screen == "hud" then
        return nil
    end

    if self.screen == "menu" then
        if playdate.buttonJustPressed(playdate.kButtonUp) or playdate.buttonJustPressed(playdate.kButtonLeft) then
            self.menuIndex = wrapIndex(self.menuIndex - 1, #self.menuOptions)
        elseif playdate.buttonJustPressed(playdate.kButtonDown) or playdate.buttonJustPressed(playdate.kButtonRight) then
            self.menuIndex = wrapIndex(self.menuIndex + 1, #self.menuOptions)
        end

        local crankDelta = playdate.getCrankChange()
        if crankDelta ~= 0 then
            self.crankAccum += crankDelta
            while self.crankAccum >= self.crankStepDegMenu do
                self.crankAccum -= self.crankStepDegMenu
                self.menuIndex = wrapIndex(self.menuIndex + 1, #self.menuOptions)
            end
            while self.crankAccum <= -self.crankStepDegMenu do
                self.crankAccum += self.crankStepDegMenu
                self.menuIndex = wrapIndex(self.menuIndex - 1, #self.menuOptions)
            end
        end

        if playdate.buttonJustPressed(playdate.kButtonA) then
            if self.menuIndex == 1 then return "play" end
            if self.menuIndex == 2 then return "howto" end
            if self.menuIndex == 3 then return "credits" end
        end
        return nil
    end

    if self.screen == "howto" or self.screen == "credits" then
        if playdate.buttonJustPressed(playdate.kButtonB) then return "back" end
        local moveFunc = self.screen == "howto" and self.howtoMove or self.creditsMove
        
        if playdate.buttonJustPressed(playdate.kButtonDown) then moveFunc(self, 1)
        elseif playdate.buttonJustPressed(playdate.kButtonUp) then moveFunc(self, -1) end

        local crankDelta = playdate.getCrankChange()
        if crankDelta ~= 0 then
            self.crankAccum += crankDelta
            while self.crankAccum >= self.crankStepDegHowto do
                self.crankAccum -= self.crankStepDegHowto
                moveFunc(self, 1)
            end
            while self.crankAccum <= -self.crankStepDegHowto do
                self.crankAccum += self.crankStepDegHowto
                moveFunc(self, -1)
            end
        end
        return nil
    end
end

local function drawPlaceholderBox(x, y, w, h, label)
    gfx.drawRect(x, y, w, h)
    if label then gfx.drawText(label, x + 6, y + 6) end
end

function UI:getBulletPositions(weaponType, maxAmmo, bulletW, bulletH)
    self.bulletPosCache[weaponType] = self.bulletPosCache[weaponType] or {}
    local cacheForWeapon = self.bulletPosCache[weaponType]
    local key = tostring(maxAmmo) .. ":" .. tostring(bulletW) .. "x" .. tostring(bulletH)
    if cacheForWeapon[key] then return cacheForWeapon[key] end

    local topY, bottomY = 54, 226
    local stepY, stepX = bulletH + 2, bulletW + 3
    local rowsFit = math.max(1, math.floor((bottomY - topY) / stepY))
    local rowsCap = (weaponType == "Minigun") and 24 or 20
    local rows = math.min(rowsFit, rowsCap)
    local colCount = math.ceil(maxAmmo / rows)
    
    local rightX = 400 - 18 - bulletW
    local leftX = rightX - (colCount - 1) * stepX

    local positions, idx, remaining = {}, 1, maxAmmo
    for col = 0, (colCount - 1) do
        local x = leftX + col * stepX
        local bulletsInCol = math.min(rows, remaining)
        for row = 0, (bulletsInCol - 1) do
            local y = topY + (bulletsInCol - 1 - row) * stepY
            positions[idx] = { x = x, y = y }
            idx += 1
        end
        remaining -= bulletsInCol
        if remaining <= 0 then break end
    end
    cacheForWeapon[key] = positions
    return positions
end

function UI:drawHud(currentWeapon)
    if playdate.ui and playdate.ui.crankIndicator then
        pcall(function() playdate.ui.crankIndicator:stop() end)
    end

    if not currentWeapon then return end
    local weaponType = currentWeapon.weaponType or "Minigun"
    local ammo = math.max(0, currentWeapon.Ammo or 0)

    if self.hudWeaponType ~= weaponType or ammo > (self.hudMaxAmmo or 0) then
        self.hudWeaponType = weaponType
        self.hudMaxAmmo = ammo
    end

    local maxAmmo = math.max(ammo, self.hudMaxAmmo or ammo)
    local iconImg = (weaponType == "Minigun") and self.imgMinigunGun or (weaponType == "Revolver" and self.imgRevolverGun or self.imgShotgunGun)

    if iconImg then
        local w, h = iconImg:getSize()
        iconImg:draw(400 - 18 - w, 12)
    else
        drawPlaceholderBox(400 - 18 - 48, 12, 48, 24, "WPN")
    end

    local bulletImg = (weaponType == "Revolver") and self.imgBulletRevolver or (weaponType == "Shotgun" and self.imgBulletShotgun or self.imgBulletMinigun)
    local bulletW, bulletH = 6, 6
    if bulletImg then 
        bulletW, bulletH = bulletImg:getSize() -- Now uses full asset size
    end

    local consumed = math.min(maxAmmo, math.max(0, maxAmmo - ammo))
    local positions = self:getBulletPositions(weaponType, maxAmmo, bulletW, bulletH)

    for i = (consumed + 1), maxAmmo do
        local p = positions[i]
        if p then
            if bulletImg then 
                bulletImg:draw(p.x, p.y) -- Drawn at full scale
            else 
                gfx.fillRect(p.x, p.y, bulletW, bulletH)
            end
        end
    end
end

function UI:draw(currentWeapon)
    if self.screen == "hidden" or self.screen == "hud" then
        self:drawHud(currentWeapon)
        return
    end

    gfx.setColor(gfx.kColorWhite)
    gfx.fillRect(0, 0, 400, 240)
    gfx.setColor(gfx.kColorBlack)

    if self.screen == "menu" then
        local w, _ = gfx.getTextSize("MAIN MENU")
        gfx.drawText("MAIN MENU", (400 - w) / 2, 28)
        for i, label in ipairs(self.menuOptions) do
            local prefix = (i == self.menuIndex) and "> " or "  "
            local lw, _ = gfx.getTextSize(prefix .. label)
            gfx.drawText(prefix .. label, (400 - lw) / 2, 90 + (i - 1) * 22)
        end
    elseif self.screen == "howto" or self.screen == "credits" then
        local idx = self.screen == "howto" and self.howtoIndex or self.creditIndex
        local pages = self.screen == "howto" and self.howtoPages or self.creditPages
        local pageKey = pages[idx].key
        
        local pageImg = nil
        if pageKey == "basics1" then pageImg = self.imgBasics1Page
        elseif pageKey == "basics2" then pageImg = self.imgBasics2Page
        elseif pageKey == "revolver" then pageImg = self.imgRevolverPage
        elseif pageKey == "minigun" then pageImg = self.imgMinigunPage
        elseif pageKey == "shotgun" then pageImg = self.imgShotgunPage
        elseif pageKey == "credits1" then pageImg = self.imgCredits1Page
        elseif pageKey == "credits2" then pageImg = self.imgCredits2Page end

        if pageImg then pageImg:draw(0, 0) end
        if idx > 1 then gfx.fillTriangle(200, 6, 192, 18, 208, 18) end
        if idx < #pages then gfx.fillTriangle(200, 234, 192, 222, 208, 222) end
    end
end