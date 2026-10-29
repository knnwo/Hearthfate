local _, ns = ...

local ICON_SIZE = 44
local SLOT_WIDTH = 76
local PADDING = 12
local BAR_HEIGHT = 124

local bar = CreateFrame("Frame", "HearthfateCloakBar", UIParent, "BackdropTemplate")
bar:SetFrameStrata("DIALOG")
bar:SetClampedToScreen(true)
bar:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
})
bar:Hide()

local title = bar:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
title:SetPoint("TOP", bar, "TOP", 0, -10)
title:SetText("Teleport cloaks")

local function FormatRemaining(seconds)
    if seconds >= 3600 then
        return string.format("%dh %dm", math.floor(seconds / 3600), math.floor((seconds % 3600) / 60))
    elseif seconds >= 60 then
        return string.format("%d:%02d", math.floor(seconds / 60), math.floor(seconds % 60))
    end
    return string.format("%ds", math.ceil(seconds))
end

local buttons = {}

-- Refreshes a button's border, cooldown swirl and status line. Skipped in combat,
-- when cooldown data can be restricted.
local function UpdateButton(b)
    if InCombatLockdown() or not b.itemID then
        return
    end

    local equipped = C_Item.IsEquippedItem(b.itemID)

    -- Border: gold when worn, otherwise the item's quality colour.
    if equipped then
        b:SetBackdropBorderColor(1, 0.82, 0, 1)
    else
        local r, g, bl = 0.6, 0.6, 0.6
        local quality = C_Item.GetItemQualityByID(b.itemID)
        if quality then
            r, g, bl = C_Item.GetItemQualityColor(quality)
        end
        b:SetBackdropBorderColor(r, g, bl, 1)
    end

    -- Cooldown swirl
    local remaining = 0
    local start, duration = C_Item.GetItemCooldown(b.itemID)
    if start and duration and duration > 3 then
        remaining = math.max(0, start + duration - GetTime())
    end
    if remaining > 0 then
        b.cooldown:SetCooldown(start, duration)
    else
        b.cooldown:Clear()
    end

    -- Status line
    if remaining > 0 then
        b.status:SetText(FormatRemaining(remaining))
        b.status:SetTextColor(1, 0.3, 0.3)
    elseif equipped then
        b.status:SetText("Worn")
        b.status:SetTextColor(1, 0.82, 0)
    else
        b.status:SetText("Ready")
        b.status:SetTextColor(0.3, 1, 0.3)
    end
end

local function GetButton(index)
    local b = buttons[index]
    if b then
        return b
    end

    -- Clicking equips the cloak if it's in a bag, or uses it (teleports) if it's worn.
    b = CreateFrame("Button", nil, bar, "SecureActionButtonTemplate, BackdropTemplate")
    b:SetSize(ICON_SIZE, ICON_SIZE)
    b:SetPoint("TOPLEFT", bar, "TOPLEFT", PADDING + (index - 1) * SLOT_WIDTH + (SLOT_WIDTH - ICON_SIZE) / 2, -28)
    b:RegisterForClicks("AnyUp")
    b:SetAttribute("useOnKeyDown", false)
    b:SetAttribute("type", "item")
    -- Remember the normal cloak just before it gets swapped for a teleport cloak.
    b:SetScript("PreClick", function(_, _, down)
        if down or InCombatLockdown() then
            return
        end
        ns.RememberCloak()
    end)
    b:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 2 })

    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetPoint("TOPLEFT", 2, -2)
    b.icon:SetPoint("BOTTOMRIGHT", -2, 2)
    b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")

    b.cooldown = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
    b.cooldown:SetAllPoints(b.icon)
    b.cooldown:SetHideCountdownNumbers(true) -- the status line shows the time instead

    b.name = b:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    b.name:SetPoint("TOP", b, "BOTTOM", 0, -4)
    b.name:SetWidth(SLOT_WIDTH - 6)
    b.name:SetHeight(26)
    b.name:SetJustifyH("CENTER")
    b.name:SetJustifyV("TOP")

    b.status = b:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    b.status:SetPoint("TOP", b, "BOTTOM", 0, -32)

    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetItemByID(self.itemID)
        GameTooltip:AddLine(" ")
        if C_Item.IsEquippedItem(self.itemID) then
            GameTooltip:AddLine("Click: teleport", 0.1, 1, 0.1)
        else
            GameTooltip:AddLine("Click: equip it. Click again to teleport.", 0.1, 1, 0.1)
        end
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    buttons[index] = b
    return b
end

-- Fills the bar with the cloaks the player has. Returns how many there are.
local function Rebuild()
    local owned = ns.GetOwnedCloaks()

    for i, cloak in ipairs(owned) do
        local b = GetButton(i)
        b.itemID = cloak.id
        b:SetAttribute("item", "item:" .. cloak.id)
        b.icon:SetTexture(cloak.icon)
        b.name:SetText(C_Item.GetItemNameByID(cloak.id) or cloak.name)
        b:Show()
        UpdateButton(b)
    end
    for i = #owned + 1, #buttons do
        buttons[i]:Hide()
    end

    bar:SetSize(PADDING * 2 + #owned * SLOT_WIDTH, BAR_HEIGHT)
    return #owned
end

function ns.ToggleCloakBar()
    if InCombatLockdown() then
        ns.Print("can't open the cloak bar in combat.")
        return
    end

    if bar:IsShown() then
        bar:Hide()
        return
    end

    if Rebuild() == 0 then
        ns.Print("you don't have any teleport cloaks in your bags. If you're in a guild, you can visit the guild vendor to buy one.")
        return
    end

    bar:ClearAllPoints()
    bar:SetPoint("BOTTOM", ns.button, "TOP", 0, 8)
    bar:Show()
end

local function UpdateAll()
    for _, b in ipairs(buttons) do
        if b:IsShown() then
            UpdateButton(b)
        end
    end
end

-- While the bar is open, refresh once a second so countdowns tick,
-- and right away when the worn cloak changes.
local ticker

local watcher = CreateFrame("Frame")
watcher:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_ENTERING_WORLD" then
        -- Teleporting loads a new area, so close the bar behind us.
        if bar:IsShown() and not InCombatLockdown() then
            bar:Hide()
        end
    elseif bar:IsShown() then
        UpdateAll()
    end
end)
watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
watcher:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")

bar:HookScript("OnShow", function()
    ticker = C_Timer.NewTicker(1, UpdateAll)
end)
bar:HookScript("OnHide", function()
    if ticker then
        ticker:Cancel()
        ticker = nil
    end
end)