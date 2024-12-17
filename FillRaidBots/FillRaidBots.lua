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
local versionNumber = "2.0.1"
local botCount = 0
local initialBotRemoved = false
local firstBotName = nil
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
            QueueMessage("Resuming..", "none")
            isInCombat = false
            retryTimerRunning = false
			incombatmessagesent = false	
            combatCheckFrame:SetScript("OnUpdate", nil) 
            ProcessMessageQueue() 
        else
            --print("Still in combat, retrying...")
        end
    end
end
local firstBotRemovalFrame = CreateFrame("Frame")
firstBotRemovalFrame:RegisterEvent("RAID_ROSTER_UPDATE")


firstBotRemovalFrame:SetScript("OnEvent", function()
    
    if not initialBotRemoved and GetNumRaidMembers() >= 3 then
        if firstBotName then
            QueueMessage("Removed first bot: " .. firstBotName, "debugremove")
            UninviteMember(firstBotName, "firstBotRemoved")

        end
    end
end)


function ProcessMessageQueue()
    if next(messageQueue) ~= nil then 
        local messageInfo = table.remove(messageQueue, 1)
        local message = messageInfo.message
        local recipient = messageInfo.recipient


        local colors = {
            Error = "|cFFFF0000",     
            WARNING = "|cFFFFA500",  
            INFO = "|cFFFFFF00",     
            Detected = "|cFF00FF00", 
            Added = "|cFF00FF00",     
			Removing = "|cFFADD8E6",
			Removed = "|cFFADD8E6",
			Fixgroups = "|cFFDDA0DD"
        }
        local resetColor = "|r" 

        
        for keyword, color in pairs(colors) do
            message = string.gsub(message, "(" .. keyword .. ")", color .. "%1" .. resetColor)
        end

        
        if recipient == "SAY" then
            
            if IsAnyRaidMemberInCombat() then
				if not incombatmessagesent then 
					QueueMessage("Raid member in combat, waiting..", "none")
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
--RoleDetector:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE")
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
    --["Heroic Strike"] = {class = "warrior", role = "meleedps", confidenceIncrease = 3},
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
    --["Rejuvenation"] = {class = "druid", role = "healer", confidenceIncrease = 3},
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
            QueueMessage("Detected:" .. detectedPlayerCount .. " - " .. playerName .. " is a " .. coloredClass .. " (" .. role .. ") using: " .. spell, "debugdetection")
        end
    else
        QueueMessage("INFO: Updated confidence for " .. playerName .. ": " .. data.roleConfidence, "debugdetection")
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


local buffIconMap = {
    ["Interface\\Icons\\INV_Potion_86"] = "Greater Armor",  
    ["Interface\\Icons\\Spell_Frost_FrostArmor02"] = "Ice Armor",  
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
                        --print(unitName .. " (Tank) has Greater Armor or equivalent active.")
                        detectedPlayers[unitName] = true  
                        updateRoleConfidence(unitName, unitClass, "tank", 3, "Greater Armor")
                    end
                end

                
                if buffTexture == "Interface\\Icons\\Spell_Frost_FrostArmor02" then
                    if not detectedPlayers[unitName] then
                        --print(unitName .. " has Ice Armor active.")
                        detectedPlayers[unitName] = true  
                        updateRoleConfidence(unitName, "mage", "rangedps", 3, "Ice Armor")
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
        QueueMessage("Cleared both lists", "debugdetection")
    end

    
    wasInGroup = isInParty or isInRaid

    
    for name in pairs(oldGroupMembers) do
        local normalizedName = normalizePlayerName(name)

        
        if not groupMembers[normalizedName] then
            
            if detectedPlayers[normalizedName] then
                QueueMessage("Removed: " .. normalizedName .. " from detected player list!", "debugremove")
                detectedPlayers[normalizedName] = nil
				detectedPlayerCount = detectedPlayerCount -1
            end

            
            if playerData[normalizedName] then
                QueueMessage("Removed: " .. normalizedName .. " from active player list!", "debugremove")
                playerData[normalizedName] = nil
            end
        end
    end
end)



