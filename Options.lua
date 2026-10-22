local _, ns = ...

local ACCOUNT_MACRO_LIMIT = 120
local MACRO_NAME = "Hearthfate"
local MACRO_BODY = "/click HearthfateButton"
local MACRO_ICON = 134414 -- hearthstone icon

local panel = CreateFrame("Frame")
panel.name = "Hearthfate"

local announceCheck, autoCloakCheck, showCheck, lockCheck, sizeSlider

-- Section heading with a thin divider line under it.
local function CreateSection(text, y)
    local header = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    header:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, y)
    header:SetText(text)

    local line = panel:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(1, 1, 1, 0.15)
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, y - 22)
    line:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -16, y - 22)
end

-- Checkbox with a text label to its right.
local function CreateCheckbox(label, x, y, onClick)
    local check = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    check:SetSize(24, 24)
    check:SetPoint("TOPLEFT", panel, "TOPLEFT", x, y)
    check:SetScript("OnClick", function(self)
        onClick(self:GetChecked() and true or false)
    end)

    local text = check:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    text:SetPoint("LEFT", check, "RIGHT", 2, 0)
    text:SetText(label)

    return check
end

-- Title and shortcut hint
local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalHuge")
title:SetPoint("TOPLEFT", 16, -16)
title:SetText("Hearthfate")

local hint = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
hint:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
hint:SetText("Click: random toy  |  Right-click: Arcantina key  |  Shift+click: Garrison  |  Shift+right-click: Dalaran")

local function Refresh()
    announceCheck:SetChecked(ns.db.announce)
    autoCloakCheck:SetChecked(ns.db.autoRestoreCloak)
    showCheck:SetChecked(ns.db.showButton)
    lockCheck:SetChecked(ns.db.locked)
    sizeSlider:SetValue(ns.db.buttonSize)
end

-- Section: On-screen button
CreateSection("On-screen button", -72)

showCheck = CreateCheckbox("Show on-screen button", 16, -104, function(checked)
    ns.db.showButton = checked
    ns.ApplyButtonSettings()
end)

lockCheck = CreateCheckbox("Lock position", 220, -104, function(checked)
    ns.db.locked = checked
end)

sizeSlider = CreateFrame("Slider", nil, panel, "OptionsSliderTemplate")
sizeSlider:SetPoint("TOPLEFT", panel, "TOPLEFT", 24, -156)
sizeSlider:SetWidth(220)
sizeSlider:SetMinMaxValues(32, 96)
sizeSlider:SetValueStep(4)
sizeSlider:SetObeyStepOnDrag(true)
sizeSlider.Low:SetText("32")
sizeSlider.High:SetText("96")
sizeSlider:SetScript("OnValueChanged", function(self, value)
    value = math.floor(value + 0.5)
    ns.db.buttonSize = value
    self.Text:SetText("Button size: " .. value)
    ns.ApplyButtonSettings()
end)

-- Section: Behaviour
CreateSection("Behaviour", -186)

announceCheck = CreateCheckbox("Announce chosen toy in chat", 16, -218, function(checked)
    ns.db.announce = checked
end)

autoCloakCheck = CreateCheckbox("Put my normal cloak back after teleporting", 16, -246, function(checked)
    ns.db.autoRestoreCloak = checked
    ns.UpdateRestoreButton()
end)

-- Section: Macro
CreateSection("Macro", -284)

