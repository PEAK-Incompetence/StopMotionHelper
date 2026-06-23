local packIntoEntity = CreateConVar("smh_packentity", "0", FCVAR_PROTECTED + FCVAR_ARCHIVE, "If set to 1, this packs animation data into the entity itself. Useful for animation sharing, but you are limited by the amount of keyframes")
local disablePacking = CreateConVar("smh_disablepacking", "0", FCVAR_PROTECTED + FCVAR_ARCHIVE, "If set to 1, it prevents applying SMH packages upon loading a save")

local MGR = {}

---@param entities {[string]: Entity}
---@param serializedKeyframes SMHFile
---@param savePath string
---@return boolean
local function packSaveIntoEntity(entities, serializedKeyframes, savePath)
    local hasDupes = false
    for _,  data in ipairs(serializedKeyframes.Entities) do
        local entity = entities[data.Properties.Name]
        if not IsValid(entity) or entity:IsPlayer() then continue end
        ---@cast entity Entity

        if entity.smh_IsDupe then
            hasDupes = true
        end
        duplicator.ClearEntityModifier(entity, "SMHPackage")
        duplicator.StoreEntityModifier(entity, "SMHPackage", {
            name = data.Properties.Name,
            save = savePath,
            isDupe = entity.smh_IsDupe ---@diagnostic disable-line
        })
        -- Only apply the dupe tag once, so that it only carries over once per packing operation.
        entity.smh_IsDupe = nil
    end
    return hasDupes
end

---@param entities {[string]: Entity}
---@param serializedKeyframes SMHFile
---@return boolean
local function packDataIntoEntity(entities, serializedKeyframes)
    ---TODO: Add guards for saving packed data. The duplicator is unable
    ---to save at least 256KB worth of keyframe data, and will kick the
    ---client out due to reliable buffer error
    
    for _,  data in ipairs(serializedKeyframes.Entities) do
        local entity = entities[data.Properties.Name]
        if not IsValid(entity) or entity:IsPlayer() then continue end

        duplicator.ClearEntityModifier(entity, "SMHPackage")
        duplicator.StoreEntityModifier(entity, "SMHPackage", table.Copy(data))
    end
    return true
end

---@param player Player
function MGR.NotifyPack(player)
    if packIntoEntity:GetBool() then
        return player:ChatPrint(Format("Stop Motion Helper: Successfully packed animation data into all entities", path))
    else
        return player:ChatPrint(Format("Stop Motion Helper: Successfully packed the following save path: %s!", path))
    end
end

---@param path string
---@return boolean
function MGR.ValidateSave(path)
    return Either(not packIntoEntity:GetBool(), SMH.Saves.CheckIfExists(path, NULL), true)
end

---@param entities {[string]: Entity}
---@param serializedKeyframes SMHFile
---@param savePath string
function MGR.Pack(entities, serializedKeyframes, savePath)
    local hasDupes = false

    if packIntoEntity:GetBool() then
        hasDupes = packDataIntoEntity(entities, serializedKeyframes)
    else
        hasDupes = packSaveIntoEntity(entities, serializedKeyframes, savePath)
    end

    return hasDupes
end

---@param player Player
---@param entity SMHEntity
---@param data Data
local function applyDataIntoEntity(player, entity, data)
    SMH.PropertiesManager.AddEntity(player, {entity})
    SMH.KeyframeManager.ImportSave(player, entity, data.Frames, data.Properties)

    local serializedKeyframes = {
        Entities = {data}
    }

    SMH.Spawner.DupeOffsetKeyframes(player, entity, serializedKeyframes)

    duplicator.ClearEntityModifier(ent, "SMHPackage")
    duplicator.StoreEntityModifier(ent, "SMHPackage", data)
end

---@param player Player
---@param entity SMHEntity
---@param data PackageData
local function applySaveIntoEntity(player, entity, data)
    local frameData, properties, _, settings = SMH.Saves.LoadPathForEntity(data.save, data.name)
    if not frameData or not properties then return end
    local smhFile = SMH.Saves.Load(data.save, NULL)

    SMH.PropertiesManager.AddEntity(player, {entity})
    SMH.KeyframeManager.ImportSave(player, entity, frameData, properties)

    if data.isDupe then
        SMH.Spawner.DupeOffsetKeyframes(player, entity, smhFile)
    end

    duplicator.ClearEntityModifier(entity, "SMHPackage")
    duplicator.StoreEntityModifier(entity, "SMHPackage", data)

    net.Start(SMH.MessageTypes.LoadResponseSettings)
    net.WriteEntity(entity)
    net.WriteTable(settings or {})
    net.Send(player)
end

---@param player Player
---@param entity SMHEntity
---@param data PackageData|Data
---@return boolean?
local function PackageApply(player, entity, data)
    if not IsValid(entity) then return false end
    if disablePacking:GetBool() then return false end

    timer.Simple(0, function()
        if data.save then
            ---@cast data PackageData
            applySaveIntoEntity(player, entity, data)
        else
            ---@cast data Data
            applyDataIntoEntity(player, entity, data)
        end
    end)

end

duplicator.RegisterEntityModifier("SMHPackage", PackageApply)

if not duplicator.smh_Copy then
    duplicator.smh_Copy = duplicator.Copy
end

---Override `duplicator.Copy` to label copied entities as dupes, so SMH can preserve animations in saves
---@param Ent Entity
---@param AddToTable table
---@return table
function duplicator.Copy(Ent, AddToTable)
    Ent.smh_IsDupe = true
    local ents = duplicator.GetAllConstrainedEntitiesAndConstraints(Ent, {}, {})
    -- local count = 0
    for _, ent in pairs(ents or {}) do
        ent.smh_IsDupe = true
        -- local data = ent.EntityMods and ent.EntityMods["SMHPackage"]
        -- if data then
        --     count = count + #util.Compress(util.TableToJSON(data))
        -- end
    end
    -- print(count, string.NiceSize(count))

    return duplicator.smh_Copy(Ent, AddToTable)
end

SMH.Packer = MGR