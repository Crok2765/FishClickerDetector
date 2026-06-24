-- FishClickerDetector 1.4 - Configurable para WoW 3.3.5a


local ADDON_NAME = "FishClickerDetector"
local SPELL_FISH_FEAST_CLICK = 57397
local SPELL_FISH_FEAST_CREATE = 57426
local FISH_FEAST_ITEM = 43015

local fishtrack = CreateFrame("Frame")
fishtrack:RegisterEvent("ADDON_LOADED")
fishtrack:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
fishtrack:RegisterEvent("ZONE_CHANGED")
fishtrack:RegisterEvent("ZONE_CHANGED_NEW_AREA")
fishtrack.num = {}
fishtrack.ui = {}

local defaults = {
    enabled = true,
    channel = "YELL",
    message = "{name} hizo click en {spell}. Clicks detectados: {count}",
}

local channels = {
    { text = "Gritar", detail = "/yell", value = "YELL" },
    { text = "Decir", detail = "/say", value = "SAY" },
    { text = "Grupo", detail = "/party", value = "PARTY" },
    { text = "Banda", detail = "/raid", value = "RAID" },
    { text = "Aviso de banda", detail = "/rw", value = "RAID_WARNING" },
    { text = "Hermandad", detail = "/guild", value = "GUILD" },
    { text = "Oficial", detail = "/officer", value = "OFFICER" },
    { text = "Emote", detail = "/emote", value = "EMOTE" },
}

local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00FishClickerDetector:|r " .. tostring(msg))
end

local function CopyDefaults()
    if type(FishClickerDetectorDB) ~= "table" then FishClickerDetectorDB = {} end
    for k, v in pairs(defaults) do
        if FishClickerDetectorDB[k] == nil then FishClickerDetectorDB[k] = v end
    end
end

local function GetConfig()
    CopyDefaults()
    return FishClickerDetectorDB
end

local function GetChannelIndex(channel)
    for i = 1, #channels do
        if channels[i].value == channel then return i end
    end
    return 1
end

local function GetChannelText(channel)
    local c = channels[GetChannelIndex(channel)]
    return c.text .. " |cff9d9d9d" .. c.detail .. "|r"
end

local function CanUseChannel(channel)
    if channel == "PARTY" and GetNumPartyMembers() == 0 then return false, "No estas en grupo." end
    if channel == "RAID" and GetNumRaidMembers() == 0 then return false, "No estas en banda." end
    if channel == "RAID_WARNING" and GetNumRaidMembers() == 0 then return false, "No estas en banda para usar Raid Warning." end
    if channel == "GUILD" and not IsInGuild() then return false, "No estas en hermandad." end
    if channel == "OFFICER" and not IsInGuild() then return false, "No estas en hermandad para usar Oficial." end
    return true
end

local function BuildMessage(playerName, count)
    local cfg = GetConfig()
    local spellLink = GetSpellLink(SPELL_FISH_FEAST_CLICK) or "Festin de pescado"
    local msg = cfg.message or defaults.message
    msg = string.gsub(msg, "{name}", playerName or "Desconocido")
    msg = string.gsub(msg, "{spell}", spellLink)
    msg = string.gsub(msg, "{count}", tostring(count or 0))
    return msg
end

local function SendConfiguredMessage(playerName, count)
    local cfg = GetConfig()
    if not cfg.enabled then return end
    local ok, reason = CanUseChannel(cfg.channel)
    if not ok then Print(reason .. " Mensaje no enviado."); return end
    SendChatMessage(BuildMessage(playerName, count), cfg.channel)
end

local function ResetCounter()
    table.wipe(fishtrack.num)
    local itemLink = select(2, GetItemInfo(FISH_FEAST_ITEM)) or "Festin de pescado"
    Print("El contador de clicks en " .. itemLink .. " se reinicio.")
end

