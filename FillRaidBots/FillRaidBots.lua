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

local botCount = 0
local initialBotRemoved = false
local firstBotName = nil
local messageQueue = {}
local delay = 0.5 -- Delay between messages
local nextUpdateTime = 0 -- Initialize the next update time

local classCounts = {}
local FillRaidFrame -- Declare global reference for your frame
local fillRaidFrameManualClose = false -- State variable to track manual close
local isCheckAndRemoveEnabled = false


if FillRaidBotsSavedSettings == nil then
    FillRaidBotsSavedSettings = {}
end

-- Initialize the saved setting for the toggle button
local function InitializeSettings()
    -- Initialize the setting for isCheckAndRemoveEnabled if not already set
    if FillRaidBotsSavedSettings.isCheckAndRemoveEnabled == nil then
        FillRaidBotsSavedSettings.isCheckAndRemoveEnabled = false  -- Default to false
    end
end

-- Add messages to the queue
local function QueueMessage(message, recipient, incrementBotCount)
  table.insert(messageQueue,
      { message = message, recipient = recipient or "none", incrementBotCount = incrementBotCount or false })
end

-- Function to process and send chat messages from the queue
local function ProcessMessageQueue()
  if next(messageQueue) ~= nil then -- Check if the queue is not empty
      local messageInfo = table.remove(messageQueue, 1)
      local message = messageInfo.message
      local recipient = messageInfo.recipient

      if recipient == "none" then
          -- Handle notifications (not sent in chat)
          DEFAULT_CHAT_FRAME:AddMessage(message)
      else
          -- Handle chat messages
          SendChatMessage(message, recipient)
      end

      if messageInfo.incrementBotCount then
          botCount = botCount + 1
          -- Remove the first bot after the tenth bot is added
          if botCount == 10 and not initialBotRemoved then
              if firstBotName then
                  UninviteMember(firstBotName, "firstBotRemoved")
              else
                  QueueMessage("Error: First bot's name not captured.", "none")
              end
              initialBotRemoved = true
          end
      end
  end
end

-- Function to uninvite a specific member by their name
function UninviteMember(name, reason)
    if name then
        UninviteByName(name)
        if reason == "dead" then
            --QueueMessage(name .. " has been uninvited because they are dead.", "none")
        elseif reason == "firstBotRemoved" then
            --QueueMessage("10 bots added. Removing party bot: " .. name, "none")
			firstBotName = nil
        end
       
    end
end


-- Function to check for dead bots and remove them
local messagecantremove = false

local function CheckAndRemoveDeadBots()
    if not FillRaidBotsSavedSettings.isCheckAndRemoveEnabled then return end
    -- Get the player's name to avoid removing yourself
    local playerName = UnitName("player")

    -- Check if we are in a raid
    if GetNumRaidMembers() > 0 then
        -- Ensure raid has at least 2 members before removing anyone
        if GetNumRaidMembers() > 2 then
            for i = 1, GetNumRaidMembers() do
                local name, _, _, _, _, _, _, _, isDead = GetRaidRosterInfo(i)
                local unit = "raid" .. i

                -- Check if the member is dead and exists, but also ensure it's not the player
                if isDead and UnitExists(unit) and not UnitIsGhost(unit) and name ~= playerName then
                    UninviteMember(name, "dead")
                end
            end
            messagecantremove = false -- Reset the flag if removal is possible
        elseif not messagecantremove then
            --QueueMessage("Saving the last bot so the raid does not disband.", "none")
            messagecantremove = true
        end
        -- Check if we are in a party
    elseif GetNumPartyMembers() > 0 then
        for i = 1, GetNumPartyMembers() do
            local unit = "party" .. i
            local name = UnitName(unit)

            -- Check if the member is dead and exists, but also ensure it's not the player
            if UnitIsDead(unit) and not UnitIsGhost(unit) and name ~= playerName then
                UninviteMember(name, "dead")
            end
        end
    end
end



-- Function to save party member names and set the first bot's name
local function SavePartyMembersAndSetFirstBot()
  local partyMembers = {}
  for i = 1, GetNumPartyMembers() do
      local unit = "party" .. i
      local name = UnitName(unit)
      if name then
          table.insert(partyMembers, name)
      end
  end

  -- Set firstBotName to the first party member that's not the player
  local playerName = UnitName("player")
  for _, member in ipairs(partyMembers) do
      if member ~= playerName then
          firstBotName = member
          break
      end
  end

  if firstBotName then
      QueueMessage("First bot set to: " .. firstBotName, "none")
  else
      QueueMessage("Error: No bot found to set as the first bot.", "none")
  end
