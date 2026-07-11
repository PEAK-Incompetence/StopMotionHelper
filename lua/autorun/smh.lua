---
-- SMH Entry point.
---

if SERVER then
    AddCSLuaFile("smh.lua")
    include("smh/server.lua")
else
    include("smh/client.lua")
end

timer.Simple(0, function ()
    -- Since either `server.lua` or `client.lua` includes will
    -- add "PostSMHLoaded" to the HookTable, this function should
    -- be able to run
    hook.Run("PostSMHLoaded", SMH)
end)