local function CreatePanel(parent, w, h, point, rel, relPoint, x, y)
    local panel = CreateFrame("Frame", nil, parent)
    panel:SetWidth(w)
    panel:SetHeight(h)
    panel:SetPoint(point, rel, relPoint, x, y)
    panel:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 14,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    panel:SetBackdropColor(0.03, 0.025, 0.02, 0.94)
    panel:SetBackdropBorderColor(0.85, 0.62, 0.22, 0.85)
    return panel
end

local function CreateGoldButton(parent, text, w, h)
    local b = CreateFrame("Button", nil, parent)
    b:SetWidth(w or 110)
    b:SetHeight(h or 26)
    b:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    b:SetBackdropColor(0.12, 0.09, 0.045, 0.96)
    b:SetBackdropBorderColor(0.95, 0.68, 0.23, 0.9)
    b.text = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    b.text:SetPoint("CENTER")
    b.text:SetText(text)
    b:SetScript("OnEnter", function(self) self:SetBackdropColor(0.22, 0.15, 0.055, 1) end)
    b:SetScript("OnLeave", function(self) self:SetBackdropColor(0.12, 0.09, 0.045, 0.96) end)
    return b
end

local RefreshChannelDropdown

local function SaveFromUI()
    local ui = fishtrack.ui
    local cfg = GetConfig()
    if ui.editBox then
        local text = ui.editBox:GetText()
        if text and string.gsub(text, "%s", "") ~= "" then
            cfg.message = text
        else
            cfg.message = defaults.message
        end
    end
    if ui.enableCheck then cfg.enabled = ui.enableCheck:GetChecked() and true or false end
end

local function UpdateUI(forceText)
    local ui = fishtrack.ui
    local cfg = GetConfig()
    if ui.enableCheck then ui.enableCheck:SetChecked(cfg.enabled) end
    if ui.channelValue then ui.channelValue:SetText(GetChannelText(cfg.channel)) end
    if ui.dropdownText then ui.dropdownText:SetText(GetChannelText(cfg.channel)) end
    RefreshChannelDropdown()
    if ui.editBox and (forceText or not ui.editBox:HasFocus()) then
        ui.editBox:SetText(cfg.message or defaults.message)
        ui.editBox:SetCursorPosition(0)
    end
end

RefreshChannelDropdown = function()
    if fishtrack.ui.channelDrop then
        UIDropDownMenu_SetSelectedValue(fishtrack.ui.channelDrop, GetConfig().channel)
        UIDropDownMenu_SetText(fishtrack.ui.channelDrop, GetChannelText(GetConfig().channel))
    end
end

local function SetChannel(value)
    local cfg = GetConfig()
    cfg.channel = value
    RefreshChannelDropdown()
    CloseDropDownMenus()
    UpdateUI()
end

local function CreateChannelDropdown(parent)
    local drop = CreateFrame("Frame", "FishClickerDetectorChannelDropDown", parent, "UIDropDownMenuTemplate")
    UIDropDownMenu_SetWidth(drop, 185)
    UIDropDownMenu_Initialize(drop, function(self, level)
        local cfg = GetConfig()
        for i = 1, #channels do
            local info = UIDropDownMenu_CreateInfo()
            local value = channels[i].value
            info.text = channels[i].text .. "  |cff9d9d9d" .. channels[i].detail .. "|r"
            info.value = value
            info.checked = cfg.channel == value
            info.isNotRadio = false
            info.keepShownOnClick = false
            info.func = function()
                SetChannel(value)
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)
    UIDropDownMenu_SetSelectedValue(drop, GetConfig().channel)
    UIDropDownMenu_SetText(drop, GetChannelText(GetConfig().channel))
    return drop
end

