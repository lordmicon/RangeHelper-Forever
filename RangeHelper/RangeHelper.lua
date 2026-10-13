----------------------------------------------------------------------
-- RangeHelper : Hunter range helper
-- Shows MELEE / DEAD ZONE / Ranged: XX / Out of Range above mobs.
-- Slash commands: /rh  (or /rangehelper)
----------------------------------------------------------------------
local defaults = {
    mode      = "TARGET", -- ALL | ATTACKABLE | ENEMY | TARGET
    fontSize  = 14,
    yOffset   = 6,
    minRange  = 8,        -- hunter dead zone upper edge (auto-detected from spell if possible)
    maxRange  = 35,       -- hunter max ranged distance (auto-detected from spell if possible)
    redEdge   = 2,        -- far edge (max range): within this many yards -> RED
    yellowEdge= 5,        -- far edge (max range): within this many yards -> YELLOW
    nearYellow= 3,        -- near edge (dead zone): within this many yards above it -> YELLOW
    x = 0, y = -180,      -- custom position (only used when anchor = CUSTOM)
    display   = "BOTH",   -- PLATE (nameplate) | PANEL (target panel) | BOTH
    panelOffset = 0,      -- vertical offset of the text above the target panel
    anchor    = "TARGETFRAME", -- panel text position: TARGETFRAME | CUSTOM
}

-- Spells used for in-range tests (English names; add localized names if needed)
local MELEE_SPELLS  = { "Raptor Strike", "Wing Clip", "Mongoose Bite" }
local RANGED_SPELLS = { "Auto Shot", "Arcane Shot", "Serpent Sting", "Concussive Shot" }
local FAR_SPELLS    = { "Hunter's Mark" }

-- Optional item range checkers used ONLY when LibRangeCheck isn't available.
-- { yards, itemID }. Edit freely; unknown items are simply ignored.
local ITEM_CHECKERS = {
    { 20, 10645 },  -- Gnomish Death Ray
    { 30, 835 },    -- Large Rope Net
    { 30, 7734 },   -- Six Demon Bag
}

RangeHelper = RangeHelper or {}
RangeHelper.defaults = defaults

local COLORS = {
    GREEN  = "|cff00ff00",
    YELLOW = "|cffffff00",
    RED    = "|cffff0000",
    WHITE  = "|cffffffff",
    GRAY   = "|cffaaaaaa",
}

local DB
local RC = LibStub and (LibStub("LibRangeCheck-3.0", true) or LibStub("LibRangeCheck-2.0", true))

----------------------------------------------------------------------
-- API wrappers (work across Classic-era clients)
----------------------------------------------------------------------
local function SpellInRange(name, unit)
    if C_Spell and C_Spell.IsSpellInRange then
        local r = C_Spell.IsSpellInRange(name, unit)
        if r == true then return 1 elseif r == false then return 0 end
        return nil
    end
    if IsSpellInRange then return IsSpellInRange(name, unit) end
end

local function AnyInRange(list, unit)
    local sawZero = false
    for _, name in ipairs(list) do
        local r = SpellInRange(name, unit)
        if r == 1 then return 1 elseif r == 0 then sawZero = true end
    end
    return sawZero and 0 or nil
end

local function SpellRangeInfo(name)
    local minR, maxR
    if C_Spell and C_Spell.GetSpellInfo then
        local i = C_Spell.GetSpellInfo(name)
        if i then minR, maxR = i.minRange, i.maxRange end
    elseif GetSpellInfo then
        local _, _, _, _, a, b = GetSpellInfo(name)
        minR, maxR = a, b
    end
    return minR, maxR
end

local function RefreshSpellRanges()
    for _, n in ipairs({ "Auto Shot", "Arcane Shot" }) do
        local a, b = SpellRangeInfo(n)
        if a and a > 0 then DB.minRange = a end
        if b and b > 0 then DB.maxRange = b end
    end
end

