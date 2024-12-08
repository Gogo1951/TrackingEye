local TrackingEye = {}
local LDB = LibStub:GetLibrary("LibDataBroker-1.1")
local icon = LibStub:GetLibrary("LibDBIcon-1.0")

-- Error reporting utility
local function ReportError(message)
    print("|cffff0000[TrackingEye Error]:|r " .. message)
end

-- Ensure EasyMenu library is loaded
if not EasyMenu and not LoadAddOn("Blizzard_UIDropDownMenu") then
    function EasyMenu(menuList, menuFrame, anchor, xOffset, yOffset, displayMode, autoHideDelay)
        local frameName = menuFrame and menuFrame:GetName() or nil
        menuFrame = menuFrame or CreateFrame("Frame", "EasyMenuDummyFrame", UIParent, "UIDropDownMenuTemplate")
        UIDropDownMenu_Initialize(
            menuFrame,
            function(_, level)
                for _, info in ipairs(menuList) do
                    UIDropDownMenu_AddButton(info, level)
                end
            end,
            displayMode
        )
        ToggleDropDownMenu(1, nil, menuFrame, anchor, xOffset, yOffset, menuList, nil, autoHideDelay)
    end
end

-- Default saved variables
local TrackingEyeDB

-- Tracking abilities
local trackingAbilities = {
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

TrackingEye.SelectedAbility = nil

-- DataBroker object for minimap button
local trackingDataBroker =
    LDB:NewDataObject(
    "TrackingEye",
    {
        type = "data source",
        text = "TrackingEye",
        icon = "Interface\\Icons\\inv_misc_map_01",
        OnClick = function()
            TrackingEye:OpenTrackingMenu()
        end
    }
)

function TrackingEye:ToggleMinimapButton()
    local hide = not TrackingEyeDB.minimap.hide
    TrackingEyeDB.minimap.hide = hide
    icon[hide and "Hide" or "Show"](icon, "TrackingEye")
end

-- Reapply selected tracking ability
local function ReapplyTrackingAbility()
    local ability = TrackingEye.SelectedAbility
    if ability and IsPlayerSpell(ability) then
        if ability == 5225 and not select(5, GetShapeshiftFormInfo(3)) then
            ReportError("You must be in Cat Form to use Track Humanoids.")
            return
        end
        CastSpellByID(ability)
    end
end

-- Cast a specific tracking ability
local function CastTrackingAbility(spellId)
    if not trackingAbilities[spellId] then
        ReportError("Invalid tracking ability ID.")
        return
    end
    TrackingEye.SelectedAbility = spellId
    CastSpellByID(spellId)
end

-- Build the tracking menu
local function BuildTrackingMenu()
    local menu = {
        {text = "|cffffd517Select Tracking Ability|r", isTitle = true, notCheckable = true},
        {text = " ", isTitle = true, notCheckable = true, disabled = true}
    }

    local availableAbilities = {}
    for spellId, name in pairs(trackingAbilities) do
        if IsPlayerSpell(spellId) then
            table.insert(availableAbilities, {name = name, id = spellId, texture = GetSpellTexture(spellId)})
        end
    end

    if #availableAbilities == 0 then
        table.insert(menu, {text = "|cffff0000No tracking abilities.|r", isTitle = true, notCheckable = true})
    else
        table.sort(
            availableAbilities,
            function(a, b)
                return a.name < b.name
            end
        )
        for _, ability in ipairs(availableAbilities) do
            table.insert(
                menu,
                {
                    text = ability.name,
                    icon = ability.texture,
                    checked = (TrackingEye.SelectedAbility == ability.id),
                    func = function()
                        CastTrackingAbility(ability.id)
                    end
                }
            )
        end
    end
    return menu
end

function TrackingEye:OpenTrackingMenu()
    EasyMenu(BuildTrackingMenu(), TrackingEye.MenuFrame, "cursor", 0, 0, "MENU")
end

-- Event handling
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGOUT")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_ALIVE")
eventFrame:RegisterEvent("PLAYER_UNGHOST")
eventFrame:RegisterEvent("MINIMAP_UPDATE_TRACKING")
eventFrame:SetScript(
    "OnEvent",
    function(_, event, addon)
        if event == "ADDON_LOADED" and addon == "TrackingEye" then
            TrackingEyeDB = _G.TrackingEyeDB or {minimap = {hide = false}}
            icon:Register("TrackingEye", trackingDataBroker, TrackingEyeDB.minimap)
            if TrackingEyeDB.minimap.hide then
                icon:Hide("TrackingEye")
            end
        elseif event == "PLAYER_ALIVE" or event == "PLAYER_UNGHOST" then
            if not UnitIsDeadOrGhost("player") then
                ReapplyTrackingAbility()
            end
        elseif event == "MINIMAP_UPDATE_TRACKING" then
            trackingDataBroker.icon = GetTrackingTexture() or "Interface\\Icons\\inv_misc_map_01"
        end
    end
)

if MiniMapTrackingFrame then
    MiniMapTrackingFrame:Hide()
end