end


function resetfirstbot_OnEvent()
    if event == "RAID_ROSTER_UPDATE" or event == "PARTY_MEMBERS_CHANGED" then
        -- Check if there are no party or raid members
        if GetNumPartyMembers() == 0 and GetNumRaidMembers() == 0 then
            initialBotRemoved = false
            firstBotName = nil
			botCount = 0
            --QueueMessage("Bot state reset: No members in party or raid.", "none")
        end
    end
end

-- Create a frame for handling the events
local resetBotFrame = CreateFrame("Frame")
resetBotFrame:RegisterEvent("RAID_ROSTER_UPDATE")
resetBotFrame:RegisterEvent("PARTY_MEMBERS_CHANGED")
resetBotFrame:SetScript("OnEvent", resetfirstbot_OnEvent)

-- Function to handle the delayed sending of messages and notifications
local function OnUpdate()
  if GetTime() >= nextUpdateTime then
      ProcessMessageQueue()
      CheckAndRemoveDeadBots() -- Check for dead bots regularly
      nextUpdateTime = GetTime() + delay -- Set the next update time
  end
end

-- Initialize the frame for OnUpdate
local updateFrame = CreateFrame("Frame")
updateFrame:SetScript("OnUpdate", OnUpdate)
nextUpdateTime = GetTime() -- Initialize the next update time

function FillRaid_OnLoad()
  this:RegisterEvent("PLAYER_LOGIN")
  this:RegisterEvent("PLAYER_ENTERING_WORLD")
  this:RegisterEvent('RAID_ROSTER_UPDATE')
  this:RegisterEvent('GROUP_ROSTER_UPDATE')
  this:RegisterEvent("ADDON_LOADED")
  this:RegisterEvent("CHAT_MSG_SYSTEM")
  QueueMessage("FillRaid |cff00FF00 loaded|cffffffff", "none")
end

local function FillRaid()
  -- Check if we are in a party
  if GetNumPartyMembers() == 0 then
      -- Not in a party; add the first bot to create the party
      QueueMessage(".partybot add warrior tank", "SAY", true)
      QueueMessage("Inviting the first bot to start the party.", "none")

      -- Create a frame to wait until the party is created, then continue filling
      local waitForPartyFrame = CreateFrame("Frame")
      waitForPartyFrame:SetScript("OnUpdate", function()
          if GetNumPartyMembers() > 0 then
              this:SetScript("OnUpdate", nil)
              this:Hide()
              SavePartyMembersAndSetFirstBot() -- Save party members and set the first bot
              FillRaid() -- Retry filling the raid now that the party is created
          end
      end)
      waitForPartyFrame:Show()
      return -- Exit temporarily to wait until the bot is added and the group is created
  end

  -- Check if we are in a raid
  if GetNumRaidMembers() == 0 then
      -- In a party but not a raid; convert to raid if there are 2 or more players
      if GetNumPartyMembers() >= 1 then -- Includes yourself
          ConvertToRaid()
          --QueueMessage("Converted to raid.", "none")
      else
          --QueueMessage("You need at least 2 players in the group to convert to a raid.", "none")
          return
      end
  end

  -- Now fill the raid based on the selected class counts
  for _, class in ipairs(classes) do
      local count = classCounts[class] or 0
      for i = 1, count do
          QueueMessage(".partybot add " .. class, "SAY", true)
      end
  end

  QueueMessage("Raid filling complete.", "none")
end

