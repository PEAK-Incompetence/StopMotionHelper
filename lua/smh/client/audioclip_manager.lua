---@class AudioClipManager
local MGR = {}

--- @type table<string, Wave[]>
local Waveforms = {}
local WAVEGENERATOR_ID = "SMH_WaveformGenerator_"
local SAMPLE_INTERVAL = 0.001

--- @param path string
local function GenerateWaveform(path)
	if Waveforms[path] then
		return Waveforms[path]
	end

	Waveforms[path] = {}
	sound.PlayFile(path, "noplay noblock", function(audioChannel)
		-- We can sample the levels from an audio clip even if the volume is set to low
		audioChannel:SetVolume(0)
		audioChannel:EnableLooping(false)
		audioChannel:Play()
		local timerId = WAVEGENERATOR_ID .. path
		timer.Create(timerId, SAMPLE_INTERVAL, audioChannel:GetLength() / SAMPLE_INTERVAL, function()
			local left, right = audioChannel:GetLevel()
			-- The fraction decouples from the time unit, allowing the waveform to fit the width of an audioclip_pointer
			local fraction = audioChannel:GetTime() / audioChannel:GetLength()
			---@type Wave
			local wave = {
				Left = left,
				Right = right,
				Fraction = fraction
			}
			table.insert(Waveforms[path], wave)
		end)
		timer.Start(timerId)
		-- Stop sampling at the end of the audio track
		timer.Simple(audioChannel:GetLength() + 0.1, function()
			timer.Remove(timerId)
		end)
	end)

	return Waveforms[path]
end

function MGR.GetWaveforms()
	return Waveforms
end

--- @param path string
--- @param frame integer
--- @param startTime number?
--- @param duration number?
--- @param clipCreatedCallback fun(newClip: AudioClip, newPointer: SMHAudioClipPointer)?
--- @return AudioClip[]
function MGR.Create(path, frame, startTime, duration, clipCreatedCallback)
	
	---@type AudioClip[]
    local audioclips = {}
	
	sound.PlayFile( path, "noplay noblock", function( station, errCode, errStr )
		if ( IsValid( station ) ) then
			local startTime = startTime or 0
			local duration = duration or station:GetLength()-startTime
			
			local audioclip = SMH.AudioClipData:New(station, path)
			audioclip.Frame = frame
			audioclip.Duration = duration
			audioclip.BaseDuration = station:GetLength()
			audioclip.StartTime = startTime
			audioclip.Waveform = GenerateWaveform(path)
			
			station:SetTime(startTime)
			station:EnableLooping(false)
			
			-- print( "SMH Audio: Loaded from '"..path.."'")
			
			SMH.Controller.UpdateServerAudio()
			local pointer = SMH.UI.CreateAudioClipPointer(audioclip)

			table.insert(audioclips, audioclip)

			if clipCreatedCallback then
				clipCreatedCallback(audioclip, pointer)
			end
		else
			print( "SMH Audio: Error loading file!", errCode, errStr )
		end
	end )

    return audioclips
end

local clipboard = {}

function MGR.Copy(ids, accumulate)
	if accumulate then
		clipboard = table.Add(clipboard, ids)
	else
		clipboard = ids
	end
end

function MGR.GetClipboard()
	return clipboard
end

function MGR.Paste(frame)
	for _, id in ipairs(clipboard) do
		local audioClip = SMH.AudioClipData.AudioClips[id]
		if audioClip then
			MGR.Create(audioClip.Path, frame, audioClip.StartTime, audioClip.Duration)
		end
	end
end

--- @param id number
--- @param frame integer
--- @return AudioClip
function MGR.TrimStart(id, frame)
	//get time between start frame and target frame
	//set start time
	//subtract time from duration
	//move start frame to target frame
	local audioClip = SMH.AudioClipData.AudioClips[id]
	if audioClip then
		local timeDifference = (frame - audioClip.Frame) / SMH.State.PlaybackRate
		if timeDifference <= 0 then 
			return 
		end

		audioClip.StartTime = audioClip.StartTime + timeDifference
		audioClip.Duration = audioClip.Duration - timeDifference
		audioClip.Frame = frame
	end
	return audioClip
end

--- @param id number
--- @param frame integer
--- @return AudioClip
function MGR.TrimEnd(id, frame)
	//get time between start frame and target frame
	//modify duration of clip based on frame input
	local audioClip = SMH.AudioClipData.AudioClips[id]
	if audioClip then
		local timeDifference = (frame - audioClip.Frame) / SMH.State.PlaybackRate
		local duration = audioClip.Duration
		if timeDifference >= duration then
			return
		end

		audioClip.Duration = timeDifference
	end
	return audioClip
end

SMH.AudioClipManager = MGR