
--[[
    @desc: 字符串事件解析系统（支持多事件解析，多事件之间使用空格分开）
    author:陈德怀
    time:2018-05-26 11:06:44
]]
local StringUtil = require("util.StringUtil")
local CQueue = require("util.Queue")

local EventParser = class("EventParser")
local EventCall = class("EventCall")

--@poolType: [StringEventParse.EventParseSystem#EventParseSystem]
function EventParser:ctor(poolType)
    self.splitChars = {'(', ')', '{', '}', ',', ' ', '\t'}
    self.poolType = poolType
end

--@return [util.Queue#Queue]
local function GetStringsList(self,eventsString)
    if(StringUtil.IsNilOrEmpty(eventsString)) then
        return nil
    end

    --@RefType [util.Queue#Queue]
    local stringQueue = CQueue.new()
    
    local index = 1;
    local startIndex = 1;
    local subStr = nil;
    local startChar = string.sub( eventsString, startIndex,startIndex )

    while true do
        if (startChar == '"' or startChar == '\'') then
            index = StringUtil.IndexOf(eventsString, startChar, startIndex + 1)
            if(index == -1) then
                break
            end
            index = index + 1

            local subStrLen = index - startIndex
            if (subStrLen > 0) then
                subStr = string.sub( eventsString, startIndex, startIndex+subStrLen-1 )
                subStr = string.gsub( subStr," ","")
                if (string.len(subStr) > 0) then
                    --table.insert(stringQueue,subStr)
                    stringQueue:Enqueue(subStr)
                end
            end

            startIndex = index;
            if (startIndex > string.len(eventsString)) then
                break;
            end
            startChar = string.sub( eventsString, startIndex,startIndex )
        else
            index = StringUtil.IndexOfAny(eventsString,self.splitChars,startIndex)
            if(index == -1) then
                break
            end

            local subStrLen = index - startIndex
            if (subStrLen > 0) then
                subStr = string.sub( eventsString, startIndex, startIndex+subStrLen-1 )
                subStr = string.gsub( subStr," ","")

                if (string.len( subStr) > 0) then
                    stringQueue:Enqueue(subStr)
                end
            end
            startIndex = index
            startChar = string.sub( eventsString, index, index )

            if(startChar ~= '"' and startChar ~= '\'') then
                -- 添加分隔符(空格除外)
                subStr = string.sub( eventsString, index, index )
                subStr = StringUtil.Trim(subStr)

                if (string.len(subStr) > 0) then
                    stringQueue:Enqueue(subStr)                    
                end
                startIndex = index + 1;

                if (startIndex > string.len(eventsString)) then
                    break
                end
                startChar = string.sub( eventsString, startIndex, startIndex )
            end
        end
    end
    return stringQueue
end

--@stringQueue: [util.Queue#Queue]
local function ParseParams(self,stringQueue, endBracket)
    local word = nil
    local parameters = {}
    local subParams = nil
    local exprComplete = false
    while (stringQueue:Size() > 0) do
        word = stringQueue:Dequeue()
        local first_char = string.sub(word, 1,1 )
        local second_char = string.sub(word, 2,2 )
        if (first_char == ",") then
            break
        elseif (first_char == endBracket) then
            exprComplete = true
            break
        elseif (first_char == "\'") then
            local endPos = StringUtil.LastIndexOf(word,"\'")
            if (endPos > 0) then
                local substr = StringUtil.Substring(word,2,endPos-2)
                table.insert( parameters, substr )
            else
                break
            end
        elseif (first_char == "\"") then
            local endPos = StringUtil.LastIndexOf(word,"\"")
            if (endPos > 0) then
                local substr = StringUtil.Substring(word,2,endPos - 2)
                table.insert( parameters, substr )
            else
                break
            end
        elseif (first_char == "{") then
            subParams = ParseParams(self,stringQueue, "}")
            if (subParams ~= nil) then
                table.insert( parameters, subParams )
            else
                break
            end
        elseif (word == "true") then
            table.insert( parameters, true )
        elseif (word == "false") then
            table.insert( parameters, false )
        elseif (first_char == "@" and second_char == "B") then
            local substr = StringUtil.Substring(word,3)
            table.insert( parameters, substr )
        elseif (StringUtil.Contains(word,".")) then
            table.insert( parameters, word )
        else
            table.insert( parameters, word )
        end

        -- 分隔符
        word = stringQueue:Dequeue()
        first_char = string.sub(word, 1,1 )
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

--@return [util.EventParser#EventCall]
local function ParseFunc(self,funcName,stringQueue)
    local method = self.poolType:Get(funcName)
    if (method == nil) then
        return nil
    end

    local word = stringQueue:Dequeue()
    if (word ~= "(") then
        return nil
    end

    local parameters = ParseParams(self,stringQueue, ")")
    return EventCall.new(method, parameters)
end

--@stringQueue: [util.Queue#Queue]
local function ParseQueue(self,stringQueue)
    local word = nil
    local first,prev,last = nil
    while (stringQueue:Size() > 0) do
        word = stringQueue:Dequeue()
        if (word == "(") then
            last = ParseQueue(self,stringQueue);
        else
            last = ParseFunc(self,word, stringQueue);
        end

        if (last ~= nil) then
            if (first == nil) then
                first,prev = last
            else
                prev.NextCall = last
                prev = last
            end
            last = nil
        end
    end
    return first;
end

--@return [util.EventParser#EventCall]
function EventParser.Parse( eventsString )
    local stringEventParseSystem = CGlobal.game.eventParseSystem
    if(not stringEventParseSystem) then
        cprint.LogError("the EventParseSystem is not init.")
        return
    end

    local stringQueue = GetStringsList(stringEventParseSystem.eventParser,eventsString)
    return ParseQueue(stringEventParseSystem.eventParser,stringQueue)
end


----------------------------------------------------
function EventCall:ctor(fuc,parameters)
    self.fuc = fuc
    self.parameters = parameters
    self.nextCall = nil
end

function EventCall:Execute(eventParams)
    if(self.fuc ~= nil) then
        self.fuc(eventParams,self.parameters)
    end

    if (self.nextCall~=nil) then
        self.nextCall:Execute(eventParams)
    end
end

return EventParser