StaticPopupDialogs["HEARTHFATE_MACROS_FULL"] = {
    text = "Hearthfate: your account-wide macro slots are full, so the macro couldn't be created.\n\nDelete an unused macro (type /macro) and click the button again.",
    button1 = OKAY,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

local macroButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
macroButton:SetSize(150, 22)
macroButton:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -316)
macroButton:SetText("Create macro")
local macroIcon = macroButton:CreateTexture(nil, "ARTWORK")
macroIcon:SetSize(18, 18)
macroIcon:SetPoint("LEFT", macroButton, "LEFT", 6, 0)
macroIcon:SetTexture("Interface\\AddOns\\Hearthfate\\Icons\\EmberDice")
StaticPopupDialogs["HEARTHFATE_MACRO_EXISTS"] = {
    text = "Hearthfate: you already have a Hearthfate macro, so a new one wasn't created.\n\nType /macro to find it and drag it to an action bar.",
    button1 = OKAY,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

macroButton:SetScript("OnClick", function()
    if InCombatLockdown() then
        ns.Print("can't create macros in combat.")
        return
    end

    -- Already there: don't create or pick up anything, just tell the player.
    if GetMacroIndexByName(MACRO_NAME) ~= 0 then
        StaticPopup_Show("HEARTHFATE_MACRO_EXISTS")
        return
    end

    if GetNumMacros() >= ACCOUNT_MACRO_LIMIT then
        StaticPopup_Show("HEARTHFATE_MACROS_FULL")
        return
    end

    local index = CreateMacro(MACRO_NAME, MACRO_ICON, MACRO_BODY, false)
    if not index then
        StaticPopup_Show("HEARTHFATE_MACROS_FULL")
        return
    end

    PickupMacro(index)
    ns.Print("macro is on your cursor. Close this window (Esc) and click an action bar slot to drop it.")
end)

local macroHint = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
macroHint:SetPoint("LEFT", macroButton, "RIGHT", 12, 0)
macroHint:SetWidth(400)
macroHint:SetJustifyH("LEFT")
macroHint:SetText("Makes an account-wide macro to drop on an action bar. Or write your own: /click HearthfateButton")

-- Section: Toys
CreateSection("Hearthstone toys", -356)

local openMenu = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
openMenu:SetSize(150, 22)
openMenu:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -388)
openMenu:SetText("Open HS Toy Menu")
openMenu:SetScript("OnClick", function()
    if InCombatLockdown() then
        ns.Print("can't open the toy menu in combat.")
        return
    end
    -- Close the settings window first, or the menu would open behind it.
    HideUIPanel(SettingsPanel)
    ns.ToggleMenu()
end)

local menuHint = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
menuHint:SetPoint("LEFT", openMenu, "RIGHT", 12, 0)
menuHint:SetWidth(400)
menuHint:SetJustifyH("LEFT")
menuHint:SetText("Choose which hearthstone toys are in the random pick.")

local iconLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
iconLabel:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -176, -104)
iconLabel:SetText("Button icon")

local iconDropdown = CreateFrame("DropdownButton", nil, panel, "WowStyle1DropdownTemplate")
iconDropdown:SetWidth(150)
iconDropdown:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -16, -100)
iconDropdown:SetupMenu(function(_, root)
    for _, style in ipairs(ns.iconStyles) do
        root:CreateRadio(style.name,
            function() return ns.db.iconStyle == style.key end,
            function()
                ns.db.iconStyle = style.key
                ns.ApplyIcon()
            end)
    end
end)

local fadeCheck = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
fadeCheck:SetSize(24, 24)
fadeCheck:SetPoint("TOPRIGHT", iconDropdown, "BOTTOMRIGHT", 4, -2)
fadeCheck:SetScript("OnShow", function(self)
    self:SetChecked(ns.db.fadeIdle)
end)
fadeCheck:SetScript("OnClick", function(self)
    ns.db.fadeIdle = self:GetChecked() and true or false
    ns.ApplyFade()
end)

local cueCheck = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
cueCheck:SetSize(24, 24)
cueCheck:SetPoint("TOPRIGHT", fadeCheck, "BOTTOMRIGHT", 0, 2)
cueCheck:SetScript("OnShow", function(self)
    self:SetChecked(ns.db.readyCue)
end)
cueCheck:SetScript("OnClick", function(self)
    ns.db.readyCue = self:GetChecked() and true or false
end)

local cueLabel = cueCheck:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
cueLabel:SetPoint("RIGHT", cueCheck, "LEFT", -2, 0)
cueLabel:SetText("Flash button when hearthstone is ready")

local fadeLabel = fadeCheck:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
fadeLabel:SetPoint("RIGHT", fadeCheck, "LEFT", -2, 0)
fadeLabel:SetText("Fade button when not hovered")

panel:SetScript("OnShow", Refresh)

local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
Settings.RegisterAddOnCategory(category)
ns.settingsCategory = category