local addonName, addon = ...

local AUTO_ATTACK_SPELL_ID = 6603
local UPDATE_INTERVAL = 0.1

local SHAPES = { "square", "circle", "diamond", "triangle" }
addon.SHAPES = SHAPES

local defaults = {
    position = { point = "CENTER", relativePoint = "CENTER", x = 0, y = -150 },
    size = 40,
    shape = "square",
    locked = false,
    rangeSpell = "",
    inRangeColor = { r = 0.20, g = 1.00, b = 0.20, a = 0.90 },
    outOfRangeColor = { r = 1.00, g = 0.20, b = 0.20, a = 0.90 },
}
addon.defaults = defaults

local function CopyDefaults(src, dst)
    if type(dst) ~= "table" then dst = {} end
    for k, v in pairs(src) do
        if type(v) == "table" then
            dst[k] = CopyDefaults(v, dst[k])
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
    return dst
end
addon.CopyDefaults = CopyDefaults

local indicator
local indicatorTex
local updateTimer = 0

local function ApplyShape()
    if not indicator or not indicatorTex then return end
    local shape = MeleeIndicatorDB.shape or "square"
    local size = MeleeIndicatorDB.size or 40

    indicator:SetSize(size, size)
    indicatorTex:ClearAllPoints()
    indicatorTex:SetAllPoints(indicator)
    indicatorTex:SetRotation(0)
    indicatorTex:SetMask(nil)
    if indicatorTex.SetVertexOffset then
        for i = 0, 3 do indicatorTex:SetVertexOffset(i, 0, 0) end
    end

    if shape == "circle" then
        indicatorTex:SetMask("Interface\\CharacterFrame\\TempPortraitAlphaMask")
    elseif shape == "diamond" then
        indicatorTex:SetRotation(math.rad(45))
        local inset = size * 0.15
        indicator:SetSize(size, size)
        indicatorTex:ClearAllPoints()
        indicatorTex:SetPoint("TOPLEFT", indicator, "TOPLEFT", inset, -inset)
        indicatorTex:SetPoint("BOTTOMRIGHT", indicator, "BOTTOMRIGHT", -inset, inset)
    elseif shape == "triangle" then
        if indicatorTex.SetVertexOffset then
            local upperLeft = (Enum and Enum.VertexOffset and Enum.VertexOffset.UpperLeftVertex) or 0
            local upperRight = (Enum and Enum.VertexOffset and Enum.VertexOffset.UpperRightVertex) or 2
            indicatorTex:SetVertexOffset(upperLeft, size / 2, 0)
            indicatorTex:SetVertexOffset(upperRight, -size / 2, 0)
        end
    end
end
addon.ApplyShape = ApplyShape

local function ApplyPosition()
    if not indicator then return end
    local p = MeleeIndicatorDB.position
    indicator:ClearAllPoints()
    indicator:SetPoint(p.point or "CENTER", UIParent, p.relativePoint or p.point or "CENTER", p.x or 0, p.y or 0)
end
addon.ApplyPosition = ApplyPosition

local function ApplyColor(inRange)
    if not indicatorTex then return end
    local c = inRange and MeleeIndicatorDB.inRangeColor or MeleeIndicatorDB.outOfRangeColor
    indicatorTex:SetVertexColor(c.r, c.g, c.b, c.a)
end

local function ApplyLockState()
    if not indicator then return end
    if MeleeIndicatorDB.locked then
        indicator:EnableMouse(false)
        indicator:SetMovable(false)
        if indicator.dragHint then indicator.dragHint:Hide() end
    else
        indicator:EnableMouse(true)
        indicator:SetMovable(true)
        if indicator.dragHint then indicator.dragHint:Show() end
    end
end
addon.ApplyLockState = ApplyLockState

local function ShouldShowIndicator()
    if not UnitExists("target") then return false end
    if UnitIsDead("target") then return false end
    if not UnitCanAttack("player", "target") then return false end
    return true
end

local function ResolveRangeSpell()
    local custom = MeleeIndicatorDB.rangeSpell
    if custom and custom ~= "" then
        if tonumber(custom) then return tonumber(custom) end
        return custom
    end
    return AUTO_ATTACK_SPELL_ID
end

local function IsTargetInMeleeRange()
    local unit = "target"
    local spell = ResolveRangeSpell()
    local inRange

    if C_Spell and C_Spell.IsSpellInRange then
        inRange = C_Spell.IsSpellInRange(spell, unit)
        if inRange == nil and spell ~= AUTO_ATTACK_SPELL_ID then
            inRange = C_Spell.IsSpellInRange(AUTO_ATTACK_SPELL_ID, unit)
        end
        if type(inRange) == "boolean" then return inRange end
        if type(inRange) == "number" then return inRange == 1 end
    end

    if IsSpellInRange then
        local result
        if type(spell) == "number" then
            local info = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(spell)
            if info and info.name then result = IsSpellInRange(info.name, unit) end
        else
            result = IsSpellInRange(spell, unit)
        end
        if result == nil then
            local info = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(AUTO_ATTACK_SPELL_ID)
            if info and info.name then result = IsSpellInRange(info.name, "target") end
        end
        if result == 1 then return true end
        if result == 0 then return false end
    end

    return false