-- Create the UI frame for class selection and the Fill Raid button
function CreateFillRaidUI()
    -- Create the main UI frame
    FillRaidFrame = CreateFrame("Frame", "FillRaidFrame", UIParent) -- Assign global reference
    FillRaidFrame:SetWidth(310)
    FillRaidFrame:SetHeight(450)
    FillRaidFrame:SetPoint("CENTER", UIParent, "CENTER")
    FillRaidFrame:SetMovable(true)
    FillRaidFrame:EnableMouse(true)
    FillRaidFrame:RegisterForDrag("LeftButton")
    FillRaidFrame:SetScript("OnDragStart", FillRaidFrame.StartMoving)
    FillRaidFrame:SetScript("OnDragStop", FillRaidFrame.StopMovingOrSizing)
    -- Handle custom dragging
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
    FillRaidFrame:SetBackdropColor(0, 0, 0, 1) -- Black background


	-- Add header background texture to FillRaidFrame
	FillRaidFrame.header = FillRaidFrame:CreateTexture(nil, 'ARTWORK')
	FillRaidFrame.header:SetWidth(250)
	FillRaidFrame.header:SetHeight(64)
	FillRaidFrame.header:SetPoint('TOP', FillRaidFrame, 0, 18)
	FillRaidFrame.header:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
	FillRaidFrame.header:SetVertexColor(.2, .2, .2)

	-- Add header text to FillRaidFrame
	FillRaidFrame.headerText = FillRaidFrame:CreateFontString(nil, 'ARTWORK', 'GameFontNormal')
	FillRaidFrame.headerText:SetPoint('TOP', FillRaidFrame.header, 0, -14)
	FillRaidFrame.headerText:SetText('Fill Raid')


    local yOffset = -30
    local xOffset = 20
    local totalBots = 0 -- To keep track of the total number of bots

    -- Label to display the total number of bots
    local totalBotLabel = FillRaidFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    totalBotLabel:SetPoint("TOP", FillRaidFrame, "TOP", 0, yOffset)
    totalBotLabel:SetText("Total Bots: 0")
    yOffset = yOffset - 25

    -- Label to display the spots left
    local spotsLeftLabel = FillRaidFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    spotsLeftLabel:SetPoint("TOP", FillRaidFrame, "TOP", 0, yOffset)
    spotsLeftLabel:SetText("Spots Left: 39") -- Default value
    yOffset = yOffset - 25

    -- Label to display the role counts
    local roleCountsLabel = FillRaidFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    roleCountsLabel:SetPoint("TOP", FillRaidFrame, "TOP", 0, yOffset)
    roleCountsLabel:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    roleCountsLabel:SetText("Tanks: 0 Healers: 0 Melee DPS: 0 Ranged DPS: 0")
    yOffset = yOffset - 30

    -- Number of columns and rows
    local columns = 2
    local rowsPerColumn = 9
    local columnWidth = 150
    local rowHeight = 30

    -- Define role-based icons using built-in paths
    local roleIcons = {
        ["tank"] = "Interface\\Icons\\Ability_Defend",
        ["meleedps"] = "Interface\\Icons\\Ability_DualWield",
        ["rangedps"] = "Interface\\Icons\\Ability_Marksmanship",
        ["healer"] = "Interface\\Icons\\Spell_Holy_Heal",
    }


    -- Initialize role counts
    local roleCounts = {
        ["tank"] = 0,
        ["healer"] = 0,
        ["meleedps"] = 0,
        ["rangedps"] = 0,
    }

    -- Table to store input box references
    local inputBoxes = {}

    -- Function to split class and role using string.find
    local function SplitClassRole(classRole)
        local spaceIndex = string.find(classRole, " ")
        if spaceIndex then
            local class = string.sub(classRole, 1, spaceIndex - 1)
            local role = string.sub(classRole, spaceIndex + 1)
            return class, role
        end
        return classRole, nil
    end

    -- Create input boxes for each class with role
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

        -- Store reference in the table
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

	  -- Create the Fill Raid button
	  local fillRaidButton = CreateFrame("Button", nil, FillRaidFrame, "GameMenuButtonTemplate")
	  fillRaidButton:SetPoint("BOTTOM", FillRaidFrame, "BOTTOM", -60, 20)
	  fillRaidButton:SetWidth(120)
	  fillRaidButton:SetHeight(40)
	  fillRaidButton:SetText("Fill Raid")

	  fillRaidButton:SetScript("OnClick", function()
		  FillRaid()  -- Call your existing FillRaid function
		  FillRaidFrame:Hide()  -- Hide the FillRaidFrame after filling the raid
	  end)


	  -- Create the Close button
	  local closeButton = CreateFrame("Button", nil, FillRaidFrame, "GameMenuButtonTemplate")
	  closeButton:SetPoint("BOTTOM", FillRaidFrame, "BOTTOM", 60, 20)
	  closeButton:SetWidth(120)
	  closeButton:SetHeight(40)
	  closeButton:SetText("Close")
	  closeButton:SetScript("OnClick", function()
		  FillRaidFrame:Hide()
		  fillRaidFrameManualClose = true -- Mark as manually closed
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
	UISettingsFrame:SetBackdropColor(0, 0, 0, 1) -- Black background
	UISettingsFrame:SetFrameStrata("DIALOG")
	UISettingsFrame:SetFrameLevel(10)
	UISettingsFrame:Hide() -- Initially hidden

	local openSettingsButton = CreateFrame("Button", "OpenSettingsButton", FillRaidFrame, "GameMenuButtonTemplate")
	openSettingsButton:SetWidth(80)
	openSettingsButton:SetHeight(20)
	openSettingsButton:SetText("Settings")
	openSettingsButton:SetPoint("TOPLEFT", FillRaidFrame, "TOPLEFT", 10, -10) -- Adjusted to TOPLEFT
	openSettingsButton:SetScript("OnClick", function()
		if UISettingsFrame:IsShown() then
			UISettingsFrame:Hide()
			ClickBlockerFrame:Hide() -- Hide the blocker when the frame is hidden
		else
			UISettingsFrame:Show()
			ClickBlockerFrame:Show() -- Show the blocker when the frame is open
		end
	end)


    -- Create the Instance Buttons Frame
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
    InstanceButtonsFrame:SetBackdropColor(0, 0, 0, 1) -- Black background
    InstanceButtonsFrame:SetFrameStrata("DIALOG")
    InstanceButtonsFrame:SetFrameLevel(10)
    InstanceButtonsFrame:Hide() -- Initially hidden

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
                print("Error: Frame '" .. frameName .. "' not found.")
            end
        end)
        return button
    end

    -- Create instance buttons
    CreateInstanceButton("Naxxramas", -10, "PresetDungeounNaxxramas")
    CreateInstanceButton("BWL", -50, "PresetDungeounBWL")
    CreateInstanceButton("MC", -90, "PresetDungeounMC")
    CreateInstanceButton("Onyxia", -130, "PresetDungeounOnyxia")
    CreateInstanceButton("AQ40", -170, "PresetDungeounAQ40")
    CreateInstanceButton("AQ20", -210, "PresetDungeounAQ20")	
    CreateInstanceButton("ZG", -250, "PresetDungeounZG")	
	CreateInstanceButton("Other", -290, "PresetDungeounOther")


    -- Function to create instance frames with error checking
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
    frame:SetBackdropColor(0, 0, 0, 1) -- Black background
    frame:SetFrameStrata("DIALOG")
    frame:SetFrameLevel(10)
    frame:Hide() -- Initially hidden

    local buttonWidth = 80
    local buttonHeight = 30
    local padding = 10
    local maxButtonsPerColumn = 8

    -- Calculate total width and height needed for buttons
    local totalButtonWidth = buttonWidth + padding
    local totalButtonHeight = buttonHeight + padding
    local numButtons = table.getn(presets)
    local numColumns = math.ceil(numButtons / maxButtonsPerColumn)

    -- Set fixed vertical starting position for the first button
    local fixedStartY = -10 -- Adjust this value to your desired starting position

    -- Function to create preset buttons
    local function CreatePresetButton(preset, index)
        local button = CreateFrame("Button", nil, frame, "GameMenuButtonTemplate")
        button:SetWidth(buttonWidth)
        button:SetHeight(buttonHeight)
        button:SetText(preset.label or "Unknown preset") -- Default text if label is nil

        -- Calculate column and row based on index
        local column = math.floor((index - 1) / maxButtonsPerColumn)
        local row = (index - 1) - (column * maxButtonsPerColumn)

        -- Position the button
        button:SetPoint("TOPLEFT", frame, "TOPLEFT", (frame:GetWidth() - (numColumns * totalButtonWidth - padding)) / 2 + (column * totalButtonWidth), fixedStartY - (row * totalButtonHeight))

        -- OnClick function with additional debug info
        button:SetScript("OnClick", function()
            -- Reset all input boxes to zero
            for classRole, inputBox in pairs(inputBoxes) do
                if inputBox then
                    inputBox:SetNumber(0)
                    local onTextChanged = inputBox:GetScript("OnTextChanged")
                    if onTextChanged then
                        onTextChanged(inputBox) -- Trigger the OnTextChanged handler to update totals
                    end
                end
            end

            -- Populate the input boxes with preset values
            if preset.values then
                for classRole, value in pairs(preset.values) do
                    local inputBox = inputBoxes[classRole]
                    if inputBox then
                        inputBox:SetNumber(value)
                        local onTextChanged = inputBox:GetScript("OnTextChanged")
                        if onTextChanged then
                            onTextChanged(inputBox) -- Trigger the OnTextChanged handler to update totals
                        end
                    end
                end
            end
        end)

        -- OnEnter function to show tooltip
        button:SetScript("OnEnter", function()
            GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
            GameTooltip:SetText(preset.tooltip or "No tooltip available")
            GameTooltip:Show()
        end)

        -- OnLeave function to hide tooltip
        button:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
    end

    -- Create buttons
    for index, preset in ipairs(presets) do
        CreatePresetButton(preset, index)
    end

    return frame
