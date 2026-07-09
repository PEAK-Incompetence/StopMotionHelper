MOD.Name = "Model scale";

local opt = SMH.Optimizations
local setModelScale = opt.EntitySetModelScale

local lerpLinear = SMH.LerpLinear

function MOD:Save(entity)
    return {
        ModelScale = entity:GetModelScale();
    };
end

function MOD:LoadGhost(entity, ghost, data)
    self:Load(ghost, data);
end

function MOD:LoadGhostBetween(entity, ghost, data1, data2, percentage)
    self:LoadBetween(ghost, data1, data2, percentage);
end

function MOD:Load(entity, data)
    setModelScale(entity, data.ModelScale);
end

function MOD:LoadBetween(entity, data1, data2, percentage)

    local lerpedModelScale = lerpLinear(data1.ModelScale, data2.ModelScale, percentage);
    setModelScale(entity, lerpedModelScale);

end
