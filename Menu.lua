local _, ns = ...

local ROW_HEIGHT = 28
local SCROLL_WIDTH = 394
local SCROLL_HEIGHT = 394
local rows = {}
local missingRows = {}
local showingMissing = false
local selectAll, selectNone, viewButton

local frame = CreateFrame("Frame", "HearthfateMenu", UIParent, "BasicFrameTemplateWithInset")
frame:SetSize(440, 520)
frame:SetPoint("CENTER")
frame:SetFrameStrata("DIALOG")
frame:SetClampedToScreen(true)
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:Hide()

-- Title (the template's title field differs between game versions)
if frame.SetTitle then
    frame:SetTitle("Hearthfate")
elseif frame.TitleText then
    frame.TitleText:SetText("Hearthfate")
end

-- Drag the window by its body. It holds secure buttons, so it can't be moved in combat.
frame:SetScript("OnDragStart", function(self)
    if InCombatLockdown() then
        return
    end
    self:StartMoving()
end)
frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
end)

-- Close with Esc
tinsert(UISpecialFrames, "HearthfateMenu")

function ns.ToggleMenu()
    if InCombatLockdown() then
        ns.Print("can't open the toy menu in combat.")
        return
    end
    frame:SetShown(not frame:IsShown())
end

local cooldownFont = CreateFont("HearthfateMenuCooldownFont")
cooldownFont:SetFont(STANDARD_TEXT_FONT, 9, "OUTLINE")

local hint = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
hint:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -32)

-- Scroll area for the toy list
local scroll = CreateFrame("ScrollFrame", nil, frame)
scroll:SetSize(SCROLL_WIDTH, SCROLL_HEIGHT)
scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -60)
scroll:EnableMouseWheel(true)

local scrollChild = CreateFrame("Frame", nil, scroll)
scrollChild:SetSize(SCROLL_WIDTH, 1)
scroll:SetScrollChild(scrollChild)

-- Scrollbar: a thin gold thumb on a faint track
local scrollBar = CreateFrame("Slider", nil, frame)
scrollBar:SetOrientation("VERTICAL")
scrollBar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 6, 0)
scrollBar:SetSize(10, SCROLL_HEIGHT)
scrollBar:SetMinMaxValues(0, 0)
scrollBar:SetValueStep(1)
scrollBar:SetValue(0)

local track = scrollBar:CreateTexture(nil, "BACKGROUND")
track:SetAllPoints()
track:SetColorTexture(1, 1, 1, 0.08)

scrollBar:SetThumbTexture("Interface\\Buttons\\WHITE8X8")
local thumb = scrollBar:GetThumbTexture()
thumb:SetSize(10, 48)
thumb:SetVertexColor(1, 0.82, 0, 0.7)

scrollBar:SetScript("OnValueChanged", function(_, value)
    if not InCombatLockdown() then
        scroll:SetVerticalScroll(value)
    end
end)

scroll:SetScript("OnMouseWheel", function(_, delta)
    local minValue, maxValue = scrollBar:GetMinMaxValues()
    local value = scrollBar:GetValue() - delta * ROW_HEIGHT * 2
    scrollBar:SetValue(math.max(minValue, math.min(maxValue, value)))
end)

-- Sizes the scroll area for the number of rows shown.
local function UpdateScrollRange(count)
    local maxScroll = math.max(0, count * ROW_HEIGHT - SCROLL_HEIGHT)
    scrollChild:SetHeight(math.max(1, count * ROW_HEIGHT))
    scrollBar:SetMinMaxValues(0, maxScroll)
    scrollBar:SetShown(maxScroll > 0)
    if scrollBar:GetValue() > maxScroll then
        scrollBar:SetValue(maxScroll)
    end
end

local function UpdateStar(star)
    local on = ns.db.favorites[star.toyID]
    star.tex:SetDesaturated(not on)
    star.tex:SetAlpha(on and 1 or 0.35)
end

