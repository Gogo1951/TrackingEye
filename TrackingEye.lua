-- TrackingEye Addon (WoW Classic Era)
local addonName, TrackingEye = ...

-- Constants
local DEFAULT_MINIMAP_ICON = "Interface\\Icons\\inv_misc_map_01"
local MINIMAP_RADIUS = 80

-- SavedVariables initialized on load
local function InitializeSavedVariables()
    if not TrackingEyeDB then
        TrackingEyeDB = {
            minimapPos = 159.03,
            selectedSpellId = nil
        }
    end
end

-- Load dropdown menu addon if not already loaded
if not IsAddOnLoaded("Blizzard_UIDropDownMenu") then
    LoadAddOn("Blizzard_UIDropDownMenu")
end

-- Create dropdown frame
local dropdown = CreateFrame("Frame", "TrackingEyeDropdown", UIParent, "UIDropDownMenuTemplate")

-- List of tracking spells
local trackingSpells = {
    [2383] = "Find Herbs",
    [2580] = "Find Minerals",
    [2481] = "Find Treasure",
    [5500] = "Sense Demons",
    [5502] = "Sense Undead",
    [1494] = "Track Beasts",
    [19883] = "Track Humanoids", -- Hunter
    [5225] = "Track Humanoids", -- Druid (Cat Form)
    [19884] = "Track Undead",
    [19885] = "Track Hidden",
    [19880] = "Track Elementals",
    [19878] = "Track Demons",
    [19882] = "Track Giants",
    [19879] = "Track Dragonkin"
}

-- Check if Druid is in Cat Form
local function IsDruidInCatForm()
    if select(2, UnitClass("player")) ~= "DRUID" then
        return false
    end
    for i = 1, 40 do
        local _, _, _, _, _, _, _, _, _, spellId = UnitBuff("player", i)
        if spellId == 768 then
            return true
        end
    end
    return false
end

-- Reapply saved tracking on login / form change
local function ReapplyTracking()
    local spellId = TrackingEyeDB.selectedSpellId
    if spellId and IsPlayerSpell(spellId) then
        if spellId == 5225 and not IsDruidInCatForm() then
            return
        end
        CastSpellByID(spellId)
    end
end

-- Cancel active tracking and clear selection
local function ClearTracking()
    CancelTrackingBuff()
    TrackingEyeDB.selectedSpellId = nil
end

-- Get x, y offsets for minimap button from angle and radius
local function GetMinimapOffset(angle, radius)
    local rad = math.rad(angle)
    return math.cos(rad) * radius, math.sin(rad) * radius
end

-- Build the dropdown menu
local function BuildMenu(self, level)
    UIDropDownMenu_AddButton(
        {
            text = "Select Tracking Ability",
            isTitle = true,
            notCheckable = true
        },
        level
    )

    local spellList = {}
    for id, name in pairs(trackingSpells) do
        table.insert(spellList, {id = id, name = name})
    end
    table.sort(
        spellList,
        function(a, b)
            return a.name < b.name
        end
    )

    local hasTracking = false

    for _, spell in ipairs(spellList) do
        if IsPlayerSpell(spell.id) and (spell.id ~= 5225 or IsDruidInCatForm()) then
            hasTracking = true
            local icon = GetSpellTexture(spell.id)
            local displayText = spell.name
            if icon then
                displayText = "|T" .. icon .. ":16:16:0:0:64:64:5:59:5:59|t " .. spell.name
            end
            UIDropDownMenu_AddButton(
                {
                    text = displayText,
                    checked = (TrackingEyeDB.selectedSpellId == spell.id),
                    func = function()
                        TrackingEyeDB.selectedSpellId = spell.id
                        CastSpellByID(spell.id)
                        CloseDropDownMenus()
                    end
                },
                level
            )
        end
    end

    if not hasTracking then
        UIDropDownMenu_AddButton(
            {
                text = "No Tracking Skills Available",
                disabled = true,
                notCheckable = true
            },
            level
        )
    end
end

-- Create minimap button
local button = CreateFrame("Button", "TrackingEyeMinimapButton", Minimap)
button:SetSize(32, 32)
button:SetFrameStrata("MEDIUM")
button:SetMovable(true)
button:EnableMouse(true)
button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
button:RegisterForDrag("LeftButton")
button:SetClampedToScreen(true)
button:Hide()

-- Add icon to button
button.icon = button:CreateTexture(nil, "ARTWORK")
button.icon:SetTexture(DEFAULT_MINIMAP_ICON)
button.icon:SetAllPoints()

-- Tooltip setup
local function ShowTooltip(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOPRIGHT")
    GameTooltip:AddLine("TrackingEye")
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Left-click : Select Tracking", 1, 1, 1)
    GameTooltip:AddLine("Right-click : Clear Tracking", 1, 1, 1)
    GameTooltip:Show()
end

button:SetScript("OnEnter", ShowTooltip)
button:SetScript("OnLeave", GameTooltip_Hide)

-- Handle button clicks
button:SetScript(
    "OnClick",
    function(self, buttonPressed)
        if buttonPressed == "RightButton" then
            ClearTracking()
        else
            UIDropDownMenu_Initialize(dropdown, BuildMenu, "MENU")
            ToggleDropDownMenu(1, nil, dropdown, "cursor", 0, 0)
        end
    end
)

-- Drag logic
local function OnDragUpdate(self)
    local mx, my = Minimap:GetCenter()
    local px, py = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    px, py = px / scale, py / scale
    local angle = math.deg(math.atan2(py - my, px - mx)) % 360
    TrackingEyeDB.minimapPos = angle
    local x, y = GetMinimapOffset(angle, MINIMAP_RADIUS)
    self:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

button:SetScript(
    "OnDragStart",
    function(self)
        self:SetScript("OnUpdate", OnDragUpdate)
    end
)

button:SetScript(
    "OnDragStop",
    function(self)
        self:SetScript("OnUpdate", nil)
    end
)

-- Position the button based on saved angle
local function PositionButton()
    local angle = TrackingEyeDB.minimapPos or 45
    local x, y = GetMinimapOffset(angle, MINIMAP_RADIUS)
    button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

-- Event handler frame
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_ALIVE")
f:RegisterEvent("PLAYER_UNGHOST")
f:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
f:RegisterEvent("MINIMAP_UPDATE_TRACKING")

f:SetScript(
    "OnEvent",
    function(_, event, arg)
        if event == "ADDON_LOADED" and arg == addonName then
            InitializeSavedVariables()
            PositionButton()
            button:Show()
        elseif event == "PLAYER_ALIVE" or event == "PLAYER_UNGHOST" then
            ReapplyTracking()
        elseif event == "UPDATE_SHAPESHIFT_FORM" then
            if TrackingEyeDB.selectedSpellId == 5225 and IsDruidInCatForm() then
                local currentTracking = GetTrackingTexture()
                if not currentTracking then
                    CastSpellByID(5225)
                end
            end
        elseif event == "MINIMAP_UPDATE_TRACKING" then
            local texture = GetTrackingTexture()
            if texture then
                button.icon:SetTexture(texture)
            else
                button.icon:SetTexture(DEFAULT_MINIMAP_ICON)
                TrackingEyeDB.selectedSpellId = nil
            end
        end
    end
)

-- Slash command for debugging
SLASH_TRACKINGEYE1 = "/trackingeye"
SlashCmdList["TRACKINGEYE"] = function()
    print("TrackingEye minimap position: " .. (TrackingEyeDB.minimapPos or "unknown"))
end
