---Micro-optimizations
---We want to get as much performance out of playback as possible.
---To do that, we try to reduce `__index`ing calls and also use
---Lua to cache the data

local isValid = IsValid

local MGR = {}

do

---@type PhysObj
local PHYSOBJ = FindMetaTable("PhysObj")
local physSetPos = PHYSOBJ.SetPos
local physSetAngles = PHYSOBJ.SetAngles
local physEnableMotion = PHYSOBJ.EnableMotion
local physWake = PHYSOBJ.Wake

---@param po PhysObj
---@param pos Vector
---@param teleport boolean?
---@return nil
function MGR.PhysObjSetPos(po, pos, teleport)
    return physSetPos(po, pos, teleport)
end

---@param po PhysObj
---@param ang Angle
---@return nil
function MGR.PhysObjSetAngles(po, ang)
    return physSetAngles(po, ang)
end

---@param po PhysObj
---@param motion boolean
---@return nil
function MGR.PhysObjEnableMotion(po, motion)
    return physEnableMotion(po, motion)
end

---@param po PhysObj
---@return nil
function MGR.PhysObjWake(po)
    return physWake(po)
end

end

do

---@type Entity
local ENTITY = FindMetaTable("Entity")
local entSetPos = ENTITY.SetPos
local entSetAngles = ENTITY.SetAngles
local entGetModel = ENTITY.GetModel
local entGetPhysicsObjectCount = ENTITY.GetPhysicsObjectCount
local entGetPhysicsObjectNum = ENTITY.GetPhysicsObjectNum
local entSetSkin = ENTITY.SetSkin
local entManipulateBonePosition = ENTITY.ManipulateBonePosition
local entManipulateBoneAngles = ENTITY.ManipulateBoneAngles
local entManipulateBoneScale = ENTITY.ManipulateBoneScale
local entGetBoneCount = ENTITY.GetBoneCount
local entGetFlexNum = ENTITY.GetFlexNum
local entSetFlexScale = ENTITY.SetFlexScale
local entSetFlexWeight = ENTITY.SetFlexWeight
local entSetNW2Float = ENTITY.SetNW2Float
local entSetColor = ENTITY.SetColor
local entSetBodygroup = ENTITY.SetBodygroup
local entSetMaterial = ENTITY.SetMaterial
local entSetSubMaterial = ENTITY.SetSubMaterial
local entSetPoseParameter = ENTITY.SetPoseParameter
local entSetModelScale = ENTITY.SetModelScale

---@param entity Entity
---@return string
function MGR.EntityGetModel(entity)
    return entGetModel(entity)
end

local optEntityGetModel = MGR.EntityGetModel

---@param entity Entity
---@param scale number
---@return nil
function MGR.EntitySetModelScale(entity, scale)
    return entSetModelScale(entity, scale)
end

---@param entity Entity
---@param poseName string|integer
---@param poseValue number
---@return nil
function MGR.EntitySetPoseParameter(entity, poseName, poseValue)
    return entSetPoseParameter(entity, poseName, poseValue)
end

---@param entity Entity
---@param index integer
---@param submaterial string
---@return nil
function MGR.EntitySetSubMaterial(entity, index, submaterial)
    return entSetSubMaterial(entity, index, submaterial)
end

---@param entity Entity
---@param material string
---@return nil
function MGR.EntitySetMaterial(entity, material)
    return entSetMaterial(entity, material)
end

---@param entity Entity
---@param bodyGroupId integer
---@param subModelId integer
---@return nil
function MGR.EntitySetBodygroup(entity, bodyGroupId, subModelId)
    return entSetBodygroup(entity, bodyGroupId, subModelId)
end

---@param entity Entity
---@param color Color
---@return nil
function MGR.EntitySetColor(entity, color)
    return entSetColor(entity, color)
end

do 
local entFlexNum = {}
---@param entity Entity
---@return number
function MGR.EntityGetFlexNum(entity)
    local model = optEntityGetModel(entity)
    local flexNum = entFlexNum[model]
    if not flexNum then
        flexNum = entGetFlexNum(entity)
        entFlexNum[model] = flexNum
    end
    return flexNum
end
end

---@param entity Entity
---@param scale number
---@return nil
function MGR.EntitySetFlexScale(entity, scale)
    return entSetFlexScale(entity, scale)
end

---@param entity Entity
---@param flex integer
---@param weight number
---@return nil
function MGR.EntitySetFlexWeight(entity, flex, weight)
    return entSetFlexWeight(entity, flex, weight)
end

---@param entity Entity
---@param key string
---@param float number
---@return nil
function MGR.EntitySetNW2Float(entity, key, float)
    return entSetNW2Float(entity, key, float)
end

do
---@type {[string]: integer}
local entBoneCount = {}

---@param entity Entity
---@return integer
function MGR.EntityGetBoneCount(entity)
    local model = optEntityGetModel(entity)
    local boneCount = entBoneCount[model]
    if not boneCount then
        boneCount = entGetBoneCount(entity)
        entBoneCount[model] = boneCount
    end
    return boneCount
end
end

---@param entity Entity
---@param id integer
---@param pos Vector
---@param networking boolean?
---@return nil
function MGR.EntityManipulateBonePosition(entity, id, pos, networking)
    return entManipulateBonePosition(entity, id, pos, networking)
end

---@param entity Entity
---@param id integer
---@param ang Angle
---@param networking boolean?
---@return nil
function MGR.EntityManipulateBoneAngles(entity, id, ang, networking)
    return entManipulateBoneAngles(entity, id, ang, networking)
end

---@param entity Entity
---@param id integer
---@param scale Vector
---@return nil
function MGR.EntityManipulateBoneScale(entity, id, scale)
    return entManipulateBoneScale(entity, id, scale)
end


---@param ent Entity
---@param skin number
---@return nil
function MGR.EntitySetSkin(ent, skin)
    return entSetSkin(ent, skin)
end

---@param ent Entity
---@param pos Vector
---@return nil
function MGR.EntitySetPos(ent, pos)
    return entSetPos(ent, pos)
end

---@param ent Entity
---@param ang Angle
---@return nil
function MGR.EntitySetAngles(ent, ang)
    return entSetAngles(ent, ang)
end

do
---@type {[Entity]: PhysObj[]}
local physObjIndex = {}

hook.Add("OnEntityCreated", "SMHOptimizationsEntityCreated", function (ent)
    timer.Simple(0, function()
        if isValid(ent) and ent:IsRagdoll() then
            physObjIndex[ent] = {}
        end
    end)
end)

hook.Add("EntityRemoved", "SMHOptimizationsEntityRemoved", function (ent)
    physObjIndex[ent] = nil
end)

---@param entity Entity
---@param index integer
---@return PhysObj
function MGR.EntityGetPhysicsObjectNum(entity, index)
    
    physObjIndex[entity] = physObjIndex[entity] or {}
    local physObj = physObjIndex[entity][index]
    if not physObj then
        physObj = entGetPhysicsObjectNum(entity, index)
        physObjIndex[entity][index] = physObj
    end
    return physObj
end
end

do
---@type {[string]: integer}
local physObjCount = {}

---@param entity Entity
---@return integer
function MGR.EntityGetPhysicsObjectCount(entity)
    local model = optEntityGetModel(entity)
    local count = physObjCount[model]
    if not count then
        count = entGetPhysicsObjectCount(entity)
        physObjCount[model] = count
    end
    return count
end

end

end


SMH.Optimizations = MGR