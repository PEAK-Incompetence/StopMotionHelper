-- Backwards compat
include("sent.lua")
MOD.Name = "Soft Lamps (deprecated)";
MOD.Default = false

local lerpLinear = SMH.LerpLinear
local lerpLinearVector = SMH.LerpLinearVector

function MOD:IsSoftLamp(entity)

    if entity:GetClass() ~= "gmod_softlamp" then return false; end
    return true;

end

function MOD:Load(entity, data)

    if not self:IsSoftLamp(entity) then return; end -- can never be too sure?

    entity:SetLightFOV(data.FOV or data.LightFOV);
    entity:SetNearZ(data.Nearz or data.NearZ);
    entity:SetFarZ(data.Farz or data.FarZ);
    entity:SetBrightness(data.Brightness);
    entity:SetLightColor(data.Color or data.LightColor);
    entity:SetShapeRadius(data.ShapeRadius or data.ShapeRadius);
    entity:SetFocalDistance(data.FocalPoint or data.FocalDistance);
    entity:SetLightOffset(data.Offset or data.LightOffset);

end

function MOD:LoadBetween(entity, data1, data2, percentage)

    if not self:IsSoftLamp(entity) then return; end -- can never be too sure?

    entity:SetLightFOV(lerpLinear(data1.FOV or data1.LightFOV, data2.FOV or data2.LightFOV, percentage));
    entity:SetNearZ(lerpLinear(data1.Nearz or data1.NearZ, data2.Nearz or data2.NearZ, percentage));
    entity:SetFarZ(lerpLinear(data1.Farz or data1.FarZ, data2.Farz or data2.FarZ, percentage));
    entity:SetBrightness(lerpLinear(data1.Brightness, data2.Brightness, percentage));
    entity:SetLightColor(lerpLinearVector(data1.Color or data1.LightColor, data2.Color or data2.LightColor, percentage));
    entity:SetShapeRadius(lerpLinear(data1.ShapeRadius, data2.ShapeRadius, percentage));
    entity:SetFocalDistance(lerpLinear(data1.FocalPoint or data1.FocalDistance, data2.FocalPoint or data2.FocalDistance, percentage));
    entity:SetLightOffset(lerpLinearVector(data1.Offset or data1.LightOffset, data2.Offset or data2.LightOffset, percentage));

end
