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
local versionNumber = "3.0.0"
local a = "3"
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




local combatCheckFrame = CreateFrame("Frame")
combatCheckFrame:SetScript("OnUpdate", nil) 

local messageQueue = {} 
local botCount = 0
local initialBotRemoved = false
local firstBotName = nil 
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
local firstBotRemovalFrame = CreateFrame("Frame")
firstBotRemovalFrame:RegisterEvent("RAID_ROSTER_UPDATE")

firstBotRemovalFrame:SetScript("OnEvent", function()
    
    if not initialBotRemoved and GetNumRaidMembers() >= 3 then
		
        if firstBotName then
            QueueDebugMessage("Removed first bot: " .. firstBotName, "debugremove")
            UninviteMember(firstBotName, "firstBotRemoved")
        end

    end
end)


function ProcessMessageQueue()
	
	if next(messageQueue) ~= nil then 
		local messageInfo = table.remove(messageQueue, 1)
		local message = messageInfo.message
		local recipient = messageInfo.recipient

        
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
        if recipient == "none" then
            
            DEFAULT_CHAT_FRAME:AddMessage(message)
        else
            
            SendChatMessage(message, recipient)
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
        if (char >= "a" and char <= "z") or (char >= "A" and char <= "Z") or (char >= "0" and char <= "9") then
            cleanName = cleanName .. string.lower(char) 
        end
    end
    return cleanName
end



local function updateRoleConfidence(playerName, class, role, confidenceIncrease, spell)
    
    local normalizedPlayerName = normalizePlayerName(playerName)
    if not normalizedPlayerName then return end  

    
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


    local coloredClass = classColors[string.lower(class)] and (classColors[string.lower(class)] .. class .. resetColor) or class
	local plainClass = string.lower(class)
    local data = playerData[normalizedPlayerName] or { classColored = coloredClass, ClassNoColor = plainClass, role = role, roleConfidence = 0 }


    data.roleConfidence = data.roleConfidence + confidenceIncrease

    
    if data.roleConfidence >= 3 then
        if not detectedPlayers[normalizedPlayerName] then
            detectedPlayers[normalizedPlayerName] = true
            detectedPlayerCount = detectedPlayerCount + 1
            QueueDebugMessage("Detected:" .. detectedPlayerCount .. " - " .. playerName .. " is a " .. coloredClass .. " (" .. role .. ") using: " .. spell, "debugdetection")
        end
    else
        QueueDebugMessage("INFO: Updated confidence for " .. playerName .. ": " .. data.roleConfidence, "debugdetection")
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



function UninviteMember(name, reason)
    
    local normalizedName = normalizePlayerName(name)
    if not normalizedName then
        QueueDebugMessage("ERROR: Could not normalize name for UninviteMember", "debugerror")
        return
    end

    
    

    
    if playerData[normalizedName] then
        
        ReplaceDeadBot[normalizedName] = playerData[normalizedName]
        playerData[normalizedName] = nil  
    else
        QueueDebugMessage("WARNING: Player not found in playerData:" .. normalizedName, "debugremove")
    end

    
    UninviteByName(normalizedName)

    
    if reason == "dead" then
        
    elseif reason == "firstBotRemoved" then
        QueueDebugMessage("Removing party bot: " .. normalizedName, "debugremove")
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


local function CheckAndRemoveDeadBots()
    if not FillRaidBotsSavedSettings or not FillRaidBotsSavedSettings.isCheckAndRemoveEnabled then
        return
    end

    local playerName = UnitName("player")

    if not (IsRaidLeader() or IsRaidOfficer()) and GetNumRaidMembers() > 0 then
        if not hasWarnedNoPermission then
            QueueDebugMessage("WARNING: You must be a raid leader or officer to remove bots.", "debuginfo")
            hasWarnedNoPermission = true
        end
        return
    end
    hasWarnedNoPermission = false

    local function buildGuildRoster()
        local guildMembers = {}
        for j = 1, GetNumGuildMembers() do
            local guildName = GetGuildRosterInfo(j)
            if guildName then
                guildMembers[guildName] = true
            end
        end
        return guildMembers
    end

    local function buildFriendList()
        local friends = {}
        for i = 1, GetNumFriends() do
            local name, _, _, _, online = GetFriendInfo(i)
            if name and online then
                friends[name] = true  
            end
        end
        return friends
    end

    if GetNumRaidMembers() > 0 then
        if GetNumRaidMembers() > 2 then
            for i = 1, GetNumRaidMembers() do
                local name, _, _, _, _, _, _, _, isDead = GetRaidRosterInfo(i)
                local unit = "raid" .. i

                if UnitExists(unit) then
                    name = name or UnitName(unit)  
                    if name then
                        local guildMembers = buildGuildRoster()
                        local friends = buildFriendList()

                        if isDead and not UnitIsGhost(unit) then
                            if guildMembers[name] then
                                if not guildDeadStatus[name] then
                                    QueueDebugMessage("INFO: STOPPED FROM KICKING GUILD MEMBER.", "debuginfo")
                                    guildDeadStatus[name] = true
                                end
                            elseif friends[name] then
                                if not guildDeadStatus[name] then
                                    QueueDebugMessage("INFO: STOPPED FROM KICKING FRIEND: " .. name, "debuginfo")
                                    guildDeadStatus[name] = true
                                end
                            else
                                UninviteMember(name, "dead")
                            end
                        else
                            guildDeadStatus[name] = nil
                        end
                    else
                        QueueDebugMessage("DEBUG: Name is nil for raid unit: " .. unit, "error")
                    end
                end
            end
            messagecantremove = false
        elseif not messagecantremove then
            QueueDebugMessage("INFO: Saving the last bot so the raid does not disband.", "debuginfo")
            messagecantremove = true
        end
    elseif GetNumPartyMembers() > 0 then
        for i = 1, GetNumPartyMembers() do
            local unit = "party" .. i
            local name = UnitName(unit)

            if UnitExists(unit) then
                name = name or UnitName(unit)  
                if name then
                    local guildMembers = buildGuildRoster()
                    local friends = buildFriendList()

                    if UnitIsDead(unit) and not UnitIsGhost(unit) then
                        if guildMembers[name] then
                            if not guildDeadStatus[name] then
                                QueueDebugMessage("INFO: STOPPED FROM KICKING GUILD MEMBER.", "debuginfo")
                                guildDeadStatus[name] = true
                            end
                        elseif friends[name] then
                            if not guildDeadStatus[name] then
                                QueueDebugMessage("INFO: STOPPED FROM KICKING FRIEND: " .. name, "debuginfo")
                                guildDeadStatus[name] = true
                            end
                        else
                            UninviteMember(name, "dead")
                        end
                    else
                        guildDeadStatus[name] = nil
                    end
                else
                    QueueDebugMessage("DEBUG: Name is nil for party unit: " .. unit, "error")
                end
            end
        end
    end
