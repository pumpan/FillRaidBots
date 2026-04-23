local classes = {
  "warrior tank",
  "warrior meleedps",
  "paladin healer",
  "paladin tank",
  "paladin meleedps",
  "hunter rangedps",
  "rogue meleedps",
  "priest healer",
  "priest rangedps",
  "shaman healer",  
  "shaman rangedps",
  "shaman meleedps",
  "mage rangedps",
  "warlock rangedps",
  "druid tank",
  "druid healer",
  "druid meleedps",
  "druid rangedps"
}
local addonName = "FillRaidBots"
local addonPrefix = "FillRaidBotsVersion"
local versionNumber = "5.0.0"
local a = "5"
local botCount = 0
local initialBotRemoved = false
local firstBotName = nil
local DebugMessageQueue = {}
local messageQueue = {}
local delay = 0.1 
local nextUpdateTime = 0 

local classCounts = {}
local FillRaidFrame 
local fillRaidFrameManualClose = false 
local isCheckAndRemoveEnabled = false


if FillRaidBotsSavedSettings == nil then
    FillRaidBotsSavedSettings = {}
end


local function FRB_StrTrim(value)
    if value == nil then
        return ""
    end
    return string.gsub(value, "^%s*(.-)%s*$", "%1")
end

if not strtrim then
    setglobal("strtrim", FRB_StrTrim)
end

--========================
-- Generate toggle functions
--========================
for _, section in ipairs(SettingsConfig.sections) do
    for _, item in ipairs(section.items) do
        if item.type == "checkbox" and item.toggle then

            local varName = item.toggle
            local funcBase = string.gsub(varName, "Enabled$", "")
            local funcName = "Toggle"..funcBase

            if not getglobal(funcName) then
                setglobal(funcName, function(isChecked)
                    setglobal(varName, isChecked)
                end)
            end

        end
    end
end
----------------------VIP Detector--------------------------
local vipFrame = CreateFrame("Frame", "VIPDetectorFrame")
local isVIP = false
local vipTimer = 0
local vipListening = true


local VIP_KEYWORDS = {
    "repaired.",
}


vipFrame:RegisterEvent("CHAT_MSG_SYSTEM")
vipFrame:RegisterEvent("PLAYER_ENTERING_WORLD")


local function IsVIPMessage(msg)
    for _, keyword in ipairs(VIP_KEYWORDS) do
        if string.find(msg, keyword) then
            return true
        end
    end
    return false
end


local vipFrame = CreateFrame("Frame")
vipFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
vipFrame:RegisterEvent("CHAT_MSG_SYSTEM")

local vipTimer = 0
local vipListening = false

function UpdateVIPSettingsState()
    if not FillRaidBotsSavedSettings then
        return
    end

    local isVip = FillRaidBotsSavedSettings.isVIP and true or false

    local cb = GetSettingsCheckbox and GetSettingsCheckbox("isAutoRepairEnabled")
    if cb then
        if isVip then
            cb:SetChecked(FillRaidBotsSavedSettings.isAutoRepairEnabled and true or false)
            cb:Enable()
            cb.text:SetTextColor(1, 1, 1)
            cb.text:SetText("Auto Repair")
        else
            FillRaidBotsSavedSettings.isAutoRepairEnabled = false
            cb:SetChecked(false)
            cb:Disable()
            cb.text:SetTextColor(0.5, 0.5, 0.5)
            cb.text:SetText("Auto Repair (VIP ONLY)")
        end
    end

    local vipCb = GetSettingsCheckbox and GetSettingsCheckbox("useVipPresets")
    if vipCb then
        if isVip then
            vipCb:SetChecked(FillRaidBotsSavedSettings.useVipPresets and true or false)
            vipCb:Enable()
            vipCb.text:SetTextColor(1, 1, 1)
            vipCb.text:SetText("Use VIP Presets")
        else
            FillRaidBotsSavedSettings.useVipPresets = false
            vipCb:SetChecked(false)
            vipCb:Disable()
            vipCb.text:SetTextColor(0.5, 0.5, 0.5)
            vipCb.text:SetText("Use VIP Presets (VIP ONLY)")
        end
    end
end

vipFrame:SetScript("OnEvent", function()
    if event == "PLAYER_ENTERING_WORLD" then
        if not FillRaidBotsSavedSettings.isVIP then
            SendChatMessage(".repair", "SAY")
            vipTimer = 0
            vipListening = true

            this:SetScript("OnUpdate", function()
                if vipListening and not FillRaidBotsSavedSettings.isVIP then
                    vipTimer = vipTimer + arg1
                    if vipTimer > 10 then
                        vipListening = false
                        FillRaidBotsSavedSettings.isVIP = false
                        DebugMessage("|cffffff00[VIP SCAN DONE]|r No VIP detected.", "debuginfo")
                        this:SetScript("OnUpdate", nil)
                        UpdateVIPSettingsState()
                    end
                end
            end)
        else
            UpdateVIPSettingsState()
        end

    elseif event == "CHAT_MSG_SYSTEM" then
        if vipListening and not FillRaidBotsSavedSettings.isVIP then
            local msg = arg1
            if msg and IsVIPMessage(msg) then
                FillRaidBotsSavedSettings.isVIP = true
                vipListening = false
                this:SetScript("OnUpdate", nil)
                UpdateVIPSettingsState()
                DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[VIP DETECTED]|r You have VIP status!")
            end
        end
    end
end)


---------------------------------------------------- auto repair ----------------------------------------------

local durabilityFrame = CreateFrame("Frame", "DurabilityRepairFrame")
durabilityFrame:RegisterEvent("PLAYER_UNGHOST")
durabilityFrame:RegisterEvent("PLAYER_ALIVE")

local DURABLE_SLOTS = {
    "HeadSlot",
    "ShoulderSlot",
    "ChestSlot",
    "WaistSlot",
    "LegsSlot",
    "FeetSlot",
    "WristSlot",
    "HandsSlot",
    "MainHandSlot",
    "SecondaryHandSlot",
    "RangedSlot",
}


local scanTooltip = CreateFrame("GameTooltip", "DurabilityScannerTooltip", nil, "GameTooltipTemplate")
scanTooltip:SetOwner(UIParent, "ANCHOR_NONE")


local function ParseDurability(text)
    local _, _, current, max = string.find(text, "(%d+)%s*/%s*(%d+)")
    if current and max then
        return tonumber(current), tonumber(max)
    end
    return nil, nil
end


local function GetDurability(slotId)
    scanTooltip:ClearLines()
    scanTooltip:SetInventoryItem("player", slotId)

    for i = 2, scanTooltip:NumLines() do
        local leftText = getglobal("DurabilityScannerTooltipTextLeft"..i)
        local text = leftText and leftText:GetText()
        if text then
            local current, max = ParseDurability(text)
            if current and max then
                return current, max
            end
        end
    end

    return nil, nil
end


local function ColorPercent(pct)
    if pct > 80 then
        return "|cff00ff00" .. string.format("%.0f%%", pct) .. "|r"
    elseif pct > 50 then
        return "|cffffff00" .. string.format("%.0f%%", pct) .. "|r"
    else
        return "|cffff0000" .. string.format("%.0f%%", pct) .. "|r"
    end
end


durabilityFrame:SetScript("OnEvent", function()
    durabilityFrame.elapsed = 0
    durabilityFrame:SetScript("OnUpdate", function()
        durabilityFrame.elapsed = durabilityFrame.elapsed + arg1
        if durabilityFrame.elapsed > 0.5 then
            durabilityFrame:SetScript("OnUpdate", nil)
            durabilityFrame.elapsed = 0

            if not AutoRepairEnabled or UnitIsGhost("player") then return end
            local totalCurrent, totalMax = 0, 0

            for _, slotName in ipairs(DURABLE_SLOTS) do
                local slotId = GetInventorySlotInfo(slotName)
                local current, max = GetDurability(slotId)
                if current and max then
                    totalCurrent = totalCurrent + current
                    totalMax = totalMax + max
                end
            end

            if totalMax > 0 then
                local avg = (totalCurrent / totalMax) * 100
                if avg < 100 and AutoRepairEnabled then
                    DEFAULT_CHAT_FRAME:AddMessage("Durability is "..ColorPercent(avg).." Repairing...")
                    SendChatMessage(".repair", "SAY")
                end
            end
        end
    end)
end)

------------------------auto invite guild-----------------------------
local guildCheckFrame = CreateFrame("Frame")
guildCheckFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

local delayguildcheck = 5
local elapsed = 0
local waiting = false

guildCheckFrame:SetScript("OnEvent", function()
    if not AutoJoinGuildEnabled then return end
    waiting = true
    elapsed = 0
    guildCheckFrame:SetScript("OnUpdate", function()
        if not waiting then return end
        elapsed = elapsed + arg1
        if elapsed >= delayguildcheck then
            waiting = false
            guildCheckFrame:SetScript("OnUpdate", nil)

            local guildName = GetGuildInfo("player")
            if not guildName then
                DEFAULT_CHAT_FRAME:AddMessage("FillRaidBots: Joining the guild")
                SendChatMessage(".i", "SAY")
			else 
				QueueDebugMessage("INFO: You are in a guild " .. guildName, "debuginfo")
            end
        end
    end)
end)

----------------------------------SerparatorLine--------------------------------------
function CreateSeparatorLine(parent, x, y, width, anchor)
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetHeight(1)
    line:SetWidth(width or 100)
    if anchor then
        line:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", x or 0, y or -6)
    else
        line:SetPoint("TOPLEFT", parent, "TOPLEFT", x or 0, y or 0)
    end
    line:SetTexture("Interface\\Buttons\\WHITE8x8")
    line:SetVertexColor(1, 1, 1, 0.5)
    return line
end

------------------------------------------------------------------------

local combatCheckFrame = CreateFrame("Frame")
combatCheckFrame:SetScript("OnUpdate", nil) 






local isInCombat = false
local retryTimerRunning = false
local lastTimeChecked = 0
local checkInterval = 1 
local incombatmessagesent = false

local function IsAnyRaidMemberInCombat()
    if GetNumRaidMembers() > 0 then
        for i = 1, GetNumRaidMembers() do
            if UnitAffectingCombat("raid"..i) then
                return true 
            end
        end
    end
    return false 
end


function RetryMessageQueueProcessing()
    local currentTime = GetTime()
    
    if currentTime - lastTimeChecked >= checkInterval then
        lastTimeChecked = currentTime 

        if not IsAnyRaidMemberInCombat() then
            DEFAULT_CHAT_FRAME:AddMessage("Resuming..", "none")
            isInCombat = false
            retryTimerRunning = false
			incombatmessagesent = false	
            combatCheckFrame:SetScript("OnUpdate", nil) 
            ProcessMessageQueue()
			ProcessDebugMessageQueue()
        else
           
        end
    end
end
local starterSequenceRunning = false
local continueFillAfterStarter = false
local starterSwapDone = false

local firstBotRemovalFrame = CreateFrame("Frame")
firstBotRemovalFrame:RegisterEvent("RAID_ROSTER_UPDATE")
firstBotRemovalFrame:RegisterEvent("PARTY_MEMBERS_CHANGED")

firstBotRemovalFrame:SetScript("OnEvent", function()
    if not CanManageRaidBots() then
        return
    end

    if starterSequenceRunning then
        return
    end

    if initialBotRemoved then
        return
    end

    if not firstBotName or not totaly or totaly <= 5 then
        return
    end

    if GetNumRaidMembers() >= 3 then
        initialBotRemoved = true
        QueueDebugMessage("Removed first bot: " .. firstBotName, "debugremove")
        UninviteMember(firstBotName, "firstBotRemoved")
    end
end)

local shouldStopBotAdding = false

local restrictionListener = CreateFrame("Frame")
restrictionListener:RegisterEvent("CHAT_MSG_SYSTEM")
restrictionListener:SetScript("OnEvent", function()
    local msg = arg1 
    if msg == "You can only add bots in raid group while you are in an instance map or at world bosses." then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000FillRaidBots: Bot adding stopped. You can only add up to 4 bots in this area.|r")
        shouldStopBotAdding = true
    end
end)

function ProcessMessageQueue()
	
	if next(messageQueue) ~= nil then 
		local messageInfo = table.remove(messageQueue, 1)
		local message = messageInfo.message
		local recipient = messageInfo.recipient


        if shouldStopBotAdding and string.find(message, "%.partybot add") then
            QueueDebugMessage("Blocked queued message due to instance/world boss restriction: " .. message, "debugfilling")
            return
        end
        
        if recipient == "SAY" then
            
            if IsAnyRaidMemberInCombat() then
				if not incombatmessagesent then 
					DEFAULT_CHAT_FRAME:AddMessage("Raid member in combat, waiting..", "none")
					incombatmessagesent = true	
				end	
                isInCombat = true
                if not retryTimerRunning then
                    combatCheckFrame:SetScript("OnUpdate", RetryMessageQueueProcessing)
                    retryTimerRunning = true
                end
                
                table.insert(messageQueue, 1, messageInfo)
                return 
            end
        end

 

        if recipient == "none" then
            
            DEFAULT_CHAT_FRAME:AddMessage(message)
        else
            
            SendChatMessage(message, recipient)
        end		
    end
end


function ProcessDebugMessageQueue()
		if next(DebugMessageQueue) ~= nil then 
		local messageInfo = table.remove(DebugMessageQueue, 1)
		local message = messageInfo.message
		local recipient = messageInfo.recipient

		
		local colors = {
			["error"] = "|cFFFF0000",     
			["warning"] = "|cFFFFA500",  
			["info"] = "|cFFFFFF00",     
			["detected"] = "|cFF00FF00", 
			["added"] = "|cFF00FF00",  
			["adding"] = "|cFF00FF00",  			
			["removing"] = "|cFFADD8E6", 
			["removed"] = "|cFFADD8E6",  
			["fixgroups"] = "|cFFDDA0DD" 
		}
		local resetColor = "|r" 

		
		for keyword, color in pairs(colors) do
			
			message = string.gsub(message, "([%a]+)", function(word)
				if string.lower(word) == keyword then
					return color .. word .. resetColor
				else
					return word
				end
			end)
		end
        
        if recipient == "debug" then
            if FillRaidBotsSavedSettings.debugMessagesEnabled then  
                DebugMessage(message, "debug")
            end
            return 
        end
        if recipient == "debuginfo" then
            if FillRaidBotsSavedSettings.debugMessagesEnabled then  
                DebugMessage(message, "debuginfo")
            end
            return 
        end
        if recipient == "debugfilling" then
            if FillRaidBotsSavedSettings.debugMessagesEnabled then  
                DebugMessage(message, "debugfilling")
            end
            return 
        end
        if recipient == "debugdetection" then
            if FillRaidBotsSavedSettings.debugMessagesEnabled then  
                DebugMessage(message, "debugdetection")
            end
            return 
        end
        if recipient == "debugremove" then
            if FillRaidBotsSavedSettings.debugMessagesEnabled then  
                DebugMessage(message, "debugremove")
            end
            return 
        end	
        if recipient == "debugerror" then
            if FillRaidBotsSavedSettings.debugMessagesEnabled then  
                DebugMessage(message, "debugerror")
            end
            return 
        end	
        if recipient == "debugversion" then
            if FillRaidBotsSavedSettings.debugMessagesEnabled then  
                DebugMessage(message, "debugversion")
            end
            return 
        end
        if recipient == "debugzones" then
            if FillRaidBotsSavedSettings.debugMessagesEnabled then
                DebugMessage(message, "debugzones")
            end
            return
        end
        if recipient == "none" then
            
            DEFAULT_CHAT_FRAME:AddMessage(message)
        elseif recipient == "SAY" or recipient == "YELL" or recipient == "GUILD" or recipient == "PARTY" or recipient == "RAID" or recipient == "WHISPER" then
            
            SendChatMessage(message, recipient)
        else
            DEFAULT_CHAT_FRAME:AddMessage(message)
        end

    end
end

function QueueMessage(message, recipient, incrementBotCount)
    table.insert(messageQueue,
        { message = message, recipient = recipient or "none", incrementBotCount = incrementBotCount or false })
end
function QueueDebugMessage(message, recipient)
    table.insert(DebugMessageQueue,
        { message = message, recipient = recipient or "none" })
end




local RoleDetector = CreateFrame("Frame")
RoleDetector:RegisterEvent("CHAT_MSG_SPELL_HOSTILEPLAYER_BUFF")
RoleDetector:RegisterEvent("UNIT_AURA")
RoleDetector:RegisterEvent("CHAT_MSG_SPELL_SELF_BUFF")
RoleDetector:RegisterEvent("CHAT_MSG_SPELL_PARTY_BUFF")
RoleDetector:RegisterEvent("CHAT_MSG_SPELL_FRIENDLYPLAYER_BUFF")
RoleDetector:RegisterEvent("CHAT_MSG_SPELL_CAST_SUCCESS")
RoleDetector:RegisterEvent("CHAT_MSG_SPELL_AURA_GONE_OTHER")
RoleDetector:RegisterEvent("CHAT_MSG_SPELL_AURA_GONE_SELF")
RoleDetector:RegisterEvent("CHAT_MSG_SPELL_CAST_START")
RoleDetector:RegisterEvent("CHAT_MSG_SPELL_CAST_SUCCESS")
RoleDetector:RegisterEvent("CHAT_MSG_SPELL_DAMAGE")
RoleDetector:RegisterEvent("CHAT_MSG_SPELL_HEAL")
RoleDetector:RegisterEvent("PLAYER_ENTERING_WORLD")
RoleDetector:RegisterEvent("CHAT_MSG_SPELL_FRIENDLYPLAYER_DAMAGE")
RoleDetector:RegisterEvent("CHAT_MSG_SPELL_PARTY_DAMAGE")
RoleDetector:RegisterEvent("CHAT_MSG_COMBAT_PARTY_HITS")

RoleDetector:RegisterEvent("PARTY_MEMBERS_CHANGED")
RoleDetector:RegisterEvent("RAID_ROSTER_UPDATE")


local wasInGroup = false

local spellDictionary = {
    
    ["Defensive Stance"] = {class = "warrior", role = "tank", confidenceIncrease = 3},
    ["Sunder Armor"] = {class = "warrior", role = "tank", confidenceIncrease = 3},
    ["Taunt"] = {class = "warrior", role = "tank", confidenceIncrease = 3},
    ["Revenge"] = {class = "warrior", role = "tank", confidenceIncrease = 3},
    ["Shield Wall"] = {class = "warrior", role = "tank", confidenceIncrease = 3},
    ["Last Stand"] = {class = "warrior", role = "tank", confidenceIncrease = 3},
    ["Shield Block"] = {class = "warrior", role = "tank", confidenceIncrease = 3},
    ["Mocking Blow"] = {class = "warrior", role = "tank", confidenceIncrease = 3},
    ["Greater Armor"] = {class = "warrior", role = "tank", confidenceIncrease = 3},	
   
    ["Mortal Strike"] = {class = "warrior", role = "meleedps", confidenceIncrease = 3},
    ["Bloodthirst"] = {class = "warrior", role = "meleedps", confidenceIncrease = 3},
    ["Whirlwind"] = {class = "warrior", role = "meleedps", confidenceIncrease = 3},

    
    ["Greater Heal"] = {class = "priest", role = "healer", confidenceIncrease = 3},
    ["Prayer of Healing"] = {class = "priest", role = "healer", confidenceIncrease = 3},
    ["Flash Heal"] = {class = "priest", role = "healer", confidenceIncrease = 3},
    ["Heal"] = {class = "priest", role = "healer", confidenceIncrease = 3},
    ["Holy Nova"] = {class = "priest", role = "healer", confidenceIncrease = 3},
    ["Power Word: Shield"] = {class = "priest", role = "healer", confidenceIncrease = 3},
    ["Shadow Word: Pain"] = {class = "priest", role = "rangedps", confidenceIncrease = 3},
    ["Mind Blast"] = {class = "priest", role = "rangedps", confidenceIncrease = 3},
    ["Mind Flay"] = {class = "priest", role = "rangedps", confidenceIncrease = 3},
    ["Shadowform"] = {class = "priest", role = "rangedps", confidenceIncrease = 3},
    ["Vampiric Embrace"] = {class = "priest", role = "rangedps", confidenceIncrease = 3},

    
    ["Bear Form"] = {class = "druid", role = "tank", confidenceIncrease = 3},
    ["Maul"] = {class = "druid", role = "tank", confidenceIncrease = 3},
    ["Growl"] = {class = "druid", role = "tank", confidenceIncrease = 3},
    ["Swipe"] = {class = "druid", role = "tank", confidenceIncrease = 3},
    ["Cat Form"] = {class = "druid", role = "meleedps", confidenceIncrease = 3},
    ["Rake"] = {class = "druid", role = "meleedps", confidenceIncrease = 3},
    ["Ferocious Bite"] = {class = "druid", role = "meleedps", confidenceIncrease = 3},
    ["Shred"] = {class = "druid", role = "meleedps", confidenceIncrease = 3},
    ["Healing Touch"] = {class = "druid", role = "healer", confidenceIncrease = 3},
   
    ["Regrowth"] = {class = "druid", role = "healer", confidenceIncrease = 3},
    ["Tranquility"] = {class = "druid", role = "healer", confidenceIncrease = 3},
    ["Starfire"] = {class = "druid", role = "rangedps", confidenceIncrease = 3},
    ["Moonfire"] = {class = "druid", role = "rangedps", confidenceIncrease = 3},
    ["Hurricane"] = {class = "druid", role = "rangedps", confidenceIncrease = 3},

    
    ["Healing Wave"] = {class = "shaman", role = "healer", confidenceIncrease = 3},
    ["Chain Heal"] = {class = "shaman", role = "healer", confidenceIncrease = 3},
    ["Lesser Healing Wave"] = {class = "shaman", role = "healer", confidenceIncrease = 3},
    ["Lightning Bolt"] = {class = "shaman", role = "rangedps", confidenceIncrease = 3},
    ["Chain Lightning"] = {class = "shaman", role = "rangedps", confidenceIncrease = 3},
    ["Earth Shock"] = {class = "shaman", role = "rangedps", confidenceIncrease = 3},
    ["Flame Shock"] = {class = "shaman", role = "rangedps", confidenceIncrease = 3},
    ["Stormstrike"] = {class = "shaman", role = "meleedps", confidenceIncrease = 3},
    ["Lava Lash"] = {class = "shaman", role = "meleedps", confidenceIncrease = 3},
    ["Windfury Weapon"] = {class = "shaman", role = "meleedps", confidenceIncrease = 3},

    
    ["Holy Light"] = {class = "paladin", role = "healer", confidenceIncrease = 3},
    ["Flash of Light"] = {class = "paladin", role = "healer", confidenceIncrease = 3},
    ["Holy Shock"] = {class = "paladin", role = "healer", confidenceIncrease = 3},
    ["Righteous Fury"] = {class = "paladin", role = "tank", confidenceIncrease = 3},
    ["Seal of Righteousness"] = {class = "paladin", role = "tank", confidenceIncrease = 3},
    ["Shield of the Righteous"] = {class = "paladin", role = "tank", confidenceIncrease = 3},
    ["Consecration"] = {class = "paladin", role = "tank", confidenceIncrease = 3},
    ["Seal of Command"] = {class = "paladin", role = "meleedps", confidenceIncrease = 3},
    ["Crusader Strike"] = {class = "paladin", role = "meleedps", confidenceIncrease = 3},
    ["Judgement of Command"] = {class = "paladin", role = "meleedps", confidenceIncrease = 3},

    
    ["Arcane Missiles"] = {class = "mage", role = "rangedps", confidenceIncrease = 3},
    ["Arcane Power"] = {class = "mage", role = "rangedps", confidenceIncrease = 3},
    ["Arcane Explosion"] = {class = "mage", role = "rangedps", confidenceIncrease = 3},
    ["Fireball"] = {class = "mage", role = "rangedps", confidenceIncrease = 3},
    ["Frostbolt"] = {class = "mage", role = "rangedps", confidenceIncrease = 3},
    ["Ice Armor"] = {class = "mage", role = "rangedps", confidenceIncrease = 3},
    ["Blizzard"] = {class = "mage", role = "rangedps", confidenceIncrease = 3},
    ["Pyroblast"] = {class = "mage", role = "rangedps", confidenceIncrease = 3},
    ["Frost Nova"] = {class = "mage", role = "rangedps", confidenceIncrease = 3},
    ["Cone of Cold"] = {class = "mage", role = "rangedps", confidenceIncrease = 3},
    ["Scorch"] = {class = "mage", role = "rangedps", confidenceIncrease = 3},
    ["Flamestrike"] = {class = "mage", role = "rangedps", confidenceIncrease = 3},
    ["Fire Blast"] = {class = "mage", role = "rangedps", confidenceIncrease = 3},
    ["Ice Block"] = {class = "mage", role = "rangedps", confidenceIncrease = 3},

    
    ["Shadow Bolt"] = {class = "warlock", role = "rangedps", confidenceIncrease = 3},
    ["Incinerate"] = {class = "warlock", role = "rangedps", confidenceIncrease = 3},
    ["Corruption"] = {class = "warlock", role = "rangedps", confidenceIncrease = 3},
    ["Immolate"] = {class = "warlock", role = "rangedps", confidenceIncrease = 3},
    ["Unstable Affliction"] = {class = "warlock", role = "rangedps", confidenceIncrease = 3},
    ["Siphon Life"] = {class = "warlock", role = "rangedps", confidenceIncrease = 3},
    ["Curse of Agony"] = {class = "warlock", role = "rangedps", confidenceIncrease = 3},
    ["Curse of Doom"] = {class = "warlock", role = "rangedps", confidenceIncrease = 3},
    ["Seed of Corruption"] = {class = "warlock", role = "rangedps", confidenceIncrease = 3},
    ["Rain of Fire"] = {class = "warlock", role = "rangedps", confidenceIncrease = 3},
    ["Life Tap"] = {class = "warlock", role = "rangedps", confidenceIncrease = 1},
    ["Hellfire"] = {class = "warlock", role = "rangedps", confidenceIncrease = 3},
    ["Shadowburn"] = {class = "warlock", role = "rangedps", confidenceIncrease = 3},
    ["Death Coil"] = {class = "warlock", role = "rangedps", confidenceIncrease = 3},
    ["Drain Soul"] = {class = "warlock", role = "rangedps", confidenceIncrease = 3},
    ["Drain Life"] = {class = "warlock", role = "rangedps", confidenceIncrease = 3},


    
    ["Stealth"] = {class = "rogue", role = "meleedps", confidenceIncrease = 3},  
    ["Backstab"] = {class = "rogue", role = "meleedps", confidenceIncrease = 3},
    ["Sinister Strike"] = {class = "rogue", role = "meleedps", confidenceIncrease = 3},
    ["Eviscerate"] = {class = "rogue", role = "meleedps", confidenceIncrease = 3},
    ["Ambush"] = {class = "rogue", role = "meleedps", confidenceIncrease = 3},
    ["Slice and Dice"] = {class = "rogue", role = "meleedps", confidenceIncrease = 3},
    ["Gouge"] = {class = "rogue", role = "meleedps", confidenceIncrease = 3},
    ["Hemorrhage"] = {class = "rogue", role = "meleedps", confidenceIncrease = 3},
    ["Rupture"] = {class = "rogue", role = "meleedps", confidenceIncrease = 3},
    ["Kidney Shot"] = {class = "rogue", role = "meleedps", confidenceIncrease = 3},
    ["Expose Armor"] = {class = "rogue", role = "meleedps", confidenceIncrease = 3},
    ["Sprint"] = {class = "rogue", role = "meleedps", confidenceIncrease = 3},
    ["Cloak of Shadows"] = {class = "rogue", role = "meleedps", confidenceIncrease = 3},
    ["Vanish"] = {class = "rogue", role = "meleedps", confidenceIncrease = 3},
    ["Distract"] = {class = "rogue", role = "meleedps", confidenceIncrease = 3},
    ["Shadowstep"] = {class = "rogue", role = "meleedps", confidenceIncrease = 3},
    ["Preparation"] = {class = "rogue", role = "meleedps", confidenceIncrease = 3},
    ["Blind"] = {class = "rogue", role = "meleedps", confidenceIncrease = 3},

    
    
    ["Aimed Shot"] = {class = "hunter", role = "rangedps", confidenceIncrease = 3},
    ["Multi-Shot"] = {class = "hunter", role = "rangedps", confidenceIncrease = 3},
    ["Arcane Shot"] = {class = "hunter", role = "rangedps", confidenceIncrease = 3},
    ["Explosive Shot"] = {class = "hunter", role = "rangedps", confidenceIncrease = 3},
    ["Serpent Sting"] = {class = "hunter", role = "rangedps", confidenceIncrease = 3},
    ["Scatter Shot"] = {class = "hunter", role = "rangedps", confidenceIncrease = 3},
    ["Feign Death"] = {class = "hunter", role = "rangedps", confidenceIncrease = 3},
    ["Steady Shot"] = {class = "hunter", role = "rangedps", confidenceIncrease = 3},
    ["Rapid Fire"] = {class = "hunter", role = "rangedps", confidenceIncrease = 3},
    ["Kill Command"] = {class = "hunter", role = "rangedps", confidenceIncrease = 3},
    ["Viper Sting"] = {class = "hunter", role = "rangedps", confidenceIncrease = 3},
    ["Hunter's Mark"] = {class = "hunter", role = "rangedps", confidenceIncrease = 3},
    ["Volley"] = {class = "hunter", role = "rangedps", confidenceIncrease = 3},
   
}


local patterns = {
    "^(.-) begins to cast",            
    "^(.-) casts",                     
    "fades from (.+)$",                
    "^(.-)'s ",                        
    "^(.-) gains",                     
    "^(.-) deals",                     
    "^(.-) hits",                      
    "^(.-) suffers",                   
    "^(.-) is hit by",                 
    "^(.-) heals",                     
    "^(.-) receives healing from",     
    "^(.-) crits",                     
    "^(.-) absorbs",                   
    "^(.-) resists",                   
}


local playerData = playerData or {}
local detectedPlayers = detectedPlayers or {}  
local detectedPlayerCount = detectedPlayerCount or 0

function extractPlayerName(message)
    for _, pattern in ipairs(patterns) do
        local startIdx, endIdx, name = string.find(message, pattern)
        if startIdx then 
            return name or string.sub(message, startIdx, endIdx) 
        end
    end
    return nil
end


local function normalizePlayerName(playerName)
    if type(playerName) ~= "string" then
        return nil
    end

    local cleanName = ""
    for i = 1, string.len(playerName) do
        local char = string.sub(playerName, i, i)
        if (char >= "a" and char <= "z") or 
           (char >= "A" and char <= "Z") or 
           (char >= "0" and char <= "9") or 
           char == "*" then
            cleanName = cleanName .. string.lower(char)
        end
    end

    return cleanName
end


local classColors = {
    warrior = "|cFFC79C6E",
    mage = "|cFF40C7EB",
    warlock = "|cFF8788EE",
    hunter = "|cFFABD473",
    rogue = "|cFFFFF569",
    paladin = "|cFFF58CBA",
    shaman = "|cFF0070DE",
    druid = "|cFFFF7D0A",
    priest = "|cFFFFFFFF",
}

local resetColor = "|r"

local function GetColoredClass(classRole)
    if not classRole then return "" end

    
    classRole = string.gsub(classRole, "^%s*(.-)%s*$", "%1")

    
    local spacePos = string.find(classRole, " ")

    local class
    if spacePos then
        class = string.sub(classRole, 1, spacePos - 1)
    else
        class = classRole
    end

    local lower = string.lower(class)

    
    local display = string.upper(string.sub(lower, 1, 1)) ..
                    string.sub(lower, 2)

    local color = classColors[lower]

    if color then
        return color .. display .. resetColor
    end

    return display
end


local function updateRoleConfidence(playerName, class, role, confidenceIncrease, spell)

    local normalizedPlayerName = normalizePlayerName(playerName)
    if not normalizedPlayerName then return end  

    local coloredClass = GetColoredClass(class)
    local plainClass = string.lower(class or "")

    local data = playerData[normalizedPlayerName] or {
        classColored = coloredClass,
        ClassNoColor = plainClass,
        role = role,
        roleConfidence = 0
    }

    data.roleConfidence = data.roleConfidence + confidenceIncrease

    if data.roleConfidence >= 3 then
        if not detectedPlayers[normalizedPlayerName] then
            detectedPlayers[normalizedPlayerName] = true
            detectedPlayerCount = detectedPlayerCount + 1

            QueueDebugMessage(
                "Detected:" .. detectedPlayerCount ..
                " - " .. playerName ..
                " is a " .. coloredClass ..
                " (" .. role .. ") using: " .. spell,
                "debugdetection"
            )
        end
    else
        QueueDebugMessage(
            "INFO: Updated confidence for " .. playerName ..
            ": " .. data.roleConfidence,
            "debugdetection"
        )
    end

    playerData[normalizedPlayerName] = data
