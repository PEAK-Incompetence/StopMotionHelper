---Legacy keyframe getter
---TODO: Make `WalkBetweenKeyframes` behavior the same as `GetBetweenKeyframes` 
---@param keyframes FrameData[]
---@param frame integer
---@param ignoreCurrentFrame boolean
---@param modname Modifiers
---@return FrameData? prevKeyframe
---@return FrameData? nextKeyframe
function SMH.GetBetweenKeyframes(keyframes, frame, ignoreCurrentFrame, modname)
    if ignoreCurrentFrame == nil then
        ignoreCurrentFrame = false
    end

    local prevKeyframe = nil
    local nextKeyframe = nil
    for _, keyframe in ipairs(keyframes) do
        if keyframe.Modifiers[modname] then
            if keyframe.Frame == frame and not ignoreCurrentFrame then
                prevKeyframe = keyframe
                nextKeyframe = keyframe
                break
            elseif keyframe.Frame < frame then
                prevKeyframe = keyframe
            elseif keyframe.Frame > frame then
                nextKeyframe = keyframe
                break
            end
        end
    end


    if not prevKeyframe and not nextKeyframe then
        return nil, nil
    elseif not prevKeyframe then
        prevKeyframe = nextKeyframe
    elseif not nextKeyframe then
        nextKeyframe = prevKeyframe
    end

    return prevKeyframe, nextKeyframe
end

---Playback performant keyframe getter
---@param keyframes FrameData[]
---@param frame integer
---@param ignoreCurrentFrame boolean
---@param modname Modifiers
---@param delta number
---@param start FrameData?
---@return FrameData? prevKeyframe
---@return FrameData? nextKeyframe
function SMH.WalkBetweenKeyframes(keyframes, frame, ignoreCurrentFrame, modname, delta, start)
    if ignoreCurrentFrame == nil then
        ignoreCurrentFrame = false
    end

    local walk = start or keyframes[1]
    local direction = delta < 0 and "Previous" or "Next"

    local prevKeyframe = nil
    local nextKeyframe = nil
    while walk do
        if walk.Modifiers[modname] then
            if walk.Frame == frame and not ignoreCurrentFrame then
                prevKeyframe = walk
                nextKeyframe = walk
                break
            elseif walk.Frame < frame then
                prevKeyframe = walk
                if delta < 0 then
                    break
                end
            elseif walk.Frame > frame then
                nextKeyframe = walk
                if delta >= 0 then
                    break
                end
            end
        end
        walk = walk[direction]
    end

    if not prevKeyframe and not nextKeyframe then
        return nil, nil
    elseif not prevKeyframe then
        prevKeyframe = nextKeyframe
    elseif not nextKeyframe then
        nextKeyframe = prevKeyframe
    end

    return prevKeyframe, nextKeyframe
end

local GetBetweenKeyframes = SMH.GetBetweenKeyframes
local WalkBetweenKeyframes = SMH.WalkBetweenKeyframes

---@param keyframes FrameData[]
---@param frame integer
---@param ignoreCurrentFrame boolean
---@param modname Modifiers
---@param delta number
---@return FrameData? prevKeyframe
---@return FrameData? nextKeyframe
---@return integer
function SMH.GetClosestKeyframes(keyframes, frame, ignoreCurrentFrame, modname, delta)
    local prevKeyframe, nextKeyframe = WalkBetweenKeyframes(keyframes, frame, ignoreCurrentFrame, modname, delta)

    if not prevKeyframe and not nextKeyframe then
        return nil, nil, 0
    end

    ---@cast prevKeyframe FrameData
    ---@cast nextKeyframe FrameData

    local lerpMultiplier = 0
    if prevKeyframe.Frame ~= nextKeyframe.Frame then
        lerpMultiplier = (frame - prevKeyframe.Frame) / (nextKeyframe.Frame - prevKeyframe.Frame)
        lerpMultiplier = math.EaseInOut(lerpMultiplier, prevKeyframe.EaseOut[modname], nextKeyframe.EaseIn[modname])
    end

    return prevKeyframe, nextKeyframe, lerpMultiplier
end

---@param player Player
---@param entity Entity
function SMH.SortKeyframes(player, entity)
    local keyframes = SMH.KeyframeData.Players[player].Entities[entity]
    if keyframes then
        table.sort(keyframes, function (a, b)
            ---@cast a FrameData
            ---@cast b FrameData
            
            a.Previous = nil
            a.Next = nil
            b.Previous = nil
            b.Next = nil
            return a.Frame < b.Frame
        end)
    end

    ---@type FrameData
    local prevKeyframe
    for i, keyframe in ipairs(keyframes) do
        keyframe.Previous = prevKeyframe
        if prevKeyframe then
            prevKeyframe.Next = keyframe
        end
        prevKeyframe = keyframe
    end
end

---@class KeyframeData
local META = {}
META.__index = META

---@param player Player
---@param entity Entity
---@return FrameData
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

---@param player Player
---@param id integer
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

---@type KeyframeData
---@diagnostic disable-next-line
SMH.KeyframeData = {
    NextKeyframeId = 0,
    Players = {},
}
setmetatable(SMH.KeyframeData, META)