function UninviteMember(name, reason)
    
    local normalizedName = normalizePlayerName(name)
    if not normalizedName then
        QueueMessage("ERROR: Could not normalize name for UninviteMember", "debugerror")
        return
    end

    
    QueueMessage("INFO: Attempting to uninvite member:" .. normalizedName .. " Reason: " .. reason, "debugremove")

    
    if playerData[normalizedName] then
        QueueMessage("DEBUG: Player found in playerData and marked for removal: " .. normalizedName, "debugremove")
        ReplaceDeadBot[normalizedName] = playerData[normalizedName]
        playerData[normalizedName] = nil  
    else
        QueueMessage("WARNING: Player not found in playerData:" .. normalizedName, "debugremove")
    end

    
    UninviteByName(normalizedName)

    
    if reason == "dead" then
        --print("DEBUG: Uninviting due to death:", normalizedName)  
        QueueMessage(normalizedName .. " has been uninvited because they are dead.", "debugremove")
    elseif reason == "firstBotRemoved" then
        QueueMessage("Removing party bot: " .. normalizedName, "debugremove")
        firstBotName = nil
		ReplaceDeadBot[normalizedName] = nil
        initialBotRemoved = true 
    else
        QueueMessage(normalizedName .. " has been uninvited.", "debugremove")  
    end
end
function resetData()
    playerData = {}  
    detectedPlayers = {}  
    detectedPlayerCount = 0  
    QueueMessage("INFO: All player data has been reset.", "debuginfo")
end

SLASH_ROLELIST1 = "/rolelist"
SlashCmdList["ROLELIST"] = function()
    QueueMessage("INFO: Player Role List:", "debuginfo")
    local count = 0

    
    for playerName, data in pairs(playerData) do
        count = count + 1
        QueueMessage(count .. ". " .. playerName .. " - Class: " .. data.classColored .. ", Role: " .. data.role, "debuginfo")
    end

end

SLASH_TT1 = "/tt"
SlashCmdList["TT"] = function()
    DebugMessage("Det här är ett testmeddelande 3.", "debuginfo")
    DebugMessage("Det här är ett testmeddelande 3.", "debug")
    DebugMessage("Det här är ett testmeddelande 3.", "debug")
    DebugMessage("Det här är ett testmeddelande 3.", "debug")
    DebugMessage("Det här är ett testmeddelande 3.", "debug")
    DebugMessage("Det här är ett testmeddelande 3.", "debug")
    DebugMessage("Det här är ett testmeddelande 3.", "debug")
    DebugMessage("Det här är ett testmeddelande 3.", "debug")
    DebugMessage("Det här är ett testmeddelande 3.", "debug")
    DebugMessage("Det här är ett testmeddelande 3.", "debug")
    DebugMessage("Det här är ett testmeddelande 3.", "debug")
    DebugMessage("Det här är ett testmeddelande 3.", "debug")
    DebugMessage("Det här är ett testmeddelande 3.", "debug")	
end


SLASH_REPLACELIST1 = "/replacelist"
SlashCmdList["REPLACELIST"] = function()
    if next(ReplaceDeadBot) == nil then
        QueueMessage("Replaced Bot List is empty.", "debuginfo")
    else
        QueueMessage("Replaced Bot List:", "debuginfo")
        for playerName, data in pairs(ReplaceDeadBot) do
            QueueMessage(playerName .. " - Class: " .. data.classColored .. ", Role: " .. data.role, "debuginfo")
            --QueueMessage(".partybot add " .. data.classColored .. " " .. data.role, "SAY", true)
        end

    end
end


local messagecantremove = false

local function CheckAndRemoveDeadBots()
    if not FillRaidBotsSavedSettings.isCheckAndRemoveEnabled then return end
    local playerName = UnitName("player")



	if not (IsRaidLeader() or IsRaidOfficer()) and GetNumRaidMembers() > 0 then
		QueueMessage("WARNING: You must be a raid leader or officer to remove bots.", "debuginfo")
		return
	end

    if GetNumRaidMembers() > 0 then
        
        if GetNumRaidMembers() > 2 then
            for i = 1, GetNumRaidMembers() do
                local name, _, _, _, _, _, _, _, isDead = GetRaidRosterInfo(i)
                local unit = "raid" .. i

                
                if isDead and UnitExists(unit) and not UnitIsGhost(unit) and name ~= playerName then
                    UninviteMember(name, "dead")
                end
            end
            messagecantremove = false 
        elseif not messagecantremove then
            QueueMessage("INFO: Saving the last bot so the raid does not disband.", "debuginfo")
            messagecantremove = true
        end
    elseif GetNumPartyMembers() > 0 then
        for i = 1, GetNumPartyMembers() do
            local unit = "party" .. i
            local name = UnitName(unit)

            if UnitIsDead(unit) and not UnitIsGhost(unit) and name ~= playerName then
                UninviteMember(name, "dead")
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
            table.insert(raidMembers, name)
            if not firstBotName then
                firstBotName = name
            end
        end
    end
    
    if firstBotName then
        QueueMessage("INFO: First bot in raid set to: " .. firstBotName, "debuginfo")
    else
        QueueMessage("Error: No bot found to set as the first bot in raid.", "debugerror")
    end
