-- Prevent props from disappearing when resized.

if SERVER then
    local forceRenderBoundsCVar = CreateConVar("smh_force_render_bounds", "1", {FCVAR_ARCHIVE, FCVAR_REPLICATED}, "If set to 1, it sets the render bounds of entity when using scaling an entity with bone manipulations. This is useful for ensuring resized props do not disappear", 0, 1)
    local forceRenderBounds = forceRenderBoundsCVar:GetBool()
    cvars.AddChangeCallback(forceRenderBoundsCVar:GetName(), function (convar, oldValue, newValue)
        forceRenderBounds = tobool(newValue)
    end)
    
    util.AddNetworkString("SMHForceRenderBounds")
    ---@class Entity
    local ENTITY = FindMetaTable("Entity")
    ENTITY.smh_ManipulateBoneScale = ENTITY.smh_ManipulateBoneScale or ENTITY.ManipulateBoneScale
    function ENTITY:ManipulateBoneScale(i, scale, ...)
        if forceRenderBounds then
            net.Start("SMHForceRenderBounds")
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
    local oldMin, oldMax = ent.smh_RenderBoundsCacheMin, ent.smh_RenderBoundsCacheMax

    local min = oldMin * scale
    local max = oldMax * scale
    
    ent:SetRenderBounds(min, max)
end

hook.Add("OnEntityCreated", "SMHForceRenderBoundsInitialize", function (entity)
    if IsValid(entity) then
        entity.smh_RenderBoundsCacheMin, entity.smh_RenderBoundsCacheMax = entity:GetRenderBounds()
    end
end)

net.Receive("SMHForceRenderBounds", function (len, ply)
    local ent = net.ReadEntity()
    local index = net.ReadUInt(8)
    local scale = net.ReadVector()
    setScaledRenderBounds(ent, index, scale)
end)