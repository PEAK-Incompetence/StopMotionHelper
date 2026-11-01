include("smh/modifiers/bodytemplate.lua")

local modName = "rootphysics"
local refreshBody
do
    local directory = Format("smh_%s/", modName)
    function refreshBody()
        local files = file.Find(Format("%s/*.txt", directory), "DATA")
        for _, f in ipairs(files) do 
            local list = file.Read(Format("%s/%s", directory, f), "DATA")
            if list then
                for _, item in ipairs(string.Split(list, '\n')) do
                    table.insert(MOD.BodyEnds, string.TrimRight(item))
                end
            end
        end
    end
    refreshBody()

    local default = [[ValveBiped.Bip01_Pelvis
bip_pelvis
    ]]

    local function initializeDirectory(check)
        if not file.IsDir(directory, "DATA") then
            file.CreateDir(directory)
        end
        local path = Format("%s/%s", directory, "valve.txt")
        if check or not file.Read(path) then
            local s = default
            file.Write(path, s)
        end
    end
    concommand.Add(Format("smh_%s_refresh", modName), function (ply, cmd, args, argStr)
        initializeDirectory(true) 
    end)
    initializeDirectory(false)
end

MOD.Name = "Root Physics (Root)"
MOD.SetRoot = true
MOD.Default = true
