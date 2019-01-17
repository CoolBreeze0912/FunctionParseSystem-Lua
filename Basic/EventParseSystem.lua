--[[
    @desc: 数据配档函数事件解析存储中心
    author:陈德怀
    time:2018-07-11 17:29:37
]]
local base = require "core.Object"
local EventParser = require("StringEventParse.EventParser")

--@SuperType [core.Object#CObject]
local EventParseSystem = class("EventParseSystem",base)

function EventParseSystem:OnInit()
    self.events = {}
    self.eventParser = EventParser.new(self)
end

function EventParseSystem:Add(name,fuc)
    table.insert( self.events, {name = name,fuc = fuc})
end

function EventParseSystem:Get(name)
    for k,v in pairs(self.events) do
        if(name == v.name) then
            return v.fuc
        end
    end

    cprint.LogWarning(string.format( "EventParseSystem have no event named '%s'",name ))
    return nil
end

function EventParseSystem:OnFini()
    self.events = nil
end


return EventParseSystem