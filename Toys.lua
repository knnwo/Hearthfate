local _, ns = ...

-- Known hearthstone toys.
-- destination = true means the toy does NOT take you to your bind location,
-- so we'll leave it out by default later.
-- Known hearthstone toys.
-- destination = true means the toy does NOT take you to your bind location.
-- source = a short "how to obtain" line shown in the menu's missing-toys section.
-- Known hearthstone toys.
-- destination = true means the toy does NOT take you to your bind location.
ns.toyData = {
    { id = 54452 },  -- Ethereal Portal
    { id = 64488 },  -- The Innkeeper's Daughter
    { id = 142542 }, -- Tome of Town Portal
    { id = 162973 }, -- Greatfather Winter's Hearthstone
    { id = 163045 }, -- Headless Horseman's Hearthstone
    { id = 165669 }, -- Lunar Elder's Hearthstone
    { id = 165670 }, -- Peddlefeet's Lovely Hearthstone
    { id = 165802 }, -- Noble Gardener's Hearthstone
    { id = 166746 }, -- Fire Eater's Hearthstone
    { id = 166747 }, -- Brewfest Reveler's Hearthstone
    { id = 168907 }, -- Holographic Digitalization Hearthstone
    { id = 172179 }, -- Eternal Traveler's Hearthstone
    { id = 180290 }, -- Night Fae Hearthstone
    { id = 182773 }, -- Necrolord Hearthstone
    { id = 183716 }, -- Venthyr Sinstone
    { id = 184353 }, -- Kyrian Hearthstone
    { id = 188952 }, -- Dominated Hearthstone
    { id = 190196 }, -- Enlightened Hearthstone
    { id = 190237 }, -- Broker Translocation Matrix
    { id = 193588 }, -- Timewalker's Hearthstone
    { id = 200630 }, -- Ohn'ir Windsage's Hearthstone
    { id = 206195 }, -- Path of the Naaru
    { id = 208704 }, -- Deepdweller's Earthen Hearthstone
    { id = 209035 }, -- Hearthstone of the Flame
    { id = 210455 }, -- Draenic Hologem
    { id = 212337 }, -- Stone of the Hearth
    { id = 228940 }, -- Notorious Thread's Hearthstone
    { id = 235016 }, -- Redeployment Module
    { id = 236687 }, -- Explosive Hearthstone
    { id = 245970 }, -- P.O.S.T. Master's Express Hearthstone
    { id = 246565 }, -- Cosmic Hearthstone
    { id = 257736 }, -- Lightcalled Hearthstone
    { id = 263933 }, -- Preyseeker's Hearthstone
    { id = 265100 }, -- Corewarden's Hearthstone
    { id = 281136 }, -- Hiveborne Hearthstone
    { id = 281615 }, -- Shadeweaver's Hearthstone

    -- Teleport somewhere other than your bind location
    { id = 110560, destination = true }, -- Garrison Hearthstone
    { id = 140192, destination = true }, -- Dalaran Hearthstone
}

-- Returns a list of { id, name, icon, destination } for known toys the player owns.
function ns.GetOwnedToys()
    local owned = {}
    for _, data in ipairs(ns.toyData) do
        if PlayerHasToy(data.id) then
            local _, name, icon = C_ToyBox.GetToyInfo(data.id)
            owned[#owned + 1] = {
                id = data.id,
                name = name or ("Toy " .. data.id),
                icon = icon,
                destination = data.destination or false,
            }
        end
    end
    return owned
end

-- Owned toys that can go in the random pick: everything that takes you to your bind location.
-- Garrison and Dalaran are on their own Shift-click shortcuts instead.
function ns.GetRandomizableToys()
    local list = {}
    for _, toy in ipairs(ns.GetOwnedToys()) do
        if not toy.destination then
            list[#list + 1] = toy
        end
    end
    return list
end

-- Known toys the player doesn't own yet, for the menu's unavailable view.
function ns.GetMissingToys()
    local missing = {}
    for _, data in ipairs(ns.toyData) do
        if not PlayerHasToy(data.id) then
            local _, name, icon = C_ToyBox.GetToyInfo(data.id)
            if name then
                missing[#missing + 1] = {
                    id = data.id,
                    name = name,
                    icon = icon,
                    destination = data.destination or false,
                }
            end
        end
    end
    return missing
end