----------------------------------------------------------------------
-- Range classification
-- returns: kind ("MELEE"|"DEAD"|"RANGED"|"OUT"), distance (or nil)
----------------------------------------------------------------------
local function Classify(unit)
    local minRange, maxRange = DB.minRange, DB.maxRange

    -- Preferred path: LibRangeCheck gives actual distance bands
    if RC then
        local minR, maxR = RC:GetRange(unit)
        if not minR and not maxR then return nil end
        if maxR and maxR <= 5 then return "MELEE", maxR end
        if (not maxR) or (minR and minR >= maxRange) then return "OUT" end

        -- LibRangeCheck only gives distance bands (e.g. 5-10), which can't pinpoint
        -- the dead zone. Ask the actual shot spells: if the target is close but the
        -- shot says "out of range", you are standing in the dead zone.
        local shot = AnyInRange(RANGED_SPELLS, unit)
        if shot == 1 then return "RANGED", maxR end
        if shot == 0 then
            if maxR <= 15 then return "DEAD", maxR end
            return "OUT"
        end

        -- No shot spell could be tested: fall back to the configured dead zone edge
        if maxR <= minRange then return "DEAD", maxR end
        return "RANGED", maxR
    end

    -- Fallback path: spell range checks (+ optional item checkers)
    if AnyInRange(MELEE_SPELLS, unit) == 1 then return "MELEE", 5 end

    local ranged = AnyInRange(RANGED_SPELLS, unit)
    if ranged == nil then return nil end -- no spells known / can't test

    -- Estimate distance with item checkers (smallest range that reports "in range")
    local est
    if IsItemInRange then
        for _, c in ipairs(ITEM_CHECKERS) do
            local r = IsItemInRange(c[2], unit)
            if r == true or r == 1 then
                if not est or c[1] < est then est = c[1] end
            end
        end
    end

    if ranged == 1 then return "RANGED", est end

    -- Not in melee, not in ranged: dead zone or too far?
    if est and est <= minRange then return "DEAD", est end
    if AnyInRange(FAR_SPELLS, unit) == 0 then return "OUT" end
    if CheckInteractDistance and CheckInteractDistance(unit, 3) then return "DEAD" end
    return "OUT"
end

local function RangedColor(dist)
    if not dist then return COLORS.GREEN end
    -- Far edge (about to be out of range): yellow, then red right at the edge
    local toMax = DB.maxRange - dist
    if toMax <= DB.redEdge then return COLORS.RED end
    if toMax <= DB.yellowEdge then return COLORS.YELLOW end
    -- Near edge (about to enter the dead zone): yellow only, the dead zone itself is red
    if dist - DB.minRange <= DB.nearYellow then return COLORS.YELLOW end
    return COLORS.GREEN
end

local function BuildText(kind, dist)
    if kind == "MELEE" then
        return COLORS.WHITE .. "Melee|r"
    elseif kind == "DEAD" then
        return COLORS.RED .. "DEAD ZONE|r"
    elseif kind == "RANGED" then
        local c = RangedColor(dist)
        if dist then return c .. "Ranged: " .. dist .. "|r" end
        return c .. "Ranged|r"
    elseif kind == "OUT" then
        return COLORS.GRAY .. "Out of Range|r"
    end
end

----------------------------------------------------------------------
-- Display
----------------------------------------------------------------------
local anchorFrame -- fallback anchor (draggable)
local texts = {}

local function GetText(key)
    local fs = texts[key]
    if not fs then
        fs = UIParent:CreateFontString(nil, "OVERLAY")
        fs:SetDrawLayer("OVERLAY", 7)
        texts[key] = fs
    end
    fs:SetFont(STANDARD_TEXT_FONT, DB.fontSize, "OUTLINE")
    return fs
end

local function GetPlate(unit)
    if C_NamePlate and C_NamePlate.GetNamePlateForUnit then
        return C_NamePlate.GetNamePlateForUnit(unit)
    end
end

-- Red (hostile) mobs only. Neutral/yellow mobs can be attacked but are NOT hostile:
-- reaction 1-3 = hated / hostile / unfriendly (red), 4 = neutral (yellow), 5+ = friendly.
local function IsHostile(unit)
    if not UnitCanAttack("player", unit) then return false end
    local reaction = UnitReaction("player", unit)
    if reaction then return reaction <= 3 end
    return UnitIsEnemy("player", unit) and true or false
end