local function CreateConfigFrame()
    if fishtrack.configFrame then return fishtrack.configFrame end

    local frame = CreateFrame("Frame", "FishClickerDetectorConfigFrame", UIParent)
    frame:SetWidth(610)
    frame:SetHeight(390)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 18,
        insets = { left = 5, right = 5, top = 5, bottom = 5 },
    })
    frame:SetBackdropColor(0.015, 0.012, 0.01, 0.98)
    frame:SetBackdropBorderColor(1, 0.72, 0.25, 1)
    frame:Hide()

    local header = CreateFrame("Frame", nil, frame)
    header:SetHeight(64)
    header:SetPoint("TOPLEFT", 8, -8)
    header:SetPoint("TOPRIGHT", -8, -8)
    header:SetBackdrop({ bgFile = "Interface\\ChatFrame\\ChatFrameBackground" })
    header:SetBackdropColor(0.10, 0.065, 0.025, 0.96)

    local iconBorder = CreatePanel(header, 46, 46, "LEFT", header, "LEFT", 14, 0)
    local icon = iconBorder:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("CENTER")
    icon:SetWidth(36)
    icon:SetHeight(36)
    icon:SetTexture("Interface\\Icons\\inv_misc_fish_52")

    local title = header:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", iconBorder, "TOPRIGHT", 14, -8)
    title:SetText("|cffffd36bFish Clicker Detector|r")

    local sub = header:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -5)
    sub:SetText("Configuracion de avisos para Festin de pescado")

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -6, -6)

    local statusPanel = CreatePanel(frame, 550, 72, "TOP", frame, "TOP", 0, -86)

    local enableCheck = CreateFrame("CheckButton", nil, statusPanel, "UICheckButtonTemplate")
    enableCheck:SetPoint("LEFT", 16, 0)
    enableCheck.text = enableCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    enableCheck.text:SetPoint("LEFT", enableCheck, "RIGHT", 2, 0)
    enableCheck.text:SetText("Activar mensajes automaticos")
    fishtrack.ui.enableCheck = enableCheck
    enableCheck:SetScript("OnClick", function(self)
        GetConfig().enabled = self:GetChecked() and true or false
        UpdateUI()
    end)

    local channelLabel = statusPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    channelLabel:SetPoint("LEFT", 300, 11)
    channelLabel:SetText("Canal de aviso")

    local drop = CreateChannelDropdown(statusPanel)
    drop:SetPoint("TOPLEFT", channelLabel, "BOTTOMLEFT", -18, 2)
    fishtrack.ui.channelDrop = drop

    local msgPanel = CreatePanel(frame, 550, 155, "TOP", statusPanel, "BOTTOM", 0, -12)

    local msgLabel = msgPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    msgLabel:SetPoint("TOPLEFT", 16, -14)
    msgLabel:SetText("Mensaje personalizado")

    local editBox = CreateFrame("EditBox", nil, msgPanel)
    editBox:SetWidth(510)
    editBox:SetHeight(78)
    editBox:SetPoint("TOPLEFT", 16, -38)
    editBox:SetAutoFocus(false)
    editBox:SetMultiLine(true)
    editBox:SetFontObject(ChatFontNormal)
    editBox:SetTextInsets(9, 9, 9, 9)
    editBox:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 13,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    editBox:SetBackdropColor(0, 0, 0, 0.88)
    editBox:SetBackdropBorderColor(0.55, 0.40, 0.16, 0.9)
    editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    editBox:SetScript("OnEditFocusLost", function() SaveFromUI() end)
    editBox:SetScript("OnTextChanged", function(self, userInput)
        if userInput then
            local cfg = GetConfig()
            local text = self:GetText()
            if text and string.gsub(text, "%s", "") ~= "" then
                cfg.message = text
            end
        end
    end)
    fishtrack.ui.editBox = editBox

    local help = msgPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    help:SetPoint("TOPLEFT", editBox, "BOTTOMLEFT", 2, -10)
    help:SetText("Variables: |cffffd36b{name}|r jugador  |  |cffffd36b{spell}|r festin  |  |cffffd36b{count}|r clicks")

    local previewPanel = CreatePanel(frame, 550, 44, "TOP", msgPanel, "BOTTOM", 0, -12)
    local previewLabel = previewPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    previewLabel:SetPoint("LEFT", 74, 0)
    previewLabel:SetText("Usa |cffffd36bProbar|r para ver el texto en tu chat sin mandarlo al canal.")

    local resetButton = CreateGoldButton(frame, "Reset", 62, 28)
    resetButton:SetPoint("BOTTOMLEFT", 40, 18)
    resetButton:SetScript("OnClick", function()
        if type(FishClickerDetectorDB) ~= "table" then FishClickerDetectorDB = {} end
        for k in pairs(FishClickerDetectorDB) do FishClickerDetectorDB[k] = nil end
        for k, v in pairs(defaults) do FishClickerDetectorDB[k] = v end
        if fishtrack.ui.editBox then fishtrack.ui.editBox:ClearFocus() end
        RefreshChannelDropdown()
        UpdateUI(true)
        Print("Configuracion restaurada al valor predeterminado.")
    end)

    local testButton = CreateGoldButton(frame, "Probar", 62, 28)
    testButton:SetPoint("BOTTOMRIGHT", -100, 18)
    testButton:SetScript("OnClick", function()
        SaveFromUI()
        local randomClicks = math.random(1, 20)
        DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00FishClickerDetector prueba:|r " .. BuildMessage(UnitName("player"), randomClicks))
    end)

    local saveButton = CreateGoldButton(frame, "Guardar", 62, 28)
    saveButton:SetPoint("LEFT", testButton, "RIGHT", 0, 0)
    saveButton:SetScript("OnClick", function()
        SaveFromUI()
        RefreshChannelDropdown()
        UpdateUI()
        Print("Configuracion guardada.")
    end)

    frame:SetScript("OnHide", function() SaveFromUI() end)

    fishtrack.configFrame = frame
    UpdateUI(true)
    return frame
