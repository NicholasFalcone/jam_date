class('GameManager').extends()

import "Game/Dice"
import "Core/AudioManager"
import "Core/UI"

local gfx = playdate.graphics

-- Game states
local GAME_STATE = {
	IDLE = "idle",
	RUNNING = "running",
	ROLLING = "rolling",
	GAME_OVER = "gameOver",
	PAUSED = "paused"
}

local audioManager = AudioManager()

function GameManager:init()
	self.currentState = GAME_STATE.IDLE
	self.score = 0
	self.waveCount = 0
	self.timeAlive = 0
	self.enemiesDefeated = 0
	self.playerHealth = 100
	self.maxPlayerHealth = 100

	-- Rolling state variables
	self.weaponDice = nil
	self.ammoDice = {}
	self.rolledWeapon = nil
	self.rolledAmmo = 0

	-- UI (menu/howto/credits)
	self.ui = UI()
	self.ui:setScreen("menu")

	-- GAME OVER UI assets (put in: source/images/ui/)
	self.gameOverBg = gfx.image.new("images/ui/GAME_OVER_3-dithered")
	self.gameOverSelector = gfx.image.new("images/ui/Bullet_Revolver_White")

	self.gameOverIndex = 1 -- 1=Play Again, 2=Main Menu
	self.gameOverCrankAccum = 0
	self.gameOverCrankStepDeg = 18
end

function GameManager:update(deltaTime)
	if self.currentState == GAME_STATE.RUNNING then
		self.timeAlive = self.timeAlive + (deltaTime or 0.016)
	end
end

function GameManager:resetGame()
	-- Reset all game variables
	self.score = 0
	self.waveCount = 0
	self.timeAlive = 0
	self.enemiesDefeated = 0
	self.playerHealth = self.maxPlayerHealth
end

function GameManager:setState(newState)
	if newState == self.currentState then return end

	-- Gate IDLE->RUNNING unless menu selection is Play (no main.lua edits)
	if self.currentState == GAME_STATE.IDLE and newState == GAME_STATE.RUNNING then
		if self.ui and self.ui.canStart and not self.ui:canStart() then
			return
		end
	end

	-- main.lua likely does GAME_OVER -> IDLE on A press.
	-- Redirect that based on selection:
	-- Play Again => RUNNING, Main Menu => IDLE
	if self.currentState == GAME_STATE.GAME_OVER and newState == GAME_STATE.IDLE then
		if self.gameOverIndex == 1 then
			newState = GAME_STATE.RUNNING
		else
			newState = GAME_STATE.IDLE
		end
	end

	self.currentState = newState

	if newState == GAME_STATE.IDLE then
		self:onIdleEnter()
	elseif newState == GAME_STATE.RUNNING then
		self:onRunningEnter()
	elseif newState == GAME_STATE.ROLLING then
		self:onRollingEnter()
	elseif newState == GAME_STATE.GAME_OVER then
		self:onGameOverEnter()
	elseif newState == GAME_STATE.PAUSED then
		self:onPausedEnter()
	end
end

function GameManager:getState() return self.currentState end
function GameManager:isRunning() return self.currentState == GAME_STATE.RUNNING end
function GameManager:isGameOver() return self.currentState == GAME_STATE.GAME_OVER end
function GameManager:isIdle() return self.currentState == GAME_STATE.IDLE end
function GameManager:isPaused() return self.currentState == GAME_STATE.PAUSED end
function GameManager:isRolling() return self.currentState == GAME_STATE.ROLLING end

local music = nil

function GameManager:onIdleEnter()
	-- Reset all game variables
	self:resetGame()

	print("Idle state entered.")
	if self.ui and self.ui.setScreen then
		self.ui:setScreen("menu")
	end

	if music then music:stop() end
	music = audioManager:loadSample("sounds/Music_Menu.mp3")
	if music then music:play(0) end
end