end


local function SavePartyMembersAndSetFirstBot()
  local partyMembers = {}
  for i = 1, GetNumPartyMembers() do
      local unit = "party" .. i
      local name = UnitName(unit)
      if name then
          table.insert(partyMembers, name)
      end
  end

  
  local playerName = UnitName("player")
  for _, member in ipairs(partyMembers) do
      if member ~= playerName then
          firstBotName = member
          break
      end
  end

  if firstBotName then
      QueueMessage("First bot set to: " .. firstBotName, "debuginfo")
  else
      QueueMessage("Error: No bot found to set as the first bot.", "debugerror")
  end
end


function resetfirstbot_OnEvent()
    if event == "RAID_ROSTER_UPDATE" or event == "PARTY_MEMBERS_CHANGED" then
        if GetNumPartyMembers() == 0 and GetNumRaidMembers() == 0 then
            initialBotRemoved = false
            firstBotName = nil
			botCount = 0
            QueueMessage("INFO: Bot state reset: No members in party or raid.", "debuginfo")
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
  QueueMessage("FillRaidBots [" .. versionNumber .. "]|cff00FF00 loaded|cffffffff", "none")
end

----------------------------------------------FixGroups----------------------------------------------------------------------
local MAX_PLAYERS_PER_GROUP = 5
local MAX_GROUPS = 8
local isFixingGroups = false
local moveDelay = 0.1 
local lastMoveTime = 0
local moveQueue = {} 
local healerClasses = {"PALADIN", "PRIEST", "DRUID", "SHAMAN"} 
local currentPhase = 1
local FixGroups





------------------------------------------------------FILLRAID WICH CALLS FIXGROUPS-------------------------------------------------------------------------
local function FillRaid()
    if GetNumRaidMembers() > 0 then
        if GetNumRaidMembers() == 2 then
            SaveRaidMembersAndSetFirstBot() 
            QueueMessage("SaveRaidMembersAndSetFirstBot called", "debugfilling")
        end
    else
        
        if GetNumPartyMembers() == 0 then
            QueueMessage(".partybot add warrior tank", "SAY", true)
            QueueMessage("Inviting the first bot to start the party.", "none")

            
            local waitForPartyFrame = CreateFrame("Frame")
            waitForPartyFrame:SetScript("OnUpdate", function()
                if GetNumPartyMembers() > 0 then
                    this:SetScript("OnUpdate", nil)
                    this:Hide()
                    SavePartyMembersAndSetFirstBot() 
                    FillRaid() 
                end
            end)
            waitForPartyFrame:Show()
            return
        end

        
        if GetNumPartyMembers() >= 1 then
            
            ConvertToRaid()
            QueueMessage("Converted to raid.", "debugfilling")
        elseif GetNumPartyMembers() < 2 then
            QueueMessage("You need at least 2 players in the group to convert to a raid.", "debugfilling")
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

    QueueMessage("Added: Going to add healers:" .. totalHealers, "debugfilling")
    QueueMessage("Added: Going to add classes:" .. totalOthers, "debugfilling")
    QueueMessage("Added: Totaly:" .. totaly, "debugfilling")

    
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
        QueueMessage("Added " .. coloredClass, "debuginfo")
    end

    
    local function addothers()
        QueueMessage("addothers called", "debuginfo")

        
        local otherClassesCount = countTableEntries(others)
        if otherClassesCount == 0 then
            QueueMessage("No other classes to add.", "debugfilling")
            return
        end

        
        for _, otherClass in ipairs(others) do
            addBot(otherClass)
        end
        QueueMessage("Raid filling complete.", "none")
    end

    
    if totalHealers == 0 then
        QueueMessage("No healers found. Skipping healer addition.", "debugfilling")
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
					QueueMessage("Fixgroups: All healers are in the raid. Starting FixGroups after 1-second delay.", "debuginfo")

					
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
									
									QueueMessage("Added: Adding other classes after healers.", "debugfilling")
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
            QueueMessage("Fixgroups: Phase 1 complete, starting Phase 2", "debuginfo")
            currentPhase = 2
            FixGroups()
        else
            QueueMessage("Fixgroups: Phase 2 complete, groups organized", "debuginfo")
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
                
                QueueMessage("Warning: Too many healers of class " .. class .. ", assigning remaining healers randomly.", "debugfilling")
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
                        
                        QueueMessage("Error: Too many of " .. class .. " in raid. Assigning to available group.", "debugerror")
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
                            
                            QueueMessage("Error: Too many of " .. healer.class .. " in raid. Assigning to available group.", "debugerror")
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

