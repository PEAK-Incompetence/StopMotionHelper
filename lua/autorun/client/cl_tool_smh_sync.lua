---Generate a think hook that updates an entity when the SMH state changes
---@param convar string
---@param hookName string
---@param callback fun(ent: SMHEntity)
function SMHEntitySyncFactory(convar, hookName, callback)
	local enableSync = CreateClientConVar(convar, "1", true, false, nil, 0, 1)
	local enabled = enableSync:GetBool()
	cvars.RemoveChangeCallback(convar, "updateBoolean")
	cvars.AddChangeCallback(convar, function(_, _, newValue)
		enabled = tobool(Either(tonumber(newValue) ~= nil, tonumber(newValue) > 0, false))
	end, "updateBoolean")

	hook.Remove("SMH_PostSetFrame", hookName)
	hook.Add("SMH_PostSetFrame", hookName, function(frame)
		if enabled then
			local ents = SMH.State.Entity
			callback(next(ents))
		end
	end)
end

local entitySyncFactory = SMHEntitySyncFactory

-- On frame change, set each slider on the faceposer to correspond to a flex
entitySyncFactory("sync_smh_to_facepose", "syncFacePoseSMH", function(ent)
	local n = ent:GetFlexNum()
	if n == 0 then
		return
	end
	if not ent:HasFlexManipulatior() then
		return
	end
	for i = 0, n - 1 do
		RunConsoleCommand("faceposer_flex" .. i, ent:GetNW2Float("faceposer_flex" .. i))
	end
end)

-- On frame change, set the eye on the finger poser UI
entitySyncFactory("sync_smh_to_eyepose", "syncEyePoseSMH", function(ent)
	---@type Vector
	local eyeTarget = ent:GetNW2Vector("eyeposer_target")

	local attachment = ent:GetAttachment(ent:LookupAttachment("eyes"))
	if attachment == 0 then
		return
	end

	local s = math.Clamp(GetConVar("eyeposer_strabismus"):GetFloat(), -1, 1)
	local distance = 1000

	if s < 0 then
		s = math.Remap(s, -1, 0, 0, 1)
		distance = distance * math.pow(10000, s - 1)
	elseif s > 0 then
		distance = distance * -math.pow(10000, -s)
	end

	local angle = (eyeTarget / distance):Angle()
	angle:Normalize()
	angle:Div(45)
	local y, x = math.Remap(angle[1], -1, 1, 0, 1), math.Remap(angle[2], -1, 1, 0, 1)

	RunConsoleCommand("eyeposer_x", x)
	RunConsoleCommand("eyeposer_y", y)
end)

local VarsOnHand = 15

---Returns true if it has TF2 hands
---@param pEntity Entity
---@return boolean
local function HasTF2Hands(pEntity)
	return pEntity:LookupBone("bip_hand_L") ~= nil
end

-- On frame change, set the positions of the fingers on the finger poser UI
entitySyncFactory("sync_smh_to_fingerpose", "syncFingerPoseSMH", function(ent)
	local owner = LocalPlayer()
	local tool = owner:GetActiveWeapon()
	if tool:GetClass() ~= "gmod_tool" then
		return
	end

	-- FIXME: This isn't consistent for most ragdolls
	local bTF2 = HasTF2Hands(ent)
	for i = 0, VarsOnHand - 1 do
		local Ang = ent:GetNW2Angle(Format("finger_%s", i))

		if bTF2 then
			if i < 3 then
				RunConsoleCommand(Format("finger_%s", i), Format("%.1f %.1f", Ang.r, Ang.y))
			else
				RunConsoleCommand(Format("finger_%s", i), Format("%.1f %.1f", Ang.y, -Ang.r))
			end
		else
			if i < 3 then
				RunConsoleCommand(Format("finger_%s", i), Format("%.1f %.1f", Ang.y, Ang.p))
			else
				RunConsoleCommand(Format("finger_%s", i), Format("%.1f %.1f", Ang.p, Ang.y))
			end
		end
	end
end)
