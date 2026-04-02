class('LeaderboardScreen').extends()

import "Core/AudioManager"

local gfx = playdate.graphics

function LeaderboardScreen:init()
    self.leaderboard = {}
    self.selectedIndex = 1
    self.sortMode = "score"  -- "score", "time", "enemies"
    self.page = 1
    self.itemsPerPage = 10
    self.crankAccum = 0
    self.crankStep = 18
    
    -- Server sync
    self.showingServerScores = false
    self.serverScores = nil
    self.isFetching = false
    self.lastFetchTime = 0
    
    local audioManager = AudioManager()
    self.SFX_ChangePage = audioManager:loadSample("sounds/SFX_Ui_ChangePage")
end

function LeaderboardScreen:setGameManager(gameManager)
    self.gameManager = gameManager
    self:updateLeaderboard()
end

function LeaderboardScreen:updateLeaderboard()
    if not self.gameManager then return end
    
    -- Use local leaderboard or server scores if showing
    local source = self.serverScores or self.gameManager:getFullLeaderboard()
    self.leaderboard = source
    
    self.page = 1
    self.selectedIndex = 1
end

function LeaderboardScreen:update()
    -- Handle fetching server scores (Y button or similar)
    if playdate.buttonJustPressed(playdate.kButtonB) then
        -- B button will handle back navigation in parent
        return
    end
    
    -- Up button can also fetch/refresh server scores if available
    if playdate.buttonJustPressed(playdate.kButtonUp) and not self.isFetching then
        if self.gameManager then
            local dataManager = self.gameManager.dataManager
            if dataManager and dataManager:isOnlineSyncAvailable() then
                self:fetchServerScores(dataManager)
                return  -- Don't process normal up navigation while fetching
            end
        end
    end
    
    -- Handle sorting mode change (Left/Right)
    if playdate.buttonJustPressed(playdate.kButtonLeft) then
        if self.sortMode == "score" then
            self.sortMode = "enemies"
        elseif self.sortMode == "time" then
            self.sortMode = "score"
        elseif self.sortMode == "enemies" then
            self.sortMode = "time"
        end
        self:updateLeaderboard()
        if self.SFX_ChangePage then
            pcall(function() self.SFX_ChangePage:play(1) end)
        end
    elseif playdate.buttonJustPressed(playdate.kButtonRight) then
        if self.sortMode == "score" then
            self.sortMode = "time"
        elseif self.sortMode == "time" then
            self.sortMode = "enemies"
        elseif self.sortMode == "enemies" then
            self.sortMode = "score"
        end
        self:updateLeaderboard()
        if self.SFX_ChangePage then
            pcall(function() self.SFX_ChangePage:play(1) end)
        end
    end
    
    -- Handle up/down and crank for list navigation
    local maxVisible = self.itemsPerPage
    local totalEntries = #self.leaderboard
    local maxPages = math.ceil(totalEntries / maxVisible)
    
    if playdate.buttonJustPressed(playdate.kButtonUp) then
        self.selectedIndex = math.max(1, self.selectedIndex - 1)
        if self.selectedIndex < ((self.page - 1) * maxVisible + 1) then
            self.page = math.max(1, self.page - 1)
        end
    elseif playdate.buttonJustPressed(playdate.kButtonDown) then
        self.selectedIndex = math.min(totalEntries, self.selectedIndex + 1)
        if self.selectedIndex > (self.page * maxVisible) then
            self.page = math.min(maxPages, self.page + 1)
        end
    end
    
    local crankDelta = playdate.getCrankChange()
    if crankDelta ~= 0 then
        self.crankAccum = self.crankAccum + crankDelta
        
        while self.crankAccum >= self.crankStep do
            self.crankAccum = self.crankAccum - self.crankStep
            self.selectedIndex = math.max(1, self.selectedIndex - 1)
            if self.selectedIndex < ((self.page - 1) * maxVisible + 1) then
                self.page = math.max(1, self.page - 1)
            end
        end
        
        while self.crankAccum <= -self.crankStep do
            self.crankAccum = self.crankAccum + self.crankStep
            self.selectedIndex = math.min(totalEntries, self.selectedIndex + 1)
            if self.selectedIndex > (self.page * maxVisible) then
                self.page = math.min(maxPages, self.page + 1)
            end
        end
    end
end

function LeaderboardScreen:fetchServerScores(dataManager)
    if not dataManager or self.isFetching then return end
    
    self.isFetching = true
    
    dataManager:fetchScoresFromServer(function(result, error)
        self.isFetching = false
        
        if result and result.scores then
            -- Convert server score format to our format
            self.serverScores = {}
            for _, score in ipairs(result.scores) do
                table.insert(self.serverScores, {
                    rank = score.rank,
                    player = score.player,
                    score = score.value,
                    isServerScore = true,
                    timeAlive = 0,
                    enemiesDefeated = 0,
                    waveCount = 0
                })
            end
            self.showingServerScores = true
            self:updateLeaderboard()
        else
            -- Fall back to local scores
            self.showingServerScores = false
            self.serverScores = nil
            self:updateLeaderboard()
        end
    end)
