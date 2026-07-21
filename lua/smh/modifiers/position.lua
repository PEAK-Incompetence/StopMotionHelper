
MOD.Name = "Position and Rotation";

local opt = SMH.Optimizations
local setPos = opt.EntitySetPos
local setAngles = opt.EntitySetAngles

local lerpLinearVector = SMH.LerpLinearVector
local lerpLinearAngle = SMH.LerpLinearAngle

function MOD:Save(entity)

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

    setPos(entity, data.Pos);
    setAngles(entity, data.Ang);

end

function MOD:LoadBetween(entity, data1, data2, percentage)

    local Pos = lerpLinearVector(data1.Pos, data2.Pos, percentage);
    local Ang = lerpLinearAngle(data1.Ang, data2.Ang, percentage);

    setPos(entity, Pos);
    setAngles(entity, Ang);

end

function MOD:Offset(data, origindata, worldvector, worldangle, hitpos)

    if not hitpos then
        hitpos = origindata.Pos
    end

    local datanew = {};
    local Pos, Ang = WorldToLocal(data.Pos, data.Ang, origindata.Pos, Angle(0, 0, 0));
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
