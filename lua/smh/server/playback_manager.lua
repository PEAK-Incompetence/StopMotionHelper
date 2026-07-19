---@type table<Player, Playback>
local ActivePlaybacks = {}

local MGR = {}

local check = SMH.SettingsManager.CheckSetting
local getSetting = SMH.SettingsManager.GetSetting

local walkBetweenKeyframes = SMH.WalkBetweenKeyframes
local getBetweenKeyframes = SMH.GetBetweenKeyframes
---Increment the current frame, validate it, and return its new value
---@param increment number
---@param playback Playback
local function incrementFrame(increment, playback)
    playback.CurrentFrame = increment + playback.StartFrame
    if playback.CurrentFrame > playback.EndFrame then
        playback.CurrentFrame = 0
        playback.StartFrame = 0
        playback.Timer = 0
    end
    return playback.CurrentFrame
end

---Increment the `Playback.Timer` and return the new value 
---@param playback Playback
---@return number
local function incrementTime(playback)
    playback.Timer = playback.Timer + FrameTime()
    return playback.Timer
end


---Skip loading Physical Bone keyframes when enabled, so the animator can use other 
---physics bone body modifiers to either record manually or automatically with the physics recorder
---@param entity Entity
---@param modName string
---@param settings Settings
---@return boolean
local function checkPhysBake(entity, modName, settings)
    return modName == "physbones" and check(settings, "EnablePhysBake", entity)
end

---This is used to make the walking algorithm go the right direction
---@type {[Player]: number}
local frameHistory = {}

---Store the previous and next keyframes and the interval between them
---@type PlaybackCache
local playbackCache = {}

---Store the modifiers used per entity and update the cache on keyframe change
---@type ModifierCache
local modifierCache = {}

---@param entity Entity
---@param modName string
---@return boolean, FrameData?, FrameData?, number?
local function lookupPlaybackCache(player, entity, modName)
    local playerCache = playbackCache[player]
    local entityCache = playerCache and playerCache[entity]
    local modCache = entityCache and entityCache[modName]

    if modCache then
        return true, modCache[1], modCache[2], modCache[3]
    end

    return false
end

---@param player Player
---@param entity Entity
local function lookupModifierCache(player, entity)
    modifierCache[player] = modifierCache[player] or {}
    modifierCache[player][entity] = modifierCache[player][entity] or {}
    return modifierCache[player][entity]
end

---@param player Player
---@param entity Entity
---@param modName string
---@param prev FrameData?
---@param next FrameData?
---@return number
local function storePlaybackCache(player, entity, modName, prev, next)
    local invDelta = prev and next and prev ~= next and 1 / (next.Frame - prev.Frame) or 0
    playbackCache[player] = playbackCache[player] or {}
    playbackCache[player][entity] = playbackCache[player][entity] or {}
    local entry = playbackCache[player][entity][modName]
    if not playbackCache[player][entity][modName] then
        entry = {}
        playbackCache[player][entity][modName] = entry
    end
    entry[1] = prev
    entry[2] = next
    entry[3] = invDelta
    return invDelta
end

---@param player Player
---@param entity Entity
---@param modName string
---@param mod ModifierClass
---@return ModifierClass
local function storeModifierCache(player, entity, modName, mod)
    modifierCache[player] = modifierCache[player] or {}
    modifierCache[player][entity] = modifierCache[player][entity] or {}
    modifierCache[player][entity][modName] = mod
    return mod
end

---@param player Player
---@param entity Entity
function MGR.UpdateCacheFor(player, entity)
    if playbackCache[player] and IsValid(entity) then
        playbackCache[player][entity] = {}
        modifierCache[player][entity] = {}
    end
end

---@param player Player
function MGR.FlushCache(player)
    if not IsValid(player) then
        playbackCache = {}
        modifierCache = {}
        return
    end

    if playbackCache[player] then
        playbackCache[player] = {}
    end
    if modifierCache[player] then
        modifierCache[player] = {}
    end
end

function MGR.GetCache()
    return table.Copy(playbackCache) -- return a copy for dev purposes
end

hook.Add("EntityRemoved", "SMHPlaybackManagerEntityRemoved", function(entity)
    for _, entityTable in pairs(playbackCache) do
        entityTable[entity] = nil
    end
    for _, modTable in pairs(modifierCache) do
        modTable[entity] = nil
    end
end)