end





    -- Create instance frames
    instanceFrames = {}

    instanceFrames["PresetDungeounNaxxramas"] = CreateInstanceFrame("PresetDungeounNaxxramas", naxxramasPresets)
    instanceFrames["PresetDungeounBWL"] = CreateInstanceFrame("PresetDungeounBWL", bwlPresets)
    instanceFrames["PresetDungeounMC"] = CreateInstanceFrame("PresetDungeounMC", mcPresets)
    instanceFrames["PresetDungeounOnyxia"] = CreateInstanceFrame("PresetDungeounOnyxia", onyxiaPresets)
    instanceFrames["PresetDungeounAQ40"] = CreateInstanceFrame("PresetDungeounAQ40", aq40Presets)
    instanceFrames["PresetDungeounAQ20"] = CreateInstanceFrame("PresetDungeounAQ20", aq20Presets)	
    instanceFrames["PresetDungeounZG"] = CreateInstanceFrame("PresetDungeounZG", ZGPresets)	
	instanceFrames["PresetDungeounOther"] = CreateInstanceFrame("PresetDungeounOther", otherPresets)

    -- Modify the button to open InstanceButtonsFrame
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
            ClickBlockerFrame:Show() -- Show the blocker when InstanceButtonsFrame is open
        end
    end)
	

		