end







local function SaveRaidMembersAndSetFirstBot()
    local raidMembers = {}
    local playerName = UnitName("player")
    firstBotName = nil

    
    local guildMembers = {}
    for i = 1, GetNumGuildMembers() do
        local name = GetGuildRosterInfo(i)
        if name then
            guildMembers[name] = true
        end
    end

    
    local friends = {}
    for i = 1, GetNumFriends() do
        local name, _, _, _, online = GetFriendInfo(i)
        if name and online then
            friends[name] = true  
        end
    end

    
    for i = 1, GetNumRaidMembers() do
        local unit = "raid" .. i
        local name = UnitName(unit)

        if name and name ~= playerName then
            
            if guildMembers[name] then
                QueueDebugMessage("INFO: " .. name .. " is a member of a guild, skipping!", "debuginfo")
            elseif friends[name] then
                QueueDebugMessage("INFO: " .. name .. " is a friend, skipping!", "debuginfo")
            else
                
                if not firstBotName then
                    firstBotName = name
                    QueueDebugMessage("INFO: First raid bot set to: " .. firstBotName, "debuginfo")
                end
                table.insert(raidMembers, name)
            end
        end
    end

    
    if not firstBotName then
        QueueDebugMessage("ERROR: No first Bot found", "debugerror")
    end
end



local function SavePartyMembersAndSetFirstBot()
    local partyMembers = {}
    local raidMembers = {}
    local guildMembers = {}
    local friends = {}

    
    for i = 1, GetNumGuildMembers() do
        local name = GetGuildRosterInfo(i)
        if name then
            guildMembers[name] = true
        end
    end

    
    for i = 1, GetNumFriends() do
        local name, _, _, _, online = GetFriendInfo(i)
        if name and online then
            friends[name] = true  
        end
    end

    
    for i = 1, GetNumPartyMembers() do
        local unit = "party" .. i
        local name = UnitName(unit)
        if name then
            table.insert(partyMembers, name)
        end
    end

    local playerName = UnitName("player")

    
    for _, member in ipairs(partyMembers) do
        local guildName = nil
        local isFriend = friends[member]  

        
        if guildMembers[member] then
            guildName = "Member of guild"
        end

        if member ~= playerName then
            if guildName then
                QueueDebugMessage("INFO: " .. member .. " is a member of a guild, skipping!", "debuginfo")
            elseif isFriend then
                QueueDebugMessage("INFO: " .. member .. " is a friend, skipping!", "debuginfo")
            else
                
                if not firstBotName then
                    firstBotName = member
                    QueueDebugMessage("INFO: First bot set to: " .. firstBotName, "debuginfo")
                    return
                end
            end

            
            table.insert(raidMembers, member)
        end
    end
end





function resetfirstbot_OnEvent()
    if event == "RAID_ROSTER_UPDATE" or event == "PARTY_MEMBERS_CHANGED" then

        if GetNumPartyMembers() == 0 and GetNumRaidMembers() == 0 then
            initialBotRemoved = false
            firstBotName = nil
			botCount = 0
            QueueDebugMessage("INFO: Bot state reset: No members in party or raid.", "debuginfo")
        end
    end
end


local resetBotFrame = CreateFrame("Frame")
resetBotFrame:RegisterEvent("RAID_ROSTER_UPDATE")
resetBotFrame:RegisterEvent("PARTY_MEMBERS_CHANGED")
resetBotFrame:SetScript("OnEvent", resetfirstbot_OnEvent)



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

local function GetSelectedLootMethod()
    if AutoFFACheckButton:GetChecked() then
        return "freeforall"
    elseif AutoGroupLootCheckButton:GetChecked() then
        return "group"
    elseif AutoMasterLootCheckButton:GetChecked() then
        return "master"
    end
    return "freeforall"  
