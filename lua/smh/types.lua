--- @meta

-- Miscellaneous Types

--- @alias Set<T> {[T]: boolean}
--- @alias ServerReceiver fun(msgLength: integer, player: Player)
--- @alias ClientReceiver fun(msgLength: integer, player: Player)
--- @generic T
--- @alias Falsy<T> T|false

--- @class Wave
--- @field Fraction number
--- @field Left number
--- @field Right number

-- SMH Types

--- @alias EntitySet Set<Entity>

--- @class NewState
--- @field Entity EntitySet?
--- @field Frame integer?
--- @field Timeline integer?
--- @field PlaybackRate integer?
--- @field PlaybackLength integer?
--- @field TimeStamp number?

--- @class State
--- @field Entity EntitySet
--- @field Frame integer
--- @field Timeline integer
--- @field PlaybackRate integer
--- @field PlaybackLength integer
--- @field TimeStamp number

--- @class AudioClip
--- @field ID integer
--- @field Path string
--- @field AudioChannel IGModAudioChannel
--- @field Frame integer
--- @field Duration number
--- @field BaseDuration number
--- @field StartTime integer
--- @field Waveform Wave[]

--- @class AudioClipData
--- @field AudioClips {[integer]: AudioClip}
--- @field NextKeyframeId integer
--- @field Delete fun(self: AudioClipData, id: number)
--- @field New fun(self: AudioClipData, station: IGModAudioChannel, path: string): AudioClip
--- @field DeleteAll fun(self: AudioClipData)

--- @class Settings
--- @field FreezeAll boolean
--- @field LocalizePhysBones boolean
--- @field IgnorePhysBones boolean
--- @field GhostPrevFrame boolean
--- @field GhostNextFrame boolean
--- @field GhostXRay boolean
--- @field GhostAllEntities boolean
--- @field GhostTransparency number
--- @field OnionSkin boolean
--- @field TweenDisable boolean
--- @field SmoothPlayback boolean
--- @field EnableWorld boolean

--- ### Structure
--- 
--- ```
--- {
---  [Entity]: {
---      [Modifier]: {
---          [Frame]: {
---              [1]: PrevFrame
---              [2]: NextFrame
---              [3]: LerpMultiplier
---          }
---      }
---  }
--- }
--- ```
--- 
--- @alias PlaybackCache {[Player]: {[Entity]: {[string]: {[number]: {[1]: FrameData, [2]: FrameData, [3]: number}}}}}
--- @alias ModifierCache {[Player]: {[Entity]: {[Modifiers]: ModifierClass}}}

--- @class Playback
--- @field StartFrame integer
--- @field EndFrame integer
--- @field PlaybackRate integer
--- @field CurrentFrame integer
--- @field PrevFrame integer
--- @field Timer number
--- @field Settings Settings

--- @class SMHEntity: Entity
--- @field SMHGhost boolean Is it a ghost?
--- @field Entity Entity If the entity is an SMHGhost, select the pointed entity
--- @field EyeVec Vector
--- @field GetEyeVector fun(self: SMHEntity): Vector Returns where the entity is looking
--- @field AttachedEntity SMHEntity
--- @field Frame integer
--- @field Physbones boolean
--- @field RagdollWeightData number[]
--- @field smh_OldDoNotDuplicate boolean
--- @field smh_RenderBoundsCacheMinOG Vector
--- @field smh_RenderBoundsCacheMaxOG Vector
--- @field smh_RenderBoundsCacheModelScale number

--- @class BufferDatum
--- @field Ids integer[]
--- @field UpdateData table?
--- @field Frames table?
--- @field Timeline integer

--- @alias Modifiers
--- | "advcamera"
--- | "advlight"
--- | "bodygroup"
--- | "bones"
--- | "color"
--- | "eyetarget"
--- | "flex"
--- | "modelscale"
--- | "physbones"
--- | "poseparameter"
--- | "position"
--- | "skin"
--- | "softlamps"
--- | "ragdollpuppeteer"
--- | "world"
--- All known fields controlled by SMH, including the custom ragdollpuppeteer modifier

--- @class TimelineMod An array of timeline modifiers
--- @field KeyColor Color

--- @alias ModifierNames table<integer, Modifiers>

--- @class FramePose A struct of the entity's pose at an SMH frame and metadata related to it
--- @field Ang Angle
--- @field Pos Vector
--- @field LocalAng Angle?
--- @field LocalPos Vector?
--- @field RootAng Angle?
--- @field RootPos Vector?
--- @field Moveable boolean?
--- @field Scale Vector

--- @class ColorPose A struct of the entity's color at an SMH frame
--- @field Color Color

--- @class ModifierClass
--- @field Name string
--- @field Ghost boolean

