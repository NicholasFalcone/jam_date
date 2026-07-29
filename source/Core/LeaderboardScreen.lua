class('LeaderboardScreen').extends()

import "Core/AudioManager"

local gfx = playdate.graphics

local function formatSurvivalTime(seconds)
    local totalSeconds = math.max(0, tonumber(seconds) or 0)
    local wholeSeconds = math.floor(totalSeconds)
    local minutes = math.floor(wholeSeconds / 60)
    local secs = wholeSeconds % 60
    local centiseconds = math.floor((totalSeconds - wholeSeconds) * 100 + 0.5)

    if centiseconds >= 100 then
        centiseconds = 0
        secs = secs + 1
        if secs >= 60 then
            secs = 0
            minutes = minutes + 1
        end
    end

    return string.format("%02d:%02d:%02d", minutes, secs, centiseconds)
end

local function getEntryName(entry)
    local name = (entry and (entry.playerName or entry.player)) or "Player"
    if type(name) ~= "string" or name == "" then
        name = "Player"
    end
    if #name > 13 then
        return name:sub(1, 10) .. "..."
    end
    return name
end

local function getServerTimeAlive(score)
    local rawValue = tonumber(score and (score.value or score.score)) or 0
    return rawValue / 100
end

-- DISABLED (removes Back / Offline + dots)
local function drawButtonHint(...)
    return
end

local function moveSelection(screen, delta)
    local totalEntries = #screen.leaderboard
    if totalEntries == 0 then
        screen.selectedIndex = 1
        screen.page = 1
        return
    end

    local prevIndex = screen.selectedIndex
    screen.selectedIndex = math.max(1, math.min(totalEntries, screen.selectedIndex + delta))
    if screen.selectedIndex ~= prevIndex and screen.SFX_MenuHighlight then
        pcall(function() screen.SFX_MenuHighlight:play(1) end)
    end

    local firstVisible = ((screen.page - 1) * screen.itemsPerPage) + 1
    local lastVisible = math.min(firstVisible + screen.itemsPerPage - 1, totalEntries)
    local maxPages = math.max(1, math.ceil(totalEntries / screen.itemsPerPage))

    if screen.selectedIndex < firstVisible then
        screen.page = math.max(1, screen.page - 1)
    elseif screen.selectedIndex > lastVisible then
        screen.page = math.min(maxPages, screen.page + 1)
    end
end

function LeaderboardScreen:init()
    self.leaderboard = {}
    self.selectedIndex = 1
    self.page = 1
    self.itemsPerPage = 5
    self.crankAccum = 0
    self.crankStep = 18
    
    self.showingServerScores = false
    self.serverScores = nil
    self.isFetching = false
    local bgPathsToTry = {
        "Sprites/Leaderboar_Background",
        "sprites/Leaderboar_Background",
        "Leaderboar_Background"
    }
    for _, path in ipairs(bgPathsToTry) do
        self.backgroundImage = gfx.image.new(path)
        if self.backgroundImage then break end
    end
    if not self.backgroundImage then
        print("LeaderboardScreen: failed to load background image 'Leaderboar_Background' - check it's in source/Sprites/ and that you rebuilt the pdx")
    end

    self.overlayLocal = gfx.image.new("Sprites/Leaderbard_Text_Local")
    self.overlayGlobal = gfx.image.new("Sprites/Leaderbard_Text_Global")
    
    if not self.overlayLocal then
        print("LeaderboardScreen: failed to load 'Sprites/Leaderbard_Text_Local'")
    end
    if not self.overlayGlobal then
        print("LeaderboardScreen: failed to load 'Sprites/Leaderbard_Text_Global'")
    end
    self.selectionImage  = gfx.image.new("Sprites/Leaderboar_Selection")
    self.crownImage      = gfx.image.new("Sprites/Crown")
    
    local audioManager = AudioManager()
    self.SFX_ChangePage    = audioManager:loadSample("sounds/SFX_Ui_ChangePage")
    self.SFX_MenuHighlight = audioManager:loadSample("sounds/SFX_Menu_Highlight")
    self.SFX_UIClick       = audioManager:loadSample("sounds/SFX_UIClick")
end

function LeaderboardScreen:setGameManager(gameManager)
    self.gameManager = gameManager
    self:updateLeaderboard()
end

function LeaderboardScreen:updateLeaderboard()
    if not self.gameManager then return end
    
    local source = {}
    if self.showingServerScores and self.serverScores and #self.serverScores > 0 then
        source = self.serverScores
    else
        source = self.gameManager:getTopTimeAlive(50)
    end
    self.leaderboard = source or {}
    
    self.page = 1
    self.selectedIndex = 1
end

