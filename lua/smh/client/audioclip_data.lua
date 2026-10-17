--- @class AudioClipData
local META = {}
META.__index = META

--- @param station IGModAudioChannel
--- @param path string
function META:New(station, path)
	if not self.AudioClips then
		self.AudioClips = {}
	end
	
    local audioClip = {
        ID = self.NextKeyframeId,
		Path = path,
		AudioChannel = station,
        Frame = -1,
        Duration = 1,
        BaseDuration = 1,
		StartTime = 0,
        Waveform = {},
    }
    self.NextKeyframeId = self.NextKeyframeId + 1
    
    self.AudioClips[audioClip.ID] = audioClip
    
    return audioClip
end

--- @param id number
function META:Delete(id)
    if not self.AudioClips[id] then
        return
    end
	self.AudioClips[id].AudioChannel:Stop()
    self.AudioClips[id] = nil
end

function META:DeleteAll()
	for k,v in pairs(self.AudioClips) do
		self:Delete(v.ID)
	end
end

--- @class AudioClipData
SMH.AudioClipData = {
	AudioClips = {},
    NextKeyframeId = 0
}
setmetatable(SMH.AudioClipData, META)
