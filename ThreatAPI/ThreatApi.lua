local f = CreateFrame("Frame")

f:RegisterEvent("CHAT_MSG_COMBAT_MISC_INFO")

local messageBuffer = {}

local creatureBuffer = {}
local tankingBuffer = {}

local getNormalizedGUID = function(unit)
    if unit == nil then
        return nil
    end
    local guid = UnitGUID(unit)
    if guid == nil then
        return nil
    end
    if (GetClassicExpansionLevel ~= nil) then
		local unit_type = strsplit("-", guid)
		if unit_type == "Creature" or unit_type == "Vehicle" then
			local _, _, _, _, _, _, spawn_uid = strsplit("-", guid)
            guid = spawn_uid
		elseif unit_type == "Player" then
			local _, _, player_id = strsplit("-", guid)
            guid = player_id
		end
    end
    guid = strsub(guid, -6)
    return guid
end

local handleThreatUpdate = function(message)
    local creatureguid = strsub(message[2], -6)
    local count = message[3]
    if (creatureBuffer[creatureguid] == nil) then
        creatureBuffer[creatureguid] = {}
    end
    for i=0,(count * 2)-2,2 do
        local targetguid = strsub(message[4+i], -6)
        local targetvalue = message[4+i+1]
        creatureBuffer[creatureguid][targetguid] = targetvalue;
    end
end

local handleHighestThreatUpdate = function(message)
    local creatureguid = strsub(message[2], -6)
    local highestguid = strsub(message[3], -6)
    local count = message[4]
    tankingBuffer[creatureguid] = highestguid;
    --DevTools_Dump(tankingBuffer)
    if (creatureBuffer[creatureguid] == nil) then
        creatureBuffer[creatureguid] = {}
    end
    for i=0,(count * 2)-2,2 do
        local targetguid = strsub(message[5 + i], -6)
        local targetvalue = strsub(message[5 + i + 1], -6)
        creatureBuffer[creatureguid][targetguid] = targetvalue;
    end
end

local handleThreatClear = function(message)
    local creatureguid = strsub(message[2], -6)
    creatureBuffer[creatureguid] = nil
    tankingBuffer[creatureguid] = nil
end

local handleThreatRemove = function(message)
    local creatureguid = strsub(message[2], -6)
    local removedguid = strsub(message[3], -6)
    if (creatureBuffer[creatureguid] == nil) then
        return;
    end
    creatureBuffer[creatureguid][removedguid] = nil
end

local handleOpcode = function(message)
    if (message[1] == "SMSG_THREAT_UPDATE") then
        handleThreatUpdate(message)
    elseif (message[1] == "SMSG_HIGHEST_THREAT_UPDATE") then
        handleHighestThreatUpdate(message)
    elseif (message[1] == "SMSG_THREAT_CLEAR") then
        handleThreatClear(message)
    elseif (message[1] == "SMSG_THREAT_REMOVE") then
        handleThreatRemove(message)
    end
end

f:SetScript("OnEvent", function(self, event, ...)    	
    local msg = ...;
    local id, content = strsplit(":", msg);
    if ((id == nil) or (not type(id) == "number")) then
        return;
    end
    _, content = strsplit(" ", content)
    if (content ~= "END") then
        if (messageBuffer[id] == nil) then
            messageBuffer[id] = {}
        end
        table.insert(messageBuffer[id], content);
    else
        handleOpcode(messageBuffer[id])
        messageBuffer[id] = nil
    end
end)

UnitThreatPercentageOfLead = function (unitGuid, mobUnitGuid, scaled)
    local _unitGuid = unitGuid
    local _mobUnitGuid = mobUnitGuid
    local _highestThreat = 1
    local _tanking = tankingBuffer[_mobUnitGuid]
    if _tanking == nil then
        return 1
    end
    _highestThreat = creatureBuffer[_mobUnitGuid][_tanking]
    if (_highestThreat == nil or _highestThreat == 0) then
        return 1
    end
    _unitThreat = creatureBuffer[_mobUnitGuid][_unitGuid]
    if (_unitThreat == nil or _unitThreat == 0) then
        return 1
    end
    return ((_unitThreat + 0.1) / (_highestThreat + 0.1)) * 100
