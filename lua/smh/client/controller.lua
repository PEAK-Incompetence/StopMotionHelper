local INT_BITCOUNT = 32
local KFRAMES_PER_MSG = 60
local MAX_MODIFIER_BITS = 8

local DECIMAL_BITS = 7
local function twoDecimalPrecision(x)
    return x / 100
end

local function ReceiveKeyframes()
    local framecount = net.ReadUInt(INT_BITCOUNT)
    for i = 1, framecount do
        local ID, entity, Frame, ModCount = net.ReadUInt(INT_BITCOUNT), net.ReadEntity(), net.ReadUInt(INT_BITCOUNT), net.ReadUInt(INT_BITCOUNT)
        --- @cast entity SMHEntity
        local Modifiers, In, Out = {}, {}, {}
        for j = 1, ModCount do
            local name = net.ReadUInt(MAX_MODIFIER_BITS)
            Modifiers[name] = true
            In[name] = twoDecimalPrecision(net.ReadUInt(DECIMAL_BITS)) --net.ReadFloat()
            Out[name] = twoDecimalPrecision(net.ReadUInt(DECIMAL_BITS)) --net.ReadFloat()
        end
        SMH.TableSplit.AKeyframes(ID, entity, Frame, In, Out, Modifiers)
    end
    return SMH.TableSplit.GetKeyframes()
end

--- @param Timelines integer
--- @param KeyColor Color[]
--- @param ModCount integer[]
--- @param Modifiers table
local function SendProperties(Timelines, KeyColor, ModCount, Modifiers)
    net.WriteUInt(Timelines, INT_BITCOUNT)
    for i=1, Timelines do
        net.WriteColor(KeyColor[i])
        net.WriteUInt(ModCount[i], INT_BITCOUNT)
        local modifierRow = Modifiers[i] or {}
        for j=1, ModCount[i] do
            net.WriteString(modifierRow[j])
        end
    end
end

local function ReceiveProperties()
    local Timelines = SMH.TableSplit.StartAProperties(net.ReadUInt(INT_BITCOUNT))
    for i=1, Timelines do
        SMH.TableSplit.AProperties(i, nil, net.ReadColor())
        for j=1, net.ReadUInt(INT_BITCOUNT) do
            SMH.TableSplit.AProperties(i, net.ReadString())
        end
    end
    return SMH.TableSplit.GetProperties()
end

local function RequestNodes()
    net.Start(SMH.MessageTypes.RequestNodes)
    net.WriteTable(SMH.Settings.GetAll())
    net.SendToServer()
end

--- Source: https://github.com/NO-LOAFING/AnimpropOverhaul/blob/a3a6268a5d57655611a8b8ed43dcf43051ecd93a/lua/entities/prop_animated.lua#L3550
--- @param ent Entity Entity in reference pose
--- @return table defaultPose Array consisting of a bones offsets from the entity, and offsets from its parent bones
function GetDefaultPoseTree(ent)
	local defaultPose = {}
	local entPos = ent:GetPos()
	local entAngles = ent:GetAngles()
	for b = 0, ent:GetBoneCount() - 1 do
		local parent = ent:GetBoneParent(b)
        local isPhysBone = b == ent:TranslatePhysBoneToBone(ent:TranslateBoneToPhysBone(b))
		local bMatrix = ent:GetBoneMatrix(b)
		if bMatrix then
			local pos1, ang1 = WorldToLocal(bMatrix:GetTranslation(), bMatrix:GetAngles(), entPos, entAngles)
			local pos2, ang2 = pos1 * 1, ang1 * 1
			if parent > -1 then
				local pMatrix = ent:GetBoneMatrix(parent)
				pos2, ang2 = WorldToLocal(
					bMatrix:GetTranslation(),
					bMatrix:GetAngles(),
					pMatrix:GetTranslation(),
					pMatrix:GetAngles()
				)
			end

			defaultPose[b + 1] = { pos1, ang1, pos2, ang2, parent, isPhysBone }
		else
			defaultPose[b + 1] = { vector_origin, angle_zero, vector_origin, angle_zero, -1, false }
		end
	end

	return defaultPose
end