local function Allowed(unit)
    if not UnitExists(unit) or UnitIsDead(unit) then return false end
    local mode = DB.mode
    if mode == "ALL" then return true end                              -- anything with a nameplate
    if mode == "ATTACKABLE" then return UnitCanAttack("player", unit) end  -- red + yellow
    if mode == "ENEMY" then return IsHostile(unit) end                 -- red only
    -- TARGET: just your target, as long as it's something you can attack (in or out of combat)
    return UnitIsUnit(unit, "target") and UnitCanAttack("player", unit)
end

local function UnitList()
    local list = {}
    if DB.mode == "TARGET" or not (C_NamePlate and C_NamePlate.GetNamePlateForUnit) then
        list[1] = "target"
        return list
    end
    -- walk the nameplate unit tokens directly instead of reading fields off plate frames
    local targetCovered = false
    for i = 1, 40 do
        local u = "nameplate" .. i
        if UnitExists(u) then
            list[#list + 1] = u
            if UnitIsUnit(u, "target") then targetCovered = true end
        end
    end
    -- Nameplates turned off (or the target has none)? Still check your target so the
    -- text can appear above the target panel.
    if not targetCovered and UnitExists("target") then
        list[#list + 1] = "target"
    end
    return list
end

local function ShowAt(key, msg, point, rel, relPoint, x, y)
    local fs = GetText(key)
    fs:ClearAllPoints()
    fs:SetPoint(point, rel, relPoint, x, y)
    fs:SetText(msg)
    fs:Show()
end

local function ShowOnPanel(msg)
    if DB.anchor == "CUSTOM" or not (TargetFrame and TargetFrame:IsShown()) then
        ShowAt("panel", msg, "CENTER", anchorFrame, "CENTER", 0, 0)
    else
        ShowAt("panel", msg, "BOTTOM", TargetFrame, "TOP", 0, DB.panelOffset)
    end
end

local function Update()
    for _, fs in pairs(texts) do fs:Hide() end
    if UnitIsDeadOrGhost("player") then return end

    local display = DB.display
    local panelDone = false

    for _, unit in ipairs(UnitList()) do
        if Allowed(unit) then
            local kind, dist = Classify(unit)
            local msg = kind and BuildText(kind, dist)
            if msg then
                local plate = GetPlate(unit)

                -- text over the nameplate
                if plate and display ~= "PANEL" then
                    ShowAt("plate:" .. unit, msg, "BOTTOM", plate, "TOP", 0, DB.yOffset)
                end

                -- text over the target (mob) panel: only for your current target
                if not panelDone and UnitIsUnit(unit, "target") then
                    -- PLATE mode still falls back to the panel if there is no nameplate
                    if display ~= "PLATE" or not plate then
                        ShowOnPanel(msg)
                        panelDone = true
                    end
                end
            end
        end
    end
end

----------------------------------------------------------------------
-- Setup / events
----------------------------------------------------------------------
local function CreateAnchor()
    anchorFrame = CreateFrame("Frame", "RangeHelperAnchor", UIParent)
    anchorFrame:SetSize(160, 30)
    anchorFrame:SetPoint("CENTER", UIParent, "CENTER", DB.x, DB.y)
    anchorFrame:SetMovable(true)
    anchorFrame:SetClampedToScreen(true)
    anchorFrame:RegisterForDrag("LeftButton")
    anchorFrame:SetScript("OnDragStart", anchorFrame.StartMoving)
    anchorFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local _, _, _, x, y = self:GetPoint()
        DB.x, DB.y = x, y
    end)
    anchorFrame.bg = anchorFrame:CreateTexture(nil, "BACKGROUND")
    anchorFrame.bg:SetAllPoints()
    anchorFrame.bg:SetColorTexture(0, 1, 0, 0.3)
    anchorFrame.bg:Hide()
    anchorFrame:EnableMouse(false)
end

local function Print(msg) print("|cff00ccffRangeHelper:|r " .. msg) end
local notHunter = false
local testFS

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("SPELLS_CHANGED")
f:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        -- Hunter-only addon: bail out cleanly for any other class
        local _, class = UnitClass("player")
        if class ~= "HUNTER" then
            notHunter = true
            f:UnregisterAllEvents()
            f:SetScript("OnUpdate", nil)
            Print("not loaded because this character is not a Hunter.")
            return
        end
        RangeHelperDB = RangeHelperDB or {}
        DB = RangeHelperDB
        for k, v in pairs(defaults) do if DB[k] == nil then DB[k] = v end end
        CreateAnchor()
        RefreshSpellRanges()
        if not RC then
            Print("LibRangeCheck not available - using spell-based ranges (less precise).")
        end
        if RangeHelper.InitOptions then RangeHelper.InitOptions() end
        Print("loaded. Mode: " .. DB.mode .. ", display: " .. DB.display .. ". Type /rh to open the settings window.")
    elseif DB then
        RefreshSpellRanges()
    end
end)

