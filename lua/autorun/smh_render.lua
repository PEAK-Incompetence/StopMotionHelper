-- Prevent props from disappearing when resized.
---@class Entity
local ENTITY = FindMetaTable("Entity")

if SERVER then
    local forceRenderBoundsCVar = CreateConVar("smh_force_render_bounds", "1", {FCVAR_ARCHIVE, FCVAR_REPLICATED}, "If set to 1, it sets the render bounds of entity when using scaling an entity with bone manipulations. This is useful for ensuring resized props do not disappear", 0, 1)
        local forceRenderBounds = forceRenderBoundsCVar:GetBool()
        cvars.AddChangeCallback(forceRenderBoundsCVar:GetName(), function (convar, oldValue, newValue)
            forceRenderBounds = tobool(newValue)
        end)
        
        util.AddNetworkString("SMHForceRenderBoundsModelScale")
        util.AddNetworkString("SMHForceRenderBoundsBoneScale")

    ENTITY.smh_SetModelScale = ENTITY.smh_SetModelScale or ENTITY.SetModelScale
    function ENTITY:SetModelScale(scale, deltaTIme, ...)
        if forceRenderBounds then
            net.Start("SMHForceRenderBoundsModelScale")
            net.WriteEntity(self)
            net.WriteDouble(scale)
            net.Broadcast()
        end
        return self:smh_SetModelScale(scale, deltaTime, ...)
    end

    ENTITY.smh_ManipulateBoneScale = ENTITY.smh_ManipulateBoneScale or ENTITY.ManipulateBoneScale
    function ENTITY:ManipulateBoneScale(i, scale, ...)
        if forceRenderBounds then
            net.Start("SMHForceRenderBoundsBoneScale")
            net.WriteEntity(self)
            net.WriteUInt(i, 8)
            net.WriteVector(scale)
            net.Broadcast()
        end
        return self:smh_ManipulateBoneScale(i, scale, ...)
    end
    return 
end

---@param ent Entity
---@param boneID number
---@param scale Vector|number
local function setScaledRenderBounds(ent, boneID, scale)
    local oldMin, oldMax = ent.smh_RenderBoundsCacheMinOG, ent.smh_RenderBoundsCacheMaxOG

    scale = scale * ent.smh_RenderBoundsCacheMatrixScale * ent.smh_RenderBoundsCacheModelScale
    local min = oldMin * scale 
    local max = oldMax * scale
    
    ent:SetRenderBounds(min, max)
end

---@param entity Entity
local function initializeRenderBounds(entity)
    if IsValid(entity) and not entity.smh_RenderBoundsCacheMinOG then
        entity.smh_RenderBoundsCacheMinOG, entity.smh_RenderBoundsCacheMaxOG = entity:GetRenderBounds()
        entity.smh_RenderBoundsCacheModelScale = entity:GetModelScale()
        entity.smh_RenderBoundsCacheMatrixScale = Vector(1, 1, 1)
    end
end


hook.Add("OnEntityCreated", "SMHForceRenderBoundsInitialize", initializeRenderBounds)

net.Receive("SMHForceRenderBoundsBoneScale", function (len, ply)
    local ent = net.ReadEntity()
    local index = net.ReadUInt(8)
    local scale = net.ReadVector()
    initializeRenderBounds(entity)
    setScaledRenderBounds(ent, index, scale)
end)

net.Receive("SMHForceRenderBoundsModelScale", function (len, ply)
    local entity = net.ReadEntity()
    local scale = net.ReadDouble()
    initializeRenderBounds(entity)
    entity.smh_RenderBoundsCacheModelScale = scale
end)

ENTITY.smh_EnableMatrix = ENTITY.smh_EnableMatrix or ENTITY.EnableMatrix
function ENTITY:EnableMatrix(matrixType, matrix, ...)
    self.smh_RenderBoundsCacheMatrixScale = matrix:GetScale()
    return self:smh_EnableMatrix(matrixType, matrix, ...)
end