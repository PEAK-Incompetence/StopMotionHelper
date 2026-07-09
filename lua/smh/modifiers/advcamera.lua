
MOD.Name = "Advanced Cameras";

local lerpLinear = SMH.LerpLinear
local lerpLinearVector = SMH.LerpLinearVector

function MOD:IsAdvCamera(entity)

    if entity:GetClass() ~= "hl_camera" then return false; end
    return true;

end

function MOD:Save(entity)

    if not self:IsAdvCamera(entity) then return nil; end

    local data = {};

    data.FOV = entity:GetFOV();
    data.Nearz = entity:GetNearZ();
    data.Farz = entity:GetFarZ();
    data.Roll = entity:GetRoll();
    data.Offset = entity:GetViewOffset();

    return data;

end

function MOD:Load(entity, data)

    if not self:IsAdvCamera(entity) then return; end -- can never be too sure?

    entity:SetFOV(data.FOV);
    entity:SetNearZ(data.Nearz);
    entity:SetFarZ(data.Farz);
    entity:SetRoll(data.Roll);
    entity:SetViewOffset(data.Offset);

end

function MOD:LoadBetween(entity, data1, data2, percentage)

    if not self:IsAdvCamera(entity) then return; end -- can never be too sure?

    entity:SetFOV(lerpLinear(data1.FOV, data2.FOV, percentage));
    entity:SetNearZ(lerpLinear(data1.Nearz, data2.Nearz, percentage));
    entity:SetFarZ(lerpLinear(data1.Farz, data2.Farz, percentage));
    entity:SetRoll(lerpLinear(data1.Roll, data2.Roll, percentage));
    entity:SetViewOffset(lerpLinearVector(data1.Offset, data2.Offset, percentage));

end
