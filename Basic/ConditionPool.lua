--[[
    @desc: 数据配档中配置条件的具体实现
    author:陈德怀
    time:2018-07-11 17:25:25
]]
local CEvent = CS.CEvent
local SystemOpenSystem = CS.SystemOpenSystem
local base = require "core.Object"

--@SuperType [core.Object#CObject]
local ConditionPool = class(base)

local function IsSystemOpen(self, envParams, system_open_type, is_show_hint)
    --@RefType [luaIde#CS.SystemOpenSystem]
    local systemOpen = self:GetSingle(typeof(SystemOpenSystem))
    if (is_show_hint == 1) then
        is_show_hint = true
    else
        is_show_hint = false
    end
    local isopen = systemOpen:isSystemOpened(system_open_type, is_show_hint)
    if (isopen) then
        return 1
    else
        return 0
    end
end

--@desc 是否加入仙盟
local function IsHaveGroup(self, envParams)
    if (CGlobal.gamemgr.groupSystem.SelfGroup == nil) then
        local csevent = CEvent.Message.HintMessage(CErrorCode.Misc.HaveNoGroup)
        self:FireEvent(csevent)
        return 0
    end

    return 1
end

--@desc 能否使用boss刷新卡
local function CanUseBossCard(self, envParams, cardType)
    local curMapType = CGlobal.gamemgr.world.ref.Type
    if
        cardType == 0 and
            (curMapType == MapType.WorldBoss or curMapType == MapType.BossHome or curMapType == MapType.BossIsland)
     then
        --通用（世界boss，boss之家，神兽岛）
        return 1
    elseif cardType == 1 and curMapType == MapType.WorldBoss then
        --世界boss
        return 1
    elseif cardType == 2 and curMapType == MapType.BossHome then
        --boss之家
        return 1
    elseif cardType == 3 and curMapType == MapType.BossIsland then
        --神兽岛
        return 1
    elseif cardType == 4 and curMapType == MapType.BossArea then
        --蛮荒之地
        return 1
    else
        local csevent = CEvent.Message.HintMessage(CErrorCode.Common.MapCannotUse)
        self:FireEvent(csevent)
        return 0
    end
end

function ConditionPool:OnInit()
    --@RefType [StringEventParse.ConditionParseSystem#ConditionParseSystem]
    self.mrg:Add(
        "IsSystemOpen",
        function(...)
            return IsSystemOpen(self, ...)
        end
    )
    self.mrg:Add(
        "IsHaveGroup",
        function(...)
            return IsHaveGroup(self, ...)
        end
    )
    self.mrg:Add(
        "CanUseBossCard",
        function(...)
            return CanUseBossCard(self, ...)
        end
    )
end

function ConditionPool:OnFini()
end

return ConditionPool
