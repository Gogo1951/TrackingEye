-- TrackingEye Addon
local ADDON_NAME = "TrackingEye"
local addonTable = ... -- Addon namespace table provided by WoW

-- Constants
local DEFAULT_MINIMAP_ICON = "Interface\\Icons\\inv_misc_map_01"
local MINIMAP_RADIUS = 80
local DRUID_CAT_FORM_SPELL_ID = 768

-- Initialize SavedVariables on first load or if corrupted
local function InitializeSavedVariables()
    if not _G[ADDON_NAME .. "DB"] or type(_G[ADDON_NAME .. "DB"]) ~= "table" then
        _G[ADDON_NAME .. "DB"] = {}
    end
    local db = _G[ADDON_NAME .. "DB"]

    -- Set defaults if missing
    if not db.minimapPos or type(db.minimapPos) ~= "number" then
        db.minimapPos = 159.03
    end
    if db.selectedSpellId and type(db.selectedSpellId) ~= "number" then
        db.selectedSpellId = nil
    end
end

-- Ensure UIDropDownMenu is loaded
if not IsAddOnLoaded("Blizzard_UIDropDownMenu") then
    LoadAddOn("Blizzard_UIDropDownMenu")
end

-- Create dropdown frame
local dropdown = CreateFrame("Frame", ADDON_NAME .. "Dropdown", UIParent, "UIDropDownMenuTemplate")

-- List of all possible tracking spells the addon supports
local trackingSpells = {
    [2383] = "Find Herbs",
    [2580] = "Find Minerals",
    [2481] = "Find Treasure",
    [5500] = "Sense Demons", -- Warlock
    [5502] = "Sense Undead", -- Warlock
    [1494] = "Track Beasts", -- Hunter
    [19883] = "Track Humanoids", -- Hunter
    [5225] = "Track Humanoids", -- Druid (Cat Form)
    [19884] = "Track Undead", -- Hunter
    [19885] = "Track Hidden", -- Hunter
    [19880] = "Track Elementals", -- Hunter
    [19878] = "Track Demons", -- Hunter
    [19882] = "Track Giants", -- Hunter
    [19879] = "Track Dragonkin" -- Hunter
}

-- Check if the player is a Druid currently in Cat Form
local function IsDruidInCatForm()
    if select(2, UnitClass("player")) ~= "DRUID" then
        return false
    end
    for i = 1, 40 do
        local _, _, _, _, _, _, _, _, _, spellId = UnitBuff("player", i)
        if spellId == DRUID_CAT_FORM_SPELL_ID then
            return true
        end
    end
    return false
end

-- Reapply the user's selected tracking spell if conditions are met
local function ReapplyTracking()
    local db = _G[ADDON_NAME .. "DB"]
    local spellId = db.selectedSpellId
    if spellId and IsPlayerSpell(spellId) then
        -- Special handling for Druid 'Track Humanoids' (ID 5225)
        if spellId == 5225 and not IsDruidInCatForm() then
            return -- Don't try to cast if not in Cat Form
        end
        CastSpellByID(spellId)
    end
end

-- Cancel any active tracking buff AND clear the user's saved selection
local function ClearTrackingSelection()
    local db = _G[ADDON_NAME .. "DB"]
    CancelTrackingBuff()
    db.selectedSpellId = nil -- Clear the saved preference
    -- Icon update is handled by MINIMAP_UPDATE_TRACKING event
end

-- Calculate X, Y offsets for positioning the button around the minimap
local function GetMinimapOffset(angle, radius)
    local rad = math.rad(angle)
    return math.cos(rad) * radius, math.sin(rad) * radius
end

-- Build the contents of the dropdown menu dynamically
local function BuildMenu(self, level)
    if level ~= 1 then
        return
    end -- Only build top level

    local db = _G[ADDON_NAME .. "DB"]
    local info = UIDropDownMenu_CreateInfo()

    -- Title Item
    info.text = "Select Tracking Ability"
    info.isTitle = true
    info.notCheckable = true
    UIDropDownMenu_AddButton(info, level)

    -- Create a temporary list to sort spells by name
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

    local hasAnyAvailableTracking = false

    -- Add available tracking spells to the menu
    for _, spellData in ipairs(spellList) do
        local spellId = spellData.id
        local spellName = spellData.name

        -- Check if player knows the spell AND meets Druid form requirements
        local isAvailable = IsPlayerSpell(spellId) and (spellId ~= 5225 or IsDruidInCatForm())

        if isAvailable then
            hasAnyAvailableTracking = true
            local icon = GetSpellTexture(spellId)

            info = UIDropDownMenu_CreateInfo()
            info.text = spellName
            if icon then
                info.text = "|T" .. icon .. ":16:16:0:0:64:64:5:59:5:59|t " .. spellName
            end
            info.value = {spellId = spellId} -- Store spellId for the click function
            info.checked = (db.selectedSpellId == spellId)
            info.func = function(self)
                local idToCast = self.value.spellId
                local current_db = _G[ADDON_NAME .. "DB"]
                current_db.selectedSpellId = idToCast -- Save the selection
                CastSpellByID(idToCast)
                CloseDropDownMenus()
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end

    -- Add a disabled item if no tracking skills are currently available
    if not hasAnyAvailableTracking then
        info = UIDropDownMenu_CreateInfo()
        info.text = "No Tracking Skills Available"
        info.disabled = true
        info.notCheckable = true
        UIDropDownMenu_AddButton(info, level)
    end
