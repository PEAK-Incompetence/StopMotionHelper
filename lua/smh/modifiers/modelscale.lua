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
    if data.ModelScale then
        setModelScale(entity, data.ModelScale);
    end
end

function MOD:LoadBetween(entity, data1, data2, percentage)

    local lerpedModelScale = data1.ModelScale and data2.ModelScale and lerpLinear(data1.ModelScale, data2.ModelScale, percentage);
    lerpedModelScale = lerpedModelScale or data1.ModelScale
    lerpedModelScale = lerpedModelScale or data2.ModelScale
    if lerpedModelScale then
        setModelScale(entity, lerpedModelScale);
    end

end