end

local getThreatStatus = function (unitGuid, mobUnitGuid)
    local _unitGuid = unitGuid
    local _mobUnitGuid = mobUnitGuid
    if (creatureBuffer[_mobUnitGuid] == nil) then
        return
    end
    _unitThreat = creatureBuffer[_mobUnitGuid][_unitGuid]
    if _unitThreat == nil then
        return nil
    end
    if (UnitThreatPercentageOfLead(unitGuid, mobUnitGuid, false) == nil) then
        return nil
    end
    if UnitThreatPercentageOfLead(unitGuid, mobUnitGuid, false) < 100 then
        return 0
    elseif UnitThreatPercentageOfLead(unitGuid, mobUnitGuid, false) >= 100 then
        if tankingBuffer[_mobUnitGuid] ~= _unitGuid then
            return 1
        end
        if tankingBuffer[_mobUnitGuid] == _unitGuid then
            return 3
        end
    end 
end

ThreatUnitDetailedThreatSituation = function (unit, mobUnit)
    local _unitGuid = getNormalizedGUID(unit)
    local _mobUnitGuid = getNormalizedGUID(mobUnit)

    local _tankingUnit = tankingBuffer[_mobUnitGuid]
    local _threatVal = nil
    if (creatureBuffer[_mobUnitGuid] ~= nil) then
        _threatVal = creatureBuffer[_mobUnitGuid][_unitGuid]
    end
    if _threatVal ~= nil then
        _threatVal = tonumber(_threatVal)
    end
    local _threatStatus = getThreatStatus(_unitGuid, _mobUnitGuid)
    if _threatStatus ~= nil then
        _threatStatus = tonumber(_threatStatus)
    end
    local _threatPct1 = UnitThreatPercentageOfLead(_unitGuid, _mobUnitGuid, true)
    if _threatPct1 ~= nil then
        _threatPct1 = tonumber(_threatPct1)
    end
    local _threatPct2 = UnitThreatPercentageOfLead(_unitGuid, _mobUnitGuid, false)
    if _threatPct2 ~= nil then
        _threatPct2 = tonumber(_threatPct2)
    end
    return _tankingUnit == _unitGuid, _threatStatus, _threatPct1, _threatPct2, _threatVal
end

UnitDetailedThreatSituation = ThreatUnitDetailedThreatSituation

UnitThreatSituation = function (unitGuid, mobUnitGuid)
    local _unitGuid = getNormalizedGUID(unitGuid)
    local _mobUnitGuid = ""
    if (mobUnitGuid == nil) then
        local threat = 0;
        if (creatureBuffer == nil) then
            return;
        end
        for k,v in pairs(creatureBuffer) do
            if (v ~= nil) then
                for i,j in pairs(v) do
                    if (tonumber(j) > tonumber(threat)) then
                        threat = j;
                        _mobUnitGuid = k
                    end
                end
            end
        end
    else
        _mobUnitGuid = getNormalizedGUID(mobUnitGuid)
    end
    local _result = getThreatStatus(_unitGuid, _mobUnitGuid)
    if _result ~= nil then
        _result = tonumber(_result)
    end
    return _result
end

GetThreatStatusColor = function(status)
    if (status == nil or status == 0) then
        return {0.69, 0.69, 0.69}
    elseif (status == 1) then
        return {1.00, 1.00, 0.47}
    elseif (status == 2) then
        return {1.00, 0.60, 0.00}
    elseif (status == 3) then
        return {1.00, 0.00, 0.00}
    else
        return {0.0, 0.0, 0.0}
    end
end
