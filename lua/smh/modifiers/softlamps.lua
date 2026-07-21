
MOD.Name = "Soft Lamps";

local lerpLinear = SMH.LerpLinear
local lerpLinearVector = SMH.LerpLinearVector

function MOD:IsSoftLamp(entity)

    if entity:GetClass() ~= "gmod_softlamp" then return false; end
    return true;

end

function MOD:Save(entity)

    if not self:IsSoftLamp(entity) then return nil; end

    local data = {};

    data.FOV = entity:GetLightFOV();
    data.Nearz = entity:GetNearZ();
    data.Farz = entity:GetFarZ();
    data.Brightness = entity:GetBrightness();
    data.Color = entity:GetLightColor();
    data.ShapeRadius = entity:GetShapeRadius();
    data.FocalPoint = entity:GetFocalDistance();
    data.Offset = entity:GetLightOffset();

    return data;

end

function MOD:Load(entity, data)

    if not self:IsSoftLamp(entity) then return; end -- can never be too sure?

    entity:SetLightFOV(data.FOV);
    entity:SetNearZ(data.Nearz);
    entity:SetFarZ(data.Farz);
    entity:SetBrightness(data.Brightness);
    entity:SetLightColor(data.Color);
    entity:SetShapeRadius(data.ShapeRadius);
    entity:SetFocalDistance(data.FocalPoint);
    entity:SetLightOffset(data.Offset);

end

function MOD:LoadBetween(entity, data1, data2, percentage)

    if not self:IsSoftLamp(entity) then return; end -- can never be too sure?

    entity:SetLightFOV(lerpLinear(data1.FOV, data2.FOV, percentage));
    entity:SetNearZ(lerpLinear(data1.Nearz, data2.Nearz, percentage));
    entity:SetFarZ(lerpLinear(data1.Farz, data2.Farz, percentage));
    entity:SetBrightness(lerpLinear(data1.Brightness, data2.Brightness, percentage));
    entity:SetLightColor(lerpLinearVector(data1.Color, data2.Color, percentage));
    entity:SetShapeRadius(lerpLinear(data1.ShapeRadius, data2.ShapeRadius, percentage));
    entity:SetFocalDistance(lerpLinear(data1.FocalPoint, data2.FocalPoint, percentage));
    entity:SetLightOffset(lerpLinearVector(data1.Offset, data2.Offset, percentage));

end
