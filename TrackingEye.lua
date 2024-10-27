-- SimpleTrackingEye
-- A simple addon to add a tracking button to the minimap using LibDBIcon.
-- License: MIT

local SimpleTrackingEye = {}
local LDB = LibStub:GetLibrary("LibDataBroker-1.1")
local icon = LibStub("LibDBIcon-1.0")

-- Ensure UIDropDownMenu library is loaded
if not EasyMenu then
    LoadAddOn("Blizzard_UIDropDownMenu")
end

-- Fallback if EasyMenu still isn't available
if not EasyMenu then
    function EasyMenu(menuList, menuFrame, anchor, xOffset, yOffset, displayMode, autoHideDelay)
        if (not menuFrame or not menuFrame:GetName()) then
            menuFrame = CreateFrame("Frame", "EasyMenuDummyFrame", UIParent, "UIDropDownMenuTemplate")
        end
        UIDropDownMenu_Initialize(menuFrame, function(self, level, menuList)
            for i = 1, #menuList do
                local info = UIDropDownMenu_CreateInfo()
                for k, v in pairs(menuList[i]) do
                    info[k] = v
                end
                UIDropDownMenu_AddButton(info, level)
            end
        end, displayMode, nil, menuList)
        ToggleDropDownMenu(1, nil, menuFrame, anchor, xOffset, yOffset, menuList, nil, autoHideDelay)
    end
end

-- List of tracking spells (IDs)
local trackingSpells = {
    1494,   -- Track Beasts
    19883,  -- Track Humanoids
    19884,  -- Track Undead
    19885,  -- Track Hidden
    19880,  -- Track Elementals
    19878,  -- Track Demons
    19882,  -- Track Giants
    19879,  -- Track Dragonkin
    5225,   -- Track Humanoids (Druid, only in Cat Form)
    5500,   -- Sense Demons
    5502,   -- Sense Undead
    2383,   -- Find Herbs
    2580,   -- Find Minerals
    2481    -- Find Treasure
}

-- Create a DataBroker object
local trackingLDB = LDB:NewDataObject("SimpleTrackingEye", {
    type = "data source",
    text = "SimpleTrackingEye",
    icon = "Interface\\Icons\\INV_Misc_Map_01", -- Default icon when no tracking is active
    OnClick = function(_, button)
        if button == "LeftButton" then
            SimpleTrackingEye:OpenTrackingMenu()
        elseif button == "RightButton" then
            SimpleTrackingEye:CancelTrackingBuff()
        end
    end,
    OnTooltipShow = function(tooltip)
        tooltip:AddLine("SimpleTrackingEye")
        tooltip:AddLine("Left-click to select tracking.")
        tooltip:AddLine("Right-click to cancel tracking.")
    end
})

-- Default minimap button settings
local db = {
    minimap = {
        hide = false, -- This allows users to toggle the minimap button
    }
}

-- Register the minimap button with LibDBIcon
icon:Register("SimpleTrackingEye", trackingLDB, db.minimap)

-- Function to check if the player is a Druid in Cat Form
local function IsDruidInCatForm()
    if UnitClass("player") == "Druid" then
        for i = 1, 40 do
            local buffName = UnitBuff("player", i)
            if buffName == GetSpellInfo(768) then -- 768 is the spell ID for Cat Form
                return true
            end
        end
    end
    return false
end

-- Function to cast the tracking spell by ID
local function CastTrackingSpell(spellId)
    if spellId then
        CastSpellByID(spellId)
    end
end

-- Function to open the tracking menu with sorted spell names
function SimpleTrackingEye:OpenTrackingMenu()
    local menu = {
        { text = "Select Tracking", isTitle = true }
    }

    -- Create a table of spells with their names and IDs
    local spells = {}

    for _, spellId in ipairs(trackingSpells) do
        local spellName = GetSpellInfo(spellId)
        if IsPlayerSpell(spellId) then
            -- Check for Druids and Cat Form for Track Humanoids (Druid)
            if spellId == 5225 then -- Track Humanoids (Druid spell ID)
                if IsDruidInCatForm() then
                    table.insert(spells, {name = spellName, id = spellId, texture = GetSpellTexture(spellId)})
                end
            else
                -- Add all other spells normally
                table.insert(spells, {name = spellName, id = spellId, texture = GetSpellTexture(spellId)})
            end
        end
    end

    -- Sort the spells alphabetically by name
    table.sort(spells, function(a, b) return a.name < b.name end)

    -- Add sorted spells to the menu
    for _, spell in ipairs(spells) do
        table.insert(menu, {
            text = spell.name,
            icon = spell.texture,
            func = function()
                CastTrackingSpell(spell.id) -- Cast the spell using the sorted list
            end
        })
    end

    EasyMenu(menu, SimpleTrackingEyeMenu, "cursor", 0, 0, "MENU")
end

-- Function to cancel the current tracking buff
function SimpleTrackingEye:CancelTrackingBuff()
    for i = 1, 40 do
        local name, _, _, _, _, _, _, _, _, spellId = UnitBuff("player", i)
        if name and tContains(trackingSpells, spellId) then
            CancelUnitBuff("player", i)
            break
        end
    end
end

-- Event handling for updating tracking icon
local frame = CreateFrame("Frame")
frame:RegisterEvent("MINIMAP_UPDATE_TRACKING")
frame:SetScript("OnEvent", function()
    local trackingTexture = GetTrackingTexture()

    if trackingTexture then
        trackingLDB.icon = trackingTexture
    else
        trackingLDB.icon = "Interface\\Icons\\INV_Misc_Map_01" -- Default icon
    end
end)

-- Hide Blizzard's default tracking button
if MiniMapTrackingFrame then
    MiniMapTrackingFrame:Hide()
end
