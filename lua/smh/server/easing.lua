---
-- Lerp methods
---

local lerp = Lerp
local lerpVector = LerpVector
local lerpAngle = LerpAngle

function SMH.LerpLinear(s, e, p)

    return lerp(p, s, e);

end

function SMH.LerpLinearVector(s, e, p)

    return lerpVector(p, s, e);

end

function SMH.LerpLinearAngle(s, e, p)

    return lerpAngle(p, s, e);

end