---@param player Player
---@param playback Playback
---@param settings Settings
local function PlaybackSmooth(player, playback, settings)
    local currentFrame = incrementFrame(playback.Timer * playback.PlaybackRate, playback)

    local playerData = SMH.KeyframeData.Players[player]
    if not playerData then
        return
    end

    local globalModifiers = SMH.Modifiers
    local entities = SMH.KeyframeData.Players[player].Entities
    local enableWorldKeyframes = tobool(player:GetInfo("smh_enableworldkeyframes"))
    local delta = currentFrame - (frameHistory[player] or currentFrame)

    for entity, keyframes in pairs(entities) do
        if entity == player then
            if enableWorldKeyframes then
                SMH.WorldKeyframesManager.Load(player, math.Round(currentFrame), keyframes)
                continue
            end
        end

        local entityModifiers = lookupModifierCache(player, entity)
        local mods = next(entityModifiers) and entityModifiers or globalModifiers
        local entitySettings = getSetting(settings, entity)
        local tweenDisabled = check(settings, "TweenDisable", entity)

        for name, mod in pairs(mods) do
            if checkPhysBake(entity, name, settings) then continue end

            local cached, prevKeyframe, nextKeyframe, invDelta = lookupPlaybackCache(player, entity, name)
            if 
                not cached 
                or (prevKeyframe and prevKeyframe.Frame > currentFrame) 
                or (nextKeyframe and nextKeyframe.Frame < currentFrame) 
            then
                prevKeyframe, nextKeyframe = walkBetweenKeyframes(keyframes, currentFrame, false, name, delta, prevKeyframe)
                invDelta = storePlaybackCache(player, entity, name, prevKeyframe, nextKeyframe)
            end
            if not prevKeyframe then
                continue
            end        
            ---@cast prevKeyframe FrameData
            ---@cast nextKeyframe FrameData
            if not entityModifiers[name] then
                storeModifierCache(player, entity, name, mod)
            end

            local prevFrame = prevKeyframe.Frame
            local nextFrame = nextKeyframe.Frame
            local prevData, nextData = prevKeyframe.Modifiers[name], nextKeyframe.Modifiers[name]

            if prevFrame == nextFrame then
                if prevData and nextData then
                    mod:Load(entity, prevData, entitySettings);
                end
            else
                local lerpMultiplier = (currentFrame - prevFrame) * invDelta
                lerpMultiplier = math.EaseInOut(lerpMultiplier, prevKeyframe.EaseOut[name], nextKeyframe.EaseIn[name])

                if lerpMultiplier <= 0 or tweenDisabled then
                    mod:Load(entity, prevData, entitySettings)
                elseif prevData and nextData then
                    mod:LoadBetween(entity, prevData, nextData, lerpMultiplier, entitySettings);
                end
            end
        end
    end
    frameHistory[player] = currentFrame
end

---Legacy set frame
---@param player Player
---@param newFrame integer
---@param settings Settings
function MGR.SelectFrame(player, newFrame, settings)
    local playerData = SMH.KeyframeData.Players[player]
    
    if not playerData then
        return
    end

    local entities = playerData.Entities
    local globalModifiers = SMH.Modifiers
    local enableWorldKeyframes = tobool(player:GetInfo("smh_enableworldkeyframes"))

    for entity, keyframes in pairs(entities) do
        if entity == player then
            if enableWorldKeyframes then
                SMH.WorldKeyframesManager.Load(player, newFrame, keyframes)
            end
            continue
        end

        local entityModifiers = lookupModifierCache(player, entity)
        local mods = next(entityModifiers) and entityModifiers or globalModifiers
        local entitySettings = getSetting(settings, entity)
        local tweenDisabled = check(settings, "TweenDisable", entity)

        for name, mod in pairs(mods) do
            if checkPhysBake(entity, name, settings) then continue end

            local cached, prevKeyframe, nextKeyframe, invDelta = lookupPlaybackCache(player, entity, name)
            if 
                not cached
                or (prevKeyframe and prevKeyframe.Frame > newFrame) 
                or (nextKeyframe and nextKeyframe.Frame <= newFrame)
            then
                prevKeyframe, nextKeyframe  = getBetweenKeyframes(keyframes, newFrame, false, name)
                invDelta = storePlaybackCache(player, entity, name, prevKeyframe, nextKeyframe)
            end
            if not prevKeyframe then
                continue
            end
            ---@cast prevKeyframe FrameData
            ---@cast nextKeyframe FrameData
            if not entityModifiers[name] then
                storeModifierCache(player, entity, name, mod)
            end

            local lerpMultiplier = (newFrame - prevKeyframe.Frame) * invDelta
            lerpMultiplier = math.EaseInOut(lerpMultiplier, prevKeyframe.EaseOut[name], nextKeyframe.EaseIn[name])
            if lerpMultiplier <= 0 or tweenDisabled then
                mod:Load(entity, prevKeyframe.Modifiers[name], entitySettings);
            elseif lerpMultiplier >= 1 then
                mod:Load(entity, nextKeyframe.Modifiers[name], entitySettings);
            else
                mod:LoadBetween(entity, prevKeyframe.Modifiers[name], nextKeyframe.Modifiers[name], lerpMultiplier, entitySettings);
            end
        end
    end
    frameHistory[player] = newFrame
