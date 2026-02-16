class('UI').extends()

import "Core/AudioManager"

local gfx = playdate.graphics

function UI:init()
    -- IMPORTANT: gameplay UI() instances should default to HUD
    self.screen = "hud" -- "menu" | "howto" | "credits" | "hud" | "hidden"

    -- Main menu
    self.menuOptions = { "Play", "How to play", "Credits" }
    self.menuIndex = 1

    -- How-to pages (order required) - now using full-page images
    self.howtoPages = {
        { key="basics1" },
        { key="basics2" },
        { key="revolver" },
        { key="minigun" },
        { key="shotgun" }
    }
    self.howtoIndex = 1

    -- Credits pages (2 pages with full-page images)
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

    -- ==========================================
    -- ROBUST BACKGROUND LOADER
    -- ==========================================
    local bgPathsToTry = {
        "images/ui/MainMenuBG",
        "images/Ui/MainMenuBG",
        "Ui/MainMenuBG",
        "ui/MainMenuBG",
        "MainMenuBG"
    }
    
    for _, path in ipairs(bgPathsToTry) do
        self.imgMainMenuBG = self:loadImage(path)
        if self.imgMainMenuBG then
            print("SUCCESS: Loaded Main menu background from: " .. path)
            break
        end
    end

    if not self.imgMainMenuBG then
        print("ERROR: MainMenuBG.png could not be found! Make sure to REBUILD/RESTART the Playdate Simulator.")
    end

    -- ==========================================
    -- ROBUST MENU CURSOR (BULLET) LOADER
    -- ==========================================
    local cursorPathsToTry = {
        "images/ui/MenuCursor",
        "images/ui/Bullet_Revolver_UI_Black",
        "images/Ui/Bullet_Revolver_UI_Black",
        "Ui/Bullet_Revolver_UI_Black",
        "ui/Bullet_Revolver_UI_Black",
        "Bullet_Revolver_UI_Black"
    }
    
    for _, path in ipairs(cursorPathsToTry) do
        self.imgMenuCursor = self:loadImage(path)
        if self.imgMenuCursor then
            print("SUCCESS: Loaded Menu Cursor from: " .. path)
            break
        end
    end

    if not self.imgMenuCursor then
        print("ERROR: Cursor image (Bullet_Revolver_UI_Black.png) could not be found!")
    end
    -- ==========================================

    -- How-to full page images (put in: source/images/howto/)
    self.imgBasics1Page  = self:loadImage("images/howto/BASICS_1-dithered")
    self.imgBasics2Page  = self:loadImage("images/howto/BASICS2_1-dithered")
    self.imgRevolverPage = self:loadImage("images/howto/REVOLVER_1-dithered")
    self.imgMinigunPage  = self:loadImage("images/howto/MINIGUN_1-dithered")
    self.imgShotgunPage  = self:loadImage("images/howto/SHOTGUN_1-dithered")

    -- Credits full page images (put in: source/images/credits/)
    self.imgCredits1Page = self:loadImage("images/credits/CREDITS_2-dithered")
    self.imgCredits2Page = self:loadImage("images/credits/CREDITS_1-dithered")

    -- Keep weapon icons for HUD
    self.imgRevolverGun = self:loadImage("images/howto/revolver_gun")
    self.imgMinigunGun  = self:loadImage("images/howto/minigun_gun")
    self.imgShotgunGun  = self:loadImage("images/howto/shotgun_gun")

    -- HUD bullet sprites
    self.imgBulletShotgun  = self:loadImage("images/ui/Bullet_Shotgun")
    self.imgBulletRevolver = self:loadImage("images/ui/Bullet_Revolver")
    self.imgBulletMinigun  = self:loadImage("images/ui/Bullet_Minigun")

    -- HUD ammo tracking
    self.hudWeaponType = nil
    self.hudMaxAmmo = 0

    -- Bullet layout cache
    self.bulletPosCache = {}
