--- @type PropertiesManager
SMH.Properties = SMH.Properties or {
    Players = {}
}

--- @param entity Entity
--- @return string
local function GetModelName(entity)
    local mdl = string.Split(entity:GetModel(), "/")
    mdl = mdl[#mdl]

    return mdl
end

--- @param player Player
--- @param entity Entity
--- @param name string
--- @return string uniqueName
local function SetUniqueName(player, entity, name)
    local playerData = SMH.Properties.Players[player]
    local usedNames = playerData.UsedNames
    local entityProperties = playerData.Entities[entity]
    if entityProperties then
        usedNames[entityProperties.Name] = nil -- so we won't consider our own name when sorting
    end

    for kentity, value in pairs(playerData.Entities) do
        if kentity ~= entity and name == value.Name then -- if there's another entity with our name
            usedNames[value.Name] = true
            break
        end
    end

    local namebase = name
    local num = 1

    if usedNames[name] then
        local startPos = string.find(namebase, "%d*$")
        namebase = string.sub(namebase, 1, startPos - 1)
    end
    while usedNames[name] do
        name = namebase .. num
        num = num + 1
    end
    usedNames[name] = true
    return name
end

--- @param player Player
--- @return Entity?
local function FindEntity(player) -- I use this to find entity that doesn't have recorded frames
    local sorting = {}
    local playerData = SMH.Properties.Players[player]
    for entity, _ in pairs(playerData.Entities) do
        if sorting[entity] then continue end

        for k, value in pairs(SMH.KeyframeData.Players[player].Keyframes) do
            if value.Entity == entity then
                sorting[entity] = true
                break 
            end
        end
    end

    for entity, _ in pairs(playerData.Entities) do
        if not sorting[entity] then return entity end
    end

    return nil
end

local function initializePlayer(player)
    ---@type PlayerProperties
    local playerProperties = { 
        Entities = {}, 
        UsedNames = {}, 
        TimelineSetting = {
            Timelines = 1,
            TimelineMods = {},
        } 
    }
    SMH.Properties.Players[player] = playerProperties
end

hook.Add("PlayerInitialSpawn", "SMHInitPlayerProperties", initializePlayer)

hook.Add("PlayerDisconnected", "SMHDeleteProperties", function(player)
    SMH.Properties.Players[player] = nil
end)

hook.Add("EntityRemoved", "SMHPropertiesEntityRemoved", function(entity)
    local players = SMH.Properties.Players
    for _, player in ipairs(player.GetAll()) do
        local playerData = players[player]
        local entityProperties = playerData and playerData.Entities[entity]
        if entityProperties then
            playerData.UsedNames[entityProperties.Name] = nil
            playerData.Entities[entity] = nil
        end
    end

end)

--- [SERVER]
--- 
--- @class SMH.PropertiesManager
local MGR = {}

function MGR.Reset(player)
    -- If we're resetting our session for the player, we remove entity data, but preserve
    -- timeline settings
    local old = SMH.Properties.Players[player]
    initializePlayer(player)
    SMH.Properties.Players[player].TimelineSetting = old.TimelineSetting
end

--- @param player Player
--- @return table
function MGR.GetTimelinesInfo(player)
    local playerData = SMH.Properties.Players[player]
    if not playerData or not playerData.TimelineSetting then return {} end

    local info = {}

    info = table.Copy(playerData.TimelineSetting)

    return info
end

--- @param player Player
--- @return table
function MGR.GetAllProperties(player)
    local playerData = SMH.Properties.Players[player]
    if not playerData or not playerData.Entities then return {} end

    local info = {}

    for entity, value in pairs(playerData.Entities) do
        info[entity] = {
            Name = value.Name,
            Class = value.Class,
            Model = value.Model,
        }
    end

    return info
end

--- @param player Player
--- @return table<Entity, {Name: string}>
function MGR.GetAllEntitiesNames(player)
    local playerData = SMH.Properties.Players[player]
    if not playerData or not playerData.Entities then return {} end

    local info = {}

    for entity, value in pairs(playerData.Entities) do
        info[entity] = {
            Name = value.Name,
        }
    end

    return info
end

--- @param player Player
function MGR.RemoveEntity(player)
    if not SMH.KeyframeData.Players[player] or not SMH.KeyframeData.Players[player].Entities or not SMH.Properties.Players[player] or not SMH.Properties.Players[player].Entities then return end
    local entity = FindEntity(player)
    local playerData = SMH.Properties.Players[player]
    if entity then
        playerData.UsedNames[playerData.Entities[entity].Name] = nil
        playerData.Entities[entity] = nil
    end
end

--- @param player Player
--- @param entities Entities
function MGR.AddEntity(player, entities)
    local playerData = SMH.Properties.Players[player]
    if not playerData then
        initializePlayer(player)
    end

    for _, entity in ipairs(entities) do
        if not playerData.Entities[entity] then
            if player ~= entity then
                local class = entity:GetClass()
                local model

                if class == "prop_effect" and IsValid(entity.AttachedEntity) then
                    model = entity.AttachedEntity:GetModel()
                else
                    model = entity:GetModel()
                end

                SMH.Properties.Players[player].Entities[entity] = {
                    Name = SetUniqueName(player, entity, GetModelName(entity)),
                    Class = class,
                    Model = model,
                }
            else
                playerData.Entities[entity] = {
                    Name = SetUniqueName(player, entity, "world"),
                }
            end
        end
        playerData[playerData.Entities[entity].Name] = true
    end
end

--- @param player Player
--- @param entity Entity
--- @param newname string
--- @return string?
function MGR.SetName(player, entity, newname)
    if not SMH.Properties.Players[player] or not SMH.Properties.Players[player].Entities[entity] then return end
    if not newname then return end

    newname = SetUniqueName(player, entity, newname)
    SMH.Properties.Players[player].Entities[entity].Name = newname

    return newname
end

--- @param player Player
--- @param timelineInfo TimelineSetting
function MGR.InitTimelineSetting(player, timelineInfo)
    local playerData = SMH.Properties.Players[player]
    if not playerData then
        initializePlayer(player)
    end

    local timelines
    local timelinemods = {}

    if not next(timelineInfo) then
        timelines = 1

        timelinemods[1] = { KeyColor = Color(0, 200, 0) }
        for name, mod in pairs(SMH.Modifiers) do
            if mod.Default then
                table.insert(timelinemods[1], name)
            end
        end
    else
        timelines = timelineInfo.Timelines

        timelinemods = table.Copy(timelineInfo.TimelineMods)
    end

    SMH.Properties.Players[player].TimelineSetting = {
        Timelines = timelines,
        TimelineMods = timelinemods,
    }
end

--- @param player Player
--- @param add boolean
function MGR.SetTimelines(player, add)
    if not SMH.Properties.Players[player] or not SMH.Properties.Players[player].TimelineSetting then return end

    local timelines = SMH.Properties.Players[player].TimelineSetting.Timelines
    local count
    if add then
        count = timelines + 1
    else
        count = timelines - 1
    end

    if count > 10 or count < 1 then return end  -- just in case

    if add then
        SMH.Properties.Players[player].TimelineSetting.TimelineMods[count] = { KeyColor = Color(0, 200, 0) }
    else
        SMH.Properties.Players[player].TimelineSetting.TimelineMods[timelines] = nil
    end

    SMH.Properties.Players[player].TimelineSetting.Timelines = count
end

--- @param player Player
--- @param itimeline integer
--- @param name string
--- @param state any
--- @return string?
function MGR.UpdateModifier(player, itimeline, name, state)
    if not SMH.Properties.Players[player] or not SMH.Properties.Players[player].TimelineSetting then return end

    if state then 
        table.insert(SMH.Properties.Players[player].TimelineSetting.TimelineMods[itimeline], name)
        for i = 1, SMH.Properties.Players[player].TimelineSetting.Timelines do
            if i == itimeline then continue end
            table.RemoveByValue(SMH.Properties.Players[player].TimelineSetting.TimelineMods[i], name)
        end
    else
        table.RemoveByValue(SMH.Properties.Players[player].TimelineSetting.TimelineMods[itimeline], name)
    end

    return name
end

--- @param player Player
--- @param color Color
--- @param timeline integer
function MGR.UpdateKeyframeColor(player, color, timeline)
    if not SMH.Properties.Players[player] or not SMH.Properties.Players[player].TimelineSetting then return end

    SMH.Properties.Players[player].TimelineSetting.TimelineMods[timeline].KeyColor = color
end

--- @param player Player
--- @return integer
function MGR.GetTimelines(player)
    if not SMH.Properties.Players[player] or not SMH.Properties.Players[player].TimelineSetting then return 1 end
    return SMH.Properties.Players[player].TimelineSetting.Timelines
end

--- @param player Player
--- @param entity Entity
--- @param properties Properties
function MGR.SetProperties(player, entity, properties)
    if not SMH.Properties.Players[player] or not SMH.Properties.Players[player].Entities[entity] then return end

    local newname = SetUniqueName(player, entity, properties.Name)
    SMH.Properties.Players[player].Entities[entity].Name = newname
end

SMH.PropertiesManager = MGR