function LeaderboardScreen:update()
    if playdate.buttonJustPressed(playdate.kButtonB) then
        return
    end

    if playdate.buttonJustPressed(playdate.kButtonA) and not self.isFetching and self.gameManager then
        local dataManager = self.gameManager.dataManager
        if self.showingServerScores then
            if self.SFX_UIClick then pcall(function() self.SFX_UIClick:play(1) end) end
            self.showingServerScores = false
            self:updateLeaderboard()
            if self.SFX_ChangePage then
                pcall(function() self.SFX_ChangePage:play(1) end)
            end
        elseif dataManager and dataManager:isOnlineSyncAvailable() then
            if self.SFX_UIClick then pcall(function() self.SFX_UIClick:play(1) end) end
            self:fetchServerScores(dataManager)
            if self.SFX_ChangePage then
                pcall(function() self.SFX_ChangePage:play(1) end)
            end
        end
    end
 
    local totalEntries = #self.leaderboard
    local maxPages = math.max(1, math.ceil(totalEntries / self.itemsPerPage))
    
    if totalEntries == 0 then
        self.selectedIndex = 1
        self.page = 1
        return
    end

    if playdate.buttonJustPressed(playdate.kButtonUp) or playdate.buttonJustPressed(playdate.kButtonLeft) then
        moveSelection(self, -1)
    elseif playdate.buttonJustPressed(playdate.kButtonDown) or playdate.buttonJustPressed(playdate.kButtonRight) then
        moveSelection(self, 1)
    end
    
    local crankDelta = playdate.getCrankChange()
    if crankDelta ~= 0 then
        self.crankAccum = self.crankAccum + crankDelta
        
        while self.crankAccum >= self.crankStep do
            self.crankAccum = self.crankAccum - self.crankStep
            moveSelection(self, -1)
        end
        
        while self.crankAccum <= -self.crankStep do
            self.crankAccum = self.crankAccum + self.crankStep
            moveSelection(self, 1)
        end
    end

    self.page = math.max(1, math.min(self.page, maxPages))
end

function LeaderboardScreen:fetchServerScores(dataManager)
    if not dataManager or self.isFetching then return end
    
    self.isFetching = true
    
    dataManager:fetchScoresFromServer(function(result, error)
        self.isFetching = false
        
        if result and result.scores and #result.scores > 0 then
            self.serverScores = {}
            for _, score in ipairs(result.scores) do
                local playerName = score.player or score.playerName or "Player"
                table.insert(self.serverScores, {
                    rank = score.rank,
                    player = playerName,
                    playerName = playerName,
                    isServerScore = true,
                    timeAlive = getServerTimeAlive(score)
                })
            end
            self.showingServerScores = true
            self:updateLeaderboard()
        else
            self.showingServerScores = false
            self.serverScores = nil
            self:updateLeaderboard()
        end
    end)
end

function LeaderboardScreen:draw(g)
    if self.backgroundImage then
        self.backgroundImage:draw(0, 0)
    else
        g.setColor(g.kColorWhite)
        g.fillRect(0, 0, 400, 240)
    end
    local currentOverlay = self.showingServerScores and self.overlayGlobal or self.overlayLocal
    if currentOverlay then
        currentOverlay:draw(0, 0)
    end

    -- REMOVED TOP WHITE RECTANGLES

    g.setColor(g.kColorBlack)

    local rowX = 122
    local rowW = 156
    local rowH = 26
    local rowGap = 6
    local startY = 58
    local startIdx = ((self.page - 1) * self.itemsPerPage) + 1
    local endIdx = math.min(startIdx + self.itemsPerPage - 1, #self.leaderboard)
    
    if #self.leaderboard == 0 then
        local emptyText = "No runs yet"
        if self.showingServerScores then
            emptyText = "No global times"
        end
        g.setColor(g.kColorWhite)
        g.fillRect(rowX, 108, rowW, rowH)
        g.setColor(g.kColorBlack)
        g.drawRect(rowX, 108, rowW, rowH)
        g.drawTextAligned(emptyText, 200, 114, kTextAlignment.center)
    else
        for i = startIdx, endIdx do
            local entry = self.leaderboard[i]
            if entry then
                local isSelected = (i == self.selectedIndex)
                local visibleIndex = i - startIdx
                local y = startY + (visibleIndex * (rowH + rowGap))
                local rank = entry.rank or i

                g.setColor(g.kColorBlack)
                g.fillRect(rowX - 6, y, 4, rowH)
                g.fillRect(rowX + rowW + 2, y, 4, rowH)

                if isSelected then
                    g.setColor(g.kColorWhite)
                    g.fillRect(rowX, y, rowW, rowH)
                    if self.selectionImage then
                        local imgW, imgH = self.selectionImage:getSize()
                        local imgX = rowX + math.floor((rowW - imgW) / 2)
                        local imgY = y + math.floor((rowH - imgH) / 2) + 2
                        self.selectionImage:draw(imgX, imgY)
                    end
                else
                    g.setColor(g.kColorWhite)
                    g.fillRect(rowX, y, rowW, rowH)
                    g.setColor(g.kColorBlack)
                    g.drawRect(rowX, y, rowW, rowH)
                end

                g.drawTextAligned(tostring(rank), rowX + 10, y + 5, kTextAlignment.left)
                if self.showingServerScores then
                    -- Global leaderboard: player name + time on the right (unchanged)
                    g.drawText(getEntryName(entry), rowX + 34, y + 5)
                    g.drawTextAligned(formatSurvivalTime(entry.timeAlive), rowX + rowW - 10, y + 5, kTextAlignment.right)
                else
                    -- Local leaderboard: no player name, time centered, crown on rank 1
                    g.drawTextAligned(formatSurvivalTime(entry.timeAlive), rowX + math.floor(rowW / 2), y + 5, kTextAlignment.center)
                    if rank == 1 and self.crownImage then
                        local cw, ch = self.crownImage:getSize()
                        local cx = rowX + rowW - cw - 4
                        local cy = y + math.floor((rowH - ch) / 2) + 1
                        self.crownImage:draw(cx, cy)
                    end
                end
            end
        end
    end

    local totalEntries = #self.leaderboard
    local maxPages = math.max(1, math.ceil(totalEntries / self.itemsPerPage))
    if maxPages > 1 then
        g.setColor(g.kColorWhite)
        g.fillRect(170, 214, 60, 16)
        g.setColor(g.kColorBlack)
        g.drawTextAligned(tostring(self.page) .. "/" .. tostring(maxPages), 200, 214, kTextAlignment.center)
    end

    -- BUTTON HINTS REMOVED
end

return LeaderboardScreen