end

function UI:loadImage(pathNoExt)
    return gfx.image.new(pathNoExt) -- returns nil if missing
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
    local newIndex = self.howtoIndex + dir
    self.howtoIndex = clamp(newIndex, 1, #self.howtoPages)
    
    if self.howtoIndex ~= oldIndex and self.SFX_ChangePage then
        pcall(function() self.SFX_ChangePage:play(1) end)
    end
end

function UI:creditsMove(dir)
    local oldIndex = self.creditIndex
    local newIndex = self.creditIndex + dir
    self.creditIndex = clamp(newIndex, 1, #self.creditPages)
    
    if self.creditIndex ~= oldIndex and self.SFX_ChangePage then
        pcall(function() self.SFX_ChangePage:play(1) end)
    end
end

function UI:update()
    if self.screen == "hidden" or self.screen == "hud" then
        return nil
    end

    -- MENU
    if self.screen == "menu" then
        if playdate.buttonJustPressed(playdate.kButtonUp) or playdate.buttonJustPressed(playdate.kButtonLeft) then
            self.menuIndex = wrapIndex(self.menuIndex - 1, #self.menuOptions)
        elseif playdate.buttonJustPressed(playdate.kButtonDown) or playdate.buttonJustPressed(playdate.kButtonRight) then
            self.menuIndex = wrapIndex(self.menuIndex + 1, #self.menuOptions)
        end

        local crankDelta = playdate.getCrankChange()
        if crankDelta ~= 0 then
            self.crankAccum = self.crankAccum + crankDelta
            while self.crankAccum >= self.crankStepDegMenu do
                self.crankAccum = self.crankAccum - self.crankStepDegMenu
                self.menuIndex = wrapIndex(self.menuIndex + 1, #self.menuOptions)
            end
            while self.crankAccum <= -self.crankStepDegMenu do
                self.crankAccum = self.crankAccum + self.crankStepDegMenu
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

    -- HOW TO PLAY (4 pages)
    if self.screen == "howto" then
        if playdate.buttonJustPressed(playdate.kButtonB) then
            return "back"
        end

        if playdate.buttonJustPressed(playdate.kButtonDown) then
            self:howtoMove(1)
        elseif playdate.buttonJustPressed(playdate.kButtonUp) then
            self:howtoMove(-1)
        end

        local crankDelta = playdate.getCrankChange()
        if crankDelta ~= 0 then
            self.crankAccum = self.crankAccum + crankDelta
            while self.crankAccum >= self.crankStepDegHowto do
                self.crankAccum = self.crankAccum - self.crankStepDegHowto
                self:howtoMove(1)
            end
            while self.crankAccum <= -self.crankStepDegHowto do
                self.crankAccum = self.crankAccum + self.crankStepDegHowto
                self:howtoMove(-1)
            end
        end

        return nil
    end

    -- CREDITS
    if self.screen == "credits" then
        if playdate.buttonJustPressed(playdate.kButtonB) then
            return "back"
        end

        if playdate.buttonJustPressed(playdate.kButtonDown) then
            self:creditsMove(1)
        elseif playdate.buttonJustPressed(playdate.kButtonUp) then
            self:creditsMove(-1)
        end

        local crankDelta = playdate.getCrankChange()
        if crankDelta ~= 0 then
            self.crankAccum = self.crankAccum + crankDelta
            while self.crankAccum >= self.crankStepDegHowto do
                self.crankAccum = self.crankAccum - self.crankStepDegHowto
                self:creditsMove(1)
            end
            while self.crankAccum <= -self.crankStepDegHowto do
                self.crankAccum = self.crankAccum + self.crankStepDegHowto
                self:creditsMove(-1)
            end
        end

        return nil
    end

    return nil
end

local function drawPlaceholderBox(x, y, w, h, label)
    gfx.drawRect(x, y, w, h)
    if label then
        gfx.drawText(label, x + 6, y + 6)
    end
end

function UI:getBulletPositions(weaponType, maxAmmo, bulletW, bulletH)
    self.bulletPosCache[weaponType] = self.bulletPosCache[weaponType] or {}
    local cacheForWeapon = self.bulletPosCache[weaponType]

    local key = tostring(maxAmmo) .. ":" .. tostring(bulletW) .. "x" .. tostring(bulletH)
    if cacheForWeapon[key] then
        return cacheForWeapon[key]
    end

    local topY = 54 
    local bottomY = 226

    local stepY = bulletH + 2
    local stepX = bulletW + 3

    local rowsFit = math.floor((bottomY - topY) / stepY)
    if rowsFit < 1 then rowsFit = 1 end

    local rowsCap = 20
    if weaponType == "Minigun" then rowsCap = 24 end
    if weaponType == "Revolver" then rowsCap = 20 end
    if weaponType == "Shotgun"  then rowsCap = 18 end

    local rows = math.min(rowsFit, rowsCap)
    if rows < 1 then rows = 1 end

    local colCount = math.ceil(maxAmmo / rows)
    if colCount < 1 then colCount = 1 end

    local rightX = 400 - 18 - bulletW
    local leftX = rightX - (colCount - 1) * stepX

    local positions = {}
    local idx = 1

    for col = 0, (colCount - 1) do
        local x = leftX + col * stepX
        local bulletsInCol = rows
        
        if col == 0 then
            bulletsInCol = maxAmmo - (colCount - 1) * rows
            if bulletsInCol == 0 then bulletsInCol = rows end
        end

        for r = (bulletsInCol - 1), 0, -1 do
            local y = topY + r * stepY
            positions[idx] = { x = x, y = y }
            idx = idx + 1
        end
    end

    cacheForWeapon[key] = positions
    return positions
end

function UI:drawHud(currentWeapon)
    if playdate.ui and playdate.ui.crankIndicator then
        local ci = playdate.ui.crankIndicator
        local ok = false
        if ci.stop then ok = pcall(function() ci:stop() end) end
        if (not ok) and ci.hide then ok = pcall(function() ci:hide() end) end
        if (not ok) and ci.setVisible then pcall(function() ci:setVisible(false) end) end
    end

    if not currentWeapon then return end

    local weaponType = currentWeapon.weaponType or "Minigun"
    local ammo = currentWeapon.Ammo or 0
    if ammo < 0 then ammo = 0 end

    if self.hudWeaponType ~= weaponType then
        self.hudWeaponType = weaponType
        self.hudMaxAmmo = ammo
    elseif ammo > (self.hudMaxAmmo or 0) then
        self.hudMaxAmmo = ammo
    end

    local maxAmmo = self.hudMaxAmmo or ammo
    if maxAmmo < ammo then maxAmmo = ammo end

    local iconImg = nil
    if weaponType == "Minigun" then iconImg = self.imgMinigunGun end
    if weaponType == "Revolver" then iconImg = self.imgRevolverGun end
    if weaponType == "Shotgun" then iconImg = self.imgShotgunGun end

    if iconImg then
        local w, h = iconImg:getSize()
        local x = 400 - 18 - w
        local y = 12
        iconImg:draw(x, y)
    else
        drawPlaceholderBox(400 - 18 - 48, 12, 48, 24, "WPN")
    end

    local bulletImg = self.imgBulletMinigun
    if weaponType == "Revolver" then bulletImg = self.imgBulletRevolver end
    if weaponType == "Shotgun" then bulletImg = self.imgBulletShotgun end

    local bulletW, bulletH = 6, 6
    if bulletImg then
        bulletW, bulletH = bulletImg:getSize()
    end

    local consumed = maxAmmo - ammo
    if consumed < 0 then consumed = 0 end
    if consumed > maxAmmo then consumed = maxAmmo end

    local positions = self:getBulletPositions(weaponType, maxAmmo, bulletW, bulletH)

    for i = (consumed + 1), maxAmmo do
        local p = positions[i]
        if p then
            if bulletImg then
                bulletImg:draw(p.x, p.y)
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

    if self.screen == "menu" then
        
        if self.imgMainMenuBG then
            self.imgMainMenuBG:draw(0, 0)
        else
            gfx.setColor(gfx.kColorWhite)
            gfx.fillRect(0, 0, 400, 240)
        end
        
        -- Make sure we are drawing in standard mode (black pixels draw as black)
        local prevMode = gfx.getImageDrawMode()
        gfx.setImageDrawMode(gfx.kDrawModeCopy)
        gfx.setColor(gfx.kColorBlack)

        local startY = 130 
        local lineH = 22

        for i, label in ipairs(self.menuOptions) do
            local isSelected = (i == self.menuIndex)
            
            -- Replicate exact old string math so text shifts slightly when selected
            local prefix = isSelected and "> " or "  "
            local tw, th = gfx.getTextSize(prefix .. label)
            local startX = (400 - tw) / 2
            
            -- Find where the actual word starts after the prefix
            local prefixW, _ = gfx.getTextSize(prefix)
            local textX = startX + prefixW
            local itemY = startY + (i - 1) * lineH
            
            -- Draw the label itself
            gfx.drawText(label, textX, itemY)
            
            -- Draw the bullet image where the ">" would have been
            if isSelected and self.imgMenuCursor then
                local cw, ch = self.imgMenuCursor:getSize()
                -- Center the bullet vertically alongside the text
                local cursorY = itemY + math.floor((th - ch) / 2) + 1
                -- Center the bullet horizontally inside the space left by the prefix
                local cursorX = startX + math.floor((prefixW - cw) / 2)
                self.imgMenuCursor:draw(cursorX, cursorY)
            end
        end

        -- Restore previous drawing mode just in case
        gfx.setImageDrawMode(prevMode)
        return
    end

    if self.screen == "howto" then
        local showUp = (self.howtoIndex > 1)
        local showDown = (self.howtoIndex < #self.howtoPages)
        
        gfx.setColor(gfx.kColorWhite)
        gfx.fillRect(0, 0, 400, 240)
        gfx.setColor(gfx.kColorBlack)
        
        local page = self.howtoPages[self.howtoIndex]
        local pageImg = nil
        
        if page.key == "basics1" then pageImg = self.imgBasics1Page
        elseif page.key == "basics2" then pageImg = self.imgBasics2Page
        elseif page.key == "revolver" then pageImg = self.imgRevolverPage
        elseif page.key == "minigun" then pageImg = self.imgMinigunPage
        elseif page.key == "shotgun" then pageImg = self.imgShotgunPage end
        
        if pageImg then pageImg:draw(0, 0) end
        
        if showUp then gfx.fillTriangle(200, 6, 192, 18, 208, 18) end
        if showDown then gfx.fillTriangle(200, 234, 192, 222, 208, 222) end
        
        return
    end

    if self.screen == "credits" then
        local showUp = (self.creditIndex > 1)
        local showDown = (self.creditIndex < #self.creditPages)
        
        gfx.setColor(gfx.kColorWhite)
        gfx.fillRect(0, 0, 400, 240)
        gfx.setColor(gfx.kColorBlack)
        
        local page = self.creditPages[self.creditIndex]
        local pageImg = nil
        
        if page.key == "credits1" then pageImg = self.imgCredits1Page
        elseif page.key == "credits2" then pageImg = self.imgCredits2Page end
        
        if pageImg then pageImg:draw(0, 0) end
        
        if showUp then gfx.fillTriangle(200, 6, 192, 18, 208, 18) end
        if showDown then gfx.fillTriangle(200, 234, 192, 222, 208, 222) end
        
        return
    end
end