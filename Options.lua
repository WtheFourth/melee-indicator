local addonName, addon = ...

local options
local widgets = {}

local function MakeLabel(parent, text, anchorTo, xOff, yOff)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("TOPLEFT", anchorTo, "BOTTOMLEFT", xOff or 0, yOff or -10)
    fs:SetText(text)
    return fs
end

local function MakeCheckBox(parent, label, onClick)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb.text:SetText(label)
    cb:SetScript("OnClick", function(self)
        onClick(self:GetChecked() and true or false)
    end)
    return cb
end

local function MakeSlider(parent, label, minV, maxV, step, onChanged)
    local slider = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
    slider:SetWidth(220)
    slider:SetMinMaxValues(minV, maxV)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)
    slider.Low:SetText(tostring(minV))
    slider.High:SetText(tostring(maxV))
    slider.Text:SetText(label)
    slider.label = label
    local valueText = slider:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    valueText:SetPoint("TOP", slider, "BOTTOM", 0, 2)
    slider.valueText = valueText
    slider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value / step + 0.5) * step
        self.valueText:SetText(tostring(value))
        onChanged(value)
    end)
    return slider
end

local function MakeButton(parent, label, width, onClick)
    local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btn:SetSize(width or 100, 22)
    btn:SetText(label)
    btn:SetScript("OnClick", onClick)
    return btn
end

local function MakeEditBox(parent, width)
    local eb = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    eb:SetAutoFocus(false)
    eb:SetSize(width or 60, 20)
    eb:SetFontObject(ChatFontNormal)
    return eb
end

local dropdownCounter = 0
local function MakeDropdown(parent, width, getItems, getValue, setValue)
    dropdownCounter = dropdownCounter + 1
    local dd = CreateFrame("Frame", "MeleeIndicatorDropdown" .. dropdownCounter, parent, "UIDropDownMenuTemplate")
    UIDropDownMenu_SetWidth(dd, width or 160)

    local function SetTextFromValue()
        local current = getValue()
        local label
        for _, item in ipairs(getItems()) do
            if item.path == current then
                label = item.name
                break
            end
        end
        UIDropDownMenu_SetText(dd, label or "Custom")
    end

    UIDropDownMenu_Initialize(dd, function(self, level)
        local current = getValue()
        for _, item in ipairs(getItems()) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = item.name
            info.value = item.path
            info.checked = (item.path == current)
            info.func = function()
                setValue(item.path)
                SetTextFromValue()
                CloseDropDownMenus()
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)

    dd.Refresh = SetTextFromValue
    SetTextFromValue()
    return dd
end

local function ShowColorPicker(r, g, b, a, onChange)
    local function apply()
        local nr, ng, nb = ColorPickerFrame:GetColorRGB()
        local na = ColorPickerFrame.GetColorAlpha and ColorPickerFrame:GetColorAlpha() or (1 - (OpacitySliderFrame and OpacitySliderFrame:GetValue() or 0))
        onChange(nr, ng, nb, na)
    end
    local function cancel(prev)
        if prev then
            onChange(prev.r, prev.g, prev.b, prev.opacity or prev.a or 1)
        end
    end

    if ColorPickerFrame.SetupColorPickerAndShow then
        ColorPickerFrame:SetupColorPickerAndShow({
            swatchFunc = apply,
            opacityFunc = apply,
            cancelFunc = cancel,
            hasOpacity = true,
            opacity = a,
            r = r, g = g, b = b,
        })
    else
        ColorPickerFrame.func = apply
        ColorPickerFrame.opacityFunc = apply
        ColorPickerFrame.cancelFunc = cancel
        ColorPickerFrame.hasOpacity = true
        ColorPickerFrame.opacity = a
        ColorPickerFrame.previousValues = { r = r, g = g, b = b, opacity = a }
        ColorPickerFrame:SetColorRGB(r, g, b)
        ColorPickerFrame:Hide()
        ColorPickerFrame:Show()
    end
end

local function MakeColorSwatch(parent, label, getColor, setColor)
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(180, 24)

    local swatch = CreateFrame("Button", nil, container)
    swatch:SetSize(24, 24)
    swatch:SetPoint("LEFT", container, "LEFT", 0, 0)
    swatch:SetNormalTexture("Interface\\Buttons\\WHITE8X8")
    local border = swatch:CreateTexture(nil, "OVERLAY")
    border:SetPoint("TOPLEFT", -1, 1)
    border:SetPoint("BOTTOMRIGHT", 1, -1)
    border:SetColorTexture(0, 0, 0, 1)
    border:SetDrawLayer("BACKGROUND")
    swatch:SetScript("OnClick", function()
        local c = getColor()
        ShowColorPicker(c.r, c.g, c.b, c.a, function(r, g, b, a)
            setColor(r, g, b, a)
            local tex = swatch:GetNormalTexture()
            tex:SetVertexColor(r, g, b, a)
        end)
    end)

    local fs = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("LEFT", swatch, "RIGHT", 8, 0)
    fs:SetText(label)

    container.swatch = swatch
    container.Refresh = function()
        local c = getColor()
        swatch:GetNormalTexture():SetVertexColor(c.r, c.g, c.b, c.a)
    end
    container.Refresh()

    return container