end



local MAX_PLAYERS_PER_GROUP = 5
local MAX_GROUPS = 8
local isFixingGroups = false
local moveDelay = 0.1 
local lastMoveTime = 0
local moveQueue = {} 
local healerClasses = {"PALADIN", "PRIEST", "DRUID", "SHAMAN"} 
local currentPhase = 1
local FixGroups

local function FillRaid()
    if GetNumRaidMembers() > 0 then
        if GetNumRaidMembers() == 2 then
            SaveRaidMembersAndSetFirstBot() 
            QueueDebugMessage("SaveRaidMembersAndSetFirstBot called", "debugfilling")
        end
    else
        
        if GetNumPartyMembers() == 0 then
            QueueMessage(".partybot add warrior tank", "SAY", true)
            QueueDebugMessage("Inviting the first bot to start the party.", "none")

            
            local waitForPartyFrame = CreateFrame("Frame")
            waitForPartyFrame:SetScript("OnUpdate", function()
                if GetNumPartyMembers() > 0 then
                    this:SetScript("OnUpdate", nil)
                    this:Hide()
                    SavePartyMembersAndSetFirstBot()
                    local selectedLoot = GetSelectedLootMethod()
                    if selectedLoot == "master" then
                        
                        local playerName = UnitName("player")
                        SetLootMethod("master", playerName)
                        QueueDebugMessage("Loot method set to Master Looter. Assigned to: " .. playerName, "debuginfo")
                    else
                        SetLootMethod(selectedLoot)
                        QueueDebugMessage("Loot method set to: " .. selectedLoot, "debuginfo")
                    end
                    FillRaid() 
                end
            end)
            waitForPartyFrame:Show()
            return
        end

        
        if GetNumPartyMembers() >= 1 then
            
            ConvertToRaid()
            QueueDebugMessage("Converted to raid.", "debugfilling")
        elseif GetNumPartyMembers() < 2 then
            QueueDebugMessage("You need at least 2 players in the group to convert to a raid.", "debugfilling")
            return
        end
    end

    local healers = {}
    local others = {}
    totalHealers = 0
    local totalOthers = 0

    
    for class, count in pairs(classCounts) do
        if string.find(class, "healer") then
            for i = 1, count do
                table.insert(healers, class)
            end
            totalHealers = totalHealers + count
        else
            for i = 1, count do
                table.insert(others, class)
            end
            totalOthers = totalOthers + count
        end
    end

    
    totalHealers = totalHealers or 0
    totalOthers = totalOthers or 0

    
    totaly = totalHealers + totalOthers

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

        
        for _, otherClass in ipairs(others) do
            addBot(otherClass)
        end
        QueueDebugMessage("Raid filling complete.", "none")
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
							FixGroups()

							
							local delayTimer = CreateFrame("Frame")
							local delayStartTime = GetTime()
							delayTimer:SetScript("OnUpdate", function()
								if GetTime() - delayStartTime >= 5 then
									delayTimer:SetScript("OnUpdate", nil)
									delayTimer:Hide()
									
									QueueDebugMessage("Added: Adding other classes after healers.", "debugfilling")
									addothers()
								end
							end)
							delayTimer:Show()
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
        end
    end
end