end

local function isBotNameInGroup(playerName)
    local normalizedPlayerName = normalizePlayerName(playerName)
    
    if GetNumRaidMembers() > 0 then
        for i = 1, GetNumRaidMembers() do
            local name = GetRaidRosterInfo(i)
            if name and normalizePlayerName(name) == normalizedPlayerName then
                return true
            end
        end
    else
        for i = 1, GetNumPartyMembers() do
            local name = UnitName("party" .. i)
            if name and normalizePlayerName(name) == normalizedPlayerName then
                return true
            end
        end
    end
    return false
end


local function DetectRole()
    if not CanManageRaidBots() then
        return
    end

    if type(arg1) ~= "string" then return end  

    
    if string.find(arg1, "gains %d+ Mana") or string.find(arg1, "gains %d+ Rage") or string.find(arg1, "gains %d+ Energy") or string.find(arg1, "gain Rejuvenation") then
        return  
    end

    local playerName = extractPlayerName(arg1)
    if not playerName then return end  

    
    local normalizedPlayerName = normalizePlayerName(playerName)
    if not normalizedPlayerName then return end  

    
    if detectedPlayers[normalizedPlayerName] or not isBotNameInGroup(normalizedPlayerName) then
        return
    end

    
    for spell, details in pairs(spellDictionary) do
        if string.find(arg1, spell) then
            updateRoleConfidence(playerName, details.class, details.role, details.confidenceIncrease, spell)
            return  
        end
    end
end




local buffIconMap = {
    ["Greater Armor"] = "Interface\\Icons\\Inv_potion_86",  
    ["Ice Armor"] = "Interface\\Icons\\Spell_Frost_FrostArmor02",  
}

local warriorDetectionCount = {}
local function CheckRaidAuras()
    if not CanManageRaidBots() then
        return
    end

    local playerName = UnitName("player")  

    for i = 1, GetNumRaidMembers() do
        local unitId = "raid" .. i
        local unitName = UnitName(unitId)

        if unitName and unitName ~= playerName then  
            local unitClass, _ = UnitClass(unitId)  
            unitClass = string.lower(unitClass or "")  

            local hasTankBuff = false  

            
            if not detectedPlayers[unitName] then
                if unitClass == "mage" or unitClass == "warlock" or unitClass == "hunter" then
                    detectedPlayers[unitName] = true  
                    updateRoleConfidence(unitName, unitClass, "rangedps", 3, "Class Detection")
                elseif unitClass == "rogue" then
                    detectedPlayers[unitName] = true  
                    updateRoleConfidence(unitName, unitClass, "meleedps", 3, "Class Detection")
                end
            end

            
            for j = 1, 16 do
                local buffTexture = UnitBuff(unitId, j)
                if not buffTexture then break end  

                
                

                
                if buffTexture == "Interface\\Icons\\INV_Potion_86" then
                    hasTankBuff = true  
                    if not detectedPlayers[unitName] then
                       
                        detectedPlayers[unitName] = true  
                        updateRoleConfidence(unitName, unitClass, "tank", 3, "Greater Armor")
                    end
                end

                
               
               
               
               
               
               
               
            end

            
            if unitClass == "warrior" and not hasTankBuff and not detectedPlayers[unitName] then
                if not warriorDetectionCount[unitName] then
                    warriorDetectionCount[unitName] = 1  
                else
                    warriorDetectionCount[unitName] = warriorDetectionCount[unitName] + 1  
                end

                
                if warriorDetectionCount[unitName] >= 10 then
                    detectedPlayers[unitName] = true  
                    updateRoleConfidence(unitName, "warrior", "meleedps", 3, "Checked 5 times")
                    warriorDetectionCount[unitName] = nil  
                end
            end
        end
    end
end


RoleDetector:SetScript("OnEvent", function()
    if event == "PARTY_MEMBERS_CHANGED" or event == "RAID_ROSTER_UPDATE" then
        wasInGroup = GetNumPartyMembers() > 0 or GetNumRaidMembers() > 0
    elseif event == "UNIT_AURA" then
        CheckRaidAuras()
    else
      
        DetectRole()
    end
end)

SLASH_SHOWUNDETECTED1 = "/showundetected"  
local b = "0"
local function ShowUndetectedPlayers()
    local playerName = UnitName("player")
    local undetectedPlayers = {}
    local undetectedCount = 0
    local detectedCount = 0


    if GetNumRaidMembers() > 0 then
        for i = 1, GetNumRaidMembers() do
            local unitId = "raid" .. i
            local unitName = UnitName(unitId)
            if unitName and unitName ~= playerName then
                local normalizedName = normalizePlayerName(unitName)

                if detectedPlayers[normalizedName] then
                    detectedCount = detectedCount + 1
                else
                    undetectedCount = undetectedCount + 1
                    table.insert(undetectedPlayers, unitName) 
                end
            end
        end
    else

        for i = 1, GetNumPartyMembers() do
            local unitId = "party" .. i
            local unitName = UnitName(unitId)
            if unitName and unitName ~= playerName then
                local normalizedName = normalizePlayerName(unitName)

                if detectedPlayers[normalizedName] then
                    detectedCount = detectedCount + 1
                else
                    undetectedCount = undetectedCount + 1
                    table.insert(undetectedPlayers, unitName) 
                end
            end
        end
    end


    QueueDebugMessage("INFO: Detected players: " .. detectedCount, "debuginfo")
    QueueDebugMessage("INFO: Undetected players: " .. undetectedCount, "debuginfo")


    if undetectedCount > 0 then
        QueueDebugMessage("INFO: The following players are undetected:", "debuginfo")
        for _, name in ipairs(undetectedPlayers) do
            QueueDebugMessage("- " .. name, "debuginfo")
        end
    else
        QueueDebugMessage("INFO: All players in the group have been detected.", "debuginfo")
    end
end



SlashCmdList["SHOWUNDETECTED"] = ShowUndetectedPlayers


local RoleRemoverFrame = CreateFrame("Frame")

RoleRemoverFrame:RegisterEvent("PARTY_MEMBERS_CHANGED")
RoleRemoverFrame:RegisterEvent("RAID_ROSTER_UPDATE")

local wasInGroup = false

local groupMembers = {}
local ReplaceDeadBot = {}

local function UpdateGroupMembers()
    
    groupMembers = {}

    
    for i = 1, GetNumPartyMembers() do
        local name = UnitName("party" .. i)
        if name then
            groupMembers[normalizePlayerName(name)] = true
        end
    end

    
    for i = 1, GetNumRaidMembers() do
        local name = UnitName("raid" .. i)
        if name then
            groupMembers[normalizePlayerName(name)] = true
        end
    end
end


UpdateGroupMembers()


RoleRemoverFrame:SetScript("OnEvent", function()
    
    local oldGroupMembers = groupMembers

    
    UpdateGroupMembers()
    UpdateReFillButtonVisibility()  

    
    local isInParty = GetNumPartyMembers() > 0
    local isInRaid = GetNumRaidMembers() > 0
    if wasInGroup and not isInParty and not isInRaid then
        ReplaceDeadBot = {}
        UpdateReFillButtonVisibility()
        resetData()  
        QueueDebugMessage("Cleared both lists", "debugdetection")
    end

    
    wasInGroup = isInParty or isInRaid

    
    for name in pairs(oldGroupMembers) do
        local normalizedName = normalizePlayerName(name)

        
        if not groupMembers[normalizedName] then
            
            if detectedPlayers[normalizedName] then
                QueueDebugMessage("Removed: " .. normalizedName .. " from detected player list!", "debugremove")
                detectedPlayers[normalizedName] = nil
				detectedPlayerCount = detectedPlayerCount -1
            end

            
            if playerData[normalizedName] then
                QueueDebugMessage("Removed: " .. normalizedName .. " from active player list!", "debugremove")
                playerData[normalizedName] = nil
            end
        end
    end
end)



local alreadyRemoved = alreadyRemoved or {}

local function markAsRemoved(name, timeout)
    alreadyRemoved[name] = true
    local clearFrame = CreateFrame("Frame")
    local started = GetTime()
    clearFrame:SetScript("OnUpdate", function()
        if GetTime() - started >= (timeout or 15) then
            alreadyRemoved[name] = nil
            this:SetScript("OnUpdate", nil)
            this:Hide()
        end
    end)
end

function UninviteMember(name, reason)
    local normalizedName = normalizePlayerName(name)
    if not normalizedName then
        QueueDebugMessage("ERROR: Could not normalize name for UninviteMember", "debugerror")
        return
    end

    if alreadyRemoved[normalizedName] then
        return
    end
    markAsRemoved(normalizedName)

    if playerData[normalizedName] then
        ReplaceDeadBot[normalizedName] = playerData[normalizedName]
        playerData[normalizedName] = nil
    else
        QueueDebugMessage("WARNING: Player not found in playerData: " .. normalizedName, "debugremove")
    end

    SendChatMessage(".partybot remove " .. tostring(name), "GUILD")

    local retryName = normalizedName
    local retryFrame = CreateFrame("Frame")
    local retryStart = GetTime()
    retryFrame:SetScript("OnUpdate", function()
        if GetTime() - retryStart >= 0.75 then
            SendChatMessage(".partybot remove " .. retryName, "GUILD")
            this:SetScript("OnUpdate", nil)
            this:Hide()
        end
    end)

    if reason == "dead" then
        QueueDebugMessage(normalizedName .. " has been uninvited because they are dead.", "debugremove")
    elseif reason == "firstBotRemoved" then
        QueueDebugMessage("Removing party bot: " .. tostring(name), "debugremove")
        firstBotName = nil
        ReplaceDeadBot[normalizedName] = nil
        initialBotRemoved = true
    else
        QueueDebugMessage(normalizedName .. " has been uninvited.", "debugremove")
    end
end
function resetData()
    playerData = {}  
    detectedPlayers = {}  
    detectedPlayerCount = 0  
    QueueDebugMessage("INFO: All player data has been reset.", "debuginfo")
end

SLASH_ROLELIST1 = "/rolelist"
SlashCmdList["ROLELIST"] = function()
    QueueDebugMessage("INFO: Player Role List:", "debuginfo")
    local count = 0

    
    for playerName, data in pairs(playerData) do
        count = count + 1
        QueueDebugMessage(count .. ". " .. playerName .. " - Class: " .. data.classColored .. ", Role: " .. data.role, "debuginfo")
    end

end


SLASH_REPLACELIST1 = "/replacelist"
SlashCmdList["REPLACELIST"] = function()
    if next(ReplaceDeadBot) == nil then
        QueueDebugMessage("Replaced Bot List is empty.", "debuginfo")
    else
        QueueDebugMessage("Replaced Bot List:", "debuginfo")
        for playerName, data in pairs(ReplaceDeadBot) do
            QueueDebugMessage(playerName .. " - Class: " .. data.classColored .. ", Role: " .. data.role, "debuginfo")
           
        end

    end
end


local messagecantremove = false

local hasWarnedNoPermission = false
local messagecantremove = false
local guildDeadStatus = {}

local function isBotName(name)
	return name and string.sub(name, -1) == "*"
end

function CanManageRaidBots()
    if GetNumRaidMembers() > 0 then
        return IsRaidLeader() or IsRaidOfficer()
    elseif GetNumPartyMembers() > 0 then
        return IsPartyLeader()
    end

    return true
end

local function WarnNoBotManagementPermission(actionText)
    if hasWarnedNoPermission then
        return
    end

    QueueDebugMessage("WARNING: You must be party leader, raid leader, or raid assistant to " .. (actionText or "manage bots") .. ".", "debuginfo")
    hasWarnedNoPermission = true
end

local function CheckAndRemoveDeadBots(force)
    if not force and (not FillRaidBotsSavedSettings or not FillRaidBotsSavedSettings.isCheckAndRemoveEnabled) then
		return
	end

	local raidCount = GetNumRaidMembers()
	local partyCount = GetNumPartyMembers()

	
	if not CanManageRaidBots() then
		WarnNoBotManagementPermission("remove bots")
		return
	end
	hasWarnedNoPermission = false

	
	realPlayerStatus = realPlayerStatus or {}

	local function debug(msg)
		if FillRaidBotsSavedSettings.debugMode then
			QueueDebugMessage(msg, "debuginfo")
		end
	end



	-- =========================
	-- RAID LOGIC
	-- =========================
	if raidCount > 0 then
		if raidCount > 2 then
			for i = 1, raidCount do
				local unit = "raid" .. i
				if UnitExists(unit) then
					local name = UnitName(unit)
					if name then
						if isBotName(name) then
							if UnitIsDead(unit)
							and not UnitIsGhost(unit)
							and UnitIsConnected(unit) then
								QueueDebugMessage("Removing dead bot: " .. name, "debuginfo")
								UninviteMember(name, "dead")
							elseif UnitIsDead(unit) and not UnitIsConnected(unit) then
								QueueDebugMessage("Cannot kick offline bot: " .. name, "debuginfo")
							end
						else
							
							if not realPlayerStatus[name] then
								QueueDebugMessage("Found " .. name .. " (real player).", "debuginfo")
								realPlayerStatus[name] = true
							end
						end
					end
				end
			end
			messagecantremove = false
		elseif not messagecantremove then
			QueueDebugMessage("Saving the last bot so the raid does not disband.", "debuginfo")
			messagecantremove = true
		end

	-- =========================
	-- PARTY LOGIC
	-- =========================
	elseif partyCount > 0 then
		for i = 1, partyCount do
			local unit = "party" .. i
			if UnitExists(unit) then
				local name = UnitName(unit)
				if name then
					if isBotName(name) then
						if UnitIsDead(unit)
						and not UnitIsGhost(unit)
						and UnitIsConnected(unit) then
							QueueDebugMessage("Removing dead bot: " .. name)
							UninviteMember(name, "dead")
						elseif UnitIsDead(unit) and not UnitIsConnected(unit) then
							QueueDebugMessage("Cannot kick offline bot: " .. name)
						end
					else
						if not realPlayerStatus[name] then
							QueueDebugMessage("Keeping " .. name .. " (real player).")
							realPlayerStatus[name] = true
						end
					end
				end
			end
		end
	end
end

local function SaveRaidMembersAndSetFirstBot()
	local raidMembers = {}
	local playerName = UnitName("player")
	firstBotName = nil


	for i = 1, GetNumRaidMembers() do
		local unit = "raid" .. i
		local name = UnitName(unit)

		if name and name ~= playerName then
			if isBotName(name) then
				if not firstBotName then
					firstBotName = name
					QueueDebugMessage("INFO: First raid bot set to: " .. firstBotName, "debuginfo")
				end
				table.insert(raidMembers, name)
			else
				QueueDebugMessage("INFO: " .. name .. " is not marked as a bot (no *), skipping!", "debuginfo")
			end
		end
	end

	if not firstBotName then
		QueueDebugMessage("ERROR: No first bot found (only real players detected)", "debugerror")
	end

	
	return raidMembers
end



local function SavePartyMembersAndSetFirstBot()
    local partyMembers = {}
    local playerName = UnitName("player")
    firstBotName = nil


    
    for i = 1, GetNumPartyMembers() do
        local unit = "party" .. i
        local name = UnitName(unit)
        if name and name ~= playerName then
            if isBotName(name) then
                if not firstBotName then
                    firstBotName = name
                    QueueDebugMessage("INFO: First party bot set to: " .. firstBotName, "debuginfo")
                end
                table.insert(partyMembers, name)
            else
                QueueDebugMessage("INFO: " .. name .. " is not marked as a bot (no *), skipping!", "debuginfo")
            end
        end
    end

    if not firstBotName then
        QueueDebugMessage("ERROR: No first party bot found (only real players detected)", "debugerror")
    end

    
    return partyMembers
end





local function ResetStarterSequenceState()
    starterSequenceRunning = false
    continueFillAfterStarter = false
    starterSwapDone = false
    initialBotRemoved = false
    firstBotName = nil
    botCount = 0
end

function resetfirstbot_OnEvent()
    if event == "RAID_ROSTER_UPDATE" or event == "PARTY_MEMBERS_CHANGED" then
        if GetNumPartyMembers() == 0 and GetNumRaidMembers() == 0 then
            ResetStarterSequenceState()
            QueueDebugMessage("INFO: Bot state reset: No members in party or raid.", "debuginfo")
        end
    end
end


local function GetSelectedLootMethod()
    if FillRaidBotsSavedSettings.isFFAEnabled then
        return "freeforall"
    elseif FillRaidBotsSavedSettings.isGroupLootEnabled then
        return "group"
    elseif FillRaidBotsSavedSettings.isMasterLootEnabled then
        return "master"
    end
end

--==================================================
-- Apply loot method with delay (WoW 1.12.1)
--==================================================
local lootApplyTimerRunning = false
local lastAppliedLootMethod = nil

local function ResetLootApplyState()
    if GetNumPartyMembers() == 0 and GetNumRaidMembers() == 0 then
        lootApplyTimerRunning = false
        lastAppliedLootMethod = nil
    end
end

local function ApplySavedLootMethod()
	if not isLootTypeEnabled then return end

    if lootApplyTimerRunning then
        return
    end

    if not FillRaidBotsSavedSettings then
        return
    end

    lootApplyTimerRunning = true

    local timerFrame = CreateFrame("Frame")
    local startTime = GetTime()
    local delay = 0.3

    timerFrame:SetScript("OnUpdate", function()
        if GetTime() - startTime >= delay then
            timerFrame:SetScript("OnUpdate", nil)
            lootApplyTimerRunning = false

            if not CanManageRaidBots() then
                timerFrame:Hide()
                return
            end

            local desiredMethod = GetSelectedLootMethod()
            local currentMethod = GetLootMethod()

            if not desiredMethod then
                timerFrame:Hide()
                return
            end

            if desiredMethod == currentMethod and lastAppliedLootMethod == desiredMethod then
                timerFrame:Hide()
                return
            end

            if desiredMethod == "master" then
                if currentMethod ~= "master" then
                    SetLootMethod("master", UnitName("player"))
                    DEFAULT_CHAT_FRAME:AddMessage("Loot set to Master Loot")
                end
            elseif desiredMethod == "group" then
                if currentMethod ~= "group" then
                    SetLootMethod("group")
                    DEFAULT_CHAT_FRAME:AddMessage("Loot set to Group Loot")
                end
            elseif desiredMethod == "freeforall" then
                if currentMethod ~= "freeforall" then
                    SetLootMethod("freeforall")
                    DEFAULT_CHAT_FRAME:AddMessage("Loot set to FFA")
                end
            end

            lastAppliedLootMethod = desiredMethod
            timerFrame:Hide()
        end
    end)
end


local resetBotFrame = CreateFrame("Frame")
resetBotFrame:RegisterEvent("RAID_ROSTER_UPDATE")
resetBotFrame:RegisterEvent("PARTY_MEMBERS_CHANGED")

resetBotFrame:SetScript("OnEvent", function()
    resetfirstbot_OnEvent()
    ResetLootApplyState()
    CheckAndRemoveDeadBots()
    ApplySavedLootMethod()
end)



local function OnUpdate()
  if GetTime() >= nextUpdateTime then
      ProcessMessageQueue()
	  ProcessDebugMessageQueue()
	  CheckAndRemoveDeadBots() 
      nextUpdateTime = GetTime() + delay 
  end
end

local updateFrame = CreateFrame("Frame")
updateFrame:SetScript("OnUpdate", OnUpdate)
nextUpdateTime = GetTime() 

function FillRaid_OnLoad()
  this:RegisterEvent("PLAYER_LOGIN")
  this:RegisterEvent("PLAYER_ENTERING_WORLD")
  this:RegisterEvent('RAID_ROSTER_UPDATE')
  this:RegisterEvent('GROUP_ROSTER_UPDATE')
  this:RegisterEvent("ADDON_LOADED")
  this:RegisterEvent("CHAT_MSG_SYSTEM")
  QueueDebugMessage("FillRaidBots [" .. versionNumber .. "]|cff00FF00 loaded|cffffffff", "none")
  factionName, factionGroup = UnitFactionGroup("player")
end


local originalSoundVolume = nil
local restoreFrame = CreateFrame("Frame")
restoreFrame:Hide()

local restoreStartTime = 0
local restoreDelay = 2

restoreFrame:SetScript("OnUpdate", function()
	if GetTime() - restoreStartTime >= restoreDelay then
		SetCVar("SoundVolume", originalSoundVolume)
		QueueDebugMessage("Sound volume restored.", "debuginfo")
		originalSoundVolume = nil
		restoreFrame:Hide()
	end
end)

function ToggleSoundEffectsVolume(action)
	if action == "lower" then
		if not originalSoundVolume then
			originalSoundVolume = GetCVar("SoundVolume")
			SetCVar("SoundVolume", "0.1")
			QueueDebugMessage("Sound volume lowered.", "debuginfo")
		else
			QueueDebugMessage("Sound already lowered.", "debuginfo")
		end

	elseif action == "restore" then
		if originalSoundVolume then
			QueueDebugMessage("Restoring sound in 2 seconds...", "debuginfo")
			restoreStartTime = GetTime()
			restoreFrame:Show()
		else
			QueueDebugMessage("No volume to restore.", "debuginfo")
		end

	end
end





------------------------------------------------------FILLRAID WICH CALLS FIXGROUPS-------------------------------------------------------------------------


local MAX_PLAYERS_PER_GROUP = 5
local MAX_GROUPS = 8
local isFixingGroups = false
local moveDelay = 0.1 
local lastMoveTime = 0
local moveQueue = {} 
local healerClasses = {"PALADIN", "PRIEST", "DRUID", "SHAMAN"} 
local currentPhase = 1
local FixGroups
local FillRaid
local pendingAddOthersFunc = nil
local pendingAddOthersStarted = false

local function TakeNextPresetBot(healers, others)
    if table.getn(healers) > 0 then
        return table.remove(healers, 1)
    end

    if table.getn(others) > 0 then
        return table.remove(others, 1)
    end

    return nil
end

local function GroupHasAnyBot()
    local playerName = UnitName("player")

    if GetNumRaidMembers() > 0 then
        local i
        for i = 1, GetNumRaidMembers() do
            local name = UnitName("raid" .. i)
            if name and name ~= playerName and isBotName(name) then
                return true
            end
        end
    else
        local i
        for i = 1, GetNumPartyMembers() do
            local name = UnitName("party" .. i)
            if name and name ~= playerName and isBotName(name) then
                return true
            end
        end
    end

    return false
end

local function StartStarterSequenceDelay(seconds, callback)
    local timerFrame = CreateFrame("Frame")
    local startTime = GetTime()
    timerFrame:SetScript("OnUpdate", function()
        if GetTime() - startTime >= seconds then
            this:SetScript("OnUpdate", nil)
            this:Hide()
            callback()
        end
    end)
    timerFrame:Show()
end

local function StartStarterBotSequence(healers, others)
    hasWarnedNoPermission = false

    if starterSequenceRunning then
        return
    end

    starterSequenceRunning = true
    continueFillAfterStarter = false
    initialBotRemoved = false

    local starterFrame = CreateFrame("Frame")
    local stage = 1
    local invitedStarterBot = false
    local replacementBot = nil
    local stage3StartMembers = 0
    local stage3StartedAt = nil
    local stage5Ready = false

    starterFrame:SetScript("OnUpdate", function()
        if stage == 1 then
            if GetNumRaidMembers() > 0 then
                
                
                SaveRaidMembersAndSetFirstBot()

                if firstBotName then
                    QueueDebugMessage("Using existing raid bot as starter bot: " .. firstBotName, "debugfilling")
                    stage = 3
                else
                    QueueDebugMessage("Starter sequence aborted: no existing raid bot found to replace.", "debugerror")
                    ResetStarterSequenceState()
                    this:SetScript("OnUpdate", nil)
                    this:Hide()
                end

            elseif GetNumPartyMembers() == 0 then
                if not invitedStarterBot then
                    QueueMessage(".partybot add warrior tank", "SAY", true)
                    QueueDebugMessage("Inviting the first bot to start the party for a raid.", "debugfilling")
                    invitedStarterBot = true
                end

                if GetNumPartyMembers() > 0 then
                    SavePartyMembersAndSetFirstBot()
                    if firstBotName then
                        QueueDebugMessage("Starter bot joined. Saved first bot.", "debugfilling")
                        stage = 2
                    end
                end

            else
                
                SavePartyMembersAndSetFirstBot()

                if firstBotName then
                    QueueDebugMessage("Using existing party bot as starter bot: " .. firstBotName, "debugfilling")
                    stage = 2
                else
                    QueueDebugMessage("Starter sequence aborted: no existing party bot found to replace.", "debugerror")
                    ResetStarterSequenceState()
                    this:SetScript("OnUpdate", nil)
                    this:Hide()
                end
            end

        elseif stage == 2 then
            if GetNumRaidMembers() == 0 then
                if GetNumPartyMembers() > 0 then
                    ConvertToRaid()
                    QueueDebugMessage("Converted to raid.", "debugfilling")
                    stage = 3
                end
            else
                stage = 3
            end

        elseif stage == 3 then
            if GetNumRaidMembers() > 0 then
                replacementBot = TakeNextPresetBot(healers, others)

                if replacementBot then
                    stage3StartMembers = GetNumRaidMembers()
                    QueueMessage(".partybot add " .. string.lower(replacementBot), "SAY", true)
                    QueueDebugMessage("Added replacement bot: " .. replacementBot, "debugfilling")
                    stage = 4
                else
                    QueueDebugMessage("No preset bot available for starter sequence.", "debugfilling")
                    ResetStarterSequenceState()
                    this:SetScript("OnUpdate", nil)
                    this:Hide()
                end
            end

        elseif stage == 4 then
            local currentMembers = GetNumRaidMembers()
            local replacementJoined = nil

            if replacementBot and playerData then
                local normalizedReplacement = normalizePlayerName(replacementBot)
                if normalizedReplacement then
                    replacementJoined = playerData[normalizedReplacement] ~= nil
                end
            end

            if replacementJoined or currentMembers >= (stage3StartMembers + 1) then
                if firstBotName and not initialBotRemoved then
                    initialBotRemoved = true
                    QueueDebugMessage("Removed starter bot: " .. firstBotName, "debuginfo")
                    UninviteMember(firstBotName, "firstBotRemoved")
                end

                stage = 5
                StartStarterSequenceDelay(1, function()
                    continueFillAfterStarter = true
                    stage5Ready = true
                end)
            end

        elseif stage == 5 then
            if continueFillAfterStarter and stage5Ready then
                local remainingTotal = table.getn(healers) + table.getn(others)
                ResetStarterSequenceState()
                starterSwapDone = true
                this:SetScript("OnUpdate", nil)
                this:Hide()
                FillRaid(true, healers, others, remainingTotal)
            end
        end
    end)

    starterFrame:Show()
end

FillRaid = function(skipStarterSequence, existingHealers, existingOthers, existingTotal)
    hasWarnedNoPermission = false

    shouldStopBotAdding = false
    local healers = existingHealers or {}
    local others = existingOthers or {}
    local totalHealers = 0
    local totalOthers = 0

    if not skipStarterSequence then
        starterSwapDone = false
    end

    ToggleSoundEffectsVolume("lower")

    if existingHealers and existingOthers then
        totalHealers = table.getn(healers)
        totalOthers = table.getn(others)
        totaly = existingTotal or (totalHealers + totalOthers)
    else
        for class, count in pairs(classCounts) do
            if string.find(class, "healer") then
                local i
                for i = 1, count do
                    table.insert(healers, class)
                end
                totalHealers = totalHealers + count
            else
                local i
                for i = 1, count do
                    table.insert(others, class)
                end
                totalOthers = totalOthers + count
            end
        end

        totaly = totalHealers + totalOthers
    end

    local totalToAdd = totaly

    if GetNumRaidMembers() > 0 then
        if not starterSwapDone and totalToAdd > 0 and GroupHasAnyBot() then
            if not firstBotName then
                SaveRaidMembersAndSetFirstBot()
            end
            StartStarterBotSequence(healers, others)
            return
        end
    else
        local currentMembers = GetNumPartyMembers() + 1
        local targetGroupSize = currentMembers + totalToAdd

        if targetGroupSize > 5 then
            if GetNumPartyMembers() == 0 then
                StartStarterBotSequence(healers, others)
                return
            elseif GroupHasAnyBot() then
                if not firstBotName then
                    SavePartyMembersAndSetFirstBot()
                end
                StartStarterBotSequence(healers, others)
                return
            else
                ConvertToRaid()
                QueueDebugMessage("Converted to raid with real players only. No starter bot needed.", "debugfilling")

                local _, healer
                for _, healer in ipairs(healers) do
                    QueueMessage(".partybot add " .. string.lower(healer), "SAY", true)
                end

                local _, other
                for _, other in ipairs(others) do
                    QueueMessage(".partybot add " .. string.lower(other), "SAY", true)
                end

                local restoreSoundFrame = CreateFrame("Frame")
                local restoreElapsed = 0
                restoreSoundFrame:SetScript("OnUpdate", function()
                    restoreElapsed = restoreElapsed + arg1
                    if restoreElapsed >= 3 then
                        this:SetScript("OnUpdate", nil)
                        this:Hide()
                        ToggleSoundEffectsVolume("restore")
                    end
                end)
                restoreSoundFrame:Show()
                return
            end
        end

        if GetNumPartyMembers() == 0 then
            QueueDebugMessage("Creating a party group.", "none")

            local _, healer
            for _, healer in ipairs(healers) do
                QueueMessage(".partybot add " .. string.lower(healer), "SAY", true)
            end

            local _, other
            for _, other in ipairs(others) do
                QueueMessage(".partybot add " .. string.lower(other), "SAY", true)
            end

            local restoreSoundFrame = CreateFrame("Frame")
            local restoreElapsed = 0
            restoreSoundFrame:SetScript("OnUpdate", function()
                restoreElapsed = restoreElapsed + arg1
                if restoreElapsed >= 3 then
                    this:SetScript("OnUpdate", nil)
                    this:Hide()
                    ToggleSoundEffectsVolume("restore")
                end
            end)
            restoreSoundFrame:Show()
            return
        end

        if GetNumPartyMembers() >= 2 then
            ConvertToRaid()
            QueueDebugMessage("Converted to raid.", "debugfilling")
        else
            QueueDebugMessage("You need at least 2 players in the group to convert to a raid.", "debugfilling")
            return
        end
    end

    totalHealers = totalHealers or 0
    totalOthers = totalOthers or 0

    QueueDebugMessage("Added: Going to add healers:" .. totalHealers, "debugfilling")
    QueueDebugMessage("Added: Going to add classes:" .. totalOthers, "debugfilling")
    QueueDebugMessage("Added: Totaly:" .. totaly, "debugfilling")

    
    local function countTableEntries(tbl)
        local count = 0
        for _ in pairs(tbl) do
            count = count + 1
        end
        return count
    end

local function FinalizeFillCheck(totalExpected)
    local fillCompleteFrame = CreateFrame("Frame")
    local startTime = GetTime()
    local MAX_WAIT_TIME = 40
    local CHECK_INTERVAL = 1
    local GRACE_TIME = 3
    local STALL_TIMEOUT = 10

    local lastCheckTime = GetTime()
    local lastMemberCount = 0
    local timeOfLastProgress = GetTime()
    local combatPaused = false
    local pausedStartTime = 0
    local totalPauseTime = 0

    fillCompleteFrame:SetScript("OnUpdate", function()
        local now = GetTime()
        local expectedTotal = totalExpected
        if now - lastCheckTime < CHECK_INTERVAL then return end
        lastCheckTime = now

        local currentMembers = GetNumRaidMembers()
        QueueDebugMessage("Checking fill: " .. currentMembers .. "/" .. expectedTotal, "debugfilling")

       
        local inCombatNow = IsAnyRaidMemberInCombat()
        if inCombatNow and not combatPaused then
            combatPaused = true
            pausedStartTime = now
            QueueDebugMessage("Raid filling paused - group members in combat.", "debugfilling")
        elseif not inCombatNow and combatPaused then
            totalPauseTime = totalPauseTime + (now - pausedStartTime)
            pausedStartTime = 0
            combatPaused = false
            lastMemberCount = -1
            QueueDebugMessage("Combat ended, resuming raid fill checks.", "debugfilling")
        end

       
        local dynamicPause = 0
        if combatPaused and pausedStartTime > 0 then
            dynamicPause = now - pausedStartTime
        end
        local elapsed = now - startTime - totalPauseTime - dynamicPause
        local sinceLastProgress = now - timeOfLastProgress
        QueueDebugMessage(string.format("Elapsed: %.1fs / %ds (adjusted), %.1fs since last progress", elapsed, MAX_WAIT_TIME, sinceLastProgress), "debugfilling")

       
        if currentMembers > lastMemberCount then
            timeOfLastProgress = now
        end
        lastMemberCount = currentMembers

       
        if currentMembers >= expectedTotal then
            fillCompleteFrame:SetScript("OnUpdate", nil)
            fillCompleteFrame:Hide()
            QueueDebugMessage("Raid filling complete. Total members: " .. currentMembers, "none")
            ToggleSoundEffectsVolume("restore")
            return
        end

       
        if not inCombatNow and elapsed >= MAX_WAIT_TIME and sinceLastProgress >= STALL_TIMEOUT then
            fillCompleteFrame:SetScript("OnUpdate", nil)
            fillCompleteFrame:Hide()
            if shouldStopBotAdding then
                QueueDebugMessage("Bot adding stopped due to instance/world boss restriction", "debuginfo")
            else
                QueueDebugMessage("Raid filling incomplete. Only " .. currentMembers .. "/" .. expectedTotal .. " members joined. Possibly due to combat, lag, or restrictions.", "none")
            end
            ToggleSoundEffectsVolume("restore")
            return
        end
    end)

    fillCompleteFrame:Show()
