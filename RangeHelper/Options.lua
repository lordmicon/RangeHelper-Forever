----------------------------------------------------------------------
-- RangeHelper settings window + Options > AddOns panel
-- Opened with /rh (or the button in Options > AddOns > RangeHelper).
----------------------------------------------------------------------
local RH = RangeHelper
if not RH then return end

local win, built
local refreshers = {}

local function DB() return RH.GetDB() end

-- Try several templates; use the first one this client knows about.
local function TryCreate(frameType, name, parent, templates)
    for _, tpl in ipairs(templates) do
        local ok, obj = pcall(CreateFrame, frameType, name, parent, tpl)
        if ok and obj then return obj, tpl end
    end
    return CreateFrame(frameType, name, parent)
end

local function Label(parent, fontObject, text, x, y, width)
    local fs = parent:CreateFontString(nil, "OVERLAY", fontObject)
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    fs:SetJustifyH("LEFT")
    if width then fs:SetWidth(width) end
    fs:SetText(text)
    return fs
end

local function Header(parent, text, x, y)
    return Label(parent, "GameFontHighlightLarge", text, x, y)
end

local function HasAtlas(name)
    return C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(name) ~= nil
end

----------------------------------------------------------------------
-- A group of radio buttons that all edit one setting.
-- items = { { value, label, description }, ... }  returns the next free y
----------------------------------------------------------------------
local function RadioGroup(parent, x, y, key, items)
    local buttons = {}
    for _, item in ipairs(items) do
        local value, label, desc = item[1], item[2], item[3]
        local b = TryCreate("CheckButton", nil, parent, { "UIRadioButtonTemplate", "UICheckButtonTemplate" })
        b:SetSize(22, 22)
        b:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
        Label(parent, "GameFontNormal", label, x + 26, y - 4)
        if desc then
            Label(parent, "GameFontDisableSmall", desc, x + 26, y - 19, 270)
        end
        b:SetScript("OnClick", function()
            DB()[key] = value
            RH.Refresh()
        end)
        buttons[#buttons + 1] = { button = b, value = value }
        y = y - (desc and 40 or 26)
    end
    refreshers[#refreshers + 1] = function()
        for _, e in ipairs(buttons) do e.button:SetChecked(DB()[key] == e.value) end
    end
    return y
end

----------------------------------------------------------------------
-- A  [-] value [+]  control that edits one number setting.
----------------------------------------------------------------------
local function ArrowButton(parent, direction)
    -- direction = "Left" or "Right". Uses the same arrow art as the Options sliders when
    -- this client has it; otherwise falls back to a plain  -  /  +  button.
    local base = "Minimal_SliderBar_Button_" .. direction
    if HasAtlas(base) then
        local b = CreateFrame("Button", nil, parent)
        b:SetSize(14, 20)
        pcall(function()
            b:SetNormalAtlas(base)
            if HasAtlas(base .. "_Pressed") then b:SetPushedAtlas(base .. "_Pressed") end
            if HasAtlas(base .. "_Disabled") then b:SetDisabledAtlas(base .. "_Disabled") end
            if HasAtlas(base .. "_Highlight") then b:SetHighlightAtlas(base .. "_Highlight") end
        end)
        return b
    end
    local b = TryCreate("Button", nil, parent, { "UIPanelButtonTemplate" })
    b:SetSize(22, 22)
    b:SetText(direction == "Left" and "-" or "+")
    return b
end

local function Stepper(parent, x, y, key, text, minV, maxV, step, tip)
    Label(parent, "GameFontNormal", text, x, y - 4)
    local minus = ArrowButton(parent, "Left")
    minus:SetPoint("TOPLEFT", parent, "TOPLEFT", x + 185, y - 1)

    local valueFS = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    valueFS:SetPoint("LEFT", minus, "RIGHT", 0, 0)
    valueFS:SetWidth(40)
    valueFS:SetJustifyH("CENTER")

    local plus = ArrowButton(parent, "Right")
    plus:SetPoint("LEFT", minus, "RIGHT", 40, 0)

    local function change(delta)
        local v = (DB()[key] or 0) + delta
        if v < minV then v = minV elseif v > maxV then v = maxV end
        DB()[key] = v
        RH.Refresh()
    end
    minus:SetScript("OnClick", function() change(-step) end)
    plus:SetScript("OnClick", function() change(step) end)

    if tip then
        for _, w in ipairs({ minus, plus }) do
            w:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(tip, 1, 1, 1, 1, true)
            end)
            w:SetScript("OnLeave", function() GameTooltip:Hide() end)
        end
    end

    refreshers[#refreshers + 1] = function() valueFS:SetText(tostring(DB()[key])) end
    return y - 28
end

local function Button(parent, text, width, point, rel, relPoint, x, y, onClick)
    local b = TryCreate("Button", nil, parent, { "UIPanelButtonTemplate" })
    b:SetSize(width, 22)
    b:SetText(text)
    b:SetPoint(point, rel, relPoint, x, y)
    b:SetScript("OnClick", onClick)
    return b
end

----------------------------------------------------------------------
-- Build the window (once, on first open)
----------------------------------------------------------------------
local function Build()
    if built then return end
    built = true

    -- Same frame style the game's Options window uses (brown border + inset + bottom bar).
    local frame, tpl = TryCreate("Frame", "RangeHelperOptions", UIParent,
        { "ButtonFrameTemplateNoPortrait", "ButtonFrameTemplate", "BasicFrameTemplateWithInset", "BackdropTemplate" })
    win = frame
    win:SetSize(700, 540)
    win:SetPoint("CENTER")
    win:SetFrameStrata("DIALOG")
    win:SetMovable(true)
    win:SetClampedToScreen(true)
    win:EnableMouse(true)
    win:RegisterForDrag("LeftButton")
    win:SetScript("OnDragStart", win.StartMoving)
    win:SetScript("OnDragStop", win.StopMovingOrSizing)

    local isButtonFrame = (tpl == "ButtonFrameTemplateNoPortrait" or tpl == "ButtonFrameTemplate")
    if tpl == "ButtonFrameTemplate" then
        pcall(function()
            if ButtonFrameTemplate_HidePortrait then ButtonFrameTemplate_HidePortrait(win) end
        end)
    end
    if isButtonFrame and win.Inset then
        win.Inset:ClearAllPoints()
        win.Inset:SetPoint("TOPLEFT", win, "TOPLEFT", 4, -26)
        win.Inset:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -6, 28)
    end

    if not isButtonFrame and tpl ~= "BasicFrameTemplateWithInset" then
        -- plain fallback look
        if win.SetBackdrop then
            win:SetBackdrop({
                bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
                edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
                tile = true, tileSize = 32, edgeSize = 32,
                insets = { left = 8, right = 8, top = 8, bottom = 8 },
            })
        end
        local close = TryCreate("Button", nil, win, { "UIPanelCloseButton" })
        close:SetPoint("TOPRIGHT", win, "TOPRIGHT", -4, -4)
    end

    -- Title: use the frame's own title bar when it has one; normal-size font so it fits.
    if isButtonFrame and win.SetTitle then
        win:SetTitle("RangeHelper Settings")
    else
        local title = win:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("TOP", win, "TOP", 0, -6)
        title:SetText("RangeHelper Settings")
    end

    tinsert(UISpecialFrames, "RangeHelperOptions") -- ESC closes it

    -- ===== LEFT COLUMN =====
    local lx = 20
    local y = -38
    Header(win, "Which mobs show the text?", lx, y); y = y - 28
    y = RadioGroup(win, lx, y, "mode", {
        { "TARGET",     "Target only",   "Just your target (anything you can attack), in or out of combat. (Default)" },
        { "ENEMY",      "Hostile mobs",  "Red mobs only. Skips yellow (neutral) mobs." },
        { "ATTACKABLE", "Red + yellow",  "Anything you could attack: hostile and neutral mobs." },
        { "ALL",        "Everything",    "Every mob with a nameplate, even friendly ones." },
    })

    y = y - 8
    Header(win, "Where does the text appear?", lx, y); y = y - 28
    y = RadioGroup(win, lx, y, "display", {
        { "PLATE", "Over the nameplate",    "Above the mob's head. Needs enemy nameplates ON (press V)." },
        { "PANEL", "Over the target panel", "Above your target frame, for your target only." },
        { "BOTH",  "Both",                  "Show it in both places. (Default)" },
    })

    -- ===== RIGHT COLUMN =====
    local rx = 350
    local ry = -38
    Header(win, "How it looks", rx, ry); ry = ry - 28
    ry = Stepper(win, rx, ry, "fontSize",    "Text size",                8, 40, 1)
    ry = Stepper(win, rx, ry, "yOffset",     "Height over nameplate",  -30, 80, 2,
        "Raise or lower the text above a mob's nameplate.")
    ry = Stepper(win, rx, ry, "panelOffset", "Height over target panel", -30, 80, 2,
        "Raise or lower the text above your target panel.")

    ry = ry - 6
    Header(win, "Where does the panel text sit?", rx, ry); ry = ry - 28
    ry = RadioGroup(win, rx, ry, "anchor", {
        { "TARGETFRAME", "Above the target panel" },
        { "CUSTOM",      "My own spot (use Move Text below)" },
    })

    ry = ry - 6
    Header(win, "Color warnings", rx, ry); ry = ry - 28
    ry = Stepper(win, rx, ry, "nearYellow", "Yellow near dead zone (yd)", 0, 10, 1,
        "Turn yellow when you are this many yards above the dead zone. Bigger = earlier warning as you close in.")
    ry = Stepper(win, rx, ry, "yellowEdge", "Yellow near max range (yd)", 1, 20, 1,
        "Turn yellow when you are this many yards from your max range.")
    ry = Stepper(win, rx, ry, "redEdge",    "Red near max range (yd)",    0, 15, 1,
        "Turn red when you are this many yards from your max range.")

    ry = ry - 6
    Header(win, "Advanced", rx, ry); ry = ry - 28
    ry = Stepper(win, rx, ry, "minRange", "Dead zone ends at (yd)", 3, 20, 1,
        "Normally detected automatically. Only change this if the dead zone looks wrong.")
    ry = Stepper(win, rx, ry, "maxRange", "Max shooting range (yd)", 20, 60, 1,
        "Normally detected automatically.")

    -- ===== BOTTOM =====
    Label(win, "GameFontDisableSmall",
        "Tip: for text above mobs' heads, turn enemy nameplates on (press V). With them off you still get the text above the target panel.",
        20, -466, 640)

    -- these sit in the frame's bottom bar, like the Close button in the game's Options window
    local moveBtn
    Button(win, "Test Text", 110, "BOTTOMLEFT", win, "BOTTOMLEFT", 12, 4, function() RH.RunTest() end)
    moveBtn = Button(win, "Move Text", 110, "BOTTOMLEFT", win, "BOTTOMLEFT", 128, 4, function()
        RH.SetUnlocked(not RH.IsUnlocked())
        RH.Refresh()
    end)
    Button(win, "Reset Defaults", 120, "BOTTOMLEFT", win, "BOTTOMLEFT", 244, 4, function()
        RH.Reset()
        RH.Refresh()
    end)
    Button(win, "Close", 90, "BOTTOMRIGHT", win, "BOTTOMRIGHT", -10, 4, function() win:Hide() end)

    refreshers[#refreshers + 1] = function()
        moveBtn:SetText(RH.IsUnlocked() and "Lock Text" or "Move Text")
    end

    win:SetScript("OnShow", function() RH.Refresh() end)
    win:Hide()
end

function RH.Refresh()
    if not built then return end
    for _, fn in ipairs(refreshers) do fn() end
end

function RH.ToggleWindow()
    Build()
    if win:IsShown() then win:Hide() else win:Show() end
end

function RH.ShowWindow()
    Build()
    win:Show()
end

----------------------------------------------------------------------
-- Options > AddOns > RangeHelper : short explanation + button
----------------------------------------------------------------------
function RH.InitOptions()
    local panel = CreateFrame("Frame")
    panel.name = "RangeHelper"

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("RangeHelper")

    local desc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -12)
    desc:SetWidth(560)
    desc:SetJustifyH("LEFT")
    desc:SetText(
        "A range helper for Hunters. It shows Melee, DEAD ZONE, Ranged: XX or Out of Range " ..
        "above your target or mobs, so you always know which zone you're standing in.\n\n" ..
        "The Ranged number is colored: green means you're in the sweet spot, yellow means you're " ..
        "getting close to an edge, and red means you're right at your maximum range. Going closer, " ..
        "yellow warns you before the red DEAD ZONE.\n\n" ..
        "You can choose which mobs get the text, where it shows up, how it looks, and when the colors change.")

    local note = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    note:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -16)
    note:SetWidth(560)
    note:SetJustifyH("LEFT")
    note:SetText("Tip: to see the text above mobs' heads, turn enemy nameplates on (press V). You can also type /rh at any time to open the settings.")

    local btn = TryCreate("Button", nil, panel, { "UIPanelButtonTemplate" })
    btn:SetSize(180, 28)
    btn:SetText("Open RangeHelper Settings")
    btn:SetPoint("TOPLEFT", note, "BOTTOMLEFT", 0, -20)
    btn:SetScript("OnClick", function()
        -- close the game options so the window isn't hidden behind them
        pcall(function() if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end end)
        pcall(function() if InterfaceOptionsFrame and InterfaceOptionsFrame:IsShown() then InterfaceOptionsFrame:Hide() end end)
        pcall(function() if GameMenuFrame and GameMenuFrame:IsShown() then HideUIPanel(GameMenuFrame) end end)
        RH.ShowWindow()
    end)

    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
        Settings.RegisterAddOnCategory(category)
        RH.category = category
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    end
end
