class('UI').extends()

local gfx = playdate.graphics

function UI:init()
    -- Default to HUD so that a UI() created in main.lua and used only for gameplay
    -- will not accidentally show menus.
    self.screen = "hud" -- "menu" | "howto" | "credits" | "hud" | "hidden"

    -- Main menu
    self.menuOptions = { "Play", "How to play", "Credits" }
    self.menuIndex = 1

    -- How-to pages (order required by you)
    self.howtoPages = {
        { key="basics",  title="Basics",   text="Shoot the enemies and\nsurvive as long as you\ncan.\n\nUse the arrows to aim\nand the crank to shoot.\n\nWhen you are out of\nammo, shake the\nplaydate to roll the dice\nand gain a new,\nreloaded weapon!" },
        { key="revolver", title="Revolver", text="Spin backward\nuntil you hear the\n'Click', then\nforward until you\nshoot." },
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
    -- with these names (no extension in the code):
    --   basics_main.png, revolver_gun.png, minigun_gun.png, shotgun_gun.png, playdate_icon.png
    self.imgBasicsMain = self:loadImage("images/howto/basics_main")
    self.imgRevolverGun = self:loadImage("images/howto/revolver_gun")
    self.imgMinigunGun  = self:loadImage("images/howto/minigun_gun")
    self.imgShotgunGun  = self:loadImage("images/howto/shotgun_gun")
    self.imgPlaydate    = self:loadImage("images/howto/playdate_icon")
end

-- Safe image loader: returns nil if the file doesn't exist yet
function UI:loadImage(pathNoExt)
    local img = gfx.image.new(pathNoExt)
    return img
end

function UI:setScreen(name)
    self.screen = name
    self.crankAccum = 0

    -- Always start How To at Basics
    if name == "howto" then
        self.howtoIndex = 1
    end
end

-- Used by GameManager to gate main.lua's "press A to start" without touching main.lua.
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

-- Move how-to page: dir = +1 (down/forward) or -1 (up/backward)
function UI:howtoMove(dir)
    local newIndex = self.howtoIndex + dir

    -- Required behavior:
    -- Up on Basics: nothing
    -- Down goes Basics -> Revolver -> Minigun -> Shotgun
    -- Down on Shotgun: nothing
    newIndex = clamp(newIndex, 1, #self.howtoPages)
    self.howtoIndex = newIndex
end

-- Returns an "action" string when user selects something
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

        if playdate.buttonJustPressed(playdate.kButtonA) then
            if self.menuIndex == 1 then return "play" end
            if self.menuIndex == 2 then return "howto" end
            if self.menuIndex == 3 then return "credits" end
        end

        return nil
    end

    -- HOW TO PLAY (4 pages)
    if self.screen == "howto" then
        -- Back to menu
        if playdate.buttonJustPressed(playdate.kButtonB) then
            return "back"
        end

        -- Required arrow behavior
        if playdate.buttonJustPressed(playdate.kButtonDown) then
            self:howtoMove(1)
        elseif playdate.buttonJustPressed(playdate.kButtonUp) then
            self:howtoMove(-1)
        end

        -- Crank behavior: forward = next page, backward = previous page
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

local function drawCenteredText(text, y)
    local w, _ = gfx.getTextSize(text)
    gfx.drawText(text, (400 - w) / 2, y)
end

-- Simple placeholder box if image missing
local function drawPlaceholderBox(x, y, w, h, label)
    gfx.drawRect(x, y, w, h)
    if label then
        gfx.drawText(label, x + 6, y + 6)
    end
end

-- Frame + small triangles like your mockups
local function drawHowtoFrame()
    -- Outer frame
    gfx.setColor(gfx.kColorWhite)
    gfx.fillRect(0, 0, 400, 240)
    gfx.setColor(gfx.kColorBlack)

    -- Border
    gfx.drawRect(10, 10, 380, 220)

    -- Top triangle (up)
    gfx.fillTriangle(200, 6, 192, 18, 208, 18)
    -- Bottom triangle (down)
    gfx.fillTriangle(200, 234, 192, 222, 208, 222)
end

function UI:draw(currentWeapon)
    -- HUD / hidden: only ammo text (same behavior as before)
    if self.screen == "hidden" or self.screen == "hud" then
        if currentWeapon and currentWeapon.Ammo ~= nil then
            gfx.drawText("Ammo: " .. tostring(currentWeapon.Ammo), 10, 10)
        end
        return
    end

    -- MENU
    if self.screen == "menu" then
        drawCenteredText("MAIN MENU", 28)

        local startY = 90
        local lineH = 22
        for i, label in ipairs(self.menuOptions) do
            local prefix = (i == self.menuIndex) and "> " or "  "
            drawCenteredText(prefix .. label, startY + (i - 1) * lineH)
        end

        gfx.drawText("Arrows/Crank: Select   A: Confirm", 10, 220)
        return
    end

    -- HOW TO PLAY (4 screens)
    if self.screen == "howto" then
        drawHowtoFrame()

        local page = self.howtoPages[self.howtoIndex]
        drawCenteredText(page.title, 20)

        -- Layout zones (approx like your mockups)
        -- Left image zone
        local leftX, leftY, leftW, leftH = 30, 60, 170, 130
        -- Right text zone
        local textX, textY = 220, 60

        -- Choose which placeholders to show
        if page.key == "basics" then
            if self.imgBasicsMain then
                self.imgBasicsMain:draw(leftX, leftY)
            else
                drawPlaceholderBox(leftX, leftY, leftW, leftH, "BASICS IMG")
            end

            gfx.drawText(page.text, textX, textY)

        elseif page.key == "revolver" then
            if self.imgRevolverGun then
                self.imgRevolverGun:draw(leftX, leftY)
            else
                drawPlaceholderBox(leftX, leftY, leftW, leftH, "REVOLVER IMG")
            end

            gfx.drawText(page.text, textX, textY)

            -- Playdate icon placeholder (bottom-right)
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

            gfx.drawText(page.text, textX, textY)

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

            gfx.drawText(page.text, textX, textY)

            if self.imgPlaydate then
                self.imgPlaydate:draw(300, 150)
            else
                drawPlaceholderBox(300, 150, 70, 60, "PD")
            end
        end

        -- Navigation hints
        gfx.drawText("Up/Down or Crank: Page    B: Back", 20, 218)
        return
    end

    -- CREDITS (simple)
    if self.screen == "credits" then
        gfx.setColor(gfx.kColorWhite)
        gfx.fillRect(0, 0, 400, 240)
        gfx.setColor(gfx.kColorBlack)

        drawCenteredText("CREDITS", 30)
        gfx.drawText("B: Back", 20, 220)
        return
    end
end
