class('UI').extends()

local gfx = playdate.graphics

function UI:init()
    -- "menu", "howto", "credits", "hud"
    self.screen = "menu"

    -- Main Menu "buttons"
    self.menuOptions = { "Play", "How to play", "Credits" }
    self.menuIndex = 1

    -- For later: scrolling pages/images
    self.scrollY = 0
end

function UI:setScreen(screenName)
    self.screen = screenName

    -- Reset per-screen state
    if screenName == "menu" then
        self.menuIndex = 1
    end
    self.scrollY = 0
end

-- Returns an "action" string when something is selected
function UI:update()
    if self.screen == "menu" then
        if playdate.buttonJustPressed(playdate.kButtonUp) then
            self.menuIndex -= 1
            if self.menuIndex < 1 then self.menuIndex = #self.menuOptions end

        elseif playdate.buttonJustPressed(playdate.kButtonDown) then
            self.menuIndex += 1
            if self.menuIndex > #self.menuOptions then self.menuIndex = 1 end

        elseif playdate.buttonJustPressed(playdate.kButtonA) then
            if self.menuIndex == 1 then return "play" end
            if self.menuIndex == 2 then return "howto" end
            if self.menuIndex == 3 then return "credits" end
        end

        return nil
    end

    -- Info screens: B = back, crank scroll (placeholder for later images)
    if self.screen == "howto" or self.screen == "credits" then
        if playdate.buttonJustPressed(playdate.kButtonB) then
            return "back"
        end

        local crank = playdate.getCrankChange()
        if crank ~= 0 then
            self.scrollY += crank
        end

        return nil
    end

    -- hud: no actions for now
    return nil
end

local function drawCenteredText(text, y)
    local w, h = gfx.getTextSize(text)
    gfx.drawText(text, (400 - w) / 2, y)
end

function UI:draw()
    if self.screen == "menu" then
        drawCenteredText("MAIN MENU", 30)

        local startY = 90
        local lineH = 22

        for i, label in ipairs(self.menuOptions) do
            local prefix = (i == self.menuIndex) and "> " or "  "
            drawCenteredText(prefix .. label, startY + (i - 1) * lineH)
        end

        gfx.drawText("Up/Down: Select   A: Confirm", 10, 220)
        return
    end

    if self.screen == "howto" then
        drawCenteredText("HOW TO PLAY", 20)
        gfx.drawText("Placeholder screen (images later).", 20, 70 + self.scrollY)
        gfx.drawText("Press B to return.", 20, 95 + self.scrollY)
        gfx.drawText("Crank scroll is wired.", 20, 120 + self.scrollY)
        return
    end

    if self.screen == "credits" then
        drawCenteredText("CREDITS", 20)
        gfx.drawText("Placeholder screen (images later).", 20, 70 + self.scrollY)
        gfx.drawText("Press B to return.", 20, 95 + self.scrollY)
        return
    end

    -- hud (in-game UI)
    gfx.drawText("Hello!", 5, 220)
end
