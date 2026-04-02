class('DataManager').extends()

-- Constants
local DATA_FOLDER = "jam_date_data"
local LEADERBOARD_STATE_FILE = "leaderboard_state"
local LEADERBOARD_FILE = "leaderboard"
local LEADERBOARD_META_FILE = "leaderboard_meta"
local LEGACY_LEADERBOARD_STATE_FILE = "leaderboard_state.json"
local LEGACY_LEADERBOARD_FILE = "leaderboard.json"
local LEGACY_LEADERBOARD_META_FILE = "leaderboard_meta.json"
local MAX_LEADERBOARD_ENTRIES = 50

-- Scoreboard configuration - these need to match what you create in Panic's Dev Portal
-- IMPORTANT: Set your game's bundle ID in pdxinfo
local SCOREBOARD_ID = ""  -- Set this to your Panic Dev Portal board ID to enable online sync
local USE_PLAYDATE_SCOREBOARD = true  -- Set to false to disable online syncing

local function logDataManager(message)
    print("[DataManager] " .. tostring(message))
end

local function isScoreboardConfigured()
    return USE_PLAYDATE_SCOREBOARD
        and type(SCOREBOARD_ID) == "string"
        and SCOREBOARD_ID ~= ""
end

function DataManager:init()
    self.leaderboard = {}
    self.personalBestScore = 0
    self.totalRuns = 0
    self.lastSaveOk = false
    self.lastSaveError = nil
    self.lastDebugMessage = "init"
    self.syncInProgress = false
    self.lastSyncTime = 0
    
    self:ensureDataFolder()
    self:loadState()
    
    -- Try to sync with Playdate scoreboards on init
    if isScoreboardConfigured() and playdate.scoreboards then
        self:syncLocalToServer()
    end
end

-- Ensure data folder exists
function DataManager:ensureDataFolder()
    -- No-op: using playdate.datastore for persistence, no folder needed
end

local function readDatastoreFile(primaryName, legacyName)
    if not (playdate.datastore and playdate.datastore.read) then
        return nil
    end

    local data = playdate.datastore.read(primaryName)
    if data ~= nil then
        return data
    end

    if legacyName then
        return playdate.datastore.read(legacyName)
    end

    return nil
end

function DataManager:setDebugStatus(message, saveError)
    self.lastDebugMessage = tostring(message or "")
    self.lastSaveError = saveError
    logDataManager(self.lastDebugMessage)
    if saveError then
        logDataManager("error: " .. tostring(saveError))
    end
end

