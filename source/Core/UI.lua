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

    -- How-to full page images (put in: source/images/howto/)
    -- These are complete page images with all text and graphics included
    self.imgBasics1Page  = self:loadImage("images/howto/BASICS_1-dithered")
    self.imgBasics2Page  = self:loadImage("images/howto/BASICS2_1-dithered")
    self.imgRevolverPage = self:loadImage("images/howto/REVOLVER_1-dithered")
    self.imgMinigunPage  = self:loadImage("images/howto/MINIGUN_1-dithered")
    self.imgShotgunPage  = self:loadImage("images/howto/SHOTGUN_1-dithered")

    -- Credits full page images (put in: source/images/credits/)
    -- Page 1: SFX Credits, Page 2: Team Faces
    self.imgCredits1Page = self:loadImage("images/credits/CREDITS_2-dithered")
    self.imgCredits2Page = self:loadImage("images/credits/CREDITS_1-dithered")

    -- Keep weapon icons for HUD (different from how-to pages now)
    self.imgRevolverGun = self:loadImage("images/howto/revolver_gun")
    self.imgMinigunGun  = self:loadImage("images/howto/minigun_gun")
    self.imgShotgunGun  = self:loadImage("images/howto/shotgun_gun")

    -- HUD bullet sprites (safe if missing)
    -- Put these in: source/images/ui/
    -- names:
    -- Bullet_Shotgun.png, Bullet_Revolver.png, Bullet_Minigun.png
    self.imgBulletShotgun  = self:loadImage("images/ui/Bullet_Shotgun")
    self.imgBulletRevolver = self:loadImage("images/ui/Bullet_Revolver")
    self.imgBulletMinigun  = self:loadImage("images/ui/Bullet_Minigun")

    -- HUD ammo tracking
    self.hudWeaponType = nil
    self.hudMaxAmmo = 0

    -- Bullet layout cache: cache[weaponType][maxAmmo] = { {x=...,y=...}, ... }
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

-- Used by GameManager to gate main.lua's "press A" start without touching main.lua
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
    
    -- Play sound only if page actually changed
    if self.howtoIndex ~= oldIndex and self.SFX_ChangePage then
        pcall(function() self.SFX_ChangePage:play(1) end)
    end
end

