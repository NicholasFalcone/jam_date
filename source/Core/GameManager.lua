class('GameManager').extends()

-- Game states
local GAME_STATE = {
	IDLE = "idle",           -- Main menu / waiting to start
	RUNNING = "running",     -- Active gameplay
	GAME_OVER = "gameOver",  -- Player defeated
	PAUSED = "paused"        -- Game paused
}

function GameManager:init()
	self.currentState = GAME_STATE.IDLE
	self.score = 0
	self.waveCount = 0
	self.timeAlive = 0
	self.enemiesDefeated = 0
	self.playerHealth = 100
	self.maxPlayerHealth = 100
end

function GameManager:update(deltaTime)
	if self.currentState == GAME_STATE.RUNNING then
		self.timeAlive = self.timeAlive + (deltaTime or 0.016)
	end
end

function GameManager:setState(newState)
	if newState == self.currentState then return end
	
	local oldState = self.currentState
	self.currentState = newState
	
	-- Handle state transitions
	if newState == GAME_STATE.IDLE then
		self:onIdleEnter()
	elseif newState == GAME_STATE.RUNNING then
		self:onRunningEnter()
	elseif newState == GAME_STATE.GAME_OVER then
		self:onGameOverEnter()
	elseif newState == GAME_STATE.PAUSED then
		self:onPausedEnter()
	end
end

function GameManager:getState()
	return self.currentState
end

function GameManager:isRunning()
	return self.currentState == GAME_STATE.RUNNING
end

function GameManager:isGameOver()
	return self.currentState == GAME_STATE.GAME_OVER
end

function GameManager:isIdle()
	return self.currentState == GAME_STATE.IDLE
end

function GameManager:isPaused()
	return self.currentState == GAME_STATE.PAUSED
end

-- State callbacks
function GameManager:onIdleEnter()
	-- Reset game variables for new run
	self.score = 0
	self.waveCount = 0
	self.timeAlive = 0
	self.enemiesDefeated = 0
	self.playerHealth = self.maxPlayerHealth
end

function GameManager:onRunningEnter()
	-- Game started
	self.timeAlive = 0
	self.waveCount = 1
end

function GameManager:onGameOverEnter()
	-- Player died - game over
end

function GameManager:onPausedEnter()
	-- Game paused
end

-- Score management
function GameManager:addScore(points)
	self.score = self.score + points
end

function GameManager:addEnemyDefeated()
	self.enemiesDefeated = self.enemiesDefeated + 1
	self:addScore(10) -- 10 points per enemy
end

-- Health management
function GameManager:takeDamage(amount)
	self.playerHealth = math.max(0, self.playerHealth - amount)
	if self.playerHealth <= 0 then
		self:setState(GAME_STATE.GAME_OVER)
	end
end

function GameManager:heal(amount)
	self.playerHealth = math.min(self.maxPlayerHealth, self.playerHealth + amount)
end

function GameManager:getHealthPercent()
	return self.playerHealth / self.maxPlayerHealth
end

-- Wave management
function GameManager:nextWave()
	self.waveCount = self.waveCount + 1
	self:addScore(100 * self.waveCount) -- Bonus for surviving wave
end

-- Draw UI
function GameManager:drawStateScreen(gfx)
	if self.currentState == GAME_STATE.IDLE then
		self:drawIdleScreen(gfx)
	elseif self.currentState == GAME_STATE.GAME_OVER then
		self:drawGameOverScreen(gfx)
	end
end

function GameManager:drawIdleScreen(gfx)
	-- Clear and set white background
	gfx.setColor(gfx.kColorWhite)
	gfx.fillRect(0, 0, 400, 240)
	
	-- Draw text in black
	gfx.setColor(gfx.kColorBlack)
	gfx.drawText("JAM DATE", 5, 50)
	gfx.drawText("Press A Button to START", 5, 100)
	gfx.drawText("Use DPAD to aim", 5, 130)
	gfx.drawText("Rotate CRANK to shoot", 5, 160)
	gfx.drawText("Press B to switch weapon", 5, 190)
end

function GameManager:drawGameOverScreen(gfx)
	-- Clear and set white background
	gfx.setColor(gfx.kColorWhite)
	gfx.fillRect(0, 0, 400, 240)
	
	-- Draw text in black
	gfx.setColor(gfx.kColorBlack)
	gfx.drawText("GAME OVER", 10, 30)
	gfx.drawText("Score: " .. self.score, 10, 70)
	gfx.drawText("Enemies: " .. self.enemiesDefeated, 10, 100)
	gfx.drawText("Time: " .. string.format("%.1f", self.timeAlive) .. "s", 10, 130)
	gfx.drawText("Press A to restart", 10, 180)
end

-- Exports for state constants
function GameManager.getStateConstants()
	return GAME_STATE
end

return GAME_STATE