-- Create the Reset button
local resetButton = CreateFrame("Button", nil, FillRaidFrame, "GameMenuButtonTemplate")
resetButton:SetPoint("TOPRIGHT", FillRaidFrame, "TOPRIGHT", -10, -30)
resetButton:SetWidth(80)
resetButton:SetHeight(20)
resetButton:SetText("Reset")

-- Add functionality to reset all input boxes
resetButton:SetScript("OnClick", function()
    for _, inputBox in pairs(inputBoxes) do
        inputBox:SetNumber(0) -- Reset to 0
        local onTextChanged = inputBox:GetScript("OnTextChanged")
        if onTextChanged then
            onTextChanged(inputBox) -- Trigger the OnTextChanged handler to update totals
        end
    end

    -- Reset total bot counts and role counts
    totalBotLabel:SetText("Total Bots: 0")
    spotsLeftLabel:SetText("Spots Left: 39")
    roleCountsLabel:SetText("Tanks: 0 Healers: 0 Melee DPS: 0 Ranged DPS: 0")
end)



  -- Create a full-screen ClickBlockerFrame to handle clicks outside PresetFrame
local ClickBlockerFrame = CreateFrame("Frame", "ClickBlockerFrame", UIParent)
ClickBlockerFrame:SetAllPoints(UIParent) -- Covers the entire screen
ClickBlockerFrame:EnableMouse(true) -- Captures mouse clicks
ClickBlockerFrame:SetFrameStrata("DIALOG") -- Same strata as PresetFrame
ClickBlockerFrame:SetFrameLevel(1) -- Below PresetFrame
ClickBlockerFrame:SetScript("OnMouseDown", function()
    ClickBlockerFrame:Hide() -- Hide the blocker
    InstanceButtonsFrame:Hide() -- Hide the PresetFrame
	UISettingsFrame:Hide()
    -- Hide all instance frames
    for frameName, frame in pairs(instanceFrames) do
        if frame:IsShown() then
            frame:Hide()
        end
    end
end)
ClickBlockerFrame:Hide() -- Initially hidden


	-- Create the "Open FillRaid" button
	local openFillRaidButton = CreateFrame("Button", "OpenFillRaidButton", UIParent, "GameMenuButtonTemplate")
	openFillRaidButton:SetWidth(20)
	openFillRaidButton:SetHeight(180)

	local function SetVerticalText(button, text)
		local verticalText = ""
		for i = 1, string.len(text) do
			verticalText = verticalText .. string.sub(text, i, i) .. "\n"
		end
		button:SetText(verticalText)
	end

	SetVerticalText(openFillRaidButton, "FILL RAID")

	openFillRaidButton:SetScript("OnClick", function()
		if FillRaidFrame:IsShown() then
			FillRaidFrame:Hide()
			fillRaidFrameManualClose = true
		else
			FillRaidFrame:Show()
			fillRaidFrameManualClose = false
		end
	end)

	openFillRaidButton:Hide() -- Hide the button initially

	-- Create the "Kick All" button below OpenFillRaidButton
	local kickAllButton = CreateFrame("Button", "KickAllButton", UIParent, "GameMenuButtonTemplate")
	kickAllButton:SetWidth(20)
	kickAllButton:SetHeight(180)

	SetVerticalText(kickAllButton, "KICK ALL")

	kickAllButton:SetScript("OnClick", function()
		UninviteAllRaidMembers()  -- Call the function to uninvite all raid members
	end)

	kickAllButton:Hide() -- Hide the button initially

	-- Function to update the position of the openFillRaidButton and kickAllButton relative to PCPFrame
	local function UpdateButtonPosition()
		if PCPFrame and PCPFrame:IsVisible() then
			-- Position OpenFillRaidButton
			openFillRaidButton:ClearAllPoints()
			openFillRaidButton:SetPoint("RIGHT", PCPFrame, "LEFT", 0, 250)

			-- Position KickAllButton below OpenFillRaidButton
			kickAllButton:ClearAllPoints()
			kickAllButton:SetPoint("TOP", openFillRaidButton, "BOTTOM", 0, -10) -- Adjust position to be under OpenFillRaidButton
		end
	end

	-- Create a frame to periodically check the visibility of PCPFrame
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
		elseif PCPFrame and not PCPFrame:IsVisible() then
			openFillRaidButton:Hide()
			kickAllButton:Hide()
			FillRaidFrame:Hide()    
			fillRaidFrameManualClose = false
		else
			if openFillRaidButton:IsShown() and not fillRaidFrameManualClose then
				openFillRaidButton:Hide()
			end
			if kickAllButton:IsShown() then
				kickAllButton:Hide()
			end
		end
	end)
	visibilityFrame:Show()

