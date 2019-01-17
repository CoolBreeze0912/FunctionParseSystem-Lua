--[[
    @desc: 数据配档中配置事件的具体实现
    author:陈德怀
    time:2018-07-11 17:25:25
]]
local base = require "core.Object"
local StringUtil = require("util.StringUtil")
local CReferenceHelper = require("helper.CReferenceHelper")
local CEvent = CS.CEvent

--@SuperType [core.Object#CObject]
local EventPool = class("EventPool",base)

local function ShowWindow(self,envParams,parameters)
    local winname = parameters[1]
    table.remove( parameters,1 )

    -- local pars = ""
    -- if(#parameters >= 1) then 
    --     for i=1,#parameters do
    --         pars = pars..","..parameters[i]
    --     end
    -- end

    -- local eventstr = string.format("ShowWindow('%s')",winname)
    -- if(not StringUtil.IsNilOrEmpty(pars)) then
    --     eventstr = string.format("ShowWindow('%s'%s)",winname,pars)
    -- end
    -- cprint.LogWarning(eventstr)
    -- CS.EventParser.Instance:Parse(eventstr):Execute(nil)
    
    -- CS.CLuaManager.ShowWindow(winname,nil,table.unpack(parameters))
    self:FireEvent(CEventCode.Window.Show,winname,nil,table.unpack(parameters))
end

local function GotoNpc(self,envParams,parameters)
    local csevent = CEvent.Auto.Talk();
    local npc_id =  parameters[1]
    csevent.npc = npc_id
    self:FireEvent(csevent)
end

--使用心锁激活道具
local function ItemUseHeartLock(self, envParams, parameters)
    if CGlobal.game.marriageSystem:IsHeartLockActived() then
        CGlobal.game.marriageSystem:SendBagItemByRef(CReferenceHelper.Item.HEARTLOCK_UNLOCK_ITEM_ID)
    else
        self:FireEvent(CEventCode.Window.Show, "MarriageWindow", nil, 1)
    end
end

--@desc: 使用改名卡
local function ItemUseChangeName(self, envParams, parameters)
    if CGlobal.game.mainPlayer.csmainPlayer.cross then
        local csevent = CEvent.Message.HintMessage(CErrorCode.Common.CrossingCannotOperate)
        self:FireEvent(csevent)
        return
    end
    local p = parameters[1]
    if p == Proto.Misc.ChangeName.System.Group then
        if CGlobal.game.mainPlayer.sn ~= CGlobal.game.groupSystem:GetLeaderSN() then
            local csevent = CEvent.Message.HintMessage(CErrorCode.ChangeName.NotGroupLeader)
            self:FireEvent(csevent)
			return
        end
    end
    self:FireEvent(CEventCode.Window.Show, "ChangeNameWindow",function(win, request_data)
        win.request_data = {request_data[0]}
    end, p)
end

--@desc: 使用红包
local function ItemUseRedPacket(self, envParams, parameters)
    if CGlobal.game.mainPlayer.csmainPlayer.cross then
        local csevent = CEvent.Message.HintMessage(CErrorCode.Common.CrossingCannotOperate)
        self:FireEvent(csevent)
        return
    end
    local ref_id = tonumber(parameters[1])
    self:FireEvent(CEventCode.Window.Show, "SendRedPacketWindow",function(win, request_data)
        win.request_data = {request_data[0]}
    end, ref_id)
end

--@desc: 使用圣魂道具
local function ItemUseSealSoul(self, envParams, parameters)
    self:FireEvent(CEventCode.Seal.UseSealSoulInBag)
end

function EventPool:OnInit()
    self.mrg = CGlobal.game.eventParseSystem

    self.mrg:Add("ShowWindowEx",function(...)
        ShowWindow(self,...)
    end)
    self.mrg:Add("GotoNpc",function(...)
        GotoNpc(self,...)
    end)
    self.mrg:Add("ItemUseHeartLock",function(...)
        ItemUseHeartLock(self,...)
    end)
    self.mrg:Add("ItemUseChangeName",function(...)
        ItemUseChangeName(self,...)
    end)
    self.mrg:Add("ItemUseRedPacket",function(...)
        ItemUseRedPacket(self,...)
    end)
    self.mrg:Add("ItemUseSealSoul",function(...)
        ItemUseSealSoul(self,...)
    end)
end

function EventPool:OnFini()
end


return EventPool