--- @class KeyframeData
local META = {}
META.__index = META

--- @param player Player
--- @param entity Entity
--- @return FrameData
function META:New(player, entity)
    local keyframe = {
        ID = self.NextKeyframeId,
        Entity = entity,
        Frame = -1,
        EaseIn = {},
        EaseOut = {},
        Modifiers = {}
    }
    self.NextKeyframeId = self.NextKeyframeId + 1

    if not self.Players[player] then
        self.Players[player] = {
            Keyframes = {},
            Entities = {},
        }
    end

    self.Players[player].Keyframes[keyframe.ID] = keyframe

    if not self.Players[player].Entities[entity] then
        self.Players[player].Entities[entity] = {}
    end

    table.insert(self.Players[player].Entities[entity], keyframe)

    return keyframe
end

--- @param player Player
--- @param id integer
function META:Delete(player, id)
    if not self.Players[player] or not self.Players[player].Keyframes[id] then
        return
    end

    local keyframe = self.Players[player].Keyframes[id]
    if self.Players[player].Entities[keyframe.Entity] then
        table.RemoveByValue(self.Players[player].Entities[keyframe.Entity], keyframe)
    end
    keyframe.Next = nil
    keyframe.Previous = nil
    self.Players[player].Keyframes[id] = nil
end

--- @type KeyframeData
--- @diagnostic disable-next-line
SMH.KeyframeData = {
    NextKeyframeId = 0,
    Players = {},
}
setmetatable(SMH.KeyframeData, META)
