
MOD.Name = "Color";

local opt = SMH.Optimizations
local setColor = opt.EntitySetColor

local lerpLinear = SMH.LerpLinear

function MOD:Save(entity)

    if self:IsEffect(entity) then
        entity = entity.AttachedEntity;
    end

    local color = entity:GetColor();
    return { Color = color };

end

function MOD:Load(entity, data)

    if self:IsEffect(entity) then
        entity = entity.AttachedEntity;
    end

    setColor(entity, data.Color);

end

local colorSetter = Color(255, 255, 255, 255)

function MOD:LoadBetween(entity, data1, data2, percentage)

    if self:IsEffect(entity) then
        entity = entity.AttachedEntity;
    end

    local c1 = data1.Color;
    local c2 = data2.Color;

    local r = lerpLinear(c1.r, c2.r, percentage);
    local g = lerpLinear(c1.g, c2.g, percentage);
    local b = lerpLinear(c1.b, c2.b, percentage);
    local a = lerpLinear(c1.a, c2.a, percentage);

    colorSetter:SetUnpacked(r, g, b, a)

    setColor(entity, colorSetter);

end