end




    local function addBot(class)
        local classColors = {
            warrior = "|cFFC79C6E",   
            mage = "|cFF40C7EB",      
            warlock = "|cFF8788EE",   
            hunter = "|cFFABD473",    
            rogue = "|cFFFFF569",     
            paladin = "|cFFF58CBA",   
            shaman = "|cFF0070DE",    
            druid = "|cFFFF7D0A",     
            priest = "|cFFFFFFFF",    
        }
        local resetColor = "|r"  

        local plainClass = string.lower(class)

        
        local coloredClass = class
        for className, color in pairs(classColors) do
            if string.find(plainClass, className) then
                coloredClass = string.gsub(class, className, color .. className .. resetColor)
                break
            end
        end

        
        QueueMessage(".partybot add " .. plainClass, "SAY", true)
        QueueDebugMessage("Added " .. coloredClass, "debugfilling")
    end

    
    local function addothers()
        QueueDebugMessage("addothers called", "debuginfo")

        
        local otherClassesCount = countTableEntries(others)
        if otherClassesCount == 0 then
            QueueDebugMessage("No other classes to add.", "debugfilling")
            return
        end

        
		local totalBots = 0
		for _, _ in pairs(others) do
			totalBots = totalBots + 1
		end
		local botsAdded = 0
		for _, otherClass in pairs(others) do
			addBot(otherClass)
			botsAdded = botsAdded + 1
			if botsAdded == totalBots then
				FinalizeFillCheck(totaly)
			end
		end
    end

    
    if totalHealers == 0 then
        QueueDebugMessage("No healers found. Skipping healer addition.", "debugfilling")
        addothers()
        return
    end

    
    local totalHealersAdded = 0
    for _, healerClass in ipairs(healers) do
        addBot(healerClass)
        totalHealersAdded = totalHealersAdded + 1

        
        if totalHealersAdded == totalHealers then
            
            local waitForHealersFrame = CreateFrame("Frame")
            waitForHealersFrame:SetScript("OnUpdate", function()
				if GetNumRaidMembers() >= totalHealers + 1 then
					waitForHealersFrame:SetScript("OnUpdate", nil)
					waitForHealersFrame:Hide()
					QueueDebugMessage("Fixgroups: All healers are in the raid. Starting FixGroups after 1-second delay.", "debuginfo")

					
					local fixGroupsDelayTimer = CreateFrame("Frame")
					local fixGroupsStartTime = GetTime()
					fixGroupsDelayTimer:SetScript("OnUpdate", function()
						if GetTime() - fixGroupsStartTime >= 1 then
							fixGroupsDelayTimer:SetScript("OnUpdate", nil)
							fixGroupsDelayTimer:Hide()

							
							isFixingGroups = true
							currentPhase = 1
							lastMoveTime = 0
							moveQueue = {}
							pendingAddOthersFunc = addothers
							pendingAddOthersStarted = false
							FixGroups()
						end
					end)
					fixGroupsDelayTimer:Show()
				end

            end)
            waitForHealersFrame:Show()
            break
        end
    end
end


-------------------------fixgroups ------------------------------------------
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


local function TableContains(tbl, value)
    for _, v in pairs(tbl) do
        if v == value then
            return true
        end
    end
    return false
end

local function ProcessMoveQueue()
    local currentTime = GetTime() 
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
            QueueDebugMessage("Fixgroups: Phase 1 complete, starting Phase 2", "debuginfo")
            currentPhase = 2
            FixGroups()
        else
            QueueDebugMessage("Fixgroups: Phase 2 complete, groups organized", "debuginfo")
            isFixingGroups = false

            if pendingAddOthersFunc and not pendingAddOthersStarted then
                pendingAddOthersStarted = true
                QueueDebugMessage("Added: Adding other classes after healer grouping completed.", "debugfilling")
                pendingAddOthersFunc()
                pendingAddOthersFunc = nil
            end
        end
    end
end


function FixGroups()
    hasWarnedNoPermission = false

    local groupSizes = {}
    local groupClasses = {}
    local healers = {}

    for i = 1, MAX_GROUPS do
        groupSizes[i] = 0
        groupClasses[i] = {}
    end

    local playerName = UnitName("player")

    for i = 1, GetNumRaidMembers() do
        local name, _, subgroup, _, _, class, _, online = GetRaidRosterInfo(i)

        if subgroup and subgroup >= 1 and subgroup <= MAX_GROUPS then
            groupSizes[subgroup] = groupSizes[subgroup] + 1
        end

        if name ~= playerName and class and TableContains(healerClasses, class) then
            if subgroup and subgroup >= 1 and subgroup <= MAX_GROUPS and not TableContains(groupClasses[subgroup], class) then
                table.insert(groupClasses[subgroup], class)
            end

            if isBotName(name) then
                local player = {name = name, index = i, group = subgroup, class = class, online = online, moved = false}
                table.insert(healers, player)
            end
        end
    end

    local maxGroups = (totaly <= 20) and 4 or MAX_GROUPS

    if currentPhase == 1 then
        local healersByClass = {}
        local groupIndex = 1
        local class
        local classHealers
        local healer
        local attempts

        for _, healer in ipairs(healers) do
            if not healersByClass[healer.class] then
                healersByClass[healer.class] = {}
            end
            table.insert(healersByClass[healer.class], healer)
        end

        for class, classHealers in pairs(healersByClass) do
            QueueDebugMessage("Class: " .. class .. " has " .. table.getn(classHealers) .. " healers", "debuginfo")
        end

        for class, classHealers in pairs(healersByClass) do
            for _, healer in ipairs(classHealers) do
                attempts = 0

                while TableContains(groupClasses[groupIndex], healer.class) and groupIndex <= maxGroups do
                    groupIndex = math.mod(groupIndex, maxGroups) + 1
                    attempts = attempts + 1

                    if attempts > 20 then
                        QueueDebugMessage("Error: Too many attempts to find a group for healer " .. healer.name .. " (" .. healer.class .. ")", "debugerror")
                        break
                    end
                end

                if attempts > 20 then
                    QueueDebugMessage("Error: Unable to assign healer " .. healer.name .. " (" .. healer.class .. ") after 20 attempts.", "debugerror")
                else
                    QueueMove(healer, groupIndex)
                    groupSizes[groupIndex] = groupSizes[groupIndex] + 1
                    table.insert(groupClasses[groupIndex], healer.class)
                    QueueDebugMessage("Assigned healer " .. healer.name .. " to group " .. groupIndex, "debuginfo")
                end

                groupIndex = math.mod(groupIndex, maxGroups) + 1
            end
        end

    elseif currentPhase == 2 then
        local healersByClass = {}
        local healerCountsByGroup = {}
        local classOrder = {"PALADIN", "DRUID", "PRIEST", "SHAMAN"}
        local classIndex
        local className
        local classHealers
        local groupIndex
        local startGroup
        local minCount
        local i
        local name
        local subgroup
        local class
        local isMovableBotHealer

        for i = 1, maxGroups do
            healerCountsByGroup[i] = 0
        end

        for _, healer in ipairs(healers) do
            if not healersByClass[healer.class] then
                healersByClass[healer.class] = {}
            end
            table.insert(healersByClass[healer.class], healer)
        end

        
        
        for i = 1, GetNumRaidMembers() do
            name, _, subgroup, _, _, class = GetRaidRosterInfo(i)

            if name ~= playerName and class and TableContains(healerClasses, class) then
                isMovableBotHealer = isBotName(name)

                if subgroup and subgroup >= 1 and subgroup <= maxGroups and not isMovableBotHealer then
                    healerCountsByGroup[subgroup] = healerCountsByGroup[subgroup] + 1
                end
            end
        end

        local function GetLeastHealerGroup()
            local bestGroup = 1
            local bestCount = healerCountsByGroup[1] or 0
            local g

            for g = 2, maxGroups do
                if (healerCountsByGroup[g] or 0) < bestCount then
                    bestGroup = g
                    bestCount = healerCountsByGroup[g] or 0
                end
            end

            return bestGroup
        end

        for classIndex = 1, table.getn(classOrder) do
            className = classOrder[classIndex]
            classHealers = healersByClass[className]

            if classHealers and table.getn(classHealers) > 0 then
                startGroup = GetLeastHealerGroup()
                groupIndex = startGroup
                minCount = healerCountsByGroup[startGroup] or 0

                QueueDebugMessage("Phase 2: Starting class " .. className .. " at group " .. startGroup .. " (lowest healer count: " .. minCount .. ")", "debuginfo")

                for _, healer in ipairs(classHealers) do
                    QueueMove(healer, groupIndex)
                    healerCountsByGroup[groupIndex] = healerCountsByGroup[groupIndex] + 1

                    QueueDebugMessage("Rebalanced healer " .. healer.name .. " to group " .. groupIndex, "debuginfo")

                    groupIndex = math.mod(groupIndex, maxGroups) + 1
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
-------------------------------help buttons -----------------------------
local function CreateHelpButton(parentFrame, relativeFrame, offsetX, offsetY, tooltipText, buttonText)
    local helpBtn = CreateFrame("Button", nil, parentFrame)
    helpBtn:SetWidth(16)
    helpBtn:SetHeight(16)
    helpBtn:SetPoint("LEFT", relativeFrame, "RIGHT", offsetX, offsetY)

   
    helpBtn:SetNormalTexture("Interface\\Icons\\INV_Misc_QuestionMark")

   
    helpBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")
    helpBtn:GetHighlightTexture():SetBlendMode("ADD")

   
    helpBtn:SetScript("OnEnter", function()
        GameTooltip:SetOwner(helpBtn, "ANCHOR_RIGHT")
        GameTooltip:SetText(buttonText)
        GameTooltip:AddLine(tooltipText, 1,1,1)
        GameTooltip:Show()
    end)

    helpBtn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

   
    helpBtn:SetScript("OnClick", function()
        PlaySound("igMainMenuOptionCheckBoxOn")
    end)

    return helpBtn
end
----------------------------------------------------------THE UI------------------------------------------------------------------------------------
local function ShowStaticPopup(message, title, isConfirmation)
    StaticPopupDialogs["FILLRAID_GENERIC_POPUP"] = {
        text = message,
        button1 = "Yes",
        button2 = "No",
        OnAccept = function()
            if isConfirmation then
                ReloadUI() 
            end
        end,
        OnCancel = function()
           
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 4,
    }

    if not isConfirmation then
       
        StaticPopupDialogs["FILLRAID_GENERIC_POPUP"].button1 = "OK"
        StaticPopupDialogs["FILLRAID_GENERIC_POPUP"].button2 = nil
    end

	local popup = StaticPopup_Show("FILLRAID_GENERIC_POPUP", title)

	if popup then
		popup:ClearAllPoints()
		popup:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
	end
end


function CreateFillRaidUI()
    FillRaidFrame = CreateFrame("Frame", "FillRaidFrame", UIParent) 
    FillRaidFrame:SetWidth(310)
    FillRaidFrame:SetHeight(450)
    FillRaidFrame:SetPoint("CENTER", UIParent, "CENTER")
    FillRaidFrame:SetMovable(true)
    FillRaidFrame:EnableMouse(true)
    FillRaidFrame:RegisterForDrag("LeftButton")
    FillRaidFrame:SetScript("OnDragStart", FillRaidFrame.StartMoving)
    FillRaidFrame:SetScript("OnDragStop", FillRaidFrame.StopMovingOrSizing)

    FillRaidFrame:SetScript("OnMouseDown", function()
        if arg1 == "LeftButton" and not this.isMoving then
            this:StartMoving()
            this.isMoving = true
        end
    end)
    FillRaidFrame:SetScript("OnMouseUp", function()
        if arg1 == "LeftButton" and this.isMoving then
            this:StopMovingOrSizing()
            this.isMoving = false
        end
    end)
    table.insert(UISpecialFrames, "FillRaidFrame")

    FillRaidFrame:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    FillRaidFrame:SetBackdropColor(0, 0, 0, 1) 

    local versionText = FillRaidFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    versionText:SetPoint("BOTTOMRIGHT", FillRaidFrame, "BOTTOMRIGHT", -10, 8)
    versionText:SetJustifyH("RIGHT")
    function newversion(newVersionDetected)
        if newVersionDetected then
            versionText:SetText("You are running:" .. versionNumber .. " - Update available: " .. newVersionDetected)
        else
            versionText:SetText("Version: " .. versionNumber)
        end
    end

    FillRaidBotsVersionText = versionText

    local versionClickButton = CreateFrame("Button", "FillRaidBotsVersionClickButton", FillRaidFrame)
    versionClickButton:SetPoint("TOPLEFT", versionText, "TOPLEFT", -4, 2)
    versionClickButton:SetPoint("BOTTOMRIGHT", versionText, "BOTTOMRIGHT", 4, -2)
    versionClickButton:EnableMouse(true)
    versionClickButton:RegisterForClicks("LeftButtonUp")
    versionClickButton:SetScript("OnClick", function()
        if ShowUpdateVersionPopup then
            ShowUpdateVersionPopup()
        end
    end)
    versionClickButton:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_TOPLEFT")
        GameTooltip:SetText("Click to show update info.")
        GameTooltip:Show()
    end)
    versionClickButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

	FillRaidFrame.header = FillRaidFrame:CreateTexture(nil, 'ARTWORK')
	FillRaidFrame.header:SetWidth(250)
	FillRaidFrame.header:SetHeight(64)
	FillRaidFrame.header:SetPoint('TOP', FillRaidFrame, 0, 18)
	FillRaidFrame.header:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
	FillRaidFrame.header:SetVertexColor(.2, .2, .2)

	FillRaidFrame.headerText = FillRaidFrame:CreateFontString(nil, 'ARTWORK', 'GameFontNormal')
	FillRaidFrame.headerText:SetPoint('TOP', FillRaidFrame.header, 0, -14)
	FillRaidFrame.headerText:SetText('Fill Raid')


local yOffset = -30
local xOffset = 10
local totalBots = 0


local raid20Zones = {
    ["Zul'Gurub"] = true,
    ["Ruins of Ahn'Qiraj"] = true,
}

local raid15Zones = {
    ["Blackrock Spire"] = true,
    ["Lower Blackrock Spire"] = true,
    ["Upper Blackrock Spire"] = true,
}

local dungeonZones = {
    ["Ragefire Chasm"] = true,
    ["Wailing Caverns"] = true,
    ["The Deadmines"] = true,
    ["Shadowfang Keep"] = true,
    ["Blackfathom Deeps"] = true,
    ["The Stockade"] = true,
    ["Gnomeregan"] = true,
    ["Razorfen Kraul"] = true,
    ["Scarlet Monastery"] = true,
    ["Razorfen Downs"] = true,
    ["Uldaman"] = true,
    ["Zul'Farrak"] = true,
    ["Maraudon"] = true,
    ["The Temple of Atal'Hakkar"] = true,
    ["Blackrock Depths"] = true,
    ["Dire Maul"] = true,
    ["Scholomance"] = true,
    ["Stratholme"] = true,
}

local raid40Zones = {
    ["Molten Core"] = true,
    ["Blackwing Lair"] = true,
    ["Ahn'Qiraj"] = true,
    ["Naxxramas"] = true,
    ["Onyxia's Lair"] = true,
}

local worldBossSubZones = {
    ["The Tainted Scar"] = true,
    ["Dream Bough"] = true,
    ["Bough Shadow"] = true,
    ["Seradane"] = true,
    ["Twilight Grove"] = true,
    ["The Crystal Vale"] = true,
}

local lastZoneDebugText = nil

local function GetMaxBotsForCurrentZone()
    local zone = GetRealZoneText()
    local subZone = GetSubZoneText()
    local maxBots
    local debugText

    if raid20Zones[zone] then
        maxBots = 19
    elseif raid15Zones[zone] then
        maxBots = 14
    elseif dungeonZones[zone] then
        maxBots = 9
    elseif raid40Zones[zone] then
        maxBots = 39
    elseif worldBossSubZones[subZone] then
        maxBots = 39
    elseif zone == "Azshara" and (not subZone or subZone == "") then
        maxBots = 39
    else
        maxBots = 4
    end

    debugText = "Zone: " .. (zone or "nil") .. " | SubZone: " .. (subZone or "nil") .. " | Max bots: " .. maxBots
    if debugText ~= lastZoneDebugText then
        lastZoneDebugText = debugText
        QueueDebugMessage(debugText, "debugzones")
    end

    return maxBots
end

local function IsBotName(name)
    return name and string.find(name, "%*") ~= nil
end

local function GetOtherRealPlayerCount()
    local count = 0
    local playerName = UnitName("player")
    local numRaidMembers = GetNumRaidMembers and GetNumRaidMembers() or 0
    local numPartyMembers = GetNumPartyMembers and GetNumPartyMembers() or 0

    if numRaidMembers > 0 then
        local i
        for i = 1, numRaidMembers do
            local name = GetRaidRosterInfo(i)
            if name and name ~= playerName and not IsBotName(name) then
                count = count + 1
            end
        end
    else
        local i
        for i = 1, numPartyMembers do
            local name = UnitName("party" .. i)
            if name and name ~= playerName and not IsBotName(name) then
                count = count + 1
            end
        end
    end

    return count
end

    
    local totalBotLabel = FillRaidFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    totalBotLabel:SetPoint("TOP", FillRaidFrame, "TOP", 0, yOffset)
    totalBotLabel:SetText("Total Bots: 0")
    yOffset = yOffset - 25

    
    local spotsLeftLabel = FillRaidFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    spotsLeftLabel:SetPoint("TOP", FillRaidFrame, "TOP", 0, yOffset)
    spotsLeftLabel:SetText("Spots left: " .. math.max(0, GetMaxBotsForCurrentZone() - GetOtherRealPlayerCount())) 
    yOffset = yOffset - 25

    
    local roleCountsLabel = FillRaidFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    roleCountsLabel:SetPoint("TOP", FillRaidFrame, "TOP", 0, yOffset)
    roleCountsLabel:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    roleCountsLabel:SetText("Tanks: 0 Healers: 0 Melee DPS: 0 Ranged DPS: 0")
    yOffset = yOffset - 30

    local function UpdateSpotsLeft()
        local maxBots = GetMaxBotsForCurrentZone()
        local otherRealPlayers = GetOtherRealPlayerCount()
        local allowedBots = math.max(0, maxBots - otherRealPlayers)
        local botsLeftToAdd = math.max(0, allowedBots - totalBots)

        if totalBots <= allowedBots then
            totalBotLabel:SetText("Total Bots: " .. totalBots)
            spotsLeftLabel:SetText("Spots left: " .. botsLeftToAdd)
        else
            totalBotLabel:SetText("Too many: |cffff0000" .. totalBots .. "|r")
            spotsLeftLabel:SetText("Spots left: 0")
        end
    end

    FillRaidFrame.UpdateSpotsLeft = UpdateSpotsLeft

    local columns = 2
    local rowsPerColumn = 14
    local columnWidth = 150
    local rowHeight = 0
	local groupGap = 6
    local roleIcons = {
        ["tank"] = "Interface\\Icons\\Ability_Defend",
        ["meleedps"] = "Interface\\Icons\\Ability_DualWield",
        ["rangedps"] = "Interface\\Icons\\Ability_Marksmanship",
        ["healer"] = "Interface\\Icons\\Spell_Holy_Heal",
    }

    local roleCounts = {
        ["tank"] = 0,
        ["healer"] = 0,
        ["meleedps"] = 0,
        ["rangedps"] = 0,
    }

    local inputBoxes = {}

    
    
    
    local GetPresetValues
    local GetTutorialLinksForPlayer
    local GetTutorialLinkInfoForPreset
    local EnsureTutorialLinkPopup
    local ShowTutorialLinkPopup

    
    
    
    local currentLoadedPreset = nil

    function ReapplyCurrentPreset()
        local selectedValues
        local classRole
        local inputBox
        local value
        local onTextChanged

        if not currentLoadedPreset then
            return
        end

        for classRole, inputBox in pairs(inputBoxes) do
            if inputBox then
                inputBox:SetNumber(0)
                onTextChanged = inputBox:GetScript("OnTextChanged")
                if onTextChanged then
                    onTextChanged(inputBox)
                end
            end
        end

        selectedValues = GetPresetValues(currentLoadedPreset)
        if not selectedValues then
            return
        end

        for classRole, value in pairs(selectedValues) do
            inputBox = inputBoxes[classRole]
            if inputBox then
                inputBox:SetNumber(value)
                onTextChanged = inputBox:GetScript("OnTextChanged")
                if onTextChanged then
                    onTextChanged(inputBox)
                end
            end
        end

        if currentPresetLabel and currentLoadedPreset.label then
            currentPresetLabel:SetText("Preset: " .. currentLoadedPreset.label)
            currentPresetName = currentLoadedPreset.label
        end
    end

    local function SplitClassRole(classRole)
        local spaceIndex = string.find(classRole, " ")
        if spaceIndex then
            local class = string.sub(classRole, 1, spaceIndex - 1)
            local role = string.sub(classRole, spaceIndex + 1)
            return class, role
        end
        return classRole, nil
    end

local WaitForFactionFrame = CreateFrame("Frame")
WaitForFactionFrame:RegisterEvent("PLAYER_LOGIN")

WaitForFactionFrame:SetScript("OnEvent", function()
    if event == "PLAYER_LOGIN" then
        local currentColumn = 0
        local currentRowInColumn = 0
        local classGroupYOffset = yOffset 
        local lastClass = nil

        for i, classRole in ipairs(classes) do
            local class, role = SplitClassRole(classRole)
            local faction = UnitFactionGroup("player")

            if not ((faction == "Alliance" and class == "shaman") or (faction == "Horde" and class == "paladin")) then

               
                if lastClass ~= class then
                   
                    if currentRowInColumn > 0 then
                        classGroupYOffset = classGroupYOffset - groupGap
                        currentRowInColumn = currentRowInColumn + 1
                    end

                   
                    if currentRowInColumn >= rowsPerColumn then
                        currentColumn = currentColumn + 1
                        currentRowInColumn = 0
                        classGroupYOffset = yOffset 
                    end

                    local classXOffset = xOffset + (currentColumn * columnWidth)

                    CreateSeparatorLine(FillRaidFrame, classXOffset, classGroupYOffset - 12, columnWidth - 10)

                   
                    local classHeader = FillRaidFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                    classHeader:SetPoint("TOPLEFT", FillRaidFrame, "TOPLEFT", classXOffset, classGroupYOffset)
                    classHeader:SetText(strupper(string.sub(class, 1, 1)) .. string.sub(class, 2))

                   
                    classGroupYOffset = classGroupYOffset - 18
                    currentRowInColumn = currentRowInColumn + 1

                    lastClass = class
                end

               
                local classXOffset = xOffset + (currentColumn * columnWidth)

               
                local roleIcon = FillRaidFrame:CreateTexture(nil, "OVERLAY")
                roleIcon:SetPoint("TOPLEFT", FillRaidFrame, "TOPLEFT", classXOffset, classGroupYOffset + 2)
                roleIcon:SetWidth(12)
                roleIcon:SetHeight(12)
                roleIcon:SetTexture(roleIcons[role] or "Interface\\Icons\\INV_Misc_QuestionMark")

               
                local classLabel = FillRaidFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                classLabel:SetPoint("TOPLEFT", FillRaidFrame, "TOPLEFT", classXOffset + 16, classGroupYOffset + 2)
                classLabel:SetText(class .. " " .. (role or ""))

               
                local classInput = CreateFrame("EditBox", classRole .. "Input", FillRaidFrame, "InputBoxTemplate")
                classInput:SetWidth(25)
                classInput:SetHeight(14)
                classInput:SetPoint("TOPLEFT", FillRaidFrame, "TOPLEFT", classXOffset + 110, classGroupYOffset + 1)
                classInput:SetNumeric(true)
                classInput:SetNumber(0)
                classInput:SetAutoFocus(false)
                classInput:SetScript("OnEscapePressed", function()
                    openFillRaid()
                end)

                inputBoxes[classRole] = classInput

                local className = classRole

                classInput:SetScript("OnTextChanged", function()
                    local newValue = tonumber(classInput:GetText()) or 0
                    classCounts[className] = newValue

                    totalBots = 0
                    roleCounts["tank"] = 0
                    roleCounts["healer"] = 0
                    roleCounts["meleedps"] = 0
                    roleCounts["rangedps"] = 0

                    for role, _ in pairs(roleCounts) do
                        for clsRole, count in pairs(classCounts) do
                            if string.find(clsRole, role) then
                                roleCounts[role] = roleCounts[role] + count
                            end
                        end
                    end

                    for _, count in pairs(classCounts) do
                        totalBots = totalBots + count
                    end

                    roleCountsLabel:SetText(string.format(
                        "Tanks: %d Healers: %d Melee DPS: %d Ranged DPS: %d",
                        roleCounts["tank"], roleCounts["healer"],
                        roleCounts["meleedps"], roleCounts["rangedps"]
                    ))

                    UpdateSpotsLeft()
                end)

               
                classGroupYOffset = classGroupYOffset - 18
                currentRowInColumn = currentRowInColumn + 1
            end
        end
    end
end)




	  local fillRaidButton = CreateFrame("Button", nil, FillRaidFrame, "GameMenuButtonTemplate")
	  fillRaidButton:SetPoint("BOTTOM", FillRaidFrame, "BOTTOM", -60, 20)
	  fillRaidButton:SetWidth(120)
	  fillRaidButton:SetHeight(40)
	  fillRaidButton:SetText("Fill Raid")

	  fillRaidButton:SetScript("OnClick", function()
		  FillRaid()
		  ReplaceDeadBot = {}
		  resetData()
		  UpdateReFillButtonVisibility()		  
		  FillRaidFrame:Hide()  
	  end)



	  local closeButton = CreateFrame("Button", nil, FillRaidFrame, "GameMenuButtonTemplate")
	  closeButton:SetPoint("BOTTOM", FillRaidFrame, "BOTTOM", 60, 20)
	  closeButton:SetWidth(120)
	  closeButton:SetHeight(40)
	  closeButton:SetText("Close")
	  closeButton:SetScript("OnClick", function()
		  FillRaidFrame:Hide()
		  fillRaidFrameManualClose = true 
	  end)

    if not FillRaidBotsZoneFrame then
        FillRaidBotsZoneFrame = CreateFrame("Frame")
        FillRaidBotsZoneFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
        FillRaidBotsZoneFrame:RegisterEvent("ZONE_CHANGED")
        FillRaidBotsZoneFrame:RegisterEvent("ZONE_CHANGED_INDOORS")
        FillRaidBotsZoneFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
        FillRaidBotsZoneFrame:SetScript("OnEvent", function()
            if FillRaidFrame and FillRaidFrame.UpdateSpotsLeft then
                FillRaidFrame.UpdateSpotsLeft()
            end
        end)
    end


	  
	local UISettingsFrame = CreateFrame("Frame", "UISettingsFrame", UIParent)
	UISettingsFrame:SetWidth(200)
	UISettingsFrame:SetHeight(30)
	UISettingsFrame:SetPoint("LEFT", FillRaidFrame, "RIGHT", 10, 0)
	UISettingsFrame:SetBackdrop({
		bgFile = "Interface/Buttons/WHITE8X8", 
		edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
		tile = true, tileSize = 16, edgeSize = 16,
		insets = { left = 4, right = 4, top = 4, bottom = 4 }
	})
	UISettingsFrame:SetBackdropColor(0, 0, 0, 1)
	UISettingsFrame:SetFrameStrata("DIALOG")
	UISettingsFrame:SetFrameLevel(10)
	UISettingsFrame:SetMovable(true)
	UISettingsFrame:EnableMouse(true)
	UISettingsFrame:RegisterForDrag("LeftButton")

	UISettingsFrame:SetScript("OnDragStart", function()
		UISettingsFrame:StartMoving()
	end)	
	UISettingsFrame:SetScript("OnDragStop", function()
		UISettingsFrame:StopMovingOrSizing()	
	end)	
	UISettingsFrame:Hide() 
	table.insert(UISpecialFrames, "UISettingsFrame")
	local openSettingsButton = CreateFrame("Button", "OpenSettingsButton", FillRaidFrame, "GameMenuButtonTemplate")
	openSettingsButton:SetWidth(80)
	openSettingsButton:SetHeight(20)
	openSettingsButton:SetText("Settings")
	openSettingsButton:SetPoint("TOPLEFT", FillRaidFrame, "TOPLEFT", 10, -10) 
	openSettingsButton:SetScript("OnClick", function()
	
		if UISettingsFrame:IsShown() then
			UISettingsFrame:Hide()
			ClickBlockerFrame:Hide() 
		else
			UISettingsFrame:Show()
			ClickBlockerFrame:Show()
		end
	end)


    local saveButton = CreateFrame("Button", "SaveButton", FillRaidFrame, "GameMenuButtonTemplate")
    saveButton:SetText("Save")
	saveButton:SetWidth(80)
	saveButton:SetHeight(20)
	saveButton:Hide()
	saveButton:SetPoint("BOTTOM", FillRaidFrame, "BOTTOM", -90, 60)
   
    saveButton:SetScript("OnClick", function()
       
        SavePresetValues() 
    end)

   
    saveButton:SetScript("OnEnter", function()
        GameTooltip:SetOwner(saveButton, "ANCHOR_RIGHT")
        GameTooltip:SetText("Click to save current preset values")
        GameTooltip:Show()
    end)

    saveButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

local KEY_ESCAPE = 27
local KEY_ENTER = 13


local PresetPopup = CreateFrame("Frame", "PresetPopupFrame", UIParent)
PresetPopup:SetWidth(300)
PresetPopup:SetHeight(250)
PresetPopup:SetPoint("CENTER", UIParent, "CENTER")
PresetPopup:SetFrameStrata("DIALOG")
PresetPopup:SetBackdrop({
    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
})
PresetPopup:SetBackdropColor(0, 0, 0, 1)
PresetPopup:Hide()

PresetPopup:SetMovable(true)
PresetPopup:EnableMouse(true)
PresetPopup:RegisterForDrag("LeftButton")


PresetPopup:SetScript("OnDragStart", function()
    this:StartMoving()
end)


PresetPopup:SetScript("OnDragStop", function()
    this:StopMovingOrSizing()
end)


local function CreateButton(parent, width, height, point, text)
    local button = CreateFrame("Button", nil, parent)
    button:SetWidth(width)
    button:SetHeight(height)
    button:SetPoint(point, parent, "CENTER")
    
   
    local normalTexture = button:CreateTexture()
    normalTexture:SetTexture("Interface/Buttons/UI-Panel-Button-Up")
    normalTexture:SetTexCoord(0, 0.625, 0, 0.6875)
    normalTexture:SetAllPoints()
    button:SetNormalTexture(normalTexture)
    
   
    local pushedTexture = button:CreateTexture()
    pushedTexture:SetTexture("Interface/Buttons/UI-Panel-Button-Down")
    pushedTexture:SetTexCoord(0, 0.625, 0, 0.6875)
    pushedTexture:SetAllPoints()
    button:SetPushedTexture(pushedTexture)

   
    local highlightTexture = button:CreateTexture()
    highlightTexture:SetTexture("Interface/Buttons/UI-Panel-Button-Highlight")
    highlightTexture:SetTexCoord(0, 0.625, 0, 0.6875)
    highlightTexture:SetAllPoints()
    button:SetHighlightTexture(highlightTexture)
    
   
    local buttonText = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    buttonText:SetPoint("CENTER", button, "CENTER")
    buttonText:SetText(text)
    buttonText:SetTextColor(1, 1, 1)
    
    return button
