
MOD.Name = "Editors";

local lerpLinear = SMH.LerpLinear
local lerpLinearVector = SMH.LerpLinearVector

local validClasses = {
    edit_fog = true,
    edit_sky = true,
    edit_sun = true,
}

function MOD:IsEditor(entity)

    return validClasses[entity:GetClass()]

end

function MOD:Save(entity)

    if not self:IsEditor(entity) then return nil; end

    local data = {};

    if entity:GetClass() == "edit_fog" then
        data.FogStart = entity:GetFogStart();
        data.FogEnd = entity:GetFogEnd();
        data.Density = entity:GetDensity();
        data.FogColor = entity:GetFogColor();
    elseif entity:GetClass() == "edit_sky" then
        data.TopColor = entity:GetTopColor()
        data.BottomColor = entity:GetBottomColor()
        data.FadeBias = entity:GetFadeBias()
        data.HDRScale = entity:GetHDRScale()
        data.StarLayers = entity:GetStarLayers()
        data.StarScale = entity:GetStarScale()
        data.StarFade = entity:GetStarFade()
        data.StarSpeed = entity:GetStarSpeed()
        data.DuskIntensity = entity:GetDuskIntensity()
        data.DuskScale = entity:GetDuskScale()
        data.DuskColor = entity:GetDuskColor()
        data.SunSize = entity:GetSunSize()
        data.SunColor = entity:GetSunColor()
    elseif entity:GetClass() == "edit_sun" then
        data.SunSize = entity:GetSunSize();
        data.OverlaySize = entity:GetOverlaySize();
        data.SunColor = entity:GetSunColor();
        data.OverlayColor = entity:GetOverlayColor();
    end

    return data;

end

function MOD:Load(entity, data)

    if not self:IsEditor(entity) then return; end -- can never be too sure?

    if entity:GetClass() == "edit_fog" then
        entity:SetFogStart(data.FogStart);
        entity:SetFogEnd(data.FogEnd);
        entity:SetDensity(data.Density);
        entity:SetFogColor(data.FogColor);
    elseif entity:GetClass() == "edit_fog" then
        entity:SetTopColor(data.TopColor)
        entity:SetBottomColor(data.BottomColor)
        entity:SetFadeBias(data.FadeBias)
        entity:SetHDRScale(data.HDRScale)
        entity:SetStarLayers(data.StarLayers)
        entity:SetStarScale(data.StarScale)
        entity:SetStarFade(data.StarFade)
        entity:SetStarSpeed(data.StarSpeed)
        entity:SetDuskIntensity(data.DuskIntensity)
        entity:SetDuskScale(data.DuskScale)
        entity:SetDuskColor(data.DuskColor)
        entity:SetSunSize(data.SunSize)
        entity:SetSunColor(data.SunColor)
    elseif entity:GetClass() == "edit_sun" then
        entity:SetSunSize(data.SunSize);
        entity:SetOverlaySize(data.OverlaySize);
        entity:SetSunColor(data.SunColor);
        entity:SetOverlayColor(data.OverlayColor);
    end

end

function MOD:LoadBetween(entity, data1, data2, percentage)

    if not self:IsEditor(entity) then return; end -- can never be too sure?

    if entity:GetClass() == "edit_fog" then
        entity:SetFogStart(lerpLinear(data1.FogStart, data2.FogStart, percentage));
        entity:SetFogEnd(lerpLinear(data1.FogEnd, data2.FogEnd, percentage));
        entity:SetDensity(lerpLinear(data1.Density, data2.Density, percentage));
        entity:SetFogColor(lerpLinearVector(data1.FogColor, data2.FogColor, percentage));
    elseif entity:GetClass() == "edit_sky" then
        entity:SetTopColor(lerpLinearVector(data1.TopColor, data2.TopColor, percentage))
        entity:SetBottomColor(lerpLinearVector(data1.BottomColor, data2.BottomColor, percentage))
        entity:SetFadeBias(lerpLinear(data1.FadeBias, data2.FadeBias, percentage))
        entity:SetHDRScale(lerpLinear(data1.HDRScale, data2.HDRScale, percentage))
        entity:SetStarLayers(lerpLinear(data1.StarLayers, data2.StarLayers, percentage))
        entity:SetStarScale(lerpLinear(data1.StarScale, data2.StarScale, percentage))
        entity:SetStarFade(lerpLinear(data1.StarFade, data2.StarFade, percentage))
        entity:SetStarSpeed(lerpLinear(data1.StarSpeed, data2.StarSpeed, percentage))
        entity:SetDuskIntensity(lerpLinear(data1.DuskIntensity, data2.DuskIntensity, percentage))
        entity:SetDuskScale(lerpLinear(data1.DuskScale, data2.DuskScale, percentage))
        entity:SetDuskColor(lerpLinearVector(data1.DuskColor, data2.DuskColor, percentage))
        entity:SetSunSize(lerpLinear(data1.SunSize, data2.SunSize, percentage))
        entity:SetSunColor(lerpLinearVector(data1.SunColor, data2.SunColor, percentage))
    elseif entity:GetClass() == "edit_sun" then
        entity:SetSunSize(lerpLinear(data1.SunSize, data2.SunSize, percentage));
        entity:SetOverlaySize(lerpLinear(data1.OverlaySize, data2.OverlaySize, percentage));
        entity:SetSunColor(lerpLinearVector(data1.SunColor, data2.SunColor, percentage));
        entity:SetOverlayColor(lerpLinearVector(data1.OverlayColor, data2.OverlayColor, percentage));
    end

end
