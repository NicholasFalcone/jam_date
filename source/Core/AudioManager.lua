class('AudioManager').extends()

function AudioManager:init()
end

local sampleCache = {}

-- Load sound samples (for short SFX)
function AudioManager:loadSample(path)
    local sample = sampleCache[path]
    if not sample then
        local ok, s = pcall(function() return playdate.sound.sample.new(path) end)
        if ok and s then
            sample = s
            sampleCache[path] = sample
        else
            -- try with .wav suffix
            ok, s = pcall(function() return playdate.sound.sample.new(path..".wav") end)
            if ok and s then
                sample = s
                sampleCache[path] = sample
            end
        end
    end

    if sample then
        local ok, sp = pcall(function() return playdate.sound.sampleplayer.new(sample) end)
        if ok and sp then
            return sp
        end
    end

    -- Fallback
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