-- Load leaderboard from file
function DataManager:loadLeaderboard()
    -- Use playdate.datastore for persistent tables
    local data = readDatastoreFile(LEADERBOARD_FILE, LEGACY_LEADERBOARD_FILE)
    if data and type(data) == "table" then
        self.leaderboard = data
        self:setDebugStatus("loaded legacy leaderboard entries=" .. tostring(#self.leaderboard))
        return
    end
    self.leaderboard = {}
end

function DataManager:loadLeaderboardMeta()
    local data = readDatastoreFile(LEADERBOARD_META_FILE, LEGACY_LEADERBOARD_META_FILE)
    if data and type(data) == "table" then
        self.personalBestScore = tonumber(data.personalBestScore) or 0
        self.totalRuns = tonumber(data.totalRuns) or 0
        self:setDebugStatus("loaded legacy meta best=" .. tostring(self.personalBestScore) .. " runs=" .. tostring(self.totalRuns))
        return
    end

    self.personalBestScore = 0
    self.totalRuns = #self.leaderboard
    for _, entry in ipairs(self.leaderboard) do
        local score = tonumber(entry.score) or 0
        if score > self.personalBestScore then
            self.personalBestScore = score
        end
    end
end

function DataManager:loadState()
    local state = readDatastoreFile(LEADERBOARD_STATE_FILE, LEGACY_LEADERBOARD_STATE_FILE)
    if state and type(state) == "table" then
        local entries = state.entries
        if type(entries) == "table" then
            self.leaderboard = entries
        else
            self.leaderboard = {}
        end
        self.personalBestScore = tonumber(state.personalBestScore or state.bestScore) or 0
        self.totalRuns = tonumber(state.totalRuns or state.runCount) or 0

        if self.totalRuns == 0 then
            self.totalRuns = #self.leaderboard
        end

        if self.personalBestScore == 0 then
            for _, entry in ipairs(self.leaderboard) do
                local score = tonumber(entry.score) or 0
                if score > self.personalBestScore then
                    self.personalBestScore = score
                end
            end
        end
        self:setDebugStatus("loaded state entries=" .. tostring(#self.leaderboard) .. " best=" .. tostring(self.personalBestScore) .. " runs=" .. tostring(self.totalRuns))
        return
    end

    self:loadLeaderboard()
    self:loadLeaderboardMeta()
    self:setDebugStatus("no saved state found; fallback entries=" .. tostring(#self.leaderboard) .. " best=" .. tostring(self.personalBestScore) .. " runs=" .. tostring(self.totalRuns))
end

-- Save leaderboard to file
function DataManager:saveLeaderboard()
    if playdate.datastore and playdate.datastore.write then
        local ok, err = pcall(function()
            playdate.datastore.write(self.leaderboard, LEADERBOARD_FILE)
        end)
        if not ok then
            self:setDebugStatus("saveLeaderboard failed", err)
        end
        return ok
    end
    self:setDebugStatus("saveLeaderboard unavailable")
    return false
end

function DataManager:saveState()
    if playdate.datastore and playdate.datastore.write then
        local ok, err = pcall(function()
            playdate.datastore.write({
                entries = self.leaderboard,
                personalBestScore = self.personalBestScore or 0,
                totalRuns = self.totalRuns or 0
            }, LEADERBOARD_STATE_FILE)
        end)
        self.lastSaveOk = ok
        if ok then
            self:setDebugStatus("saveState ok entries=" .. tostring(#self.leaderboard) .. " best=" .. tostring(self.personalBestScore) .. " runs=" .. tostring(self.totalRuns))
        else
            self:setDebugStatus("saveState failed", err)
        end
        return ok
    end
    self.lastSaveOk = false
    self:setDebugStatus("saveState unavailable")
    return false
end

function DataManager:saveLeaderboardMeta()
    if playdate.datastore and playdate.datastore.write then
        local ok, err = pcall(function()
            playdate.datastore.write({
                personalBestScore = self.personalBestScore or 0,
                totalRuns = self.totalRuns or 0
            }, LEADERBOARD_META_FILE)
        end)
        if not ok then
            self:setDebugStatus("saveLeaderboardMeta failed", err)
        end
        return ok
    end
    self:setDebugStatus("saveLeaderboardMeta unavailable")
    return false
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
    
    self.totalRuns = (self.totalRuns or 0) + 1
    local score = tonumber(result.score) or 0
    self.personalBestScore = math.max(self.personalBestScore or 0, score)
    self:setDebugStatus("addRunResult score=" .. tostring(score) .. " runs=" .. tostring(self.totalRuns))

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
    
    local savedState = self:saveState()
    local savedLeaderboard = self:saveLeaderboard()
    local savedMeta = self:saveLeaderboardMeta()
    
    -- Try to post to Playdate scoreboards
    if isScoreboardConfigured() and playdate.scoreboards then
        self:postScoreToServer(result.score)
    end
    
    return savedState or (savedLeaderboard and savedMeta)
end

-- Post score to Playdate's online scoreboard
function DataManager:postScoreToServer(score)
    if not isScoreboardConfigured() or not playdate.scoreboards or self.syncInProgress then
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
    if not isScoreboardConfigured() or not playdate.scoreboards then
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
    if not isScoreboardConfigured() or not playdate.scoreboards or self.syncInProgress then
        return
    end
    
    -- Post top local score to server
    if #self.leaderboard > 0 then
        local topScore = self.personalBestScore or self.leaderboard[1].score
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
    return self.totalRuns or #self.leaderboard
end

function DataManager:getPersonalBestScore()
    return self.personalBestScore or 0
end

function DataManager:getDebugStatus()
    return {
        lastSaveOk = self.lastSaveOk,
        lastSaveError = self.lastSaveError,
        lastDebugMessage = self.lastDebugMessage,
        entryCount = #self.leaderboard,
        totalRuns = self.totalRuns or 0,
        personalBestScore = self.personalBestScore or 0
    }
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
    self.personalBestScore = 0
    self.totalRuns = 0
    self:saveState()
    self:saveLeaderboard()
    self:saveLeaderboardMeta()
end

-- Check if online sync is enabled and available
function DataManager:isOnlineSyncAvailable()
    return isScoreboardConfigured() and playdate.scoreboards ~= nil
end

-- Get personal best from device
function DataManager:getPersonalBest(callback)
    if not isScoreboardConfigured() or not playdate.scoreboards then
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