end

local function ToggleConfig()
    local frame = CreateConfigFrame()
    if frame:IsShown() then
        SaveFromUI()
        frame:Hide()
    else
        UpdateUI(true)
        frame:Show()
    end
end

SLASH_FISHCLICKERDETECTOR1 = "/fcd"
SLASH_FISHCLICKERDETECTOR2 = "/fishclicker"
SlashCmdList["FISHCLICKERDETECTOR"] = function(msg)
    msg = string.lower(msg or "")
    if msg == "reset" then
        ResetCounter()
    elseif msg == "on" then
        GetConfig().enabled = true
        UpdateUI()
        Print("Mensajes activados.")
    elseif msg == "off" then
        GetConfig().enabled = false
        UpdateUI()
        Print("Mensajes desactivados.")
    else
        ToggleConfig()
    end
end

fishtrack:SetScript("OnEvent", function(self, event, ...)
    local arg = {...}

    if event == "ADDON_LOADED" then
        if arg[1] == ADDON_NAME then
            CopyDefaults()
            math.randomseed(time())
            Print("cargado. Usa /fcd para configurar.")
        end
        return
    end

    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        if arg[9] == SPELL_FISH_FEAST_CLICK and arg[2] == "SPELL_CAST_SUCCESS" then
            local name = arg[7]
            if name then
                self.num[name] = (self.num[name] or 1) + 1
                if self.num[name] > 4 then
                    SendConfiguredMessage(name, self.num[name] - 1)
                end
            end
        end

        if (arg[9] == SPELL_FISH_FEAST_CREATE and arg[2] == "SPELL_CREATE") or (arg[7] == UnitName("player") and arg[2] == "UNIT_DIED") then
            ResetCounter()
        end
        return
    end

    if event == "ZONE_CHANGED" or event == "ZONE_CHANGED_NEW_AREA" then
        local _, iT = IsInInstance()
        if iT == "raid" or iT == "party" then ResetCounter() end
    end
end)