end

local function UpdateIndicator()
    if not indicator then return end
    if MeleeIndicatorDB.locked == false then
        indicator:Show()
        ApplyColor(true)
        return
    end
    if not ShouldShowIndicator() then
        indicator:Hide()
        return
    end
    indicator:Show()
    ApplyColor(IsTargetInMeleeRange())
end
addon.UpdateIndicator = UpdateIndicator

local function CreateIndicator()
    indicator = CreateFrame("Frame", "MeleeIndicatorFrame", UIParent, "BackdropTemplate")
    indicator:SetFrameStrata("MEDIUM")
    indicator:SetClampedToScreen(true)

    indicatorTex = indicator:CreateTexture(nil, "ARTWORK")
    indicatorTex:SetTexture("Interface\\Buttons\\WHITE8X8")
    indicatorTex:SetAllPoints(indicator)

    local hint = indicator:CreateTexture(nil, "OVERLAY")
    hint:SetColorTexture(1, 1, 1, 0.25)
    hint:SetPoint("TOPLEFT", indicator, "TOPLEFT", -2, 2)
    hint:SetPoint("BOTTOMRIGHT", indicator, "BOTTOMRIGHT", 2, -2)
    hint:Hide()
    indicator.dragHint = hint

    indicator:RegisterForDrag("LeftButton")
    indicator:SetScript("OnDragStart", function(self)
        if MeleeIndicatorDB.locked then return end
        self:StartMoving()
    end)
    indicator:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relativePoint, x, y = self:GetPoint()
        MeleeIndicatorDB.position.point = point
        MeleeIndicatorDB.position.relativePoint = relativePoint
        MeleeIndicatorDB.position.x = x
        MeleeIndicatorDB.position.y = y
        if addon.RefreshOptionsPositionFields then
            addon.RefreshOptionsPositionFields()
        end
    end)

    indicator:SetScript("OnUpdate", function(self, elapsed)
        updateTimer = updateTimer + elapsed
        if updateTimer >= UPDATE_INTERVAL then
            updateTimer = 0
            UpdateIndicator()
        end
    end)

    indicator:Hide()
end

local function InitDB()
    MeleeIndicatorDB = CopyDefaults(defaults, MeleeIndicatorDB or {})
end

local function ApplyAll()
    ApplyPosition()
    ApplyShape()
    ApplyLockState()
    UpdateIndicator()
end
addon.ApplyAll = ApplyAll

local function ResetToDefaults()
    MeleeIndicatorDB = CopyDefaults(defaults, {})
    ApplyAll()
    if addon.RefreshOptions then addon.RefreshOptions() end
end
addon.ResetToDefaults = ResetToDefaults

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:RegisterEvent("PLAYER_LOGIN")
loader:RegisterEvent("PLAYER_TARGET_CHANGED")
loader:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        InitDB()
    elseif event == "PLAYER_LOGIN" then
        CreateIndicator()
        ApplyAll()
    elseif event == "PLAYER_TARGET_CHANGED" then
        UpdateIndicator()
    end
end)

local function PrintHelp()
    print("|cff66ccffMelee Indicator|r commands:")
    print("  |cffffff00/melee|r or |cffffff00/mi|r - open options")
    print("  |cffffff00/mi reset|r - reset to defaults")
    print("  |cffffff00/mi lock|r / |cffffff00/mi unlock|r - lock or unlock the indicator")
end

local function HandleSlash(msg)
    msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if msg == "" then
        if addon.ToggleOptions then addon.ToggleOptions() end
    elseif msg == "reset" then
        ResetToDefaults()
        print("|cff66ccffMelee Indicator|r: settings reset to defaults.")
    elseif msg == "lock" then
        MeleeIndicatorDB.locked = true
        ApplyLockState()
        UpdateIndicator()
        if addon.RefreshOptions then addon.RefreshOptions() end
    elseif msg == "unlock" then
        MeleeIndicatorDB.locked = false
        ApplyLockState()
        UpdateIndicator()
        if addon.RefreshOptions then addon.RefreshOptions() end
    elseif msg == "help" or msg == "?" then
        PrintHelp()
    else
        PrintHelp()
    end
end

SLASH_MELEEINDICATOR1 = "/melee"
SLASH_MELEEINDICATOR2 = "/mi"
SlashCmdList["MELEEINDICATOR"] = HandleSlash