SlashCmdList["FIXGROUPS"] = function()
    isFixingGroups = true
    currentPhase = 1
    lastMoveTime = 0
    moveQueue = {}
    FixGroups()
end

SLASH_FIXGROUPS1 = "/fixgroups"
----------------------------------------------------------THE UI------------------------------------------------------------------------------------

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
                QueueMessage("Error: Frame '" .. frameName .. "' not found.", "debugerror")
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


    
local function CreateInstanceFrame(name, presets)
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

    return frame
end

    
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
	UISettingsFrame:Hide()
    for frameName, frame in pairs(instanceFrames) do
        if frame:IsShown() then
            frame:Hide()
        end
    end
end)
ClickBlockerFrame:Hide() 

	
local savedPositions = {}

local openFillRaidButton = CreateFrame("Button", "OpenFillRaidButton", UIParent)
openFillRaidButton:SetWidth(40)  
openFillRaidButton:SetHeight(100) 


openFillRaidButton:SetNormalTexture("Interface\\AddOns\\fillraidbots\\img\\fillraid")
openFillRaidButton:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")  
openFillRaidButton:SetPushedTexture("Interface\\AddOns\\fillraidbots\\img\\fillraid")  
openFillRaidButton:SetMovable(true)
openFillRaidButton:EnableMouse(true)
openFillRaidButton:RegisterForDrag("LeftButton")


function InitializeButtonPosition()
    local position = savedPositions["OpenFillRaidButton"] or {x = -20, y = 250}
    openFillRaidButton:SetPoint("CENTER", PCPFrame, "LEFT", position.x, position.y) 
end

function ToggleButtonMovement(button)
    if FillRaidBotsSavedSettings.moveButtonsEnabled then
        openFillRaidButton:SetMovable(true)
        QueueMessage("Movable enabled for OpenFillRaidButton", "debuginfo")

        openFillRaidButton:SetScript("OnDragStart", function()
            this:StartMoving()
            this.isMoving = true
        end)

        openFillRaidButton:SetScript("OnDragStop", function()
            this:StopMovingOrSizing()
            this.isMoving = false
            local point, _, _, x, y = this:GetPoint()
            savedPositions["OpenFillRaidButton"] = {x = x, y = y}
            QueueMessage("Coordinates: x: " .. tostring(x) .. ", y: " .. tostring(y), "debuginfo") 
        end)		
    else
        --openFillRaidButton:SetMovable(false)
        
        openFillRaidButton:SetScript("OnDragStart", nil)
        openFillRaidButton:SetScript("OnDragStop", nil)
        QueueMessage("Movable disabled for OpenFillRaidButton", "debuginfo")
    end
end


ToggleButtonMovement(openFillRaidButton)


openFillRaidButton:SetScript("OnClick", function()
    if FillRaidFrame:IsShown() then
        FillRaidFrame:Hide()
        fillRaidFrameManualClose = true
    else
        FillRaidFrame:Show()
        fillRaidFrameManualClose = false
    end
end)

openFillRaidButton:Hide()



local kickAllButton = CreateFrame("Button", "KickAllButton", UIParent)
kickAllButton:SetWidth(40)  
kickAllButton:SetHeight(100) 

kickAllButton:SetNormalTexture("Interface\\AddOns\\fillraidbots\\img\\kickall")
kickAllButton:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")  
kickAllButton:SetPushedTexture("Interface\\AddOns\\fillraidbots\\img\\kickall")  

kickAllButton:SetScript("OnClick", function()
    UninviteAllRaidMembers()
	ReplaceDeadBot = {}
	resetData()
	UpdateReFillButtonVisibility()	
end)
kickAllButton:Hide() 

local reFillButton = CreateFrame("Button", "reFillButton", UIParent)
reFillButton:SetWidth(40)  
reFillButton:SetHeight(100) 

reFillButton:SetNormalTexture("Interface\\AddOns\\fillraidbots\\img\\refill")
reFillButton:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")  
reFillButton:SetPushedTexture("Interface\\AddOns\\fillraidbots\\img\\refill")  


function UpdateReFillButtonVisibility()
    if next(ReplaceDeadBot) == nil then
        reFillButton:Hide()
    else
	if FillRaidBotsSavedSettings.isRefillEnabled then
        reFillButton:Show()
	end
    end
end


