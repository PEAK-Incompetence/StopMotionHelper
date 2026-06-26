---@class rgmPlayer
---@field Bone integer
---@field Entity Entity
---@field rgmEntLocks {[Entity] : {[Entity]: {id: number, ent: Entity, poseid: number}}}
---@field rgmAngLocks {[Entity] : {[number]: PhysObj}}
---@field rgmPosLocks {[Entity] : {[number]: PhysObj}}
---@field rgmOffsetTable table

if CLIENT then
	local lastBone
	local enableSync = CreateClientConVar(
		"sync_rgm_to_smh",
		"1",
		true,
		false,
		[[
		When enabled, multiple events will occur: 
		- Selecting a bone in Ragdoll Mover update the `smh_motionpathbone` ConVar. This convar is only available in vlazed's fork of Stop Motion Helper.
		- Upon frame change from SMH, the gizmo will orient and position itself correctly; previously, it would only have the orientation or position of the initial frame 
		- Upon frame change from SMH, entity constraints will be set. Lock offsets can be modified by transforming (positioning or rotating) the entity in Ragdoll Mover. Can be disabled with `sync_rgm_to_smh_locks 0`.
		]],
		0,
		1
	)
	local enableLock = CreateClientConVar(
		"sync_rgm_to_smh_locks",
		"0",
		true,
		false,
		[[
		When enabled, entity constraints will be set. This requires `sync_rgm_to_smh 1`. 
		]],
		0,
		1
	)
	local smhBone = GetConVar("smh_motionpathbone")

	local enabled = enableSync:GetBool()
	cvars.RemoveChangeCallback("sync_rgm_to_smh", "updateBoolean")
	cvars.AddChangeCallback("sync_rgm_to_smh", function(_, _, newValue)
		enabled = tobool(Either(tonumber(newValue) ~= nil, tonumber(newValue) > 0, false))
	end, "updateBoolean")

	local enabled2 = enableLock:GetBool()
	cvars.RemoveChangeCallback("sync_rgm_to_smh_locks", "updateBoolean")
	cvars.AddChangeCallback("sync_rgm_to_smh_locks", function(_, _, newValue)
		enabled2 = tobool(Either(tonumber(newValue) ~= nil, tonumber(newValue) > 0, false))
	end, "updateBoolean")

	hook.Remove("SMH_PostSetFrame", "syncRGMSMHBone")
	hook.Add("SMH_PostSetFrame", "syncRGMSMHBone", function(frame)
		if not enabled then
			return
		end
		smhBone = smhBone or GetConVar("smh_motionpathbone")
		local pl = LocalPlayer()
		---@type rgmPlayer
		---@diagnostic disable-next-line
		local plTable = RAGDOLLMOVER and RAGDOLLMOVER[pl]
		if not plTable or not plTable.Bone or not IsValid(plTable.Entity) then
			return
		end

		local bone = plTable.Bone
		local ent = plTable.Entity

		if lastBone and bone == lastBone then
			return
		end

		smhBone:SetString(ent:GetBoneName(bone))
		lastBone = bone
	end)

	---@diagnostic disable
	---Hack for getting Ragdoll Mover gizmos to update properly with nonphysical bone changes, since this doesn't happen automatically
	---like they usually do with PhysicsObjects.
	---
	---It requires rgmSendBonePos to be a global function in stools/ragdollmover.lua. This is the main hack, unless we can adjust
	---how external bone positions update the gizmo somehow in ragdoll mover itself
	local sendBonePos = rgmSendBonePos
	timer.Simple(0, function()
		sendBonePos = rgmSendBonePos
		if not isfunction(sendBonePos) then
			print("RGM SMH Sync: Failed to synchronize with rgmSendBonePos")
			print("RGM SMH Sync: Make sure to set `local function rgmSendBonePos` to `function rgmSendBonePos`")
		end
	end)
	hook.Remove("SMH_PostSetFrame", "syncRGMSMHBoneFrame")
	hook.Add("SMH_PostSetFrame", "syncRGMSMHBoneFrame", function(frame)
		if not enabled then
			return
		end

		local pl = LocalPlayer()

		local plTable = RAGDOLLMOVER and RAGDOLLMOVER[pl]

		if not plTable or not IsValid(RAGDOLLMOVER[pl].Entity) then
			return
		end

		if isfunction(sendBonePos) then
			sendBonePos(pl, plTable.Entity, plTable.Bone)
		else
			hook.Remove("Think", "syncRGMSMHBoneFrame")
			return
		end
	end)

	-- TODO: Replace below with a dedicated, Ragdoll Mover version which calls the correct functions, without
	-- having to do it all in this script
	hook.Remove("SMH_PostSetFrame", "syncRGMSMHLocks")
	hook.Add("SMH_PostSetFrame", "syncRGMSMHLocks", function()
		if not enabled then
			return
		end
		if not enabled2 then
			return
		end

		if not RAGDOLLMOVER then
			return
		end

		net.Start("RAGDOLLMOVER_SMH_SYNC")
		net.SendToServer()
	end)
else
	print("RGM SMH Sync: Ready to receive signals for offsetting")
	util.AddNetworkString("RAGDOLLMOVER_SMH_SYNC")

	-- Tool is used to get the type of IK type. However, we don't need to calculate iks right now
	local fakeTool = {
		GetClientNumber = function()
			return -1
		end,
	}
	net.Receive("RAGDOLLMOVER_SMH_SYNC", function(len, pl)
		---@type rgmPlayer
		---@diagnostic disable-next-line: undefined-global
		local plTable = RAGDOLLMOVER[pl]
		local parent = plTable.Entity

		if not IsValid(parent) then
			return
		end
		if not istable(plTable.rgmOffsetTable) then
			return
		end

		local physcount = parent:GetPhysicsObjectCount() - 1
		for child, info in pairs(plTable.rgmEntLocks[parent]) do
			---@source https://github.com/vlazed/RagdollMover/blob/c2ea1fa0a9a6eb744b4a7bd3fd24744174323e68/lua/weapons/gmod_tool/stools/ragdollmover.lua#L2565
			local bone = info.id
			local obj = parent:GetPhysicsObjectNum(bone)
			if not IsValid(obj) then
				continue
			end

			---@diagnostic disable-next-line: undefined-global
			local postable = rgm.SetOffsets(
				fakeTool,
				parent,
				plTable.rgmOffsetTable,
				{ b = bone, p = obj:GetPos(), a = obj:GetAngles() },
				plTable.rgmAngLocks,
				plTable.rgmPosLocks
			)

			for i = 0, physcount do
				if postable[i] and postable[i].locked then
					for lockent, bones in pairs(postable[i].locked) do
						for j = 0, lockent:GetPhysicsObjectCount() - 1 do
							if bones[j] then
								local obj = lockent:GetPhysicsObjectNum(j)

								obj:EnableMotion(true)
								obj:Wake()
								obj:SetPos(bones[j].pos)
								obj:SetAngles(bones[j].ang)
								obj:EnableMotion(false)
								obj:Wake()
							end
						end
					end
				end
			end
		end
	end)
end