end

local function BuildOptions()
    options = CreateFrame("Frame", "MeleeIndicatorOptions", UIParent, "BackdropTemplate")
    options:SetSize(360, 700)
    options:SetPoint("CENTER")
    options:SetFrameStrata("HIGH")
    options:SetMovable(true)
    options:EnableMouse(true)
    options:RegisterForDrag("LeftButton")
    options:SetScript("OnDragStart", options.StartMoving)
    options:SetScript("OnDragStop", options.StopMovingOrSizing)
    options:SetClampedToScreen(true)
    options:Hide()

    if options.SetBackdrop then
        options:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 32,
            insets = { left = 8, right = 8, top = 8, bottom = 8 },
        })
    end

    local title = options:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -16)
    title:SetText("Melee Indicator")

    local close = CreateFrame("Button", nil, options, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -4, -4)

    local lockCb = MakeCheckBox(options, "Lock indicator (uncheck to drag)", function(checked)
        MeleeIndicatorDB.locked = checked
        addon.ApplyLockState()
        addon.UpdateIndicator()
    end)
    lockCb:SetPoint("TOPLEFT", 20, -48)
    widgets.lockCb = lockCb

    local shapeLabel = MakeLabel(options, "Shape:", lockCb, 0, -8)
    local shapeButtons = {}
    local shapeX = 0
    for i, shape in ipairs(addon.SHAPES) do
        local btn = CreateFrame("Button", nil, options, "UIPanelButtonTemplate")
        btn:SetSize(70, 22)
        btn:SetText(shape:sub(1, 1):upper() .. shape:sub(2))
        btn:SetPoint("TOPLEFT", shapeLabel, "BOTTOMLEFT", shapeX, -4)
        btn:SetScript("OnClick", function()
            MeleeIndicatorDB.shape = shape
            addon.ApplyShape()
            for _, b in ipairs(shapeButtons) do
                b:UnlockHighlight()
            end
            btn:LockHighlight()
        end)
        shapeX = shapeX + 75
        shapeButtons[i] = btn
        btn.shape = shape
    end
    widgets.shapeButtons = shapeButtons

    local sizeSlider = MakeSlider(options, "Size", 16, 128, 1, function(value)
        MeleeIndicatorDB.size = value
        addon.ApplyShape()
    end)
    sizeSlider:SetPoint("TOPLEFT", shapeButtons[1], "BOTTOMLEFT", 4, -24)
    widgets.sizeSlider = sizeSlider

    local borderHeader = options:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    borderHeader:SetPoint("TOPLEFT", sizeSlider, "BOTTOMLEFT", -4, -24)
    borderHeader:SetText("Border:")

    local borderDropdown = MakeDropdown(options, 180, addon.GetBorderTextureChoices,
        function() return MeleeIndicatorDB.border.texture end,
        function(path)
            MeleeIndicatorDB.border.texture = path
            addon.ApplyBorder()
        end)
    borderDropdown:SetPoint("TOPLEFT", borderHeader, "BOTTOMLEFT", -16, -2)
    widgets.borderDropdown = borderDropdown

    local borderSizeSlider = MakeSlider(options, "Border thickness (0 = off)", 0, 8, 1, function(value)
        MeleeIndicatorDB.border.size = value
        addon.ApplyShape()
        addon.ApplyBorder()
    end)
    borderSizeSlider:SetPoint("TOPLEFT", borderDropdown, "BOTTOMLEFT", 20, -16)
    widgets.borderSizeSlider = borderSizeSlider

    local borderSwatch = MakeColorSwatch(options, "Border color",
        function() return MeleeIndicatorDB.border.color end,
        function(r, g, b, a)
            local c = MeleeIndicatorDB.border.color
            c.r, c.g, c.b, c.a = r, g, b, a
            addon.ApplyBorder()
        end)
    borderSwatch:SetPoint("TOPLEFT", borderSizeSlider, "BOTTOMLEFT", -20, -18)
    widgets.borderSwatch = borderSwatch

    local posLabel = MakeLabel(options, "Position (drag indicator or type X/Y):", borderSwatch, 0, -16)

    local xLabel = options:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    xLabel:SetPoint("TOPLEFT", posLabel, "BOTTOMLEFT", 0, -10)
    xLabel:SetText("X:")
    local xEdit = MakeEditBox(options, 70)
    xEdit:SetPoint("LEFT", xLabel, "RIGHT", 6, 0)
    xEdit:SetNumeric(false)
    xEdit:SetScript("OnEnterPressed", function(self)
        local v = tonumber(self:GetText())
        if v then
            MeleeIndicatorDB.position.x = v
            addon.ApplyPosition()
        end
        self:ClearFocus()
    end)
    xEdit:SetScript("OnEscapePressed", EditBox_ClearFocus)

    local yLabel = options:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    yLabel:SetPoint("LEFT", xEdit, "RIGHT", 16, 0)
    yLabel:SetText("Y:")
    local yEdit = MakeEditBox(options, 70)
    yEdit:SetPoint("LEFT", yLabel, "RIGHT", 6, 0)
    yEdit:SetNumeric(false)
    yEdit:SetScript("OnEnterPressed", function(self)
        local v = tonumber(self:GetText())
        if v then
            MeleeIndicatorDB.position.y = v
            addon.ApplyPosition()
        end
        self:ClearFocus()
    end)
    yEdit:SetScript("OnEscapePressed", EditBox_ClearFocus)

    widgets.xEdit = xEdit
    widgets.yEdit = yEdit

    local centerBtn = MakeButton(options, "Center", 70, function()
        MeleeIndicatorDB.position.point = "CENTER"
        MeleeIndicatorDB.position.relativePoint = "CENTER"
        MeleeIndicatorDB.position.x = 0
        MeleeIndicatorDB.position.y = -150
        addon.ApplyPosition()
        addon.RefreshOptionsPositionFields()
    end)
    centerBtn:SetPoint("LEFT", yEdit, "RIGHT", 12, 0)

    local inSwatch = MakeColorSwatch(options, "In-range color",
        function() return MeleeIndicatorDB.inRangeColor end,
        function(r, g, b, a)
            local c = MeleeIndicatorDB.inRangeColor
            c.r, c.g, c.b, c.a = r, g, b, a
            addon.UpdateIndicator()
        end)
    inSwatch:SetPoint("TOPLEFT", xLabel, "BOTTOMLEFT", 0, -22)
    widgets.inSwatch = inSwatch

    local outSwatch = MakeColorSwatch(options, "Out-of-range color",
        function() return MeleeIndicatorDB.outOfRangeColor end,
        function(r, g, b, a)
            local c = MeleeIndicatorDB.outOfRangeColor
            c.r, c.g, c.b, c.a = r, g, b, a
            addon.UpdateIndicator()
        end)
    outSwatch:SetPoint("TOPLEFT", inSwatch, "BOTTOMLEFT", 0, -8)
    widgets.outSwatch = outSwatch

    local spellLabel = MakeLabel(options, "Range spell (name or ID, blank = Auto Attack):", outSwatch, 0, -16)
    local spellEdit = MakeEditBox(options, 200)
    spellEdit:SetPoint("TOPLEFT", spellLabel, "BOTTOMLEFT", 0, -6)
    spellEdit:SetScript("OnEnterPressed", function(self)
        MeleeIndicatorDB.rangeSpell = self:GetText() or ""
        self:ClearFocus()
        addon.UpdateIndicator()
    end)
    spellEdit:SetScript("OnEscapePressed", EditBox_ClearFocus)
    widgets.spellEdit = spellEdit

    local resetBtn = MakeButton(options, "Reset to defaults", 140, function()
        addon.ResetToDefaults()
    end)
    resetBtn:SetPoint("BOTTOM", 0, 16)