reFillButton:SetScript("OnClick", function()
    if next(ReplaceDeadBot) == nil then
        QueueMessage("Replaced Bot List is empty.", "debugfilling")
    else
        QueueMessage("Replaced Bot List:", "debugfilling")
        for playerName, data in pairs(ReplaceDeadBot) do
            QueueMessage(playerName .. " - Class: " .. data.classColored .. ", Role: " .. data.role, "debugfilling")
            QueueMessage(".partybot add " .. data.ClassNoColor .. " " .. data.role, "SAY", true)
        end
        
        ReplaceDeadBot = {}
		--resetData()

        QueueMessage("Replaced Bot List has been cleared.", "debugfilling")

        
        UpdateReFillButtonVisibility()
    end  
end)


UpdateReFillButtonVisibility()



local function UpdateButtonPosition()
    if PCPFrame and PCPFrame:IsVisible() then
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
		if PCPFrame and PCPFrame:IsVisible() then
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
		elseif PCPFrame and not PCPFrame:IsVisible() then
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
  initialBotRemoved = false
  firstBotName = nil
  botCount = 0    
  for i = 2, GetNumRaidMembers() do
      local unit = "raid" .. tostring(i)
      local name = UnitName(unit)
      if name then
          UninviteByName(name)
      end
  end
end



SLASH_UNINVITE_RAID1 = "/uninviteraid"
SlashCmdList["UNINVITE_RAID"] = function()
    UninviteAllRaidMembers()
end


--------------------------------------------------------------------------------------------------------------------





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

        
        QueueMessage(addonName .. " loaded. Current version: " .. versionNumber, "debuginfo")
        QueueMessage("INFO: Total unique users detected: " .. FillRaidBotsSavedSettings.userCount, "debuginfo")
        QueueMessage("Userid:" .. SessionUserID, "debuginfo")
        
        if isNewerVersion(versionNumber, FillRaidBotsSavedSettings.lastNotifiedVersion) then
            QueueMessage("INFO: New update available: " .. FillRaidBotsSavedSettings.lastNotifiedVersion, "debuginfo")
            sendVersionMessage(FillRaidBotsSavedSettings.lastNotifiedVersion, SessionUserID)  
            newversion(FillRaidBotsSavedSettings.lastNotifiedVersion) 
        else
			newversion()
            sendVersionMessage(versionNumber, SessionUserID)  
        end
	elseif event == "CHAT_MSG_ADDON" then
		local prefix = arg1
		local message = arg2
		local sender = arg4

		if prefix == addonPrefix then
			if sender ~= UnitName("player") then
				
				if not message or message == "" then
					QueueMessage("ERROR: Received an empty or nil message", "debugversion")
					return
				end
				local version, userID = strsplit(";", "1.13.8;7780693")

				
				local receivedVersion, userID = strsplit(";", message)

				
				QueueMessage("ReceivedVersion: [" .. receivedVersion .. "], from userID: [" .. tostring(userID) .. "]", "debugversion")


				
				if not tonumber(userID) then
					QueueMessage("ERROR: UserID is not a valid number: " .. tostring(userID), "debugversion")
					return
				end

				
				local versionPattern = "^%d+%.%d+%.%d+$"
				if not strfind(receivedVersion, versionPattern) then
					QueueMessage("ERROR: Version format is invalid: " .. tostring(receivedVersion), "debugversion")
					return
				end

				
				if not SessionUniqueUsers[userID] and not FillRaidBotsSavedSettings.uniqueUsers[userID] then
					SessionUniqueUsers[userID] = true
					FillRaidBotsSavedSettings.uniqueUsers[userID] = true
					FillRaidBotsSavedSettings.userCount = FillRaidBotsSavedSettings.userCount + 1
					QueueMessage("INFO: New user detected. Total unique users: " .. FillRaidBotsSavedSettings.userCount, "debugversion")
				end

				
				if isNewerVersion(versionNumber, receivedVersion) then
					local lastNotifiedVersion = FillRaidBotsSavedSettings.lastNotifiedVersion or ""
					if isNewerVersion(lastNotifiedVersion, receivedVersion) then
						QueueMessage("INFO: New version detected: " .. receivedVersion, "debuginfo")
						FillRaidBotsSavedSettings.lastNotifiedVersion = receivedVersion
						sendVersionMessage(receivedVersion, SessionUserID)  
						newversion(receivedVersion) 
					else
						QueueMessage("INFO: Version " .. receivedVersion .. " already notified.", "debugversion")
					end
				else
					QueueMessage("INFO: Your version is up to date.", "debugversion")
				end
			end
    end
end



end)





----------------------------------------------------------------------------------------------------------------------

