local TrackingEye = {}
local LDB = LibStub:GetLibrary("LibDataBroker-1.1")
local icon = LibStub("LibDBIcon-1.0")

-- Centralized error reporting
local function ReportError(message)
    print("|cffff0000[TrackingEye Error]:|r " .. message)
end

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

-- Ensure TrackingEyeMenu is a valid frame
if not TrackingEye.MenuFrame then
    TrackingEye.MenuFrame = CreateFrame("Frame", "TrackingEyeMenuFrame", UIParent, "UIDropDownMenuTemplate")
end

-- Default saved variables
local TrackingEyeDB

-- List of tracking spells (IDs)
local trackingSpells = {
    [2383] = "Find Herbs",
    [2580] = "Find Minerals",
    [2481] = "Find Treasure",
    [5500] = "Sense Demons",
    [5502] = "Sense Undead",
    [1494] = "Track Beasts",
    [19883] = "Track Humanoids",
    [5225] = "Track Humanoids (Cat Form Only)",
    [19884] = "Track Undead",
    [19885] = "Track Hidden",
    [19880] = "Track Elementals",
    [19878] = "Track Demons",
    [19882] = "Track Giants",
    [19879] = "Track Dragonkin"
}

-- Variable to store the selected tracking spell
TrackingEye.SelectedSpell = nil

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

-- Function to toggle the minimap button
function TrackingEye:ToggleMinimapButton()
    if TrackingEyeDB.minimap.hide then
        icon:Show("TrackingEye")
        TrackingEyeDB.minimap.hide = false
    else
        icon:Hide("TrackingEye")
        TrackingEyeDB.minimap.hide = true
    end
end

-- Function to reapply tracking after resurrection
local function ReapplyTracking()
    if TrackingEye.SelectedSpell and IsPlayerSpell(TrackingEye.SelectedSpell) then
        -- Exclude Druid Track Humanoids (spellId 5225) unless in Cat Form
        if TrackingEye.SelectedSpell == 5225 then
            local _, _, _, _, formId = GetShapeshiftFormInfo(3) -- Cat Form index
            if not formId then
                ReportError("You must be in Cat Form to use Track Humanoids.")
                return
            end
        end
        CastSpellByID(TrackingEye.SelectedSpell)
    end
end

-- Function to cast the tracking spell by ID
local function CastTrackingSpell(spellId)
    if not trackingSpells[spellId] then
        ReportError("Invalid tracking spell ID.")
        return
    end
    TrackingEye.SelectedSpell = spellId
    CastSpellByID(spellId)
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
            -- Initialize saved variables
            _G.TrackingEyeDB = _G.TrackingEyeDB or {minimap = {hide = false, minimapPos = 220}}
            TrackingEyeDB = _G.TrackingEyeDB

            -- Register minimap icon with LibDBIcon
            icon:Register("TrackingEye", trackingLDB, TrackingEyeDB.minimap)

            -- Apply visibility state
            if TrackingEyeDB.minimap.hide then
                icon:Hide("TrackingEye")
            else
                icon:Show("TrackingEye")
            end
        elseif event == "PLAYER_LOGOUT" then
            -- Save settings on logout
            -- No additional action needed as LibDBIcon updates TrackingEyeDB automatically
        elseif event == "PLAYER_ALIVE" or event == "PLAYER_UNGHOST" then
            -- Reapply tracking after resurrection
            if not UnitIsDeadOrGhost("player") then
                ReapplyTracking()
            end
        elseif event == "MINIMAP_UPDATE_TRACKING" then
            local trackingTexture = GetTrackingTexture() or "Interface\\Icons\\INV_Misc_Map_01"
            trackingLDB.icon = trackingTexture
        end
    end
)

-- Function to open the tracking menu
function TrackingEye:OpenTrackingMenu()
    local menu = {
        {text = "|cffffd517Select Tracking Ability|r", isTitle = true, notCheckable = true},
        {text = " ", isTitle = true, notCheckable = true, disabled = true} -- Line break
    }

    local spells = {}

    for spellId, spellName in pairs(trackingSpells) do
        if IsPlayerSpell(spellId) then
            table.insert(spells, {name = spellName, id = spellId, texture = GetSpellTexture(spellId)})
        end
    end

    -- If no tracking abilities are available, show a message
    if #spells == 0 then
        table.insert(
            menu,
            {
                text = "|cffff0000No tracking abilities known.|r",
                isTitle = true,
                notCheckable = true
            }
        )
    else
        -- Sort and add known abilities to the menu
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
    end

    EasyMenu(menu, TrackingEye.MenuFrame, "cursor", 0, 0, "MENU")
end

-- Hide Blizzard's default tracking button
if MiniMapTrackingFrame then
    MiniMapTrackingFrame:Hide()
end
