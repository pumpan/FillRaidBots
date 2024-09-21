local function FillRaidBots_OnEvent()
    if event == "ADDON_LOADED" then
        FillRaidBots_LoadSettings()
    elseif event == "PLAYER_LOGOUT" then
        FillRaidBots_SaveSettings()
    end
end

local settingsLoaded = false

-- Save settings function
function FillRaidBots_SaveSettings()
    if ToggleCheckAndRemoveCheckButton then
        FillRaidBotsSavedSettings.isCheckAndRemoveEnabled = ToggleCheckAndRemoveCheckButton:GetChecked() and true or false
    end
    if BotMessagesCheckButton then
        FillRaidBotsSavedSettings.isBotMessagesEnabled = BotMessagesCheckButton:GetChecked() and true or false
    end
    if DebugMessagesCheckButton then
        FillRaidBotsSavedSettings.debugMessagesEnabled = DebugMessagesCheckButton:GetChecked() and true or false
    end

end

-- Register the event handler
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGOUT")
frame:SetScript("OnEvent", FillRaidBots_OnEvent)

-- Create toggle check buttons
local function CreateToggleCheckButton()
    -- Create "Auto Remove Dead Bots" button
    local checkButton = CreateFrame("CheckButton", "ToggleCheckAndRemoveCheckButton", UISettingsFrame, "UICheckButtonTemplate")
    checkButton:SetWidth(30)
    checkButton:SetHeight(30)
    checkButton:SetPoint("TOPLEFT", UISettingsFrame, "TOPLEFT", 10, -10)

    -- Create a text label for the button
    checkButton.text = checkButton:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    checkButton.text:SetPoint("LEFT", checkButton, "RIGHT", 5, 0)
    checkButton.text:SetText("Auto Remove Dead Bots")

    checkButton:SetChecked(FillRaidBotsSavedSettings.isCheckAndRemoveEnabled)

    checkButton:SetScript("OnClick", function(self)
        FillRaidBotsSavedSettings.isCheckAndRemoveEnabled = checkButton:GetChecked()

        if FillRaidBotsSavedSettings.isCheckAndRemoveEnabled then
            checkButton.text:SetText("Disable CheckAndRemoveDeadBots")
        else
            checkButton.text:SetText("Enable CheckAndRemoveDeadBots")
        end
    end)

    checkButton:SetScript("OnEnter", function()
        GameTooltip:SetOwner(checkButton, "ANCHOR_RIGHT")
        GameTooltip:SetText("When enabled, dead bots will be automatically removed from the raid or party.")
        GameTooltip:Show()
    end)
    checkButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    -- Create "Bot Messages" button
    local botMessagesCheckButton = CreateFrame("CheckButton", "BotMessagesCheckButton", UISettingsFrame, "UICheckButtonTemplate")
    botMessagesCheckButton:SetWidth(30)
    botMessagesCheckButton:SetHeight(30)
    botMessagesCheckButton:SetPoint("TOPLEFT", UISettingsFrame, "TOPLEFT", 10, -50)

    botMessagesCheckButton.text = botMessagesCheckButton:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    botMessagesCheckButton.text:SetPoint("LEFT", botMessagesCheckButton, "RIGHT", 5, 0)
    botMessagesCheckButton.text:SetText("Suppress Messages")

    botMessagesCheckButton:SetChecked(FillRaidBotsSavedSettings.isBotMessagesEnabled)

    botMessagesCheckButton:SetScript("OnClick", function(self)
        FillRaidBotsSavedSettings.isBotMessagesEnabled = botMessagesCheckButton:GetChecked()
    end)

    botMessagesCheckButton:SetScript("OnEnter", function()
        GameTooltip:SetOwner(botMessagesCheckButton, "ANCHOR_RIGHT")
        GameTooltip:SetText("When enabled, bot messages will be suppressed.")
        GameTooltip:Show()
    end)
    botMessagesCheckButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    -- Create "Debug Messages" button
    local debugMessagesCheckButton = CreateFrame("CheckButton", "DebugMessagesCheckButton", UISettingsFrame, "UICheckButtonTemplate")
    debugMessagesCheckButton:SetWidth(30)
    debugMessagesCheckButton:SetHeight(30)
    debugMessagesCheckButton:SetPoint("TOPLEFT", UISettingsFrame, "TOPLEFT", 10, -90)

    debugMessagesCheckButton.text = debugMessagesCheckButton:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    debugMessagesCheckButton.text:SetPoint("LEFT", debugMessagesCheckButton, "RIGHT", 5, 0)
    debugMessagesCheckButton.text:SetText("Enable Debug")

    debugMessagesCheckButton:SetChecked(FillRaidBotsSavedSettings.debugMessagesEnabled)

    debugMessagesCheckButton:SetScript("OnClick", function(self)
        FillRaidBotsSavedSettings.debugMessagesEnabled = debugMessagesCheckButton:GetChecked()
    end)

    debugMessagesCheckButton:SetScript("OnEnter", function()
        GameTooltip:SetOwner(debugMessagesCheckButton, "ANCHOR_RIGHT")
        GameTooltip:SetText("When enabled, debug messages will be shown.")
        GameTooltip:Show()
    end)
    debugMessagesCheckButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end



-- Load settings function
function FillRaidBots_LoadSettings()
    if settingsLoaded then return end
    settingsLoaded = true
    
    if not FillRaidBotsSavedSettings then
        FillRaidBotsSavedSettings = {}
    end

    -- Ensure default values if they are nil
    if FillRaidBotsSavedSettings.isCheckAndRemoveEnabled == nil then
        FillRaidBotsSavedSettings.isCheckAndRemoveEnabled = true -- Default to enabled
        DEFAULT_CHAT_FRAME:AddMessage("Defaulting CheckAndRemove to enabled") -- Debug message
    else
        DEFAULT_CHAT_FRAME:AddMessage("CheckAndRemove loaded as: " .. tostring(FillRaidBotsSavedSettings.isCheckAndRemoveEnabled)) -- Debug message
    end

    if FillRaidBotsSavedSettings.isBotMessagesEnabled == nil then
        FillRaidBotsSavedSettings.isBotMessagesEnabled = true -- Default to enabled
    end
    if FillRaidBotsSavedSettings.debugMessagesEnabled == nil then
        FillRaidBotsSavedSettings.debugMessagesEnabled = false -- Default to disabled
    end

    -- Create the toggle check buttons
    CreateToggleCheckButton()

    -- Force the button's checked state based on loaded settings
    ToggleCheckAndRemoveCheckButton:SetChecked(FillRaidBotsSavedSettings.isCheckAndRemoveEnabled)
end