end


local function CreateInputBox(parent, point, autoFocus)
    local inputBox = CreateFrame("EditBox", nil, parent)
    inputBox:SetWidth(180)
    inputBox:SetHeight(20)
    inputBox:SetPoint("LEFT", parent, "LEFT", 20, 0)
    inputBox:SetAutoFocus(autoFocus)
    inputBox:SetFontObject(GameFontNormal)
    inputBox:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    inputBox:SetBackdropColor(0, 0, 0, 0.5)
    inputBox:SetBackdropBorderColor(0.6, 0.6, 0.6)
    inputBox:SetTextInsets(6, 6, 3, 3)

    return inputBox
end

local popupLabel = PresetPopup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
popupLabel:SetPoint("TOP", PresetPopup, "TOP", 0, -10)


local helpButton = CreateHelpButton(PresetPopup, popupLabel, 10, 0, "Enter name:\n  - Preset name to save the current setup\n\nBoss names:\n  - Name of the boss or mob for the Ctrl+Alt+Click function\n\nTip:\n  - Hold Alt and click a mob to add it to the list.", "Preset Help")


local presetInput = CreateInputBox(PresetPopup, "TOP", true)
presetInput:SetPoint("TOP", popupLabel, "BOTTOM", 0, -5)

local bossInput = CreateInputBox(PresetPopup, "TOP", false)
bossInput:SetWidth(120)
bossInput:SetPoint("TOPLEFT", presetInput, "BOTTOMLEFT", 0, -10)

local bossInputLabel = PresetPopup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
bossInputLabel:SetPoint("BOTTOMLEFT", bossInput, "TOPLEFT", 0, 2)
bossInputLabel:SetText("Boss Names or Zone: (optional)")

local addBossButton = CreateButton(PresetPopup, 60, 20, "LEFT", "Add")
addBossButton:SetPoint("LEFT", bossInput, "RIGHT", 5, 0)

local addZoneButton = CreateButton(PresetPopup, 60, 20, "LEFT", "Zone")
addZoneButton:SetPoint("LEFT", addBossButton, "RIGHT", 5, 0)


local bossListScrollFrame = CreateFrame("ScrollFrame", "BossListScrollFrame", PresetPopup, "UIPanelScrollFrameTemplate")
bossListScrollFrame:SetPoint("TOPLEFT", 10, -80)
bossListScrollFrame:SetPoint("BOTTOMRIGHT", -30, 40)

local bossListScrollChild = CreateFrame("Frame", "BossListScrollChild", bossListScrollFrame)
bossListScrollChild:SetWidth(200)
bossListScrollChild:SetHeight(1)
bossListScrollFrame:SetScrollChild(bossListScrollChild)

local currentBosses = {}
local bossListItems = {}


local function tableSize(t)
    local count = 0
    for _ in pairs(t) do
        count = count + 1
    end
    return count
end


function RefreshBossList()
   
    for i = 1, tableSize(bossListItems) do
        local item = bossListItems[i]
        if item and item.frame then 
            item.frame:Hide() 
            item.frame:SetParent(nil) 
        end
    end
    bossListItems = {}
    
    local itemHeight = 28
    local spacing = 5
    local totalHeight = 0
    local width = bossListScrollFrame:GetWidth() - 20
    
    local index = 1
    for i, bossName in pairs(currentBosses) do
        local itemFrame = CreateFrame("Frame", nil, bossListScrollChild)
        itemFrame:SetWidth(width)
        itemFrame:SetHeight(itemHeight)
        itemFrame:SetPoint("TOPLEFT", 0, -((index-1) * (itemHeight + spacing)))
        
       
        local label = itemFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetPoint("LEFT", itemFrame, "LEFT", 5, 0)
        label:SetText("- " .. bossName)
        label:SetJustifyH("LEFT")
        
       
        local removeButton = CreateFrame("Button", nil, itemFrame, "UIPanelButtonTemplate")
        removeButton:SetWidth(25)
        removeButton:SetHeight(25)
        removeButton:SetText("X")
        removeButton:SetPoint("RIGHT", itemFrame, "RIGHT", -5, 0)
        removeButton:SetScript("OnClick", function()
            tremove(currentBosses, i)
            RefreshBossList()
        end)
        
       
        itemFrame:EnableMouse(true)
        itemFrame:SetScript("OnMouseDown", function(self, button)
            if IsAltKeyDown() then
                AddBossDirectly(bossName)
            end
        end)
        
       
        itemFrame:SetScript("OnEnter", function()
            GameTooltip:SetOwner(itemFrame, "ANCHOR_RIGHT")
            GameTooltip:SetText("ALT-click to add again")
            GameTooltip:Show()
        end)
        itemFrame:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        
        bossListItems[index] = {
            frame = itemFrame,
            label = label,
            button = removeButton
        }
        
        totalHeight = totalHeight + itemHeight + spacing
        index = index + 1
    end
    
   
    local visibleHeight = bossListScrollFrame:GetHeight()
    bossListScrollChild:SetHeight(math.max(totalHeight, visibleHeight + 1))
    bossListScrollFrame:UpdateScrollChildRect()
    bossListScrollFrame:SetVerticalScroll(0)
end


local AddBossDirectly
local AddCurrentZoneToBosses

AddBossDirectly = function(bossName)
    if not PresetPopup:IsVisible() then return end

    bossName = strtrim(bossName)
    if bossName == "" then return end

    local lowerName = strlower(bossName)
    for _, existing in pairs(currentBosses) do
        if strlower(existing) == lowerName then
            ShowStaticPopup(bossName .. " already in list!", "ERROR")
            return
        end
    end

    tinsert(currentBosses, bossName)
    RefreshBossList()
    DEFAULT_CHAT_FRAME:AddMessage(bossName .. " added to list!")
end

AddCurrentZoneToBosses = function()
    if not PresetPopup:IsVisible() then return end

    local zone = GetRealZoneText()
    if not zone or zone == "" then return end

    local lowerZone = strlower(zone)
    for _, existing in pairs(currentBosses) do
        if strlower(existing) == lowerZone then
            ShowStaticPopup(zone .. " already in list!", "ERROR")
            return
        end
    end

    tinsert(currentBosses, zone)
    RefreshBossList()
    DEFAULT_CHAT_FRAME:AddMessage(zone .. " added to list!")
end

addBossButton:SetScript("OnClick", function()
    local name = strtrim(bossInput:GetText())
    if name ~= "" then
        AddBossDirectly(name)
        bossInput:SetText("")
    end
end)

addZoneButton:SetScript("OnEnter", function()
    GameTooltip:SetOwner(addZoneButton, "ANCHOR_RIGHT")
    GameTooltip:SetText("Add current zone")
    GameTooltip:Show()
end)

addZoneButton:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

addZoneButton:SetScript("OnClick", function()
    AddCurrentZoneToBosses()
end)


local targetScanFrame = CreateFrame("Frame")
targetScanFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
targetScanFrame:SetScript("OnEvent", function()
    if PresetPopup:IsVisible() and IsAltKeyDown() and UnitExists("target") and not UnitIsPlayer("target") then
        local bossName = UnitName("target")
        if bossName then
            AddBossDirectly(bossName)
        end
    end
end)


local keyboardFrame = CreateFrame("Frame")
keyboardFrame:RegisterEvent("MODIFIER_STATE_CHANGED")
keyboardFrame:SetScript("OnEvent", function(_, _, key, state)
    if PresetPopup:IsVisible() and (key == "LALT" or key == "RALT") then
        if state == 1 and UnitExists("target") and not UnitIsPlayer("target") then
            local bossName = UnitName("target")
            if bossName then
                AddBossDirectly(bossName)
            end
        end
    end
end)


local saveButtonPresetPopup = CreateButton(PresetPopup, 80, 22, "BOTTOMLEFT", "Save")
saveButtonPresetPopup:SetPoint("BOTTOMLEFT", PresetPopup, "BOTTOMLEFT", 10, 10)

local cancelButton = CreateButton(PresetPopup, 80, 22, "BOTTOMRIGHT", "Cancel")
cancelButton:SetPoint("BOTTOMRIGHT", PresetPopup, "BOTTOMRIGHT", -10, 10)
cancelButton:SetScript("OnClick", function() PresetPopup:Hide() end)


saveButtonPresetPopup:SetScript("OnClick", function()
    local name = presetInput:GetText()
    local bosses = currentBosses

    if not name or name == "" then
        ShowStaticPopup("Please enter a name.", "Error")
        return
    end

    local instanceKey = "otherPresets"
    if not FillRaidPresets[faction] then
        FillRaidPresets[faction] = {}
    end
    if not FillRaidPresets[faction][instanceKey] then
        FillRaidPresets[faction][instanceKey] = {}
    end

    local presetList = FillRaidPresets[faction][instanceKey]
    
    if PresetPopup.mode == "edit" then
       
        for i, p in pairs(presetList) do
            if p.label == PresetPopup.editingPreset then
               
                presetList[i].label = name
                presetList[i].bosses = bosses
                
               
                for classRole, inputBox in pairs(inputBoxes) do
                    if inputBox then
                        local value = tonumber(inputBox:GetText())
                        if value and value > 0 then
                            presetList[i].values[classRole] = value
                        end
                    end
                end
                
                PresetPopup:Hide()
                DEFAULT_CHAT_FRAME:AddMessage("Updated preset: \"" .. name .. "\"")
                
                if currentPresetLabel then
                    currentPresetLabel:SetText("Preset: " .. name)
                end
                currentPresetName = name
                return
            end
        end
    else
       
        for _, p in pairs(presetList) do
            if p.label == name then
                ShowStaticPopup("A preset with that name already exists.", "Error")
                return
            end
        end

        local newPreset = {
            label = name,
            values = {},
            bosses = bosses,
        }

       
        for classRole, inputBox in pairs(inputBoxes) do
            if inputBox then
                local value = tonumber(inputBox:GetText())
                if value and value > 0 then
                    newPreset.values[classRole] = value
                end
            end
        end

        table.insert(presetList, newPreset)
        PresetPopup:Hide()
        DEFAULT_CHAT_FRAME:AddMessage("Saved new preset: \"" .. name .. "\"")

        if currentPresetLabel then
            currentPresetLabel:SetText("Preset: " .. name)
        end
        currentPresetName = name
    end
end)


presetInput:SetScript("OnEnterPressed", function()
    saveButtonPresetPopup:GetScript("OnClick")()
end)

presetInput:SetScript("OnEscapePressed", function()
    PresetPopup:Hide()
end)

bossInput:SetScript("OnEscapePressed", function()
    PresetPopup:Hide()
end)

PresetPopup:SetScript("OnKeyDown", function()
    if arg1 == KEY_ESCAPE then
        PresetPopup:Hide()
    end
end)


function OpenSaveAsPopup()
    PresetPopup.mode = "save"
    popupLabel:SetText("Enter preset name:")
    presetInput:SetText("")
    bossInput:SetText("")
    currentBosses = {}
    RefreshBossList()
    saveButton:SetText("Save")
    presetInput:SetFocus()
    if PresetPopup:IsShown() then
        PresetPopup:Hide()
    else
        PresetPopup:Show()
    end
end

function OpenEditPopup()
    if not currentPresetName then

		ShowStaticPopup("No preset selected to edit.", "Error")
        return
    end

   
    local instanceKey = "otherPresets"
    local presetList = FillRaidPresets[faction] and FillRaidPresets[faction][instanceKey] or {}
    local currentPreset
    
    for _, p in pairs(presetList) do
        if p.label == currentPresetName then
            currentPreset = p
            break
        end
    end
    
    if not currentPreset then
        ShowStaticPopup("You can only rename presets \n under Others.")
        return
    end
    
   
    PresetPopup.mode = "edit"
    PresetPopup.editingPreset = currentPresetName
    popupLabel:SetText("Edit preset:")
    presetInput:SetText(currentPresetName)
    currentBosses = {}
    
   
    if currentPreset.bosses then
        for _, boss in ipairs(currentPreset.bosses) do
            table.insert(currentBosses, boss)
        end
    end
    
    RefreshBossList()
    saveButton:SetText("Save")
    PresetPopup:Show()
    presetInput:SetFocus()
end




local ConfirmDeletePopup = CreateFrame("Frame", "ConfirmDeletePopup", UIParent)
ConfirmDeletePopup:SetWidth(260)
ConfirmDeletePopup:SetHeight(100)
ConfirmDeletePopup:SetPoint("CENTER", UIParent, "CENTER")
ConfirmDeletePopup:SetFrameStrata("DIALOG")
ConfirmDeletePopup:SetFrameLevel(20) 
ConfirmDeletePopup:SetBackdrop({
    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
})
ConfirmDeletePopup:SetBackdropColor(1, 0, 0, 1)
ConfirmDeletePopup:Hide()

local confirmText = ConfirmDeletePopup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
confirmText:SetPoint("TOP", ConfirmDeletePopup, "TOP", 0, -20)

local yesButton = CreateFrame("Button", nil, ConfirmDeletePopup, "GameMenuButtonTemplate")
yesButton:SetWidth(60)
yesButton:SetHeight(20)
yesButton:SetPoint("BOTTOMLEFT", ConfirmDeletePopup, "BOTTOMLEFT", 20, 10)
yesButton:SetText("Yes")

local noButton = CreateFrame("Button", nil, ConfirmDeletePopup, "GameMenuButtonTemplate")
noButton:SetWidth(60)
noButton:SetHeight(20)
noButton:SetPoint("BOTTOMRIGHT", ConfirmDeletePopup, "BOTTOMRIGHT", -20, 10)
noButton:SetText("No")
noButton:SetScript("OnClick", function()
    ConfirmDeletePopup:Hide()
end)

function ShowConfirmDeletePopup(presetName)
    ConfirmDeletePopup:Show()
    confirmText:SetText("Delete preset: \"" .. presetName .. "\"?\nThis will also reload the UI.")

    yesButton:SetScript("OnClick", function()
        local presetList = FillRaidPresets[faction]["otherPresets"]
        for i = table.getn(presetList), 1, -1 do
            if presetList[i].label == presetName then
                table.remove(presetList, i)
                break
            end
        end
        ConfirmDeletePopup:Hide()
        PresetPopup:Hide()
        ReloadUI()
    end)
end


local saveAsButton = CreateButton(FillRaidFrame, 80, 20, "LEFT", "Save As")
saveAsButton:SetPoint("LEFT", saveButton, "RIGHT", 10, 0)
saveAsButton:SetScript("OnClick", OpenSaveAsPopup)

saveAsButton:Hide()
saveAsButton:SetScript("OnEnter", function()
    GameTooltip:SetOwner(saveAsButton, "ANCHOR_RIGHT")
    GameTooltip:SetText("Saves a new preset into Presets > Other")
    GameTooltip:Show()
end)

saveAsButton:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

local editButton2 = CreateButton(FillRaidFrame, 80, 20, "LEFT", "Rename")
editButton2:SetPoint("LEFT", saveAsButton, "RIGHT", 10, 0)
editButton2:SetScript("OnClick", OpenEditPopup)
editButton2:Hide()
editButton2:SetScript("OnEnter", function()
    GameTooltip:SetOwner(editButton2, "ANCHOR_RIGHT")
    GameTooltip:SetText("Rename the currently selected preset name and add bosses")
    GameTooltip:Show()
end)

editButton2:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)





local removeButton = CreateButton(FillRaidFrame, 80, 20, "LEFT", "Remove")
removeButton:SetPoint("TOPLEFT", editButton2, "BOTTOMLEFT", 0, -10)
removeButton:Hide()

removeButton:SetScript("OnClick", function()
    if currentPresetName then
        ShowConfirmDeletePopup(currentPresetName)
    else
        ShowStaticPopup("No preset selected to Remove.", "Error")
    end
end)

removeButton:SetScript("OnEnter", function()
    GameTooltip:SetOwner(removeButton, "ANCHOR_RIGHT")
    GameTooltip:SetText("Remove the currently selected preset")
    GameTooltip:Show()
end)

removeButton:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)







local function OnPresetSelected(presetName)
    currentPresetName = presetName
    if presetName then
        removeButton:Show()
    else
        removeButton:Hide()
    end
   
end


PresetPopup:SetScript("OnHide", function()
    if not currentPresetName then
        removeButton:Show()
    end
end)

-------------------------------------------export suppress -----------------------------------------------------------------------
local SuppressExportFrame = CreateFrame("Frame", "FillRaidSuppressExportFrame", UIParent)
SuppressExportFrame:SetBackdrop({
    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
})


SuppressExportFrame:SetBackdropColor(0, 0, 0, 1)
SuppressExportFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
SuppressExportFrame:SetWidth(400)
SuppressExportFrame:SetHeight(300)
SuppressExportFrame:SetFrameStrata("DIALOG")
SuppressExportFrame:SetToplevel(true)
SuppressExportFrame:Hide()

SuppressExportFrame.background = SuppressExportFrame:CreateTexture(nil, "BACKGROUND")
SuppressExportFrame.background:SetAllPoints(SuppressExportFrame)
SuppressExportFrame:SetBackdropColor(0, 0, 0, 1)

SuppressExportFrame:SetMovable(true)
SuppressExportFrame:EnableMouse(true)
SuppressExportFrame:RegisterForDrag("LeftButton")
SuppressExportFrame:SetScript("OnDragStart", SuppressExportFrame.StartMoving)
SuppressExportFrame:SetScript("OnDragStop", SuppressExportFrame.StopMovingOrSizing)

table.insert(UISpecialFrames, "SuppressExportFrame")

local suppressTitle = SuppressExportFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
suppressTitle:SetPoint("TOP", SuppressExportFrame, "TOP", 0, -10)
suppressTitle:SetText("Export/Import Suppressed Bot Messages")

local helpSuppress = CreateHelpButton(SuppressExportFrame, suppressTitle, 10, 0, "To export select all and Ctrl+C.\nTo import, replace content and click Import.", "Help")

local suppressScroll = CreateFrame("ScrollFrame", "FillRaidSuppressScrollFrame", SuppressExportFrame, "UIPanelScrollFrameTemplate")
suppressScroll:SetPoint("TOPLEFT", SuppressExportFrame, "TOPLEFT", 16, -40)
suppressScroll:SetPoint("BOTTOMRIGHT", SuppressExportFrame, "BOTTOMRIGHT", -30, 50)

local suppressScrollChild = CreateFrame("Frame", nil, suppressScroll)
suppressScrollChild:SetWidth(suppressScroll:GetWidth())
suppressScroll:SetScrollChild(suppressScrollChild)

local suppressEditBox = CreateFrame("EditBox", "FillRaidSuppressEditBox", suppressScrollChild)
suppressEditBox:SetMultiLine(true)
suppressEditBox:SetWidth(340)
suppressEditBox:SetHeight(1000)
suppressEditBox:SetFontObject(GameFontHighlight)
suppressEditBox:SetAutoFocus(false)
suppressEditBox:SetScript("OnEscapePressed", function() suppressEditBox:ClearFocus() end)
suppressEditBox:SetPoint("TOPLEFT", suppressScrollChild, "TOPLEFT", 0, 0)

local function SerializeTable(tbl, indent)
    indent = indent or ""
    local str = "{\n"
    for k, v in pairs(tbl) do
        local key
        if type(k) == "string" then
            key = string.format("[%q]", k) 
        else 
            key = string.format("[%d]", k) 
        end
        
        str = str .. indent .. "  " .. key .. " = "
        
       
        if type(v) == "table" then
            str = str .. SerializeTable(v, indent .. "  ")
        elseif type(v) == "string" then
            str = str .. string.format("%q", v)
        elseif type(v) == "boolean" then
            str = str .. (v and "true" or "false")
        else 
            str = str .. tostring(v)
        end
        str = str .. ",\n"
    end
    return str .. indent .. "}"
end


local function OpenSuppressExportFrame()
    if FillRaidSuppressBotMsg then
        suppressEditBox:SetText("FillRaidSuppressBotMsg = " .. SerializeTable(FillRaidSuppressBotMsg))
    else
        suppressEditBox:SetText("FillRaidSuppressBotMsg is nil.")
    end

    local text = suppressEditBox:GetText()
    local lineCount = 1
    local pos = 1

    while true do
        local newPos = string.find(text, "\n", pos)
        if not newPos then break end
        lineCount = lineCount + 1
        pos = newPos + 1
    end

    local contentHeight = lineCount * 16
    suppressScrollChild:SetHeight(math.max(contentHeight, suppressScroll:GetHeight()))

    SuppressExportFrame:Show()
    suppressEditBox:SetFocus()
end



local selectAllSuppress = CreateFrame("Button", nil, SuppressExportFrame, "GameMenuButtonTemplate")
selectAllSuppress:SetText("Select All")
selectAllSuppress:SetWidth(100)
selectAllSuppress:SetHeight(20)
selectAllSuppress:SetPoint("BOTTOMLEFT", SuppressExportFrame, "BOTTOMLEFT", 10, 10)
selectAllSuppress:SetScript("OnClick", function()
    suppressEditBox:HighlightText()
    suppressEditBox:SetFocus()
end)

local importSuppressButton = CreateFrame("Button", nil, SuppressExportFrame, "GameMenuButtonTemplate")
importSuppressButton:SetText("Import")
importSuppressButton:SetWidth(80)
importSuppressButton:SetHeight(20)
importSuppressButton:SetPoint("BOTTOM", SuppressExportFrame, "BOTTOM", 0, 10)
importSuppressButton:SetScript("OnClick", function()
    local text = suppressEditBox:GetText()
    
    if not text or strtrim(text) == "" then
        ShowStaticPopup("Import failed: No data to import", "import")
        return
    end
    
   
    text = string.gsub(text, "([%[%]])%s*=%s*", "%1 = ")
    text = string.gsub(text, "(%d+)%s*=%s*", "[%1] = ")
    
   
    if strsub(strtrim(text), 1, 1) == "{" then
        text = "return " .. text
    end
    
   
    local env = {}
    local func, err = loadstring(text)
    
    if not func then
        ShowStaticPopup("Import failed: "..(err or "Syntax error"), "import")
        return
    end
    
    setfenv(func, env)

    local success, result = pcall(func)
    
    if success then
       
        local importedTable = result or env.FillRaidSuppressBotMsg
        if type(importedTable) == "table" then
            FillRaidSuppressBotMsg = importedTable
            ShowStaticPopup("SuppressBotMsg imported! Reloading UI...", "import", true)

        else
            ShowStaticPopup("Import failed: No valid table data found", "import")
        end
                                                                                   
    else
        ShowStaticPopup("Import failed: "..(result or "Execution error"), "import")
    end
end)

local closeSuppressButton = CreateFrame("Button", nil, SuppressExportFrame, "GameMenuButtonTemplate")
closeSuppressButton:SetText("Close")
closeSuppressButton:SetWidth(80)
closeSuppressButton:SetHeight(20)
closeSuppressButton:SetPoint("BOTTOMRIGHT", SuppressExportFrame, "BOTTOMRIGHT", -10, 10)
closeSuppressButton:SetScript("OnClick", function()
    SuppressExportFrame:Hide()
end)

--------------------------------------------SuppressBotMsgList-------------------------------------------------------------------


SuppressEditor = CreateFrame("Frame", "SuppressEditorFrame", UIParent)
SuppressEditor:SetWidth(370)
SuppressEditor:SetHeight(450)

SuppressEditor:SetPoint("CENTER", UIParent, "CENTER", 0, 0)

SuppressEditor:SetFrameStrata("DIALOG")
SuppressEditor:SetBackdrop({
    bgFile = "Interface/Buttons/WHITE8X8",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
})
SuppressEditor:SetBackdropColor(0, 0, 0, 1)
SuppressEditor:SetMovable(true)
SuppressEditor:EnableMouse(true)
SuppressEditor:RegisterForDrag("LeftButton")
    SuppressEditor:SetScript("OnDragStart", SuppressEditor.StartMoving)
    SuppressEditor:SetScript("OnDragStop", SuppressEditor.StopMovingOrSizing)

    SuppressEditor:SetScript("OnMouseDown", function()
        if arg1 == "LeftButton" and not this.isMoving then
            this:StartMoving()
            this.isMoving = true
        end
    end)
    SuppressEditor:SetScript("OnMouseUp", function()
        if arg1 == "LeftButton" and this.isMoving then
            this:StopMovingOrSizing()
            this.isMoving = false
        end
    end)
SuppressEditor:Hide()
table.insert(UISpecialFrames, "SuppressEditorFrame")


local title = SuppressEditor:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOP", 0, -10)
title:SetText("SuppressBotMsg Editor")
local helpButton = CreateHelpButton(SuppressEditorFrame, title, 10, 0, "Enter a message pattern to suppress.\n\nCooldown:\n - Time (in seconds) to wait before showing the same message again.\n - Set to 0 to fully suppress that message.\n\nTip:\n - Partial matches are supported. For example, 'joins the party' matches \nmessages like 'Bot123 joins the party.", "Suppress Message Help")


local patternLabel = SuppressEditor:CreateFontString(nil, "OVERLAY", "GameFontNormal")
patternLabel:SetPoint("TOPLEFT", 20, -40)
patternLabel:SetText("Message Pattern:")

local patternInput = CreateFrame("EditBox", "SuppressPatternInput", SuppressEditor, "InputBoxTemplate")
patternInput:SetWidth(260)
patternInput:SetHeight(20)

patternInput:SetAutoFocus(false)
patternInput:SetPoint("TOPLEFT", patternLabel, "BOTTOMLEFT", 0, -5)
patternInput:SetScript("OnEscapePressed", patternInput.ClearFocus)


local cooldownLabel = SuppressEditor:CreateFontString(nil, "OVERLAY", "GameFontNormal")
cooldownLabel:SetPoint("TOPLEFT", patternInput, "BOTTOMLEFT", 0, -10)
cooldownLabel:SetText("Cooldown (seconds):")

local cooldownInput = CreateFrame("EditBox", "SuppressCooldownInput", SuppressEditor, "InputBoxTemplate")
cooldownInput:SetWidth(80)
cooldownInput:SetHeight(20)

cooldownInput:SetAutoFocus(false)
cooldownInput:SetPoint("TOPLEFT", cooldownLabel, "BOTTOMLEFT", 0, -5)
cooldownInput:SetNumeric(true)
cooldownInput:SetScript("OnEscapePressed", cooldownInput.ClearFocus)


CreateSeparatorLine(SuppressEditor, 0, -6, 336, cooldownInput)

local addButton = CreateFrame("Button", "SuppressAddButton", SuppressEditor, "UIPanelButtonTemplate")
addButton:SetWidth(100)
addButton:SetHeight(24)

addButton:SetText("Add/Update")
addButton:SetPoint("LEFT", cooldownInput, "RIGHT", 10, 0)


local scrollFrame = CreateFrame("ScrollFrame", "SuppressListScrollFrame", SuppressEditor, "UIPanelScrollFrameTemplate")
scrollFrame:SetPoint("TOPLEFT", 20, -140)
scrollFrame:SetPoint("BOTTOMRIGHT", -45, 60)

local scrollChild = CreateFrame("Frame", "SuppressListScrollChild", scrollFrame)
scrollChild:SetWidth(260)
scrollChild:SetHeight(1)
scrollFrame:SetScrollChild(scrollChild)

local suppressListItems = {}


local function tableSize(t)
    local count = 0
    for _ in pairs(t) do count = count + 1 end
    return count
end


local MAX_CHARS = 40
local ROW_HEIGHT = 20
local ROW_SPACING = 4

local function TruncateText(text, maxChars)
    if string.len(text) <= maxChars then
        return text, false
    end
    return string.sub(text, 1, maxChars) .. "...", true
end

local function WordWrap(text, maxCharsPerLine)
    if not text then return "" end

    local wrapped = ""
    local lineLength = 0

    for word in string.gfind(text, "%S+") do
        local wordLength = string.len(word)

        
        if wordLength > maxCharsPerLine then
            for i = 1, wordLength, maxCharsPerLine do
                wrapped = wrapped .. "\n" .. string.sub(word, i, i + maxCharsPerLine - 1)
            end
            lineLength = 0

        elseif lineLength + wordLength > maxCharsPerLine then
            wrapped = wrapped .. "\n" .. word .. " "
            lineLength = wordLength + 1

        else
            wrapped = wrapped .. word .. " "
            lineLength = lineLength + wordLength + 1
        end
    end

    return wrapped
end
function RefreshSuppressList()

    if not FillRaidSuppressBotMsg then
        FillRaidSuppressBotMsg = {}
    end

    if not FillRaidSuppressBotMsg.messagesToHide then
        FillRaidSuppressBotMsg.messagesToHide = {}
    end

    local list = FillRaidSuppressBotMsg.messagesToHide
    local width = SuppressListScrollFrame:GetWidth() - 0

    ------------------------------------------------------------------
    -- SORT KEYS ALPHABETICALLY (case insensitive)
    ------------------------------------------------------------------

    local sortedPatterns = {}

    for pattern in pairs(list) do
        table.insert(sortedPatterns, pattern)
    end

    table.sort(sortedPatterns, function(a, b)
        return string.lower(a) < string.lower(b)
    end)

    ------------------------------------------------------------------

    local index = 1

    for _, pattern in ipairs(sortedPatterns) do

        local cooldown = list[pattern]
        local row = suppressListItems[index]

        --------------------------------------------------------------
        
        

        if not row then
            row = {}

            row.frame = CreateFrame("Frame", nil, SuppressListScrollChild)
			row.frame:EnableMouse(true)
            row.frame:SetHeight(ROW_HEIGHT)

            
            row.highlight = row.frame:CreateTexture(nil, "BACKGROUND")
            row.highlight:SetAllPoints(row.frame)
            row.highlight:SetTexture(1, 1, 1, 0.08)
            row.highlight:Hide()

            row.label = row.frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            row.label:SetPoint("LEFT", row.frame, "LEFT", 5, 0)
            row.label:SetJustifyH("LEFT")


            row.delete = CreateFrame("Button", nil, row.frame, "UIPanelButtonTemplate")
            row.delete:SetWidth(20)
            row.delete:SetHeight(20)
            row.delete:SetText("X")
            row.delete:SetPoint("RIGHT", row.frame, "RIGHT", -5, 0)

            suppressListItems[index] = row
        end

        row.frame:SetFrameLevel(SuppressEditor:GetFrameLevel() + 2)
        row.delete:SetFrameLevel(SuppressEditor:GetFrameLevel() + 3)

        --------------------------------------------------------------

        row.frame:SetWidth(width)
        row.frame:SetPoint("TOPLEFT", 0, -((index - 1) * (ROW_HEIGHT + ROW_SPACING)))
        row.frame:Show()

        local shortText, truncated = TruncateText(pattern, MAX_CHARS)

        row.label:SetWidth(width - 30)
        row.label:SetText(shortText .. " (" .. cooldown .. "s)")

        
        
        

        row.delete:SetScript("OnClick", function()
            FillRaidSuppressBotMsg.messagesToHide[pattern] = nil
            RefreshSuppressList()
        end)

        
        
        

		local currentPattern = pattern
		local currentCooldown = cooldown

		row.frame:SetScript("OnEnter", function()
			row.highlight:Show()

			GameTooltip:SetOwner(row.frame, "ANCHOR_CURSOR_RIGHT")
			GameTooltip:ClearLines()

			local wrappedPattern = WordWrap(currentPattern, 50)

			
			GameTooltip:AddLine(wrappedPattern, 1, 1, 1)

			GameTooltip:AddLine(" ")

			
			if currentCooldown == 0 then
				GameTooltip:AddLine("Cooldown: 0 seconds (Fully suppressed)", 1, 0.2, 0.2)
			else
				GameTooltip:AddLine("Cooldown: "..currentCooldown.." seconds", 0.7, 0.7, 0.7)
			end

			GameTooltip:Show()
		end)

		row.frame:SetScript("OnLeave", function()
			row.highlight:Hide()
			GameTooltip:Hide()
		end)

		row.delete:SetScript("OnClick", function()
			FillRaidSuppressBotMsg.messagesToHide[currentPattern] = nil
			RefreshSuppressList()
		end)

        index = index + 1
    end

    
    
    

    for i = index, table.getn(suppressListItems) do
        suppressListItems[i].frame:Hide()
    end

    local totalHeight = (index - 1) * (ROW_HEIGHT + ROW_SPACING)

    SuppressListScrollChild:SetHeight(
        math.max(totalHeight, SuppressListScrollFrame:GetHeight() + 1)
    )

    SuppressListScrollFrame:UpdateScrollChildRect()
    SuppressListScrollFrame:SetVerticalScroll(0)
end
CreateSeparatorLine(SuppressEditor, 0, -6, 336, scrollFrame)

