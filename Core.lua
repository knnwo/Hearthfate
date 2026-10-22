local addonName, ns = ...

ns.name = addonName

BINDING_HEADER_HEARTHFATE = "Hearthfate"
_G["BINDING_NAME_CLICK HearthfateButton:LeftButton"] = "Use random hearthstone toy"

local DB_VERSION = 1

-- Default settings. `enabled` will map toyID -> true for toys the player includes.
local defaults = {
    dbVersion = DB_VERSION,
    announce = true,
    showButton = true,
    locked = false,
    buttonSize = 48,
    fadeIdle = false,
    readyCue = true,
    iconStyle = "emberdice",
    savedCloaks = {},
    autoRestoreCloak = true,
    disabled = {},
    useCount = {},
    favorites = {},
    position = {
        point = "CENTER",
        relativePoint = "CENTER",
        x = 0,
        y = -200,
    },
}

-- Fill in any missing keys from defaults without overwriting saved values.
local function MergeDefaults(target, source)
    for key, value in pairs(source) do
        if target[key] == nil then
            if type(value) == "table" then
                target[key] = {}
                MergeDefaults(target[key], value)
            else
                target[key] = value
            end
        elseif type(value) == "table" and type(target[key]) == "table" then
            MergeDefaults(target[key], value)
        end
    end
end

local function Print(msg)
    print("|cff33ff99Hearthfate:|r " .. tostring(msg))
end
ns.Print = Print

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, _, loadedAddon)
    if loadedAddon ~= addonName then
        return
    end

    HearthfateDB = HearthfateDB or {}
    MergeDefaults(HearthfateDB, defaults)
    ns.db = HearthfateDB

    ns.InitButton()

    self:UnregisterEvent("ADDON_LOADED")
end)

SLASH_HEARTHFATE1 = "/hfate"
SlashCmdList["HEARTHFATE"] = function(msg)
    msg = (msg or ""):match("^%s*(.-)%s*$"):lower()

    if msg == "list" then
        local owned = ns.GetOwnedToys()
        if #owned == 0 then
            Print("you don't own any of the known hearthstone toys.")
            return
        end
        Print(#owned .. " owned:")
        for _, toy in ipairs(owned) do
            print(string.format("  %d  %s%s", toy.id, toy.name, toy.destination and " (destination)" or ""))
        end
        return
    end

    if msg == "menu" then
        ns.ToggleMenu()
        return
    end

    if msg == "options" or msg == "config" then
        Settings.OpenToCategory(ns.settingsCategory:GetID())
        return
    end

    local version = C_AddOns.GetAddOnMetadata(addonName, "Version")
    Print("v" .. tostring(version) .. " loaded. Type /hfate menu, /hfate list or /hfate options.")
end

-- TEMPORARY TEST CODE: delete this whole block when you're done testing.
SLASH_RHTDEBUG1 = "/hfatedebug"
SlashCmdList["RHTDEBUG"] = function()
    local function Show(label, spellID)
        if not spellID then
            Print(label .. ": no spell ID found")
            return
        end
        Print(label .. " (spell " .. tostring(spellID) .. ")")

        local charges = C_Spell.GetSpellCharges(spellID)
        if charges then
            print(string.format("  charges %s/%s, start %s, duration %s",
                tostring(charges.currentCharges), tostring(charges.maxCharges),
                tostring(charges.cooldownStartTime), tostring(charges.cooldownDuration)))
        else
            print("  no charge info")
        end

        local cd = C_Spell.GetSpellCooldown(spellID)
        if cd then
            print(string.format("  cooldown start %s, duration %s",
                tostring(cd.startTime), tostring(cd.duration)))
        else
            print("  no cooldown info")
        end
    end

    -- The regular Hearthstone spell
    Show("Hearthstone spell", 8690)

    -- The first owned toy that goes to the bind location
    for _, toy in ipairs(ns.GetOwnedToys()) do
        if not toy.destination then
            local _, spellID = C_Item.GetItemSpell(toy.id)
            Show(toy.name, spellID)
            break
        end
    end

    -- What our current swirl reads
    local start, duration = C_Item.GetItemCooldown(6948)
    Print(string.format("item 6948 cooldown: start %s, duration %s", tostring(start), tostring(duration)))
end