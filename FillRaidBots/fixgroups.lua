local MAX_PLAYERS_PER_GROUP = 5
local MAX_GROUPS = 8
local isFixingGroups = false
local moveDelay = 0.1 -- Delay time in seconds
local lastMoveTime = 0
local moveQueue = {} -- Queue for delayed moves
local healerClasses = {"PALADIN", "PRIEST", "DRUID", "SHAMAN"} -- Healer classes
local currentPhase = 1
local FixGroups

DEFAULT_CHAT_FRAME:AddMessage("Fixgroups |cff00FF00 loaded|cffffffff, /fixgroups |cff00eeee to start. ")

local function QueueMove(player, group)
    table.insert(moveQueue, {player = player, group = group})
end

local function GetTableLength(tbl)
    local count = 0
    for _ in pairs(tbl) do
        count = count + 1
    end
    return count
end

-- Custom TableContains function
local function TableContains(tbl, value)
    for _, v in pairs(tbl) do
        if v == value then
            return true
        end
    end
    return false
end

local function ProcessMoveQueue()
    local currentTime = GetTime() -- Use GetTime() for sub-second precision
    if currentTime >= (lastMoveTime + moveDelay) and GetTableLength(moveQueue) > 0 then
        local nextMove = table.remove(moveQueue, 1)
        local player = nextMove.player
        local group = nextMove.group

        if not player.moved then
            SetRaidSubgroup(player.index, group)
            player.moved = true
            lastMoveTime = currentTime
        end
    end

    if GetTableLength(moveQueue) == 0 then
        if currentPhase == 1 then
            UIErrorsFrame:AddMessage("Phase 1 complete, starting Phase 2")
            currentPhase = 2
            FixGroups()
        else
            UIErrorsFrame:AddMessage("Phase 2 complete, groups organized")
            isFixingGroups = false
        end
    end
end

function FixGroups()
    local groupSizes = {}
    local healers = {}
    for i = 1, MAX_GROUPS do
        groupSizes[i] = 0
    end

    -- Collect all healers
    for i = 1, GetNumRaidMembers() do
        local name, _, subgroup, _, _, class, _, online = GetRaidRosterInfo(i)
        if class and TableContains(healerClasses, class) then
            local player = {name = name, index = i, group = subgroup, class = class, online = online, moved = false}
            table.insert(healers, player)
        end
    end

    if currentPhase == 1 then
        -- Phase 1: Move healers to Group 8, 7, 6, ..., 1
        local groupIndex = MAX_GROUPS
        for _, healer in ipairs(healers) do
            while groupSizes[groupIndex] >= MAX_PLAYERS_PER_GROUP and groupIndex > 1 do
                groupIndex = groupIndex - 1
            end
            if groupIndex >= 1 then
                QueueMove(healer, groupIndex)
                groupSizes[groupIndex] = groupSizes[groupIndex] + 1
            end
        end
    elseif currentPhase == 2 then
        -- Phase 2: Distribute healers evenly across all groups (1 -> 8)
        local groupIndex = 1
        for _, healer in ipairs(healers) do
            while groupSizes[groupIndex] >= MAX_PLAYERS_PER_GROUP and groupIndex <= MAX_GROUPS do
                groupIndex = groupIndex + 1
            end
            if groupIndex <= MAX_GROUPS then
                QueueMove(healer, groupIndex)
                groupSizes[groupIndex] = groupSizes[groupIndex] + 1
                groupIndex = groupIndex + 1
                if groupIndex > MAX_GROUPS then
                    groupIndex = 1 -- Wrap back to Group 1
                end
            end
        end
    end
end

local frame = CreateFrame("Frame")
frame:SetScript("OnUpdate", function(self, elapsed)
    if not isFixingGroups then
        return
    end
    ProcessMoveQueue()
end)

frame:Show()

SlashCmdList["FIXGROUPS"] = function()
    isFixingGroups = true
    currentPhase = 1
    lastMoveTime = 0
    moveQueue = {}
    FixGroups()
end

SLASH_FIXGROUPS1 = "/fixgroups"