-- A row in the owned view: checkbox for the pool, and a button that uses the toy.
local function GetRow(index)
    local row = rows[index]
    if row then
        return row
    end

    row = CreateFrame("Frame", nil, scrollChild)
    row:SetSize(SCROLL_WIDTH, ROW_HEIGHT)
    row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -(index - 1) * ROW_HEIGHT)

    -- Checkbox: ticked means the toy is in the random pick.
    row.check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
    row.check:SetSize(24, 24)
    row.check:SetPoint("LEFT", row, "LEFT", 0, 0)
    row.check:SetScript("OnClick", function(self)
        ns.db.disabled[row.toyID] = (not self:GetChecked()) or nil
    end)

    -- Clicking the icon or the name uses the toy. The toy ID is set in Refresh.
    row.use = CreateFrame("Button", nil, row, "SecureActionButtonTemplate")
    row.use:SetSize(SCROLL_WIDTH - 28, 24)
    row.use:SetPoint("LEFT", row.check, "RIGHT", 4, 0)
    row.use:RegisterForClicks("AnyUp")
    row.use:SetAttribute("useOnKeyDown", false)
    row.use:SetAttribute("type", "toy")

    local highlight = row.use:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, 1, 1, 0.08)

    row.icon = row.use:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(22, 22)
    row.icon:SetPoint("LEFT", row.use, "LEFT", 0, 0)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    row.cooldown = CreateFrame("Cooldown", nil, row.use, "CooldownFrameTemplate")
    row.cooldown:SetAllPoints(row.icon)
    row.cooldown:SetCountdownFont("HearthfateMenuCooldownFont")

    row.label = row.use:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    row.label:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)

    row.count = row:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    row.count:SetPoint("RIGHT", row, "RIGHT", -8, 0)

    row.star = CreateFrame("Button", nil, row)
    row.star:SetSize(18, 18)
    row.star:SetPoint("RIGHT", row, "RIGHT", -44, 0)
    row.star:SetFrameLevel(row.use:GetFrameLevel() + 2)
    row.star.tex = row.star:CreateTexture(nil, "ARTWORK")
    row.star.tex:SetAllPoints()
    row.star.tex:SetAtlas("auctionhouse-icon-favorite")
    row.star:SetScript("OnClick", function(self)
        ns.db.favorites[self.toyID] = (not ns.db.favorites[self.toyID]) or nil
        UpdateStar(self)
    end)
    row.star:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Favourite", 1, 1, 1)
        GameTooltip:AddLine("Picked " .. ns.FAVOURITE_WEIGHT .. "x as often by the random button.", 0.7, 0.7, 0.7, true)
        GameTooltip:Show()
    end)
    row.star:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    row.use:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetToyByItemID(row.toyID)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Click: use this toy", 0.1, 1, 0.1)
        GameTooltip:Show()
    end)
    row.use:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    rows[index] = row
    return row
end

StaticPopupDialogs["HEARTHFATE_LINK"] = {
    text = "Press Ctrl+C to copy the Wowhead link, then Esc to close.",
    button1 = CLOSE,
    hasEditBox = true,
    editBoxWidth = 300,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
    OnShow = function(self, url)
        local editBox = self.GetEditBox and self:GetEditBox() or self.editBox or self.EditBox
        editBox:SetText(url or "")
        editBox:HighlightText()
        editBox:SetFocus()

        -- Close after Ctrl+C / Ctrl+X (Cmd on Mac). The short delay lets the copy finish first.
        editBox:SetScript("OnKeyDown", function(_, key)
            if (IsControlKeyDown() or IsMetaKeyDown()) and (key == "C" or key == "X") then
                C_Timer.After(0.1, function()
                    StaticPopup_Hide("HEARTHFATE_LINK")
                end)
            end
        end)
    end,
    EditBoxOnTextChanged = function(editBox, url)
        -- Keep the link intact if the player types in the box.
        if url and editBox:GetText() ~= url then
            editBox:SetText(url)
            editBox:HighlightText()
        end
    end,
    EditBoxOnEnterPressed = function(editBox)
        editBox:GetParent():Hide()
    end,
    EditBoxOnEscapePressed = function(editBox)
        editBox:GetParent():Hide()
    end,
}

-- A row in the unavailable view: greyed-out icon and name, with the source on mouseover.
local function GetMissingRow(index)
    local row = missingRows[index]
    if row then
        return row
    end

    row = CreateFrame("Button", nil, scrollChild)
    row:SetSize(SCROLL_WIDTH, ROW_HEIGHT)
    row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -(index - 1) * ROW_HEIGHT)
    row:SetHighlightTexture("Interface\\Buttons\\WHITE8X8")
    row:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.08)

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(22, 22)
    row.icon:SetPoint("LEFT", row, "LEFT", 4, 0)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.icon:SetDesaturated(true)

    row.label = row:CreateFontString(nil, "ARTWORK", "GameFontDisable")
    row.label:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)

    row:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetToyByItemID(self.toyID)
        GameTooltip:AddLine("Shift+click: copy Wowhead link", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)

    row:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    row:SetScript("OnClick", function(self)
        if IsShiftKeyDown() and self.toyID then
            StaticPopup_Show("HEARTHFATE_LINK", nil, nil, "https://www.wowhead.com/item=" .. self.toyID)
        end
    end)

    missingRows[index] = row
    return row
end