end

---Playback performant set frame
---@param player Player
---@param newFrame integer
---@param settings Settings
function MGR.SetFrame(player, newFrame, settings)
    local playerData = SMH.KeyframeData.Players[player]
    
    if not playerData then
        return
    end

    local entities = playerData.Entities
    local globalModifiers = SMH.Modifiers
    local enableWorldKeyframes = tobool(player:GetInfo("smh_enableworldkeyframes"))
    local delta = newFrame - (frameHistory[player] or newFrame)

    for entity, keyframes in pairs(entities) do
        if entity == player then
            if enableWorldKeyframes then
                SMH.WorldKeyframesManager.Load(player, newFrame, keyframes)
            end
            continue
        end

        local entityModifiers = lookupModifierCache(player, entity)
        local mods = next(entityModifiers) and entityModifiers or globalModifiers
        local entitySettings = getSetting(settings, entity)
        local tweenDisabled = check(settings, "TweenDisable", entity)

        for name, mod in pairs(mods) do
            if checkPhysBake(entity, name, settings) then continue end

            local cached, prevKeyframe, nextKeyframe, invDelta = lookupPlaybackCache(player, entity, name)
            if 
                not cached
                or (prevKeyframe and prevKeyframe.Frame > newFrame) 
                or (nextKeyframe and nextKeyframe.Frame <= newFrame) 
            then
                prevKeyframe, nextKeyframe  = walkBetweenKeyframes(keyframes, newFrame, false, name, delta, prevKeyframe)
                invDelta = storePlaybackCache(player, entity, name, prevKeyframe, nextKeyframe)
            end
            if not prevKeyframe then
                continue
            end
            ---@cast prevKeyframe FrameData
            ---@cast nextKeyframe FrameData
            if not entityModifiers[name] then
                storeModifierCache(player, entity, name, mod)
            end

            local lerpMultiplier = (newFrame - prevKeyframe.Frame) * invDelta
            lerpMultiplier = math.EaseInOut(lerpMultiplier, prevKeyframe.EaseOut[name], nextKeyframe.EaseIn[name])
            if lerpMultiplier <= 0 or tweenDisabled then
                mod:Load(entity, prevKeyframe.Modifiers[name], entitySettings);
            elseif lerpMultiplier >= 1 then
                mod:Load(entity, nextKeyframe.Modifiers[name], entitySettings);
            else
                mod:LoadBetween(entity, prevKeyframe.Modifiers[name], nextKeyframe.Modifiers[name], lerpMultiplier, entitySettings);
            end
        end
    end
    frameHistory[player] = newFrame
end

---@param player Player
---@param newFrame integer
---@param settings Settings
---@param ignored Set<Entity>
function MGR.SetFrameIgnore(player, newFrame, settings, ignored)
    local playerData = SMH.KeyframeData.Players[player]
    if not playerData then
        return
    end

    local globalModifiers = SMH.Modifiers
    local entities = playerData.Entities
    local delta = newFrame - (frameHistory[player] or newFrame)

    for entity, keyframes in pairs(entities) do
        if ignored[entity] then continue end

        local entityModifiers = lookupModifierCache(player, entity)
        local mods = next(entityModifiers) and entityModifiers or globalModifiers
        local entitySettings = getSetting(settings, entity)
        local tweenDisabled = check(settings, "TweenDisable", entity)

        for name, mod in pairs(mods) do
            local cached, prevKeyframe, nextKeyframe, invDelta = lookupPlaybackCache(player, entity, name)
            if 
                not cached 
                or (prevKeyframe and prevKeyframe.Frame > newFrame) 
                or (nextKeyframe and nextKeyframe.Frame <= newFrame) 
            then
                prevKeyframe, nextKeyframe = walkBetweenKeyframes(keyframes, newFrame, false, name, delta, prevKeyframe)
                invDelta = storePlaybackCache(player, entity, name, prevKeyframe, nextKeyframe)
            end
            if not prevKeyframe then
                continue
            end
            ---@cast prevKeyframe FrameData
            ---@cast nextKeyframe FrameData
            if not entityModifiers[name] then
                storeModifierCache(player, entity, name, mod)
            end

            local lerpMultiplier = (newFrame - prevKeyframe.Frame) * invDelta
            lerpMultiplier = math.EaseInOut(lerpMultiplier, prevKeyframe.EaseOut[name], nextKeyframe.EaseIn[name])
            if lerpMultiplier <= 0 or tweenDisabled then
                mod:Load(entity, prevKeyframe.Modifiers[name], entitySettings);
            elseif lerpMultiplier >= 1 then
                mod:Load(entity, nextKeyframe.Modifiers[name], entitySettings);
            else
                mod:LoadBetween(entity, prevKeyframe.Modifiers[name], nextKeyframe.Modifiers[name], lerpMultiplier, entitySettings);
            end
        end
    end
    frameHistory[player] = newFrame