local function RequestDefaultPose()
    local entity = net.ReadEntity()
    --- @cast entity SMHEntity

    if entity:GetClass() == "prop_effect" and IsValid(entity.AttachedEntity) then
        entity = entity.AttachedEntity
    end

    ---@diagnostic disable
    local csModel = ClientsideModel(entity:GetModel())
    csModel:DrawModel()
	csModel:SetupBones()
	csModel:InvalidateBoneCache()
    local tree = GetDefaultPoseTree(csModel)
    csModel:Remove()
    ---@diagnostic enable

    net.Start(SMH.MessageTypes.RequestDefaultPoseResponse)
    net.WriteString(entity:GetModel()) ---@diagnostic disable-line: param-type-mismatch
    net.WriteUInt(#tree, 8)
    for i = 1, #tree do
        net.WriteVector(tree[i][1])
        net.WriteAngle(tree[i][2])
        net.WriteVector(tree[i][3])
        net.WriteAngle(tree[i][4])
        net.WriteInt(tree[i][5], 9)
        net.WriteBool(tree[i][6])
    end
    net.SendToServer()
end

--- [CLIENT]
--- 
--- Sends requests to the server
--- @class SMH.ClientController
local CTRL = {}

--- Set to a `frame` of the animation
--- 
--- This method also sends the (entity) settings.
--- @param frame integer
function CTRL.SetFrame(frame)
    if SMH.PhysRecord.IsActive() or (frame < 0) then return end

    local settings = SMH.Settings.GetAll()
    net.Start(SMH.MessageTypes.SetFrame)
    net.WriteUInt(frame, INT_BITCOUNT)
    net.WriteTable(settings)
    net.WriteUInt(SMH.State.Timeline, INT_BITCOUNT)
    net.SendToServer()

    RequestNodes()
end

--- Select the `entity` record keyframes. 
--- 
--- For multi-selection, this function gets called again, but with an accumulating `enttable` argument
--- which is usually comes from the `SMH.State.Entity` field
--- @param entity SMHEntity|Player
--- @param enttable Set<Entity>
function CTRL.SelectEntity(entity, enttable)
    if SMH.PhysRecord.IsActive() then return end
    local count = 0

    for ent, _ in pairs(enttable) do
        count = count + 1
    end

    net.Start(SMH.MessageTypes.SelectEntity)
    net.WriteEntity(entity)
    net.WriteUInt(count, INT_BITCOUNT)
    for tentity, _ in pairs(enttable) do
        net.WriteEntity(tentity)
    end
    net.SendToServer()
end

-- AUDIO =========================

--- @param path string 
function CTRL.AddAudio(path)
	local frame = SMH.State.Frame

	-- print(path, frame)
	
	local audioclips = SMH.AudioClipManager.Create(path, frame)
end

--- Delete the audio clip from its `id` and its associated `pointer`
--- @param id integer 
--- @param pointer SMHAudioClipPointer
function CTRL.DeleteAudio(id, pointer)
	SMH.AudioClipData:Delete(id)
	if pointer ~= nil then
		SMH.UI.DeleteAudioClipPointer(pointer)
	end
	CTRL.UpdateServerAudio()
end

--- Delete all audio clips
function CTRL.DeleteAllAudio()
	SMH.AudioClipData:DeleteAll()
	SMH.UI.DeleteAllAudioClipPointers()
	CTRL.UpdateServerAudio()
end

--- Notify the server of changes to audio updates. 
--- 
--- **This must be called after any functions that add, delete, or trim audio**
function CTRL.UpdateServerAudio()
	local audioTable = {}
	for i,clip in pairs(SMH.AudioClipData.AudioClips) do
		if audioTable[clip.Frame] == nil then
			audioTable[clip.Frame] = {}
		end
		table.insert(audioTable[clip.Frame], {
			ID = clip.ID,
			Duration = clip.Duration
		})
	end
	
	net.Start(SMH.MessageTypes.UpdateServerAudio)
	net.WriteTable(audioTable)
	net.SendToServer()
end
-- ===============================

--- Record a keyframe, either at a specified `frame` or on the playhead (`SMH.State.Frame`)
--- @param frame integer?
function CTRL.Record(frame)
    if not next(SMH.State.Entity) or SMH.State.Frame < 0 or SMH.State.Timeline < 1 or SMH.PhysRecord.IsActive() or (frame and frame < 0) then
        return
    end
    SMH.State.TimeStamp = RealTime()
    local count = 0

    for ent, _ in pairs(SMH.State.Entity) do
        count = count + 1
    end

    net.Start(SMH.MessageTypes.CreateKeyframe)
    net.WriteUInt(count, INT_BITCOUNT)
    for entity, _ in pairs(SMH.State.Entity) do
        net.WriteEntity(entity)
    end
    net.WriteUInt(frame or SMH.State.Frame, INT_BITCOUNT)
    net.WriteUInt(SMH.State.Timeline, INT_BITCOUNT)
    net.SendToServer()
end

--- Modify the animation length, composed by the selected group of keyframes.
--- 
--- Two types of behavior happen with stretching / compression
--- 1. If stretching, this will replace keyframes outside of the selected keyframes
--- 2. If compressing, this will replace keyframes inside the selected keyframes
--- 
--- The stretching / compression pivot is the first frame. 
--- @param frames {[1]: SMHFramePointer, [2]: integer}[]
--- @param amount number
function CTRL.Stretch(frames, amount)
    local firstFrame = frames[1][2]
    local start, last, interval = #frames, 2, -1
    if amount < 1 then
        start, last, interval = 2, #frames, 1
    end

    local co = coroutine.wrap(function()
        local taken = table.Flip(frames)
        for i = start, last, interval do
            local newPosition = math.floor((frames[i][2] - firstFrame) * amount) + firstFrame
            local pointer = frames[i][1]

            if taken[newPosition] then
                --- @type integer[]
                local data = {}
                if amount > 1 then
                    data = SMH.UI.GetKeyframesOnFrame(newPosition) or {}
                else
                    for id, _ in pairs(pointer:GetIDs()) do
                        table.insert(data, id)
                    end
                    taken[i] = nil
                end
                if data[1] ~= nil then
                    SMH.Controller.DeleteKeyframe(data)
                end
                continue
            end
            pointer:SetFrame(newPosition)
            pointer:OnPointerReleased(newPosition)
            taken[newPosition] = true
            taken[i] = nil

            coroutine.yield(false)
        end

        coroutine.yield(true)
    end)

    timer.Remove("SMH_Stretching_Timer")
    timer.Create("SMH_Stretching_Timer", 0, -1, function()
        local done = co()
        if done then
            timer.Remove("SMH_Stretching_Timer")
            RequestNodes()
        end
    end)

    timer.Start("SMH_Stretching_Timer")
end

--- Apply the arc trick (Eltorro64Rus's smoothing method) to reduce the jerkiness of a motion
--- 
--- Smoothing is applied to the animator's selected `frames`. The `maxPasses` is the smoothing factor:
--- higher results in a smoother result.
--- 
--- @param frames integer[]
--- @param maxPasses integer
function CTRL.Smooth(frames, maxPasses)
    local co = coroutine.wrap(function()
        for p = 1, maxPasses do
            local smoothingFrames = {}

            for i, keyframe in ipairs(frames) do
                if keyframe >= 0 and not smoothingFrames[keyframe] and SMH.UI.IsFrameKeyframe(keyframe) then
                    SMH.Controller.SetFrame(keyframe-1)
                    coroutine.wait(0)
                    SMH.Controller.Record(keyframe-1)
                    coroutine.wait(0)
                    SMH.Controller.SetFrame(keyframe+1)
                    coroutine.wait(0)
                    SMH.Controller.Record(keyframe+1)
                    coroutine.wait(0)

                    local exists = SMH.UI.GetKeyframesOnFrame(keyframe)
                    if not exists then continue end
                    SMH.Controller.DeleteKeyframe(exists)
                    smoothingFrames[keyframe-1] = keyframe-1
                    smoothingFrames[keyframe+1] = keyframe+1

                    table.insert(frames, keyframe-1)
                    table.insert(frames, keyframe+1)
                    table.remove(frames, i)
                end
                table.sort(frames)
            end

            coroutine.yield(false)
        end
        coroutine.yield(true)
    end)

    timer.Remove("SMH_Smoothing_Timer")
    timer.Create("SMH_Smoothing_Timer", 0, -1, function()
        local done = co()
        if done then
            chat.AddText("SMH Smoothing stopped.")
            timer.Remove("SMH_Smoothing_Timer")
        end
    end)

    timer.Start("SMH_Smoothing_Timer")
end

--- If internal `updateData`` for a keyframe of a specific `keyframeId` has been modified,
--- then update the keyframe data on the server realm
--- @param keyframeId integer[]
--- @param updateData any
--- @param singledata any
function CTRL.UpdateKeyframe(keyframeId, updateData, singledata)
    local keyframeAmount = #keyframeId

    for i = 1, math.ceil(keyframeAmount / KFRAMES_PER_MSG) do
        local keyframesToSend = keyframeAmount - KFRAMES_PER_MSG * (i - 1) > KFRAMES_PER_MSG and KFRAMES_PER_MSG or keyframeAmount - KFRAMES_PER_MSG * (i - 1)

        net.Start(SMH.MessageTypes.UpdateKeyframe)
        net.WriteUInt(keyframesToSend, INT_BITCOUNT)

        for ids = 1 + KFRAMES_PER_MSG * (i - 1), keyframesToSend + KFRAMES_PER_MSG * (i - 1) do
            net.WriteUInt(keyframeId[ids], INT_BITCOUNT)

            if singledata then
                for data, value in pairs(updateData) do
                    net.WriteString(data)
                    if data == "Frame" then
                        net.WriteUInt(value, INT_BITCOUNT)
                    else
                        net.WriteFloat(value)
                    end
                end
            else
                for data, value in pairs(updateData[ids]) do
                    net.WriteString(data)
                    if data == "Frame" then
                        net.WriteUInt(value, INT_BITCOUNT)
                    else
                        net.WriteFloat(value)
                    end
                end
            end
        end
        net.WriteUInt(SMH.State.Timeline, INT_BITCOUNT)
        net.SendToServer()
    end

    net.Start(SMH.MessageTypes.UpdateKeyframeExecute)
    net.SendToServer()

    RequestNodes()
end

--- Copies an array of keyframe data and move them to a new place on the timeline
--- @param keyframeId integer[]
--- @param frame table
function CTRL.CopyKeyframe(keyframeId, frame)
    local keyframeAmount = #keyframeId

    for i = 1, math.ceil(keyframeAmount / KFRAMES_PER_MSG) do
        local keyframesToSend = keyframeAmount - KFRAMES_PER_MSG * (i - 1) > KFRAMES_PER_MSG and KFRAMES_PER_MSG or keyframeAmount - KFRAMES_PER_MSG * (i - 1)

        net.Start(SMH.MessageTypes.CopyKeyframe)
        net.WriteUInt(keyframesToSend, INT_BITCOUNT)

        for ids = 1 + KFRAMES_PER_MSG * (i - 1), keyframesToSend + KFRAMES_PER_MSG * (i - 1) do
            net.WriteUInt(keyframeId[ids], INT_BITCOUNT)
            net.WriteUInt(frame[ids], INT_BITCOUNT)
        end
        net.WriteUInt(SMH.State.Timeline, INT_BITCOUNT)
        net.SendToServer()
    end

    net.Start(SMH.MessageTypes.CopyKeyframeExecute)
    net.SendToServer()

    RequestNodes()
end

--- Delete the keyframes of the specified `keyframeId`s
--- @param keyframeId integer[]
function CTRL.DeleteKeyframe(keyframeId)
    local keyframeAmount = #keyframeId

    for i = 1, math.ceil(keyframeAmount / KFRAMES_PER_MSG) do
        local keyframesToSend = keyframeAmount - KFRAMES_PER_MSG * (i - 1) > KFRAMES_PER_MSG and KFRAMES_PER_MSG or keyframeAmount - KFRAMES_PER_MSG * (i - 1)

        net.Start(SMH.MessageTypes.DeleteKeyframe)
        net.WriteUInt(keyframesToSend, INT_BITCOUNT)
        net.WriteUInt(SMH.State.Timeline, INT_BITCOUNT)

        for ids = 1 + KFRAMES_PER_MSG * (i - 1), keyframesToSend + KFRAMES_PER_MSG * (i - 1) do
            net.WriteUInt(keyframeId[ids], INT_BITCOUNT)
        end

        net.SendToServer()
    end

    RequestNodes()
end

local function PlayAudioInBetween()
    local currentFrame = SMH.State.Frame
    local playbackRate = SMH.State.PlaybackRate
    local secondsPerFrame = 1 / playbackRate
    -- AUDIO =========================
	//check for any clips that are partway through and play them from that point
	for i,clip in ipairs(SMH.AudioClipData.AudioClips) do
        local startFrame = clip.Frame
        local duration = clip.Duration
		//calculate end frame
		local endFrame = math.ceil(currentFrame + playbackRate * duration)
		if currentFrame > startFrame and currentFrame < endFrame then
			//calculate start point
			local startTime = ((currentFrame - startFrame - 0.5) * secondsPerFrame) + clip.StartTime
			SMH.AudioClip.Play(clip.ID, startTime)
            timer.Simple(duration - startTime, function()
                SMH.AudioClip.Stop(clip.ID)
            end)
		end
	end
	-- AUDIO =========================
end

--- Signal the playback manager to animate all entities owned by the client
--- @param startFrame integer
function CTRL.StartPlayback(startFrame)
    if SMH.PhysRecord.IsActive() then return end

    net.Start(SMH.MessageTypes.StartPlayback)
    net.WriteUInt(startFrame, INT_BITCOUNT)
    net.WriteUInt(SMH.State.PlaybackLength - 1, INT_BITCOUNT)
    net.WriteUInt(SMH.State.PlaybackRate, INT_BITCOUNT)
    net.WriteTable(SMH.Settings.GetAll())
    net.SendToServer()
	
    PlayAudioInBetween()
end

--- Signal the playback manager to stop for the client
function CTRL.StopPlayback()
    net.Start(SMH.MessageTypes.StopPlayback)
    net.SendToServer()
	
	-- AUDIO
	SMH.AudioClip.StopAll()
end

--- Get all animation saves owned by the server
function CTRL.GetServerSaves()
    net.Start(SMH.MessageTypes.GetServerSaves)
    net.SendToServer()
end

--- Get a list of models for an animation save of the specified `path`
--- @param path string
--- @param loadFromClient boolean?
function CTRL.GetModelList(path, loadFromClient)
    if loadFromClient then
        local models = SMH.Saves.ListModels(path, LocalPlayer())
        SMH.UI.SetModelList(models)
    else
        net.Start(SMH.MessageTypes.GetModelList)
        net.WriteString(path)
        net.SendToServer()
    end
end

--- Get all animatable entities owned by the client from the server
function CTRL.GetServerEntities()
    net.Start(SMH.MessageTypes.GetServerEntities)
    net.SendToServer()
end


--- Load an animation save from the `path` for an entity specified by its `modelName` (usually the model or its name defined by the Properties menu) 
--- @param path string
--- @param modelName string
--- @param loadFromClient boolean
function CTRL.Load(path, modelName, loadFromClient)
    if not next(SMH.State.Entity) then
        return
    end
    local entity = next(SMH.State.Entity)

    net.Start(SMH.MessageTypes.Load)

    net.WriteEntity(entity)
    net.WriteBool(loadFromClient)

    if loadFromClient then
        local serializedKeyframes, _, _, settings = SMH.Saves.LoadForEntity(path, modelName, LocalPlayer())
        --- @cast serializedKeyframes SMHFile
        --- @cast settings Settings
        if settings then
            SMH.Settings.Update(settings, SMH.State.Entity)
        end
        net.WriteTable(serializedKeyframes)
        net.WriteTable(settings)
    else
        net.WriteString(path)
        net.WriteString(modelName)
    end

    net.SendToServer()
end

--- For an animation save defined by `path`, get more information about the entity of `modelName`
--- @param path string
--- @param modelName string
--- @param loadFromClient boolean
function CTRL.GetModelInfo(path, modelName, loadFromClient)
    net.Start(SMH.MessageTypes.GetModelInfo)
    net.WriteString(path)
    net.WriteString(modelName)
    net.SendToServer()
end

--- @param path string
--- @param saveToClient boolean
--- @param isFolder boolean
function CTRL.RequestSave(path, saveToClient, isFolder)
    net.Start(SMH.MessageTypes.RequestSave)
    net.WriteBool(saveToClient)
    net.WriteBool(isFolder)
    net.WriteString(path)
    net.WriteTable(SMH.Settings.GetAll(true))
    net.SendToServer()
end

--- Request the server to save an animation into the `path`.
--- 
--- If we are using the autosave feature, `isAutoSave` is set to `true`, which
--- lets the server handle the autosaved animation. 
--- @param path string
--- @param isAutoSave boolean?
function CTRL.Save(path, isAutoSave)
    net.Start(SMH.MessageTypes.Save)
    net.WriteString(path)
    net.WriteBool(isAutoSave ~= nil and true or false)
    net.WriteTable(SMH.Settings.GetAll(true))
    net.SendToServer()
end

--- @param path string
--- @param toClient boolean
function CTRL.RequestGoToFolder(path, toClient)
    net.Start(SMH.MessageTypes.RequestGoToFolder)
    net.WriteBool(toClient)
    net.WriteString(path)
    net.SendToServer()
end

--- @param path string
function CTRL.RequestAppend(path)
    net.Start(SMH.MessageTypes.RequestAppend)
    net.WriteString(path)
    net.SendToServer()
end

--- @param path string
--- @param savenames string[]
--- @param gamenames string[]
function CTRL.Append(path, savenames, gamenames)
    net.Start(SMH.MessageTypes.Append)
    local count = #savenames

    net.WriteString(path)
    net.WriteUInt(count, INT_BITCOUNT)
    for _, name in ipairs(savenames) do
        net.WriteString(name)
    end

    count = #gamenames
    net.WriteUInt(count, INT_BITCOUNT)
    for _, name in ipairs(gamenames) do
        net.WriteString(name)
    end
    net.SendToServer()
end

--- Uses the `Save` function to save an animation to the root 
function CTRL.QuickSave()
    local nick = LocalPlayer():Nick()
    local qs1 = "quicksave_" .. nick
    local qs2 = "quicksave_" .. nick .. "_backup"

    SMH.Saves.CopyIfExists(qs1, qs2, LocalPlayer())
    CTRL.Save(qs1)
end

--- Request the server to remove `SMHPackage` info from every animatable entity
function CTRL.RequestUnpack()
    net.Start(SMH.MessageTypes.RequestUnpack)
    net.SendToServer()
end

--- Request the server to pack animation data into an `SMHPackage` for every animatable entity
--- 
--- Depending on the value of `smh_packentity`, `path` gets stored in the `SMHPackage` of an entity 
--- @param path string
function CTRL.RequestPack(path)
    net.Start(SMH.MessageTypes.RequestPack)
    net.WriteString(path)
    net.WriteTable(SMH.Settings.GetAll(true))
    net.SendToServer()
end

--- Request the server to delete the animation file. If `deleteFromClient` is `true`, then
--- delete the animation file directly 
--- @param path string
--- @param isFolder boolean
--- @param deleteFromClient boolean
function CTRL.DeleteSave(path, isFolder, deleteFromClient)
    if deleteFromClient then
        SMH.Saves.Delete(path, LocalPlayer())
    else
        net.Start(SMH.MessageTypes.DeleteSave)
        net.WriteBool(isFolder)
        net.WriteString(path)
        net.SendToServer()
    end
end

-- AUDIO SAVES ====================================================

---Save the audio clips on the timeline to an audio sequence file (defined as .txt)
---@param path string
function CTRL.SaveAudioSeq(path)
	//all clientside
	local keyframes = SMH.AudioClipData.AudioClips
	local serializedClips = SMH.AudioSeqSaves.Serialize(keyframes)
	SMH.AudioSeqSaves.Save(path, serializedClips)
end

--- Delete the audio sequence file
--- @param path string
function CTRL.DeleteAudioSeq(path)
	SMH.AudioSeqSaves.Delete(path)
end

--- Load the audio sequence file from the `path`.
--- 
--- If `setFrameRate` is `true`, this also sets the frame count and FPS
---@param path string
---@param setFrameRate boolean
function CTRL.LoadAudioSeq(path, setFrameRate)
	local setFrameRate = setFrameRate or false
	
	// Clear audio clips
	CTRL.DeleteAllAudio()
	
	// Create new clips
	local loadFile = SMH.AudioSeqSaves.Load(path)
	local audioClipLoad = loadFile.Clips
	for k,v in pairs(audioClipLoad) do
		if v.Path and v.Frame and v.StartTime and v.Duration then
			SMH.AudioClipManager.Create(v.Path, v.Frame, v.StartTime, v.Duration)
		else
			print("SMH Audio: Sequence file contains errors!")
		end
	end
	
	//Set frame rate if required
	if setFrameRate then
		local newState = {
			Frame = SMH.State.Frame,
			PlaybackRate = loadFile.PlaybackRate,
			PlaybackLength = loadFile.PlaybackLength
		}
		CTRL.UpdateState(newState, true)
	end
end
-- ================================================================

function CTRL.ShouldHighlight()
    return SMH.UI.IsOpen()
end

--- Start or stop the rendering process, depending on `SMH.Renderer` state
--- 
--- The `StartFrame` can be specified to begin the render at a specific frame
--- @param renderCmd string
--- @param StartFrame integer
function CTRL.ToggleRendering(renderCmd, StartFrame)
    if SMH.PhysRecord.IsActive() then return end

    if SMH.Renderer.IsRendering() then
        SMH.Renderer.Stop()
    else
        SMH.Renderer.Start(renderCmd, StartFrame)
    end
end

--- Open the timeline
function CTRL.OpenMenu()
    SMH.UI.Open()
end

--- Close the timeline
function CTRL.CloseMenu()
    SMH.UI.Close()
end

--- Update `SMH.State` with `newState`
--- @param newState NewState
--- @param updatePlaybackControls any
function CTRL.UpdateState(newState, updatePlaybackControls)
	local updatePlaybackControls = updatePlaybackControls or false
	
    local allowedKeys = {
        Frame = true,
        Timeline = true,
        PlaybackRate = true,
        PlaybackLength = true,
    }

    for k, v in pairs(newState) do
        if not allowedKeys[k] then
            error("Key not allowed: " .. k)
        end
        SMH.State[k] = v
    end

    SMH.UI.UpdateState(SMH.State, updatePlaybackControls)
end

--- Update settings for the selected entities
--- @param newSettings any
function CTRL.UpdateSettings(newSettings)
    SMH.Settings.Update(newSettings, SMH.State.Entity)
end

--- Update the `setting` on the UI to a `value` 
function CTRL.UpdateUISetting(setting, value)
    SMH.UI.UpdateUISetting(setting, value)
end

function CTRL.OpenHelp()
    gui.OpenURL("https://github.com/Winded/StopMotionHelper/blob/master/TUTORIAL.md")
end

--- Notify the server about the new `rendering` state
--- @param rendering boolean
function CTRL.SetRendering(rendering)
    net.Start(SMH.MessageTypes.SetRendering)
    net.WriteBool(rendering)
    net.SendToServer()

    local entities = {}
    for _, entity in ents.Iterator() do
        if entity.GetModel and entity:GetModel() then
            table.insert(entities, entity)
        end
    end
end

--- Update the server ghost data 
function CTRL.UpdateGhostState()
    net.Start(SMH.MessageTypes.UpdateGhostState)
    net.WriteTable(SMH.Settings.GetAll())
    net.SendToServer()
end

--- Update the entity's name from the Properties menu for the server 
--- @param ent Entity
--- @param name string
function CTRL.ApplyEntityName(ent, name)
    net.Start(SMH.MessageTypes.ApplyEntityName)
    net.WriteEntity(ent)
    net.WriteString(name)
    net.SendToServer()
end

--- Update the timeline for selected entities
function CTRL.UpdateTimeline()
    local count = 0

    for ent, _ in pairs(SMH.State.Entity) do
        count = count + 1
    end

    net.Start(SMH.MessageTypes.UpdateTimeline)
    net.WriteUInt(count, INT_BITCOUNT)
    for entity, _ in pairs(SMH.State.Entity) do
        net.WriteEntity(entity)
    end
    net.SendToServer()
end

--- Request new modifier data from the server
function CTRL.RequestModifiers()
    net.Start(SMH.MessageTypes.RequestModifiers)
    net.SendToServer()
end

--- Add a timeline
function CTRL.AddTimeline()
    net.Start(SMH.MessageTypes.AddTimeline)
    net.SendToServer()
end

--- Remove a timeline
function CTRL.RemoveTimeline()
    net.Start(SMH.MessageTypes.RemoveTimeline)
    net.SendToServer()
end

--- Notify the server of an updated modifier state 
--- @param i integer
--- @param mod string
--- @param check boolean
function CTRL.UpdateModifier(i, mod, check)
    net.Start(SMH.MessageTypes.UpdateModifier)
    net.WriteUInt(i, INT_BITCOUNT)
    net.WriteString(mod)
    net.WriteBool(check)
    net.SendToServer()
end

--- Give a new keyframe `color` to the server, for a specified `timeline`.
--- @param color Color
--- @param timeline integer
function CTRL.UpdateKeyframeColor(color, timeline)
    net.Start(SMH.MessageTypes.UpdateKeyframeColor)
    net.WriteUInt(timeline, INT_BITCOUNT)
    net.WriteColor(color)
    net.SendToServer()
end

--- Show the preview entity of the first frame of an animation (specified by `path`), with a given `model` 
--- @param path string
--- @param model string
--- @param loadFromClient boolean
function CTRL.SetPreviewEntity(path, model, loadFromClient)
    net.Start(SMH.MessageTypes.SetPreviewEntity)
    net.WriteString(path)
    net.WriteString(model)
    net.WriteTable(SMH.Settings.GetAll())
    net.SendToServer()
end

--- @param state boolean
function CTRL.SetSpawnGhost(state)
    net.Start(SMH.MessageTypes.SetSpawnGhost)
    net.WriteBool(state)
    net.SendToServer()
end

--- Spawn an animated entity for an animation save specified by `path` and the animation specified by `model`
--- @param path string
--- @param model string
--- @param loadFromClient boolean
function CTRL.SpawnEntity(path, model, loadFromClient)
    if SMH.PhysRecord.IsActive() then return end

    net.Start(SMH.MessageTypes.SpawnEntity)
    net.WriteString(path)
    net.WriteString(model)
    net.WriteTable(SMH.Settings.GetAll())
    net.SendToServer()
end

function CTRL.SpawnReset()
    net.Start(SMH.MessageTypes.SpawnReset)
    net.SendToServer()
end

--- @param set boolean
function CTRL.SetSpawnOffsetMode(set)
    net.Start(SMH.MessageTypes.SetSpawnOffsetMode)
    net.WriteBool(set)
    net.SendToServer()
end

--- @param path string
--- @param model string
--- @param loadFromClient boolean
function CTRL.SetSpawnOrigin(path, model, loadFromClient)
    net.Start(SMH.MessageTypes.SetSpawnOrigin)
    net.WriteString(path)
    net.WriteString(model)
    net.SendToServer()
end

--- @param Pos Vector
function CTRL.OffsetPos(Pos)
    net.Start(SMH.MessageTypes.OffsetPos)
    net.WriteVector(Pos)
    net.SendToServer()
end

--- @param Ang Angle
function CTRL.OffsetAng(Ang)
    net.Start(SMH.MessageTypes.OffsetAng)
    net.WriteAngle(Ang)
    net.SendToServer()
end

--- Change the timeline to modify on the server
--- @param settings Properties
--- @param presetname string
function CTRL.SetTimeline(settings, presetname)
    net.Start(SMH.MessageTypes.SetTimeline)
    net.WriteBool(presetname == "default")
    if not (presetname == "default") then
        local Timelines, KeyColor, ModCount, Modifiers = SMH.TableSplit.DProperties(settings)
        --- @cast Timelines integer
        --- @cast KeyColor Color[]
        --- @cast ModCount integer[]
        --- @cast Modifiers table
        SendProperties(Timelines, KeyColor, ModCount, Modifiers)
    end
    net.SendToServer()
end

--- Get new timeline information of specified `name` from the server
--- @param name string
function CTRL.RequestTimelineInfo(name)
    net.Start(SMH.MessageTypes.RequestTimelineInfo)
    net.WriteString(name)
    net.SendToServer()
end

--- Get world keyframe data from the server for a specified `frame`
--- @param frame integer
function CTRL.RequestWorldData(frame)
    net.Start(SMH.MessageTypes.RequestWorldData)
    net.WriteUInt(frame, INT_BITCOUNT)
    net.SendToServer()
end

--- Update world keyframe data on the server
--- @param str string
--- @param key string
function CTRL.UpdateWorld(str, key)
    net.Start(SMH.MessageTypes.UpdateWorld)
    net.WriteString(str)
    net.WriteString(key)
    net.WriteUInt(SMH.State.Frame, INT_BITCOUNT)
    net.SendToServer()
end

--- Tell the server to start its physics recorder
--- @param framecount integer
--- @param interval integer
--- @param entities table<Entity, integer>
function CTRL.StartPhysicsRecord(framecount, interval, entities)
    if not next(entities) or SMH.State.Frame < 0 or SMH.State.Timeline < 1 then
        return
    end

    net.Start(SMH.MessageTypes.StartPhysicsRecord)
    net.WriteUInt(framecount, INT_BITCOUNT)
    net.WriteUInt(interval, INT_BITCOUNT)
    net.WriteUInt(SMH.State.Frame, INT_BITCOUNT)
    net.WriteUInt(SMH.State.PlaybackRate, INT_BITCOUNT)
    net.WriteUInt(SMH.State.PlaybackLength, INT_BITCOUNT)
    net.WriteUInt(table.Count(entities), INT_BITCOUNT)
    for entity, timeline in pairs(entities) do
        net.WriteEntity(entity)
        net.WriteUInt(timeline, INT_BITCOUNT)
    end
    net.WriteTable(SMH.Settings.GetAll())
    net.SendToServer()

    PlayAudioInBetween()
end

--- Tell the server to stop its physics recorder
function CTRL.StopPhysicsRecord()
    net.Start(SMH.MessageTypes.StopPhysicsRecord)
    net.SendToServer()
end

--- Begin a new slate. Also tell the server to remove everything 
function CTRL.RequestNewSession()
    local entities = {}
    SMH.State.Entity = entities
    SMH.UI.SetSelectedEntity(entities)
    SMH.UI.SetKeyframes(entities)
    net.Start(SMH.MessageTypes.RequestNewSession)
    net.SendToServer()
end

SMH.Controller = CTRL

local function SetFrameResponse(msgLength)
    local frame = net.ReadUInt(INT_BITCOUNT)
    SMH.State.Frame = frame
    SMH.State.TimeStamp = RealTime()
    SMH.UI.SetFrame(frame)

    hook.Run("SMH_PostSetFrame", frame)
end

local function SelectEntityResponse(msgLength)
    local keyframes = ReceiveKeyframes()
    local entities = {}
    local entityList = {}
    for i = 1, net.ReadUInt(INT_BITCOUNT) do
        local ent = net.ReadEntity()
        entities[ent] = true
        entityList[i] = ent
    end

    local entity = next(entities)

    SMH.State.Entity = entities
    
    SMH.State.TimeStamp = RealTime()
    SMH.UI.SetSelectedEntity(entities)
    SMH.UI.SetUsingWorld(entity == LocalPlayer())
    SMH.UI.SetKeyframes(keyframes)


    hook.Run("SMH_PostSelectEntity", entity, entityList)
end

local function UpdateKeyframeResponse(msgLength)
    local keyframes = ReceiveKeyframes()

    for num, keyframe in ipairs(keyframes) do
        if SMH.State.Entity[keyframe.Entity] then
            SMH.UI.UpdateKeyframe(keyframe)
        end
    end
end

local function UpdateNode(msgLength)
    local frame = net.ReadUInt(INT_BITCOUNT)
    local node = net.ReadTable(true)
    ---@cast node SerializedNode
    SMH.Renderer.UpdateNode(frame, node)
end

local function DeleteKeyframeResponse(msgLength)
    local keyframeId = net.ReadUInt(INT_BITCOUNT)
    SMH.UI.DeleteKeyframe(keyframeId)
end

local function GetAllKeyframes(msgLength)
    local keyframes = ReceiveKeyframes()

    SMH.UI.SetKeyframes(keyframes, true)
end

local function GetServerSavesResponse(msgLength)
    for i=1, net.ReadUInt(INT_BITCOUNT) do
        SMH.TableSplit.ATable(i, net.ReadString())
    end
    local folders = SMH.TableSplit.GetTable()

    for i=1, net.ReadUInt(INT_BITCOUNT) do
        SMH.TableSplit.ATable(i, net.ReadString())
    end
    local saves = SMH.TableSplit.GetTable()
    local path = net.ReadString()
    ---@cast folders string[] 
    ---@cast saves string[]

    SMH.UI.SetServerSaves(folders, saves, path)
end

local function GetModelListResponse(msgLength)
    for i=1, net.ReadUInt(INT_BITCOUNT) do
        SMH.TableSplit.ATable(i, net.ReadString())
    end
    local models = SMH.TableSplit.GetTable()
    ---@cast models string[]
    local map = net.ReadString()
    SMH.UI.SetModelList(models, map)
end

local function GetServerEntitiesResponse(msgLength)
    for i=1, net.ReadUInt(INT_BITCOUNT) do
        SMH.TableSplit.ATable(net.ReadEntity(), {Name = net.ReadString()})
    end
    local entities = SMH.TableSplit.GetTable()
    ---@cast entities Entities 
    SMH.UI.SetEntityList(entities)
end

local function LoadResponse(msgLength)
    local keyframes = ReceiveKeyframes()
    local entity = net.ReadEntity()
    local settings = net.ReadTable()
    ---@cast settings Settings

    if SMH.State.Entity[entity] then
        SMH.UI.SetKeyframes(keyframes)
        if GetConVar("smh_entity_settings"):GetBool() then
            SMH.Settings.Initialize(entity, settings)
            SMH.UI.UpdateUISettings(settings)
        end
    end
end

local function LoadResponseSettings(msgLength)
    local entity = net.ReadEntity()
    local settings = net.ReadTable()
    SMH.Settings.Initialize(entity, settings)
end

local function GetModelInfoResponse(msgLength)
    local name, class = net.ReadString(), net.ReadString()
    SMH.UI.SetModelName(name, class)
end

local function SaveExists(msgLength)
    local names = {}

    for i = 1, net.ReadUInt(INT_BITCOUNT) do
        table.insert(names, net.ReadString())
    end

    SMH.UI.SaveExistsWarning(names)
end

local function SaveResponse(msgLength)
    local saveToClient = net.ReadBool()
    local path = net.ReadString()
    if not saveToClient then
        CTRL.GetServerSaves() -- Refresh server saves
        return
    end

    local serializedKeyframes = net.ReadTable()
    SMH.Saves.Save(path, serializedKeyframes, LocalPlayer())
    SMH.UI.AddSaveFile(path)
end

local function AddFolderResponse(msgLength)
    local saveToClient = net.ReadBool()
    local folder = net.ReadString()
    if not saveToClient then
        CTRL.GetServerSaves()
        return
    end

    SMH.Saves.AddFolder(folder, LocalPlayer())
end

local function RequestAppendResponse(msgLength)
    local savenames, gamenames = {}, {}

    for i = 1, net.ReadUInt(INT_BITCOUNT) do
        table.insert(savenames, net.ReadString())
    end
    for i = 1, net.ReadUInt(INT_BITCOUNT) do
        table.insert(gamenames, net.ReadString())
    end

    SMH.UI.AppendWindow(savenames, gamenames)
end

local function DeleteSaveResponse(msgLength)
    local isFolder = net.ReadBool()
    local path = net.ReadString()

    SMH.UI.RemoveSaveFile(path, isFolder)
end

local function ApplyEntityNameResponse(msgLength)
    local name = net.ReadString()

    SMH.UI.UpdateName(name)
end

local function UpdateTimelineResponse(msgLength)
    local keyframes = ReceiveKeyframes()

    SMH.UI.SetKeyframes(keyframes)
end

local function RequestModifiersResponse(msgLength)
    local list = net.ReadTable()
    local ids = net.ReadTable(true)

    SMH.UI.InitModifiers(list, ids)
end

local function UpdateTimelineInfoResponse(msgLength)
    local timeline = ReceiveProperties()

    SMH.UI.SetTimeline(timeline)
end

local function UpdateModifierResponse(msgLength)
    local changed = net.ReadString()
    local timeline = ReceiveProperties()

    SMH.UI.UpdateModifier(timeline, changed)
    CTRL.UpdateTimeline()
end

local function UpdateKeyframeColorResponse(msgLength)
    local timelineinfo = ReceiveProperties()

    SMH.UI.UpdateKeyColor(timelineinfo)
end

local function RequestTimelineInfoResponse(msgLength)
    local name = net.ReadString()
    local timeline = ReceiveProperties()

    SMH.Saves.SaveProperties(timeline, name)
    SMH.UI.RefreshTimelineSettings()
end

local function RequestWorldDataResponse(msgLength)
    local console = net.ReadString()
    local push = net.ReadString()
    local release = net.ReadString()

    SMH.UI.SetWorldData(console, push, release)
end

local function StopPhysicsRecordResponse(msgLength)
    SMH.PhysRecord.Stop()
end

local function RequestNodesResponse(msgLength)
    ---@type NetworkedNode[]
    local nodes = {}
    local len = net.ReadUInt(14)
    for i = 1, len do 
        nodes[i] = {net.ReadUInt(14), net.ReadVector(), net.ReadAngle()}
    end

    SMH.Renderer.SetNodes(nodes)
end

-- AUDIO CONTROL =================
local function PlayAudio()
	--print("play audio")
	local id = net.ReadUInt(INT_BITCOUNT)
	SMH.AudioClip.Play(id)
end

local function StopAudio()
	--print("stop audio")
	local id = net.ReadUInt(INT_BITCOUNT)
	SMH.AudioClip.Stop(id)
end

local function StopAllAudio()
	--print("stop all audio")
	SMH.AudioClip.StopAll()
end
-- ===============================

local function ReceiveModifierIds(msgLength)
    local modCount = net.ReadUInt(MAX_MODIFIER_BITS)
    local modNames = {}
    for i = 1, modCount do
        modNames[i] = net.ReadString()
    end

end

local function PlaybackResponse(msgLength) end

local function Setup()
    net.Receive(SMH.MessageTypes.SetFrameResponse, SetFrameResponse)

    net.Receive(SMH.MessageTypes.SelectEntityResponse, SelectEntityResponse)

    net.Receive(SMH.MessageTypes.UpdateKeyframeResponse, UpdateKeyframeResponse)
    net.Receive(SMH.MessageTypes.DeleteKeyframeResponse, DeleteKeyframeResponse)
    net.Receive(SMH.MessageTypes.GetAllKeyframes, GetAllKeyframes)

    net.Receive(SMH.MessageTypes.GetServerSavesResponse, GetServerSavesResponse)
    net.Receive(SMH.MessageTypes.GetModelListResponse, GetModelListResponse)
    net.Receive(SMH.MessageTypes.GetServerEntitiesResponse, GetServerEntitiesResponse)
    net.Receive(SMH.MessageTypes.LoadResponse, LoadResponse)
    net.Receive(SMH.MessageTypes.LoadResponseSettings, LoadResponseSettings)
    net.Receive(SMH.MessageTypes.GetModelInfoResponse, GetModelInfoResponse)
    net.Receive(SMH.MessageTypes.SaveExists, SaveExists)
    net.Receive(SMH.MessageTypes.SaveResponse, SaveResponse)
    net.Receive(SMH.MessageTypes.AddFolderResponse, AddFolderResponse)
    net.Receive(SMH.MessageTypes.RequestAppendResponse, RequestAppendResponse)
    net.Receive(SMH.MessageTypes.DeleteSaveResponse, DeleteSaveResponse)

    net.Receive(SMH.MessageTypes.ApplyEntityNameResponse, ApplyEntityNameResponse)
    net.Receive(SMH.MessageTypes.UpdateTimelineResponse, UpdateTimelineResponse)
    net.Receive(SMH.MessageTypes.RequestModifiersResponse, RequestModifiersResponse)
    net.Receive(SMH.MessageTypes.UpdateTimelineInfoResponse, UpdateTimelineInfoResponse)
    net.Receive(SMH.MessageTypes.UpdateModifierResponse, UpdateModifierResponse)
    net.Receive(SMH.MessageTypes.UpdateKeyframeColorResponse, UpdateKeyframeColorResponse)

    net.Receive(SMH.MessageTypes.RequestTimelineInfoResponse, RequestTimelineInfoResponse)

    net.Receive(SMH.MessageTypes.RequestWorldDataResponse, RequestWorldDataResponse)

    net.Receive(SMH.MessageTypes.StopPhysicsRecordResponse, StopPhysicsRecordResponse)

    net.Receive(SMH.MessageTypes.RequestNodesResponse, RequestNodesResponse)
	
	net.Receive(SMH.MessageTypes.PlayAudio, PlayAudio)
	net.Receive(SMH.MessageTypes.StopAudio, StopAudio)
	net.Receive(SMH.MessageTypes.StopAllAudio, StopAllAudio)

    net.Receive(SMH.MessageTypes.RequestDefaultPose, RequestDefaultPose)
    net.Receive(SMH.MessageTypes.UpdateNode, UpdateNode)

    net.Receive(SMH.MessageTypes.PlaybackResponse, PlaybackResponse)

    if game.SinglePlayer() then
        local lastUpdate = SMH.State.TimeStamp
        local interval = GetConVar("smh_autosavetime")
        timer.Remove("SMH_Autosave_Timer")
        timer.Create("SMH_Autosave_Timer", interval:GetFloat() * 60, -1, function()
            -- Only autosave when the user is active (i.e. he changes the state).
            -- Otherwise, we would be performing unnecessary saving when nothing has changed
            if lastUpdate == SMH.State.TimeStamp then return end
            -- Don't autosave if we're disabled (i.e. this is set to 0)
            if interval:GetFloat() == 0 then return end

            local nick = LocalPlayer():Nick():gsub(" ", "")
            local root = "smh/"
            local prefix = ("auto_save_%s"):format(nick)
            local suffix = "_00"
            local search = root .. prefix .. suffix .. "*.txt"
            local autosaves = file.Find(search, "DATA", "dateasc") or {}
            for _, autosave in ipairs(autosaves) do
                local name = autosave:gsub(".txt", "")
                local index = name:sub(-1)
                if index + 1 > 5 then
                    file.Delete(root .. autosave, "DATA")
                else
                    file.Rename(root .. autosave, root .. name:sub(1, #name-1) .. tostring(index + 1) .. ".txt")
                end
            end
            CTRL.Save(prefix .. suffix .. "1", true)
            print(("SMH: Autosaved to %s..."):format(prefix))
            print(("SMH: Next autosave will be in %.2f minutes"):format(interval:GetFloat()))
            lastUpdate = SMH.State.TimeStamp
        end)
    end
end

Setup()