function UI:creditsMove(dir)
    local oldIndex = self.creditIndex
    local newIndex = self.creditIndex + dir
    self.creditIndex = clamp(newIndex, 1, #self.creditPages)
    
    -- Play sound only if page actually changed
    if self.creditIndex ~= oldIndex and self.SFX_ChangePage then
        pcall(function() self.SFX_ChangePage:play(1) end)
    end
end

-- ---------- UPDATE ----------

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

        -- Crank navigation (menu)
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

        -- Confirm
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

        -- Crank: forward = next, backward = previous
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

        -- Crank: forward = next, backward = previous
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

-- ---------- DRAW HELPERS ----------

local function drawPlaceholderBox(x, y, w, h, label)
    gfx.drawRect(x, y, w, h)
    if label then
        gfx.drawText(label, x + 6, y + 6)
    end
end

-- Build bullet positions mapping perfectly to the consumption order
function UI:getBulletPositions(weaponType, maxAmmo, bulletW, bulletH)
    self.bulletPosCache[weaponType] = self.bulletPosCache[weaponType] or {}
    local cacheForWeapon = self.bulletPosCache[weaponType]

    local key = tostring(maxAmmo) .. ":" .. tostring(bulletW) .. "x" .. tostring(bulletH)
    if cacheForWeapon[key] then
        return cacheForWeapon[key]
    end

    -- Position restored to 54 to match the original placement right under the gun
    local topY = 54 
    local bottomY = 226

    local stepY = bulletH + 2
    local stepX = bulletW + 3

    -- rows that physically fit
    local rowsFit = math.floor((bottomY - topY) / stepY)
    if rowsFit < 1 then rowsFit = 1 end

    -- rows that we WANT visually 
    local rowsCap = 20
    if weaponType == "Minigun" then rowsCap = 24 end
    if weaponType == "Revolver" then rowsCap = 20 end
    if weaponType == "Shotgun"  then rowsCap = 18 end

    -- final rows per column
    local rows = math.min(rowsFit, rowsCap)
    if rows < 1 then rows = 1 end

    local colCount = math.ceil(maxAmmo / rows)
    if colCount < 1 then colCount = 1 end

    -- Align grid starting from the right side of the screen
    local rightX = 400 - 18 - bulletW
    -- Calculate leftmost column's X position
    local leftX = rightX - (colCount - 1) * stepX

    local positions = {}
    local idx = 1

    -- Loop left-to-right columns
    for col = 0, (colCount - 1) do
        local x = leftX + col * stepX
        local bulletsInCol = rows
        
        -- Leftmost column takes the remainder; rightmost columns are completely full
        if col == 0 then
            bulletsInCol = maxAmmo - (colCount - 1) * rows
            if bulletsInCol == 0 then bulletsInCol = rows end
        end

        -- Iterate from the bottom-most bullet to the top-most bullet to set the order of consumption.
        -- Visually, they are always placed from topY and flow downwards.
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
    -- Hide/stop the system crank indicator (robust across SDK versions)
    if playdate.ui and playdate.ui.crankIndicator then
        local ci = playdate.ui.crankIndicator
        local ok = false

        if ci.stop then
            ok = pcall(function() ci:stop() end)
        end
        if (not ok) and ci.hide then
            ok = pcall(function() ci:hide() end)
        end
        if (not ok) and ci.setVisible then
            pcall(function() ci:setVisible(false) end)
        end
    end

    if not currentWeapon then return end

    local weaponType = currentWeapon.weaponType or "Minigun"
    local ammo = currentWeapon.Ammo or 0
    if ammo < 0 then ammo = 0 end

    -- Detect weapon change or reload -> reset max ammo
    if self.hudWeaponType ~= weaponType then
        self.hudWeaponType = weaponType
        self.hudMaxAmmo = ammo
    elseif ammo > (self.hudMaxAmmo or 0) then
        -- reload (ammo increased)
        self.hudMaxAmmo = ammo
    end

    local maxAmmo = self.hudMaxAmmo or ammo
    if maxAmmo < ammo then maxAmmo = ammo end

    -- Weapon icon (top-right): use same images as how-to
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
        -- fallback placeholder
        drawPlaceholderBox(400 - 18 - 48, 12, 48, 24, "WPN")
    end

    -- Bullet sprite by weapon type
    local bulletImg = self.imgBulletMinigun
    if weaponType == "Revolver" then bulletImg = self.imgBulletRevolver end
    if weaponType == "Shotgun" then bulletImg = self.imgBulletShotgun end

    local bulletW, bulletH = 6, 6
    if bulletImg then
        bulletW, bulletH = bulletImg:getSize()
    end

    -- Calculate how many bullets are missing
    local consumed = maxAmmo - ammo
    if consumed < 0 then consumed = 0 end
    if consumed > maxAmmo then consumed = maxAmmo end

    -- Get positions mapped exactly to consumption order
    local positions = self:getBulletPositions(weaponType, maxAmmo, bulletW, bulletH)

    -- Because positions are perfectly ordered by consumption (idx 1 = Left, Bottom),
    -- we simply skip the first 'consumed' indices to draw the remaining bullets.
    for i = (consumed + 1), maxAmmo do
        local p = positions[i]
        if p then
            if bulletImg then
                bulletImg:draw(p.x, p.y)
            else
                -- fallback bullet
                gfx.fillRect(p.x, p.y, bulletW, bulletH)
            end
        end
    end
end

-- ---------- DRAW ----------

function UI:draw(currentWeapon)
    -- HUD / hidden
    if self.screen == "hidden" or self.screen == "hud" then
        self:drawHud(currentWeapon)
        return
    end

    -- MENU
    if self.screen == "menu" then
        gfx.setColor(gfx.kColorWhite)
        gfx.fillRect(0, 0, 400, 240)
        gfx.setColor(gfx.kColorBlack)

        local w, _ = gfx.getTextSize("MAIN MENU")
        gfx.drawText("MAIN MENU", (400 - w) / 2, 28)

        local startY = 90
        local lineH = 22
        for i, label in ipairs(self.menuOptions) do
            local prefix = (i == self.menuIndex) and "> " or "  "
            local tw, _ = gfx.getTextSize(prefix .. label)
            gfx.drawText(prefix .. label, (400 - tw) / 2, startY + (i - 1) * lineH)
        end

        return
    end

    -- HOW TO PLAY
    if self.screen == "howto" then
        local showUp = (self.howtoIndex > 1)
        local showDown = (self.howtoIndex < #self.howtoPages)
        
        -- White background
        gfx.setColor(gfx.kColorWhite)
        gfx.fillRect(0, 0, 400, 240)
        gfx.setColor(gfx.kColorBlack)
        
        -- Draw the appropriate full-page image based on current index
        local page = self.howtoPages[self.howtoIndex]
        local pageImg = nil
        
        if page.key == "basics1" then
            pageImg = self.imgBasics1Page
        elseif page.key == "basics2" then
            pageImg = self.imgBasics2Page
        elseif page.key == "revolver" then
            pageImg = self.imgRevolverPage
        elseif page.key == "minigun" then
            pageImg = self.imgMinigunPage
        elseif page.key == "shotgun" then
            pageImg = self.imgShotgunPage
        end
        
        -- Draw the full-page image (it includes all text, graphics, borders, etc.)
        if pageImg then
            pageImg:draw(0, 0)
        end
        
        -- Draw navigation arrows on top (black)
        if showUp then
            gfx.fillTriangle(200, 6, 192, 18, 208, 18)
        end
        if showDown then
            gfx.fillTriangle(200, 234, 192, 222, 208, 222)
        end
        
        return
    end

    -- CREDITS
    if self.screen == "credits" then
        local showUp = (self.creditIndex > 1)
        local showDown = (self.creditIndex < #self.creditPages)
        
        -- White background
        gfx.setColor(gfx.kColorWhite)
        gfx.fillRect(0, 0, 400, 240)
        gfx.setColor(gfx.kColorBlack)
        
        -- Draw the appropriate full-page image based on current index
        local page = self.creditPages[self.creditIndex]
        local pageImg = nil
        
        if page.key == "credits1" then
            pageImg = self.imgCredits1Page
        elseif page.key == "credits2" then
            pageImg = self.imgCredits2Page
        end
        
        -- Draw the full-page image (it includes all text, graphics, borders, etc.)
        if pageImg then
            pageImg:draw(0, 0)
        end
        
        -- Draw navigation arrows on top (black)
        if showUp then
            gfx.fillTriangle(200, 6, 192, 18, 208, 18)
        end
        if showDown then
            gfx.fillTriangle(200, 234, 192, 222, 208, 222)
        end
        
        return
    end
end