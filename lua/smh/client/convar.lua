---@class SMH.ConVars
local convars = SMH.ConVars or {}
SMH.ConVars = convars
convars.Storage = {}

if CLIENT then
    ---@param name string
    ---@param default string
    ---@param userinfo boolean
    ---@param helptext string?
    ---@param type TYPE?
    ---@param min number?
    ---@param max number?
    ---@param category string?
    ---@return any
    function convars.Create(name, default, userinfo, helptext, type, min, max, category)
        local cvar
        if type == TYPE_BOOL then
            cvar = CreateClientConVar(name, default, true, userinfo, helptext, 0, 1)
        elseif type == TYPE_NUMBER then
            cvar = CreateClientConVar(name, default, true, userinfo, helptext, min, max)
        else
            cvar = CreateClientConVar(name, default, true, userinfo, helptext)
        end
        convars.Storage[name] = {cvar = cvar, helptext = helptext, type = type or TYPE_STRING, category = category or "Miscellaneous"}
        return cvar
    end

    function convars.Get()
        return convars.Storage
    end
end