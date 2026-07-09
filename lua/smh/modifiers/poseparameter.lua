
MOD.Name = "Pose parameters";

local opt = SMH.Optimizations
local setPoseParameter = opt.EntitySetPoseParameter

local lerpLinear = SMH.LerpLinear

function MOD:Save(entity)

    local data = {};

    local count = entity:GetNumPoseParameters();
    for i = 0, count - 1 do
        local name = entity:GetPoseParameterName(i);
        data[name] = entity:GetPoseParameter(name);
    end

    return data;

end

function MOD:Load(entity, data)

    for name, value in pairs(data) do
        setPoseParameter(entity, name, value);
    end

end

function MOD:LoadBetween(entity, data1, data2, percentage)

    for name, value1 in pairs(data1) do

        local value2 = data2[name];
        if value1 and value2 then
            setPoseParameter(entity, name, lerpLinear(value1, value2, percentage));
        elseif value1 then
            setPoseParameter(entity, name, value1);
        end

    end

end
