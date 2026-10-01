local AUD = {}

--- @param id integer
---@return IGModAudioChannel
local function GetAudioChannelByID(id)
	if SMH.AudioClipData.AudioClips[id] then
		return SMH.AudioClipData.AudioClips[id].AudioChannel
	end
end

local function GetAudioClipData(id)
	if SMH.AudioClipData.AudioClips[id] then
		return SMH.AudioClipData.AudioClips[id]
	end
end


// Audio channel start/stop

--- @param id integer
--- @param startTime number?
function AUD.Play(id, startTime)
	local audioChannel = GetAudioChannelByID(id)
	local audioData = GetAudioClipData(id)
	
	startTime = startTime or audioData.StartTime
	
	if startTime ~= audioData.StartTime then
		audioChannel:SetTime(startTime)
	end
	-- Do some simple audio priority
	audioData.WillPlay = true
	if audioData.WillStop then
		audioData.WillStop = false
	end
	
	audioChannel:Play()
end

function AUD.Stop(id, rewind)
	rewind = rewind or true
	
	local audioChannel = GetAudioChannelByID(id)
	local audioData = GetAudioClipData(id)
	audioChannel:Pause()
	if rewind then
		audioChannel:SetTime(audioData.StartTime)
	end
end

function AUD.StopAll()
	if SMH.AudioClipData.AudioClips then
		for i,clip in pairs(SMH.AudioClipData.AudioClips) do
			AUD.Stop(clip.ID)
		end
	end
end

---@type table<integer, {[1]: AudioClipData, [2]: integer, [3]: boolean?}>
local audioStopQueue = {}
local function processStops()
	for _, audio in ipairs(audioStopQueue) do
		-- Prioritize playing audio over stopping them
		if audio[1].WillStop and not audio[1].WillPlay then
			AUD.Stop(audio[2], audio[3])
		end
	end
	audioStopQueue = {}
end
hook.Add("Think", "SMHAudioClipStopQueue", processStops)

-- Recommended to use this in the client.
-- Prevents a race condition where audio would stop and play at the same frame.
-- We prioritize playing audio over stopping.
function AUD.QueueStop(id, rewind)
	local audioData = GetAudioClipData(id)
	audioData.WillStop = true
	table.insert(audioStopQueue, {audioData, id, rewind})
end

-- function AUD.Destroy(id)
-- 	local audioChannel = GetAudioChannelByID(id)
-- 	audioChannel:Stop()
-- end

SMH.AudioClip = AUD