function FixGroups()
    local groupSizes = {}
    local groupClasses = {} 
    local healers = {}

    
    for i = 1, MAX_GROUPS do
        groupSizes[i] = 0
        groupClasses[i] = {}
    end

    
    local playerName = UnitName("player") 
    local healerCounts = {} 
    for _, healerClass in ipairs(healerClasses) do
        healerCounts[healerClass] = 0
    end

    for i = 1, GetNumRaidMembers() do
        local name, _, subgroup, _, _, class, _, online = GetRaidRosterInfo(i)
        
        
        if name ~= playerName and class and TableContains(healerClasses, class) then
            local player = {name = name, index = i, group = subgroup, class = class, online = online, moved = false}
            table.insert(healers, player)

            
            healerCounts[class] = (healerCounts[class] or 0) + 1
        end
    end

    
    local maxGroups = (totaly <= 20) and 4 or MAX_GROUPS 

    
    local runPhase2 = false
    for class, count in pairs(healerCounts) do
        if count >= 8 then
            runPhase2 = true
            break
        end
    end

    
    if currentPhase == 1 then
        
        local healersByClass = {}
        for _, healer in ipairs(healers) do
            if not healersByClass[healer.class] then
                healersByClass[healer.class] = {}
            end
            table.insert(healersByClass[healer.class], healer)
        end

        
        local groupIndex = 1
        for class, classHealers in pairs(healersByClass) do
            
            if table.getn(classHealers) > maxGroups then
                
                QueueDebugMessage("Warning: Too many healers of class " .. class .. ", assigning remaining healers randomly.", "debugfilling")
            end

            for _, healer in ipairs(classHealers) do
                
                local attempts = 0
                while TableContains(groupClasses[groupIndex], healer.class) and groupIndex <= maxGroups do
                    groupIndex = groupIndex + 1
                    if groupIndex > maxGroups then
                        groupIndex = 1 
                    end

                    attempts = attempts + 1
                    if attempts > 20 then
                        
                        QueueDebugMessage("Error: Too many of " .. class .. " in raid. Assigning to available group.", "debugerror")
                        break
                    end
                end

                
                QueueMove(healer, groupIndex)
                groupSizes[groupIndex] = groupSizes[groupIndex] + 1
                table.insert(groupClasses[groupIndex], healer.class) 

                
                groupIndex = groupIndex + 1
                if groupIndex > maxGroups then
                    groupIndex = 1
                end
            end
        end
    elseif currentPhase == 2 and runPhase2 then
        
        local healersByClass = {}
        for _, healer in ipairs(healers) do
            if not healersByClass[healer.class] then
                healersByClass[healer.class] = {}
            end
            table.insert(healersByClass[healer.class], healer)
        end

        
        local groupIndex = 1
        local allHealersAssigned = false
        while not allHealersAssigned do
            allHealersAssigned = true  

            
            for _, classHealers in pairs(healersByClass) do
                if table.getn(classHealers) > 0 then
                    
                    local healer = table.remove(classHealers, 1)

                    
                    local attempts = 0
                    while TableContains(groupClasses[groupIndex], healer.class) and groupIndex <= maxGroups do
                        groupIndex = groupIndex + 1
                        if groupIndex > maxGroups then
                            groupIndex = 1
                        end

                        attempts = attempts + 1
                        if attempts > 20 then
                            
                            QueueDebugMessage("Error: Too many of " .. healer.class .. " in raid. Assigning to available group.", "debugerror")
                            break
                        end
                    end

                    
                    QueueMove(healer, groupIndex)
                    groupSizes[groupIndex] = groupSizes[groupIndex] + 1
                    table.insert(groupClasses[groupIndex], healer.class) 
                    allHealersAssigned = false  
                end
            end
        end
    end

    
    for group, size in pairs(groupSizes) do
        local classesInGroup = {}
        for _, class in ipairs(groupClasses[group]) do
            classesInGroup[class] = (classesInGroup[class] or 0) + 1
        end
        local classStrs = {}
        for class, count in pairs(classesInGroup) do
            table.insert(classStrs, count .. " x " .. class)
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

    FillRaidFrame:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    FillRaidFrame:SetBackdropColor(0, 0, 0, 1) 

    local versionText = FillRaidFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    versionText:SetPoint("BOTTOMRIGHT", FillRaidFrame, "BOTTOMRIGHT", -10, 8)  
	function newversion(newVersionDetected)
		if newVersionDetected then
			versionText:SetText("You are running:" .. versionNumber .. " - Update available: " .. newVersionDetected)
		else
			versionText:SetText("Version: " .. versionNumber)
		end
	end

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
    local xOffset = 20
    local totalBots = 0 

    
    local totalBotLabel = FillRaidFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    totalBotLabel:SetPoint("TOP", FillRaidFrame, "TOP", 0, yOffset)
    totalBotLabel:SetText("Total Bots: 0")
    yOffset = yOffset - 25

    
    local spotsLeftLabel = FillRaidFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    spotsLeftLabel:SetPoint("TOP", FillRaidFrame, "TOP", 0, yOffset)
    spotsLeftLabel:SetText("Spots Left: 39") 
    yOffset = yOffset - 25

    
    local roleCountsLabel = FillRaidFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    roleCountsLabel:SetPoint("TOP", FillRaidFrame, "TOP", 0, yOffset)
    roleCountsLabel:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    roleCountsLabel:SetText("Tanks: 0 Healers: 0 Melee DPS: 0 Ranged DPS: 0")
    yOffset = yOffset - 30

    local columns = 2
    local rowsPerColumn = 9
    local columnWidth = 150
    local rowHeight = 30

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

    
    local function SplitClassRole(classRole)
        local spaceIndex = string.find(classRole, " ")
        if spaceIndex then
            local class = string.sub(classRole, 1, spaceIndex - 1)
            local role = string.sub(classRole, spaceIndex + 1)
            return class, role
        end
        return classRole, nil
    end

    
    for i, classRole in ipairs(classes) do
        local class, role = SplitClassRole(classRole)

        local index = i - 1
        local column = math.floor(index / rowsPerColumn)
        local row = index - column * rowsPerColumn

        local classXOffset = xOffset + (column * columnWidth)
        local classYOffset = yOffset - (row * rowHeight)

        local roleIcon = FillRaidFrame:CreateTexture(nil, "OVERLAY")
        roleIcon:SetPoint("TOPLEFT", FillRaidFrame, "TOPLEFT", classXOffset - 10, classYOffset)
        roleIcon:SetWidth(15)
        roleIcon:SetHeight(15)
        roleIcon:SetTexture(roleIcons[role] or "Interface\\Icons\\INV_Misc_QuestionMark")

        local classLabel = FillRaidFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        classLabel:SetPoint("TOPLEFT", FillRaidFrame, "TOPLEFT", classXOffset + 10, classYOffset)
        classLabel:SetText(class .. " " .. (role or ""))

        local classInput = CreateFrame("EditBox", classRole .. "Input", FillRaidFrame, "InputBoxTemplate")
        classInput:SetWidth(20)
        classInput:SetHeight(15)
        classInput:SetPoint("TOPLEFT", FillRaidFrame, "TOPLEFT", classXOffset + 100, classYOffset)
        classInput:SetNumeric(true)
        classInput:SetNumber(0)

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

            if totalBots < 40 then
                totalBotLabel:SetText("Total Bots: " .. totalBots)
                spotsLeftLabel:SetText("Spots Left: " .. (39 - totalBots))
            else
                totalBotLabel:SetText("Too many added: " .. totalBots)
                spotsLeftLabel:SetText("Spots Left: 0")
            end
            roleCountsLabel:SetText(string.format("Tanks: %d Healers: %d Melee DPS: %d Ranged DPS: %d",
                roleCounts["tank"], roleCounts["healer"], roleCounts["meleedps"], roleCounts["rangedps"]))
        end)
    end


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
	  
	local UISettingsFrame = CreateFrame("Frame", "UISettingsFrame", UIParent)
	UISettingsFrame:SetWidth(200)
	UISettingsFrame:SetHeight(350)
	UISettingsFrame:SetPoint("LEFT", FillRaidFrame, "RIGHT", 10, 0)
	UISettingsFrame:SetBackdrop({
		bgFile = "Interface/Tooltips/UI-Tooltip-Background",
		edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
		tile = true, tileSize = 16, edgeSize = 16,
		insets = { left = 4, right = 4, top = 4, bottom = 4 }
	})
	UISettingsFrame:SetBackdropColor(0, 0, 0, 1) 
	UISettingsFrame:SetFrameStrata("DIALOG")
	UISettingsFrame:SetFrameLevel(10)
	UISettingsFrame:Hide() 

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


