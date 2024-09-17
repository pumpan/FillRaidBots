-- Event handler function for loading and saving settings
function FillRaidBots_OnEvent()
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

    -- Optionally, inform the user that settings are saved
    DEFAULT_CHAT_FRAME:AddMessage("FillRaidBots settings saved.")
end

-- Register the event handler
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGOUT")
frame:SetScript("OnEvent", FillRaidBots_OnEvent)

local function CreateToggleCheckButton()
    -- Check if the button already exists for "Auto Remove Dead Bots"
    if not _G["ToggleCheckAndRemoveCheckButton"] then
        -- Create the check button for "Auto Remove Dead Bots"
        local checkButton = CreateFrame("CheckButton", "ToggleCheckAndRemoveCheckButton", UISettingsFrame, "UICheckButtonTemplate")
        checkButton:SetWidth(30)
        checkButton:SetHeight(30)
        checkButton:SetPoint("TOPLEFT", UISettingsFrame, "TOPLEFT", 10, -10)
        checkButton.text = _G[checkButton:GetName() .. "Text"]
        checkButton.text:SetText("Auto Remove Dead Bots")

        -- Load the saved state and set the checkbox accordingly
        checkButton:SetChecked(FillRaidBotsSavedSettings.isCheckAndRemoveEnabled)

        -- Define what happens when the check button is clicked
        checkButton:SetScript("OnClick", function(self)
            FillRaidBotsSavedSettings.isCheckAndRemoveEnabled = checkButton:GetChecked()

            -- Update the text based on the new state
            if FillRaidBotsSavedSettings.isCheckAndRemoveEnabled then
                checkButton.text:SetText("Disable CheckAndRemoveDeadBots")
            else
                checkButton.text:SetText("Enable CheckAndRemoveDeadBots")
            end
        end)

        -- Tooltip handling for "Auto Remove Dead Bots"
        checkButton:SetScript("OnEnter", function()
            GameTooltip:SetOwner(checkButton, "ANCHOR_RIGHT")
            GameTooltip:SetText("When enabled, dead bots will be automatically removed from the raid or party.")
            GameTooltip:Show()
        end)
        checkButton:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
    end

    -- Check if the button already exists for "Bot Messages"
    if not _G["BotMessagesCheckButton"] then
        -- Create the check button for "Bot Messages"
        local botMessagesCheckButton = CreateFrame("CheckButton", "BotMessagesCheckButton", UISettingsFrame, "UICheckButtonTemplate")
        botMessagesCheckButton:SetWidth(30)
        botMessagesCheckButton:SetHeight(30)
        botMessagesCheckButton:SetPoint("TOPLEFT", UISettingsFrame, "TOPLEFT", 10, -50)
        botMessagesCheckButton.text = _G[botMessagesCheckButton:GetName() .. "Text"]
        botMessagesCheckButton.text:SetText("Suppress Messages")

        -- Load the saved state and set the checkbox accordingly
        botMessagesCheckButton:SetChecked(FillRaidBotsSavedSettings.isBotMessagesEnabled)

        -- Define what happens when the check button is clicked
        botMessagesCheckButton:SetScript("OnClick", function(self)
            FillRaidBotsSavedSettings.isBotMessagesEnabled = botMessagesCheckButton:GetChecked()

            -- You can update the text or take additional actions based on this setting
        end)

        -- Tooltip handling for "Bot Messages"
        botMessagesCheckButton:SetScript("OnEnter", function()
            GameTooltip:SetOwner(botMessagesCheckButton, "ANCHOR_RIGHT")
            GameTooltip:SetText("When enabled, bot messages will be suppressed.")
            GameTooltip:Show()
        end)
        botMessagesCheckButton:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
    end
end


-- Load settings function
function FillRaidBots_LoadSettings()
    if settingsLoaded then return end
    settingsLoaded = true
    
    if not FillRaidBotsSavedSettings then
        FillRaidBotsSavedSettings = {}
    end

    if FillRaidBotsSavedSettings.isCheckAndRemoveEnabled == nil then
        FillRaidBotsSavedSettings.isCheckAndRemoveEnabled = false
    end
    if FillRaidBotsSavedSettings.isBotMessagesEnabled == nil then
        FillRaidBotsSavedSettings.isBotMessagesEnabled = true -- Default to enabled
    end

    -- Create the toggle check buttons
    CreateToggleCheckButton()
end
