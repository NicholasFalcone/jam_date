class('UI').extends()

local gfx = playdate.graphics

function UI:init()
self.screen = "menu" -- "menu" | "howto" | "credits" | "hud" | "hidden"

    self.menuOptions = { "Play", "How to play", "Credits" }
    self.menuIndex = 1

    -- Crank navigation
    self.crankAccum = 0
    self.crankStepDeg = 18 -- smaller = more sensitive

    -- For later scrolling screens
    self.scrollY = 0
end

function UI:setScreen(name)
    self.screen = name
    self.crankAccum = 0
    self.scrollY = 0
end

local function wrapIndex(i, count)
    if i < 1 then return count end
    if i > count then return 1 end
    return i
end

-- Returns an "action" string when the user selects something
function UI:update()
    if self.screen == "hidden" or self.screen == "hud" then
        return nil
    end

    -- MENU
    if self.screen == "menu" then
        -- D-pad navigation
        if playdate.buttonJustPressed(playdate.kButtonUp) or playdate.buttonJustPressed(playdate.kButtonLeft) then
            self.menuIndex = wrapIndex(self.menuIndex - 1, #self.menuOptions)
        elseif playdate.buttonJustPressed(playdate.kButtonDown) or playdate.buttonJustPressed(playdate.kButtonRight) then
            self.menuIndex = wrapIndex(self.menuIndex + 1, #self.menuOptions)
        end

        -- Crank navigation
        local crankDelta = playdate.getCrankChange()
        if crankDelta ~= 0 then
            self.crankAccum = self.crankAccum + crankDelta

            while self.crankAccum >= self.crankStepDeg do
                self.crankAccum = self.crankAccum - self.crankStepDeg
                self.menuIndex = wrapIndex(self.menuIndex + 1, #self.menuOptions)
            end

            while self.crankAccum <= -self.crankStepDeg do
                self.crankAccum = self.crankAccum + self.crankStepDeg
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

    -- HOWTO / CREDITS screens
    if self.screen == "howto" or self.screen == "credits" then
        if playdate.buttonJustPressed(playdate.kButtonB) then
            return "back"
        end

        -- simple scrolling placeholder (crank)
        local crankDelta = playdate.getCrankChange()
        if crankDelta ~= 0 then
            self.scrollY = self.scrollY + crankDelta
        end

        -- optional: also allow arrows to scroll
        if playdate.buttonIsPressed(playdate.kButtonUp) then self.scrollY = self.scrollY + 2 end
        if playdate.buttonIsPressed(playdate.kButtonDown) then self.scrollY = self.scrollY - 2 end

        return nil
    end

    -- HUD (in-game)
    return nil
end

local function drawCenteredText(text, y)
    local w, _ = gfx.getTextSize(text)
    gfx.drawText(text, (400 - w) / 2, y)
end

function UI:draw(currentWeapon)
    -- Gameplay overlay (ammo in top-left)
    if self.screen == "hidden" or self.screen == "hud" then
        if currentWeapon and currentWeapon.Ammo ~= nil then
            gfx.drawText("Ammo: " .. tostring(currentWeapon.Ammo), 10, 10)
        end
        return
    end

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

    if self.screen == "howto" then
        drawCenteredText("HOW TO PLAY", 20)
        gfx.drawText("Placeholder (images later).", 20, 70 + self.scrollY)
        gfx.drawText("B: Back", 20, 95 + self.scrollY)
        return
    end

    if self.screen == "credits" then
        drawCenteredText("CREDITS", 20)
        gfx.drawText("Placeholder (images later).", 20, 70 + self.scrollY)
        gfx.drawText("B: Back", 20, 95 + self.scrollY)
        return
    end
end