addButton:SetScript("OnClick", function()
    local pattern = patternInput:GetText()
    local cooldown = tonumber(cooldownInput:GetText()) or 0
    if pattern == "" then return end

    FillRaidSuppressBotMsg = FillRaidSuppressBotMsg or {}
    FillRaidSuppressBotMsg.messagesToHide = FillRaidSuppressBotMsg.messagesToHide or {}

    FillRaidSuppressBotMsg.messagesToHide[pattern] = cooldown
    patternInput:SetText("")
    cooldownInput:SetText("")
    RefreshSuppressList()
end)


local saveSupressMsgButton = CreateFrame("Button", nil, SuppressEditor, "GameMenuButtonTemplate")
saveSupressMsgButton:SetWidth(80)
saveSupressMsgButton:SetHeight(24)

saveSupressMsgButton:SetText("Save")
saveSupressMsgButton:SetPoint("BOTTOMLEFT", 10, 20)
saveSupressMsgButton:SetScript("OnClick", function()
    StaticPopupDialogs["SUPPRESS_SAVE_CONFIRM"] = {
        text = "Saved new Suppress message.\n\nReload UI to apply?",
        button1 = "Reload",
        button2 = "No",
        OnAccept = function() ReloadUI() end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
    StaticPopup_Show("SUPPRESS_SAVE_CONFIRM")
end)


local restoreButton = CreateFrame("Button", nil, SuppressEditor, "GameMenuButtonTemplate")
restoreButton:SetText("Defaults")
restoreButton:SetWidth(80)
restoreButton:SetHeight(24)

restoreButton:SetPoint("LEFT", saveSupressMsgButton, "RIGHT", 10, 0)
restoreButton:SetScript("OnClick", function()
    StaticPopupDialogs["SUPPRESS_RESTORE_DEFAULTS"] = {
        text = "Restore defaults? All custom entries will be lost.",
        button1 = "Yes",
        button2 = "No",
        OnAccept = function()
            FillRaidSuppressBotMsg = nil
            ReloadUI()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
    StaticPopup_Show("SUPPRESS_RESTORE_DEFAULTS")
end)

local openSuppressButton = CreateFrame("Button", nil, SuppressEditor, "GameMenuButtonTemplate")
openSuppressButton:SetText("Export")
openSuppressButton:SetWidth(80)
openSuppressButton:SetHeight(24)
openSuppressButton:SetPoint("LEFT", restoreButton, "RIGHT", 10, 0)
openSuppressButton:SetScript("OnClick", OpenSuppressExportFrame)
openSuppressButton:Show()



local cancelSupressMsgButton = CreateFrame("Button", nil, SuppressEditor, "GameMenuButtonTemplate")
cancelSupressMsgButton:SetWidth(80)
cancelSupressMsgButton:SetHeight(24)

cancelSupressMsgButton:SetText("Cancel")
cancelSupressMsgButton:SetPoint("LEFT", openSuppressButton, "RIGHT", 10, 0)
cancelSupressMsgButton:SetScript("OnClick", function()
    SuppressEditor:Hide()
end)

local function RefreshSuppressEditorFrameLevels()
    local baseLevel = SuppressEditor:GetFrameLevel()

    if helpButton then
        helpButton:SetFrameLevel(baseLevel + 3)
    end

    if patternInput then
        patternInput:SetFrameLevel(baseLevel + 2)
    end

    if cooldownInput then
        cooldownInput:SetFrameLevel(baseLevel + 2)
    end

    if addButton then
        addButton:SetFrameLevel(baseLevel + 2)
    end

    if scrollFrame then
        scrollFrame:SetFrameLevel(baseLevel + 1)
    end

    if scrollChild then
        scrollChild:SetFrameLevel(baseLevel + 2)
    end

    if saveSupressMsgButton then
        saveSupressMsgButton:SetFrameLevel(baseLevel + 2)
    end

    if restoreButton then
        restoreButton:SetFrameLevel(baseLevel + 2)
    end

    if openSuppressButton then
        openSuppressButton:SetFrameLevel(baseLevel + 2)
    end

    if cancelSupressMsgButton then
        cancelSupressMsgButton:SetFrameLevel(baseLevel + 2)
    end

    if suppressListItems then
        local i
        for i = 1, table.getn(suppressListItems) do
            local row = suppressListItems[i]
            if row and row.frame then
                row.frame:SetFrameLevel(baseLevel + 2)
            end
            if row and row.delete then
                row.delete:SetFrameLevel(baseLevel + 3)
            end
        end
    end
end

SuppressEditor:SetScript("OnShow", function()
    RefreshSuppressEditorFrameLevels()
end)

RefreshSuppressEditorFrameLevels()



--------------------------------------------Restore default-----------------------------------------------------------------------
local restoreDefaultsButton = CreateFrame("Button", nil, FillRaidFrame, "GameMenuButtonTemplate")
restoreDefaultsButton:SetText("Defaults")
restoreDefaultsButton:SetWidth(80)
restoreDefaultsButton:SetHeight(20)
restoreDefaultsButton:SetPoint("TOP", saveButton, "BOTTOM", 0, -10)
restoreDefaultsButton:Hide()

restoreDefaultsButton:SetScript("OnClick", function()
    if not faction then
        print("Faction not set.")
        return
    end

    StaticPopupDialogs["CONFIRM_RESTORE_DEFAULTS"] = {
        text = "Are you sure you want to restore the default presets for " .. faction .. "? This will delete all your custom presets.",
        button1 = "Yes",
        button2 = "No",
        OnAccept = function()
            FillRaidPresets[faction] = nil
            ReloadUI()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }

    StaticPopup_Show("CONFIRM_RESTORE_DEFAULTS")
end)

restoreDefaultsButton:SetScript("OnEnter", function()
    GameTooltip:SetOwner(restoreDefaultsButton, "ANCHOR_RIGHT")
    GameTooltip:SetText("Restores all preset to default")
    GameTooltip:Show()
end)
restoreDefaultsButton:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)



-------------------------export/import................................

local ExportFrame = CreateFrame("Frame", "FillRaidExportFrame", UIParent)
ExportFrame:SetBackdrop({
    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
})
ExportFrame:SetBackdropColor(0, 0, 0, 0.8)
ExportFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
ExportFrame:SetWidth(400)
ExportFrame:SetHeight(300)
ExportFrame:SetFrameStrata("DIALOG")
ExportFrame:Hide()


local title = ExportFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOP", ExportFrame, "TOP", 0, -10)
title:SetText("Export / Import FillRaidPresets")
local helpexport = CreateHelpButton(ExportFrame, title, 10, 0, "To export Select all and ctrl+c to copy to a document\n To import remove everything and paste your saved settings", "Another Help")

local scrollFrame = CreateFrame("ScrollFrame", "FillRaidExportScrollFrame", ExportFrame, "UIPanelScrollFrameTemplate")
scrollFrame:SetPoint("TOPLEFT", ExportFrame, "TOPLEFT", 16, -40)
scrollFrame:SetPoint("BOTTOMRIGHT", ExportFrame, "BOTTOMRIGHT", -30, 50)


local scrollChild = CreateFrame("Frame", nil, scrollFrame)
scrollChild:SetWidth(scrollFrame:GetWidth()) 
scrollFrame:SetScrollChild(scrollChild)


local editBox = CreateFrame("EditBox", "FillRaidExportEditBox", scrollChild)
editBox:SetMultiLine(true)
editBox:SetWidth(340)
editBox:SetHeight(1000) 
editBox:SetFontObject(GameFontHighlight)
editBox:SetAutoFocus(false)
editBox:SetScript("OnEscapePressed", function() editBox:ClearFocus() end)
editBox:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, 0)


local function SerializeTable(tbl, indent)
    indent = indent or ""
    local str = "{\n"
    for k, v in pairs(tbl) do
        local key
        if type(k) == "string" then
            key = string.format("[%q]", k) 
        else 
            key = string.format("[%d]", k) 
        end
        
        str = str .. indent .. "  " .. key .. " = "
        
       
        if type(v) == "table" then
            str = str .. SerializeTable(v, indent .. "  ")
        elseif type(v) == "string" then
            str = str .. string.format("%q", v)
        elseif type(v) == "boolean" then
            str = str .. (v and "true" or "false")
        else 
            str = str .. tostring(v)
        end
        str = str .. ",\n"
    end
    return str .. indent .. "}"
end



local function OpenExportFrame()
    if FillRaidPresets then
        editBox:SetText("FillRaidPresets = " .. SerializeTable(FillRaidPresets))
    else
        editBox:SetText("FillRaidPresets is nil.")
    end
    
   
    local text = editBox:GetText()
    local lineCount = 1
    local pos = 1
    
   
    while true do
        local newPos = string.find(text, "\n", pos)
        if not newPos then break end
        lineCount = lineCount + 1
        pos = newPos + 1
    end
    
   
    local contentHeight = lineCount * 16
    scrollChild:SetHeight(math.max(contentHeight, scrollFrame:GetHeight()))
    
    ExportFrame:Show()
    editBox:SetFocus()
end


local openExportButton = CreateFrame("Button", nil, FillRaidFrame, "GameMenuButtonTemplate")
openExportButton:SetText("Export")
openExportButton:SetWidth(80)
openExportButton:SetHeight(20)
openExportButton:SetPoint("LEFT", restoreDefaultsButton, "RIGHT", 10, 0)
openExportButton:SetScript("OnClick", OpenExportFrame)
openExportButton:Hide()

local SuppressEditorButton = CreateFrame("Button", nil, FillRaidFrame, "GameMenuButtonTemplate")
SuppressEditorButton:SetText("Suppress")
SuppressEditorButton:SetWidth(80)
SuppressEditorButton:SetHeight(20)
SuppressEditorButton:SetPoint("TOP", openExportButton, "BOTTOM", 0, -10)
SuppressEditorButton:Hide()
SuppressEditorButton:SetScript("OnEnter", function()
    GameTooltip:SetOwner(SuppressEditorButton, "ANCHOR_RIGHT")
    GameTooltip:SetText("Add/Edit Messages to be Suppressed")
    GameTooltip:Show()
end)
SuppressEditorButton:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)
SuppressEditorButton:SetScript("OnClick", function()
    if SuppressEditor:IsShown() then
        SuppressEditor:Hide()
    else
        RefreshSuppressList()
        SuppressEditor:Show()
    end
end)


local copyButton = CreateFrame("Button", nil, ExportFrame, "GameMenuButtonTemplate")
copyButton:SetText("Select All")
copyButton:SetWidth(100)
copyButton:SetHeight(20)
copyButton:SetPoint("BOTTOMLEFT", ExportFrame, "BOTTOMLEFT", 10, 10)
copyButton:SetScript("OnClick", function()
    editBox:HighlightText()
    editBox:SetFocus()
end)


local importButton = CreateFrame("Button", nil, ExportFrame, "GameMenuButtonTemplate")
importButton:SetText("Import")
importButton:SetWidth(80)
importButton:SetHeight(20)
importButton:SetPoint("BOTTOM", ExportFrame, "BOTTOM", 0, 10)
importButton:SetScript("OnClick", function()
    local text = editBox:GetText()
    
   
    if not text or strtrim(text) == "" then
        ShowStaticPopup("Import failed: No data to import", "import")
        return
    end
    
   
    text = string.gsub(text, "([%[%]])%s*=%s*", "%1 = ")
    text = string.gsub(text, "(%d+)%s*=%s*", "[%1] = ")
    
   
    if strsub(strtrim(text), 1, 1) == "{" then
        text = "return " .. text
    end
    
   
    local env = {}
    local func, err = loadstring(text)
    
    if not func then
        ShowStaticPopup("Import failed: "..(err or "Syntax error"), "import")
        return
    end
    
    setfenv(func, env)
    local success, result = pcall(func)
    
    if success then
       
        local importedTable = result or env.FillRaidPresets
        if type(importedTable) == "table" then
            FillRaidPresets = importedTable
            ShowStaticPopup("Presets imported successfully! Reloading UI...", "import", true)

        else
            ShowStaticPopup("Import failed: No valid table data found", "import")
        end
    else
        ShowStaticPopup("Import failed: "..(result or "Execution error"), "import")
    end
end)


local closeButton4 = CreateFrame("Button", nil, ExportFrame, "GameMenuButtonTemplate")
closeButton4:SetText("Close")
closeButton4:SetWidth(80)
closeButton4:SetHeight(20)
closeButton4:SetPoint("BOTTOMRIGHT", ExportFrame, "BOTTOMRIGHT", -10, 10)
closeButton4:SetScript("OnClick", function()
    ExportFrame:Hide()
end)




-------------------------------------------------------------------------------------------------------------------------------------
	local editmodeshown = false
	local editButton = CreateFrame("Button", nil, FillRaidFrame, "GameMenuButtonTemplate")
	editButton:SetPoint("TOPRIGHT", FillRaidFrame, "TOPRIGHT", -10, -50)
	editButton:SetWidth(80)
	editButton:SetHeight(20)
	editButton:SetText("Edit")
	editButton:SetScript("OnClick", function()
		if saveButton:IsShown() then
			saveButton:Hide()
			saveAsButton:Hide()
			openExportButton:Hide()
			removeButton:Hide()
			restoreDefaultsButton:Hide()
			editButton2:Hide()
			saveAsButton:Hide()
			currentInstanceLabel:Hide()
			currentPresetLabel:Hide()
			fillRaidButton:Show()
			closeButton:Show()
			editButton:SetText("Edit")
		else
			saveButton:Show()
			saveAsButton:Show()
			openExportButton:Show()
			removeButton:Show()
			restoreDefaultsButton:Show()
			editButton2:Show()
			saveAsButton:Show()	
			currentInstanceLabel:Show()
			currentPresetLabel:Show()
			fillRaidButton:Hide()
			closeButton:Hide()
			editButton:SetText("Back")
			if not editmodeshown then
			ShowStaticPopup("Edit mode activated. You can now save your changes.", "Preset Saved")
			editmodeshown = true
			end

		end
	end)

	currentPresetLabel = FillRaidFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	currentPresetLabel:SetPoint("TOPLEFT", openSettingsButton, "BOTTOMLEFT", 0, -15)
	currentPresetLabel:SetText("Preset: None")
	currentPresetName = nil
	currentPresetLabel:Hide()
	
	currentInstanceLabel = FillRaidFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	currentInstanceLabel:SetPoint("TOPLEFT", openSettingsButton, "BOTTOMLEFT", 0, -5) 
	currentInstanceLabel:SetText("Instance: None") 
	currentInstanceName = nil
	currentInstanceLabel:Hide()
			
local CreditsFrame = CreateFrame("Frame", "CreditsFrame", UIParent)
CreditsFrame:SetWidth(300)
CreditsFrame:SetHeight(230)
CreditsFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
CreditsFrame:SetFrameStrata("DIALOG")  
CreditsFrame:SetFrameLevel(1)  

CreditsFrame:EnableMouse(true)
CreditsFrame:SetMovable(true)
CreditsFrame:RegisterForDrag("LeftButton")
CreditsFrame:SetScript("OnDragStart", CreditsFrame.StartMoving)
CreditsFrame:SetScript("OnDragStop", CreditsFrame.StopMovingOrSizing)

CreditsFrame:SetScript("OnMouseDown", function()
    if arg1 == "LeftButton" and not this.isMoving then
        this:StartMoving()
        this.isMoving = true
    end
end)
CreditsFrame:SetScript("OnMouseUp", function()
    if arg1 == "LeftButton" and this.isMoving then
        this:StopMovingOrSizing()
        this.isMoving = false
    end
end)


CreditsFrame.background = CreditsFrame:CreateTexture(nil, "BACKGROUND")
CreditsFrame.background:SetAllPoints(CreditsFrame)
CreditsFrame.background:SetTexture(0, 0, 0, 1)  
  


CreditsFrame.border = CreateFrame("Frame", nil, CreditsFrame, BackdropTemplateMixin and "BackdropTemplate")
CreditsFrame.border:SetPoint("TOPLEFT", -4, 4)
CreditsFrame.border:SetPoint("BOTTOMRIGHT", 4, -4)
CreditsFrame.border:SetBackdrop({
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border", 
    edgeSize = 16,
})
CreditsFrame.border:SetBackdropBorderColor(0.8, 0.8, 0.8)
CreditsFrame.border:SetFrameLevel(CreditsFrame:GetFrameLevel() + 1)  


CreditsFrame.header = CreateFrame("Frame", nil, CreditsFrame)
CreditsFrame.header:SetWidth(250)
CreditsFrame.header:SetHeight(64)
CreditsFrame.header:SetPoint('TOP', CreditsFrame, 0, 18)
CreditsFrame.header:SetFrameLevel(CreditsFrame:GetFrameLevel() + 2)  

CreditsFrame.header.texture = CreditsFrame.header:CreateTexture(nil, 'ARTWORK')
CreditsFrame.header.texture:SetAllPoints(CreditsFrame.header)
CreditsFrame.header.texture:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
CreditsFrame.header.texture:SetVertexColor(0.2, 0.2, 0.2)

CreditsFrame.header.text = CreditsFrame.header:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
CreditsFrame.header.text:SetPoint('TOP', CreditsFrame.header, 0, -14)
CreditsFrame.header.text:SetText('Credits')

local creditsData = {
    {name = "|cffffd700Pumpan|r", contribution = "Creator of the addon"},  

    {name = "|cffffd700Dedirtyone|r", contribution = "Special thanks to Dedirtyone for his incredible generosity\nin donating 50EUR to help me get VIP status.\nYour support means so much and has truly motivated me\nto keep contributing to the community.\nThis addon wouldn't be the same without people like you!"},  

    {name = "|cffffd700TheSamurai206|r", contribution = "A huge thank you to TheSamurai206 (Zugginator) for his generous donation of 20EUR.\nYour support means a lot and helps me continue improving this addon.\nIt's supporters like you that keep this project going!"},

    {name = "|cffffd700Spinach|r", contribution = "A heartfelt thank you to Spinach for the generous 20EU<R donation.\nYour support truly means a lot and motivates me to keep improving this addon.\nAmazing supporters like you are what keep this project alive!"},

    {name = "|cffffffffGemma|r", contribution = "Has been part of the project from the very beginning.\nContributed many great ideas, helped with extensive beta testing,\nand created one of the button themes used in the addon.\nYour support and feedback have been invaluable!"},  

    {name = "|cffffffffNymz|r", contribution = "Since 2026, Nymz has contributed with great ideas,\ncode improvements for the 1.14 client version, bug reports,\nand also created a button theme.\nThese contributions have helped improve both the addon\nand the overall user experience."},	

    {name = "|cffffffffTO EVERYONE ELSE!|r", contribution = "To everyone who has been supporting!\nIf you are interested in contributing in any way,\nbug reporting, beta testing, or whatever,\nplease contact me on the forum, Discord, or in-game."},  
}

local function CreateCreditsButton(data, index)
    local nameButton = CreateFrame("Button", nil, CreditsFrame)
    nameButton:SetWidth(200)
    nameButton:SetHeight(20)
    nameButton:SetPoint("TOP", CreditsFrame, "TOP", 0, -40 - (index - 1) * 25)  

    
    local nameText = nameButton:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    nameText:SetText(data.name)
    nameText:SetPoint("CENTER", nameButton, "CENTER")

    
    nameButton:SetScript("OnEnter", function()
        GameTooltip:SetOwner(nameButton, "ANCHOR_RIGHT")
        GameTooltip:SetText(data.contribution, 1, 1, 1, true)  
        GameTooltip:Show()
    end)

    
    nameButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    
    nameButton:EnableMouse(true)
end

for index, data in ipairs(creditsData) do
    CreateCreditsButton(data, index)
end



local openCreditsButton = CreateFrame("Button", "OpenCreditsButton", FillRaidFrame, "UIPanelButtonTemplate")
openCreditsButton:SetWidth(55)
openCreditsButton:SetHeight(12)
openCreditsButton:SetText("Credits")
openCreditsButton:SetPoint("BOTTOMLEFT", FillRaidFrame, "BOTTOMLEFT", 5, 5)
openCreditsButton:GetFontString():SetFont("Fonts\\FRIZQT__.TTF", 10)


openCreditsButton:SetScript("OnClick", function()
    if CreditsFrame:IsShown() then
        CreditsFrame:Hide()
        ClickBlockerFrame:Hide()
    else
        CreditsFrame:Show()
        ClickBlockerFrame:Show()
    end
end)

CreditsFrame:Hide()

    
    local InstanceButtonsFrame = CreateFrame("Frame", "InstanceButtonsFrame", UIParent)
    InstanceButtonsFrame:SetWidth(200)
    InstanceButtonsFrame:SetHeight(350)
    InstanceButtonsFrame:SetPoint("LEFT", FillRaidFrame, "RIGHT", 10, 0)
    InstanceButtonsFrame:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    InstanceButtonsFrame:SetBackdropColor(0, 0, 0, 1) 
    InstanceButtonsFrame:SetFrameStrata("DIALOG")
    InstanceButtonsFrame:SetFrameLevel(10)
    InstanceButtonsFrame:Hide()
	table.insert(UISpecialFrames, "InstanceButtonsFrame")
    local instanceButtons = {}
    local function CreateInstanceButton(label, yOffset, frameName, presetName)
        local button = CreateFrame("Button", nil, InstanceButtonsFrame, "GameMenuButtonTemplate")
        local fullInstanceNames = {
            ["BWL"] = "Blackwing Lair",
            ["MC"] = "Molten Core",
            ["AQ40"] = "Temple of Ahn'Qiraj",
            ["AQ20"] = "Ruins of Ahn'Qiraj",
            ["ZG"] = "Zul'Gurub",
            ["Other"] = "Other Presets",
        }
        button:SetPoint("TOP", InstanceButtonsFrame, "TOP", 0, yOffset)
        button:SetWidth(180)
        button:SetHeight(30)
        button:SetText(label)
		button:SetScript("OnEnter", function()
			local fullLabel = fullInstanceNames[label] or label

			GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
			GameTooltip:ClearLines()
			GameTooltip:SetText(fullLabel) 

			GameTooltip:Show()
		end)

		button:SetScript("OnLeave", function()
			GameTooltip:Hide()
		end)
        button:SetScript("OnClick", function()
            InstanceButtonsFrame:Hide()
            ClickBlockerFrame:Show()
			
			if currentInstanceLabel then
				currentInstanceLabel:SetText("Instance: " .. label)
				currentInstanceName = presetName
			end			
			
            local frame = instanceFrames[frameName]
            if frame then
                frame:Show()
            else
                QueueDebugMessage("Error: Frame '" .. frameName .. "' not found.", "debugerror")
            end
			if frame.headerText then
				frame.headerText:SetText(label)
			end
			
        end)
        return button
    end


    CreateInstanceButton("Naxxramas", -10, "PresetDungeounNaxxramas", "naxxramasPresets")
    CreateInstanceButton("BWL", -50, "PresetDungeounBWL", "bwlPresets")
    CreateInstanceButton("MC", -90, "PresetDungeounMC", "mcPresets")
    CreateInstanceButton("Onyxia", -130, "PresetDungeounOnyxia", "onyxiaPresets")
    CreateInstanceButton("AQ40", -170, "PresetDungeounAQ40", "aq40Presets")
    CreateInstanceButton("AQ20", -210, "PresetDungeounAQ20", "aq20Presets")	
    CreateInstanceButton("ZG", -250, "PresetDungeounZG", "ZGPresets")	
	CreateInstanceButton("Other", -290, "PresetDungeounOther", "otherPresets")


    
local function TruncateToFit(button, text, maxWidth)
    if not text then
        return "", false
    end

    local fontString = button:GetFontString()
    if not fontString then
        return text, false
    end

    fontString:SetText(text)

    if fontString:GetStringWidth() <= maxWidth then
        return text, false
    end

    local truncated = text
    local ellipsis = "..."

    while string.len(truncated) > 0 do
        truncated = string.sub(truncated, 1, string.len(truncated) - 1)
        fontString:SetText(truncated .. ellipsis)

        if fontString:GetStringWidth() <= maxWidth then
            return truncated .. ellipsis, true
        end
    end

    return ellipsis, true
end




local tutorialLinkPopup
local tutorialLinkPopupTitle
local tutorialLinkPopupDescription
local tutorialLinkPopupAudience
local tutorialLinkPopupSingleLabel
local tutorialLinkPopupEditBox
local tutorialLinkPopupCopyButton
local tutorialLinkPopupRows

local TUTORIAL_POPUP_IMAGE_SIZE = 200
local TUTORIAL_POPUP_PADDING = 16
local TUTORIAL_POPUP_GAP = 14
local TUTORIAL_POPUP_TOP_OFFSET = -42
local TUTORIAL_POPUP_RIGHT_WIDTH = 360
local TUTORIAL_POPUP_BOTTOM_PADDING = 56
local TUTORIAL_POPUP_MIN_HEIGHT = 300
local TUTORIAL_POPUP_ROW_HEIGHT = 38
local TUTORIAL_POPUP_ROW_BUTTON_WIDTH = 90
local TUTORIAL_POPUP_ROW_BUTTON_GAP = 8
local TUTORIAL_BOSS_IMAGE_BASE_PATH = "Interface\\AddOns\\FillRaidBots\\img\\bosses\\"
local TUTORIAL_BOSS_IMAGE_DEFAULT = TUTORIAL_BOSS_IMAGE_BASE_PATH .. "default"

local function GetTutorialPopupLayout()
    local imageSize = TUTORIAL_POPUP_IMAGE_SIZE
    local padding = TUTORIAL_POPUP_PADDING
    local gap = TUTORIAL_POPUP_GAP
    local rightWidth = TUTORIAL_POPUP_RIGHT_WIDTH
    local buttonWidth = TUTORIAL_POPUP_ROW_BUTTON_WIDTH
    local buttonGap = TUTORIAL_POPUP_ROW_BUTTON_GAP
    local popupWidth = padding + imageSize + gap + rightWidth + padding
    local textLeft = padding + imageSize + gap
    local editBoxWidth = rightWidth - buttonWidth - buttonGap

    if editBoxWidth < 120 then
        editBoxWidth = 120
    end

    return {
        imageSize = imageSize,
        padding = padding,
        gap = gap,
        rightWidth = rightWidth,
        buttonWidth = buttonWidth,
        buttonGap = buttonGap,
        popupWidth = popupWidth,
        textLeft = textLeft,
        textRight = -padding,
        imageLeft = padding,
        imageTop = TUTORIAL_POPUP_TOP_OFFSET,
        topY = TUTORIAL_POPUP_TOP_OFFSET,
        editBoxWidth = editBoxWidth,
        rowHeight = TUTORIAL_POPUP_ROW_HEIGHT,
        bottomPadding = TUTORIAL_POPUP_BOTTOM_PADDING,
        minHeight = TUTORIAL_POPUP_MIN_HEIGHT,
    }
end

local function SetTutorialBossImage(texture, preset)
    local texturePath = nil
    local imageName = nil

    if preset then
        imageName = preset.fullname or preset.label
    end

    if imageName and imageName ~= "" then
        texturePath = TUTORIAL_BOSS_IMAGE_BASE_PATH .. imageName
    else
        texturePath = TUTORIAL_BOSS_IMAGE_DEFAULT
    end

    texture:SetTexture(texturePath)
end

GetTutorialLinksForPlayer = function(linkInfo)
    local factionGroup
    local factionKey
    local vipKey
    local variant
    local fallbackVariant
    local fallbackFaction
    local factionText
    local vipText

    local RED = "|cffff4040"
    local GRAY = "|cffaaaaaa"
    local RESET = "|r"

    if not linkInfo then
        return nil, nil
    end

    if linkInfo.url then
        return {
            {
                label = "Tutorial",
                url = linkInfo.url,
            }
        }, "General"
    end

    factionGroup = UnitFactionGroup("player")
    factionKey = (factionGroup == "Horde") and "horde" or "alliance"
    vipKey = (FillRaidBotsSavedSettings and FillRaidBotsSavedSettings.isVIP) and "vip" or "nonvip"

    factionText = (factionKey == "horde") and "Horde" or "Alliance"
    vipText = (vipKey == "vip") and "VIP" or "nonVIP"

    local requestedText = factionText .. " " .. vipText

    variant = linkInfo[factionKey]
    if variant and variant[vipKey] and table.getn(variant[vipKey]) > 0 then
        return variant[vipKey], requestedText
    end

    if variant then
        fallbackVariant = (vipKey == "vip") and variant.nonvip or variant.vip
        if fallbackVariant and table.getn(fallbackVariant) > 0 then
            local fallbackVipText = (vipKey == "vip") and "nonVIP" or "VIP"
            return fallbackVariant,
                RED .. "No " .. requestedText .. " tutorial found." .. RESET ..
                "\n" ..
                GRAY .. "Using fallback:" .. RESET .. " " .. factionText .. " " .. fallbackVipText
        end
    end

    fallbackFaction = (factionKey == "horde") and "alliance" or "horde"
    variant = linkInfo[fallbackFaction]
    local fallbackFactionText = (fallbackFaction == "horde") and "Horde" or "Alliance"

    if variant and variant[vipKey] and table.getn(variant[vipKey]) > 0 then
        return variant[vipKey],
            RED .. "No " .. requestedText .. " tutorial found." .. RESET ..
            "\n" ..
            GRAY .. "Using fallback:" .. RESET .. " " .. fallbackFactionText .. " " .. vipText
    end

    if variant then
        fallbackVariant = (vipKey == "vip") and variant.nonvip or variant.vip
        if fallbackVariant and table.getn(fallbackVariant) > 0 then
            local fallbackVipText = (vipKey == "vip") and "nonVIP" or "VIP"
            return fallbackVariant,
                RED .. "No " .. requestedText .. " tutorial found." .. RESET ..
                "\n" ..
                GRAY .. "Using fallback:" .. RESET .. " " .. fallbackFactionText .. " " .. fallbackVipText
        end
    end

    if linkInfo.alliance then
        if linkInfo.alliance.nonvip and table.getn(linkInfo.alliance.nonvip) > 0 then
            return linkInfo.alliance.nonvip,
                RED .. "No " .. requestedText .. " tutorial found." .. RESET ..
                "\n" ..
                GRAY .. "Using fallback:" .. RESET .. " Alliance nonVIP"
        end
        if linkInfo.alliance.vip and table.getn(linkInfo.alliance.vip) > 0 then
            return linkInfo.alliance.vip,
                RED .. "No " .. requestedText .. " tutorial found." .. RESET ..
                "\n" ..
                GRAY .. "Using fallback:" .. RESET .. " Alliance VIP"
        end
    end

    if linkInfo.horde then
        if linkInfo.horde.nonvip and table.getn(linkInfo.horde.nonvip) > 0 then
            return linkInfo.horde.nonvip,
                RED .. "No " .. requestedText .. " tutorial found." .. RESET ..
                "\n" ..
                GRAY .. "Using fallback:" .. RESET .. " Horde nonVIP"
        end
        if linkInfo.horde.vip and table.getn(linkInfo.horde.vip) > 0 then
            return linkInfo.horde.vip,
                RED .. "No " .. requestedText .. " tutorial found." .. RESET ..
                "\n" ..
                GRAY .. "Using fallback:" .. RESET .. " Horde VIP"
        end
    end

    return nil, nil
end

GetTutorialLinkInfoForPreset = function(preset)
    local info

    if not preset or not FillRaidTutorialLinks then
        return nil
    end

    if preset.fullname and FillRaidTutorialLinks[preset.fullname] then
        return FillRaidTutorialLinks[preset.fullname]
    end

    if preset.label and FillRaidTutorialLinks[preset.label] then
        return FillRaidTutorialLinks[preset.label]
    end

    if preset.bosses then
        for _, bossName in ipairs(preset.bosses) do
            info = FillRaidTutorialLinks[bossName]
            if info then
                return info
            end
        end
    end

    return nil
end

