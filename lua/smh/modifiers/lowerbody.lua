include("smh/modifiers/bodytemplate.lua")

local modName = "lowerbody"
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

    local default = [[ValveBiped.Bip01_L_Foot
ValveBiped.Bip01_R_Foot
ValveBiped.Bip01_L_Toe0
ValveBiped.Bip01_R_Toe0
bip_foot_L
bip_foot_R
bip_toe_L
bip_toe_R
prp_legPouch
prp_pouch
prp_cord
prp_pack
prp_coat_back_0_M
prp_coat_back_0_R
prp_coat_back_0_L
prp_coat_front_0_R
prp_coat_front_0_L
prp_coat_back_1_M
prp_coat_back_1_R
prp_coat_back_1_L
prp_coat_front_1_R
prp_coat_front_1_L
prp_coat_back_2_M
prp_coat_back_2_R
prp_coat_back_2_L
prp_coat_front_2_R
prp_coat_front_2_L
prp_hippouch_0_L
prp_hippouch_0_B
bip_hippouch_0
bip_crotchflap_0
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

MOD.Name = "Lower Body (Root)"
MOD.SetRoot = true
MOD.Default = true