end

function LeaderboardScreen:draw(g)
    g.setColor(g.kColorWhite)
    g.fillRect(0, 0, 400, 240)
    g.setColor(g.kColorBlack)
    
    -- Header
    local sortLabel = "Score"
    if self.sortMode == "time" then
        sortLabel = "Time Alive"
    elseif self.sortMode == "enemies" then
        sortLabel = "Enemies Defeated"
    end
    
    local syncStatus = ""
    if self.showingServerScores then
        syncStatus = " [SERVER]"
    end
    if self.isFetching then
        syncStatus = " [SYNCING...]"
    end
    
    g.drawTextAligned("LEADERBOARD - " .. sortLabel .. syncStatus, 200, 5, kTextAlignment.center)
    
    local helpText = "[<] [>] sort"
    if not self.showingServerScores and playdate.scoreboards then
        helpText = helpText .. " | [^] sync"
    end
    g.drawTextAligned(helpText, 200, 18, kTextAlignment.center)
    
    -- Column headers
    local y = 35
    local headerY = y
    g.drawTextAligned("#", 20, headerY, kTextAlignment.left)
    g.drawTextAligned("Player", 50, headerY, kTextAlignment.left)
    
    if self.showingServerScores or self.sortMode == "score" then
        g.drawTextAligned("Score", 250, headerY, kTextAlignment.right)
    elseif self.sortMode == "time" then
        g.drawTextAligned("Time", 250, headerY, kTextAlignment.right)
    elseif self.sortMode == "enemies" then
        g.drawTextAligned("Enemies", 250, headerY, kTextAlignment.right)
    end
    
    -- Draw separator line
    y = y + 12
    g.drawLine(10, y, 390, y)
    y = y + 5
    
    -- Draw leaderboard entries
    local maxVisible = self.itemsPerPage
    local startIdx = ((self.page - 1) * maxVisible) + 1
    local endIdx = math.min(startIdx + maxVisible - 1, #self.leaderboard)
    
    if #self.leaderboard == 0 then
        g.drawTextAligned("No scores yet", 200, 120, kTextAlignment.center)
    else
        for i = startIdx, endIdx do
            local entry = self.leaderboard[i]
            if entry then
                local isSelected = (i == self.selectedIndex)
                
                -- Draw selection highlight
                if isSelected then
                    g.fillRect(15, y - 2, 370, 12)
                    g.setColor(g.kColorWhite)
                end
                
                -- Rank
                g.drawTextAligned(tostring(i), 20, y, kTextAlignment.left)
                
                -- Player name (truncate if too long)
                local playerName = entry.player or entry.playerName or "Player"
                if #playerName > 15 then
                    playerName = playerName:sub(1, 12) .. "..."
                end
                g.drawText(playerName, 50, y)
                
                -- Value based on sort mode or if showing server scores
                if self.showingServerScores then
                    g.drawTextAligned(tostring(entry.score), 390, y, kTextAlignment.right)
                elseif self.sortMode == "score" then
                    g.drawTextAligned(tostring(entry.score), 390, y, kTextAlignment.right)
                elseif self.sortMode == "time" then
                    local timeStr = string.format("%02d:%02d", 
                        math.floor(entry.timeAlive / 60), 
                        math.floor(entry.timeAlive % 60))
                    g.drawTextAligned(timeStr, 390, y, kTextAlignment.right)
                elseif self.sortMode == "enemies" then
                    g.drawTextAligned(tostring(entry.enemiesDefeated), 390, y, kTextAlignment.right)
                end
                
                -- Show wave count (if available)
                if entry.waveCount and entry.waveCount > 0 then
                    local waveStr = "Wave " .. tostring(entry.waveCount)
                    g.drawTextAligned(waveStr, 390, y + 8, kTextAlignment.right)
                end
                
                if isSelected then
                    g.setColor(g.kColorBlack)
                end
                
                y = y + 18
            end
        end
    end
    
    -- Draw page info
    local totalEntries = #self.leaderboard
    local maxPages = math.ceil(totalEntries / maxVisible)
    if maxPages > 1 then
        local pageStr = "Page " .. self.page .. "/" .. maxPages
        g.drawTextAligned(pageStr, 200, 230, kTextAlignment.center)
    else
        local entriesStr = "Total: " .. totalEntries
        if self.showingServerScores then
            entriesStr = "Server Scores"
        end
        g.drawTextAligned(entriesStr, 200, 230, kTextAlignment.center)
    end
end

return LeaderboardScreen
