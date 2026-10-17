-- Backwards compat
include("sent.lua")
MOD.Name = "Advanced Cameras (deprecated)";
MOD.Default = false

local lerpLinear = SMH.LerpLinear
local lerpLinearVector = SMH.LerpLinearVector

function MOD:IsAdvCamera(entity)

    if entity:GetClass() ~= "hl_camera" then return false; end
    return true;

end

function MOD:Load(entity, data)

    if not self:IsAdvCamera(entity) then return; end -- can never be too sure?

    entity:SetFOV(data.FOV);
    entity:SetNearZ(data.Nearz or data.NearZ);
    entity:SetFarZ(data.Farz or data.FarZ);
    entity:SetRoll(data.Roll);
    entity:SetViewOffset(data.Offset or data.ViewOffset);

end

function MOD:LoadBetween(entity, data1, data2, percentage)

    if not self:IsAdvCamera(entity) then return; end -- can never be too sure?

    entity:SetFOV(lerpLinear(data1.FOV, data2.FOV, percentage));
    entity:SetNearZ(lerpLinear(data1.Nearz or data1.NearZ, data2.Nearz or data2.NearZ, percentage));
    entity:SetFarZ(lerpLinear(data1.Farz or data1.FarZ, data2.Farz or data2.FarZ, percentage));
    entity:SetRoll(lerpLinear(data1.Roll, data2.Roll, percentage));
    entity:SetViewOffset(lerpLinearVector(data1.Offset or data1.ViewOffset, data2.Offset or data2.ViewOffset, percentage));

end
