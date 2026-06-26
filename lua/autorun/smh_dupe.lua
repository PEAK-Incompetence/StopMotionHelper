---This file replaces the `dupe_arm` and `dupe_save` functions, to allow larger animations to be stored in
---a dupe. 

local newDupeSave = CreateConVar("smh_streamdupes", "1", { FCVAR_ARCHIVE, FCVAR_CHEAT, FCVAR_REPLICATED }, "If set to 1, this allows one to dupes with a bigger file sizes (greater than 256KB). It reduces the likelihood of getting kicked when loading big dupes.", 0, 1)

local DUPE_SEND_SIZE = 60000

local isLoadingDupe
local isSavingDupe

---There's no guarantee that the concommand table will be filled
---at the same tick, so we have to call this at the next tick
timer.Simple(0, function()
    local loadDelay = 0.2
    -- Let's use the old dupe functions in case the server owner doesn't
    -- want these new features
    if not SMH.OldArmFunc then
        local tab = concommand.GetTable()
        SMH.OldArmFunc = tab["dupe_arm"]
        SMH.OldSaveFunc = tab["dupe_save"]
    end

    if CLIENT then
        isLoadingDupe = false
        isSavingDupe = false
        local LastDupeArm = 0

        concommand.Remove("dupe_arm")
        concommand.Add( "dupe_arm", function( ply, cmd, arg )
            if not newDupeSave:GetBool() then
                return SMH.OldArmFunc(ply, cmd, arg)
            end
            if ( !arg[ 1 ] ) then return end
            local dupeName = tostring( arg[ 1 ] )

            if ( LastDupeArm > CurTime() and !game.SinglePlayer() ) then ply:ChatPrint( "Please wait a second before trying to load another duplication!" ) return end
            LastDupeArm = CurTime() + 1

            -- Server doesn't allow us to do this, don't even try to send them data
            local res, msg = hook.Run( "CanArmDupe", ply )
            if ( res == false ) then ply:ChatPrint( msg or "Refusing to load dupe, server has blocked usage of the Duplicator tool!" ) return end

            -- Load the dupe (engine takes care of making sure it's a dupe)
            local dupe = engine.OpenDupe( dupeName )
            if ( !dupe ) then ply:ChatPrint( "Error loading dupe.. (" .. dupeName .. ")" ) return end

            local uncompressed = util.Decompress( dupe.data )
            if ( !uncompressed ) then ply:ChatPrint( "That dupe seems to be corrupted!" ) return end

            --
            -- And send it to the server
            --
            local length = dupe.data:len()
            local parts = math.ceil( length / DUPE_SEND_SIZE )

            local start = 0
            for i = 1, parts do
                timer.Simple(i * loadDelay, function()
                    local endbyte = math.min( start + DUPE_SEND_SIZE, length )
                    local size = endbyte - start
                    net.Start( "ArmDupe" )
                        net.WriteUInt( i, 8 )
                        net.WriteUInt( parts, 8 )
    
                        net.WriteUInt( size, 32 )
                        net.WriteData( dupe.data:sub( start + 1, endbyte + 1 ), size )
                        if ( i == parts ) then
                            net.WriteString( dupeName:sub( 1, 128 ) )
                        end
                    net.SendToServer()
                    start = endbyte

                    isLoadingDupe = i < parts
                end)
            end
            LastDupeArm = CurTime() + loadDelay * parts + 1
        end, nil, "Arm a dupe", { FCVAR_DONTRECORD } )
    else
        concommand.Remove("dupe_save")
        concommand.Add( "dupe_save", function( ply, cmd, arg )
            if not newDupeSave:GetBool() then
                return SMH.OldSaveFunc(ply, cmd, arg)
            end
            if ( !IsValid( ply ) ) then return end

            -- No dupe to save
            if ( !ply.CurrentDupe ) then return end

            -- Current dupe was armed from a file. Don't allow immediate resave.
            if ( ply.CurrentDupeArmed ) then return end

            if ( ply.m_NextDupeSave && ply.m_NextDupeSave > CurTime() && !game.SinglePlayer() ) then
                ServerLog( tostring( ply ) .. " tried to save a dupe too quickly!\n" )
                return
            end
            ply.m_NextDupeSave = CurTime() + 1

            -- Convert dupe to JSON
            local json = util.TableToJSON( ply.CurrentDupe )

            -- Compress it
            local compressed = util.Compress( json )
            local length = compressed:len()
            local send_size = 60000
            local parts = math.ceil( length / send_size )

            ServerLog( tostring( ply ) .. " requested a Dupe. Size: " .. json:len() .. " ( " .. length .. " compressed, " .. parts .. " parts )\n" )

            -- And send it(!)
            local start = 0
            for i = 1, parts do                
                timer.Simple(i * loadDelay, function()
                    local endbyte = math.min( start + send_size, length )
                    local size = endbyte - start
                    -- print( "S [ " .. i .. " / " .. parts .. " ] Size: " .. size .. " Start: " .. start .. " End: " .. endbyte )
                    net.Start( "ReceiveDupe" )
                        net.WriteUInt( i, 8 )
                        net.WriteUInt( parts, 8 )
    
                        net.WriteUInt( size, 32 )
                        net.WriteData( compressed:sub( start + 1, endbyte + 1 ), size )
                    net.Send( ply )
                    start = endbyte

                    if i == 1 or i == parts then
                        net.Start("SMHSaveDupe")
                        net.WriteBool(i < parts)
                        net.Send(ply)
                    end
                end)
            end
            ply.m_NextDupeSave = CurTime() + loadDelay * parts + 1
        end, nil, "Save the current dupe!", { FCVAR_DONTRECORD } )

        SMH.OldArmReceiver = SMH.OldArmReceiver or net.Receivers["armdupe"]
        -- We're replacing this because we want to remove limits from the `util.Decompress` function
        net.Receive( "ArmDupe", function( size, client )
            if not newDupeSave:GetBool() then
                return SMH.OldArmReceiver(size, client)
            end
            if ( !IsValid( client ) or size < 48 ) then return end

            local res, msg = hook.Run( "CanArmDupe", client )
            if ( res == false ) then client:ChatPrint( msg or "Server has blocked usage of the Duplicator tool!" ) return end

            local part = net.ReadUInt( 8 )
            local total = net.ReadUInt( 8 )

            local length = net.ReadUInt( 32 )
            if ( length > DUPE_SEND_SIZE ) then return end

            local datachunk = net.ReadData( length )

            client.CurrentDupeBuffer = client.CurrentDupeBuffer or {}
            client.CurrentDupeBuffer[ part ] = datachunk

            if ( part != total ) then return end

            local dupeName = net.ReadString()

            local data = table.concat( client.CurrentDupeBuffer )
            client.CurrentDupeBuffer = nil

            if ( ( client.LastDupeArm or 0 ) > CurTime() and !game.SinglePlayer() ) then ServerLog( tostring( client ) .. " tried to arm a dupe too quickly!\n" ) return end
            client.LastDupeArm = CurTime() + 1

            ServerLog( tostring( client ) .. " is arming a dupe, size: " .. data:len() .. "\n" )

            local uncompressed = util.Decompress( data )
            if ( !uncompressed ) then
                client:ChatPrint( "Server failed to decompress the duplication!" )
                MsgN( "Couldn't decompress dupe from " .. client:Nick() .. "!" )
                return
            end

            local Dupe = util.JSONToTable( uncompressed )
            if ( !istable( Dupe ) ) then return end
            if ( !istable( Dupe.Constraints ) ) then return end
            if ( !istable( Dupe.Entities ) ) then return end
            if ( !isvector( Dupe.Mins ) ) then return end
            if ( !isvector( Dupe.Maxs ) ) then return end

            client.CurrentDupeArmed = true
            client.CurrentDupe = Dupe

            client:ConCommand( "gmod_tool duplicator" )

            --
            -- Tell the client we got a dupe on server, ready to paste
            --
            local workshopCount = 0
            if ( Dupe.RequiredAddons ) then workshopCount = #Dupe.RequiredAddons end

            net.Start( "CopiedDupe" )
                net.WriteUInt( 0, 1 ) -- Can save
                net.WriteVector( Dupe.Mins )
                net.WriteVector( Dupe.Maxs )
                net.WriteString( dupeName )
                net.WriteUInt( table.Count( Dupe.Entities ), 24 )
                net.WriteUInt( workshopCount, 16 )
                if ( Dupe.RequiredAddons ) then
                    for _, wsid in ipairs( Dupe.RequiredAddons ) do
                        net.WriteString( wsid )
                    end
                end
                net.WriteUInt( table.Count( Dupe.Constraints ), 24 )
            net.Send( client )

        end )

    end
end)

if SERVER then
    util.AddNetworkString("SMHLoadDupe")
    util.AddNetworkString("SMHSaveDupe")
    return
end

local x, y = ScrW() * 0.5, ScrH() * 0.5
local dotCount = 0

hook.Add("HUDPaint", "SMHShowLoadingDupe", function()
    dotCount = dotCount + 0.05
    local dots = ""
    for _ = 1, math.floor(dotCount) % 3 + 1 do
        dots = dots .. "."
    end
    if isSavingDupe then
        draw.DrawText("Saving dupe" .. dots, "Trebuchet24", x, y)
    elseif isLoadingDupe then
        draw.DrawText("Loading dupe" .. dots, "Trebuchet24", x, y)
    end
end)

net.Receive("SMHLoadDupe", function (len, ply)
    isLoadingDupe = net.ReadBool()
end)

net.Receive("SMHSaveDupe", function (len, ply)
    isSavingDupe = net.ReadBool()
end)