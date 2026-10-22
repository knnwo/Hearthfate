local _, ns = ...

-- Guild and crafting teleport cloaks. Each has an Alliance and a Horde version,
-- each with its own item ID: ids = { alliance, horde }.
-- Confirmed in game (Alliance): 65360, 63206, 63352. The Horde IDs for the Wrap of Unity
-- and the Shroud of Cooperation (63207, 63353) are unverified.
ns.cloakData = {
    { name = "Cloak of Coordination", ids = { 65360, 65274 } },
    { name = "Wrap of Unity", ids = { 63206, 63207 } },
    { name = "Shroud of Cooperation", ids = { 63352, 63353 } },
}

-- Set of every teleport cloak item ID, for quick lookups.
local cloakIDs = {}
for _, data in ipairs(ns.cloakData) do
    for _, id in ipairs(data.ids) do
        cloakIDs[id] = true
    end
end

function ns.IsTeleportCloak(itemID)
    return itemID ~= nil and cloakIDs[itemID] == true
end

-- Teleport cloaks the player has in their bags or is wearing.
function ns.GetOwnedCloaks()
    local owned = {}
    local backItem = GetInventoryItemID("player", 15)

    for _, data in ipairs(ns.cloakData) do
        for _, id in ipairs(data.ids) do
            if backItem == id or C_Item.GetItemCount(id) > 0 then
                owned[#owned + 1] = { id = id, name = data.name, icon = C_Item.GetItemIconByID(id) }
            end
        end
    end

    return owned
end

-- TEMPORARY diagnostic: print teleport cloaks found in your bags and on your back slot,
-- with their item IDs, so we can confirm the IDs for your faction.
function ns.ScanCloaksByName()
    local names = {}
    for _, data in ipairs(ns.cloakData) do
        names[data.name] = true
    end

    local found = 0
    local function Check(itemID, where)
        if not itemID then
            return
        end
        local name = C_Item.GetItemNameByID(itemID)
        if name and names[name] then
            found = found + 1
            ns.Print(string.format("%s: %d %s", where, itemID, name))
        end
    end

    Check(GetInventoryItemID("player", 15), "equipped")
    for bag = 0, 5 do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info then
                Check(info.itemID, "bag " .. bag)
            end
        end
    end

    if found == 0 then
        ns.Print("no teleport cloaks found in your bags or on your back slot.")
    end
end

-- Putting the normal cloak back after a teleport
local BACK_SLOT = 15

-- Called just before a cloak on the bar is clicked: remember the normal cloak that's about
-- to be swapped out. If a teleport cloak is already worn, the saved one is still the real one.
function ns.RememberCloak()
    if ns.IsTeleportCloak(GetInventoryItemID("player", BACK_SLOT)) then
        return
    end
    ns.db.savedCloaks[UnitGUID("player")] = GetInventoryItemLink("player", BACK_SLOT)
end

-- Equips the saved normal cloak. Gear can't be swapped in combat.
local function RestoreNow(fromButton)
    local guid = UnitGUID("player")
    local link = ns.db.savedCloaks[guid]
    if not link then
        return
    end

    -- Not wearing a teleport cloak any more, so there's nothing to swap back.
    if not ns.IsTeleportCloak(GetInventoryItemID("player", BACK_SLOT)) then
        ns.db.savedCloaks[guid] = nil
        return
    end

    if InCombatLockdown() then
        if fromButton then
            ns.Print("can't change gear in combat.")
        end
        return
    end

    C_Item.EquipItemByName(link)
    ns.Print("putting your " .. link .. " back on.")
end

-- Fallback button, shown under the main button when automatic restoring is switched off.
local restoreButton = CreateFrame("Button", "HearthfateRestoreCloakButton", UIParent)
restoreButton:SetSize(36, 36)
restoreButton:SetFrameStrata("HIGH")
restoreButton:Hide()

restoreButton.icon = restoreButton:CreateTexture(nil, "ARTWORK")
restoreButton.icon:SetAllPoints()
restoreButton.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
restoreButton:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")

restoreButton:SetScript("OnClick", function()
    RestoreNow(true)
end)
restoreButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Restore your cloak", 1, 0.82, 0)
    GameTooltip:AddLine(self.link or "", 1, 1, 1)
    GameTooltip:AddLine("Click: put it back on", 0.1, 1, 0.1)
    GameTooltip:Show()
end)
restoreButton:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

function ns.UpdateRestoreButton()
    if not ns.db then
        return
    end

    local link = ns.db.savedCloaks[UnitGUID("player")]
    local show = link
        and not ns.db.autoRestoreCloak
        and ns.IsTeleportCloak(GetInventoryItemID("player", BACK_SLOT))

    if show then
        restoreButton.link = link
        restoreButton.icon:SetTexture(C_Item.GetItemIconByID(link) or 134400)
        restoreButton:ClearAllPoints()
        restoreButton:SetPoint("TOP", ns.button, "BOTTOM", 0, -6)
        restoreButton:Show()
    else
        restoreButton:Hide()
    end
end

local restoreWatcher = CreateFrame("Frame")
restoreWatcher:RegisterEvent("PLAYER_ENTERING_WORLD")
restoreWatcher:RegisterEvent("ZONE_CHANGED_NEW_AREA")
restoreWatcher:RegisterEvent("PLAYER_REGEN_ENABLED")
restoreWatcher:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
restoreWatcher:SetScript("OnEvent", function(_, event, slot)
    if not ns.db then
        return
    end

    if event == "PLAYER_EQUIPMENT_CHANGED" then
        -- If the back slot holds something other than a teleport cloak, nothing is left to restore.
        if slot == BACK_SLOT and not ns.IsTeleportCloak(GetInventoryItemID("player", BACK_SLOT)) then
            ns.db.savedCloaks[UnitGUID("player")] = nil
        end
        ns.UpdateRestoreButton()
        return
    end

    ns.UpdateRestoreButton()

    -- Automatic mode: give the teleport a moment to finish before swapping gear.
    if ns.db.autoRestoreCloak then
        C_Timer.After(1, RestoreNow)
    end
end)