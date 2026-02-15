class('UI').extends()

local gfx = playdate.graphics

function UI:init()
    -- Default to HUD so UI() created in main.lua (for gameplay) doesn't show the menu
    self.screen = "hud" -- "menu" | "howto" | "credits" | "hud" | "hidden"

    -- Fonts: bold for titles, normal for body
    self.fontTitle = gfx.getSystemFont(gfx.font.kVariantBold)
    self.fontBody  = gfx.getSystemFont(gfx.font.kVariantNormal)

    -- Main menu
    self.menuOptions = { "Play", "How to play", "Credits" }
    self.menuIndex = 1

    -- How-to pages (order required)
    self.howtoPages = {
        { key="basics",  title="Basics",   text="Shoot the enemies and\nsurvive as long as you\ncan.\n\nUse the arrows to aim\nand the crank to shoot.\n\nWhen you are out of\nammo, shake the\nplaydate to roll the dice\nand gain a new,\nreloaded weapon!" },
        { key="revolver", title="Revolver", text="Spin backward\nuntil you hear the\n\"Click\", then\nforward until you\nshoot." },
        { key="minigun",  title="Minigun",  text="Spin forward fast\nenough to shoot.\nShooting without\nstopping increase\nrate of fire." },
        { key="shotgun",  title="Shotgun",  text="Spin a full circle to\nshoot. Wait the\nrecharge sound to\nshoot again." }
    }
    self.howtoIndex = 1

    -- Crank navigation
    self.crankAccum = 0
    self.crankStepDegMenu = 18
    self.crankStepDegHowto = 25

    -- Placeholder images (safe if missing)
    -- Put your images later in:
    --   source/images/howto/
    -- names (no extension in code):
    --   basics_main.png, revolver_gun.png, minigun_gun.png, shotgun_gun.png, playdate_icon.png
    self.imgBasicsMain = self:loadImage("images/howto/basics_main")
    self.imgRevolverGun = self:loadImage("images/howto/revolver_gun")
    self.imgMinigunGun  = self:loadImage("images/howto/minigun_gun")
    self.imgShotgunGun  = self:loadImage("images/howto/shotgun_gun")
    self.imgPlaydate    = self:loadImage("images/howto/playdate_icon")
end

function UI:loadImage(pathNoExt)
    return gfx.image.new(pathNoExt) -- returns nil if missing
end