EnsureTutorialLinkPopup = function()
    local i
    local row
    local layout = GetTutorialPopupLayout()

    if tutorialLinkPopup then
        return
    end

    tutorialLinkPopup = CreateFrame("Frame", "FillRaidTutorialLinkPopup", UIParent)
    tutorialLinkPopup:SetWidth(layout.popupWidth)
    tutorialLinkPopup:SetHeight(layout.minHeight)
    tutorialLinkPopup:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    tutorialLinkPopup:SetFrameStrata("DIALOG")
    tutorialLinkPopup:SetFrameLevel(30)
    tutorialLinkPopup:SetMovable(true)
    tutorialLinkPopup:EnableMouse(true)
    tutorialLinkPopup:RegisterForDrag("LeftButton")

    tutorialLinkPopup.background = tutorialLinkPopup:CreateTexture(nil, "BACKGROUND")
    tutorialLinkPopup.background:SetAllPoints(tutorialLinkPopup)
    tutorialLinkPopup.background:SetTexture(0, 0, 0, 1)

    tutorialLinkPopup.border = CreateFrame("Frame", nil, tutorialLinkPopup)
    tutorialLinkPopup.border:SetPoint("TOPLEFT", tutorialLinkPopup, "TOPLEFT", -4, 4)
    tutorialLinkPopup.border:SetPoint("BOTTOMRIGHT", tutorialLinkPopup, "BOTTOMRIGHT", 4, -4)
    tutorialLinkPopup.border:SetFrameStrata(tutorialLinkPopup:GetFrameStrata())
    tutorialLinkPopup.border:SetFrameLevel(tutorialLinkPopup:GetFrameLevel() - 1)
    tutorialLinkPopup.border:SetBackdrop({
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 16,
    })
    tutorialLinkPopup.border:SetBackdropBorderColor(0.8, 0.8, 0.8)

    tutorialLinkPopup.header = tutorialLinkPopup:CreateTexture(nil, "OVERLAY")
    tutorialLinkPopup.header:SetWidth(220)
    tutorialLinkPopup.header:SetHeight(48)
    tutorialLinkPopup.header:SetPoint("TOP", tutorialLinkPopup, "TOP", 0, 12)
    tutorialLinkPopup.header:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
    tutorialLinkPopup.header:SetVertexColor(0.2, 0.2, 0.2)

    tutorialLinkPopup.headerText = tutorialLinkPopup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    tutorialLinkPopup.headerText:SetPoint("TOP", tutorialLinkPopup.header, "TOP", 0, -12)
    tutorialLinkPopup.headerText:SetText("Tutorial")

    tutorialLinkPopup:Hide()
    table.insert(UISpecialFrames, "FillRaidTutorialLinkPopup")

    tutorialLinkPopup:SetScript("OnDragStart", function()
        tutorialLinkPopup:StartMoving()
    end)

    tutorialLinkPopup:SetScript("OnDragStop", function()
        tutorialLinkPopup:StopMovingOrSizing()
    end)

    tutorialLinkPopupTitle = tutorialLinkPopup:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    tutorialLinkPopupTitle:SetPoint("TOP", tutorialLinkPopup, "TOP", 0, -12)
    tutorialLinkPopupTitle:SetText("Tutorial Link")

    tutorialLinkPopup.bossImage = tutorialLinkPopup:CreateTexture(nil, "ARTWORK")
    tutorialLinkPopup.bossImage:SetWidth(layout.imageSize)
    tutorialLinkPopup.bossImage:SetHeight(layout.imageSize)
    tutorialLinkPopup.bossImage:SetPoint("TOPLEFT", tutorialLinkPopup, "TOPLEFT", layout.imageLeft, layout.imageTop)
    tutorialLinkPopup.bossImage:SetTexCoord(0, 1, 0, 1)

    tutorialLinkPopupDescription = tutorialLinkPopup:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    tutorialLinkPopupDescription:SetPoint("TOPLEFT", tutorialLinkPopup, "TOPLEFT", layout.textLeft, layout.topY)
    tutorialLinkPopupDescription:SetPoint("TOPRIGHT", tutorialLinkPopup, "TOPRIGHT", layout.textRight, layout.topY)
    tutorialLinkPopupDescription:SetWidth(layout.rightWidth)
    tutorialLinkPopupDescription:SetJustifyH("LEFT")
    tutorialLinkPopupDescription:SetJustifyV("TOP")
    tutorialLinkPopupDescription:SetText("")

    tutorialLinkPopupAudience = tutorialLinkPopup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    tutorialLinkPopupAudience:SetPoint("TOPLEFT", tutorialLinkPopup, "TOPLEFT", layout.textLeft, layout.topY - 58)
    tutorialLinkPopupAudience:SetPoint("TOPRIGHT", tutorialLinkPopup, "TOPRIGHT", layout.textRight, layout.topY - 58)
    tutorialLinkPopupAudience:SetJustifyH("LEFT")
    tutorialLinkPopupAudience:SetJustifyV("TOP")
    tutorialLinkPopupAudience:SetText("")

    tutorialLinkPopupSingleLabel = tutorialLinkPopup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    tutorialLinkPopupSingleLabel:SetPoint("TOPLEFT", tutorialLinkPopup, "TOPLEFT", layout.textLeft, layout.topY - 82)
    tutorialLinkPopupSingleLabel:SetText("Copy URL:")

    tutorialLinkPopupEditBox = CreateFrame("EditBox", "FillRaidTutorialLinkEditBox", tutorialLinkPopup, "InputBoxTemplate")
    tutorialLinkPopupEditBox:SetWidth(layout.editBoxWidth)
    tutorialLinkPopupEditBox:SetHeight(20)
    tutorialLinkPopupEditBox:SetPoint("TOPLEFT", tutorialLinkPopup, "TOPLEFT", layout.textLeft, layout.topY - 100)
    tutorialLinkPopupEditBox:SetAutoFocus(false)
    if tutorialLinkPopupEditBox.SetTextInsets then
        tutorialLinkPopupEditBox:SetTextInsets(4, 4, 0, 0)
    end
    tutorialLinkPopupEditBox:SetScript("OnEscapePressed", function()
        tutorialLinkPopupEditBox:ClearFocus()
        tutorialLinkPopup:Hide()
    end)

    tutorialLinkPopupEditBox.urlValue = ""
    tutorialLinkPopupEditBox.display = tutorialLinkPopupEditBox:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    tutorialLinkPopupEditBox.display:SetPoint("LEFT", tutorialLinkPopupEditBox, "LEFT", 6, 0)
    tutorialLinkPopupEditBox.display:SetPoint("RIGHT", tutorialLinkPopupEditBox, "RIGHT", -6, 0)
    tutorialLinkPopupEditBox.display:SetJustifyH("LEFT")
    tutorialLinkPopupEditBox.display:SetJustifyV("MIDDLE")
    tutorialLinkPopupEditBox.display:SetText("")
    tutorialLinkPopupEditBox:SetScript("OnEditFocusGained", function()
        if tutorialLinkPopupEditBox.display then
            tutorialLinkPopupEditBox.display:Hide()
        end
    end)
    tutorialLinkPopupEditBox:SetScript("OnEditFocusLost", function()
        tutorialLinkPopupEditBox:SetText("")
        if tutorialLinkPopupEditBox.display then
            tutorialLinkPopupEditBox.display:Show()
        end
    end)

    tutorialLinkPopupCopyButton = CreateFrame("Button", nil, tutorialLinkPopup, "GameMenuButtonTemplate")
    tutorialLinkPopupCopyButton:SetWidth(layout.buttonWidth)
    tutorialLinkPopupCopyButton:SetHeight(22)
    tutorialLinkPopupCopyButton:SetPoint("LEFT", tutorialLinkPopupEditBox, "RIGHT", layout.buttonGap, 0)
    tutorialLinkPopupCopyButton:SetText("Select")
    tutorialLinkPopupCopyButton:SetScript("OnClick", function()
        tutorialLinkPopupEditBox:SetText(tutorialLinkPopupEditBox.urlValue or "")
        if tutorialLinkPopupEditBox.display then
            tutorialLinkPopupEditBox.display:Hide()
        end
        tutorialLinkPopupEditBox:SetFocus()
        tutorialLinkPopupEditBox:HighlightText()
    end)

    tutorialLinkPopupRows = {}

    for i = 1, 5 do
        row = {}

        row.label = tutorialLinkPopup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        row.label:SetPoint("TOPLEFT", tutorialLinkPopup, "TOPLEFT", layout.textLeft, layout.topY - 82 - ((i - 1) * layout.rowHeight))
        row.label:SetJustifyH("LEFT")
        row.label:SetText("Guide")
        row.label:Hide()

        row.editBox = CreateFrame("EditBox", "FillRaidTutorialLinkEditBox" .. i, tutorialLinkPopup, "InputBoxTemplate")
        row.editBox:SetWidth(layout.editBoxWidth)
        row.editBox:SetHeight(20)
        row.editBox:SetPoint("TOPLEFT", row.label, "BOTTOMLEFT", 0, -4)
        row.editBox:SetAutoFocus(false)
        if row.editBox.SetTextInsets then
            row.editBox:SetTextInsets(4, 4, 0, 0)
        end
        row.editBox:SetScript("OnEscapePressed", function()
            this:ClearFocus()
            tutorialLinkPopup:Hide()
        end)
        row.editBox.urlValue = ""
        row.editBox.display = row.editBox:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        row.editBox.display:SetPoint("LEFT", row.editBox, "LEFT", 6, 0)
        row.editBox.display:SetPoint("RIGHT", row.editBox, "RIGHT", -6, 0)
        row.editBox.display:SetJustifyH("LEFT")
        row.editBox.display:SetJustifyV("MIDDLE")
        row.editBox.display:SetText("")
        row.editBox:SetScript("OnEditFocusGained", function()
            if this.display then
                this.display:Hide()
            end
        end)
        row.editBox:SetScript("OnEditFocusLost", function()
            this:SetText("")
            if this.display then
                this.display:Show()
            end
        end)
        row.editBox:Hide()

        row.copyButton = CreateFrame("Button", nil, tutorialLinkPopup, "GameMenuButtonTemplate")
        row.copyButton:SetWidth(layout.buttonWidth)
        row.copyButton:SetHeight(20)
        row.copyButton:SetPoint("LEFT", row.editBox, "RIGHT", layout.buttonGap, 0)
        row.copyButton:SetText("Select")
        row.copyButton:Hide()

        tutorialLinkPopupRows[i] = row
    end

    local closeButton = CreateFrame("Button", nil, tutorialLinkPopup, "GameMenuButtonTemplate")
    closeButton:SetWidth(100)
    closeButton:SetHeight(22)
    closeButton:SetPoint("BOTTOM", tutorialLinkPopup, "BOTTOM", 0, 14)
    closeButton:SetText("Close")
    closeButton:SetScript("OnClick", function()
        tutorialLinkPopupEditBox:ClearFocus()
        tutorialLinkPopup:Hide()
    end)
end

local function CopyTutorialUrl(url, editBox)
    local targetBox = editBox or tutorialLinkPopupEditBox
    local targetUrl = url or targetBox.urlValue or ""
    targetBox.urlValue = targetUrl
    targetBox:SetText(targetUrl)
    if targetBox.display then
        targetBox.display:Hide()
    end
    targetBox:SetFocus()
    targetBox:HighlightText()
end

ShowTutorialLinkPopup = function(preset, linkInfo)
    local availableLinks
    local audienceText
    local rowIndex
    local row
    local guideInfo
    local visibleRowCount
    local descriptionText
    local descriptionHeight
    local audienceHeight
    local contentStartY
    local popupHeight
    local maxRows
    local layout
    local imageBottomY
    local contentBottomY
    local guideSectionTopY

    EnsureTutorialLinkPopup()

    layout = GetTutorialPopupLayout()
    tutorialLinkPopup:SetWidth(layout.popupWidth)

    tutorialLinkPopupTitle:SetText((preset and (preset.fullname or preset.label)) or "Tutorial")
    tutorialLinkPopup.bossImage:SetWidth(layout.imageSize)
    tutorialLinkPopup.bossImage:SetHeight(layout.imageSize)
    tutorialLinkPopup.bossImage:ClearAllPoints()
    tutorialLinkPopup.bossImage:SetPoint("TOPLEFT", tutorialLinkPopup, "TOPLEFT", layout.imageLeft, layout.imageTop)
    SetTutorialBossImage(tutorialLinkPopup.bossImage, preset)

    availableLinks, audienceText = GetTutorialLinksForPlayer(linkInfo)

    descriptionText = (linkInfo and linkInfo.description) or ""
    tutorialLinkPopupDescription:SetText(descriptionText)
    tutorialLinkPopupDescription:SetWidth(layout.rightWidth)
    tutorialLinkPopupDescription:SetJustifyH("LEFT")
    tutorialLinkPopupDescription:SetJustifyV("TOP")
    tutorialLinkPopupDescription:ClearAllPoints()
    tutorialLinkPopupDescription:SetPoint("TOPLEFT", tutorialLinkPopup, "TOPLEFT", layout.textLeft, layout.topY)
    tutorialLinkPopupDescription:SetPoint("TOPRIGHT", tutorialLinkPopup, "TOPRIGHT", layout.textRight, layout.topY)

    tutorialLinkPopupAudience:SetText(audienceText and ("" .. audienceText) or "Showing: No matching guide")

    tutorialLinkPopupSingleLabel:Hide()
    tutorialLinkPopupEditBox:Hide()
    tutorialLinkPopupCopyButton:Hide()
    tutorialLinkPopupEditBox.urlValue = ""
    tutorialLinkPopupEditBox:SetText("")
    if tutorialLinkPopupEditBox.display then
        tutorialLinkPopupEditBox.display:SetText("")
    end
    tutorialLinkPopupEditBox:ClearFocus()

    for rowIndex = 1, table.getn(tutorialLinkPopupRows) do
        row = tutorialLinkPopupRows[rowIndex]
        row.label:Hide()
        row.editBox:Hide()
        row.copyButton:Hide()
        row.label:SetText("")
        row.editBox.urlValue = ""
        row.editBox:SetText("")
        if row.editBox.display then
            row.editBox.display:SetText("")
        end
        row.editBox:ClearFocus()
    end

    descriptionHeight = tutorialLinkPopupDescription.GetHeight and tutorialLinkPopupDescription:GetHeight() or 14
    if not descriptionHeight or descriptionHeight < 14 then
        descriptionHeight = 14
    end

    tutorialLinkPopupAudience:SetWidth(layout.rightWidth)
    tutorialLinkPopupAudience:ClearAllPoints()
    tutorialLinkPopupAudience:SetPoint("TOPLEFT", tutorialLinkPopup, "TOPLEFT", layout.textLeft, layout.topY - descriptionHeight - 12)
    tutorialLinkPopupAudience:SetPoint("TOPRIGHT", tutorialLinkPopup, "TOPRIGHT", layout.textRight, layout.topY - descriptionHeight - 12)

    audienceHeight = tutorialLinkPopupAudience.GetHeight and tutorialLinkPopupAudience:GetHeight() or 14
    if not audienceHeight or audienceHeight < 14 then
        audienceHeight = 14
    end

    contentStartY = layout.topY - descriptionHeight - 12 - audienceHeight - 10
    guideSectionTopY = contentStartY

    tutorialLinkPopupSingleLabel:ClearAllPoints()
    tutorialLinkPopupSingleLabel:SetPoint("TOPLEFT", tutorialLinkPopup, "TOPLEFT", layout.textLeft, guideSectionTopY)

    tutorialLinkPopupEditBox:SetWidth(layout.editBoxWidth)
    tutorialLinkPopupEditBox:ClearAllPoints()
    tutorialLinkPopupEditBox:SetPoint("TOPLEFT", tutorialLinkPopupSingleLabel, "BOTTOMLEFT", 0, -4)

    tutorialLinkPopupCopyButton:SetWidth(layout.buttonWidth)
    tutorialLinkPopupCopyButton:ClearAllPoints()
    tutorialLinkPopupCopyButton:SetPoint("LEFT", tutorialLinkPopupEditBox, "RIGHT", layout.buttonGap, 0)

    maxRows = table.getn(tutorialLinkPopupRows)
    visibleRowCount = 0

    if availableLinks and table.getn(availableLinks) > 0 then
        visibleRowCount = math.min(table.getn(availableLinks), maxRows)

        for rowIndex = 1, visibleRowCount do
            row = tutorialLinkPopupRows[rowIndex]
            guideInfo = availableLinks[rowIndex]

            if not row or not guideInfo then
                break
            end

            row.label:ClearAllPoints()
            row.label:SetPoint("TOPLEFT", tutorialLinkPopup, "TOPLEFT", layout.textLeft, guideSectionTopY - ((rowIndex - 1) * layout.rowHeight))
            row.label:SetText("Tutorial: " .. (guideInfo.label or ("Guide " .. rowIndex)))

            row.editBox:SetWidth(layout.editBoxWidth)
            row.editBox:ClearAllPoints()
            row.editBox:SetPoint("TOPLEFT", row.label, "BOTTOMLEFT", 0, -4)
            row.editBox.urlValue = guideInfo.url or ""
            row.editBox:SetText("")
            if row.editBox.display then
                row.editBox.display:SetText(row.editBox.urlValue)
            end

            row.copyButton:SetWidth(layout.buttonWidth)
            row.copyButton:ClearAllPoints()
            row.copyButton:SetPoint("LEFT", row.editBox, "RIGHT", layout.buttonGap, 0)

            row.label:Show()
            row.editBox:Show()
            row.copyButton:Show()

            do
                local targetEditBox = row.editBox
                row.copyButton:SetScript("OnClick", function()
                    CopyTutorialUrl(targetEditBox.urlValue or targetEditBox:GetText(), targetEditBox)
                end)
            end
        end
    end

    imageBottomY = math.abs(layout.topY) + layout.imageSize
    if visibleRowCount > 0 then
        contentBottomY = math.abs(guideSectionTopY) + (visibleRowCount * layout.rowHeight)
    else
        contentBottomY = math.abs(guideSectionTopY) + 8
    end

    popupHeight = math.max(imageBottomY, contentBottomY) + layout.bottomPadding
    if popupHeight < layout.minHeight then
        popupHeight = layout.minHeight
    end
    tutorialLinkPopup:SetHeight(popupHeight)

    tutorialLinkPopup:Show()
end

GetPresetValues = function(preset)
    if not preset then
        return nil
    end

    if FillRaidBotsSavedSettings and FillRaidBotsSavedSettings.useVipPresets then
        if preset.vipValues then
            return preset.vipValues
        end
    end

    return preset.values
end

function CreateInstanceFrame(name, presets, label)
    local buttonWidth = 80
    local buttonHeight = 30
    local padding = 10
    local maxButtonsPerColumn = 8
    
    
    
    local tutorialButtonSize = 18

    local totalButtonWidth = buttonWidth + padding
    local totalButtonHeight = buttonHeight + padding
    local includeOthersButton = (name ~= "PresetDungeounOther") and OthersButtonEnabled
    local numButtons = table.getn(presets) + (includeOthersButton and 1 or 0)
    local numColumns = math.ceil(numButtons / maxButtonsPerColumn)
    local numRows = math.min(numButtons, maxButtonsPerColumn)

    local dynamicWidth = (totalButtonWidth * numColumns) + padding
    local dynamicHeight = (totalButtonHeight * numRows) + padding
    local tutorialWidthBonus = tutorialButtonSize + 4

    local frame = CreateFrame("Frame", name, UIParent)
    setglobal(name, frame)
    table.insert(UISpecialFrames, name)

    frame.baseWidth = dynamicWidth
    frame.baseHeight = dynamicHeight
    frame.tutorialWidthBonus = tutorialWidthBonus
    frame.presetButtons = {}
    frame:SetWidth(dynamicWidth)
    frame:SetHeight(dynamicHeight)
    frame:SetPoint("LEFT", FillRaidFrame, "RIGHT", 10, 0)

    frame:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })

    frame:SetBackdropColor(0, 0, 0, 1)
    frame:SetFrameStrata("DIALOG")
    frame:SetFrameLevel(10)
    frame:Hide()

    frame.header = frame:CreateTexture(nil, 'ARTWORK')
    frame.header:SetWidth(dynamicWidth)
    frame.header:SetHeight(64)
    frame.header:SetPoint('TOP', frame, 0, 18)
    frame.header:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
    frame.header:SetVertexColor(.2, .2, .2)

    frame.headerText = frame:CreateFontString(nil, 'ARTWORK', 'GameFontNormal')
    frame.headerText:SetPoint('TOP', frame.header, 0, -14)
    frame.headerText:SetText(name)

    frame.tutorialButtons = {}

    local function IsTutorialLinksEnabled()
        return FillRaidBotsSavedSettings and FillRaidBotsSavedSettings.showTutorialLinks and true or false
    end

    local function ColumnHasVisibleTutorial(column)
        local info

        if not IsTutorialLinksEnabled() then
            return false
        end

        if not frame.presetButtons then
            return false
        end

        for _, buttonInfo in ipairs(frame.presetButtons) do
            if buttonInfo.column == column and buttonInfo.tutorialButton then
                return true
            end
        end

        return false
    end

    local function GetColumnWidth(column)
        local width = totalButtonWidth

        if ColumnHasVisibleTutorial(column) then
            width = width + tutorialWidthBonus
        end

        return width
    end

    local function GetEffectiveButtonCount()
        local count = table.getn(presets)

        if name ~= "PresetDungeounOther" and OthersButtonEnabled then
            count = count + 1
        end

        return count
    end

    local function GetLayoutWidth()
        local width = padding
        local effectiveColumns = math.ceil(GetEffectiveButtonCount() / maxButtonsPerColumn)
        local column

        for column = 0, effectiveColumns - 1 do
            width = width + GetColumnWidth(column)
        end

        return width
    end

    local fixedStartY = -10

    local function LayoutInstanceButtons()
        local xOffset = padding
        local columnOffsets = {}
        local column
        local buttonInfo
        local yOffset
        local targetWidth = GetLayoutWidth()
        local effectiveButtonCount = GetEffectiveButtonCount()
        local effectiveColumns = math.ceil(effectiveButtonCount / maxButtonsPerColumn)
        local effectiveRows = math.min(effectiveButtonCount, maxButtonsPerColumn)
        local targetHeight = (totalButtonHeight * effectiveRows) + padding

        frame:SetWidth(targetWidth)
        frame:SetHeight(targetHeight)
        frame.baseHeight = targetHeight

        if frame.header then
            frame.header:SetWidth(targetWidth)
        end

        for column = 0, effectiveColumns - 1 do
            columnOffsets[column] = xOffset
            xOffset = xOffset + GetColumnWidth(column)
        end

        if frame.presetButtons then
            for _, buttonInfo in ipairs(frame.presetButtons) do
                yOffset = fixedStartY - (buttonInfo.row * totalButtonHeight)

                buttonInfo.button:ClearAllPoints()
                buttonInfo.button:SetPoint("TOPLEFT", frame, "TOPLEFT", columnOffsets[buttonInfo.column] or padding, yOffset)

                if buttonInfo.tutorialButton then
                    buttonInfo.tutorialButton:ClearAllPoints()
                    buttonInfo.tutorialButton:SetPoint("LEFT", buttonInfo.button, "RIGHT", 2, 0)
                end
            end
        end

        if frame.othersButton then
            yOffset = fixedStartY - ((frame.othersButtonRow or 0) * totalButtonHeight)
            frame.othersButton:ClearAllPoints()
            frame.othersButton:SetPoint("TOPLEFT", frame, "TOPLEFT", columnOffsets[frame.othersButtonColumn or 0] or padding, yOffset)
        end
    end

    frame.UpdateTutorialWidth = LayoutInstanceButtons
    frame.UpdateInstanceLayout = LayoutInstanceButtons

    local function CreatePresetButton(preset, index)
        local button = CreateFrame("Button", nil, frame, "GameMenuButtonTemplate")
        button:SetWidth(buttonWidth)
        button:SetHeight(buttonHeight)

        local column = math.floor((index - 1) / maxButtonsPerColumn)
        local row = (index - 1) - column * maxButtonsPerColumn

        local yOffset = fixedStartY - (row * totalButtonHeight)

        button:SetPoint("TOPLEFT", frame, "TOPLEFT", padding, yOffset)

        
        local originalText = preset.label or "Unknown preset"
        local maxTextWidth = buttonWidth - 16  

        local finalText, wasTruncated = TruncateToFit(button, originalText, maxTextWidth)

        button:SetText(finalText)
        button.originalText = originalText
        button.wasTruncated = wasTruncated

        button:SetScript("OnClick", function()
            for classRole, inputBox in pairs(inputBoxes) do
                if inputBox then
                    inputBox:SetNumber(0)
                    local onTextChanged = inputBox:GetScript("OnTextChanged")
                    if onTextChanged then
                        onTextChanged(inputBox)
                    end
                end
            end

            currentLoadedPreset = preset
            ReapplyCurrentPreset()

            
            
            
            if IsShiftKeyDown() then
                FillRaid()
                ReplaceDeadBot = {}
                resetData()
                UpdateReFillButtonVisibility()
                FillRaidFrame:Hide()
            end
        end)

		button:SetScript("OnEnter", function()
			GameTooltip:SetOwner(button, "ANCHOR_RIGHT")

			local labelText = button.originalText or ""
			local fullName = preset.fullname
				GameTooltip:AddLine(fullName, 1, 1, 1)


			local selectedValues = GetPresetValues(preset)

			if selectedValues then
				GameTooltip:AddLine(" ")

				for classRole, value in pairs(selectedValues) do
					if value and value > 0 then

						local spacePos = string.find(classRole, " ")

						local class, role

						if spacePos then
							class = string.sub(classRole, 1, spacePos - 1)
							role  = string.sub(classRole, spacePos + 1)
						else
							class = classRole
						end

						local coloredClass = GetColoredClass(classRole)

						if role then
							GameTooltip:AddLine(value .. " " .. coloredClass .. " (" .. role .. ")")
						else
							GameTooltip:AddLine(value .. " " .. coloredClass)
						end
					end
				end
			end

			GameTooltip:Show()
		end)

        button:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        
        
        
        if name ~= "PresetDungeounOther" then
            local tutorialInfo = GetTutorialLinkInfoForPreset(preset)
            if tutorialInfo then
                local tutorialButton = CreateFrame("Button", nil, frame)
                tutorialButton:SetWidth(tutorialButtonSize)
                tutorialButton:SetHeight(tutorialButtonSize)
                tutorialButton:SetPoint("LEFT", button, "RIGHT", 2, 0)

                local tutorialTexture = tutorialButton:CreateTexture(nil, "ARTWORK")
                tutorialTexture:SetWidth(tutorialButtonSize)
                tutorialTexture:SetHeight(tutorialButtonSize)
                tutorialTexture:SetPoint("CENTER", tutorialButton, "CENTER", 0, 0)
                tutorialTexture:SetTexture("Interface\\Buttons\\UI-GuildButton-PublicNote-Up")
                tutorialButton.texture = tutorialTexture

                local tutorialHighlight = tutorialButton:CreateTexture(nil, "HIGHLIGHT")
                tutorialHighlight:SetAllPoints(tutorialButton)
                tutorialHighlight:SetTexture("Interface\\Buttons\\UI-Common-MouseHilight")
                tutorialHighlight:SetBlendMode("ADD")

                tutorialButton:SetScript("OnClick", function()
                    ShowTutorialLinkPopup(preset, tutorialInfo)
                end)

                tutorialButton:SetScript("OnEnter", function()
                    GameTooltip:SetOwner(tutorialButton, "ANCHOR_RIGHT")
                    GameTooltip:SetText("Tutorial Link")
                    GameTooltip:AddLine("Open a popup with faction/VIP-aware tutorial links.", 1, 1, 1, 1)
                    GameTooltip:Show()
                end)

                tutorialButton:SetScript("OnLeave", function()
                    GameTooltip:Hide()
                end)

                tutorialButton.linkInfo = tutorialInfo
                table.insert(frame.tutorialButtons, tutorialButton)
                button.tutorialButton = tutorialButton
            end
        end

        table.insert(frame.presetButtons, {
            button = button,
            tutorialButton = button.tutorialButton,
            column = column,
            row = row,
            preset = preset,
        })
    end

    for index, preset in ipairs(presets) do
        CreatePresetButton(preset, index)
    end



if name ~= "PresetDungeounOther" then
    local othersIndex = table.getn(presets) + 1

    local button = CreateFrame("Button", nil, frame, "GameMenuButtonTemplate")
    button:SetWidth(buttonWidth)
    button:SetHeight(buttonHeight)

    local column = math.floor((othersIndex - 1) / maxButtonsPerColumn)
    local row = (othersIndex - 1) - column * maxButtonsPerColumn

    local yOffset = fixedStartY - (row * totalButtonHeight)

    button:SetPoint("TOPLEFT", frame, "TOPLEFT", padding, yOffset)

    button:SetText("Others")

    
    frame.othersButton = button
    frame.othersButtonColumn = column
    frame.othersButtonRow = row

    
    if not OthersButtonEnabled then
        button:Hide()
    end

    button:SetScript("OnClick", function()
        frame:Hide()
        if instanceFrames and instanceFrames["PresetDungeounOther"] then
            instanceFrames["PresetDungeounOther"]:Show()
        end
    end)
end

    LayoutInstanceButtons()



function ToggleOthersButton(value)
    OthersButtonEnabled = value
    for _, frame in pairs(instanceFrames) do
        if frame.othersButton then
            if value then
                frame.othersButton:Show()
            else
                frame.othersButton:Hide()
            end
        end

        if frame.UpdateTutorialWidth then
            frame.UpdateTutorialWidth()
        elseif frame.UpdateInstanceLayout then
            frame.UpdateInstanceLayout()
        end
    end
end




UpdateTutorialLinkButtons = function()
    local enabled = FillRaidBotsSavedSettings and FillRaidBotsSavedSettings.showTutorialLinks

    if not instanceFrames then
        return
    end

    for _, frame in pairs(instanceFrames) do
        if frame.tutorialButtons then
            for _, tutorialButton in ipairs(frame.tutorialButtons) do
                if enabled then
                    tutorialButton:Show()
                else
                    tutorialButton:Hide()
                end
            end
        end

        if frame.UpdateTutorialWidth then
            frame.UpdateTutorialWidth(enabled)
        end
    end
end

function ToggleTutorialLinks(value)
    if not FillRaidBotsSavedSettings then
        FillRaidBotsSavedSettings = {}
    end

    FillRaidBotsSavedSettings.showTutorialLinks = value and true or false

    if UpdateTutorialLinkButtons then
        UpdateTutorialLinkButtons()
    end
end

-- ==================
-- open zone presets
------------------- open zone presets -----------------------
local ZoneToPreset = {
    ["Naxxramas"] = "PresetDungeounNaxxramas",
    ["Blackwing Lair"] = "PresetDungeounBWL",
    ["Molten Core"] = "PresetDungeounMC",
    ["Onyxia's Lair"] = "PresetDungeounOnyxia",
    ["Ahn'Qiraj"] = "PresetDungeounAQ40",      
    ["Ruins of Ahn'Qiraj"] = "PresetDungeounAQ20",
    ["Zul'Gurub"] = "PresetDungeounZG",
}
function OpenPresetForCurrentZone()
    local zone = GetRealZoneText()
    local frameName = ZoneToPreset[zone]

    if frameName then
        local frame = getglobal(frameName)
        if frame then
		    frame.headerText:SetText(zone)
            frame:Show()
			ClickBlockerFrame:Show() 
        end
    else
        DEFAULT_CHAT_FRAME:AddMessage("No preset mapped for this zone.")
    end
end	
------------------ add bots with a slash command --------------------------
local allPresets = {
    naxxramasPresets,
    bwlPresets,
    mcPresets,
    onyxiaPresets,
    aq40Presets,
    aq20Presets,
    ZGPresets,
    otherPresets
}

SLASH_FILLRAID1 = "/fillraid"

local function CollectMatchingPresets(msg, exactMatchOnly)
    local matches = {}
    local lowerMsg

    if not msg or type(msg) ~= "string" then
        return matches
    end

    lowerMsg = string.lower(strtrim(msg))
    if lowerMsg == "" then
        return matches
    end

    for _, presetTable in pairs(allPresets) do
        if type(presetTable) == "table" then
            for _, preset in ipairs(presetTable) do
                local matchFound = false

                if exactMatchOnly then
                    matchFound =
                        (preset.label and string.lower(strtrim(preset.label)) == lowerMsg) or
                        (preset.fullname and string.lower(strtrim(preset.fullname)) == lowerMsg)

                    if not matchFound and preset.bosses then
                        for _, bossName in ipairs(preset.bosses) do
                            if string.lower(strtrim(bossName)) == lowerMsg then
                                matchFound = true
                                break
                            end
                        end
                    end
                else
                    matchFound =
                        (preset.label and string.find(string.lower(preset.label), lowerMsg, 1, true)) or
                        (preset.fullname and string.find(string.lower(preset.fullname), lowerMsg, 1, true))

                    if not matchFound and preset.bosses then
                        for _, bossName in ipairs(preset.bosses) do
                            if string.find(string.lower(bossName), lowerMsg, 1, true) then
                                matchFound = true
                                break
                            end
                        end
                    end
                end

                if matchFound then
                    table.insert(matches, preset)
                end
            end
        end
    end

    return matches
end

local function ApplyPresetAndFill(preset)
    if not preset then
        QueueDebugMessage("FillRaid: ApplyPresetAndFill called with nil preset.", "debugerror")
        return
    end

    DEFAULT_CHAT_FRAME:AddMessage("Applying preset: " .. (preset.fullname or preset.label))
    QueueDebugMessage("FillRaid: Applying preset -> " .. (preset.fullname or preset.label), "debugfilling")

    for classRole, inputBox in pairs(inputBoxes) do
        if inputBox then
            inputBox:SetNumber(0)
            local onTextChanged = inputBox:GetScript("OnTextChanged")
            if onTextChanged then
                onTextChanged(inputBox)
            end
        end
    end

    currentLoadedPreset = preset
    ReapplyCurrentPreset()
    FillRaid()
