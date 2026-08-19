local applySpawnInfo = CreateConVar("smh_spawn_apply_info", "0", {FCVAR_PROTECTED, FCVAR_ARCHIVE}, "If set to 1, it applies skin, color, or other modifiers to an entity, similar to a duplicator.")
local spawnChildren = CreateConVar("smh_spawn_children_enabled", "0", {FCVAR_PROTECTED, FCVAR_ARCHIVE}, "If set to 1, it spawns any animatable bonemerged children.")

local Active = {}
local MGR = {}

MGR.OffsetPos, MGR.OffsetAng, MGR.OffsetMode = {}, {}, {}

MGR.OriginData = {}

---Get position data for a specific `model` and its children
---@param serializedKeyframes SMHFile
---@param model string
---@param doRecursive boolean Iterate over the children table if this is set to true
---@return string[] # Model paths
---@return string[] # Classes
---@return {[string]: ModifierDataInfo}[] # Modifier info
---@return table # Entity table
---@return integer[] # Parent indices where the child index keys to the parent
---@return string[] # Property names
local function GetPosData(serializedKeyframes, model, doRecursive)
    local classes, modelpaths, data, info, parents, names = {}, {}, {}, {}, {}, {}

    local function recursiveGetPosData(modelName, cs, ms, ds, is, ps, parentIndex)
        for i, sEntity in ipairs(serializedKeyframes.Entities) do
            local listname
            if not sEntity.Properties then -- in case if we load an old save without properties entities
                return
            else
                listname = sEntity.Properties.Name
            end
    
            if listname == modelName then
                if not sEntity.Properties.Class then
                    return
                end
                local index = table.insert(classes, sEntity.Properties.Class)
                table.insert(modelpaths, sEntity.Properties.Model)
                table.insert(info, sEntity.Info)
                table.insert(names, listname)
    
                local data = {}
    
                for _, kframe in ipairs(serializedKeyframes.Entities[i].Frames) do
                    for name, mod in pairs(kframe.EntityData) do
                        if not data[name] or data[name].Frame > kframe.Position then
                            data[name] = {Modifiers = mod, Frame = kframe.Position}
                        end
                    end
                end

                table.insert(ds, data)

                ps[index] = parentIndex
                
                if doRecursive then
                    for _, child in ipairs(sEntity.Children or {}) do
                        recursiveGetPosData(child, cs, ms, ds, is, ps, index)
                    end
                end
            end
        end
    end

    recursiveGetPosData(model, classes, modelpaths, data, info, parents)
    return classes, modelpaths, data, info, parents, names
end

---@param serializedKeyframes SMHFile
---@return FrameData
local function GetDupeData(serializedKeyframes)
    local data = {}
    for _, kframe in ipairs(serializedKeyframes.Entities[1].Frames) do
        for name, mod in pairs(kframe.EntityData) do
            if not data[name] or data[name].Frame > kframe.Position then
                data[name] = {Modifiers = mod, Frame = kframe.Position}
            end
        end
    end

    return data
end

---@param player Player
---@param modname string
---@param keyframe FrameData
---@param pos Vector
local function SetOffset(player, modname, keyframe, pos)
    local mod = SMH.Modifiers[modname]

    local offsetpos = MGR.OffsetPos[player] or Vector(0, 0, 0)
    local offsetang = MGR.OffsetAng[player] or Angle(0, 0, 0)

    keyframe.Modifiers[modname] = mod:Offset(keyframe.Modifiers[modname], MGR.OriginData[player][modname].Modifiers, offsetpos, offsetang, pos)
end

---@param entity SMHEntity
---@param modname string
---@param keyframe FrameData
---@param firstkey FrameData
local function SetDupeOffset(entity, modname, keyframe, firstkey)
    local mod = SMH.Modifiers[modname]

    keyframe.Modifiers[modname] = mod:OffsetDupe(entity, keyframe.Modifiers[modname], firstkey[modname].Modifiers)
end

---@param path string
---@param model string
---@param player Player
---@param serializedKeyframes SMHFile
---@return string?
---@return string?
---@return table?
---@return boolean?
function MGR.SetPreviewEntity(path, model, player, serializedKeyframes)
    if not Active[player] then return nil end
    local classes, modelpaths, dataSet, infos, parents = GetPosData(serializedKeyframes, model, false)
    local neworigin = false
    if not classes[1] then
        player:ChatPrint("Stop Motion Helper: Failed to get entity info. Probably you're trying to load world entity, or the save is from older SMH version!")
        return nil
    end

    local origindata = nil

    if not MGR.OriginData[player] or not MGR.OffsetMode[player] then
        MGR.SetOrigin(model, player, serializedKeyframes)
        neworigin = true
    end

    return classes[1], modelpaths[1], dataSet[1], neworigin
end

---@param state any
---@param player Player
function MGR.SetGhost(state, player)
    Active[player] = state
end

local bonemergeClasses = {
    ["ent_advbonemerge"] = function(player, info, parent)
        local target = duplicator.CreateEntityFromTable(player, info)
        local entity = CreateAdvBonemergeEntity(target, parent, player, false, false, player:GetInfoNum("advbonemerge_matchnames", 0) == 1)
        local const = constraint.AdvBoneMerge(parent, entity, player)
        return entity
    end
}

