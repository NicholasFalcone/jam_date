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

local ROLLING_PHASE = {
	WAITING_FOR_SWING = "waitingForSwing",
	PLAYING_ANIMATION = "playingAnimation",
	RESULTS = "results"
}

local audioManager = AudioManager()

function GameManager:init()
	self.currentState = GAME_STATE.IDLE
	self.prevState = self.currentState
	self.score = 0
	self.waveCount = 0
	self.timeAlive = 0
	self.timeAliveFormat = "00:00:00"
	self.enemiesDefeated = 0
	self.playerHealth = 100
	self.maxPlayerHealth = 100
	self.mainMusic = nil
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
	
	-- Rolling screen image
	self.shakeItImage = gfx.image.new("images/ui/Shake_it")
	
	-- Weapon result images (shown after rolling dice)
	self.weaponResultImages = {
		Minigun = gfx.image.new("images/rolling_results/Minigun"),
		Revolver = gfx.image.new("images/rolling_results/Revolver"),
		Shotgun = gfx.image.new("images/rolling_results/Shotgun")
	}

	self.gameOverIndex = 1 -- 1=Play Again, 2=Main Menu
	self.gameOverCrankAccum = 0
	self.gameOverCrankStepDeg = 18
	self.SFX_RollingDice = audioManager:loadSample("sounds/SFX_DiceRoll")
	self.SFX_GameOver = audioManager:loadSample("sounds/SFX_GameOver")

	-- Phase for rolling
	self.rollingPhase = ROLLING_PHASE.WAITING_FOR_SWING
	self.shakeThreshold = 1 -- Sensitivity threshold for movement
	self.shakeDeltaThreshold = 0.9 -- Sensitivity for shake (delta accel)
	self.shakeCooldown = 0.35 -- seconds between shake triggers
	self.lastShakeTime = 0
	self.prevAccelX = 0
	self.prevAccelY = 0
	self.prevAccelZ = 0
	self.rolledThisFrame = false
	
	-- Rolling animation variables
	self.rollingAnimFrames = self:loadRollingAnimFrames()
	self.rollingAnimTicks = 0  -- Counter for animation (30 ticks = 0.5 seconds @ 60fps)
	self.rollingAnimFrameIndex = 1
	self.onDiceRoll = nil
end

function GameManager:setOnDiceRollCallback(callback)
	self.onDiceRoll = callback
end

local function clamp(val, min, max)
  return val < min and min or val > max and max or val
end

function GameManager:update(deltaTime)
	self.rolledThisFrame = false
	
	-- Timer continues during both RUNNING
	if self.currentState == GAME_STATE.RUNNING then
		self.timeAlive = self.timeAlive + (deltaTime or 0.016)
		if self.mainMusic then
			local nextRate = 1 + (self.timeAlive * 0.000083) -- Gradually increase pitch over time (max 2x at 2 minutes)
			nextRate = clamp(nextRate, 1, 1.25) -- Cap the pitch increase at 1.5x for better audio quality
			self.mainMusic:setRate(nextRate) -- Gradually increase pitch over time (max 2x at 2 minutes)
		end
	end
	
	if self.currentState == GAME_STATE.ROLLING then
		if self.rollingPhase == ROLLING_PHASE.WAITING_FOR_SWING then
			-- Use accelerometer if it exists, otherwise use fallback button
			if playdate.readAccelerometer then
				local x, y, z = playdate.readAccelerometer()
				-- Detect shake by looking at sudden changes (swing-like impulse)
				local dx = x - (self.prevAccelX or 0)
				local dy = y - (self.prevAccelY or 0)
				local dz = z - (self.prevAccelZ or 0)
				self.prevAccelX, self.prevAccelY, self.prevAccelZ = x, y, z
				local deltaMag = math.sqrt(dx*dx + dy*dy + dz*dz)
				local now = playdate.getElapsedTime()
				if deltaMag > (self.shakeDeltaThreshold or self.shakeThreshold) and (now - (self.lastShakeTime or 0)) >= (self.shakeCooldown or 0) then
					self.lastShakeTime = now
					self:triggerDiceRoll()
				end
			else
				-- Safe fallback - also check for button press if accelerometer is missing
				if playdate.buttonJustPressed(playdate.kButtonA) then
					self:triggerDiceRoll()
				end
			end
		elseif self.rollingPhase == ROLLING_PHASE.PLAYING_ANIMATION then
			-- Handle animation tick countdown
			if self.rollingAnimTicks > 0 then
				-- Calculate which frame to show (11 frames over 30 ticks = ~2.7 ticks per frame)
				local totalTicks = 30
				local totalFrames = 11
				local ticksPerFrame = totalTicks / totalFrames  -- ~2.7 ticks per frame
				
				-- Calculate current frame: goes from 1 to 11 as ticks count down from 30 to 0
				local currentFrame = math.floor((totalTicks - self.rollingAnimTicks) / ticksPerFrame) + 1
				self.rollingAnimFrameIndex = math.max(1, math.min(totalFrames, currentFrame))
				
				self.rollingAnimTicks = self.rollingAnimTicks - 1
			else
				-- Animation complete, show results
				self.rollingPhase = ROLLING_PHASE.RESULTS
			end
		end
	end
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

	self.prevState = self.currentState
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