end

-- Call the function to create the UI when the addon is loaded
CreateFillRaidUI()
InitializeSettings()


-- Table to keep track of the last time a message was shown
local messageCooldowns = {}

-- Function to check if the message should be shown based on cooldown
local function shouldShowMessage(message)
    local currentTime = GetTime() -- Get the current time
    for pattern, cooldown in pairs(messagesToHide) do
        if string.find(message, pattern) then
            -- If the message should always be hidden (cooldown == 0)
            if cooldown == 0 then
                return false -- Always hide this message
            end

            local lastShown = messageCooldowns[pattern] or 0
            if currentTime - lastShown >= cooldown then
                messageCooldowns[pattern] = currentTime -- Update the last shown time
                return true -- Allow the message to be shown
            else
                return false -- Hide the message
            end
        end
    end
    return true -- Allow all other messages
end

-- Hook the default chat frame's AddMessage function
local function HideBotMessages(self, message, r, g, b, id)
    -- Only hide messages if the setting is enabled
    if not FillRaidBotsSavedSettings.isBotMessagesEnabled then
        self:OriginalAddMessage(message, r, g, b, id)
        return
    end

    -- Proceed with the normal message filtering logic
    if not shouldShowMessage(message) then
        return -- Do nothing, effectively hiding the message
    end

    self:OriginalAddMessage(message, r, g, b, id)
end

-- Apply the hook to all chat frames
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


-- Create a slash command to trigger the function
SLASH_UNINVITE1 = "/uninviteraid"
SlashCmdList["UNINVITE"] = UninviteAllRaidMembers