local function RefreshOwned(inCombat)
    hint:SetText("Tick a toy to add it to the random pick. Click a toy to use it.")

    local owned = ns.GetRandomizableToys()
    table.sort(owned, function(a, b)
        return a.name:lower() < b.name:lower()
    end)

    for i, toy in ipairs(owned) do
        local row = GetRow(i)
        row.toyID = toy.id
        row.check:SetChecked(not ns.db.disabled[toy.id])
        row.icon:SetTexture(toy.icon)
        row.label:SetText(toy.name)
        
        local count = ns.db.useCount[toy.id] or 0
        row.count:SetText(count > 0 and ("x" .. count) or "")
        
        row.star.toyID = toy.id
        UpdateStar(row.star)

        -- Colour the name by item quality, like an item tooltip does.
        local quality = C_Item.GetItemQualityByID(toy.id)
        if quality then
            local r, g, b = C_Item.GetItemQualityColor(quality)
            row.label:SetTextColor(r, g, b)
        else
            row.label:SetTextColor(1, 1, 1)
        end

        if not inCombat then
            row.use:SetAttribute("toy", toy.id)
            row:Show()
        end
    end

    if not inCombat then
        for i = #owned + 1, #rows do
            rows[i]:Hide()
        end
        for _, row in ipairs(missingRows) do
            row:Hide()
        end
        UpdateScrollRange(#owned)
    end
end

local function RefreshMissing()
    local missing = ns.GetMissingToys()
    table.sort(missing, function(a, b)
        return a.name:lower() < b.name:lower()
    end)

    if #missing == 0 then
        hint:SetText("You have every hearthstone toy on our list!")
    else
        hint:SetText(#missing .. " toys still to collect.")
    end

    for i, toy in ipairs(missing) do
        local row = GetMissingRow(i)
        row.toyID = toy.id
        row.icon:SetTexture(toy.icon)
        row.label:SetText(toy.name .. (toy.destination and " |cff999999(goes to its own location)|r" or ""))
        row:Show()
    end
    for i = #missing + 1, #missingRows do
        missingRows[i]:Hide()
    end
    for _, row in ipairs(rows) do
        row:Hide()
    end
    UpdateScrollRange(#missing)
end

local function Refresh()
    local inCombat = InCombatLockdown()

    selectAll:SetShown(not showingMissing)
    selectNone:SetShown(not showingMissing)
    viewButton:SetText(showingMissing and "See available" or "See unavailable")

    if showingMissing and not inCombat then
        RefreshMissing()
    else
        RefreshOwned(inCombat)
    end
end

selectAll = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
selectAll:SetSize(100, 22)
selectAll:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 16, 34)
selectAll:SetText("Select all")
selectAll:SetScript("OnClick", function()
    wipe(ns.db.disabled)
    Refresh()
end)

selectNone = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
selectNone:SetSize(100, 22)
selectNone:SetPoint("LEFT", selectAll, "RIGHT", 8, 0)
selectNone:SetText("Select none")
selectNone:SetScript("OnClick", function()
    for _, toy in ipairs(ns.GetRandomizableToys()) do
        ns.db.disabled[toy.id] = true
    end
    Refresh()
end)

viewButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
viewButton:SetSize(130, 22)
viewButton:SetPoint("LEFT", selectNone, "RIGHT", 8, 0)
viewButton:SetText("See unavailable")
viewButton:SetScript("OnClick", function()
    if InCombatLockdown() then
        ns.Print("can't switch views in combat.")
        return
    end
    showingMissing = not showingMissing
    scrollBar:SetValue(0)
    Refresh()
end)

frame:SetScript("OnShow", function()
    showingMissing = false
    scrollBar:SetValue(0)
    Refresh()
end)

-- Cooldown swirls on the owned toy icons. Only watched while the menu is open.
local function UpdateCooldowns()
    -- Cooldown data can be restricted in combat, and the list isn't useful then anyway.
    if InCombatLockdown() or not frame:IsShown() then
        return
    end

    for _, row in ipairs(rows) do
        if row:IsShown() and row.toyID then
            local start, duration = C_Item.GetItemCooldown(row.toyID)
            if start and duration and duration > 0 then
                row.cooldown:SetCooldown(start, duration)
            else
                row.cooldown:Clear()
            end
        end
    end
end

local cooldownWatcher = CreateFrame("Frame")
cooldownWatcher:SetScript("OnEvent", UpdateCooldowns)

frame:HookScript("OnShow", function()
    cooldownWatcher:RegisterEvent("SPELL_UPDATE_COOLDOWN")
    cooldownWatcher:RegisterEvent("BAG_UPDATE_COOLDOWN")
    cooldownWatcher:RegisterEvent("TOYS_UPDATED")
    cooldownWatcher:RegisterEvent("PLAYER_REGEN_ENABLED")
    UpdateCooldowns()
end)

frame:HookScript("OnHide", function()
    cooldownWatcher:UnregisterAllEvents()
end)