---@param modelpath string
---@param class string
---@param info table Entity table
---@return SMHEntity
local function genericSpawn(modelpath, class, info)
    
    local entity = ents.Create(class)
    ---@cast entity SMHEntity
    
    if applySpawnInfo:GetBool() then
        duplicator.DoGeneric(entity, info)
    end
    entity:SetModel(modelpath)
    entity:Spawn()
    return entity
end

---@param model string
---@param settings Settings
---@param player Player
---@param serializedKeyframes SMHFile
---@return SMHEntity[]? # spawned entity and its child entities (indices after 1 are descendants)
---@return Vector? # origin position
---@return string[]? # names
function MGR.Spawn(model, settings, player, serializedKeyframes)
    if not Active[player] then return end
    local classes, modelpaths, dataSet, infos, parents, names = GetPosData(serializedKeyframes, model, spawnChildren:GetBool())
    if not classes[1] then
        player:ChatPrint("Stop Motion Helper: Failed to get entity info. Probably you're trying to load world entity, or the save is from older SMH version!")
        return
    end

    if IsValid(player) and not player:CheckLimit("smhentity") then return end

    local class, data = classes[1], dataSet[1]
    if class == "prop_ragdoll" and not data["physbones"] then
        player:ChatPrint("Stop Motion Helper: Can't spawn the ragdoll as the save doesn't have Physical Bones modifier!")
        return
    end
    if not data["physbones"] and not data["position"] then
        player:ChatPrint("Stop Motion Helper: Can't spawn the entity as the save doesn't have Physical Bones or Position and Rotation modifiers!")
        return
    end

    local tracepos = nil
    if MGR.OffsetMode[player] then
        tracepos = player:GetEyeTraceNoCursor().HitPos
    end

    ---@type SMHEntity[]
    local entities = {}
    undo.Create("SMH Spawned entity")
    for i = 1, #classes do
        local modelpath = modelpaths[i]
        local class = classes[i]
        local info = infos[i]
        local data = dataSet[i]
        local parentIndex = parents[i]

        ---@type SMHEntity
        local entity
        -- The parent entity is the first entity
        if bonemergeClasses[class] and parentIndex and entities[parentIndex] then
            entity = bonemergeClasses[class](player, info, entities[parentIndex])
        else
            entity = genericSpawn(modelpath, class, info)
        end
        player:AddCount("smhentity", entity)
        player:AddCleanup("smhentity", entity)
    
        table.insert(entities, entity)
        
        for name, mod in pairs(SMH.Modifiers) do
            if not data[name] then continue end
            if data[name] and MGR.OriginData[player][name] and (name == "physbones" or name == "position") then
                local offsetpos = MGR.OffsetPos[player] or Vector(0, 0, 0)
                local offsetang = MGR.OffsetAng[player] or Angle(0, 0, 0)
                
                local offsetdata = mod:Offset(data[name].Modifiers, MGR.OriginData[player][name].Modifiers, offsetpos, offsetang, tracepos)
                mod:Load(entity, offsetdata, settings)
            else
                mod:Load(entity, data[name].Modifiers, settings)
            end
        end

        undo.AddEntity(entity)
    end
    undo.SetPlayer(player)
    undo.Finish()

    return entities, tracepos, names
end

---@param player Player
---@param entity Entity
---@param offsetpos Vector
function MGR.OffsetKeyframes(player, entity, offsetpos)
    for id, keyframe in pairs(SMH.KeyframeData.Players[player].Entities[entity]) do
        local hasphysics = keyframe.Modifiers["physbones"] and true or false
        local hasposition = keyframe.Modifiers["position"] and true or false

        if not hasphysics and not hasposition then continue end

        if hasphysics then
            SetOffset(player, "physbones", keyframe, offsetpos)
        end

        if hasposition then
            SetOffset(player, "position", keyframe, offsetpos)
        end
    end
end

---@param player Player
---@param entity SMHEntity
---@param serializedKeyframes SMHFile
function MGR.DupeOffsetKeyframes(player, entity, serializedKeyframes)
    local originData = GetDupeData(serializedKeyframes)

    for id, keyframe in pairs(SMH.KeyframeData.Players[player].Entities[entity]) do
        local hasphysics = keyframe.Modifiers["physbones"] and true or false
        local hasposition = keyframe.Modifiers["position"] and true or false

        if not hasphysics and not hasposition then continue end

        if hasphysics then
            SetDupeOffset(entity, "physbones", keyframe, originData)
        end

        if hasposition then
            SetDupeOffset(entity, "position", keyframe, originData)
        end
    end
end

---@param model string
---@param player Player
---@param serializedKeyframes SMHFile
---@return nil
function MGR.SetOrigin(model, player, serializedKeyframes)
    local classes, modelpaths, dataSet = GetPosData(serializedKeyframes, model, false)
    if not classes[1] then
        player:ChatPrint("Stop Motion Helper: Failed to get entity info. Probably you're trying to load world entity, or the save is from older SMH version!")
        return nil
    end

    MGR.OriginData[player] = dataSet[1]
    return dataSet[1]
end

---@param player Player
function MGR.SpawnReset(player)
    MGR.OriginData[player] = nil
end

---@param set any
---@param player Player
function MGR.SetOffsetMode(set, player)
    MGR.OffsetMode[player] = set
end

---@param pos Vector
---@param player Player
function MGR.SetPosOffset(pos, player)
    MGR.OffsetPos[player] = pos
end

---@param ang Angle
---@param player Player
function MGR.SetAngleOffset(ang, player)
    MGR.OffsetAng[player] = ang
end

SMH.Spawner = MGR
