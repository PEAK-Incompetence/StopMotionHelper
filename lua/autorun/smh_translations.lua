-- Bone translation functions, so we can change their functionality here in case the original ones fuck up even more

local opt = SMH and SMH.Optimizations
local getModel = opt and opt.EntityGetModel
hook.Add("PostSMHLoaded", "SMHTranslationsGetOptimizations", function(smh)
	opt = SMH.Optimizations
	getModel = opt.EntityGetModel
end)

local MAX_BONE_COUNT = 255

local staticProps = {}
local function isStaticProp(entity)
	local model = entity:GetModel()
	local result = staticProps[model]
	if result ~= nil then
		return result
	end
	local modelInfo = util.GetModelInfo(model)
	result = modelInfo and modelInfo.StaticProp
	staticProps[model] = result

	return result
end

--- @type {[string]: {[integer]: integer}}
local boneToPhysMap = {}

--- @param ent Entity Entity to translate bone
--- @param bone integer Bone id
--- @return integer physBone Physics object id
function SMH.BoneToPhysBone(ent, bone)
	local model = getModel(ent)
	if boneToPhysMap[model] and boneToPhysMap[model][bone] then
		return boneToPhysMap[model][bone]
	else		
		boneToPhysMap[model] = boneToPhysMap[model] or {}
		if isStaticProp(ent) or ent:GetPhysicsObjectCount() == 1 then
			boneToPhysMap[model][bone] = 0
			return 0
		end
		for i = 0, ent:GetPhysicsObjectCount() - 1 do
			local b = ent:TranslatePhysBoneToBone(i)
			if bone == b then
				boneToPhysMap[model][b] = i
				return i
			end
		end
		boneToPhysMap[model][bone] = -1
		return -1
	end
end
local BoneToPhysBone = SMH.BoneToPhysBone

--- @param ent Entity Entity to translate bone
--- @param bone integer Physics object id
--- @return integer b Bone id
function SMH.PhysBoneToBone(ent, bone)
	return ent:TranslatePhysBoneToBone(bone)
end
local PhysBoneToBone = SMH.PhysBoneToBone

--- @type {[string]: {[integer]: integer}}
local bonePhysBoneParents = {}

--- @param entity Entity Entity to translate bone
--- @param bone integer Bone id
--- @return integer physBone Physics object id
function SMH.GetPhysBoneParentFromBone(entity, bone)
	local model = getModel(entity)
	if bonePhysBoneParents[model] and bonePhysBoneParents[model][bone] then
		return bonePhysBoneParents[model][bone]
	end	
	bonePhysBoneParents[model] = bonePhysBoneParents[model] or {}
	local b = bone
	local i = 1
	local bones = {}
	while true do
		b = entity:GetBoneParent(b)
		local parent = BoneToPhysBone(entity, b)
		if parent >= 0 and parent ~= bone then
			bonePhysBoneParents[model][bone] = parent
			for c = 1, #bones do
				bonePhysBoneParents[model][c] = parent
			end
			return parent
		end
		table.insert(bones, b)
		i = i + 1
		if i > MAX_BONE_COUNT then --We've gone through all possible bones, so we get out.
			break
		end
	end
	bonePhysBoneParents[model][bone] = -1
	return -1
end
local GetPhysBoneParentFromBone = SMH.GetPhysBoneParentFromBone

--- @type {[string]: {[integer]: integer}}
local physBoneParents = {}

--- @param entity Entity Entity to translate bone
--- @param bone integer Physics object id
--- @return integer physBone Parent physics object id or -1 if it can't find it
function SMH.GetPhysBoneParent(entity, bone)
	local model = getModel(entity)
	if physBoneParents[model] and physBoneParents[model][bone] then
		return physBoneParents[model][bone]
	end
	physBoneParents[model] = physBoneParents[model] or {}
	local b = PhysBoneToBone(entity, bone)
	local i = 1
	while true do
		b = entity:GetBoneParent(b)
		local parent = BoneToPhysBone(entity, b)
		if parent >= 0 and parent ~= bone then
			physBoneParents[model][bone] = parent
			return parent
		end
		i = i + 1
		if i > MAX_BONE_COUNT then --We've gone through all possible bones, so we get out.
			break
		end
	end
	physBoneParents[model][bone] = -1
	return -1
end
local GetPhysBoneParent = SMH.GetPhysBoneParent