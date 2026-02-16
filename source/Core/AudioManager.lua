class('AudioManager').extends()

function AudioManager:init()
end

-- Load sound samples (for short SFX)
function AudioManager:loadSample(path)
	local ok, sp = pcall(function() return playdate.sound.sampleplayer.new(path) end)
	if ok then 
        return sp 
    end
	-- try with .wav suffix
	ok, sp = pcall(function() return playdate.sound.sampleplayer.new(path..".wav") end)
	if ok then 
        return sp 
    end
	return nil
end

-- Load music files (for longer tracks)
function AudioManager:loadMusic(path)
	local ok, fp = pcall(function() return playdate.sound.fileplayer.new(path) end)
	if ok then 
        return fp 
    end
	-- try with .wav suffix
	ok, fp = pcall(function() return playdate.sound.fileplayer.new(path..".wav") end)
	if ok then 
        return fp 
    end
	-- try with .mp3 suffix
	ok, fp = pcall(function() return playdate.sound.fileplayer.new(path..".mp3") end)
	if ok then 
        return fp 
    end
	return nil
end