end

setglobal("CollectMatchingPresets", CollectMatchingPresets)
setglobal("ApplyPresetAndFill", ApplyPresetAndFill)

SlashCmdList["FILLRAID"] = function(msg)
    if not msg or type(msg) ~= "string" or strtrim(msg) == "" then
        DEFAULT_CHAT_FRAME:AddMessage("Available presets:")

        for _, presetTable in pairs(allPresets) do
            if type(presetTable) == "table" then
                for _, preset in ipairs(presetTable) do
                    local displayText = preset.fullname or preset.label
                    if preset.bosses then
                        displayText = displayText .. " (" .. table.concat(preset.bosses, ", ") .. ")"
                    end
                    DEFAULT_CHAT_FRAME:AddMessage("- " .. displayText)
                end
            end
        end
        return
    end

    local matches = CollectMatchingPresets(msg)
    QueueDebugMessage("FillRaid: Search matches for '" .. msg .. "' -> " .. table.getn(matches), "debuginfo")

    if table.getn(matches) > 0 then
        ApplyPresetAndFill(matches[1])
        return
    end

    QueueDebugMessage("Error: Preset not found: " .. string.lower(msg), "debugerror")
end



    return frame
end

local detectBossFrame = CreateFrame("Frame")

local lastDetectedBoss = nil
local keyPressCooldown = false
ClickToFillEnabled = ClickToFillEnabled or false

local function ResetCooldown()
    keyPressCooldown = false
    lastDetectedBoss = nil
end

local chooserTimeoutFrame = CreateFrame("Frame")
local chooserTimeoutAt = nil
local clickToFillChooser = CreateFrame("Frame", "FillRaidBotsClickToFillChooser", UIParent)
clickToFillChooser:SetWidth(210)
clickToFillChooser:SetHeight(46)
clickToFillChooser:SetFrameStrata("DIALOG")
clickToFillChooser:SetFrameLevel(120)
clickToFillChooser:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 }
})
clickToFillChooser:SetBackdropColor(0, 0, 0, 0.95)
clickToFillChooser:EnableMouse(true)
clickToFillChooser:Hide()

local chooserLeftButton = CreateFrame("Button", nil, clickToFillChooser, "GameMenuButtonTemplate")
chooserLeftButton:SetWidth(95)
chooserLeftButton:SetHeight(24)
chooserLeftButton:SetPoint("LEFT", clickToFillChooser, "LEFT", 8, 0)

local chooserRightButton = CreateFrame("Button", nil, clickToFillChooser, "GameMenuButtonTemplate")
chooserRightButton:SetWidth(95)
chooserRightButton:SetHeight(24)
chooserRightButton:SetPoint("RIGHT", clickToFillChooser, "RIGHT", -8, 0)

local clickToFillListChooser = CreateFrame("Frame", "FillRaidBotsClickToFillListChooser", UIParent)
clickToFillListChooser:SetWidth(170)
clickToFillListChooser:SetHeight(40)
clickToFillListChooser:SetFrameStrata("DIALOG")
clickToFillListChooser:SetFrameLevel(160)
clickToFillListChooser:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 }
})
clickToFillListChooser:SetBackdropColor(0, 0, 0, 0.95)
clickToFillListChooser:EnableMouse(true)
clickToFillListChooser:Hide()

local clickToFillListButtons = {}
local chooserTimeoutToken = 0

local clickToFillListTitle = clickToFillListChooser:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
clickToFillListTitle:SetPoint("TOP", clickToFillListChooser, "TOP", 0, -8)
clickToFillListTitle:SetText("Choose preset")

local function HideClickToFillChooser()
    local i

    chooserTimeoutToken = chooserTimeoutToken + 1
    chooserTimeoutAt = nil
    chooserTimeoutFrame:SetScript("OnUpdate", nil)

    clickToFillChooser:Hide()
    clickToFillChooser.leftPreset = nil
    clickToFillChooser.rightPreset = nil
    clickToFillChooser.sourceText = nil

    clickToFillListChooser:Hide()
    clickToFillListChooser.sourceText = nil
    clickToFillListChooser.matches = nil

    for i = 1, table.getn(clickToFillListButtons) do
        clickToFillListButtons[i]:Hide()
        clickToFillListButtons[i].preset = nil
    end
end

local function StartClickToFillChooserTimeout()
    local token = chooserTimeoutToken + 1
    chooserTimeoutToken = token
    chooserTimeoutAt = GetTime() + 6

    chooserTimeoutFrame:SetScript("OnUpdate", function()
        if chooserTimeoutAt and GetTime() >= chooserTimeoutAt then
            chooserTimeoutFrame:SetScript("OnUpdate", nil)
            chooserTimeoutAt = nil
            if chooserTimeoutToken == token and (clickToFillChooser:IsShown() or clickToFillListChooser:IsShown()) then
                QueueDebugMessage("Error: Chooser: Preset chooser timed out.", "debugerror")
                HideClickToFillChooser()
            end
        end
    end)
end

local function GetClickToFillCursorPosition()
    local cursorX, cursorY = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()

    return cursorX / scale, cursorY / scale
end

local function PositionClickToFillChooser()
    local cursorX, cursorY = GetClickToFillCursorPosition()

    clickToFillChooser:ClearAllPoints()
    clickToFillChooser:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", cursorX - 105, cursorY)
end

local function PositionClickToFillListChooser()
    local cursorX, cursorY = GetClickToFillCursorPosition()

    clickToFillListChooser:ClearAllPoints()
    clickToFillListChooser:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", cursorX - 85, cursorY + 14)
end

local function ChooseClickToFillPreset(preset, sourceText)
    if not preset then
        HideClickToFillChooser()
        return
    end

    HideClickToFillChooser()
    keyPressCooldown = true
    lastDetectedBoss = sourceText or preset.label or preset.fullname
    QueueDebugMessage("Info: Chooser: Chosen zone preset -> " .. (preset.fullname or preset.label), "debuginfo")
    ApplyPresetAndFill(preset)
end

chooserLeftButton:SetScript("OnClick", function()
    ChooseClickToFillPreset(clickToFillChooser.leftPreset, clickToFillChooser.sourceText)
end)

chooserRightButton:SetScript("OnClick", function()
    ChooseClickToFillPreset(clickToFillChooser.rightPreset, clickToFillChooser.sourceText)
end)

local function GetOrCreateClickToFillListButton(index)
    local button = clickToFillListButtons[index]

    if button then
        return button
    end

    button = CreateFrame("Button", nil, clickToFillListChooser, "GameMenuButtonTemplate")
    button:SetWidth(140)
    button:SetHeight(20)
    button:SetPoint("TOP", clickToFillListChooser, "TOP", 0, -24 - ((index - 1) * 22))
    button:SetScript("OnClick", function()
        ChooseClickToFillPreset(button.preset, clickToFillListChooser.sourceText)
    end)

    clickToFillListButtons[index] = button
    return button
end

local function ShowClickToFillChooser(matches, sourceText)
    local count = table.getn(matches)
    local i
    local button

    if count < 2 then
        return false
    end

    HideClickToFillChooser()

    if count == 2 then
        clickToFillChooser.leftPreset = matches[1]
        clickToFillChooser.rightPreset = matches[2]
        clickToFillChooser.sourceText = sourceText

        chooserLeftButton:SetText(matches[1].label or matches[1].fullname or "Preset 1")
        chooserRightButton:SetText(matches[2].label or matches[2].fullname or "Preset 2")

        PositionClickToFillChooser()
        clickToFillChooser:Show()
        StartClickToFillChooserTimeout()
        QueueDebugMessage("Info: Chooser: Two zone presets found for " .. sourceText .. ". Waiting for left/right choice.", "debuginfo")
        return true
    end

    clickToFillListChooser.sourceText = sourceText
    clickToFillListChooser.matches = matches
    clickToFillListTitle:SetText("Choose preset (" .. count .. ")")
    clickToFillListChooser:SetHeight(34 + (count * 22))

    for i = 1, count do
        button = GetOrCreateClickToFillListButton(i)
        button.preset = matches[i]
        button:SetText(matches[i].label or matches[i].fullname or ("Preset " .. i))
        button:Show()
    end

    for i = count + 1, table.getn(clickToFillListButtons) do
        clickToFillListButtons[i]:Hide()
        clickToFillListButtons[i].preset = nil
    end

    PositionClickToFillListChooser()
    clickToFillListChooser:Show()
    StartClickToFillChooserTimeout()
    QueueDebugMessage("Info: FillRaid: " .. count .. " zone presets found for " .. sourceText .. ". Waiting for popup list choice.", "debuginfo")
    return true
end

local function DetectBossAndFillRaid()
    if keyPressCooldown then return end
    if not ClickToFillEnabled then return end
    if not (IsControlKeyDown() and IsAltKeyDown()) then return end

    local targetName = UnitName("target")
    local bossName = targetName or UnitName("mouseover")
    local zone = GetRealZoneText()
    local matches

    if targetName and UnitIsDead("target") then
        HideClickToFillChooser()
        keyPressCooldown = true
        QueueDebugMessage("FillRaid: Won't fill because target is dead -> " .. targetName .. " (probably already killed / misclick).", "debugfilling")
        return
    end

    if bossName then
        if bossName == "Ossirian the Unscarred" then
            bossName = "Ossirian"
        elseif bossName == "Lieutenant General Andorov" then
            bossName = "General Rajaxx"
        elseif bossName == "Vilebranch Speaker" then
            bossName = "Bloodlord Mandokir"
        elseif bossName == "Zealot Zath" then
            bossName = "High Priest Thekal"
        elseif bossName == "Zealot Lor'Khan" then
            bossName = "High Priest Thekal"
        end
    end

    if bossName then
        HideClickToFillChooser()
        if bossName ~= lastDetectedBoss then
            lastDetectedBoss = bossName
            keyPressCooldown = true
            QueueDebugMessage("FillRaid: Boss detected -> " .. bossName, "debuginfo")
            SlashCmdList["FILLRAID"](bossName)
        else
            QueueDebugMessage("FillRaid: Same boss, skipping -> " .. bossName, "debuginfo")
        end
        return
    elseif zone then
        if zone == "Onyxia's Lair" then
            zone = "Onyxia"
        end

        if CollectMatchingPresets then
            matches = CollectMatchingPresets(zone, true)
        elseif _G.CollectMatchingPresets then
            QueueDebugMessage("Info: Chooser: Using global CollectMatchingPresets fallback.", "debuginfo")
            matches = _G.CollectMatchingPresets(zone, true)
        else
            QueueDebugMessage("Error: Chooser: CollectMatchingPresets is missing.", "debugerror")
            matches = {}
        end

        QueueDebugMessage("Info: Chooser: Zone match count for " .. zone .. " -> " .. table.getn(matches), "debuginfo")

        if table.getn(matches) == 1 then
            HideClickToFillChooser()
            keyPressCooldown = true
            QueueDebugMessage("Info: Chooser: Single zone preset found -> " .. (matches[1].fullname or matches[1].label or zone), "debuginfo")
            ApplyPresetAndFill(matches[1])
            return
        elseif table.getn(matches) == 2 then
            QueueDebugMessage("Info: Chooser: Two zone presets found for " .. zone .. ". Showing left/right chooser.", "debuginfo")
            ShowClickToFillChooser(matches, zone)
            return
        elseif table.getn(matches) > 2 then
            QueueDebugMessage("Info: Chooser: " .. table.getn(matches) .. " zone presets found for " .. zone .. ". Showing popup list.", "debuginfo")
            ShowClickToFillChooser(matches, zone)
            return
        end

		HideClickToFillChooser()
		keyPressCooldown = true
		QueueDebugMessage("Info: Chooser: Zone fallback -> " .. zone .. " (no exact preset match)", "debuginfo")
		return
    end
end

detectBossFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
detectBossFrame:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
detectBossFrame:RegisterEvent("MODIFIER_STATE_CHANGED")

local ctrlAltWasDown = false
local ctrlAltPollElapsed = 0

detectBossFrame:SetScript("OnEvent", function()
    if event == "MODIFIER_STATE_CHANGED" then
        if not (IsControlKeyDown() and IsAltKeyDown()) then
            ctrlAltWasDown = false
            HideClickToFillChooser()
            ResetCooldown()
        elseif ClickToFillEnabled then
            DetectBossAndFillRaid()
        end
        return
    end

    if ClickToFillEnabled then
        DetectBossAndFillRaid()
    else
        HideClickToFillChooser()
    end
end)

detectBossFrame:SetScript("OnUpdate", function()
    ctrlAltPollElapsed = ctrlAltPollElapsed + (arg1 or 0)
    if ctrlAltPollElapsed < 0.1 then
        return
    end
    ctrlAltPollElapsed = 0

    local ctrlAltDown = IsControlKeyDown() and IsAltKeyDown()

    if ctrlAltDown then
        if not ctrlAltWasDown then
            ctrlAltWasDown = true
            if ClickToFillEnabled then
                DetectBossAndFillRaid()
            end
        end
    else
        if ctrlAltWasDown then
            ctrlAltWasDown = false
            HideClickToFillChooser()
            ResetCooldown()
        end
    end
end)

local oldMouseDown = WorldFrame:GetScript("OnMouseDown")
WorldFrame:SetScript("OnMouseDown", function()
    if oldMouseDown then
        oldMouseDown()
    end

    if not (IsControlKeyDown() and IsAltKeyDown()) then
        if clickToFillChooser:IsShown() or clickToFillListChooser:IsShown() then
            HideClickToFillChooser()
        end
    end
end)

function SavePresetValues()
    if not faction or not currentInstanceName or not currentPresetName then
        ShowStaticPopup("Error: Missing faction, instance, or preset name.", "Error")
        return
    end

   
    if not FillRaidPresets[faction] then
        FillRaidPresets[faction] = {}
    end

    if not FillRaidPresets[faction][currentInstanceName] then
        FillRaidPresets[faction][currentInstanceName] = {}
    end

    local presetList = FillRaidPresets[faction][currentInstanceName]

   
    local presetIndex = nil
    for index, p in ipairs(presetList) do
        if p.label == currentPresetName then
            presetIndex = index
            break
        end
    end

    if not presetIndex then
        presetIndex = table.getn(presetList) + 1
        presetList[presetIndex] = {
            label = currentPresetName,
            values = {},
            vipValues = {},
        }
    end

    if not presetList[presetIndex].values then
        presetList[presetIndex].values = {}
    end
    if not presetList[presetIndex].vipValues then
        presetList[presetIndex].vipValues = {}
    end

    local targetValues = presetList[presetIndex].values
    if FillRaidBotsSavedSettings and FillRaidBotsSavedSettings.useVipPresets then
        targetValues = presetList[presetIndex].vipValues
    end

    for classRole, inputBox in pairs(inputBoxes) do
        if inputBox then
            local value = inputBox:GetText()
            local numValue = tonumber(value)
            if numValue and numValue > 0 then
                targetValues[classRole] = numValue
            else
                targetValues[classRole] = nil
            end
        end
    end

    ShowStaticPopup("Preset \"" .. currentPresetName .. "\" saved for |cff00ccff" .. faction .. "|r - |cff88ff88" .. currentInstanceName .. "|r", "Preset Saved")
end





    instanceFrames = {}

	instanceFrames["PresetDungeounNaxxramas"] = CreateInstanceFrame("PresetDungeounNaxxramas", naxxramasPresets, "Naxxramas")
	instanceFrames["PresetDungeounBWL"] = CreateInstanceFrame("PresetDungeounBWL", bwlPresets, "Blackwing Lair")
	instanceFrames["PresetDungeounMC"] = CreateInstanceFrame("PresetDungeounMC", mcPresets, "Molten Core")
	instanceFrames["PresetDungeounOnyxia"] = CreateInstanceFrame("PresetDungeounOnyxia", onyxiaPresets, "Onyxia's Lair")
	instanceFrames["PresetDungeounAQ40"] = CreateInstanceFrame("PresetDungeounAQ40", aq40Presets, "AQ40")
	instanceFrames["PresetDungeounAQ20"] = CreateInstanceFrame("PresetDungeounAQ20", aq20Presets, "AQ20")
	instanceFrames["PresetDungeounZG"] = CreateInstanceFrame("PresetDungeounZG", ZGPresets, "Zul'Gurub")
	instanceFrames["PresetDungeounOther"] = CreateInstanceFrame("PresetDungeounOther", otherPresets, "Other")

    
    local openPresetButton = CreateFrame("Button", "OpenPresetButton", FillRaidFrame, "GameMenuButtonTemplate")
    openPresetButton:SetWidth(80)
    openPresetButton:SetHeight(20)
    openPresetButton:SetText("Presets")
    openPresetButton:SetPoint("TOPRIGHT", FillRaidFrame, "TOPRIGHT", -10, -10)
    openPresetButton:SetScript("OnClick", function()
        if InstanceButtonsFrame:IsShown() then
            InstanceButtonsFrame:Hide()
            ClickBlockerFrame:Hide()
        else
            InstanceButtonsFrame:Show()
            ClickBlockerFrame:Show() 
        end
    end)
	

		


local resetButton = CreateFrame("Button", nil, FillRaidFrame, "GameMenuButtonTemplate")
resetButton:SetPoint("TOPRIGHT", FillRaidFrame, "TOPRIGHT", -10, -30)
resetButton:SetWidth(80)
resetButton:SetHeight(20)
resetButton:SetText("Reset")
resetButton:SetScript("OnClick", function()
    for _, inputBox in pairs(inputBoxes) do
        inputBox:SetNumber(0) 
        local onTextChanged = inputBox:GetScript("OnTextChanged")
        if onTextChanged then
            onTextChanged(inputBox) 
        end
    end

    
    totalBotLabel:SetText("Total Bots: 0")
    roleCountsLabel:SetText("Tanks: 0 Healers: 0 Melee DPS: 0 Ranged DPS: 0")
    UpdateSpotsLeft()
end)



  
local ClickBlockerFrame = CreateFrame("Frame", "ClickBlockerFrame", UIParent)
ClickBlockerFrame:SetAllPoints(UIParent) 
ClickBlockerFrame:EnableMouse(true) 
ClickBlockerFrame:SetFrameStrata("DIALOG") 
ClickBlockerFrame:SetFrameLevel(1)
ClickBlockerFrame:SetScript("OnMouseDown", function()
    ClickBlockerFrame:Hide() 
    InstanceButtonsFrame:Hide() 
	CreditsFrame:Hide()
	UISettingsFrame:Hide()
    for frameName, frame in pairs(instanceFrames) do
        if frame:IsShown() then
            frame:Hide()
        end
    end
end)
ClickBlockerFrame:Hide() 



local defaultPosition = {x = -20, y = 250}
local openFillRaidButton = CreateFrame("Button", "OpenFillRaidButton", UIParent)
openFillRaidButton:SetMovable(true)
openFillRaidButton:EnableMouse(true)
openFillRaidButton:RegisterForDrag("LeftButton")

function GetPCPFrame()
    return PCPFrame or PCPFrameRemake
end

local savedPositions = {}

function GetSelectedButtonTheme()
    if FillRaidBotsSavedSettings then
        return FillRaidBotsSavedSettings.selectedButtonTheme or FillRaidBotsSavedSettings.buttonStyle or "Mini"
    end
    return "Mini"
end

function GetThemeDefaultSize()
    local themeKey = GetSelectedButtonTheme()

    for _, section in ipairs(SettingsConfig.sections) do
        for _, item in ipairs(section.items) do
            if item.type == "radio" and item.group == "buttonTheme" then
                for _, option in ipairs(item.options) do
                    if option.key == themeKey and option.buttons then
                        local btn = option.buttons.openFillRaidButton
                        if btn then
                            local w = btn.width or 32
                            local h = btn.height or 32
                            if w > h then
                                return w
                            end
                            return h
                        end
                    end
                end
            end
        end
    end

    return 40
end

function GetButtonLayout()
    if FillRaidBotsSavedSettings and FillRaidBotsSavedSettings.ButtonLayout ~= nil then
        if FillRaidBotsSavedSettings.ButtonLayout == true then
            return "horizontal"
        end
        return FillRaidBotsSavedSettings.ButtonLayout
    end
    return "vertical"
end

function GetButtonSpacing()
    if FillRaidBotsSavedSettings and FillRaidBotsSavedSettings.ButtonSpacing ~= nil then
        return FillRaidBotsSavedSettings.ButtonSpacing
    end

    local spacing = 10
    local styleKey = GetSelectedButtonTheme()

    for _, section in ipairs(SettingsConfig.sections) do
        for _, item in ipairs(section.items) do
            if item.type == "radio" and item.group == "buttonTheme" then
                for _, option in ipairs(item.options) do
                    if option.key == styleKey then
                        spacing = option.spacing or spacing
                        return spacing
                    end
                end
            end
        end
    end

    return spacing
end

function InitializeButtonPosition()
    local pcp = GetPCPFrame()
    if not pcp then
        return
    end

    if not savedPositions["OpenFillRaidButton"] and FillRaidBotsSavedSettings then
        if FillRaidBotsSavedSettings.buttonPositionRelative then
            savedPositions["OpenFillRaidButton"] = FillRaidBotsSavedSettings.buttonPositionRelative
        elseif FillRaidBotsSavedSettings.buttonPosition then
            savedPositions["OpenFillRaidButton"] = FillRaidBotsSavedSettings.buttonPosition
        end
    end

    local savedPosition = savedPositions["OpenFillRaidButton"]
    local offsetX = 0
    local offsetY = 0
    local styleKey = GetSelectedButtonTheme()

    for _, section in ipairs(SettingsConfig.sections) do
        for _, item in ipairs(section.items) do
            if item.type == "radio" and item.group == "buttonTheme" then
                for _, option in ipairs(item.options) do
                    if option.key == styleKey then
                        offsetX = option.offsetX or 0
                        offsetY = option.offsetY or 0
                        break
                    end
                end
            end
        end
    end

    openFillRaidButton:ClearAllPoints()

    if FillRaidBotsSavedSettings and FillRaidBotsSavedSettings.moveButtonsRelative and savedPosition and savedPosition.offsetX then
        local uiScale = UIParent:GetEffectiveScale()
        local pcpPhysX = pcp:GetLeft() * pcp:GetEffectiveScale()
        local pcpPhysY = pcp:GetTop() * pcp:GetEffectiveScale()
        openFillRaidButton:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT",
            (pcpPhysX + savedPosition.offsetX) / uiScale,
            (pcpPhysY + savedPosition.offsetY) / uiScale)
    elseif FillRaidBotsSavedSettings and FillRaidBotsSavedSettings.moveButtonsEnabled and savedPosition and savedPosition.absX then
        local uiScale = UIParent:GetEffectiveScale()
        openFillRaidButton:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT",
            savedPosition.absX / uiScale,
            savedPosition.absY / uiScale)
    elseif pcp == PCPFrameRemake then
        openFillRaidButton:SetPoint("RIGHT", pcp, "LEFT", defaultPosition.x + 10 + offsetX, 100 + offsetY)
    else
        openFillRaidButton:SetPoint("CENTER", pcp, "LEFT", defaultPosition.x + offsetX, defaultPosition.y + offsetY)
    end
end

local kickAllButton = CreateFrame("Button", "KickAllButton", UIParent)
kickAllButton:SetScript("OnClick", function()

	if not CanManageRaidBots() then
		DEFAULT_CHAT_FRAME:AddMessage("|cffff0000FillRaidBots: You need leader or assistant to kick")
		return
	end
    UninviteAllRaidMembers()
    ReplaceDeadBot = {}
    resetData()
    UpdateReFillButtonVisibility()
end)
kickAllButton:Hide()

local reFillButton = CreateFrame("Button", "reFillButton", UIParent)
function ToggleSmallbuttonCheck(isChecked)
    SmallbuttonEnabled = isChecked
end

function ApplyButtonStyle(styleKey)
    if not styleKey or styleKey == "" then
        styleKey = GetSelectedButtonTheme()
    end

    if FillRaidBotsSavedSettings then
        FillRaidBotsSavedSettings.selectedButtonTheme = styleKey
    end

    local selectedStyle = nil
    local buttonThemeSection = nil

    for _, section in ipairs(SettingsConfig.sections) do
        for _, item in ipairs(section.items) do
            if item.type == "radio" and item.group == "buttonTheme" then
                buttonThemeSection = item
                break
            end
        end
        if buttonThemeSection then
            break
        end
    end

    if not buttonThemeSection then
        return
    end

    for _, style in ipairs(buttonThemeSection.options or {}) do
        if style.key == styleKey then
            selectedStyle = style
            break
        end
    end

    if not selectedStyle then
        return
    end

    local buttons = selectedStyle.buttons or {}

    if buttons.openFillRaidButton then
        openFillRaidButton:SetWidth(buttons.openFillRaidButton.width)
        openFillRaidButton:SetHeight(buttons.openFillRaidButton.height)
        openFillRaidButton:SetNormalTexture(buttons.openFillRaidButton.normal)
        openFillRaidButton:SetHighlightTexture(buttons.openFillRaidButton.highlight)
        openFillRaidButton:SetPushedTexture(buttons.openFillRaidButton.pushed)
    end

    if buttons.kickAllButton then
        kickAllButton:SetWidth(buttons.kickAllButton.width)
        kickAllButton:SetHeight(buttons.kickAllButton.height)
        kickAllButton:SetNormalTexture(buttons.kickAllButton.normal)
        kickAllButton:SetHighlightTexture(buttons.kickAllButton.highlight)
        kickAllButton:SetPushedTexture(buttons.kickAllButton.pushed)
    end

    if buttons.reFillButton then
        reFillButton:SetWidth(buttons.reFillButton.width)
        reFillButton:SetHeight(buttons.reFillButton.height)
        reFillButton:SetNormalTexture(buttons.reFillButton.normal)
        reFillButton:SetHighlightTexture(buttons.reFillButton.highlight)
        reFillButton:SetPushedTexture(buttons.reFillButton.pushed)
    end
end

function UpdateButtonSizes()
    if not FillRaidBotsSavedSettings then
        return
    end

    local pct = FillRaidBotsSavedSettings.ButtonSize or 100
    local themeKey = GetSelectedButtonTheme()
    local defaultSize = GetThemeDefaultSize()
    local size = math.floor(defaultSize * (pct / 100) + 0.5)

    local w = size
    local h = size

    for _, section in ipairs(SettingsConfig.sections) do
        for _, item in ipairs(section.items) do
            if item.type == "radio" and item.group == "buttonTheme" then
                for _, option in ipairs(item.options) do
                    if option.key == themeKey and option.buttons then
                        local btn = option.buttons.openFillRaidButton
                        if btn then
                            local origW = btn.width or 32
                            local origH = btn.height or 32

                            if origW >= origH then
                                w = size
                                h = math.floor(size * (origH / origW) + 0.5)
                            else
                                h = size
                                w = math.floor(size * (origW / origH) + 0.5)
                            end
                        end
                        break
                    end
                end
            end
        end
    end

    local allButtons = {openFillRaidButton, kickAllButton, reFillButton}
    local i
    for i = 1, table.getn(allButtons) do
        allButtons[i]:SetWidth(w)
        allButtons[i]:SetHeight(h)
    end

    RepositionButtonsFromOffset()
end

function ToggleButtonMovement()
    if not FillRaidBotsSavedSettings then
        return
    end

    local isFree = FillRaidBotsSavedSettings.moveButtonsEnabled
    local isRelative = FillRaidBotsSavedSettings.moveButtonsRelative
    local layout = GetButtonLayout()
    local pcp = GetPCPFrame()

    if isFree or isRelative then
        openFillRaidButton:SetParent(UIParent)
        kickAllButton:SetParent(UIParent)
        reFillButton:SetParent(UIParent)
        openFillRaidButton:SetMovable(true)

        if openFillRaidButton:GetLeft() then
            local physX = openFillRaidButton:GetLeft() * openFillRaidButton:GetEffectiveScale()
            local physY = openFillRaidButton:GetTop() * openFillRaidButton:GetEffectiveScale()
            local uiScale = UIParent:GetEffectiveScale()
            openFillRaidButton:ClearAllPoints()
            openFillRaidButton:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", physX / uiScale, physY / uiScale)
        end

        if isFree and openFillRaidButton:GetLeft() then
            local btnPhysX = openFillRaidButton:GetLeft() * openFillRaidButton:GetEffectiveScale()
            local btnPhysY = openFillRaidButton:GetTop() * openFillRaidButton:GetEffectiveScale()
            if pcp then
                local pcpPhysX = pcp:GetLeft() * pcp:GetEffectiveScale()
                local pcpPhysY = pcp:GetTop() * pcp:GetEffectiveScale()
                savedPositions["OpenFillRaidButton"] = {
                    offsetX = btnPhysX - pcpPhysX,
                    offsetY = btnPhysY - pcpPhysY,
                    absX = btnPhysX,
                    absY = btnPhysY
                }
                FillRaidBotsSavedSettings.buttonPositionRelative = savedPositions["OpenFillRaidButton"]
            end
        elseif isRelative and openFillRaidButton:GetLeft() and pcp then
            local btnPhysX = openFillRaidButton:GetLeft() * openFillRaidButton:GetEffectiveScale()
            local btnPhysY = openFillRaidButton:GetTop() * openFillRaidButton:GetEffectiveScale()
            local pcpPhysX = pcp:GetLeft() * pcp:GetEffectiveScale()
            local pcpPhysY = pcp:GetTop() * pcp:GetEffectiveScale()
            savedPositions["OpenFillRaidButton"] = {
                offsetX = btnPhysX - pcpPhysX,
                offsetY = btnPhysY - pcpPhysY,
                absX = btnPhysX,
                absY = btnPhysY
            }
            FillRaidBotsSavedSettings.buttonPositionRelative = savedPositions["OpenFillRaidButton"]
        end

        openFillRaidButton:SetScript("OnDragStart", function()
            this:StartMoving()
            this.isMoving = true
        end)

        openFillRaidButton:SetScript("OnDragStop", function()
            local btnPhysX = this:GetLeft() * this:GetEffectiveScale()
            local btnPhysY = this:GetTop() * this:GetEffectiveScale()
            this:StopMovingOrSizing()
            this:SetParent(UIParent)

            local uiScale = UIParent:GetEffectiveScale()
            this:ClearAllPoints()
            this:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", btnPhysX / uiScale, btnPhysY / uiScale)

            if pcp then
                local pcpPhysX = pcp:GetLeft() * pcp:GetEffectiveScale()
                local pcpPhysY = pcp:GetTop() * pcp:GetEffectiveScale()
                savedPositions["OpenFillRaidButton"] = {
                    offsetX = btnPhysX - pcpPhysX,
                    offsetY = btnPhysY - pcpPhysY,
                    absX = btnPhysX,
                    absY = btnPhysY
                }
                FillRaidBotsSavedSettings.buttonPositionRelative = savedPositions["OpenFillRaidButton"]
            end

            this.isMoving = false
            RepositionButtonsFromOffset()
        end)
    else
        openFillRaidButton:SetScript("OnDragStart", nil)
        openFillRaidButton:SetScript("OnDragStop", nil)
        openFillRaidButton:SetMovable(false)

        if layout == "horizontal" then
            openFillRaidButton:SetParent(UIParent)
            kickAllButton:SetParent(UIParent)
            reFillButton:SetParent(UIParent)
        else
            if pcp then
                openFillRaidButton:SetParent(pcp)
                kickAllButton:SetParent(pcp)
                reFillButton:SetParent(pcp)
            end
        end

        savedPositions["OpenFillRaidButton"] = nil
        FillRaidBotsSavedSettings.buttonPosition = nil
        FillRaidBotsSavedSettings.buttonPositionRelative = nil

        InitializeButtonPosition()
    end

    RepositionButtonsFromOffset()
end

function ApplyButtonLayout(layout)
    if not FillRaidBotsSavedSettings then
        return
    end

    FillRaidBotsSavedSettings.ButtonLayout = layout
    ToggleButtonMovement()
    RepositionButtonsFromOffset()
end

ToggleSmallbuttonCheck(SmallbuttonEnabled or false)

function openFillRaid()
    if FillRaidFrame:IsShown() then
        FillRaidFrame:Hide()
        ClickBlockerFrame:Hide()
        InstanceButtonsFrame:Hide()
        CreditsFrame:Hide()
        UISettingsFrame:Hide()
        for frameName, frame in pairs(instanceFrames) do
            if frame:IsShown() then
                frame:Hide()
            end
        end
        fillRaidFrameManualClose = true
    else
        FillRaidFrame:Show()
        fillRaidFrameManualClose = false
        if FillRaidFrame.UpdateSpotsLeft then
            FillRaidFrame.UpdateSpotsLeft()
        end
        if FillRaidBotsSavedSettings.isZonePresetsEnabled then
            OpenPresetForCurrentZone()
        end
    end
