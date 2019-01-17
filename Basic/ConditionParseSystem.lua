--[[
    @desc: 数据配档条件解析存储中心
    author:陈德怀
    time:2018-07-11 17:29:37
]]
local base = require "core.Object"
local ConditionParser = require("StringEventParse.ConditionParser")

--@SuperType [core.Object#CObject]
local ConditionParseSystem = class("ConditionParseSystem",base)

function ConditionParseSystem:OnInit()
    self.conditions = {}
    self.conditionParser = ConditionParser.new(self)
end

function ConditionParseSystem:Add(name,fuc)
    table.insert( self.conditions, {name = name,fuc = fuc})
end

function ConditionParseSystem:Get(name)
    for k,v in pairs(self.conditions) do
        if(name == v.name) then
            return v.fuc
        end
    end
    return nil
end

function ConditionParseSystem:OnFini()
    self.conditions = {}
end


return ConditionParseSystem