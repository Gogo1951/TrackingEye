local TrackingEye = {}
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
        UIDropDownMenu_Initialize(
            menuFrame,
            function(self, level, menuList)
                for i = 1, #menuList do
                    local info = UIDropDownMenu_CreateInfo()
                    for k, v in pairs(menuList[i]) do
                        info[k] = v
                    end
                    UIDropDownMenu_AddButton(info, level)
                end
            end,
            displayMode,
            nil,
            menuList
        )
        ToggleDropDownMenu(1, nil, menuFrame, anchor, xOffset, yOffset, menuList, nil, autoHideDelay)
    end
end

-- Default saved variables
TrackingEyeDB =
    TrackingEyeDB or
    {
        minimap = {
            hide = false, -- Whether to hide the minimap button
            minimapPos = 220 -- Default position on the minimap
        }
    }

-- List of tracking spells (IDs)
local trackingSpells = {
    2383, -- Find Herbs
    2580, -- Find Minerals
    2481, -- Find Treasure
    5500, -- Sense Demons
    5502, -- Sense Undead
    1494, -- Track Beasts
    19883, -- Track Humanoids
    5225, -- Track Humanoids (Druid, only in Cat Form)
    19884, -- Track Undead
    19885, -- Track Hidden
    19880, -- Track Elementals
    19878, -- Track Demons
    19882, -- Track Giants
    19879 -- Track Dragonkin
}

-- Variable to store the selected tracking spell
local selectedTrackingSpell

-- Create a DataBroker object
local trackingLDB =
    LDB:NewDataObject(
    "TrackingEye",
    {
        type = "data source",
        text = "TrackingEye",
        icon = "Interface\\Icons\\INV_Misc_Map_01", -- Default icon when no tracking is active
        OnClick = function(_, button)
            TrackingEye:OpenTrackingMenu()
        end
    }
)

-- Register the minimap button with LibDBIcon
icon:Register("TrackingEye", trackingLDB, TrackingEyeDB.minimap)

-- Function to save minimap settings on logout
local function SaveMinimapSettings()
    TrackingEyeDB.minimap.hide = icon:IsRegistered("TrackingEye") and icon:IsHidden("TrackingEye") or false
end

-- Function to reapply tracking after resurrection
local function ReapplyTracking()
    if selectedTrackingSpell and IsPlayerSpell(selectedTrackingSpell) then
        -- Exclude Druid Track Humanoids (spellId 5225)
        if selectedTrackingSpell ~= 5225 then
            CastSpellByID(selectedTrackingSpell)
        end
    end
end

-- Function to cast the tracking spell by ID
local function CastTrackingSpell(spellId)
    if spellId then
        selectedTrackingSpell = spellId -- Save the selected spell
        CastSpellByID(spellId)
    end
end

-- Event handling for saving and loading saved variables
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGOUT")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_ALIVE")
frame:RegisterEvent("PLAYER_UNGHOST")
frame:RegisterEvent("MINIMAP_UPDATE_TRACKING")
frame:SetScript(
    "OnEvent",
    function(self, event, addon)
        if event == "ADDON_LOADED" and addon == "TrackingEye" then
            -- Ensure saved variables are properly initialized
            if not TrackingEyeDB.minimap then
                TrackingEyeDB.minimap = {
                    hide = false,
                    minimapPos = 220
                }
            end
            icon:Refresh("TrackingEye", TrackingEyeDB.minimap) -- Apply saved settings
        elseif event == "PLAYER_LOGOUT" then
            SaveMinimapSettings() -- Save settings on logout
        elseif event == "PLAYER_ALIVE" or event == "PLAYER_UNGHOST" then
            -- Reapply tracking after resurrection
            if not UnitIsDeadOrGhost("player") then
                ReapplyTracking()
            end
        elseif event == "MINIMAP_UPDATE_TRACKING" then
            local trackingTexture = GetTrackingTexture()
            trackingLDB.icon = trackingTexture or "Interface\\Icons\\INV_Misc_Map_01"
        end
    end
)

-- Function to open the tracking menu
function TrackingEye:OpenTrackingMenu()
    -- Ensure trackingSpells is not nil
    if not trackingSpells then
        print("Error: trackingSpells table is nil.")
        return
    end

    local menu = {
        {text = "|cffffd517Select Tracking Ability|r", isTitle = true, notCheckable = true},
        {text = " ", isTitle = true, notCheckable = true} -- Line break
    }

    local spells = {}

    for _, spellId in ipairs(trackingSpells) do
        local spellName = GetSpellInfo(spellId)
        if IsPlayerSpell(spellId) then
            table.insert(spells, {name = spellName, id = spellId, texture = GetSpellTexture(spellId)})
        end
    end

    table.sort(
        spells,
        function(a, b)
            return a.name < b.name
        end
    )

    for _, spell in ipairs(spells) do
        table.insert(
            menu,
            {
                text = spell.name,
                icon = spell.texture,
                func = function()
                    CastTrackingSpell(spell.id)
                end,
                notCheckable = true
            }
        )
    end

    EasyMenu(menu, TrackingEyeMenu, "cursor", 0, 0, "MENU")
end

-- Hide Blizzard's default tracking button
if MiniMapTrackingFrame then
    MiniMapTrackingFrame:Hide()
end
