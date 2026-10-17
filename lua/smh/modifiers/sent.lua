
-- The universal modifier for all scripted entities
-- TODO: For old modifiers, reroute their methods over to the SENT 
MOD.Name = "Scripted Entity";

-- TODO: Make an allow list to prevent some other network variables from running
-- Could also tie that into other some admin permission systems

-- Disallow most prop classes
local invalidClasses = {
    prop_physics = true,
    prop_ragdoll = true,
    prop_effect = true,
}

---@class NetworkVarInfo
---@field set {[string]: true}?
---@field arr string[]?

---@type {[string]: NetworkVarInfo}
local networkVarMap = {}

function MOD:IsPhysicsProp(entity)
    return invalidClasses[entity:GetClass()]
end

function MOD:InitializeNetworkVars(entity)
    local c = entity:GetClass()
    if not networkVarMap[c] then
        networkVarMap[c] = {
            set = {},
            arr = {}
        }
        
        for k, _ in pairs(entity:GetNetworkVars()) do
            table.insert(networkVarMap[c].arr, k)
            networkVarMap[c].set[k] = true
        end
    end
end

---@param entity Entity
---@param networkVar string
---@return any?
local function getNetworkVar(entity, networkVar)
    local func = entity["Get" .. networkVar]
    return Either(isfunction(func), func(entity), nil)
end

---@param entity Entity
---@param networkVar string
---@return any?
local function setNetworkVar(entity, networkVar, ...)
    local func = entity["Set" .. networkVar]
    return isfunction(func) and func(entity, ...)
end

function MOD:Save(entity)

    if self:IsPhysicsProp(entity) then return nil end

    local data = {};
    
    self:InitializeNetworkVars(entity)
    for _, networkVar in ipairs(networkVarMap[entity:GetClass()].arr) do
        data[networkVar] = getNetworkVar(entity, networkVar)
    end
    
    return data;

end

function MOD:Load(entity, data)

    if self:IsPhysicsProp(entity) then return nil end

    local class = entity:GetClass()
    self:InitializeNetworkVars(entity)
    for _, networkVar in ipairs(networkVarMap[class].arr) do
        local result = data[networkVar]
        if result ~= nil then
            setNetworkVar(entity, networkVar, result)
        end
    end

end

local lerpLinear = SMH.LerpLinear
local lerpLinearAngle = SMH.LerpLinearAngle
local lerpLinearVector = SMH.LerpLinearVector

function MOD:LoadBetween(entity, data1, data2, percentage)

    if self:IsPhysicsProp(entity) then return nil end

    local class = entity:GetClass()
    self:InitializeNetworkVars(entity)
    for _, networkVar in ipairs(networkVarMap[class].arr) do
        local result = data1[networkVar]
        if result ~= nil then
            if isvector(result) then
                result = lerpLinearVector(data1[networkVar], data2[networkVar], percentage)
            elseif isangle(result) then
                result = lerpLinearAngle(data1[networkVar], data2[networkVar], percentage)
            elseif IsColor(result) then
                result = result:Lerp(data2[networkVar], percentage)
            elseif isnumber(result) then
                result = lerpLinear(data1[networkVar], data2[networkVar], percentage)
            end
            setNetworkVar(entity, networkVar, result)
        end
    end
end