function GameManager:onIdleEnter()
	self.score = 0
	self.waveCount = 0
	self.timeAlive = 0
	self.enemiesDefeated = 0
	self.playerHealth = self.maxPlayerHealth

	if self.ui and self.ui.setScreen then
		self.ui:setScreen("menu")
	end

	if self.mainMusic then self.mainMusic:stop() end
	self.mainMusic = audioManager:loadMusic("sounds/Music_Menu")
	if self.mainMusic then self.mainMusic:play(0) end
end

function GameManager:onRunningEnter()
	-- Only reset game state when starting a new game (from IDLE or GAME_OVER), not when returning from ROLLING
	if self.prevState == GAME_STATE.IDLE or self.prevState == GAME_STATE.GAME_OVER then
		self.score = 0
		self.waveCount = 1
		self.timeAlive = 0
		self.enemiesDefeated = 0
		self.playerHealth = self.maxPlayerHealth
		
		if self.mainMusic then self.mainMusic:stop() end
		self.mainMusic = audioManager:loadMusic("sounds/Music_Game")
		if self.mainMusic then self.mainMusic:play(0) end
	end
	-- When returning from ROLLING, keep existing stats (timer continues)
end

function GameManager:onRollingEnter()
	
	self.rollingPhase = ROLLING_PHASE.WAITING_FOR_SWING
	
	if playdate.startAccelerometer then
		pcall(function() playdate.startAccelerometer() end)
	end
	if playdate.readAccelerometer then
		local x, y, z = playdate.readAccelerometer()
		self.prevAccelX, self.prevAccelY, self.prevAccelZ = x or 0, y or 0, z or 0
		self.lastShakeTime = playdate.getElapsedTime()
	end
	
	-- Note: Dice are NOT rolled yet
	self.weaponDice = Dice()
	self.ammoDice = {}
	for i = 1, 4 do
		table.insert(self.ammoDice, Dice())
	end
end

function GameManager:triggerDiceRoll()
	-- Start animation phase
	self.rollingPhase = ROLLING_PHASE.PLAYING_ANIMATION
	self.rollingAnimTicks = 30  -- 30 frames = 0.5 seconds @ 60fps
	self.rollingAnimFrameIndex = 1
	self.rolledThisFrame = true
	
	-- Roll the dice immediately (results calculated but not shown until animation ends)
	if self.weaponDice then
		self.weaponDice:roll()
	end

	for _, dice in ipairs(self.ammoDice) do
		dice:roll()
	end
	
	if self.SFX_RollingDice then
		pcall(function() self.SFX_RollingDice:play(1) end)
	end
	
	-- Calculate results (ready to display after animation)
	self:calculateRollingResults()

	if self.onDiceRoll then
		pcall(function() self.onDiceRoll() end)
	end
end

local function formatTimeMMSSCC(seconds)
	local totalSeconds = seconds or 0
	local m = math.floor(totalSeconds / 60)
	local s = math.floor(totalSeconds % 60)
	
	-- Get centiseconds from fractional part (0-59 range)
	-- If this causes issues with Playdate FPS, uncomment the random line below
	local fractional = totalSeconds - math.floor(totalSeconds)
	local centiseconds = math.floor(fractional * 100) % 60
	
	-- Alternative: use random if precise timing is problematic
	-- local centiseconds = math.random(0, 59)
	
	return string.format("%02d:%02d:%02d", m, s, centiseconds)
end

function GameManager:onGameOverEnter()
	self.gameOverIndex = 1 -- default selection: Play Again
	self.gameOverCrankAccum = 0
	if self.mainMusic then self.mainMusic:stop() end
	self.timeAliveFormat = formatTimeMMSSCC(self.timeAlive)
	if self.SFX_GameOver then
		pcall(function() self.SFX_GameOver:play(1) end)
	end
end

function GameManager:onPausedEnter()
end

function GameManager:calculateRollingResults()
	-- Ensure we don't roll the same weapon twice in a row.
	local weaponRoll = self.weaponDice.value
	local prevWeapon = self.rolledWeapon
	local attempts = 0
	while prevWeapon and attempts < 10 do
		local candidate
		if weaponRoll <= 2 then
			candidate = "Minigun"
		elseif weaponRoll <= 4 then
			candidate = "Revolver"
		else
			candidate = "Shotgun"
		end
		if candidate ~= prevWeapon then
			break
		end
		-- Reroll the weapon die and try again (bounded attempts)
		if self.weaponDice and self.weaponDice.roll then
			self.weaponDice:roll()
			weaponRoll = self.weaponDice.value
		else
			break
		end
		attempts = attempts + 1
	end

	if weaponRoll <= 2 then
		self.rolledWeapon = "Minigun"
	elseif weaponRoll <= 4 then
		self.rolledWeapon = "Revolver"
	else
		self.rolledWeapon = "Shotgun"
	end

	-- Calculate ammo based on final weaponRoll
	self.rolledAmmo = 0
	for _, die in ipairs(self.ammoDice) do
		if weaponRoll <= 2 then
			self.rolledAmmo = self.rolledAmmo + (die.value * 3)
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
	g.drawTextAligned(self.timeAliveFormat, 200, 112, kTextAlignment.center)

	-- Keep old stats in code, but not shown
	-- g.drawText("Score: " .. self.score, 10, 70)
	-- g.drawText("Enemies: " .. self.enemiesDefeated, 10, 100)

	-- Selector bullet (aligned to the buttons)
	local selectorX = 105  -- Moved left from 120
	local playAgainCenterY = 150
	local mainMenuCenterY  = 181  -- Adjusted for better vertical centering

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
end

