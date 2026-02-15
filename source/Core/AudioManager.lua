class('AudioManager').extends()

function AudioManager:init()
end

-- Load sound samples with fallback to .wav extension
function AudioManager:loadSample(path)
	local ok, sp = pcall(function() return playdate.sound.sampleplayer.new(path) end)
	if ok then 
        print("Loaded sound sample: " .. path)
        return sp 
    end
	-- try with .wav suffix too
	ok, sp = pcall(function() return playdate.sound.sampleplayer.new(path..".wav") end)
	if ok then 
        print("Loaded sound sample: " .. path .. ".wav")
        return sp 
    end
    -- try with .mp3 suffix too
    ok, sp = pcall(function() return playdate.sound.sampleplayer.new(path..".mp3") end)
    if ok then 
        print("Loaded sound sample: " .. path .. ".mp3")
        return sp 
    end
    print("Error loading sound sample: " .. path)
	return nil
end
