
MOD.Name = "Position and Rotation";
MOD.Ghost = true

local opt = SMH.Optimizations
local setPos = opt.EntitySetPos
local setAngles = opt.EntitySetAngles
local getPhysicsObject = opt.EntityGetPhysicsObject
local getBrushPlaneCount = opt.EntityGetBrushPlaneCount

local lerpLinearVector = SMH.LerpLinearVector
local lerpLinearAngle = SMH.LerpLinearAngle

function MOD:Save(entity)

    -- Don't record redundant data if we have a physics object that can provide
    -- more accurate transform data
    if getPhysicsObject(entity) and getBrushPlaneCount(entity) == 0 then
        return nil;
    end

    local data = {};
    data.Pos = entity:GetPos();
    data.Ang = entity:GetAngles();
    return data;

end

function MOD:LoadGhost(entity, ghost, data)
    self:Load(ghost, data);
end

function MOD:LoadGhostBetween(entity, ghost, data1, data2, percentage)
    self:LoadBetween(ghost, data1, data2, percentage);
end

function MOD:Load(entity, data)
    if getPhysicsObject(entity) and getBrushPlaneCount(entity) == 0 then
        return
    end

    setPos(entity, data.Pos);
    setAngles(entity, data.Ang);

end

function MOD:LoadBetween(entity, data1, data2, percentage)
    if getPhysicsObject(entity) and getBrushPlaneCount(entity) == 0 then
        return
    end

    local Pos = lerpLinearVector(data1.Pos, data2.Pos, percentage);
    local Ang = lerpLinearAngle(data1.Ang, data2.Ang, percentage);

    setPos(entity, Pos);
    setAngles(entity, Ang);

end

local zeroAngle = Angle(0, 0, 0)
function MOD:Offset(data, origindata, worldvector, worldangle, hitpos)

    if not hitpos then
        hitpos = origindata.Pos
    end

    local datanew = {};
    local Pos, Ang = WorldToLocal(data.Pos, data.Ang, origindata.Pos, zeroAngle);
    datanew.Pos, datanew.Ang = LocalToWorld(Pos, Ang, worldvector, worldangle);
    datanew.Pos = datanew.Pos + hitpos;
    return datanew;

end

function MOD:OffsetDupe(entity, data, origindata)

    local entPos, entAng = entity:GetPos(), entity:GetAngles();
    local datanew = {};
    datanew.Pos, datanew.Ang = WorldToLocal(data.Pos, data.Ang, origindata.Pos, origindata.Ang);
    datanew.Pos, datanew.Ang = LocalToWorld(datanew.Pos, datanew.Ang, entPos, entAng);

    return datanew;

end
