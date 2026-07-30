-- Prevent props from disappearing when resized.

---@type fun(index: integer): SMHEntity
local Entity = Entity
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

ENTITY.smh_EnableMatrix = ENTITY.smh_EnableMatrix or ENTITY.EnableMatrix
function ENTITY:EnableMatrix(matrixType, matrix, ...)
    self.smh_RenderBoundsCacheMatrixScale = matrix:GetScale()
    return self:smh_EnableMatrix(matrixType, matrix, ...)
end

---@param ent SMHEntity
---@param boneID number
---@param scale Vector|number
local function setScaledRenderBounds(ent, boneID, scale)
    if IsValid(ent) then
        local oldMin, oldMax = ent.smh_RenderBoundsCacheMinOG, ent.smh_RenderBoundsCacheMaxOG

        scale = scale * ent.smh_RenderBoundsCacheMatrixScale * ent.smh_RenderBoundsCacheModelScale
        local min = oldMin * scale 
        local max = oldMax * scale
        
        ent:SetRenderBounds(min, max)
    end
end

---@type Set<string>
local invalidEntities = {
    ["class CLuaEffect"] = true
}

---@type Set<{[1]: Vector, [2]: Vector}>
local modelRenderBounds = {}

---@param entity SMHEntity
---@return Vector
---@return Vector
---@return function
local function cacheRenderBounds(entity)
    local model = entity:GetModel()
    local renderBounds = modelRenderBounds[model]

    local function remove()
    end
    if not renderBounds and model then
        -- We need to spawn a clientside model with the default render bounds
        local csModel = ents.CreateClientProp()
        csModel:SetModel(model)
        csModel:SetupBones()
        csModel:InvalidateBoneCache()
        csModel:Spawn()

        local min, max = csModel:GetRenderBounds()
        renderBounds = {min, max}
        modelRenderBounds[model] = renderBounds
        remove = function()
            csModel:Remove()
        end
    end
    
    return renderBounds[1], renderBounds[2], remove
end

local busy = false
---@param entity SMHEntity
local function initializeRenderBounds(entity)
    if busy then return end

    busy = true
    local success, result = pcall(function()
        if 
            IsValid(entity) 
            and not invalidEntities[entity:GetClass()] 
            and entity.GetModel 
            and entity:GetModel() 
            and not entity:IsWeapon() 
            and not entity.smh_RenderBoundsCacheMinOG
        then
            local min, max, remove = cacheRenderBounds(entity)
            entity.smh_RenderBoundsCacheMinOG, entity.smh_RenderBoundsCacheMaxOG = min, max
            remove()

            entity.smh_RenderBoundsCacheModelScale = entity:GetModelScale()
            entity.smh_RenderBoundsCacheMatrixScale = Vector(1, 1, 1)
        end
    end)
    if not success and result then
        ErrorNoHaltWithStack(result .. "\n")
    end
    busy = false
end

---@param ent SMHEntity
---@param index integer
---@param scale Vector
local function setEntityRenderBounds(ent, index, scale)
    initializeRenderBounds(ent)
    setScaledRenderBounds(ent, index, scale)
end

net.Receive("SMHForceRenderBoundsBoneScale", function (len, ply)
    local entIndex = net.ReadUInt(MAX_EDICT_BITS)
    local index = net.ReadUInt(8)
    local scale = net.ReadVector()
    local entity = Entity(entIndex)
    if IsValid(entity) then
        setEntityRenderBounds(entity, index, scale)
    else
        -- In multiplayer (or other cases), the ghost entity isn't immediately available, so we have to wait an extra tick
        -- and then try again. We only need to do this for ghost entities fortunately, but this is really hacky
        timer.Simple(0.1, function()
            entity = Entity(entIndex)
            if IsValid(entity) then
                setEntityRenderBounds(entity, index, scale)
            end
        end)
    end
end)

net.Receive("SMHForceRenderBoundsModelScale", function (len, ply)
    local entIndex = net.ReadUInt(MAX_EDICT_BITS)
    local scale = net.ReadDouble()
    local entity = Entity(entIndex)
    if IsValid(entity) then
        initializeRenderBounds(entity)
        entity.smh_RenderBoundsCacheModelScale = scale
    else
        timer.Simple(0.1, function ()
            entity = Entity(entIndex)
            if IsValid(entity) then
                initializeRenderBounds(entity)
                entity.smh_RenderBoundsCacheModelScale = scale           
            end
        end)
    end
end)

hook.Add("OnEntityCreated", "SMHForceRenderBoundsInitialize", initializeRenderBounds)
