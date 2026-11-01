include("smh/modifiers/bodytemplate.lua")

local modName = "upperbody"
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

    local default = [[bip_head
bip_hand_L
bip_hand_R
bip_dogtag_0
bip_dogtag_1
bip_dogtag_2
bip_dogtag_3
ValveBiped.Bip01_L_Hand
ValveBiped.Bip01_R_Hand
ValveBiped.Bip01_Head1
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

MOD.Name = "Upper Body"
MOD.SetRoot = false
MOD.Default = true