local CreditsFrame = CreateFrame("Frame", "CreditsFrame", UIParent)
CreditsFrame:SetWidth(300)
CreditsFrame:SetHeight(200)
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
    {name = "|cffffd700Dedirtyone|r", contribution = "Special thanks to Dedirtyone for his incredible generosity\nin donating €50 to help me get VIP status.\nYour support means so much and has truly motivated me \nto keep contributing to the community. \nThis addon wouldn’t be the same without people like you!"},
	{name = "|cffffd700TheSamurai206|r", contribution = "A huge thank you to TheSamurai206 (Zugginator) for his generous donation of €20.\nYour support means a lot and helps me continue improving this addon.\nIt's supporters like you that keep this project going!"},
    {name = "|cffffffffGemma|r", contribution = "Thanks for Beta testing, and bug reports!"},
    {name = "|cffffffffTO EVERYONE ELSE!|r", contribution = "To everyone who has been supporting! \nIf you are interested in contributing in any way, \nbug reporting, beta testing, or whatever, \nplease contact me on the forum, Discord, or in-game."},
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

    local instanceButtons = {}
    local function CreateInstanceButton(label, yOffset, frameName)
        local button = CreateFrame("Button", nil, InstanceButtonsFrame, "GameMenuButtonTemplate")
        button:SetPoint("TOP", InstanceButtonsFrame, "TOP", 0, yOffset)
        button:SetWidth(180)
        button:SetHeight(30)
        button:SetText(label)
        button:SetScript("OnEnter", function()
            GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
            GameTooltip:SetText(label)
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        button:SetScript("OnClick", function()
            InstanceButtonsFrame:Hide()
            ClickBlockerFrame:Show()
            local frame = instanceFrames[frameName]
            if frame then
                frame:Show()
            else
                QueueDebugMessage("Error: Frame '" .. frameName .. "' not found.", "debugerror")
            end
        end)
        return button
    end

    
    CreateInstanceButton("Naxxramas", -10, "PresetDungeounNaxxramas")
    CreateInstanceButton("BWL", -50, "PresetDungeounBWL")
    CreateInstanceButton("MC", -90, "PresetDungeounMC")
    CreateInstanceButton("Onyxia", -130, "PresetDungeounOnyxia")
    CreateInstanceButton("AQ40", -170, "PresetDungeounAQ40")
    CreateInstanceButton("AQ20", -210, "PresetDungeounAQ20")	
    CreateInstanceButton("ZG", -250, "PresetDungeounZG")	
	CreateInstanceButton("Other", -290, "PresetDungeounOther")


    
function CreateInstanceFrame(name, presets)
    local frame = CreateFrame("Frame", name, UIParent)
    frame:SetWidth(200)
    frame:SetHeight(350)
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

    local buttonWidth = 80
    local buttonHeight = 30
    local padding = 10
    local maxButtonsPerColumn = 8


    local totalButtonWidth = buttonWidth + padding
    local totalButtonHeight = buttonHeight + padding
    local numButtons = table.getn(presets)
    local numColumns = math.ceil(numButtons / maxButtonsPerColumn)
    local fixedStartY = -10 

    
    local function CreatePresetButton(preset, index)
        local button = CreateFrame("Button", nil, frame, "GameMenuButtonTemplate")
        button:SetWidth(buttonWidth)
        button:SetHeight(buttonHeight)
        button:SetText(preset.label or "Unknown preset") 


        local column = math.floor((index - 1) / maxButtonsPerColumn)
        local row = (index - 1) - (column * maxButtonsPerColumn)


        button:SetPoint("TOPLEFT", frame, "TOPLEFT", (frame:GetWidth() - (numColumns * totalButtonWidth - padding)) / 2 + (column * totalButtonWidth), fixedStartY - (row * totalButtonHeight))


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

            
            if preset.values then
                for classRole, value in pairs(preset.values) do
                    local inputBox = inputBoxes[classRole]
                    if inputBox then
                        inputBox:SetNumber(value)
                        local onTextChanged = inputBox:GetScript("OnTextChanged")
                        if onTextChanged then
                            onTextChanged(inputBox) 
                        end
                    end
                end
            end
        end)


        button:SetScript("OnEnter", function()
            GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
            GameTooltip:SetText(preset.tooltip or "No tooltip available")
            GameTooltip:Show()
        end)


        button:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
    end

    
    for index, preset in ipairs(presets) do
        CreatePresetButton(preset, index)
    end
	

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

    msg = string.lower(msg)
    local foundPreset = false

    for _, presetTable in pairs(allPresets) do
        if type(presetTable) == "table" then
            for _, preset in ipairs(presetTable) do
                local matchFound = 
                    (preset.label and string.find(string.lower(preset.label), msg, 1, true)) or
                    (preset.fullname and string.find(string.lower(preset.fullname), msg, 1, true))
                
                if not matchFound and preset.bosses then
                    for _, bossName in ipairs(preset.bosses) do
                        if string.find(string.lower(bossName), msg, 1, true) then
                            matchFound = true
                            break
                        end
                    end
                end

                if matchFound then
                    DEFAULT_CHAT_FRAME:AddMessage("Applying preset: " .. (preset.fullname or preset.label), "debugfilling")
                    
                    
                    for classRole, inputBox in pairs(inputBoxes) do
                        if inputBox then
                            inputBox:SetNumber(0)
                            local onTextChanged = inputBox:GetScript("OnTextChanged")
                            if onTextChanged then
                                onTextChanged(inputBox)
                            end
                        end
                    end
                    
                    
                    if preset.values then
                        for classRole, value in pairs(preset.values) do
                            if inputBoxes[classRole] then
                                inputBoxes[classRole]:SetNumber(value)
                                local onTextChanged = inputBoxes[classRole]:GetScript("OnTextChanged")
                                if onTextChanged then
                                    onTextChanged(inputBoxes[classRole])
                                end
                            end
                        end
                    end
                    
                    FillRaid()
                    foundPreset = true
                    return
                end
            end
        end
    end

    if not foundPreset then
        QueueDebugMessage("Preset not found: " .. msg, "debugerror")
    end
