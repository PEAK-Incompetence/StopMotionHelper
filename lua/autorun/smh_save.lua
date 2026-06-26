local newDupeSave = CreateConVar("smh_streamsave", "1", { FCVAR_ARCHIVE, FCVAR_CHEAT, FCVAR_REPLICATED }, "If set to 1, this allows one to make GMod saves with a bigger file sizes (greater than 256KB).", 0, 1)

local isSavingMap
local isLoadingMap

timer.Simple(0, function()
    local loadDelay = 0.2
    if not SMH.OldGMSaveFunc then
        local tab = concommand.GetTable()
        SMH.OldGMSaveFunc = tab["gm_save"]
    end

    if CLIENT then
        isSavingMap = false
        isLoadingMap = false
    else
        concommand.Add( "gm_save", function( ply, cmd, args )
            if not newDupeSave:GetBool() then
                return SMH.OldGMSaveFunc(ply, cmd, args)
            end
            if ( !IsValid( ply ) ) then return end

            print("Saving with `smh_streamsave 1`. If the menu is paused, you need to unpause it in order to properly save")
            -- gmsave.SaveMap is very expensive for big maps/lots of entities. Do not allow random ppl to save the map in multiplayer!
            -- TODO: Actually do proper hooks for this
            if ( !game.SinglePlayer() && !ply:IsAdmin() ) then return end
            
            if ( ply.m_NextSave && ply.m_NextSave > CurTime() && !game.SinglePlayer() ) then
                ServerLog( tostring( ply ) ..  " tried to save too quickly!\n" )
                return
            end

            ply.m_NextSave = CurTime() + 10

            ServerLog( tostring( ply ) .. " requested a save.\n" )

            local save = gmsave.SaveMap( ply )
            if ( !save ) then return end

            local compressed_save = util.Compress( save )
            if ( !compressed_save ) then compressed_save = save end

            local len = string.len( compressed_save )
            local send_size = 60000
            local parts = math.ceil( len / send_size )

            local ShowSave = false
            if ( args[ 1 ] == "spawnmenu" ) then ShowSave = true end

            local start = 0
            for i = 1, parts do
                timer.Simple(i * loadDelay, function()
                
                    local endbyte = math.min( start + send_size, len )
                    local size = endbyte - start

                    net.Start( "GModSave" )
                        net.WriteBool( i == parts )
                        net.WriteBool( ShowSave )

                        net.WriteUInt( size, 16 )
                        net.WriteData( compressed_save:sub( start + 1, endbyte + 1 ), size )
                    net.Send( ply )

                    start = endbyte

                    if i == 1 or i == parts then
                        net.Start("SMHSaveMap")
                        net.WriteBool(i < parts)
                        net.Send(ply)
                    end
                end)

            end
            ply.m_NextSave = CurTime() + parts * loadDelay + 10

        end, nil, "", { FCVAR_DONTRECORD } )
    end
end)

if SERVER then
    util.AddNetworkString("SMHLoadMap")
    util.AddNetworkString("SMHSaveMap")
    return
end

local x, y = ScrW() * 0.5, ScrH() * 0.5
local dotCount = 0

hook.Add("HUDPaint", "SMHShowLoadingMap", function()
    dotCount = dotCount + 0.05
    local dots = ""
    for _ = 1, math.floor(dotCount) % 3 + 1 do
        dots = dots .. "."
    end
    if isSavingMap then
        draw.DrawText("Saving map" .. dots, "Trebuchet24", x, y)
    elseif isLoadingMap then
        draw.DrawText("Loading map" .. dots, "Trebuchet24", x, y)
    end
end)

net.Receive("SMHLoadMap", function (len, ply)
    isLoadingMap = net.ReadBool()
end)

net.Receive("SMHSaveMap", function (len, ply)
    isSavingMap = net.ReadBool()
end)