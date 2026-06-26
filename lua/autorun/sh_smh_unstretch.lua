-- Modified version of the following script for SMH:
-- https://gist.github.com/vlazed/117fdf704c91c48a0bda31b56a8788f6
---@alias PhysObjBoneOffset {[1]: Vector, [2]: Angle}

if not game.SinglePlayer() then
	return
end

if SERVER then
	---@type {[string]: PhysObjBoneOffset[]}
	local physObjToBoneOffsets = {}

	---@param ragdoll Entity
	---@return PhysObjBoneOffset[] | false
	local function getOffsets(ragdoll)
		local model = ragdoll:GetModel()
		if physObjToBoneOffsets[model] then
			return physObjToBoneOffsets[model]
		end

		local temp = ents.Create(ragdoll:GetClass())
		temp:SetModel(ragdoll:GetModel())
		temp:SetPos(vector_origin)
		temp:SetAngles(angle_zero)
		temp:Spawn()
		local offsets = {}

		for i = 0, temp:GetPhysicsObjectCount() - 1 do
			local phys = temp:GetPhysicsObjectNum(i)
			phys:EnableMotion(false)
			phys:EnableCollisions(false)
			phys:EnableGravity(false)
			phys:Sleep()

			local bPos, bAng = temp:GetBonePosition(temp:TranslatePhysBoneToBone(i))
			local pos, ang = WorldToLocal(phys:GetPos(), phys:GetAngles(), bPos, bAng)
			table.insert(offsets, { pos, ang })
		end
		temp:Remove()

		physObjToBoneOffsets[model] = offsets
		return offsets
	end

	---Assuming ragdoll has stretch disabled (flag 32768), set ragdoll back to it's original pose
	---@param ragdoll Entity
	local function unstretch(ragdoll)
		local offsets = getOffsets(ragdoll)
		if not offsets then
			return
		end

		for i = 0, ragdoll:GetPhysicsObjectCount() - 1 do
			local offset = offsets[i + 1]

			local bPos, bAng = ragdoll:GetBonePosition(ragdoll:TranslatePhysBoneToBone(i))
			local pos, ang = LocalToWorld(offset[1], offset[2], bPos, bAng)
			local phys = ragdoll:GetPhysicsObjectNum(i)
			phys:EnableMotion(false)
			phys:Wake()
			phys:SetPos(pos)
			phys:SetAngles(ang)
		end
	end

	---Use Penol's method to unstretch ragdolls, regardless of stretch state
	---@param ragdoll Entity
	local function peakUnstretch(ragdoll)
		if util.NetworkStringToID("RagUnstretch_Client1") == 0 then
			return
		end

		if not ragdoll.UnstretchTable then
			ragdoll.UnstretchTable = { Bones = {} }
		end

		local ent = ents.Create("prop_ragdoll")
		ent:SetModel(rag:GetModel())
		ent:SetPos(rag:GetPos())
		ent:SetAngles(rag:GetAngles())
		ent:SetCollisionGroup(COLLISION_GROUP_WORLD)
		ent:Spawn()
		local PhysObjects = rag:GetPhysicsObjectCount() - 1
		net.Start("RagUnstretch_Client1")
		net.WriteEntity(rag)
		net.WriteEntity(ent)
		net.WriteInt(PhysObjects, 8)
		net.Send(ply)
	end

	util.AddNetworkString("smh_unstretch")
	net.Receive("smh_unstretch", function(len, ply)
		local doPeakUnstretch = net.ReadBool()
		---@type Entity[]
		local ragdolls = net.ReadTable(true)
		for _, ragdoll in ipairs(ragdolls) do
			local success, err = pcall(doPeakUnstretch and peakUnstretch or unstretch, ragdoll)
			if not success then
				ErrorNoHalt(err)
			end
		end
	end)

	return
end

local doPeakUnstretch = CreateClientConVar(
	"smh_unstretch_dopeak",
	"0",
	true,
	false,
	"If set to 1 and Ragdoll Unstretch Tool is installed, use Penol's Unstretch method",
	0,
	1
)

---@param ragdolls Entity[]
local function unstretch(ragdolls)
	net.Start("smh_unstretch")
	net.WriteBool(doPeakUnstretch:GetBool())
	net.WriteTable(ragdolls, true)
	net.SendToServer()
end

concommand.Add("smh_unstretch_picker", function(ply, cmd, args, argStr)
	---@type TraceResult
	local tr = ply:GetEyeTrace()
	local ent = tr.Entity

	if ent:IsRagdoll() then
		unstretch({ ent })
	end
end)

concommand.Add("smh_unstretch_rgm", function(ply, cmd, args, argStr)
	if not RAGDOLLMOVER then
		return
	end

	local ragdoll = RAGDOLLMOVER[Entity(1)].Entity
	unstretch({ ragdoll })
end)

concommand.Add("smh_unstretch", function(ply, cmd, args, argStr)
	if not SMH then
		return
	end

	local entities = SMH.State.Entity
	local ragdolls = {}
	for entity, _ in pairs(entities) do
		if entity:IsRagdoll() then
			table.insert(ragdolls, entity)
		end
	end
	unstretch(ragdolls)
end)

---Dirty thing that ensures that my global is available on the next frame
timer.Simple(0, function()
	SMHEntitySyncFactory("smh_unstretch_sync", "unstretch_smh_sync", function(ent)
		if ent:IsRagdoll() then
			unstretch({ ent })
		end
	end, false)
end)
