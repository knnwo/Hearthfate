local _, ns = ...

local HEARTHSTONE_ITEM_ID = 6948
-- Item ID of the Personal Key to the Arcantina toy, used on right-click.
local ARCANTINA_TOY_ID = 253629 
local GARRISON_TOY_ID = 110560
local DALARAN_TOY_ID = 140192

-- Toys eligible for the random pick: every owned toy that goes to the bind location,
-- except the ones the player has turned off in the toy menu.
function ns.GetPool()
    local pool = {}

    for _, toy in ipairs(ns.GetRandomizableToys()) do
        if not ns.db.disabled[toy.id] then
            pool[#pool + 1] = toy
        end
    end

    return pool
end

local button = CreateFrame("Button", "HearthfateButton", UIParent, "SecureActionButtonTemplate")
ns.button = button

-- Always act on mouse/key release, regardless of the player's ActionButtonUseKeyDown setting.
button:RegisterForClicks("AnyUp")
button:SetAttribute("useOnKeyDown", false)
-- Right-click always uses the Arcantina key, so these are set once and never change.
button:SetAttribute("type2", "toy")
button:SetAttribute("toy2", ARCANTINA_TOY_ID)
-- Shift+click and Shift+right-click use fixed toys, set once like the right-click above.
button:SetAttribute("shift-type1", "toy")
button:SetAttribute("shift-toy1", GARRISON_TOY_ID)
button:SetAttribute("shift-type2", "toy")
button:SetAttribute("shift-toy2", DALARAN_TOY_ID)
-- Ctrl+click opens the cloak bar. This does nothing secure, so it doesn't use a toy.
button:SetAttribute("ctrl-type1", "noop")
-- Alt+click opens the toy menu. This does nothing secure, so it doesn't use a toy.
button:SetAttribute("alt-type1", "noop")

local lastToyID -- the toy used by the previous click, so we can avoid repeating it
local pendingToyID, pendingTime -- the toy picked by the last click, until its cast completes

-- Total uses and the most-used toy, for the tooltip.
function ns.GetUseStats()
    local total, bestID, bestCount = 0, nil, 0
    for id, count in pairs(ns.db.useCount) do
        total = total + count
        if count > bestCount then
            bestID, bestCount = id, count
        end
    end
    return total, bestID, bestCount
end

ns.FAVOURITE_WEIGHT = 3 -- how many times more likely a starred toy is; raise or lower to taste

-- Picks one toy from the list; starred toys count for more.
function ns.PickWeighted(list)
    local function weight(toy)
        return ns.db.favorites[toy.id] and ns.FAVOURITE_WEIGHT or 1
    end

    local total = 0
    for _, toy in ipairs(list) do
        total = total + weight(toy)
    end

    local roll = math.random() * total
    for _, toy in ipairs(list) do
        roll = roll - weight(toy)
        if roll <= 0 then
            return toy
        end
    end
    return list[#list]
end

-- Runs right before the secure action fires. Attributes can't change in combat,
-- but hearthstones can't be used in combat anyway.
button:SetScript("PreClick", function(self, mouseButton, down)
    if down or InCombatLockdown() then
        return
    end
    -- Ctrl+click opens the teleport cloak bar instead of using a toy.
    if mouseButton == "LeftButton" and IsControlKeyDown() then
        ns.ToggleCloakBar()
        return
    end
    -- Alt+click opens the toy menu instead of using a toy.
    if mouseButton == "LeftButton" and IsAltKeyDown() then
        ns.ToggleMenu()
        return
    end

    local shift = IsShiftKeyDown()

    -- Right-click, Shift+click and Shift+right-click use fixed toys (set up above),
    -- so there's no random pick for them.
    if mouseButton == "RightButton" then
        local toyID = shift and DALARAN_TOY_ID or ARCANTINA_TOY_ID
        if not PlayerHasToy(toyID) then
            ns.Print("you don't have the " .. (shift and "Dalaran Hearthstone" or "Personal Key to the Arcantina") .. " yet.")
        end
        return
    end

    if shift then
        if not PlayerHasToy(GARRISON_TOY_ID) then
            ns.Print("you don't have the Garrison Hearthstone yet.")
        end
        return
    end

    local pool = ns.GetPool()

    if #pool == 0 then
        -- Nothing to pick from: fall back to the regular Hearthstone item.
        self:SetAttribute("type", "item")
        self:SetAttribute("item", "item:" .. HEARTHSTONE_ITEM_ID)
        return
    end

    -- Hearthstone on cooldown: don't pick a toy or announce anything.
    -- The pool's toys share one cooldown, so any of them can be checked.
    local cdStart, cdDuration = C_Item.GetItemCooldown(pool[1].id)
    if cdStart and cdDuration and cdDuration > 0 then
        return
    end

    -- Avoid picking the same toy twice in a row (when there's more than one to choose from).
    local candidates = pool
    if #pool > 1 and lastToyID then
        candidates = {}
        for _, t in ipairs(pool) do
            if t.id ~= lastToyID then
                candidates[#candidates + 1] = t
            end
        end
    end

    local toy = ns.PickWeighted(candidates)
    lastToyID = toy.id
    pendingToyID, pendingTime = toy.id, GetTime()
    self:SetAttribute("type", "toy")
    self:SetAttribute("toy", toy.id)
    if ns.db.announce then
        ns.Print("using " .. toy.name)
    end
end)

-- Count a use only once the cast has completed successfully.
local castWatcher = CreateFrame("Frame")
castWatcher:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
castWatcher:SetScript("OnEvent", function(_, _, _, _, spellID)
    if not pendingToyID then
        return
    end

    -- A pick that never turned into a cast (for example, still on cooldown) expires.
    if GetTime() - pendingTime > 20 then
        pendingToyID = nil
        return
    end

    local _, toySpellID = C_Item.GetItemSpell(pendingToyID)
    if toySpellID and spellID == toySpellID then
        ns.db.useCount[pendingToyID] = (ns.db.useCount[pendingToyID] or 0) + 1
        pendingToyID = nil
    end
end)

-- Visuals
button:SetSize(48, 48)
button:SetClampedToScreen(true)
button:SetMovable(true)
button:RegisterForDrag("LeftButton")

button.icon = button:CreateTexture(nil, "BACKGROUND")
button.icon:SetAllPoints()
button.icon:SetTexture("Interface\\AddOns\\Hearthfate\\Icons\\EmberDice")

button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")

-- Shift+drag to move (unless locked). Protected frames can't be moved in combat.
button:SetScript("OnDragStart", function(self)
    if InCombatLockdown() or ns.db.locked or not IsShiftKeyDown() then
        return
    end
    self:StartMoving()
end)

button:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relativePoint, x, y = self:GetPoint()
    local pos = ns.db.position
    pos.point, pos.relativePoint, pos.x, pos.y = point, relativePoint, x, y
end)

-- Applies size and visibility from saved settings. Protected frames can't be
-- resized, shown or hidden in combat, so if we're in combat, wait until it ends.
local combatWatcher = CreateFrame("Frame")
combatWatcher:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    ns.ApplyButtonSettings()
end)

local ICON_PATH = "Interface\\AddOns\\Hearthfate\\Icons\\"

ns.iconStyles = {
    { key = "emberdice",   name = "Ember dice",   texture = ICON_PATH .. "EmberDice" },
    { key = "emberswirl",  name = "Ember swirl",  texture = ICON_PATH .. "EmberSwirl" },
    { key = "arcanedice",  name = "Arcane dice",  texture = ICON_PATH .. "ArcaneDice" },
    { key = "arcaneswirl", name = "Arcane swirl", texture = ICON_PATH .. "ArcaneSwirl" },
}

function ns.ApplyIcon()
    local texture = ns.iconStyles[1].texture
    for _, style in ipairs(ns.iconStyles) do
        if style.key == ns.db.iconStyle then
            texture = style.texture
            break
        end
    end
    button.icon:SetTexture(texture)
end

local FADED_ALPHA = 0.3 -- how see-through the button is when not hovered; raise for more visible

function ns.ApplyFade()
    if ns.db.fadeIdle and not button:IsMouseOver() then
        button:SetAlpha(FADED_ALPHA)
    else
        button:SetAlpha(1)
    end
end

-- Checks the mouse position instead of relying on the OnEnter/OnLeave scripts,
-- so it can't be affected by how the tooltip scripts are set up.
local fadeWatcher = CreateFrame("Frame")
local sinceCheck = 0
fadeWatcher:SetScript("OnUpdate", function(_, elapsed)
    sinceCheck = sinceCheck + elapsed
    if sinceCheck < 0.05 then
        return
    end
    sinceCheck = 0

    if ns.db and ns.db.fadeIdle then
        button:SetAlpha((button:IsMouseOver() or GetTime() < (ns.cueUntil or 0)) and 1 or FADED_ALPHA)
    end
end)

function ns.ApplyButtonSettings()
    ns.ApplyIcon()
    ns.ApplyFade()
    if InCombatLockdown() then
        combatWatcher:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end

    local size = ns.db.buttonSize
    button:SetSize(size, size)
    button:SetShown(ns.db.showButton)
    ns.UpdateCooldownFont()
end

-- Called from Core.lua once saved settings are loaded.
function ns.InitButton()
    local pos = ns.db.position
    button:ClearAllPoints()
    button:SetPoint(pos.point, UIParent, pos.relativePoint, pos.x, pos.y)
    ns.ApplyButtonSettings()
end

-- Cooldown swirl
button.cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
button.cooldown:SetAllPoints()

-- Charge count text. It lives on its own frame so it draws above the cooldown swirl.
local overlay = CreateFrame("Frame", nil, button)
overlay:SetAllPoints()
overlay:SetFrameLevel(button.cooldown:GetFrameLevel() + 2)

button.charges = overlay:CreateFontString(nil, "OVERLAY")
button.charges:SetFont(STANDARD_TEXT_FONT, 14, "OUTLINE")
button.charges:SetPoint("BOTTOMRIGHT", overlay, "BOTTOMRIGHT", -3, 3)
button.charges:Hide()

-- Most hearthstone toys share one cooldown with the regular Hearthstone,
-- so we read it from one reference item. Destination toys (Garrison, Dalaran)
-- have their own cooldowns, so they're skipped as a reference.
local function GetReferenceItemID()
    for _, toy in ipairs(ns.GetOwnedToys()) do
        if not toy.destination then
            return toy.id
        end
    end
    return HEARTHSTONE_ITEM_ID
end

local HEARTHSTONE_SPELL_ID = 8690

-- Re-checks the cooldown once a short cooldown (like the global cooldown) has ended,
-- so the recharge display comes back without waiting for another game event.
local function RefreshAfter(start, duration)
    local delay = (start + duration) - GetTime() + 0.1
    if delay > 0 then
        C_Timer.After(delay, ns.UpdateCooldown)
    end
end

local wasOnLongCooldown = false -- true while the real hearthstone cooldown (not the global one) is running

function ns.UpdateCooldown()
    -- Skip in combat: cooldown data can be restricted there, and a swirl
    -- that was already running keeps animating on its own.
    if InCombatLockdown() then
        return
    end

    local itemStart, itemDuration = C_Item.GetItemCooldown(GetReferenceItemID())
    local onItemCooldown = itemStart and itemDuration and itemDuration > 0

    -- Characters with extra hearthstone charges (e.g. humans) report them on the spell.
    local charges = C_Spell.GetSpellCharges(HEARTHSTONE_SPELL_ID)
    local hasCharges = charges and charges.maxCharges and charges.maxCharges > 1

    if hasCharges then
        button.charges:SetText(tostring(charges.currentCharges))
        button.charges:Show()
    else
        button.charges:Hide()
    end

    if onItemCooldown then
        -- The global cooldown, or the full cooldown with no charges left.
        button.cooldown:SetDrawSwipe(true)
        button.cooldown:SetDrawEdge(false)
        button.cooldown:SetCooldown(itemStart, itemDuration)
        RefreshAfter(itemStart, itemDuration)
    elseif hasCharges and charges.currentCharges < charges.maxCharges then
        -- A charge is recharging but one is still available: thin edge only.
        button.cooldown:SetDrawSwipe(false)
        button.cooldown:SetDrawEdge(true)
        button.cooldown:SetCooldown(charges.cooldownStartTime, charges.cooldownDuration)
    else
        button.cooldown:Clear()
    end
    -- Cooldown just finished: the hearthstone is ready again.
    local onLongCooldown = onItemCooldown and itemDuration > 3
    if wasOnLongCooldown and not onItemCooldown then
        ns.PlayReadyCue()
    end
    wasOnLongCooldown = onLongCooldown
end

local cooldownWatcher = CreateFrame("Frame")
cooldownWatcher:RegisterEvent("PLAYER_ENTERING_WORLD")
cooldownWatcher:RegisterEvent("SPELL_UPDATE_COOLDOWN")
cooldownWatcher:RegisterEvent("BAG_UPDATE_COOLDOWN")
cooldownWatcher:RegisterEvent("PLAYER_REGEN_ENABLED")
cooldownWatcher:RegisterEvent("TOYS_UPDATED")
cooldownWatcher:RegisterEvent("SPELL_UPDATE_CHARGES")
cooldownWatcher:SetScript("OnEvent", function()
    ns.UpdateCooldown()
end)

-- Cooldown text font, rescaled with the button size
local cooldownFont = CreateFont("HearthfateCooldownFont")
cooldownFont:SetFont(STANDARD_TEXT_FONT, 14, "OUTLINE")
button.cooldown:SetCountdownFont("HearthfateCooldownFont")

function ns.UpdateCooldownFont()
    -- 0.3 is the text size as a fraction of the button size; raise or lower to taste.
    local size = math.max(8, math.floor(ns.db.buttonSize * 0.33))
    cooldownFont:SetFont(STANDARD_TEXT_FONT, size, "OUTLINE")
    button.cooldown:SetCountdownFont("HearthfateCooldownFont")
    button.charges:SetFont(STANDARD_TEXT_FONT, math.max(6, math.floor(size * 0.8)), "OUTLINE")
end

-- Tooltips
local function FormatRemaining(seconds)
    if seconds >= 3600 then
        return string.format("%dh %dm", math.floor(seconds / 3600), math.floor((seconds % 3600) / 60))
    elseif seconds >= 60 then
        return string.format("%d:%02d", math.floor(seconds / 60), math.floor(seconds % 60))
    end
    return string.format("%ds", math.ceil(seconds))
end

-- Seconds left on an item's cooldown, 0 if ready, nil if it can't be read (in combat).
local function GetRemaining(itemID)
    if InCombatLockdown() then
        return nil
    end
    local start, duration = C_Item.GetItemCooldown(itemID)
    if start and duration and duration > 3 then -- ignore the short global cooldown
        local remaining = start + duration - GetTime()
        if remaining > 0 then
            return remaining
        end
    end
    return 0
end

-- One entry for the Shift tooltip: toy name, its cooldown, and which click uses it.
-- One entry for the Shift tooltip: toy name, its cooldown, and which click uses it.
local function AddToyEntry(itemID, clickHint)
    if not PlayerHasToy(itemID) then
        return
    end

    local _, name, icon = C_ToyBox.GetToyInfo(itemID)

    -- Colour the toy name by its item quality, like an item tooltip does.
    local r, g, b = 1, 1, 1
    local quality = C_Item.GetItemQualityByID(itemID)
    if quality then
        r, g, b = C_Item.GetItemQualityColor(quality)
    else
        C_Item.RequestLoadItemDataByID(itemID) -- the next redraw will pick the colour up
    end

    local left = string.format("|T%s:20|t  %s", tostring(icon), name or ("Toy " .. itemID))

    local remaining = GetRemaining(itemID)
    if remaining == nil then
        GameTooltip:AddLine(left, r, g, b)
    elseif remaining > 0 then
        GameTooltip:AddDoubleLine(left, FormatRemaining(remaining), r, g, b, 1, 0.3, 0.3)
    else
        GameTooltip:AddDoubleLine(left, "Ready", r, g, b, 0.3, 1, 0.3)
    end

    GameTooltip:AddLine("      <" .. clickHint .. ">", 0.1, 1, 0.1)
end

local function ShowTooltip()
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")

    if IsShiftKeyDown() then
        GameTooltip:SetText("Hearthfate", 1, 0.82, 0)
        GameTooltip:AddLine("Travel shortcuts", 0.7, 0.7, 0.7)
        GameTooltip:AddLine(" ")
        AddToyEntry(ARCANTINA_TOY_ID, "Right-click")
        AddToyEntry(GARRISON_TOY_ID, "Shift+click")
        AddToyEntry(DALARAN_TOY_ID, "Shift+right-click")
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("\"Fate favours the well-travelled.\"", 1, 0.82, 0, true)
    else
        GameTooltip:SetItemByID(HEARTHSTONE_ITEM_ID)
        GameTooltip:AddLine(" ")

        -- Cooldown shared by the hearthstone toys
        local remaining = GetRemaining(GetReferenceItemID())
        if remaining and remaining > 0 then
            GameTooltip:AddDoubleLine("Hearthstone", FormatRemaining(remaining), 1, 1, 1, 1, 0.3, 0.3)
        elseif remaining == 0 then
            GameTooltip:AddDoubleLine("Hearthstone", "Ready", 1, 1, 1, 0.3, 1, 0.3)
        end

        -- Extra charges (e.g. humans)
        local charges = not InCombatLockdown() and C_Spell.GetSpellCharges(HEARTHSTONE_SPELL_ID)
        if charges and charges.maxCharges and charges.maxCharges > 1 then
            GameTooltip:AddDoubleLine("Charges", charges.currentCharges .. "/" .. charges.maxCharges, 1, 1, 1, 1, 1, 1)
        end

        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine("Click", "Random toy", 1, 0.82, 0, 1, 1, 1)
        GameTooltip:AddDoubleLine("Shift", "Travel shortcuts", 1, 0.82, 0, 1, 1, 1)
        GameTooltip:AddDoubleLine("Ctrl+click", "Teleport cloaks", 1, 0.82, 0, 1, 1, 1)
        GameTooltip:AddDoubleLine("Alt+click", "Toy menu", 1, 0.82, 0, 1, 1, 1)
        if not ns.db.locked then
            GameTooltip:AddDoubleLine("Shift+drag", "Move", 1, 0.82, 0, 1, 1, 1)
        end
    end

    GameTooltip:Show()
end

-- While the mouse is over the button, redraw once a second so cooldowns count down,
-- and immediately when Shift is pressed or released.
local tooltipTicker

button:SetScript("OnEnter", function()
    ShowTooltip()
    tooltipTicker = C_Timer.NewTicker(1, ShowTooltip)
end)

button:SetScript("OnLeave", function()
    if tooltipTicker then
        tooltipTicker:Cancel()
        tooltipTicker = nil
    end
    GameTooltip:Hide()
end)

local modifierWatcher = CreateFrame("Frame")
modifierWatcher:RegisterEvent("MODIFIER_STATE_CHANGED")
modifierWatcher:SetScript("OnEvent", function()
    if tooltipTicker then
        ShowTooltip()
    end
end)

-- Ready cue: a short golden pulse around the button.
local readyGlow = overlay:CreateTexture(nil, "OVERLAY")
readyGlow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
readyGlow:SetBlendMode("ADD")
readyGlow:SetPoint("CENTER", button, "CENTER")
readyGlow:Hide()

local readyAnim = readyGlow:CreateAnimationGroup()
local function AddPulse(order, from, to, duration)
    local a = readyAnim:CreateAnimation("Alpha")
    a:SetFromAlpha(from)
    a:SetToAlpha(to)
    a:SetDuration(duration)
    a:SetOrder(order)
end
AddPulse(1, 0, 1, 0.25)
AddPulse(2, 1, 0.2, 0.35)
AddPulse(3, 0.2, 1, 0.25)
AddPulse(4, 1, 0, 0.7)
readyAnim:SetScript("OnFinished", function()
    readyGlow:Hide()
end)

function ns.PlayReadyCue()
    if not ns.db.readyCue then
        return
    end
    ns.cueUntil = GetTime() + 3 -- keeps a faded button fully visible while the cue plays
    local size = button:GetWidth() * 1.9
    readyGlow:SetSize(size, size)
    readyGlow:Show()
    readyAnim:Stop()
    readyAnim:Play()
end