end

-- AUDIO PLAYBACK CONTROL ==========
local playerAudio = {} //list of audio clips to play
local audioStopFrames = {} //which frame to stop each audio clip at
-- =================================

---@param player Player
---@param startFrame integer
---@param endFrame integer
---@param playbackRate integer
---@param settings Settings
function MGR.StartPlayback(player, startFrame, endFrame, playbackRate, settings)
    ActivePlaybacks[player] = {
        StartFrame = startFrame,
        EndFrame = endFrame,
        PlaybackRate = playbackRate,
        TimePerFrame = 1 / playbackRate,
        CurrentFrame = startFrame,
        PrevFrame = startFrame - 1,
        Timer = 0,
        Settings = settings,
    }
    MGR.SetFrame(player, startFrame, settings)
end

---@param player Player
function MGR.StopPlayback(player)
    ActivePlaybacks[player] = nil
	table.Empty(audioStopFrames) -- AUDIO: clear stop frames table when playback is stopped by user
end

-- AUDIO ================================
function MGR.UpdateServerAudio(len,ply)
	if not playerAudio[ply] then
		playerAudio[ply] = {
			audioFrames = {}
		}
	end
	local audioTable = net.ReadTable()
	if audioTable ~= nil then
		table.Empty(playerAudio[ply].audioFrames)
		playerAudio[ply].audioFrames = audioTable
		print("SMH Audio: Updated serverside list of audios")
		print(table.ToString(playerAudio, "Player Audios", true))
	else
		print("SMH Audio: Error receiving audio list from client.")
	end
end

---@param player Player
---@param playback Playback
function MGR.AudioPlayback(player, playback)
    local currentFrame = math.floor(playback.Timer * playback.PlaybackRate) + playback.StartFrame

    --check for end of playback
	if currentFrame == playback.EndFrame then
		SMH.Controller.StopAllAudio(player)
		table.Empty(audioStopFrames) --clear stop frames table when playback reaches end of timeline
		return
	end
	--check for end of clip
	if audioStopFrames[currentFrame] then
		--stop audio
		for k,v in pairs(audioStopFrames[currentFrame]) do
			SMH.Controller.StopAudio(v.ID, player)
		end
		table.remove(audioStopFrames,currentFrame) --remove stop frames once playback has reached them
	end
	
	--check for start of clip
	if playerAudio[player] then
		if playerAudio[player].audioFrames[currentFrame] ~= nil then
			for i,clip in pairs(playerAudio[player].audioFrames[currentFrame]) do
				local audioFrame = clip
				
				--calculate end point
				local endFrame = math.ceil(currentFrame + playback.PlaybackRate * audioFrame.Duration)
				local audioStop = {
					ID = audioFrame.ID,
					Player = player
				}
				
				--add stop frame
				if not audioStopFrames[endFrame] then
					audioStopFrames[endFrame] = {
						audioStop
					}
				else
					table.insert(audioStopFrames[endFrame], audioStop)
				end
				
				--start audio
				SMH.Controller.PlayAudio(audioFrame.ID, player)
			end
		end
	end
end
-- ======================================
local AudioPlayback = MGR.AudioPlayback

local setFrame = MGR.SetFrame
hook.Add("Think", "SMHPlaybackManagerThink", function()
    for player, playback in pairs(ActivePlaybacks) do
        local timer = incrementTime(playback)
		AudioPlayback(player,playback) -- AUDIO PLAYBACK
		
        if not playback.Settings.SmoothPlayback or playback.Settings.TweenDisable then

            if timer >= 1 / playback.PlaybackRate then
                
                local currentFrame = incrementFrame(math.floor(timer * playback.PlaybackRate), playback)

                if currentFrame ~= playback.PrevFrame then
                    playback.PrevFrame = currentFrame
                    setFrame(player, currentFrame, playback.Settings)
                end

            end
        else
            PlaybackSmooth(player, playback, playback.Settings)
        end
    end
end)

SMH.PlaybackManager = MGR
