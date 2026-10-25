-- Modified version of the following script for SMH:
-- https://gist.github.com/vlazed/117fdf704c91c48a0bda31b56a8788f6
--- @alias PhysObjBoneOffset {[1]: Vector, [2]: Angle}
--- @alias PhysObjParentOffset {[1]: Vector, [2]: Angle, [3]: integer}

if SERVER then
	--- For unstretching physics bones back to their bone positions
	--- @type {[string]: PhysObjBoneOffset[]}
	local physObjToBoneOffsets = {}
	--- @type {[string]: PhysObjParentOffset[]}
	local physObjToParentOffsets = {}

	-- TODO: If we ever expand this, maybe put this in another
	-- module, or make this user specified
	local problematicBones = {
		"prp_",
		"dogtag"
	}

	--- @param ragdoll Entity
	--- @return PhysObjBoneOffset[] | false
	local function getOffsets(ragdoll, ply)
		local model = ragdoll:GetModel()
		if physObjToBoneOffsets[model] then
			return physObjToBoneOffsets[model], physObjToParentOffsets[model]
		end

		local temp = ents.Create(ragdoll:GetClass())
		temp:SetModel(ragdoll:GetModel())
		temp:SetPos(vector_origin)
		temp:SetAngles(angle_zero)
		temp:Spawn()

		local offsets = {}
		--- @type PhysObjParentOffset[]
		local parentOffsets = {}
		local proportionOffsets = {}
		local referencePhysPoses = {}
		local temp2 = ents.Create("prop_dynamic")
		temp2:SetModel(ragdoll:GetModel())
		temp2:Spawn()

		-- Reference to proportion offset pass
		for i = 0, temp:GetPhysicsObjectCount() - 1 do
			local phys = temp:GetPhysicsObjectNum(i)
			phys:EnableMotion(false)
			phys:EnableCollisions(false)
			phys:EnableGravity(false)
			phys:Sleep()

			local b = temp:TranslatePhysBoneToBone(i)
			local m1 = temp:GetBoneMatrix(b)
			local m2 = temp2:GetBoneMatrix(b)
			
			local pos1, ang1 = phys:GetPos(), phys:GetAngles()
			local pos2, ang2 = temp2:GetBonePosition(b)

			local bPos = m1 and m1:GetTranslation()
			pos2 = m2 and m2:GetTranslation() or pos2

			local bAng = m1 and m1:GetAngles()
			ang2 = m2 and m2:GetAngles() or ang2

			local offsetPos, offsetAng = WorldToLocal(pos2, ang2, bPos, bAng)
			local pos, ang = WorldToLocal(pos1, ang1, pos2, ang2)
			pos, ang = LocalToWorld(pos, ang, offsetPos, offsetAng)

			proportionOffsets[i] = {pos, ang}
			local referencePos, referenceAng = LocalToWorld(pos, ang, pos2, ang2)
			referencePhysPoses[i] = {pos2, ang2}
		end
		temp2:Remove()

		for i = 0, temp:GetPhysicsObjectCount() - 1 do
			local phys = temp:GetPhysicsObjectNum(i)
			phys:EnableMotion(false)
			phys:EnableCollisions(false)
			phys:EnableGravity(false)
			phys:Sleep()

			local b = temp:TranslatePhysBoneToBone(i)
			local m = temp:GetBoneMatrix(b)

			local pos, ang = temp:GetBonePosition(b)
			local bPos, bAng = m and m:GetTranslation() or pos, m and m:GetAngles() or ang
			if proportionOffsets[i] then
				bPos, bAng = LocalToWorld(proportionOffsets[i][1], proportionOffsets[i][2], bPos, bAng)
			end
			local pos, ang = WorldToLocal(phys:GetPos(), phys:GetAngles(), bPos, bAng)
			table.insert(offsets, { pos, ang })
		end

		for i = 0, temp:GetPhysicsObjectCount() - 1 do
			local referencePose = referencePhysPoses[i]
			local parent = SMH.GetPhysBoneParent(temp, i)
			local parentPose = parent >= 0 and referencePhysPoses[parent]
			local basePos, baseAng
			if parentPose then
				basePos, baseAng = parentPose[1], parentPose[2]
			else
				basePos, baseAng = temp:GetPos(), temp:GetAngles()
			end
			local pos, ang = WorldToLocal(referencePose[1], referencePose[2], basePos, baseAng)
			parentOffsets[i + 1] = {pos, ang, parent}
		end

		temp:Remove()

		physObjToBoneOffsets[model] = offsets
		physObjToParentOffsets[model] = parentOffsets

		net.Start("smh_unstretch_bones")
		local prpPhysBones = {}
		local prpPhysBoneParents = {}
		for i = 0, ragdoll:GetPhysicsObjectCount() - 1 do
			local boneName = ragdoll:GetBoneName(ragdoll:TranslatePhysBoneToBone(i))
			for _, name in ipairs(problematicBones) do			
				if string.find(boneName, name) then
					table.insert(prpPhysBones, i)
					local parent = SMH.GetPhysBoneParent(ragdoll, i)
					prpPhysBoneParents[i] = parent
					break
				end
			end
		end
		net.WriteEntity(ragdoll)
		net.WriteTable(prpPhysBones, true)
		net.WriteTable(prpPhysBoneParents)
		net.Send(ply)

		return offsets, parentOffsets
	end

	--- Restore physics bones relative to their parent physics bones.
	--- @param ragdoll Entity
	local function parentRelativeUnstretch(ragdoll, offsets)
		if not IsValid(ragdoll) then
			return
		end

		local applied = {}
		local function applyPhysicsBone(i)
			if applied[i] then
				return
			end
			applied[i] = true

			local offset = offsets[i + 1]
			if not offset then
				return
			end

			local parent = offset[3]
			if parent < 0 then
				return
			end

			local basePos, baseAng = ragdoll:GetPos(), ragdoll:GetAngles()
			applyPhysicsBone(parent)
			local parentPhys = ragdoll:GetPhysicsObjectNum(parent)
			if IsValid(parentPhys) then
				basePos, baseAng = parentPhys:GetPos(), parentPhys:GetAngles()
			end

			local phys = ragdoll:GetPhysicsObjectNum(i)
			if IsValid(phys) then
				local pos, ang = LocalToWorld(offset[1], offset[2], basePos, baseAng)
				phys:EnableMotion(false)
				phys:Wake()
				phys:SetPos(pos)
			end
		end

		for i = 0, ragdoll:GetPhysicsObjectCount() - 1 do
			local p = SMH.GetPhysBoneParent(ragdoll, i)
			if p >= 0 then
				applyPhysicsBone(i)
			end
		end
	end

	local function relativeUnstretch(ragdoll, offsets)
		for i = 0, ragdoll:GetPhysicsObjectCount() - 1 do
			local offset = offsets[i + 1]

			local b = ragdoll:TranslatePhysBoneToBone(i)
			if SMH.GetPhysBoneParent(ragdoll, i) >= 0 then
				local bPos, bAng = ragdoll:GetBonePosition(b)
				local pos, ang = LocalToWorld(offset[1], offset[2], bPos, bAng)
				local phys = ragdoll:GetPhysicsObjectNum(i)
				phys:EnableMotion(false)
				phys:Wake()
				phys:SetPos(pos)
				phys:SetAngles(ang)
			end
		end
	end

	--- @param ragdoll Entity
	local function unstretch(ragdoll, ply)
		timer.Simple(0.1, function()
			local offsets, parentOffsets = getOffsets(ragdoll, ply)
			if not offsets then
				return
			end

			if ragdoll.ClassOverride == "prop_resizedragdoll_physparent" then
				local _, ent = next(ragdoll.PhysObjEnts)
				if IsValid(ent) then
					-- Activate Ragdoll Resizer's unstretching: it unstretches over ticks
					ent.StopMovingOnceFrozen = 8
				end
				return
			end
			parentRelativeUnstretch(ragdoll, parentOffsets)
			relativeUnstretch(ragdoll, offsets)
		end)
	end

	local colorAlpha = Color(0, 0, 0, 1)

	--- Use Penol's method to unstretch ragdolls, regardless of stretch state
	--- @param ragdoll Entity
	local function peakUnstretch(ragdoll, ply)
		if util.NetworkStringToID("RagUnstretch_Client1") == 0 then
			return
		end

		if not ragdoll.UnstretchTable then
			ragdoll.UnstretchTable = { Bones = {} }
		end

		local ent = ents.Create("prop_ragdoll")
		ent:SetModel(ragdoll:GetModel())
		ent:SetPos(ragdoll:GetPos())
		ent:SetAngles(ragdoll:GetAngles())
		ent:SetMaterial("null")
		-- If we set the alpha to completely 0, then prp_* bone transforms becomes unavailable.
		-- So we need the alpha to be around 1. This reduces the ragdoll shadow.  
		ent:SetColor(colorAlpha)
		ent:SetRenderMode(RENDERMODE_TRANSCOLOR)
		ent:SetCollisionGroup(COLLISION_GROUP_WORLD)
		ent:Spawn()
		local PhysObjects = ragdoll:GetPhysicsObjectCount() - 1
		---@diagnostic disable-next-line: gmod-net-missing-network-counterpart, gmod-unknown-net-message
		net.Start("RagUnstretch_Client1")
		net.WriteEntity(ragdoll)
		net.WriteEntity(ent)
		net.WriteInt(PhysObjects, 8)
		net.Send(ply)
	end

	util.AddNetworkString("smh_unstretch")
	net.Receive("smh_unstretch", function(len, ply)
		local doPeakUnstretch = net.ReadBool()
		--- @type Entity[]
		local ragdolls = net.ReadTable(true)
		for _, ragdoll in ipairs(ragdolls) do
			local success, err = pcall(doPeakUnstretch and peakUnstretch or unstretch, ragdoll, ply)
			if not success then
				ErrorNoHalt(err)
			end
		end
	end)

	util.AddNetworkString("smh_unstretch_bones")
	net.Receive("smh_unstretch_bones", function(len, ply)
		-- We run this net message once
		local entity = net.ReadEntity()
		local model = entity:GetModel()
		local bones = net.ReadUInt(5)
		for _ = 1, bones do
			local phys = net.ReadUInt(5)
			local parent = net.ReadUInt(5)
			local matrix = net.ReadMatrix()
			physObjToParentOffsets[model][phys + 1] = {matrix:GetTranslation(), matrix:GetAngles(), parent}
		end
	end)

	return