function GameManager:onRunningEnter()
	-- Reset all game state for a fresh start
	self.score = 0
	self.waveCount = 1
	self.timeAlive = 0
	self.enemiesDefeated = 0
	self.playerHealth = self.maxPlayerHealth

	if music then music:stop() end
	music = audioManager:loadSample("sounds/Music_Game.mp3")
	if music then music:play(0) end
end

function GameManager:onRollingEnter()
	self.weaponDice = Dice()
	self.weaponDice:roll()

	self.ammoDice = {}
	for i = 1, 4 do
		local dice = Dice()
		dice:roll()
		table.insert(self.ammoDice, dice)
	end
	
	if self.SFX_RollingDice then
		pcall(function() self.SFX_RollingDice:play(1) end)
	end
	-- Calculate results
	self:calculateRollingResults()
end

function GameManager:onGameOverEnter()
	self.gameOverIndex = 1 -- default selection: Play Again
	self.gameOverCrankAccum = 0
end

function GameManager:onPausedEnter()
end

function GameManager:calculateRollingResults()
	local weaponRoll = self.weaponDice.value
	if weaponRoll <= 2 then
		self.rolledWeapon = "Minigun"
	elseif weaponRoll <= 4 then
		self.rolledWeapon = "Revolver"
	else
		self.rolledWeapon = "Shotgun"
	end

	self.rolledAmmo = 0
	for _, die in ipairs(self.ammoDice) do
		if weaponRoll <= 2 then
			self.rolledAmmo = self.rolledAmmo + (die.value * 5)
		else
			self.rolledAmmo = self.rolledAmmo + die.value
		end
	end
end

function GameManager:addScore(points) self.score = self.score + points end

function GameManager:addEnemyDefeated()
	self.enemiesDefeated = self.enemiesDefeated + 1
	self:addScore(10)
end

function GameManager:takeDamage(amount)
	self.playerHealth = math.max(0, self.playerHealth - amount)
	if self.playerHealth <= 0 then
		self:setState(GAME_STATE.GAME_OVER)
	end
end

function GameManager:nextWave()
	self.waveCount = self.waveCount + 1
	self:addScore(100 * self.waveCount)
end

function GameManager:drawStateScreen(g)
	if self.currentState == GAME_STATE.IDLE then
		self:drawIdleScreen(g)
	elseif self.currentState == GAME_STATE.ROLLING then
		self:drawRollingScreen(g)
	elseif self.currentState == GAME_STATE.GAME_OVER then
		self:drawGameOverScreen(g)
	end
end

function GameManager:drawIdleScreen(g)
	g.setColor(g.kColorWhite)
	g.fillRect(0, 0, 400, 240)
	g.setColor(g.kColorBlack)

	if self.ui then
		local action = self.ui:update()
		if action == "howto" then
			self.ui:setScreen("howto")
		elseif action == "credits" then
			self.ui:setScreen("credits")
		elseif action == "back" then
			self.ui:setScreen("menu")
		end

		self.ui:draw(nil)
	end
end

local function clamp(v, lo, hi)
	if v < lo then return lo end
	if v > hi then return hi end
	return v
end

local function formatTimeHMS(seconds)
	local s = math.floor(seconds or 0)
	local h = math.floor(s / 3600)
	s = s - h * 3600
	local m = math.floor(s / 60)
	s = s - m * 60
	return string.format("%02d:%02d", m, s)
end

