class('DataManager').extends()

local json = require("json") -- Playdate includes json library

-- Constants
local DATA_FOLDER = "jam_date_data"
local LEADERBOARD_FILE = "leaderboard.json"
local MAX_LEADERBOARD_ENTRIES = 50

-- Scoreboard configuration - these need to match what you create in Panic's Dev Portal
-- IMPORTANT: Set your game's bundle ID in pdxinfo
local SCOREBOARD_ID = "highscores"  -- Change this to match your board ID on Panic servers
local USE_PLAYDATE_SCOREBOARD = true  -- Set to false to disable online syncing

function DataManager:init()
    self.leaderboard = {}
    self.syncInProgress = false
    self.lastSyncTime = 0
    
    self:ensureDataFolder()
    self:loadLeaderboard()
    
    -- Try to sync with Playdate scoreboards on init
    if USE_PLAYDATE_SCOREBOARD and playdate.scoreboards then
        self:syncLocalToServer()
    end
end

-- Ensure data folder exists
function DataManager:ensureDataFolder()
    local path = DATA_FOLDER
    -- Check if folder exists by trying to list it
    local ok, err = pcall(function()
        playdate.file.listFiles(path)
    end)
    
    -- If folder doesn't exist, create it by saving a dummy file
    if not ok then
        playdate.file.mkdir(DATA_FOLDER)
    end
end

-- Load leaderboard from file
function DataManager:loadLeaderboard()
    local filePath = DATA_FOLDER .. "/" .. LEADERBOARD_FILE
    local fileContent = playdate.file.read(filePath)
    
    if fileContent then
        local ok, data = pcall(function()
            return json.decode(fileContent)
        end)
        
        if ok and data then
            self.leaderboard = data
        else
            self.leaderboard = {}
        end
    else
        self.leaderboard = {}
    end
end

-- Save leaderboard to file
function DataManager:saveLeaderboard()
    local filePath = DATA_FOLDER .. "/" .. LEADERBOARD_FILE
    local ok, jsonStr = pcall(function()
        return json.encode(self.leaderboard)
    end)
    
    if ok and jsonStr then
        playdate.file.write(filePath, jsonStr)
        return true
    else
        return false
    end
end

-- Add a run result to leaderboard
-- result: {
--   score: int,
--   timeAlive: float (in seconds),
--   enemiesDefeated: int,
--   waveCount: int,
--   timestamp: int (unix timestamp),
--   playerName: string (optional, default "Player")
-- }
function DataManager:addRunResult(result)
    if not result then return false end
    
    -- Set defaults
    if not result.playerName then result.playerName = "Player" end
    if not result.timestamp then result.timestamp = playdate.getSecondsSinceEpoch() end
    
    -- Add to leaderboard
    table.insert(self.leaderboard, result)
    
    -- Sort by score (descending)
    table.sort(self.leaderboard, function(a, b)
        return a.score > b.score
    end)
    
    -- Keep only top MAX_LEADERBOARD_ENTRIES
    while #self.leaderboard > MAX_LEADERBOARD_ENTRIES do
        table.remove(self.leaderboard)
    end
    
    local saved = self:saveLeaderboard()
    
    -- Try to post to Playdate scoreboards
    if USE_PLAYDATE_SCOREBOARD and playdate.scoreboards then
        self:postScoreToServer(result.score)
    end
    
    return saved
end

-- Post score to Playdate's online scoreboard
function DataManager:postScoreToServer(score)
    if not playdate.scoreboards or self.syncInProgress then
        return
    end
    
    self.syncInProgress = true
    
    playdate.scoreboards.addScore(SCOREBOARD_ID, score, function(status, result)
        self.syncInProgress = false
        
        if status and status.code == "OK" then
            -- Successfully posted
        elseif status and status.message then
            -- Network error or other issue - that's fine, it'll be queued locally
        end
    end)
end

-- Fetch scores from Playdate's server and merge with local data
function DataManager:fetchScoresFromServer(callback)
    if not playdate.scoreboards then
        if callback then callback(nil, "Scoreboards not available") end
        return
    end
    
    if self.syncInProgress then
        if callback then callback(nil, "Sync already in progress") end
        return
    end
    
    self.syncInProgress = true
    
    playdate.scoreboards.getScores(SCOREBOARD_ID, function(status, result)
        self.syncInProgress = false
        
        if status and status.code == "OK" and result then
            -- Successfully fetched server scores
            if callback then callback(result, nil) end
        else
            local errorMsg = (status and status.message) or "Unknown error"
            if callback then callback(nil, errorMsg) end
        end
    end)
end

-- Sync local scores to server (post any new local scores)
function DataManager:syncLocalToServer()
    if not playdate.scoreboards or self.syncInProgress then
        return
    end
    
    -- Post top local score to server
    if #self.leaderboard > 0 then
        local topScore = self.leaderboard[1].score
        -- This will queue it if offline or post immediately if online
        self:postScoreToServer(topScore)
    end
end

-- Get top N entries from leaderboard
function DataManager:getTopScores(limit)
    limit = limit or 10
    local result = {}
    for i = 1, math.min(limit, #self.leaderboard) do
        table.insert(result, self.leaderboard[i])
    end
    return result
end

-- Get leaderboard sorted by time alive (descending)
function DataManager:getTopTimeAlive(limit)
    limit = limit or 10
    local sorted = {}
    for _, entry in ipairs(self.leaderboard) do
        table.insert(sorted, entry)
    end
    
    table.sort(sorted, function(a, b)
        return a.timeAlive > b.timeAlive
    end)
    
    local result = {}
    for i = 1, math.min(limit, #sorted) do
        table.insert(result, sorted[i])
    end
    return result
end

-- Get leaderboard sorted by enemies defeated (descending)
function DataManager:getTopEnemiesDefeated(limit)
    limit = limit or 10
    local sorted = {}
    for _, entry in ipairs(self.leaderboard) do
        table.insert(sorted, entry)
    end
    
    table.sort(sorted, function(a, b)
        return a.enemiesDefeated > b.enemiesDefeated
    end)
    
    local result = {}
    for i = 1, math.min(limit, #sorted) do
        table.insert(result, sorted[i])
    end
    return result
end

-- Get full leaderboard
function DataManager:getFullLeaderboard()
    return self.leaderboard
end

-- Get total runs played
function DataManager:getTotalRuns()
    return #self.leaderboard
end

-- Format time for display (seconds to MM:SS:CC format)
function DataManager.formatTime(seconds)
    local totalSeconds = seconds or 0
    local m = math.floor(totalSeconds / 60)
    local s = math.floor(totalSeconds % 60)
    local fractional = totalSeconds - math.floor(totalSeconds)
    local centiseconds = math.floor(fractional * 100) % 60
    return string.format("%02d:%02d:%02d", m, s, centiseconds)
end

-- Clear leaderboard (for testing)
function DataManager:clearLeaderboard()
    self.leaderboard = {}
    self:saveLeaderboard()
end

-- Check if online sync is enabled and available
function DataManager:isOnlineSyncAvailable()
    return USE_PLAYDATE_SCOREBOARD and playdate.scoreboards ~= nil
end

-- Get personal best from device
function DataManager:getPersonalBest(callback)
    if not playdate.scoreboards then
        if callback then callback(nil) end
        return
    end
    
    playdate.scoreboards.getPersonalBest(SCOREBOARD_ID, function(status, result)
        if callback then
            if status and status.code == "OK" then
                callback(result)
            else
                callback(nil)
            end
        end
    end)
end

return DataManager
