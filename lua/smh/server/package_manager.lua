local packIntoEntity = CreateConVar("smh_packentity", "0", FCVAR_PROTECTED + FCVAR_ARCHIVE, "If set to 1, this packs animation data into the entity itself. Useful for animation sharing, but you are limited by the amount of keyframes")
local disablePacking = CreateConVar("smh_disablepacking", "0", FCVAR_PROTECTED + FCVAR_ARCHIVE, "If set to 1, it prevents applying SMH packages upon loading a save")

local MGR = {}

local function packSaveIntoEntity()
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
        -- Only apply the dupe thing once, so that it only carries over once per packing operation.
        entity.smh_IsDupe = nil
    end
    return hasDupes
end

local function packDataIntoEntity()
    ---TODO: Add guards for packing data. We should not pack data
    ---that could potentially kick clients out due to 
    ---reliable buffer overflows
    return false
end

---@param entities {[string]: Entity}
---@param serializedKeyframes SMHFile
---@param savePath string
function MGR.Pack(entities, serializedKeyframes, savePath)
    local hasDupes = false

    if packIntoEntity:GetBool() then
        hasDupes = packDataIntoEntity()
    else
        hasDupes = packSaveIntoEntity()
    end

    return hasDupes
end

---@param player Player
---@param entity SMHEntity
---@param data Data
local function applyDataIntoEntity(player, entity, data)
    ---TODO: Add guards for packing data. We should not pack data
    ---that could potentially kick clients out due to 
    ---reliable buffer overflows
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
        if packIntoEntity:GetBool() then
            ---@cast data Data
            applyDataIntoEntity(player, entity, data)
        else
            ---@cast data PackageData
            applySaveIntoEntity(player, entity, data)
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
    for _, ent in pairs(ents or {}) do
        ent.smh_IsDupe = true
    end
    return duplicator.smh_Copy(Ent, AddToTable)
end

SMH.Packer = MGR