function UI:setScreen(name)
    self.screen = name
    self.crankAccum = 0
    if name == "howto" then
        self.howtoIndex = 1
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
    local newIndex = self.howtoIndex + dir
    newIndex = clamp(newIndex, 1, #self.howtoPages)
    self.howtoIndex = newIndex
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

    -- HOW TO PLAY
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
        return nil
    end

    return nil
end

local function drawPlaceholderBox(x, y, w, h, label)
    gfx.drawRect(x, y, w, h)
    if label then
        gfx.setFont(gfx.getSystemFont(gfx.font.kVariantNormal))
        gfx.drawText(label, x + 6, y + 6)
    end
end

local function drawHowtoFrame(showUp, showDown)
    gfx.setColor(gfx.kColorWhite)
    gfx.fillRect(0, 0, 400, 240)
    gfx.setColor(gfx.kColorBlack)

    gfx.drawRect(10, 10, 380, 220)

    -- Conditional arrows
    if showUp then
        gfx.fillTriangle(200, 6, 192, 18, 208, 18)
    end
    if showDown then
        gfx.fillTriangle(200, 234, 192, 222, 208, 222)
    end
end

local function drawCenteredBoldTitle(ui, text, y)
    gfx.setFont(ui.fontTitle)

    local w, _ = gfx.getTextSize(text)
    local x = (400 - w) / 2

    -- draw twice (slightly thicker = reads “bigger”)
    gfx.drawText(text, x, y)
    gfx.drawText(text, x, y + 1)
end

local function drawBackBottomRight(ui)
    gfx.setFont(ui.fontBody)
    local label = "B: Back"
    local w, _ = gfx.getTextSize(label)
    local x = 400 - w - 18
    local y = 240 - 28 -- "a bit up"
    gfx.drawText(label, x, y)
end

function UI:draw(currentWeapon)
    -- HUD / hidden: only ammo
    if self.screen == "hidden" or self.screen == "hud" then
        if currentWeapon and currentWeapon.Ammo ~= nil then
            gfx.setFont(self.fontBody)
            gfx.drawText("Ammo: " .. tostring(currentWeapon.Ammo), 10, 10)
        end
        return
    end

    -- MENU
    if self.screen == "menu" then
        gfx.setColor(gfx.kColorWhite)
        gfx.fillRect(0, 0, 400, 240)
        gfx.setColor(gfx.kColorBlack)

        drawCenteredBoldTitle(self, "MAIN MENU", 26)

        gfx.setFont(self.fontBody)
        local startY = 92
        local lineH = 22
        for i, label in ipairs(self.menuOptions) do
            local prefix = (i == self.menuIndex) and "> " or "  "
            local txt = prefix .. label
            local w, _ = gfx.getTextSize(txt)
            gfx.drawText(txt, (400 - w) / 2, startY + (i - 1) * lineH)
        end

        gfx.drawText("Arrows/Crank: Select   A: Confirm", 10, 220)
        return
    end

    -- HOW TO PLAY
    if self.screen == "howto" then
        local showUp = (self.howtoIndex > 1)
        local showDown = (self.howtoIndex < #self.howtoPages)

        -- Your special rule: Basics only down, Shotgun only up, middle both
        drawHowtoFrame(showUp, showDown)

        local page = self.howtoPages[self.howtoIndex]
        drawCenteredBoldTitle(self, page.title, 18)

        -- Layout
        local leftX, leftY, leftW, leftH = 30, 60, 170, 130
        local textX, textY = 200, 60

        gfx.setFont(self.fontBody)

        if page.key == "basics" then
            if self.imgBasicsMain then
                self.imgBasicsMain:draw(leftX, leftY)
            else
                drawPlaceholderBox(leftX, leftY, leftW, leftH, "BASICS IMG")
            end
            gfx.drawTextInRect(page.text, textX, textY, 170, 150)


        elseif page.key == "revolver" then
            if self.imgRevolverGun then
                self.imgRevolverGun:draw(leftX, leftY)
            else
                drawPlaceholderBox(leftX, leftY, leftW, leftH, "REVOLVER IMG")
            end
            gfx.drawTextInRect(page.text, textX, textY, 170, 150)


            if self.imgPlaydate then
                self.imgPlaydate:draw(300, 150)
            else
                drawPlaceholderBox(300, 150, 70, 60, "PD")
            end

        elseif page.key == "minigun" then
            if self.imgMinigunGun then
                self.imgMinigunGun:draw(leftX, leftY)
            else
                drawPlaceholderBox(leftX, leftY, leftW, leftH, "MINIGUN IMG")
            end
            gfx.drawTextInRect(page.text, textX, textY, 170, 150)


            if self.imgPlaydate then
                self.imgPlaydate:draw(300, 150)
            else
                drawPlaceholderBox(300, 150, 70, 60, "PD")
            end

        elseif page.key == "shotgun" then
            if self.imgShotgunGun then
                self.imgShotgunGun:draw(leftX, leftY)
            else
                drawPlaceholderBox(leftX, leftY, leftW, leftH, "SHOTGUN IMG")
            end
            gfx.drawTextInRect(page.text, textX, textY, 170, 150)


            if self.imgPlaydate then
                self.imgPlaydate:draw(300, 150)
            else
                drawPlaceholderBox(300, 150, 70, 60, "PD")
            end
        end

        -- Removed the "Up/Down or Crank..." line (per request)
        drawBackBottomRight(self)
        return
    end

    -- CREDITS
    if self.screen == "credits" then
        gfx.setColor(gfx.kColorWhite)
        gfx.fillRect(0, 0, 400, 240)
        gfx.setColor(gfx.kColorBlack)

        drawCenteredBoldTitle(self, "CREDITS", 26)

        gfx.setFont(self.fontBody)
        drawBackBottomRight(self)
        return
    end
end
