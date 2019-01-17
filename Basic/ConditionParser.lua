--[[
    @desc: 字符串条件解析系统（支持==，!=,>,<,<=,>=;支持多条件解析，不同条件之间使用or/and链接）
    author:陈德怀
    time:2018-05-26 11:06:44
]]
-- local StringUtil = require("util.StringUtil")
local CQueue = require("util.Queue")
local StrExpr = CS.StrExpr
local ListExpr = CS.ListExpr
local ConstExpr = CS.ConstExpr
local FuncExpr = CS.FuncExpr
local SubExpr = CS.SubExpr
local ExprConnectors = CS.ExprConnectors

local ConditionParser = class("ConditionParser")
local EventCall = class("EventCall")

local ParseFunc;

function ConditionParser:ctor(exprPool)
    --@RefType [StringEventParse.ConditionPool#ConditionPool]
    self.exprPool = exprPool
    self.splitChars = {"(", ")", "{", "}", ",", " ", "\t", ">", "<", "=", "!"}
end

local function GetStringsList(self, eventsString)
    --@RefType [util.Queue#Queue]
    local stringQueue = CQueue.new()
    if (StringUtil.IsNilOrEmpty(eventsString)) then
        return stringQueue
    end

    local index = 0
    local startIndex = 0
    local subStr = nil
    while (index ~= -1) do
        local subStrLen = index - startIndex
        if (subStrLen > 0) then
            subStr = StringUtil.Substring(eventsString,startIndex, subStrLen)
            subStr = StringUtil.Trim(subStr)
            if (string.len(subStr) > 0) then
                stringQueue:Enqueue(subStr)
            end
        end

        -- 添加分隔符(空格除外)
        local spliterLen = 1
        if (string.len(eventsString) > index + 1) then
            local switch = {
                ["<"] = function()
                    if (string.sub(eventsString, index + 1, index + 1) == "=") then
                        subStr = "<="
                    else
                        subStr = "<"
                    end
                end,
                [">"] = function()
                    if (string.sub(eventsString, index + 1, index + 1) == "=") then
                        subStr = ">="
                    else
                        subStr = ">"
                    end
                end,
                ["="] = function()
                    if (string.sub(eventsString, index + 1, index + 1) == "=") then
                        subStr = "=="
                    else
                        cprint.LogError("语法错误:'=',表达式原文:" .. eventsString)
                    end
                end,
                ["!"] = function()
                    if (string.sub(eventsString, index + 1, index + 1) == "=") then
                        subStr = "!="
                    else
                        cprint.LogError("语法错误:'=',表达式原文:" .. eventsString)
                    end
                end,
                ["default"] = function()
                    subStr = StringUtil.Substring(eventsString, index, 1)
                end
            }
            local switchfuc = switch[string.sub(eventsString, index, index)]
            if (switchfuc) then
                switchfuc()
            else
                switch["default"]()
            end

            spliterLen = string.len(subStr)
            subStr = StringUtil.Trim(subStr)
        else
            subStr = StringUtil.Substring(eventsString,index, 1)
            subStr = StringUtil.Trim(subStr)
        end

        if (string.len(subStr) > 0) then
            stringQueue:Enqueue(subStr)
        end
        startIndex = index + spliterLen
        index = StringUtil.IndexOfAny(eventsString, self.splitChars, startIndex)
    end

    -- 添加最后一个串
    if (startIndex < string.len(eventsString)) then
        subStr = StringUtil.Substring(eventsString,startIndex, string.len(eventsString) - startIndex)
        subStr = StringUtil.Trim(subStr)
        if (string.len(subStr) > 0) then
            stringQueue:Enqueue(subStr)
        end
    end

    return stringQueue
end

--@stringQueue: [util.Queue#Queue]
local function ParseParams(self, stringQueue, endBracket)
    local word = nil
    local parameters = {}
    local subParams = nil
    local exprComplete = false
    while (stringQueue:Size() > 0) do
        word = stringQueue:Dequeue()
        local first_char = string.sub(word, 1, 1)
        local second_char = string.sub(word, 2, 2)
        if (first_char == ",") then
            break
        elseif (first_char == endBracket) then
            exprComplete = true
            break
        elseif (first_char == "'") then
            local endPos = StringUtil.LastIndexOf(word, "'")
            if (endPos < 0) then
                break
            end

            local substr = StrExpr(StringUtil.Substring(word, 2, endPos - 2))
            table.insert(parameters, substr)
        elseif (first_char == "\"") then
            local endPos = StringUtil.LastIndexOf(word, "\"")
            if (endPos < 0) then
                break
            end
            local substr = StrExpr(StringUtil.Substring(word, 2, endPos - 2))
            table.insert(parameters, substr)
        elseif (first_char == "{") then
            subParams = ParseParams(self, stringQueue, "}")
            if (subParams == nil) then
                break
            end
            local substr = ListExpr(subParams)
            table.insert(parameters, substr)
        elseif (word == "true") then
            local substr = ConstExpr(1)
            table.insert(parameters, substr)
        elseif (word == "false") then
            local substr = ConstExpr(0)
            table.insert(parameters, substr)
        elseif (first_char == "@" and second_char == "B") then
            local str = StringUtil.Substring(word, 3)
            local substr = ConstExpr(tonumber(str))
            table.insert(parameters, substr)
        elseif (StringUtil.IsDigit(first_char) or first_char == "-") then
            if (StringUtil.Contains(word, ".")) then
                table.insert(parameters, ConstExpr(tonumber(word)))
            else
                table.insert(parameters, ConstExpr(tonumber(word)))
            end
        else
            local funcExpr = ParseFunc(self,word, stringQueue)
            if (funcExpr == nil) then
                break
            end
            table.insert(parameters, funcExpr)
        end

        -- 分隔符
        word = stringQueue:Dequeue()
        first_char = string.sub(word, 1, 1)
        if (first_char ~= ",") then
            -- 结束符
            if (first_char == endBracket) then
                exprComplete = true
            end
            break
        end
    end

    if (not exprComplete) then
        cprint.error("字串格式不正确:%s", word)
        return nil
    end

    return parameters
end

--@return [luaIde#CS.ExprBase]
local function ParseQueue(self, stringQueue)
    local word = nil
    local first, prev, last = nil
    while (stringQueue:Size() > 0) do
        word = stringQueue:Dequeue()
        local first_char = string.sub(word, 1, 1)
        if (word == "(") then
            local subExpr = ParseQueue(self, stringQueue)
            if (subExpr == nil) then
                return nil
            end
            last = SubExpr(subExpr)
        elseif (first_char == "'") then
            local endPos = StringUtil.LastIndexOf(word, "'")
            if (endPos > 0) then
                last = StrExpr(StringUtil.Substring(word, 2, endPos - 2))
            else
                return nil
            end
        elseif (first_char == '"') then
            local endPos = StringUtil.LastIndexOf('"')
            if (endPos > 0) then
                last = StrExpr(StringUtil.Substring(word, 2, endPos - 2))
            else
                return nil
            end
        elseif (word == "true") then
            last = ConstExpr(1)
        elseif (word == "false") then
            last = ConstExpr(0)
        elseif (first_char == "-" or StringUtil.IsDigit(first_char)) then
            if (StringUtil.Contains(word, ".")) then
                last = ConstExpr(tonumber(word))
            else
                last = ConstExpr(tonumber(word))
            end
        else
            last = ParseFunc(self,word, stringQueue)
        end

        if (last == nil) then
            return nil
        end

        if (first == nil) then
            first, prev = last
        else
            prev.next = last
            prev = last
        end

        -- 条件连接关系
        if (stringQueue:Size() > 0) then
            word = stringQueue:Dequeue()
            if (word == ")") then
                break
            end

            last.connector = ExprConnectors.Get(word)
            if (last.connector == nil) then
                return nil
            end
        end

        last = nil
    end
    return first
end

--@return [luaIde#CS.FuncExpr]
ParseFunc = function(self, funcName, stringQueue)
    -- 解析方法
    local method = self.exprPool:Get(funcName)
    if (method == nil) then
        return nil
    end

    -- 解析参数
    local word = stringQueue:Dequeue()
    if (word ~= "(") then
        return nil
    end
    local parameters = ParseParams(self, stringQueue, ")")
    return FuncExpr(method, parameters)
end

--@return [luaIde#CS.ExprBase]
function ConditionParser.Parse(conditionsString)
    --@RefType [StringEventParse.ConditionParseSystem#ConditionParseSystem]
    local stringConditionParseSystem = CGlobal.game.conditionParseSystem
    if (not stringConditionParseSystem) then
        cprint.LogError("then stringConditionParseSystem is not init.")
        return
    end

    local stringQueue = GetStringsList(stringConditionParseSystem.conditionParser, conditionsString)
    return ParseQueue(stringConditionParseSystem.conditionParser, stringQueue)
end

return ConditionParser