function GameManager:drawRollingScreen(g)
	g.setColor(g.kColorWhite)
	g.fillRect(0, 0, 400, 240)
	
	if self.rollingPhase == ROLLING_PHASE.WAITING_FOR_SWING then
		-- Apply random camera shake offset (Softened intensity: 0.8)
		local shakeIntensity = 0.8 
		local shakeX = (math.random() - 0.5) * shakeIntensity * 2
		local shakeY = (math.random() - 0.5) * shakeIntensity * 2
		g.setDrawOffset(shakeX, shakeY)

		-- Display the shake image centered on screen
		if self.shakeItImage then
			local imgW, imgH = self.shakeItImage:getSize()
			local x = math.floor((400 - imgW) / 2)
			local y = math.floor((240 - imgH) / 2)
			self.shakeItImage:draw(x, y)
		else
			-- Fallback to text if image not loaded
			local prompt = "SWING THE CONSOLE TO ROLL!"
			if not playdate.readAccelerometer then
				prompt = "PRESS A TO ROLL!"
			end
			g.setColor(g.kColorBlack)
			g.drawTextAligned(prompt, 200, 100, kTextAlignment.center)
		end
		
		-- Reset offset immediately after drawing the shaking elements
		g.setDrawOffset(0, 0)
		return
	elseif self.rollingPhase == ROLLING_PHASE.PLAYING_ANIMATION then
		-- Display rolling animation
		if self.rollingAnimFrames and #self.rollingAnimFrames > 0 then
			local frameIndex = math.max(1, math.min(#self.rollingAnimFrames, self.rollingAnimFrameIndex))
			local frame = self.rollingAnimFrames[frameIndex]
			if frame then
				-- Draw centered on screen
				local imgW, imgH = frame:getSize()
				local x = math.floor((400 - imgW) / 2)
				local y = math.floor((240 - imgH) / 2)
				frame:draw(x, y)
			end
		else
			-- Fallback if animation frames not loaded
			g.setColor(g.kColorBlack)
			g.drawTextAligned("ROLLING...", 200, 120, kTextAlignment.center)
		end
		return
	end

	-- RESULTS phase - show dice and results
	g.setColor(g.kColorBlack)
	
	-- Display weapon-specific result image
	if self.rolledWeapon and self.weaponResultImages and self.weaponResultImages[self.rolledWeapon] then
		local weaponImg = self.weaponResultImages[self.rolledWeapon]
		-- Draw centered on screen
		local imgW, imgH = weaponImg:getSize()
		local x = math.floor((400 - imgW) / 2)
		local y = math.floor((240 - imgH) / 2)
		weaponImg:draw(x, y)
	end
	
	-- Draw ammo dice (dots only, no squares) - weapon dice removed
	if self.ammoDice and #self.ammoDice == 4 then
		local baseX = 248
		local baseY = 71
		local spacing = 65

		self.ammoDice[1]:draw(baseX, baseY, true, false, true)  -- 5th param = dotsOnly
		self.ammoDice[2]:draw(baseX + spacing, baseY, true, false, true)
		self.ammoDice[3]:draw(baseX, baseY + spacing, true, false, true)
		self.ammoDice[4]:draw(baseX + spacing, baseY + spacing, true, false, true)
	end

	-- Display ammo text with white background
	local ammoText = "Ammo: " .. self.rolledAmmo
	
	-- ADJUST POSITION HERE:
	local textX = 280  -- Center X position (200 = screen center)
	local textY = 200  -- Y position
	
	-- Rectangle dimensions
	local rectWidth = 100
	local rectHeight = 20
	local rectPadding = 5
	
	-- Draw white rectangle background (centered on text)
	g.setColor(g.kColorWhite)
	g.fillRect(textX - rectWidth/2 - rectPadding, textY - 2, rectWidth + rectPadding*2, rectHeight)
	
	-- Draw black text centered on top
	g.setColor(g.kColorBlack)
	g.drawTextAligned(ammoText, textX, textY, kTextAlignment.center)
end
 
function GameManager.getStateConstants()
	return GAME_STATE
end

-- Load the 11 rolling animation frames
-- Put your animation frames in: source/images/rolling_anim/
-- Name them: frame_1.png, frame_2.png, ... frame_11.png
function GameManager:loadRollingAnimFrames()
	local frames = {}
	local basePath = "images/rolling_anim/frame_"
	for i = 1, 11 do
		local img = gfx.image.new(basePath .. tostring(i))
		if img then
			table.insert(frames, img)
		else
			
		end
	end
	return frames
end

return GAME_STATE