local elapsed = 0
local lastError
f:SetScript("OnUpdate", function(_, e)
    if not DB then return end
    elapsed = elapsed + e
    if elapsed < 0.1 then return end
    elapsed = 0
    local ok, err = pcall(Update)
    if not ok and err ~= lastError then
        lastError = err
        Print("|cffff4444update error:|r " .. tostring(err))
        print("  (please copy this line - it explains why nothing is showing)")
    end
end)

----------------------------------------------------------------------
-- Slash commands
----------------------------------------------------------------------
local unlocked = false

local function SetUnlocked(flag)
    unlocked = flag and true or false
    if unlocked then
        DB.anchor = "CUSTOM"
        anchorFrame:EnableMouse(true)
        anchorFrame.bg:Show()
    else
        anchorFrame:EnableMouse(false)
        anchorFrame.bg:Hide()
    end
end

local function RunTest()
    -- Shows sample text for 8 seconds, ignoring all range logic.
    testFS = testFS or UIParent:CreateFontString(nil, "OVERLAY")
    testFS:SetFont(STANDARD_TEXT_FONT, DB.fontSize + 4, "OUTLINE")
    testFS:ClearAllPoints()
    testFS:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
    testFS:SetText(COLORS.GREEN .. "RangeHelper test: Ranged: 25|r")
    testFS:Show()
    C_Timer.After(8, function() testFS:Hide() end)
    Print("test text shown in the middle of the screen for 8 seconds.")
    print("  If you do NOT see it, the display itself is failing (tell me).")
    local plate = C_NamePlate and C_NamePlate.GetNamePlateForUnit and C_NamePlate.GetNamePlateForUnit("target")
    print("  mode=" .. DB.mode .. " display=" .. DB.display)
    print("  nameplate units found: " .. #UnitList())
    print("  target has a nameplate: " .. tostring(plate ~= nil))
    print("  target panel shown: " .. tostring(TargetFrame and TargetFrame:IsShown() or false))
    print("  texts created so far: " .. (function() local n = 0 for _ in pairs(texts) do n = n + 1 end return n end)())
end

local function DoReset()
    for k, v in pairs(defaults) do DB[k] = v end
    SetUnlocked(false)
    RefreshSpellRanges()
end

RangeHelper.RunTest     = RunTest
RangeHelper.SetUnlocked = SetUnlocked
RangeHelper.IsUnlocked  = function() return unlocked end
RangeHelper.Reset       = DoReset
RangeHelper.GetDB       = function() return DB end
RangeHelper.Print       = Print
RangeHelper.HasLib      = function() return RC ~= nil end

local C = "|cff00ccff"   -- command color
local G = "|cffaaaaaa"   -- explanation color
local R = "|r"

local function PrintStatus()
    Print("current settings:")
    print("  Which mobs:  " .. C .. DB.mode .. R .. "      (/rh mode)")
    print("  Where shown: " .. C .. DB.display .. R .. "      (/rh display)")
    print("  Text size:   " .. C .. DB.fontSize .. R .. "   height over nameplate: " .. C .. DB.yOffset .. R .. "   over panel: " .. C .. DB.panelOffset .. R)
    print("  Dead zone ends at " .. C .. DB.minRange .. R .. " yd, max shooting range " .. C .. DB.maxRange .. R .. " yd")
    print("  Far edge: yellow within " .. C .. DB.yellowEdge .. R .. " yd of max, red within " .. C .. DB.redEdge .. R .. " yd")
    print("  Near edge: yellow within " .. C .. DB.nearYellow .. R .. " yd above the dead zone")
    print("  Range source: " .. (RC and "LibRangeCheck (accurate)" or "spell checks only (rough)"))
end

local function PrintHelp()
    Print("what this does  (tip: just type /rh to open the settings window instead of using these commands)")
    print(G .. "  Shows your range to a mob in text: Melee, DEAD ZONE, Ranged: XX, or Out of Range.|r")
    print(G .. "  The Ranged number is colored: green = good, yellow = getting close to trouble,|r")
    print(G .. "  red = right at the far edge. Going closer, yellow warns you before the red DEAD ZONE.|r")
    print(" ")
    print("1) Which mobs get the text?   " .. C .. "/rh mode <target|enemy|attackable|all>" .. R)
    print("  " .. C .. "target" .. R .. G .. "     - only your target, in or out of combat (default)|r")
    print("  " .. C .. "enemy" .. R .. G .. "      - only HOSTILE (red) mobs. Yellow/neutral mobs are skipped.|r")
    print("  " .. C .. "attackable" .. R .. G .. " - red AND yellow mobs (anything you could attack)|r")
    print("  " .. C .. "all" .. R .. G .. "        - every mob with a nameplate, including friendly ones|r")
    print(G .. "  Example: /rh mode enemy|r")
    print(" ")
    print("2) Where does the text appear?   " .. C .. "/rh display <plate|panel|both>" .. R)
    print("  " .. C .. "plate" .. R .. G .. " - above the mob's nameplate (uses the panel if there is no nameplate)|r")
    print("  " .. C .. "panel" .. R .. G .. " - above the target (mob) panel, for your target only|r")
    print("  " .. C .. "both" .. R .. G .. "  - in both places")
    print(G .. "  Example: /rh display both|r")
    print("  " .. C .. "Tip:" .. R .. G .. " text over mobs needs enemy nameplates ON. Press V to toggle them.|r")
    print(G .. "  With nameplates off you only get the text over the target panel, for your target.|r")
    print(" ")
    print("3) Make it look right")
    print("  " .. C .. "/rh size 18" .. R .. G .. "        - bigger or smaller text|r")
    print("  " .. C .. "/rh offset 10" .. R .. G .. "      - raise the text above the nameplate (use a negative number to lower it)|r")
    print("  " .. C .. "/rh paneloffset 5" .. R .. G .. " - same, but for the text above the target panel|r")
    print(" ")
    print("4) Tune the color warnings (most people never need these)")
    print("  " .. C .. "/rh yellow 5" .. R .. G .. "  - turn yellow when within 5 yd of max range (far edge)|r")
    print("  " .. C .. "/rh red 2" .. R .. G .. "     - turn red when within 2 yd of max range|r")
    print("  " .. C .. "/rh near 3" .. R .. G .. "    - turn yellow when within 3 yd above the dead zone. Bigger = earlier warning.|r")
    print("  " .. C .. "/rh min 8" .. R .. G .. "     - where the dead zone ends. " .. "/rh max 35" .. " - where your shots run out. (Auto-detected, rarely needs changing.)|r")
    print(" ")
    print("5) Other")
    print("  " .. C .. "/rh status" .. R .. G .. "  - show all your current settings|r")
    print("  " .. C .. "/rh test" .. R .. G .. "    - shows sample text for 8 seconds to check that the display works|r")
    print("  " .. C .. "/rh debug" .. R .. G .. "   - target a mob first; prints technical range info (useful if something looks wrong)|r")
    print("  " .. C .. "/rh unlock" .. R .. G .. "  - drag the text to your own spot if the panel position doesn't suit you; " .. "/rh lock when done|r")
    print("  " .. C .. "/rh anchor <target|custom>" .. R .. G .. " - panel text goes above the target panel, or at your custom spot|r")
    print("  " .. C .. "/rh reset" .. R .. G .. "   - put every setting back to default|r")
end

SLASH_RANGEHELPER1 = "/rh"
SLASH_RANGEHELPER2 = "/rangehelper"
SlashCmdList["RANGEHELPER"] = function(msg)
    if notHunter or not DB then
        Print("not loaded because this character is not a Hunter.")
        return
    end
    msg = (msg or ""):lower()
    local cmd, arg = msg:match("^(%S*)%s*(.-)$")
    local num = tonumber(arg)

    if cmd == "mode" then
        local m = arg:upper()
        if m == "ALL" or m == "ENEMY" or m == "ATTACKABLE" or m == "TARGET" then
            DB.mode = m
            Print("mode set to " .. m)
        else
            Print("usage: /rh mode all | attackable | enemy | target")
        end
    elseif cmd == "display" then
        local d = arg:upper()
        if d == "PLATE" or d == "NAMEPLATE" then DB.display = "PLATE"
        elseif d == "PANEL" then DB.display = "PANEL"
        elseif d == "BOTH" then DB.display = "BOTH"
        else Print("usage: /rh display plate | panel | both"); return end
        Print("display set to " .. DB.display)
    elseif cmd == "paneloffset" and num then
        DB.panelOffset = num; Print("panel text offset " .. num)
    elseif cmd == "size" and num then
        DB.fontSize = num; Print("font size " .. num)
    elseif cmd == "offset" and num then
        DB.yOffset = num; Print("vertical offset " .. num)
    elseif cmd == "min" and num then
        DB.minRange = num; Print("dead zone edge " .. num)
    elseif cmd == "max" and num then
        DB.maxRange = num; Print("max ranged distance " .. num)
    elseif cmd == "red" and num then
        DB.redEdge = num; Print("red warning within " .. num .. " yd of max range")
    elseif cmd == "yellow" and num then
        DB.yellowEdge = num; Print("yellow warning within " .. num .. " yd of max range")
    elseif cmd == "near" and num then
        DB.nearYellow = num; Print("yellow warning within " .. num .. " yd above the dead zone")
    elseif cmd == "unlock" then
        SetUnlocked(true)
        Print("drag the green box where you want the text. /rh lock when done. (/rh anchor target goes back to the target panel)")
    elseif cmd == "lock" then
        SetUnlocked(false); Print("locked")
    elseif cmd == "test" then
        RunTest()
    elseif cmd == "debug" then
        if not UnitExists("target") then Print("target a mob first, then /rh debug"); return end
        Print("LibRangeCheck loaded: " .. tostring(RC ~= nil))
        if RC then
            local a, b = RC:GetRange("target")
            Print("LibRangeCheck says: min=" .. tostring(a) .. " max=" .. tostring(b))
        end
        local function raw(name)
            local ok, r
            if C_Spell and C_Spell.IsSpellInRange then
                ok, r = pcall(C_Spell.IsSpellInRange, name, "target")
            elseif IsSpellInRange then
                ok, r = pcall(IsSpellInRange, name, "target")
            end
            return tostring(r)
        end
        for _, list in ipairs({ MELEE_SPELLS, RANGED_SPELLS, FAR_SPELLS }) do
            for _, n in ipairs(list) do Print("  spell '" .. n .. "' -> " .. raw(n)) end
        end
        Print("minRange=" .. DB.minRange .. " maxRange=" .. DB.maxRange)
        local kind, dist = Classify("target")
        Print("result: " .. tostring(kind) .. ", dist=" .. tostring(dist))
    elseif cmd == "anchor" then
        if arg == "target" or arg == "targetframe" then
            DB.anchor = "TARGETFRAME"; Print("panel text now shows above the target panel")
        elseif arg == "custom" then
            DB.anchor = "CUSTOM"; Print("panel text now uses your custom position (/rh unlock to move it)")
        else
            Print("usage: /rh anchor target | custom")
        end
    elseif cmd == "reset" then
        DoReset(); Print("settings reset")
    elseif cmd == "status" then
        PrintStatus()
    elseif cmd == "" or cmd == "options" or cmd == "config" or cmd == "window" or cmd == "settings" then
        if RangeHelper.ToggleWindow then RangeHelper.ToggleWindow() else PrintHelp() end
    else
        PrintHelp()
    end
    -- keep the settings window in sync with anything typed here
    if RangeHelper.Refresh then RangeHelper.Refresh() end
end
