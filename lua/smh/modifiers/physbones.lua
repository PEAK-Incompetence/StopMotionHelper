
MOD.Name = "Physical Bones";
MOD.Ghost = true

local opt = SMH.Optimizations
local setPos = opt.PhysObjSetPos
local setAngles = opt.PhysObjSetAngles
local enableMotion = opt.PhysObjEnableMotion
local wake = opt.PhysObjWake

local getPhysicsObjectNum = opt.EntityGetPhysicsObjectNum

local lerpLinearVector = SMH.LerpLinearVector
local lerpLinearAngle = SMH.LerpLinearAngle

function MOD:Save(entity)

    local count = entity:GetPhysicsObjectCount();
    if count <= 0 then return nil; end

    local data = {};

    for i = 0, count - 1 do

        local pb = getPhysicsObjectNum(entity, i);
        local parent = getPhysicsObjectNum(entity, GetPhysBoneParent(entity, i));

        local d = {};

        d.Pos = pb:GetPos();
        d.Ang = pb:GetAngles();

        if parent then
            d.LocalPos, d.LocalAng = WorldToLocal(pb:GetPos(), pb:GetAngles(), parent:GetPos(), parent:GetAngles());
        end

        d.Moveable = pb:IsMoveable();

        data[i] = d;

    end

    return data;

end

function MOD:Load(entity, data, settings)

    if settings.IgnorePhysBones then
        return;
    end

    local count = entity:GetPhysicsObjectCount();
    local freezeAll = settings.FreezeAll
    local localizePhysBones = settings.LocalizePhysBones

    for i = 0, count - 1 do

        local pb = getPhysicsObjectNum(entity, i);
        local parent = getPhysicsObjectNum(entity, GetPhysBoneParent(entity, i));

        local d = data[i];

        if parent and localizePhysBones and d.LocalPos and d.LocalAng then
            local pos, ang = LocalToWorld(d.LocalPos, d.LocalAng, parent:GetPos(), parent:GetAngles());
            setPos(pb, pos, true)
            setAngles(pb, ang)
        else
            setPos(pb, d.Pos, true);
            setAngles(pb, d.Ang);
        end

        if freezeAll then
            enableMotion(pb, false);
        else
            enableMotion(pb, d.Moveable);
        end

        wake(pb);

    end

end

function MOD:LoadGhost(entity, ghost, data)

    local count = ghost:GetPhysicsObjectCount();

    for i = 0, count - 1 do

        local pb = getPhysicsObjectNum(ghost, i);

        enableMotion(pb, true);
        wake(pb);

        local d = data[i];
        setPos(pb, d.Pos, true);
        setAngles(pb, d.Ang);

        enableMotion(pb, false);
        wake(pb);

    end

end

function MOD:LoadGhostBetween(entity, ghost, data1, data2, percentage)

    local count = ghost:GetPhysicsObjectCount();

    for i = 0, count - 1 do

        local pb = getPhysicsObjectNum(ghost, i);

        local d1 = data1[i];
        local d2 = data2[i];

        local Pos = lerpLinearVector(d1.Pos, d2.Pos, percentage);
        local Ang = lerpLinearAngle(d1.Ang, d2.Ang, percentage);

        enableMotion(pb, false);
        setPos(pb, Pos, true);
        setAngles(pb, Ang);

        wake(pb);

    end
end

function MOD:LoadBetween(entity, data1, data2, percentage, settings)

    if settings.IgnorePhysBones then
        return;
    end

    local count = entity:GetPhysicsObjectCount();
    local freezeAll = settings.FreezeAll

    for i = 0, count - 1 do
        local pb = getPhysicsObjectNum(entity, i);

        local d1 = data1[i];
        local d2 = data2[i];

        local Pos = lerpLinearVector(d1.Pos, d2.Pos, percentage);
        local Ang = lerpLinearAngle(d1.Ang, d2.Ang, percentage);

        if freezeAll then
            enableMotion(pb, false);
        else
            enableMotion(pb, d1.Moveable);
        end
        setPos(pb, Pos, true);
        setAngles(pb, Ang);

        wake(pb);
    end

end

function MOD:Offset(data, origindata, worldvector, worldangle, hitpos)

    if not hitpos then
        hitpos = origindata[0].Pos;
    end

    local newdata = {};

    for id, kdata in pairs(data) do

        local d = {};
        local Pos, Ang = WorldToLocal(kdata.Pos, kdata.Ang, origindata[0].Pos, Angle(0, 0, 0));
        d.Pos, d.Ang = LocalToWorld(Pos, Ang, worldvector, worldangle);
        d.Pos = d.Pos + hitpos;

        if kdata.LocalPos and kdata.LocalAng then -- those shouldn't change
            d.LocalPos, d.LocalAng = kdata.LocalPos, kdata.LocalAng;
        end

        d.Moveable = kdata.Moveable;

        newdata[id] = d;
    end

    return newdata;

end

function MOD:OffsetDupe(entity, data, origindata)

    local pb = getPhysicsObjectNum(entity, 0);
    if not IsValid(pb) then return nil end

    local entPos, entAng = pb:GetPos(), pb:GetAngles();
    local newdata = {};

    for id, kdata in pairs(data) do

        local d = {};
        d.Pos, d.Ang = WorldToLocal(kdata.Pos, kdata.Ang, origindata[0].Pos, origindata[0].Ang);
        d.Pos, d.Ang = LocalToWorld(d.Pos, d.Ang, entPos, entAng);

        if kdata.LocalPos and kdata.LocalAng then -- those shouldn't change
            d.LocalPos, d.LocalAng = kdata.LocalPos, kdata.LocalAng;
        end

        d.Moveable = kdata.Moveable;

        newdata[id] = d;
    end

    return newdata;

end