--- @class Modifier A struct of the entity's modifiers
--- @field physbones FramePose[]?
--- @field bones FramePose[]?
--- @field color ColorPose?
--- @field Console string?
--- @field Push string?
--- @field Release string?
--- @field Pos Vector?
--- @field Ang Angle?

--- @class SerializedFrameData The data shown in the SMH Timeline for the selected entity
--- @field EntityData Modifier
--- @field EaseIn number|table<string, number> If stored as a number, then this is a legacy SMH save file, otherwise this is an new SMH save file.
--- @field EaseOut number|table<string, number> If stored as a number, then this is an legacy SMH save file, otherwise this is an new SMH save file.
--- @field Modifier Modifiers Legacy SMH save file feature
--- @field Position number

--- @class FrameData The data shown in the SMH Timeline for the selected entity
--- @field ID integer
--- @field Entity SMHEntity
--- @field EaseIn number|table<string, number> If stored as a number, then this is a legacy SMH save file, otherwise this is an new SMH save file.
--- @field EaseOut number|table<string, number> If stored as a number, then this is an legacy SMH save file, otherwise this is an new SMH save file.
--- @field Modifiers table<Modifiers, Modifier> Legacy SMH save file feature
--- @field Frame number
--- @field Previous FrameData?
--- @field Next FrameData?

--- @alias TimelineMods TimelineMod[]

--- @class TimelineSetting
--- @field Timelines integer
--- @field TimelineMods TimelineMods

--- @class Properties The animation properties of the entity
--- @field TimelineMods TimelineMods? An array of timeline modifiers
--- @field Class string? The entity class
--- @field Timelines number? The count of timelines
--- @field Name string? The unique name of the entity, different from the model name
--- @field Model string? The model path of the entity
--- @field IsWorld boolean?

--- @class EntityProperties
--- @field Name string
--- @field Class string?
--- @field Model string?

--- @class PlayerProperties
--- @field Entities {[Entity]: EntityProperties}
--- @field TimelineSetting TimelineSetting

--- @class PropertiesManager
--- @field Players {[Player]: PlayerProperties}

--- @class Data The animation data for each entity
--- @field Frames SerializedFrameData[] An array of the data seen in the SMH timeline
--- @field Model string The model path of the entity
--- @field Properties Properties The animation properties of the entity
--- @field IsWorld boolean?
--- @field Settings Settings

--- @class PackageData SMH Package data
--- @field save string The path of the save file, with respect to smh/
--- @field name string The unique name of the entity referenced in the save file
--- @field isDupe boolean A field set from an overridden duplicator.Copy function, so dupes will offset while saves don't

--- @class SMHFile The text file containing SMH animation data
--- @field Map string The map where the animation takes place
--- @field Entities Data[] The animation data for each entity

--- @alias Entities table<integer, SMHEntity|Player>

--- @class GhostDatum
--- @field Entity SMHEntity[]
--- @field Ghosts SMHEntity[]
--- @field Nodes table
--- @field PreviousName string
--- @field LastEntity Entity
--- @field Updated boolean
--- @field LastTween boolean

--- @alias GhostSettings {[Player]: Settings}
--- @alias SpawnGhost {[Player]: SMHEntity}
--- @alias SpawnGhostData {[Player]: table}

--- @alias GhostData table<Player, GhostDatum>

--- @class Pose
--- @field Pos Vector
--- @field Ang Angle
--- @field LocalPos Vector
--- @field LocalAng Angle
--- @field Parent integer
--- @field IsPhysBone boolean

--- @alias PoseTree {[integer]: Pose}
--- @alias PoseTrees {[string]: PoseTree}

--- @class PlayerData
--- @field Keyframes FrameData[]
--- @field Entities {[SMHEntity]: FrameData[]}

--- @class KeyframeData
--- @field Players {[Player]: PlayerData}
--- @field NextKeyframeId integer

-- UI

--- @class Node
--- @field Pos Vector
--- @field Ang Angle
--- @field Frame integer

--- @alias NetworkedNode {[1]: integer, [2]: Vector, [3]: Angle}

--- @alias SerializedNode {[1]: Vector, [2]: Angle}

--- @class SMHWorldClicker: SMHWorldClickerPanel
--- @field MainMenu SMHMenu
--- @field PhysRecorder SMHPhysRecord
--- @field Settings SMHSettings
--- @field SpawnMenu SMHSpawn
--- @field AudioClipToolsMenu SMHAudioClipTools

--- @class SMHNumberWang: DNumberWang Extension of DNumberWang with customizable step and increment or decrement fields
--- @field Step number
--- @field Up number
--- @field Down number

--- @alias FramePointerDictionary {[integer]: SMHFramePointer}

--- @class EasingData
--- @field EaseIn number
--- @field EaseOut number