end



    return frame
end

local detectBossFrame = CreateFrame("Frame")
detectBossFrame:Hide()  

local lastDetectedBoss = nil  
local keyPressCooldown = false  

function ToggleClickToFill(isChecked)
    ClickToFillEnabled = isChecked  

end

local function DetectBossAndFillRaid()
    if keyPressCooldown then return end  

    if IsControlKeyDown() and IsAltKeyDown() then  
        local bossName = UnitName("target") or UnitName("mouseover")  
        if bossName and bossName ~= lastDetectedBoss then
            lastDetectedBoss = bossName  
            keyPressCooldown = true  
            
            SlashCmdList["FILLRAID"](bossName)
            detectBossFrame:Hide()  
        end
    end
end

local function ResetCooldown()
    keyPressCooldown = false  
    lastDetectedBoss = nil  
end

local function CheckAndEnableDetection()
    if ClickToFillEnabled and IsControlKeyDown() and IsAltKeyDown() then  
        detectBossFrame:Show()
        DetectBossAndFillRaid()  
    else
        detectBossFrame:Hide()
        ResetCooldown()  
    end
end


detectBossFrame:SetScript("OnUpdate", DetectBossAndFillRaid)


local detectBossEventFrame = CreateFrame("Frame")
detectBossEventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
detectBossEventFrame:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
detectBossEventFrame:RegisterEvent("MODIFIER_STATE_CHANGED")  
detectBossEventFrame:SetScript("OnEvent", function(_, event, key)
    if event == "MODIFIER_STATE_CHANGED" then
        if not IsControlKeyDown() and not IsAltKeyDown() then
            ResetCooldown()  
        end
    end
    CheckAndEnableDetection()
end)




    instanceFrames = {}

    instanceFrames["PresetDungeounNaxxramas"] = CreateInstanceFrame("PresetDungeounNaxxramas", naxxramasPresets)
    instanceFrames["PresetDungeounBWL"] = CreateInstanceFrame("PresetDungeounBWL", bwlPresets)
    instanceFrames["PresetDungeounMC"] = CreateInstanceFrame("PresetDungeounMC", mcPresets)
    instanceFrames["PresetDungeounOnyxia"] = CreateInstanceFrame("PresetDungeounOnyxia", onyxiaPresets)
    instanceFrames["PresetDungeounAQ40"] = CreateInstanceFrame("PresetDungeounAQ40", aq40Presets)
    instanceFrames["PresetDungeounAQ20"] = CreateInstanceFrame("PresetDungeounAQ20", aq20Presets)	
    instanceFrames["PresetDungeounZG"] = CreateInstanceFrame("PresetDungeounZG", ZGPresets)	
	instanceFrames["PresetDungeounOther"] = CreateInstanceFrame("PresetDungeounOther", otherPresets)

    
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
    spotsLeftLabel:SetText("Spots Left: 39")
    roleCountsLabel:SetText("Tanks: 0 Healers: 0 Melee DPS: 0 Ranged DPS: 0")
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
local openFillRaidButton = CreateFrame("Button", "OpenFillRaidButton", UIParent)
openFillRaidButton:SetMovable(true)
openFillRaidButton:EnableMouse(true)
openFillRaidButton:RegisterForDrag("LeftButton")