end

net.Receive("smh_unstretch_bones", function(len)
	local entity = net.ReadEntity()

	local prpPhysBones = net.ReadTable(true)
	local prpPhysBoneParents = net.ReadTable()

	local temp = ClientsideModel(entity:GetModel())
	temp:SetupBones()
	temp:InvalidateBoneCache()
	net.Start("smh_unstretch_bones")
	net.WriteEntity(entity)
	net.WriteUInt(#prpPhysBones, 5)
	pcall(function()
		for _, phys in ipairs(prpPhysBones) do
			local parent = prpPhysBoneParents[phys]
			local bone = temp:TranslatePhysBoneToBone(phys)
			local boneParent = temp:TranslatePhysBoneToBone(parent)

			local childMatrix = temp:GetBoneMatrix(bone)
			local parentMatrix = temp:GetBoneMatrix(boneParent)

			net.WriteUInt(phys, 5)
			net.WriteUInt(parent, 5)
			-- Send local matrix
			net.WriteMatrix(parentMatrix:GetInverse() * childMatrix)
		end
	end)
	net.SendToServer()
	temp:Remove()
end)

local doPeakUnstretch = SMH.ConVars.Create(
	"smh_unstretch_dopeak",
	"0",
	false,
	"If set to 1 and Ragdoll Unstretch Tool is installed, use Penol's Unstretch method",
	TYPE_BOOL
)

--- @param ragdolls Entity[]
local function unstretch(ragdolls)
	if not SMH.State.AllowUnstretch then
		return
	end

	net.Start("smh_unstretch")
	net.WriteBool(doPeakUnstretch:GetBool())
	net.WriteTable(ragdolls, true)
	net.SendToServer()
end

concommand.Add("smh_unstretch_picker", function(ply, cmd, args, argStr)
	--- @type TraceResult
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
	if IsValid(ragdoll) then
		unstretch({ ragdoll }) ---@diagnostic disable-line: param-type-mismatch
	end
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

local ragdollClass = {
	prop_ragdoll = true,
	prop_resizedragdoll_physparent = true
}

--- Dirty thing that ensures that my global (SMHEntitySyncFactory) is available on the next frame
timer.Simple(0, function()
	SMHEntitySyncFactory("smh_unstretch_sync", "unstretch_smh_sync", function(ent)
		if ragdollClass[ent:GetClass()] then
			unstretch({ ent })
		end
	end, false, "On frame change, unstretch the selected SMH entity. YMMV for your model. If you experience bugs, report them with a (Workshop) link model you are trying to unstretch")
end)
