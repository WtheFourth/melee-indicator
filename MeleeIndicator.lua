local addonName, addon = ...

local AUTO_ATTACK_SPELL_ID = 6603
local UPDATE_INTERVAL = 0.1

local SHAPES = { "square", "circle", "diamond", "triangle" }
addon.SHAPES = SHAPES

local BORDER_TEXTURES = {
    { name = "Solid",            path = "Interface\\Buttons\\WHITE8X8" },
    { name = "Tooltip",          path = "Interface\\Tooltips\\UI-Tooltip-Border" },
    { name = "Dialog",           path = "Interface\\DialogFrame\\UI-DialogBox-Border" },
    { name = "Chat Background",  path = "Interface\\ChatFrame\\ChatFrameBackground" },
    { name = "Achievement Wood", path = "Interface\\AchievementFrame\\UI-Achievement-WoodBorder" },
    { name = "Text Panel",       path = "Interface\\GLUES\\COMMON\\TextPanel-Border" },
}
addon.BORDER_TEXTURES = BORDER_TEXTURES

function addon.GetBorderTextureChoices()
    local list = {}
    for _, t in ipairs(BORDER_TEXTURES) do
        list[#list + 1] = { name = t.name, path = t.path }
    end
    if LibStub then
        local ok, LSM = pcall(LibStub, "LibSharedMedia-3.0", true)
        if ok and LSM and LSM.List then
            local names = LSM:List("border")
            if names then
                for _, name in ipairs(names) do
                    list[#list + 1] = { name = "LSM: " .. name, path = LSM:Fetch("border", name) }
                end
            end
        end
    end
    return list
end

local defaults = {
    position = { point = "CENTER", relativePoint = "CENTER", x = 0, y = -150 },
    size = 40,
    shape = "square",
    locked = false,
    rangeSpell = "",
    rangeSpellBySpec = {},
    inRangeColor = { r = 0.20, g = 1.00, b = 0.20, a = 0.90 },
    outOfRangeColor = { r = 1.00, g = 0.20, b = 0.20, a = 0.90 },
    border = {
        texture = "Interface\\Buttons\\WHITE8X8",
        size = 1,
        color = { r = 0.00, g = 0.00, b = 0.00, a = 1.00 },
    },
}
addon.defaults = defaults

function addon.GetCurrentSpecID()
    if not GetSpecialization then return nil end
    local idx = GetSpecialization()
    if not idx or idx < 1 then return nil end
    if not GetSpecializationInfo then return nil end
    local id = GetSpecializationInfo(idx)
    return id
end

function addon.GetCurrentSpecName()
    if not GetSpecialization then return nil end
    local idx = GetSpecialization()
    if not idx or idx < 1 then return nil end
    if not GetSpecializationInfo then return nil end
    local _, name = GetSpecializationInfo(idx)
    return name
end

function addon.GetActiveRangeSpellSetting()
    local specID = addon.GetCurrentSpecID()
    if specID then
        local v = MeleeIndicatorDB.rangeSpellBySpec and MeleeIndicatorDB.rangeSpellBySpec[specID]
        if v and v ~= "" then return v end
    end
    return MeleeIndicatorDB.rangeSpell or ""
end

function addon.SetActiveRangeSpellSetting(value)
    value = value or ""
    local specID = addon.GetCurrentSpecID()
    if specID then
        MeleeIndicatorDB.rangeSpellBySpec = MeleeIndicatorDB.rangeSpellBySpec or {}
        MeleeIndicatorDB.rangeSpellBySpec[specID] = value
    else
        MeleeIndicatorDB.rangeSpell = value
    end
end

local spellChoiceCache
function addon.GetSpellChoices(forceRefresh)
    if spellChoiceCache and not forceRefresh then return spellChoiceCache end
    local seen = {}
    local list = { { id = 0, name = "Auto Attack (default)", value = "" } }
    if C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines and C_SpellBook.GetSpellBookItemInfo then
        local bank = (Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player) or 0
        local spellType = Enum and Enum.SpellBookItemType and Enum.SpellBookItemType.Spell
        local numLines = C_SpellBook.GetNumSpellBookSkillLines() or 0
        for line = 1, numLines do
            local lineInfo = C_SpellBook.GetSpellBookSkillLineInfo(line)
            if lineInfo and not lineInfo.shouldHide then
                local offset = lineInfo.itemIndexOffset or 0
                local count = lineInfo.numSpellBookItems or 0
                for i = 1, count do
                    local info = C_SpellBook.GetSpellBookItemInfo(offset + i, bank)
                    if info and info.spellID and info.name and not seen[info.spellID] then
                        local isSpell = (spellType == nil) or (info.itemType == spellType)
                        local isPassive = C_Spell and C_Spell.IsSpellPassive and C_Spell.IsSpellPassive(info.spellID)
                        if isSpell and not isPassive then
                            seen[info.spellID] = true
                            list[#list + 1] = { id = info.spellID, name = info.name, value = tostring(info.spellID) }
                        end
                    end
                end
            end
        end
    end
    table.sort(list, function(a, b)
        if a.id == 0 then return true end
        if b.id == 0 then return false end
        return a.name < b.name
    end)
    spellChoiceCache = list
    return list
end

function addon.InvalidateSpellChoices()
    spellChoiceCache = nil
end

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
local borderTex
local updateTimer = 0

local CIRCLE_MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"

local function ResetTexture(tex)
    tex:ClearAllPoints()
    tex:SetRotation(0)
    tex:SetMask(nil)
    if tex.SetVertexOffset then
        for i = 0, 3 do tex:SetVertexOffset(i, 0, 0) end
    end
end

local function GetTriangleVertexIndices()
    local upperLeft = (Enum and Enum.VertexOffset and Enum.VertexOffset.UpperLeftVertex) or 0
    local upperRight = (Enum and Enum.VertexOffset and Enum.VertexOffset.UpperRightVertex) or 2
    return upperLeft, upperRight
end

local function ApplyShape()
    if not indicator or not indicatorTex or not borderTex then return end
    local shape = MeleeIndicatorDB.shape or "square"
    local size = MeleeIndicatorDB.size or 40
    local b = MeleeIndicatorDB.border or {}
    local borderSize = (b.size and b.size > 0) and b.size or 0

    indicator:SetSize(size, size)
    ResetTexture(borderTex)
    ResetTexture(indicatorTex)

    if shape == "square" then
        borderTex:SetAllPoints(indicator)
        indicatorTex:SetPoint("TOPLEFT", indicator, "TOPLEFT", borderSize, -borderSize)
        indicatorTex:SetPoint("BOTTOMRIGHT", indicator, "BOTTOMRIGHT", -borderSize, borderSize)
    elseif shape == "circle" then
        borderTex:SetAllPoints(indicator)
        borderTex:SetMask(CIRCLE_MASK)
        indicatorTex:SetPoint("TOPLEFT", indicator, "TOPLEFT", borderSize, -borderSize)
        indicatorTex:SetPoint("BOTTOMRIGHT", indicator, "BOTTOMRIGHT", -borderSize, borderSize)
        indicatorTex:SetMask(CIRCLE_MASK)
    elseif shape == "diamond" then
        local inset = size * 0.146
        borderTex:SetPoint("TOPLEFT", indicator, "TOPLEFT", inset, -inset)
        borderTex:SetPoint("BOTTOMRIGHT", indicator, "BOTTOMRIGHT", -inset, inset)
        borderTex:SetRotation(math.rad(45))
        indicatorTex:SetPoint("TOPLEFT", indicator, "TOPLEFT", inset + borderSize, -(inset + borderSize))
        indicatorTex:SetPoint("BOTTOMRIGHT", indicator, "BOTTOMRIGHT", -(inset + borderSize), inset + borderSize)
        indicatorTex:SetRotation(math.rad(45))
    elseif shape == "triangle" then
        borderTex:SetAllPoints(indicator)
        indicatorTex:SetPoint("TOPLEFT", indicator, "TOPLEFT", borderSize, -borderSize)
        indicatorTex:SetPoint("BOTTOMRIGHT", indicator, "BOTTOMRIGHT", -borderSize, borderSize)
        if borderTex.SetVertexOffset then
            local upperLeft, upperRight = GetTriangleVertexIndices()
            borderTex:SetVertexOffset(upperLeft, size / 2, 0)
            borderTex:SetVertexOffset(upperRight, -size / 2, 0)
            local innerSize = size - 2 * borderSize
            if innerSize < 0 then innerSize = 0 end
            indicatorTex:SetVertexOffset(upperLeft, innerSize / 2, 0)
            indicatorTex:SetVertexOffset(upperRight, -innerSize / 2, 0)
        end
    end
end
addon.ApplyShape = ApplyShape

local function ApplyBorder()
    if not borderTex then return end
    local b = MeleeIndicatorDB.border or {}
    borderTex:SetTexture(b.texture or "Interface\\Buttons\\WHITE8X8")
    local c = b.color or { r = 0, g = 0, b = 0, a = 1 }
    borderTex:SetVertexColor(c.r, c.g, c.b, c.a)
    if (b.size or 0) <= 0 then
        borderTex:Hide()
    else
        borderTex:Show()
    end
end
addon.ApplyBorder = ApplyBorder

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
    local custom = addon.GetActiveRangeSpellSetting()
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

    borderTex = indicator:CreateTexture(nil, "BACKGROUND")
    borderTex:SetTexture("Interface\\Buttons\\WHITE8X8")
    borderTex:SetAllPoints(indicator)

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
    ApplyBorder()
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
loader:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
loader:RegisterEvent("SPELLS_CHANGED")
loader:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        InitDB()
    elseif event == "PLAYER_LOGIN" then
        CreateIndicator()
        ApplyAll()
    elseif event == "PLAYER_TARGET_CHANGED" then
        UpdateIndicator()
    elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
        UpdateIndicator()
        if addon.RefreshOptions then addon.RefreshOptions() end
    elseif event == "SPELLS_CHANGED" then
        addon.InvalidateSpellChoices()
        if addon.RefreshOptions then addon.RefreshOptions() end
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