local kickAllButton = CreateFrame("Button", "KickAllButton", UIParent)


kickAllButton:SetScript("OnClick", function()
    UninviteAllRaidMembers()
	ReplaceDeadBot = {}
	resetData()
	UpdateReFillButtonVisibility()	
end)
kickAllButton:Hide() 

local reFillButton = CreateFrame("Button", "reFillButton", UIParent)


function ToggleSmallbuttonCheck(isChecked)
    SmallbuttonEnabled = isChecked

    
    if SmallbuttonEnabled then 
		openFillRaidButton:SetWidth(32)  
		openFillRaidButton:SetHeight(32) 
        openFillRaidButton:SetNormalTexture("Interface\\AddOns\\fillraidbots\\img\\fillraidmini")
		openFillRaidButton:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")
        openFillRaidButton:SetPushedTexture("Interface\\AddOns\\fillraidbots\\img\\fillraidmini")

		kickAllButton:SetWidth(32)  
		kickAllButton:SetHeight(32) 
		kickAllButton:SetNormalTexture("Interface\\AddOns\\fillraidbots\\img\\kickallmini")
		kickAllButton:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")  
		kickAllButton:SetPushedTexture("Interface\\AddOns\\fillraidbots\\img\\kickallmini")  

		reFillButton:SetWidth(32)  
		reFillButton:SetHeight(32) 

		reFillButton:SetNormalTexture("Interface\\AddOns\\fillraidbots\\img\\refillmini")
		reFillButton:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")  
		reFillButton:SetPushedTexture("Interface\\AddOns\\fillraidbots\\img\\refillmini")  		
    else
		openFillRaidButton:SetWidth(40)  
		openFillRaidButton:SetHeight(100) 
        openFillRaidButton:SetNormalTexture("Interface\\AddOns\\fillraidbots\\img\\fillraid")
		openFillRaidButton:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")
        openFillRaidButton:SetPushedTexture("Interface\\AddOns\\fillraidbots\\img\\fillraid")
		kickAllButton:SetWidth(40)  
		kickAllButton:SetHeight(100) 

		kickAllButton:SetNormalTexture("Interface\\AddOns\\fillraidbots\\img\\kickall")
		kickAllButton:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")  
		kickAllButton:SetPushedTexture("Interface\\AddOns\\fillraidbots\\img\\kickall") 
		reFillButton:SetWidth(40)  
		reFillButton:SetHeight(100) 

		reFillButton:SetNormalTexture("Interface\\AddOns\\fillraidbots\\img\\refill")
		reFillButton:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")  
		reFillButton:SetPushedTexture("Interface\\AddOns\\fillraidbots\\img\\refill")   		
    end  
end
local savedPositions = {}




ToggleSmallbuttonCheck(SmallbuttonEnabled or false) 
function InitializeButtonPosition()
    local position = savedPositions["OpenFillRaidButton"] or {x = -20, y = 250}

    if PCPFrame then 
        openFillRaidButton:SetPoint("CENTER", PCPFrame, "LEFT", position.x, position.y)
    elseif PCPFrameRemake then
        openFillRaidButton:SetPoint("LEFT", PCPFrameRemake, "LEFT", position.x -20, 0 + 100)  
    end
end


function ToggleButtonMovement(button)
    if FillRaidBotsSavedSettings.moveButtonsEnabled then
        openFillRaidButton:SetMovable(true)
        QueueDebugMessage("Movable enabled for OpenFillRaidButton", "debuginfo")

        openFillRaidButton:SetScript("OnDragStart", function()
            this:StartMoving()
            this.isMoving = true
        end)

        openFillRaidButton:SetScript("OnDragStop", function()
            this:StopMovingOrSizing()
            this.isMoving = false
            local point, _, _, x, y = this:GetPoint()
            savedPositions["OpenFillRaidButton"] = {x = x, y = y}
            QueueDebugMessage("Coordinates: x: " .. tostring(x) .. ", y: " .. tostring(y), "debuginfo") 
        end)		
    else
        
        openFillRaidButton:SetScript("OnDragStart", nil)
        openFillRaidButton:SetScript("OnDragStop", nil)
        QueueDebugMessage("Movable disabled for OpenFillRaidButton", "debuginfo")
    end
end


ToggleButtonMovement(openFillRaidButton)



function openFillRaid()
    if FillRaidFrame:IsShown() then
        FillRaidFrame:Hide()
        fillRaidFrameManualClose = true
    else
        FillRaidFrame:Show()
        fillRaidFrameManualClose = false
    end
end


openFillRaidButton:SetScript("OnClick", openFillRaid)

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
function RefillBots()
    if next(ReplaceDeadBot) == nil then
        QueueDebugMessage("Replaced Bot List is empty.", "debugfilling")
    else
        QueueDebugMessage("Replaced Bot List:", "debugfilling")
        for playerName, data in pairs(ReplaceDeadBot) do
            QueueDebugMessage(playerName .. " - Class: " .. data.classColored .. ", Role: " .. data.role, "debugfilling")
            QueueMessage(".partybot add " .. data.ClassNoColor .. " " .. data.role, "SAY", true)
        end
        
        ReplaceDeadBot = {}
		

        QueueDebugMessage("Replaced Bot List has been cleared.", "debugfilling")

        
        UpdateReFillButtonVisibility()
    end  