function GameManager:drawGameOverScreen(g)
	-- Input: Up/Down + Crank switch selection
	if playdate.buttonJustPressed(playdate.kButtonDown) then
		self.gameOverIndex = clamp(self.gameOverIndex + 1, 1, 2)
	elseif playdate.buttonJustPressed(playdate.kButtonUp) then
		self.gameOverIndex = clamp(self.gameOverIndex - 1, 1, 2)
	end

	local crankDelta = playdate.getCrankChange()
	if crankDelta ~= 0 then
		self.gameOverCrankAccum = self.gameOverCrankAccum + crankDelta

		while self.gameOverCrankAccum >= self.gameOverCrankStepDeg do
			self.gameOverCrankAccum = self.gameOverCrankAccum - self.gameOverCrankStepDeg
			self.gameOverIndex = clamp(self.gameOverIndex + 1, 1, 2)
		end

		while self.gameOverCrankAccum <= -self.gameOverCrankStepDeg do
			self.gameOverCrankAccum = self.gameOverCrankAccum + self.gameOverCrankStepDeg
			self.gameOverIndex = clamp(self.gameOverIndex - 1, 1, 2)
		end
	end

	-- Background
	if self.gameOverBg then
		self.gameOverBg:draw(0, 0)
	else
		g.setColor(g.kColorBlack)
		g.fillRect(0, 0, 400, 240)
	end

	-- Force text + selector to draw in white on top of dark image
	local prevMode = g.getImageDrawMode()
	g.setImageDrawMode(g.kDrawModeFillWhite)

	-- NOTE: Playdate alignment constant is global: kTextAlignment.center
	g.drawTextAligned("SURVIVAL TIME:", 200, 92, kTextAlignment.center)
	g.drawTextAligned(formatTimeHMS(self.timeAlive), 200, 112, kTextAlignment.center)

	-- Keep old stats in code, but not shown
	-- g.drawText("Score: " .. self.score, 10, 70)
	-- g.drawText("Enemies: " .. self.enemiesDefeated, 10, 100)

	-- Selector bullet (aligned to the buttons)
	local selectorX = 120
	local playAgainCenterY = 150
	local mainMenuCenterY  = 178

	local bw, bh = 12, 6
	if self.gameOverSelector then
		bw, bh = self.gameOverSelector:getSize()
	end

	local centerY = (self.gameOverIndex == 1) and playAgainCenterY or mainMenuCenterY
	local selectorY = math.floor(centerY - (bh / 2) + 0.5)

	if self.gameOverSelector then
		self.gameOverSelector:draw(selectorX, selectorY)
	else
		g.fillCircleAtPoint(selectorX + 4, centerY, 3)
	end

	g.setImageDrawMode(prevMode)

	-- Draw button text labels in BLACK with smaller font and better positioning
	g.setColor(g.kColorBlack)
	
	-- Use a smaller font for the button text
	local smallFont = gfx.font.new('font/Asheville-Sans-14-Bold')
	if smallFont then 
		gfx.setFont(smallFont)
	end
	
	local buttonTextX = 200
	-- Adjust Y positions to better center text inside buttons
	g.drawTextAligned("PLAY AGAIN", buttonTextX, playAgainCenterY - 6, kTextAlignment.center)
	g.drawTextAligned("MAIN MENU", buttonTextX, mainMenuCenterY - 6, kTextAlignment.center)
end

function GameManager:drawRollingScreen(g)
	g.setColor(g.kColorBlack)
	g.setColor(g.kColorWhite)
	g.drawText("ROLL FOR AMMO & WEAPON", 30, 10)

	if self.weaponDice then
		self.weaponDice:draw(80, 70, false, false)
	end

	if self.ammoDice and #self.ammoDice == 4 then
		local baseX = 260
		local baseY = 60
		local spacing = 45

		self.ammoDice[1]:draw(baseX, baseY, true, false)
		self.ammoDice[2]:draw(baseX + spacing, baseY, true, false)
		self.ammoDice[3]:draw(baseX, baseY + spacing, true, false)
		self.ammoDice[4]:draw(baseX + spacing, baseY + spacing, true, false)
	end

	g.setColor(g.kColorWhite)
	g.drawLine(0, 160, 400, 160)

	local weaponText = "Weapon: " .. (self.rolledWeapon or "?")
	local ammoText = "Ammo: " .. self.rolledAmmo

	g.drawText(weaponText, 50, 175)
	g.drawText(ammoText, 50, 200)
	g.drawText("Press A to continue", 60, 220)
end

function GameManager.getStateConstants()
	return GAME_STATE
end

return GAME_STATE