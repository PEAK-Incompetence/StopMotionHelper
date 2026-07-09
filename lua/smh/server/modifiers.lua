local MAX_MODIFIER_BITS = 8

---@class ModifierClass
local MODBASE = {}
---@package
MODBASE.__index = MODBASE
MODBASE.Name = "Unnamed"

---@param entity SMHEntity|Player
---@return any
function MODBASE:Save(entity) end
---@param entity SMHEntity
---@param data any
---@param settings Settings?
function MODBASE:Load(entity, data, settings) end
---@param entity Entity
---@param ghost SMHEntity
---@param data any
---@param settings Settings?
function MODBASE:LoadGhost(entity, ghost, data, settings) end
---@param entity SMHEntity
---@param data1 any
---@param data2 any
---@param percentage number
---@param settings Settings?
function MODBASE:LoadBetween(entity, data1, data2, percentage, settings) end
---@param entity SMHEntity
---@param ghost SMHEntity
---@param data1 any
---@param data2 any
---@param percentage number
---@param settings Settings?
function MODBASE:LoadGhostBetween(entity, ghost, data1, data2, percentage, settings) end
---@param data any
---@param origindata any
---@param worldvector Vector
---@param worldangle Angle
---@param offsetpos Vector?
---@param offsetang Angle?
---@return any
function MODBASE:Offset(data, origindata, worldvector, worldangle, offsetpos, offsetang) end
---@param entity SMHEntity
---@param data any
---@param origindata any
---@return any
function MODBASE:OffsetDupe(entity, data, origindata) end

function MODBASE:IsEffect(entity) -- checking if the entity is an effect prop
    if entity:GetClass() == "prop_effect" and IsValid(entity.AttachedEntity) then return true end
    return false
end

---@type {[string]: ModifierClass}
SMH.Modifiers = {}

SMH.ModifierInfo = {}
---@type string[]
SMH.ModifierInfo.Names = {}
---@type {[string]: integer}
SMH.ModifierInfo.Ids = {}

local path = "smh/modifiers/"
local files, dirs = file.Find(path .. "*.lua", "LUA")

local function refreshModifiers()
	SMH.ModifierInfo.Names = {"world"}
	for _, f in pairs(files) do

		_G["MOD"] = setmetatable({}, MODBASE)

		include(path .. f)

		local modName = f:sub(1, -5) 
		SMH.Modifiers[modName] = _G["MOD"]
		table.insert(SMH.ModifierInfo.Names, modName)

		_G["MOD"] = nil

	end

	SMH.ModifierInfo.Ids = table.Flip(SMH.ModifierInfo.Names)
end	

refreshModifiers()

concommand.Add("smh_refreshmodifiers", function(ply)
	refreshModifiers()
	SMH.PlaybackManager.FlushCache(ply)
end, nil, "Update modifier data")