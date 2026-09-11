--- 
-- Lerp methods
--- 

local lerp = Lerp
local lerpVector = LerpVector
local lerpAngle = LerpAngle

--- @param s any
--- @param e any
--- @param p any
--- @return number
function SMH.LerpLinear(s, e, p)

    return lerp(p, s, e);

end

--- @param s any
--- @param e any
--- @param p any
--- @return Vector
function SMH.LerpLinearVector(s, e, p)

    return lerpVector(p, s, e);

end

--- @param s any
--- @param e any
--- @param p any
--- @return Angle
function SMH.LerpLinearAngle(s, e, p)

    return lerpAngle(p, s, e);

end