end

openFillRaidButton:SetScript("OnClick", function()
    if IsShiftKeyDown() then
        if debuggerFrame then
            if debuggerFrame:IsShown() then
                if SetDebuggerVisibility then
                    SetDebuggerVisibility(false)
                end
                debuggerFrame:Hide()
            else
                if SetDebuggerVisibility then
                    SetDebuggerVisibility(true)
                end
                debuggerFrame:Show()
            end
        end
        return
    end

    openFillRaid()
end)
openFillRaidButton:Hide()

function UpdateReFillButtonVisibility()
    if next(ReplaceDeadBot) == nil then
        reFillButton:Hide()
    else
        if FillRaidBotsSavedSettings.isRefillEnabled then
            reFillButton:Show()
        end
    end
end

local restoreSoundDelay = 0
local restoreSoundElapsed = 0
local restoreSoundPending = false

local restoreFrame = CreateFrame("Frame")
restoreFrame:Hide()

restoreFrame:SetScript("OnUpdate", function()
    local newTime = GetTime()
    if restoreSoundPending and newTime - restoreSoundElapsed >= restoreSoundDelay then
        ToggleSoundEffectsVolume("restore")
        restoreSoundPending = false
        restoreFrame:Hide()
    end
end)

function RefillBots()
    hasWarnedNoPermission = false

    if next(ReplaceDeadBot) == nil then
        QueueDebugMessage("Replaced Bot List is empty.", "debugfilling")
    else
        ToggleSoundEffectsVolume("lower")
        QueueDebugMessage("Replaced Bot List:", "debugfilling")

        local count = 0
        for playerName, data in pairs(ReplaceDeadBot) do
            count = count + 1
            QueueDebugMessage(playerName .. " - Class: " .. data.classColored .. ", Role: " .. data.role, "debugfilling")
            QueueMessage(".partybot add " .. data.ClassNoColor .. " " .. data.role, "SAY", true)
        end

        ReplaceDeadBot = {}
        QueueDebugMessage("Replaced Bot List has been cleared.", "debugfilling")

        restoreSoundDelay = 2 + math.max(0, (count - 1) * 0.5)
        restoreSoundElapsed = GetTime()
        restoreSoundPending = true
        restoreFrame:Show()

        UpdateReFillButtonVisibility()
    end
end

reFillButton:SetScript("OnClick", RefillBots)
UpdateReFillButtonVisibility()

function RepositionButtonsFromOffset()
    if openFillRaidButton.isMoving then
        return
    end

    local savedPosition = savedPositions["OpenFillRaidButton"]
    local layout = GetButtonLayout()
    local spacing = GetButtonSpacing()
    local pcp = GetPCPFrame()

    if not pcp then
        return
    end

    local uiScale = UIParent:GetEffectiveScale()
    local pcpPhysX = pcp:GetLeft() * pcp:GetEffectiveScale()
    local pcpPhysY = pcp:GetTop() * pcp:GetEffectiveScale()
    local handled = false

    if FillRaidBotsSavedSettings and FillRaidBotsSavedSettings.moveButtonsRelative then
        if not savedPosition or not savedPosition.offsetX then
            return
        end

        openFillRaidButton:ClearAllPoints()
        openFillRaidButton:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT",
            (pcpPhysX + savedPosition.offsetX) / uiScale,
            (pcpPhysY + savedPosition.offsetY) / uiScale)
    elseif FillRaidBotsSavedSettings and FillRaidBotsSavedSettings.moveButtonsEnabled then
        if not savedPosition or not savedPosition.absX then
            return
        end

        openFillRaidButton:ClearAllPoints()
        openFillRaidButton:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT",
            savedPosition.absX / uiScale,
            savedPosition.absY / uiScale)
    else
        if layout == "horizontal" then
            reFillButton:ClearAllPoints()
            reFillButton:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", pcpPhysX / uiScale, pcpPhysY / uiScale)

            kickAllButton:ClearAllPoints()
            kickAllButton:SetPoint("RIGHT", reFillButton, "LEFT", -spacing, 0)

            openFillRaidButton:ClearAllPoints()
            openFillRaidButton:SetPoint("RIGHT", kickAllButton, "LEFT", -spacing, 0)

            handled = true
        end
    end

    if not handled then
        kickAllButton:ClearAllPoints()
        reFillButton:ClearAllPoints()

        if layout == "horizontal" then
            kickAllButton:SetPoint("LEFT", openFillRaidButton, "RIGHT", spacing, 0)
            reFillButton:SetPoint("LEFT", kickAllButton, "RIGHT", spacing, 0)
        else
            InitializeButtonPosition()
            kickAllButton:SetPoint("TOP", openFillRaidButton, "BOTTOM", 0, -spacing)
            reFillButton:SetPoint("TOP", kickAllButton, "BOTTOM", 0, -spacing)
        end
    end
end

local lastPcpPhysX = nil
local lastPcpPhysY = nil
local visibilityFrame = CreateFrame("Frame")
visibilityFrame:SetScript("OnUpdate", function()
    local pcp = GetPCPFrame()

    if pcp and pcp:IsVisible() then
        if not fillRaidFrameManualClose and not openFillRaidButton:IsShown() then
            openFillRaidButton:Show()
        end

        if not kickAllButton:IsShown() then
            kickAllButton:Show()
        end

        if not reFillButton:IsShown() then
            UpdateReFillButtonVisibility()
        end

        RepositionButtonsFromOffset()

        if not openFillRaidButton.isMoving then
            local pcpPhysX = pcp:GetLeft() * pcp:GetEffectiveScale()
            local pcpPhysY = pcp:GetTop() * pcp:GetEffectiveScale()
            if pcpPhysX ~= lastPcpPhysX or pcpPhysY ~= lastPcpPhysY then
                lastPcpPhysX = pcpPhysX
                lastPcpPhysY = pcpPhysY
                RepositionButtonsFromOffset()
            end
        end
    else
        openFillRaidButton:Hide()
        kickAllButton:Hide()
        reFillButton:Hide()
        FillRaidFrame:Hide()
        fillRaidFrameManualClose = false
    end
end)
visibilityFrame:Show()

function FillRaidBots_ResetButtonPositions()
    if not FillRaidBotsSavedSettings then
        return
    end

    FillRaidBotsSavedSettings.buttonMoveModeFixed = true
    FillRaidBotsSavedSettings.buttonModeMoveFree = false
    FillRaidBotsSavedSettings.buttonMoveModeRelative = false
    FillRaidBotsSavedSettings.moveButtonsEnabled = false
    FillRaidBotsSavedSettings.moveButtonsRelative = false

    FillRaidBotsSavedSettings.ButtonSize = 100
    FillRaidBotsSavedSettings.ButtonSpacing = 4
    FillRaidBotsSavedSettings.ButtonLayout = "vertical"
    FillRaidBotsSavedSettings.buttonMoveLocked = false

    savedPositions["OpenFillRaidButton"] = nil
    FillRaidBotsSavedSettings.buttonPosition = nil
    FillRaidBotsSavedSettings.buttonPositionRelative = nil

    openFillRaidButton:SetParent(UIParent)
    kickAllButton:SetParent(UIParent)
    reFillButton:SetParent(UIParent)

    if ApplySavedSettings then
        ApplySavedSettings()
    end

    local layoutCb = nil
    if GetSettingsCheckbox then
        layoutCb = GetSettingsCheckbox("ButtonLayout")
    end
    if layoutCb then
        layoutCb:SetChecked(false)
    end

    InitializeButtonPosition()
    ApplyButtonStyle(GetSelectedButtonTheme())
    UpdateButtonSizes()
    ToggleButtonMovement()
    RepositionButtonsFromOffset()

    DEFAULT_CHAT_FRAME:AddMessage("FillRaidBots: Buttons reset to theme default.")
end

end

CreateFillRaidUI()

local fillRaidInitFrame = CreateFrame("Frame")
fillRaidInitFrame.done = false
fillRaidInitFrame.elapsed = 0
fillRaidInitFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
fillRaidInitFrame:SetScript("OnEvent", function()
    this:UnregisterEvent("PLAYER_ENTERING_WORLD")

    this:SetScript("OnUpdate", function()
        if this.done then
            this:SetScript("OnUpdate", nil)
            return
        end

        this.elapsed = this.elapsed + arg1
        if this.elapsed < 0.2 then
            return
        end
        this.elapsed = 0

        local pcp = GetPCPFrame()
        if not pcp or not pcp:IsVisible() then
            return
        end

        this.done = true
        this:SetScript("OnUpdate", nil)

        OpenFillRaidButton:SetParent(UIParent)
        KickAllButton:SetParent(UIParent)
        reFillButton:SetParent(UIParent)

        ApplyButtonStyle(GetSelectedButtonTheme())
        InitializeButtonPosition()
        UpdateButtonSizes()
        ToggleButtonMovement()
        RepositionButtonsFromOffset()

        OpenFillRaidButton:Show()
        KickAllButton:Show()
        UpdateReFillButtonVisibility()
        RepositionButtonsFromOffset()
    end)
end)

local messageCooldowns = {}
local messagesToHide = {}

local function InitializeSuppressBotMsg()
    FillRaidSuppressBotMsg = FillRaidSuppressBotMsg or {}
    FillRaidSuppressBotMsg.messagesToHide = FillRaidSuppressBotMsg.messagesToHide or {}
    messagesToHide = FillRaidSuppressBotMsg.messagesToHide
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
    InitializeSuppressBotMsg()
end)

local function shouldShowMessage(message)
    local currentTime = GetTime() 
    for pattern, cooldown in pairs(messagesToHide) do
        if string.find(message, pattern) then
            if cooldown == 0 then
                return false 
            end

            local lastShown = messageCooldowns[pattern] or 0
            if currentTime - lastShown >= cooldown then
                messageCooldowns[pattern] = currentTime 
                return true
            else
                return false 
            end
        end
    end
    return true
end


local function HideBotMessages(this, message, r, g, b, id)
    if not FillRaidBotsSavedSettings.isBotMessagesEnabled then
        this:OriginalAddMessage(message, r, g, b, id)
        return
    end

    if not shouldShowMessage(message) then
        return 
    end

    this:OriginalAddMessage(message, r, g, b, id)
end


for i = 1, 7 do
    local chatFrame = getglobal("ChatFrame" .. i)
    if chatFrame and not chatFrame.OriginalAddMessage then
        chatFrame.OriginalAddMessage = chatFrame.AddMessage
        chatFrame.AddMessage = HideBotMessages
    end
end


function UninviteAllRaidMembers()
    if not CanManageRaidBots() then
        WarnNoBotManagementPermission("manage bots")
        return
    end
    hasWarnedNoPermission = false

    local myName = UnitName("player")
    initialBotRemoved = false
    firstBotName = nil
    botCount = 0    

    local isRaid = GetNumRaidMembers() > 0
    local totalMembers = 0
    local realPlayers = 0
    local totalBots = 0

    if isRaid then
        totalMembers = GetNumRaidMembers()
    else
        totalMembers = GetNumPartyMembers()
    end

    if totalMembers == 0 then return end

    -- ===== RÄKNA =====
    for i = 1, totalMembers do
        local unit = isRaid and ("raid"..i) or ("party"..i)
        local name = UnitName(unit)

        if name and name ~= myName then
            if isBotName(name) then
                totalBots = totalBots + 1
            else
                realPlayers = realPlayers + 1
            end
        end
    end

    local botsToRemove = totalBots

    -- Om inga riktiga spelare finns → lämna 1 bot
    if realPlayers == 0 and totalBots > 0 then
        botsToRemove = totalBots - 1
    end

    local removed = 0

    -- ===== TA BORT =====
    for i = totalMembers, 1, -1 do
        local unit = isRaid and ("raid"..i) or ("party"..i)
        local name = UnitName(unit)

        if name and name ~= myName and isBotName(name) then
            if removed < botsToRemove then
                UninviteByName(name)
                removed = removed + 1
                botCount = botCount + 1

                if not firstBotName then
                    firstBotName = name
                    initialBotRemoved = true
                end
            end
        end
    end
end



local c = "0"

SLASH_FRB1 = "/frb"
SlashCmdList["FRB"] = function(cmd)
    cmd = cmd and string.lower(strtrim(cmd)) or ""

    if cmd == "ua" or cmd == "uninvite all" then
        UninviteAllRaidMembers()
	elseif cmd == "kd" or cmd =="kick dead" then
		CheckAndRemoveDeadBots(true)
    elseif cmd == "open" then
        openFillRaid()
    elseif cmd == "refill" then
        RefillBots()
    elseif cmd == "fixgroups" then
        isFixingGroups = true
        currentPhase = 1
        lastMoveTime = 0
        moveQueue = {}
        FixGroups()
	elseif cmd == "list" then
        SlashCmdList["FILLRAID"]("")
    elseif cmd == "resetbuttons" then
        FillRaidBots_ResetButtonPositions()
    else
       
        if cmd == "" or cmd == "help" then
            DEFAULT_CHAT_FRAME:AddMessage("FillRaidBots Commands:", 1.0, 1.0, 0.0)
            DEFAULT_CHAT_FRAME:AddMessage("/frb ua - Uninvite all non-guild/friend raid members", 1.0, 1.0, 0.0)
			DEFAULT_CHAT_FRAME:AddMessage("/frb kd - Uninvite all dead bots", 1.0, 1.0, 0.0)			
            DEFAULT_CHAT_FRAME:AddMessage("/frb (preset name) - Fill raid with optimal composition", 1.0, 1.0, 0.0)
            DEFAULT_CHAT_FRAME:AddMessage("/frb list - lists all presets", 1.0, 1.0, 0.0)			
            DEFAULT_CHAT_FRAME:AddMessage("/frb open - Toggle FillRaid window", 1.0, 1.0, 0.0)
            DEFAULT_CHAT_FRAME:AddMessage("/frb refill - Replace recently removed bots", 1.0, 1.0, 0.0)
            DEFAULT_CHAT_FRAME:AddMessage("/frb fixgroups - Reorganize raid groups", 1.0, 1.0, 0.0)
            DEFAULT_CHAT_FRAME:AddMessage("/frb resetbuttons - Reset button position to default", 1.0, 1.0, 0.0)

        else
           
			ReplaceDeadBot = {}
			resetData()
			UpdateReFillButtonVisibility()
            SlashCmdList["FILLRAID"](cmd)
        end
    end
end

-------------------------------------------------------------------------------------------------------------------
local isNewerVersion
local GITHUB_URL = "https://github.com/pumpan/FillRaidBots"
local updateVersionPopup
local updateVersionPopupLinkBox
local updateVersionPopupCurrentText
local updateVersionPopupLatestText

local function HasTrackedUpdateVersion()
    local latestVersion

    if not FillRaidBotsSavedSettings then
        return false
    end

    latestVersion = FillRaidBotsSavedSettings.lastNotifiedVersion
    if not latestVersion or latestVersion == "" then
        return false
    end

    return isNewerVersion(versionNumber, latestVersion)
end

local function EnsureUpdateVersionPopup()
    if updateVersionPopup then
        return updateVersionPopup
    end

    updateVersionPopup = CreateFrame("Frame", "FillRaidBotsUpdateVersionPopup", UIParent)
    updateVersionPopup:SetWidth(460)
    updateVersionPopup:SetHeight(180)
    updateVersionPopup:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    updateVersionPopup:SetFrameStrata("DIALOG")
    updateVersionPopup:SetMovable(true)
    updateVersionPopup:EnableMouse(true)
    updateVersionPopup:RegisterForDrag("LeftButton")
    updateVersionPopup:SetScript("OnDragStart", function()
        this:StartMoving()
    end)
    updateVersionPopup:SetScript("OnDragStop", function()
        this:StopMovingOrSizing()
    end)
    updateVersionPopup:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    updateVersionPopup:SetBackdropColor(0, 0, 0, 1)
    updateVersionPopup:Hide()
    table.insert(UISpecialFrames, "FillRaidBotsUpdateVersionPopup")

    updateVersionPopup.header = updateVersionPopup:CreateTexture(nil, "ARTWORK")
    updateVersionPopup.header:SetWidth(220)
    updateVersionPopup.header:SetHeight(64)
    updateVersionPopup.header:SetPoint("TOP", updateVersionPopup, 0, 18)
    updateVersionPopup.header:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
    updateVersionPopup.header:SetVertexColor(.2, .2, .2)

    updateVersionPopup.headerText = updateVersionPopup:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    updateVersionPopup.headerText:SetPoint("TOP", updateVersionPopup.header, 0, -14)
    updateVersionPopup.headerText:SetText("Update Available")

    updateVersionPopupCurrentText = updateVersionPopup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    updateVersionPopupCurrentText:SetPoint("TOPLEFT", updateVersionPopup, "TOPLEFT", 20, -42)
    updateVersionPopupCurrentText:SetJustifyH("LEFT")
    updateVersionPopupCurrentText:SetText("You are using: " .. versionNumber)

    updateVersionPopupLatestText = updateVersionPopup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    updateVersionPopupLatestText:SetPoint("TOPLEFT", updateVersionPopupCurrentText, "BOTTOMLEFT", 0, -12)
    updateVersionPopupLatestText:SetJustifyH("LEFT")
    updateVersionPopupLatestText:SetText("Latest version: " .. versionNumber)

    local linkLabel = updateVersionPopup:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    linkLabel:SetPoint("TOPLEFT", updateVersionPopupLatestText, "BOTTOMLEFT", 0, -18)
    linkLabel:SetJustifyH("LEFT")
    linkLabel:SetText("GitHub:")

    updateVersionPopupLinkBox = CreateFrame("EditBox", "FillRaidBotsUpdateVersionPopupLinkBox", updateVersionPopup, "InputBoxTemplate")
    updateVersionPopupLinkBox:SetPoint("TOPLEFT", linkLabel, "BOTTOMLEFT", 0, -6)
    updateVersionPopupLinkBox:SetWidth(410)
    updateVersionPopupLinkBox:SetHeight(20)
    updateVersionPopupLinkBox:SetAutoFocus(false)
    updateVersionPopupLinkBox:SetText(GITHUB_URL)
    updateVersionPopupLinkBox:SetScript("OnEscapePressed", function()
        this:ClearFocus()
        this:HighlightText(0, 0)
    end)
    updateVersionPopupLinkBox:SetScript("OnEditFocusGained", function()
        this:HighlightText()
    end)
    updateVersionPopupLinkBox:SetScript("OnMouseUp", function()
        this:SetFocus()
        this:HighlightText()
    end)

    local okButton = CreateFrame("Button", nil, updateVersionPopup, "UIPanelButtonTemplate")
    okButton:SetWidth(100)
    okButton:SetHeight(22)
    okButton:SetPoint("BOTTOMRIGHT", updateVersionPopup, "BOTTOMRIGHT", -20, 16)
    okButton:SetText("OK")
    okButton:SetScript("OnClick", function()
        updateVersionPopup:Hide()
    end)

    local ignoreButton = CreateFrame("Button", nil, updateVersionPopup, "UIPanelButtonTemplate")
    ignoreButton:SetWidth(140)
    ignoreButton:SetHeight(22)
    ignoreButton:SetPoint("RIGHT", okButton, "LEFT", -10, 0)
    ignoreButton:SetText("Ignore this version")
    ignoreButton:SetScript("OnClick", function()
        if not FillRaidBotsSavedSettings then
            FillRaidBotsSavedSettings = {}
        end

        if HasTrackedUpdateVersion() then
            FillRaidBotsSavedSettings.ignoredUpdateVersion = FillRaidBotsSavedSettings.lastNotifiedVersion
        end

        updateVersionPopup:Hide()
    end)

    return updateVersionPopup
end

function ShowUpdateVersionPopup()
    local latestVersion
    local popup
    local hasUpdate = HasTrackedUpdateVersion()

    latestVersion = FillRaidBotsSavedSettings.lastNotifiedVersion
    popup = EnsureUpdateVersionPopup()

    updateVersionPopupCurrentText:SetText("You are using: " .. versionNumber)
    updateVersionPopupLatestText:SetText("Latest version: " .. latestVersion)
    updateVersionPopupLinkBox:SetText(GITHUB_URL)
    updateVersionPopupLinkBox:ClearFocus()
    updateVersionPopupLinkBox:HighlightText(0, 0)
    popup:Show()
end

local function MaybeShowUpdateVersionPopup()
    if not HasTrackedUpdateVersion() then
        return
    end

    if FillRaidBotsSavedSettings.ignoredUpdateVersion == FillRaidBotsSavedSettings.lastNotifiedVersion then
        return
    end

    ShowUpdateVersionPopup()
end

---------------------------------------- Daily tips in chat------------------------------------------------------------------------------

local function ShowDailyTipInChat()
	if not DailyTipEnabled then return end
    if not FillRaidBotsSavedSettings then
        FillRaidBotsSavedSettings = {}
    end

    local today = date("%Y-%m-%d")
    if FillRaidBotsSavedSettings.lastDailyTipDate == today then
        return
    end

    
    local delay = 15
    local startTime = GetTime()

    
    local timerFrame = CreateFrame("Frame")
    timerFrame:Show()

    timerFrame:SetScript("OnUpdate", function()
        if GetTime() - startTime >= delay then
            
            this:SetScript("OnUpdate", nil)
            this:Hide()

            
            local CMD  = "|cff00ccff"
            local FEAT = "|cff00ff00"
            local END  = "|r"

            local tips = {
                "Adding fewer than 5 bots keeps you in party mode.",
                "Large fills (5+ bots) automatically convert your group to a raid.",
                "Auto Repair works automatically if you're VIP.",
                "You can edit presets directly in-game.",
                "Use SuppressEditor to silence bot spam.",
                "Dead bots are automatically replaced when using Refill.",
                "Refill continues until all dead bots are replaced.",

                "Use " .. CMD .. "/frb help" .. END .. " to see available commands.",
                "Use " .. FEAT .. "Fast Fill" .. END .. " (Ctrl + Alt + click a boss) to automatically fill the raid.",
                "Fast Fill will not trigger if the target is already dead.",
                "You can use boss, mob, or instance names in presets for Fast Fill.",
                "You can use instance names to create default presets.",

                "Kick All will not remove real players.",
                "Use " .. CMD .. "/frb fixgroups" .. END .. " to rebalance raid groups.",
                "Use " .. CMD .. "/frb refill" .. END .. " to instantly replace dead bots.",

                "You can export and import presets between accounts.",
                "VIP presets can override normal presets if enabled.",
                "You must be leader or assistant for some features to work.",
                "Zone-based presets automatically adjust raid size limits.",

                "You can move and resize buttons in the settings.",
                "You can enable tutorial links in settings to see boss guides.",
                "Negative button spacing allows compact layouts.",
                "Enable the debugger in settings for advanced troubleshooting.",

                "Support the addon to get your name in the credits."
            }

            if not FillRaidBotsSavedSettings.usedDailyTips then
                FillRaidBotsSavedSettings.usedDailyTips = {}
            end

            local used = FillRaidBotsSavedSettings.usedDailyTips
            local availableIndexes = {}

            for i = 1, table.getn(tips) do
                if not used[i] then
                    table.insert(availableIndexes, i)
                end
            end

            if table.getn(availableIndexes) == 0 then
                FillRaidBotsSavedSettings.usedDailyTips = {}
                used = FillRaidBotsSavedSettings.usedDailyTips
                for i = 1, table.getn(tips) do
                    table.insert(availableIndexes, i)
                end
            end

            local randomPoolIndex = math.random(1, table.getn(availableIndexes))
            local selectedTipIndex = availableIndexes[randomPoolIndex]
            local selectedTip = tips[selectedTipIndex]

            used[selectedTipIndex] = true
            FillRaidBotsSavedSettings.lastDailyTipDate = today

            DEFAULT_CHAT_FRAME:AddMessage("|cffffff00[FillRaidBots Tip]|r " .. selectedTip)
        end
    end)
end
---------------------------------------------------------------------------------------------

local Guard = string.format("%d.%d.%d", a, b, c)



local frame = CreateFrame("Frame")
frame:RegisterEvent("CHAT_MSG_ADDON")
frame:RegisterEvent("PLAYER_LOGIN")


FillRaidBotsSavedSettings = FillRaidBotsSavedSettings or {}
FillRaidBotsSavedSettings.userCount = FillRaidBotsSavedSettings.userCount or 0
FillRaidBotsSavedSettings.uniqueUsers = FillRaidBotsSavedSettings.uniqueUsers or {}


local SessionUniqueUsers = {}


local function generateUserID()
    return math.random(1000000, 9999999)  
end


local function sendVersionMessage(version, userID)
    local message = version .. ";" .. userID  
    SendAddonMessage(addonPrefix, message, "GUILD")
	
end
function strsplit(delimiter, input)
    local result = {}
    local start_pos = 1
    local delim_pos = strfind(input, delimiter, start_pos)
    
    while delim_pos do
        
        local part = strsub(input, start_pos, delim_pos - 1)  
        table.insert(result, part)  
        
        
        start_pos = delim_pos + 1  
        
        
        delim_pos = strfind(input, delimiter, start_pos)  
    end

    
    local last_part = strsub(input, start_pos)
    table.insert(result, last_part)

    return unpack(result)  
end





function splitVersion(version)
    local major, minor, patch = 0, 0, 0
    local dot1 = strfind(version, "%.")
    local dot2 = dot1 and strfind(version, "%.", dot1 + 1)

    if dot1 then
        major = tonumber(strsub(version, 1, dot1 - 1)) or 0
        if dot2 then
            minor = tonumber(strsub(version, dot1 + 1, dot2 - 1)) or 0
            patch = tonumber(strsub(version, dot2 + 1)) or 0
        else
            minor = tonumber(strsub(version, dot1 + 1)) or 0
        end
    else
        major = tonumber(version) or 0
    end

    return major, minor, patch
end


function isNewerVersion(current, received)
    local cMajor, cMinor, cPatch = splitVersion(current)
    local rMajor, rMinor, rPatch = splitVersion(received)

    if rMajor > cMajor then
        return true
    elseif rMajor == cMajor and rMinor > cMinor then
        return true
    elseif rMajor == cMajor and rMinor == cMinor and rPatch > cPatch then
        return true
    end

    return false
end

local SessionUserID


local function ShowVersionPopupOnce()
    if not FillRaidBotsSavedSettings then
        FillRaidBotsSavedSettings = {}
    end

   
    if FillRaidBotsSavedSettings.lastPopupVersionSeen ~= versionNumber then
        local versionDetails = {
            {"Fast Fill", "Hold Ctrl + Alt and click a boss to automatically fill using presets."},
            {"Refill System", "Automatically replaces dead bots until your group is full again."},
            {"Auto Remove", "Automatically removes the starter bot and dead bots."},
            {"Auto Repair", "Automatically repairs after resurrection (VIP only)."},
            {"Auto Join Guild", "Joins SoloCraft automatically if you are not in a guild."},
            {"VIP Presets", "Lets you switch between normal and VIP preset values."},
            {"Tutorial Links", "Optional in-game boss guides with multiple sources and fallback support."},
            {"Export / Import", "Share presets between accounts using export/import."},
            {"Customizable Buttons", "Move, resize, and change button layouts in settings."},
            {"Reload UI", "Reload UI using /rl or /reload without /console."},
            {"Release Notes", "Shown once after updating to a new version."},
            {"Other Fixes", "Improved \"raid filling complete\" accuracy."}
        }

       
        local message = "|cffffff00FillRaidBots v" .. versionNumber .. "|r\n\n"

       
        for _, details in ipairs(versionDetails) do
            local headline = details[1]
            local content = details[2]
            message = message .. "|cffffff00" .. headline .. "|r:\n" .. content .. "\n\n"
        end

       
        ShowStaticPopup(message, nil, false)
        
       
        FillRaidBotsSavedSettings.lastPopupVersionSeen = versionNumber
    end
end


local popupFrame = CreateFrame("Frame")
popupFrame:RegisterEvent("PLAYER_LOGIN")
popupFrame:SetScript("OnEvent", function()
    ShowVersionPopupOnce()
end)

frame:SetScript("OnEvent", function()
    if event == "PLAYER_LOGIN" then
		ShowDailyTipInChat()
        if not FillRaidBotsSavedSettings.userID then
            FillRaidBotsSavedSettings.userID = generateUserID()
        end
        SessionUserID = FillRaidBotsSavedSettings.userID  

		if not FillRaidBotsSavedSettings.lastNotifiedVersion then
			FillRaidBotsSavedSettings.lastNotifiedVersion = versionNumber  
		end
		if not FillRaidBotsSavedSettings.userCount or FillRaidBotsSavedSettings.userCount == "" then
			FillRaidBotsSavedSettings.userCount = 0
		end
		if not FillRaidBotsSavedSettings.uniqueUsers then
			FillRaidBotsSavedSettings.uniqueUsers = {}
		end

        
        QueueDebugMessage(addonName .. " loaded. Current version: " .. versionNumber, "debuginfo")
        QueueDebugMessage("INFO: Total unique users detected: " .. FillRaidBotsSavedSettings.userCount, "debuginfo")
        QueueDebugMessage("Userid:" .. SessionUserID, "debuginfo")
        
        if isNewerVersion(versionNumber, FillRaidBotsSavedSettings.lastNotifiedVersion) then
            QueueDebugMessage("INFO: New update available: " .. FillRaidBotsSavedSettings.lastNotifiedVersion, "debuginfo")
            sendVersionMessage(FillRaidBotsSavedSettings.lastNotifiedVersion, SessionUserID)
            newversion(FillRaidBotsSavedSettings.lastNotifiedVersion)
            MaybeShowUpdateVersionPopup()
        else
			if versionNumber == Guard then
				newversion()
				sendVersionMessage(versionNumber, SessionUserID) 
				QueueDebugMessage("INFO: Sent version number:" .. versionNumber, "debugversion")
			else
				QueueDebugMessage("ERROR: A, a, a, you didnt say the magic word.", "debugversion")
			end		
        end
	elseif event == "CHAT_MSG_ADDON" then
		local prefix = arg1
		local message = arg2
		local sender = arg4

		if prefix == addonPrefix then
			if sender ~= UnitName("player") then
				
				if not message or message == "" then
					QueueDebugMessage("ERROR: Received an empty or nil message", "debugversion")
					return
				end
				local version, userID = strsplit(";", "1.13.8;7780693")

				
				local receivedVersion, userID = strsplit(";", message)

				
				QueueDebugMessage("ReceivedVersion: [" .. receivedVersion .. "], from userID: [" .. tostring(userID) .. "]", "debugversion")


				
				if not tonumber(userID) then
					QueueDebugMessage("ERROR: UserID is not a valid number: " .. tostring(userID), "debugversion")
					return
				end

				
				local versionPattern = "^%d+%.%d+%.%d+$"
				if not strfind(receivedVersion, versionPattern) then
					QueueDebugMessage("ERROR: Version format is invalid: " .. tostring(receivedVersion), "debugversion")
					return
				end

				
				if not SessionUniqueUsers[userID] and not FillRaidBotsSavedSettings.uniqueUsers[userID] then
					SessionUniqueUsers[userID] = true
					FillRaidBotsSavedSettings.uniqueUsers[userID] = true
					FillRaidBotsSavedSettings.userCount = FillRaidBotsSavedSettings.userCount + 1
					QueueDebugMessage("INFO: New user detected. Total unique users: " .. FillRaidBotsSavedSettings.userCount, "debugversion")
				end

				
				if isNewerVersion(versionNumber, receivedVersion) then
					local lastNotifiedVersion = FillRaidBotsSavedSettings.lastNotifiedVersion or ""
					if isNewerVersion(lastNotifiedVersion, receivedVersion) then
						QueueDebugMessage("INFO: New version detected: " .. receivedVersion, "debuginfo")
						FillRaidBotsSavedSettings.lastNotifiedVersion = receivedVersion
						sendVersionMessage(receivedVersion, SessionUserID)
						newversion(receivedVersion)
						MaybeShowUpdateVersionPopup()
					else
						QueueDebugMessage("INFO: Version " .. receivedVersion .. " already notified.", "debugversion")
					end
				else
					QueueDebugMessage("INFO: Your version is up to date.", "debugversion")
				end
			end
    end
end



end)


SLASH_RL1 = "/rl"
SLASH_RL2 = "/reload"
SLASH_RL3 = "/reloadui"
SlashCmdList["RL"] = function()
    ReloadUI()
end



----------------------------------------------------------------------------------------------------------------------