end

-- Create the minimap button
local button = CreateFrame("Button", ADDON_NAME .. "MinimapButton", Minimap)
button:SetSize(32, 32)
button:SetFrameStrata("MEDIUM")
button:SetMovable(true)
button:EnableMouse(true)
button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
button:RegisterForDrag("LeftButton")
button:SetClampedToScreen(true)
button:Hide() -- Hide initially until positioned

-- Add icon texture to the button
button.icon = button:CreateTexture(nil, "ARTWORK")
button.icon:SetTexture(DEFAULT_MINIMAP_ICON)
button.icon:SetAllPoints()

-- Tooltip setup
local function ShowTooltip(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOPRIGHT")
    GameTooltip:AddLine(ADDON_NAME)
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
            ClearTrackingSelection()
        else -- LeftButton
            UIDropDownMenu_Initialize(dropdown, BuildMenu, "MENU")
            ToggleDropDownMenu(1, nil, dropdown, "cursor", 0, 0) -- Position near cursor
        end
    end
)

-- Dragging logic
local function OnDragUpdate(self)
    local db = _G[ADDON_NAME .. "DB"]
    local mx, my = Minimap:GetCenter()
    local px, py = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    px, py = px / scale, py / scale
    local angle = math.deg(math.atan2(py - my, px - mx))
    if angle < 0 then
        angle = angle + 360
    end -- Keep angle positive
    db.minimapPos = angle
    local x, y = GetMinimapOffset(angle, MINIMAP_RADIUS)
    self:ClearAllPoints()
    self:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

button:SetScript(
    "OnDragStart",
    function(self)
        self:SetScript("OnUpdate", OnDragUpdate) -- Update position while dragging
    end
)

button:SetScript(
    "OnDragStop",
    function(self)
        self:SetScript("OnUpdate", nil) -- Stop updating position
        OnDragUpdate(self) -- Final position update
    end
)

-- Position the button based on the saved angle
local function PositionButton()
    local db = _G[ADDON_NAME .. "DB"]
    local angle = db.minimapPos
    local x, y = GetMinimapOffset(angle, MINIMAP_RADIUS)
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

-- Update the button's icon based on the currently active tracking buff
local function UpdateButtonIcon()
    local currentTrackingTexture = GetTrackingTexture()
    if currentTrackingTexture then
        button.icon:SetTexture(currentTrackingTexture)
    else
        button.icon:SetTexture(DEFAULT_MINIMAP_ICON)
    end
end

-- Main event handler frame
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ALIVE")
eventFrame:RegisterEvent("PLAYER_UNGHOST")
eventFrame:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
eventFrame:RegisterEvent("MINIMAP_UPDATE_TRACKING")

eventFrame:SetScript(
    "OnEvent",
    function(self, event, ...)
        local arg1 = ... -- First argument passed by the event
        local db = _G[ADDON_NAME .. "DB"]

        if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
            InitializeSavedVariables()
            PositionButton()
            button:Show()
        elseif event == "PLAYER_LOGIN" then
            -- Reapply tracking shortly after login, ensuring game state is ready
            C_Timer.After(2, ReapplyTracking)
            UpdateButtonIcon()
        elseif event == "PLAYER_ALIVE" or event == "PLAYER_UNGHOST" then
            -- Player has resurrected or released spirit, reapply chosen tracking
            -- Delay slightly to ensure player state is fully updated
            C_Timer.After(0.5, ReapplyTracking)
        elseif event == "UPDATE_SHAPESHIFT_FORM" then
            -- If the selected spell is Druid tracking (ID 5225) and they just shifted *into* Cat Form,
            -- reapply it if it's not already active.
            if db.selectedSpellId == 5225 and IsDruidInCatForm() then
                if not GetTrackingTexture() then -- Check if tracking is already active
                    ReapplyTracking()
                end
            end
            -- Always update the icon state after form change
            UpdateButtonIcon()
        elseif event == "MINIMAP_UPDATE_TRACKING" then
            -- This event fires whenever the active tracking buff changes.
            -- We ONLY update the icon here, not the saved selection.
            UpdateButtonIcon()
        end
    end
)