end	
reFillButton:SetScript("OnClick", RefillBots)


UpdateReFillButtonVisibility()



local function UpdateButtonPosition()
        if (PCPFrame and PCPFrame:IsVisible()) or (PCPFrameRemake and PCPFrameRemake:IsVisible()) then
        InitializeButtonPosition()
    
        kickAllButton:ClearAllPoints()
        kickAllButton:SetPoint("TOP", openFillRaidButton, "BOTTOM", 0, -10) 
        reFillButton:ClearAllPoints()
        reFillButton:SetPoint("TOP", kickAllButton, "BOTTOM", 0, -10) 		
    end
end


UpdateButtonPosition()


	
	local visibilityFrame = CreateFrame("Frame")
	visibilityFrame:SetScript("OnUpdate", function()
		    if (PCPFrame and PCPFrame:IsVisible()) or (PCPFrameRemake and PCPFrameRemake:IsVisible()) then
			UpdateButtonPosition()
			if not fillRaidFrameManualClose and not openFillRaidButton:IsShown() then
				openFillRaidButton:Show()
			end
			if not kickAllButton:IsShown() then
				kickAllButton:Show()
			end
			if not reFillButton:IsShown() then

				UpdateReFillButtonVisibility()
			end			
		elseif (PCPFrame and not PCPFrame:IsVisible()) or (PCPFrameRemake and not PCPFrameRemake:IsVisible()) then
			openFillRaidButton:Hide()
			kickAllButton:Hide()
			reFillButton:Hide()
			FillRaidFrame:Hide()    
			fillRaidFrameManualClose = false
		else
			if openFillRaidButton:IsShown() and not fillRaidFrameManualClose then
				openFillRaidButton:Hide()
			end
			if kickAllButton:IsShown() then
				kickAllButton:Hide()
			end
			if reFillButton:IsShown() then
				reFillButton:Hide()
			end			
		end
	end)
	visibilityFrame:Show()

end


CreateFillRaidUI()



local messageCooldowns = {}

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
    local myName = UnitName("player")
    initialBotRemoved = false
    firstBotName = nil
    botCount = 0    

    
    local guildMembers = {}
    for i = 1, GetNumGuildMembers() do
        local name = GetGuildRosterInfo(i)
        if name and name ~= myName then
            guildMembers[name] = true
        end
    end

    
    local friends = {}
    for i = 1, GetNumFriends() do
        local name, _, _, _, online = GetFriendInfo(i)
        if name and online then
            friends[name] = true
        end
    end

    
    local startIndex = 2
    for i = 1, GetNumRaidMembers() do
        local unit = "raid" .. tostring(i)
        local name = UnitName(unit)
        if name and (guildMembers[name] or friends[name]) then
            startIndex = 1
            break 
        end
    end

    
    for i = startIndex, GetNumRaidMembers() do
        local unit = "raid" .. tostring(i)
        local name = UnitName(unit)
        if name then
            if name == myName then
                QueueDebugMessage("INFO: Kept " .. name .. " because it's you.", "debugremove")
            elseif guildMembers[name] then
                QueueDebugMessage("INFO: Kept " .. name .. " because they are in your guild.", "debugremove")
            elseif friends[name] then
                QueueDebugMessage("INFO: Kept " .. name .. " because they are your friend.", "debugremove")
            else
                QueueDebugMessage("REMOVING: " .. name .. " because they are not in your guild or friends list.", "debugremove")
                UninviteByName(name)
            end
        else
            QueueDebugMessage("ERROR: Skipped uninviting an unknown or nil player at raid slot " .. i, "debugremove")
        end
    end
end



local c = "0"

SLASH_FRB1 = "/frb"
SlashCmdList["FRB"] = function(cmd)
    cmd = cmd and string.lower(strtrim(cmd)) or ""

    if cmd == "ua" or cmd == "uninvite all" then
        UninviteAllRaidMembers()
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
    else
        
        if cmd == "" or cmd == "help" then
            DEFAULT_CHAT_FRAME:AddMessage("FillRaidBots Commands:", 1.0, 1.0, 0.0)
            DEFAULT_CHAT_FRAME:AddMessage("/frb ua - Uninvite all non-guild/friend raid members", 1.0, 1.0, 0.0)
            DEFAULT_CHAT_FRAME:AddMessage("/frb (preset name) - Fill raid with optimal composition", 1.0, 1.0, 0.0)
            DEFAULT_CHAT_FRAME:AddMessage("/frb list - lists all presets", 1.0, 1.0, 0.0)			
            DEFAULT_CHAT_FRAME:AddMessage("/frb open - Toggle FillRaid window", 1.0, 1.0, 0.0)
            DEFAULT_CHAT_FRAME:AddMessage("/frb refill - Replace recently removed bots", 1.0, 1.0, 0.0)
            DEFAULT_CHAT_FRAME:AddMessage("/frb fixgroups - Reorganize raid groups", 1.0, 1.0, 0.0)

        else
            
			ReplaceDeadBot = {}
			resetData()
			UpdateReFillButtonVisibility()
            SlashCmdList["FILLRAID"](cmd)
        end
    end
end





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





local function splitVersion(version)
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


local function isNewerVersion(current, received)
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


frame:SetScript("OnEvent", function()
    if event == "PLAYER_LOGIN" then
        
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