end

local function RefreshOptions()
    if not options then return end
    widgets.lockCb:SetChecked(MeleeIndicatorDB.locked and true or false)
    for _, b in ipairs(widgets.shapeButtons) do
        if b.shape == MeleeIndicatorDB.shape then
            b:LockHighlight()
        else
            b:UnlockHighlight()
        end
    end
    widgets.sizeSlider:SetValue(MeleeIndicatorDB.size)
    widgets.sizeSlider.valueText:SetText(tostring(MeleeIndicatorDB.size))
    widgets.borderSizeSlider:SetValue(MeleeIndicatorDB.border.size or 0)
    widgets.borderSizeSlider.valueText:SetText(tostring(MeleeIndicatorDB.border.size or 0))
    widgets.borderDropdown.Refresh()
    widgets.borderSwatch.Refresh()
    widgets.xEdit:SetText(tostring(MeleeIndicatorDB.position.x or 0))
    widgets.yEdit:SetText(tostring(MeleeIndicatorDB.position.y or 0))
    widgets.spellEdit:SetText(MeleeIndicatorDB.rangeSpell or "")
    widgets.inSwatch.Refresh()
    widgets.outSwatch.Refresh()
end
addon.RefreshOptions = RefreshOptions

local function RefreshOptionsPositionFields()
    if not options then return end
    widgets.xEdit:SetText(tostring(math.floor((MeleeIndicatorDB.position.x or 0) + 0.5)))
    widgets.yEdit:SetText(tostring(math.floor((MeleeIndicatorDB.position.y or 0) + 0.5)))
end
addon.RefreshOptionsPositionFields = RefreshOptionsPositionFields

local function ToggleOptions()
    if not options then BuildOptions() end
    if options:IsShown() then
        options:Hide()
    else
        RefreshOptions()
        options:Show()
    end
end
addon.ToggleOptions = ToggleOptions
