-- MM2 Helper v2.9 (tabbed, seasonal themes, games)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local playerGui = player:WaitForChild("PlayerGui")

for _, gui in pairs(playerGui:GetChildren()) do
    if gui.Name == "MM2_Helper_GUI" or gui.Name == "MM2Hub_StackGame" then
        gui:Destroy()
    end
end

-- ============================
-- CONFIG
-- ============================
local SHOOT_OFFSET = 15 -- snippet's `shootOffset` (offset / 15 = 1)
local INVIS_DEPTH = 500
local REACH_MIN, REACH_MAX = 4, 30 -- Murder Reach size slider range (studs)
local COIN_SPEED = 50 -- studs per second for Auto Coin tween
local COIN_TIMEOUT = 2 -- seconds to wait for CoinCollected after arriving
local CONFIG_PATH = "MM2Hub_settings.json"

local COLOR_RED = Color3.fromRGB(220, 30, 60)
local COLOR_BLUE = Color3.fromRGB(30, 120, 255)
local COLOR_GOLD = Color3.fromRGB(255, 215, 0)
local COLOR_GREEN = Color3.fromRGB(80, 220, 120)
local COLOR_DIM = Color3.fromRGB(120, 120, 150)
local COLOR_TEXT = Color3.fromRGB(220, 220, 240)

local THEMES = {
    DEFAULT = {
        bg = Color3.fromRGB(10, 10, 15),
        accent = Color3.fromRGB(255, 60, 100),
        border = { Color3.fromRGB(255, 0, 128), Color3.fromRGB(0, 128, 255), Color3.fromRGB(128, 0, 255) },
        cycle = true,
        font = Enum.Font.GothamBold,
        deco = nil,
    },
    HALLOWEEN = {
        bg = Color3.fromRGB(14, 8, 18),
        accent = Color3.fromRGB(255, 120, 0),
        border = { Color3.fromRGB(255, 120, 0), Color3.fromRGB(120, 0, 200), Color3.fromRGB(60, 220, 90) },
        font = Enum.Font.Fondamento,
        deco = { emoji = "🦇", motion = "fly", rate = 0.9, minTime = 5, maxTime = 8, minSize = 16, maxSize = 26 },
    },
    THANKSGIVING = {
        bg = Color3.fromRGB(20, 12, 8),
        accent = Color3.fromRGB(210, 105, 30),
        border = { Color3.fromRGB(210, 105, 30), Color3.fromRGB(160, 82, 45), Color3.fromRGB(218, 165, 32) },
        font = Enum.Font.Merriweather,
        deco = { emoji = "🍂", motion = "fall", rate = 0.6, minTime = 5, maxTime = 8, minSize = 14, maxSize = 22 },
    },
    CHRISTMAS = {
        bg = Color3.fromRGB(8, 16, 12),
        accent = Color3.fromRGB(220, 40, 50),
        border = { Color3.fromRGB(220, 30, 40), Color3.fromRGB(20, 150, 70), Color3.fromRGB(255, 255, 255) },
        font = Enum.Font.FredokaOne,
        deco = { emoji = "❄️", motion = "fall", rate = 0.25, minTime = 6, maxTime = 10, minSize = 10, maxSize = 18 },
    },
    ["NEW YEAR"] = {
        bg = Color3.fromRGB(8, 8, 20),
        accent = Color3.fromRGB(255, 215, 0),
        border = { Color3.fromRGB(255, 215, 0), Color3.fromRGB(192, 192, 192), Color3.fromRGB(120, 0, 255) },
        font = Enum.Font.Bangers,
        deco = { emoji = "🎉", motion = "fall", rate = 0.8, minTime = 4, maxTime = 7, minSize = 12, maxSize = 18 },
    },
}

local THEME_ORDER = { "AUTO", "HALLOWEEN", "THANKSGIVING", "CHRISTMAS", "NEW YEAR", "DEFAULT" }
local FONT_ORDER = { "AUTO", "GOTHIC", "SPOOKY", "ROUND", "COMIC", "SERIF", "SCIFI" }
local FONT_CHOICES = {
    GOTHIC = Enum.Font.GothamBold,
    SPOOKY = Enum.Font.Fondamento,
    ROUND = Enum.Font.FredokaOne,
    COMIC = Enum.Font.Bangers,
    SERIF = Enum.Font.Merriweather,
    SCIFI = Enum.Font.SciFi,
}

-- ============================
-- SETTINGS (saved if the executor supports writefile)
-- ============================
local settings = { themeChoice = "AUTO", fontChoice = "AUTO", bgId = "" }
do
    local ok, data = pcall(function()
        if isfile and isfile(CONFIG_PATH) then
            return HttpService:JSONDecode(readfile(CONFIG_PATH))
        end
    end)
    if ok and type(data) == "table" then
        for k, v in pairs(data) do
            settings[k] = v
        end
    end
end

local function saveSettings()
    pcall(function()
        if writefile then
            writefile(CONFIG_PATH, HttpService:JSONEncode(settings))
        end
    end)
end

local function currentMonth()
    local ok, m = pcall(function()
        return DateTime.now():ToLocalTime().Month
    end)
    if ok and m then return m end
    local ok2, m2 = pcall(function()
        return os.date("*t").month
    end)
    return ok2 and m2 or 0
end

local function autoThemeKey()
    local m = currentMonth()
    if m == 10 then return "HALLOWEEN"
    elseif m == 11 then return "THANKSGIVING"
    elseif m == 12 then return "CHRISTMAS"
    elseif m == 1 then return "NEW YEAR"
    end
    return "DEFAULT"
end

local function currentThemeKey()
    if settings.themeChoice == "AUTO" or not THEMES[settings.themeChoice] then
        return autoThemeKey()
    end
    return settings.themeChoice
end

local function corner(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius)
    c.Parent = parent
    return c
end

local activeThemeDef = THEMES.DEFAULT
local activeFont = Enum.Font.GothamBold
local rgbCycle = true
local rgbColors = THEMES.DEFAULT.border
local applyAll -- defined after the UI

-- ============================
-- GUI SKELETON
-- ============================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MM2_Helper_GUI"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

local rgbBorder = Instance.new("Frame")
rgbBorder.Size = UDim2.new(0, 316, 0, 478)
rgbBorder.Position = UDim2.new(0.5, -158, 0.2, -8)
rgbBorder.BackgroundColor3 = Color3.fromRGB(255, 0, 128)
rgbBorder.BorderSizePixel = 0
rgbBorder.Active = true
rgbBorder.Draggable = true
rgbBorder.ZIndex = 1
rgbBorder.Parent = screenGui
corner(rgbBorder, 13)

local rgbGrad = Instance.new("UIGradient")
rgbGrad.Parent = rgbBorder

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 308, 0, 470)
mainFrame.Position = UDim2.new(0, 4, 0, 4)
mainFrame.BackgroundColor3 = THEMES.DEFAULT.bg
mainFrame.BorderSizePixel = 0
mainFrame.ClipsDescendants = true
mainFrame.ZIndex = 2
mainFrame.Parent = rgbBorder
corner(mainFrame, 10)

local bgImage = Instance.new("ImageLabel")
bgImage.Size = UDim2.new(1, 0, 1, 0)
bgImage.BackgroundTransparency = 1
bgImage.ImageTransparency = 0.25
bgImage.ScaleType = Enum.ScaleType.Crop
bgImage.ZIndex = 1
bgImage.Parent = mainFrame

local decorLayer = Instance.new("Frame")
decorLayer.Size = UDim2.new(1, 0, 1, 0)
decorLayer.BackgroundTransparency = 1
decorLayer.ClipsDescendants = true
decorLayer.ZIndex = 1
decorLayer.Parent = mainFrame

-- HEADER
local headerBar = Instance.new("Frame")
headerBar.Size = UDim2.new(1, 0, 0, 48)
headerBar.BackgroundColor3 = Color3.fromRGB(18, 18, 26)
headerBar.BackgroundTransparency = 0.1
headerBar.BorderSizePixel = 0
headerBar.ZIndex = 3
headerBar.Parent = mainFrame
corner(headerBar, 10)

local headerFill = Instance.new("Frame")
headerFill.Size = UDim2.new(1, 0, 0, 10)
headerFill.Position = UDim2.new(0, 0, 1, -10)
headerFill.BackgroundColor3 = Color3.fromRGB(18, 18, 26)
headerFill.BackgroundTransparency = 0.1
headerFill.BorderSizePixel = 0
headerFill.ZIndex = 3
headerFill.Parent = headerBar

local accentDot = Instance.new("Frame")
accentDot.Size = UDim2.new(0, 6, 0, 6)
accentDot.Position = UDim2.new(0, 16, 0.5, -3)
accentDot.BackgroundColor3 = THEMES.DEFAULT.accent
accentDot.BorderSizePixel = 0
accentDot.ZIndex = 4
accentDot.Parent = headerBar
corner(accentDot, 3)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -90, 1, 0)
title.Position = UDim2.new(0, 30, 0, 0)
title.BackgroundTransparency = 1
title.Text = "zzz's mm2 hub"
title.TextColor3 = COLOR_TEXT
title.TextScaled = true
title.Font = activeFont
title.TextXAlignment = Enum.TextXAlignment.Left
title.ZIndex = 4
title.Parent = headerBar

local versionBadge = Instance.new("TextLabel")
versionBadge.Size = UDim2.new(0, 40, 0, 18)
versionBadge.Position = UDim2.new(1, -50, 0.5, -9)
versionBadge.BackgroundColor3 = Color3.fromRGB(30, 30, 48)
versionBadge.Text = "v2.9"
versionBadge.TextColor3 = COLOR_DIM
versionBadge.TextScaled = true
versionBadge.Font = activeFont
versionBadge.ZIndex = 4
versionBadge.Parent = headerBar
corner(versionBadge, 5)

-- PAGES + TABS
local TAB_NAMES = { "ESP", "COMBAT", "PLAYER", "GAMES", "SETTINGS" }
local tabButtons, pages = {}, {}

local function makePage(name, scroll)
    local page
    if scroll then
        page = Instance.new("ScrollingFrame")
        page.ScrollBarThickness = 3
        page.ScrollBarImageColor3 = activeThemeDef.accent
        page.CanvasSize = UDim2.new(0, 0, 0, 400)
        page.BorderSizePixel = 0
    else
        page = Instance.new("Frame")
        page.BorderSizePixel = 0
    end
    page.Name = name .. "Page"
    page.Size = UDim2.new(1, -24, 0, 290)
    page.Position = UDim2.new(0, 12, 0, 96)
    page.BackgroundTransparency = 1
    page.Visible = false
    page.ZIndex = 3
    page.Parent = mainFrame
    pages[name] = page
    return page
end

makePage("ESP", false)
makePage("COMBAT", true)
makePage("PLAYER", false)
makePage("GAMES", true)
makePage("SETTINGS", false)

local activeTab = "ESP"

local function setTab(name)
    activeTab = name
    local accent = activeThemeDef.accent
    for tabName, page in pairs(pages) do
        page.Visible = (tabName == name)
    end
    for tabName, tb in pairs(tabButtons) do
        local on = (tabName == name)
        tb.BackgroundColor3 = on and accent or Color3.fromRGB(24, 24, 36)
        tb.TextColor3 = on and Color3.new(1, 1, 1) or COLOR_DIM
    end
end

for i, name in ipairs(TAB_NAMES) do
    local tb = Instance.new("TextButton")
    tb.Size = UDim2.new(0.2, -8, 0, 30)
    tb.Position = UDim2.new((i - 1) * 0.2, 4, 0, 56)
    tb.BackgroundColor3 = Color3.fromRGB(24, 24, 36)
    tb.BorderSizePixel = 0
    tb.AutoButtonColor = false
    tb.Text = name
    tb.TextColor3 = COLOR_DIM
    tb.TextScaled = true
    tb.Font = activeFont
    tb.ZIndex = 4
    tb.Parent = mainFrame
    corner(tb, 6)
    tb.MouseButton1Click:Connect(function()
        setTab(name)
    end)
    tabButtons[name] = tb
end

local espPage, combatPage, playerPage, gamesPage, settingsPage =
    pages.ESP, pages.COMBAT, pages.PLAYER, pages.GAMES, pages.SETTINGS

-- RESULT / STATUS BOX
local resultContainer = Instance.new("Frame")
resultContainer.Size = UDim2.new(1, -24, 0, 60)
resultContainer.Position = UDim2.new(0, 12, 0, 398)
resultContainer.BackgroundColor3 = Color3.fromRGB(18, 18, 26)
resultContainer.BackgroundTransparency = 0.15
resultContainer.BorderSizePixel = 0
resultContainer.ZIndex = 3
resultContainer.Parent = mainFrame
corner(resultContainer, 8)

local resultStroke = Instance.new("UIStroke")
resultStroke.Color = Color3.fromRGB(40, 40, 65)
resultStroke.Thickness = 1
resultStroke.Parent = resultContainer

local resultLabel = Instance.new("TextLabel")
resultLabel.Size = UDim2.new(1, -16, 1, 0)
resultLabel.Position = UDim2.new(0, 8, 0, 0)
resultLabel.BackgroundTransparency = 1
resultLabel.Text = "Pick a tab to get started..."
resultLabel.TextColor3 = COLOR_DIM
resultLabel.TextScaled = true
resultLabel.TextWrapped = true
resultLabel.Font = activeFont
resultLabel.ZIndex = 4
resultLabel.Parent = resultContainer

-- ============================
-- HELPERS
-- ============================
local function setStatus(text, color)
    resultLabel.Text = text
    resultLabel.TextColor3 = color or COLOR_DIM
end

local function setToggleVisual(stroke, on)
    TweenService:Create(stroke, TweenInfo.new(0.2), { Transparency = on and 0 or 0.5 }):Play()
end

local function makeButton(parent, text, yPos, bgColor)
    local container = Instance.new("Frame")
    container.Size = UDim2.new(1, 0, 0, 44)
    container.Position = UDim2.new(0, 0, 0, yPos)
    container.BackgroundColor3 = Color3.fromRGB(24, 24, 36)
    container.BackgroundTransparency = 0.2
    container.BorderSizePixel = 0
    container.ZIndex = 3
    container.Parent = parent
    corner(container, 8)

    local stroke = Instance.new("UIStroke")
    stroke.Color = bgColor
    stroke.Thickness = 1.5
    stroke.Transparency = 0.5
    stroke.Parent = container

    local colorBar = Instance.new("Frame")
    colorBar.Size = UDim2.new(0, 3, 0.7, 0)
    colorBar.Position = UDim2.new(0, 8, 0.15, 0)
    colorBar.BackgroundColor3 = bgColor
    colorBar.BorderSizePixel = 0
    colorBar.ZIndex = 4
    colorBar.Parent = container
    corner(colorBar, 2)

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Text = text
    btn.TextColor3 = COLOR_TEXT
    btn.TextScaled = true
    btn.Font = activeFont
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.ZIndex = 4
    btn.Parent = container

    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, 20)
    pad.Parent = btn

    btn.MouseEnter:Connect(function()
        TweenService:Create(container, TweenInfo.new(0.12), { BackgroundColor3 = Color3.fromRGB(34, 34, 52) }):Play()
        TweenService:Create(stroke, TweenInfo.new(0.12), { Transparency = 0 }):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(container, TweenInfo.new(0.12), { BackgroundColor3 = Color3.fromRGB(24, 24, 36) }):Play()
        TweenService:Create(stroke, TweenInfo.new(0.12), { Transparency = 0.5 }):Play()
    end)
    btn.MouseButton1Down:Connect(function()
        TweenService:Create(container, TweenInfo.new(0.06), { BackgroundColor3 = bgColor }):Play()
    end)
    btn.MouseButton1Up:Connect(function()
        TweenService:Create(container, TweenInfo.new(0.12), { BackgroundColor3 = Color3.fromRGB(24, 24, 36) }):Play()
    end)

    return btn, stroke
end

local function hasToolMatching(plr, keyword)
    keyword = keyword:lower()
    local function search(container)
        if not container then return false end
        for _, item in ipairs(container:GetChildren()) do
            if item:IsA("Tool") and item.Name:lower():find(keyword, 1, true) then
                return true
            end
        end
        return false
    end
    return search(plr.Character) or search(plr.Backpack)
end

local function findPlayerByTool(keyword, excludeSelf)
    for _, plr in ipairs(Players:GetPlayers()) do
        if (not excludeSelf or plr ~= player) and hasToolMatching(plr, keyword) then
            return plr
        end
    end
    return nil
end

local function findMurderer()
    return findPlayerByTool("knife", true)
end

local function findSheriffThatsNotMe()
    return findPlayerByTool("gun", true)
end

local function hasLocalGun()
    return hasToolMatching(player, "gun")
end

local function isDead(plr)
    local hum = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
    return (not hum) or hum.Health <= 0
end

local function findOwnTool(keyword)
    local char = player.Character
    local function search(container)
        if not container then return nil end
        for _, item in ipairs(container:GetChildren()) do
            if item:IsA("Tool") and item.Name:lower():find(keyword, 1, true) then
                return item
            end
        end
        return nil
    end
    return (char and search(char)) or search(player.Backpack)
end

local function outlinePlayer(plr, on, color)
    local char = plr.Character
    if not char then return end
    local existing = char:FindFirstChild("OutlineHighlight")
    if existing then existing:Destroy() end
    if on then
        local hl = Instance.new("Highlight")
        hl.Name = "OutlineHighlight"
        hl.Adornee = char
        hl.FillColor = color or Color3.new(1, 0, 0)
        hl.FillTransparency = 0.7
        hl.OutlineColor = color or Color3.new(1, 1, 1)
        hl.OutlineTransparency = 0
        hl.Parent = char
    end
end

local function clearOutlines()
    for _, plr in ipairs(Players:GetPlayers()) do
        outlinePlayer(plr, false)
    end
end

local function clearBillboards()
    for _, plr in ipairs(Players:GetPlayers()) do
        local bb = plr.Character and plr.Character:FindFirstChild("MM2_RoleLabel")
        if bb then bb:Destroy() end
    end
end

local function addBillboard(plr, labelText, labelColor)
    local hrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local bb = Instance.new("BillboardGui")
    bb.Name = "MM2_RoleLabel"
    bb.Size = UDim2.new(0, 120, 0, 34)
    bb.StudsOffset = Vector3.new(0, 3.5, 0)
    bb.AlwaysOnTop = true
    bb.Adornee = hrp
    bb.Parent = plr.Character

    local bg = Instance.new("Frame")
    bg.Size = UDim2.new(1, 0, 1, 0)
    bg.BackgroundColor3 = Color3.fromRGB(10, 10, 15)
    bg.BackgroundTransparency = 0.25
    bg.BorderSizePixel = 0
    bg.Parent = bb
    corner(bg, 6)

    local stroke = Instance.new("UIStroke")
    stroke.Color = labelColor
    stroke.Thickness = 1.5
    stroke.Parent = bg

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = labelText
    lbl.TextColor3 = labelColor
    lbl.TextScaled = true
    lbl.Font = activeFont
    lbl.Parent = bg
end

-- ============================
-- SEASONAL DECORATIONS
-- ============================
local decorGen = 0

local function spawnDecorItem(deco, gen)
    if gen ~= decorGen then return end
    local size = math.random(deco.minSize, deco.maxSize)
    local lbl = Instance.new("TextLabel")
    lbl.BackgroundTransparency = 1
    lbl.Text = deco.emoji
    lbl.TextSize = size
    lbl.Size = UDim2.new(0, size * 1.5, 0, size * 1.5)
    lbl.TextColor3 = Color3.new(1, 1, 1)
    lbl.TextTransparency = 0.1
    lbl.Font = Enum.Font.SourceSans
    lbl.ZIndex = 1
    lbl.Parent = decorLayer

    local duration = math.random(deco.minTime * 10, deco.maxTime * 10) / 10
    local endPos, endRot
    if deco.motion == "fly" then
        local y = math.random(5, 85) / 100
        lbl.Position = UDim2.new(1.1, 0, y, 0)
        lbl.Rotation = -10
        endPos = UDim2.new(-0.2, 0, math.clamp(y + math.random(-8, 8) / 100, 0, 1), 0)
        endRot = 10
    else
        local x = math.random(0, 100) / 100
        lbl.Position = UDim2.new(x, 0, -0.1, 0)
        lbl.Rotation = math.random(0, 360)
        endPos = UDim2.new(math.clamp(x + math.random(-10, 10) / 100, 0, 1), 0, 1.1, 0)
        endRot = lbl.Rotation + 360
    end

    local info = TweenInfo.new(duration, Enum.EasingStyle.Linear)
    TweenService:Create(lbl, info, { Position = endPos, Rotation = endRot }):Play()
    task.delay(duration, function()
        lbl:Destroy()
    end)
end

local function startDecor(deco)
    decorGen = decorGen + 1
    local gen = decorGen
    decorLayer:ClearAllChildren()
    if not deco then return end
    task.spawn(function()
        while gen == decorGen do
            spawnDecorItem(deco, gen)
            task.wait(deco.rate)
        end
    end)
end

-- ============================
-- ESP TAB
-- ============================
local findMurderBtn = makeButton(espPage, "🔪 FIND MURDERER", 0, COLOR_RED)
local findSheriffBtn = makeButton(espPage, "🔫 FIND SHERIFF", 50, COLOR_BLUE)
local viewBothBtn, viewBothStroke = makeButton(espPage, "👁 VIEW BOTH", 100, Color3.fromRGB(180, 80, 255))
local seeAllBtn, seeAllStroke = makeButton(espPage, "◈ SEE ALL", 150, Color3.fromRGB(255, 200, 50))
local tracersBtn, tracersStroke = makeButton(espPage, "➳ TRACERS", 200, Color3.fromRGB(80, 220, 255))

findMurderBtn.MouseButton1Click:Connect(function()
    clearOutlines()
    local murderer = findMurderer()
    if murderer then
        outlinePlayer(murderer, true, COLOR_RED)
        setStatus("🔪 " .. murderer.DisplayName .. " is the MURDERER", COLOR_RED)
    else
        setStatus("No murderer found.")
    end
end)

findSheriffBtn.MouseButton1Click:Connect(function()
    clearOutlines()
    local sheriff = findSheriffThatsNotMe()
    if sheriff then
        outlinePlayer(sheriff, true, COLOR_BLUE)
        setStatus("🔫 " .. sheriff.DisplayName .. " is the SHERIFF", COLOR_BLUE)
    else
        setStatus("No sheriff found.")
    end
end)

-- VIEW BOTH: keeps itself up to date. When the sheriff or murderer changes
-- (or dies / respawns) the highlights and labels are redrawn.
local viewBothOn = false
local viewBothGen = 0
local lastMurd, lastSheriff = nil, nil

local function refreshViewBoth(force)
    local murderer = findMurderer()
    local sheriff = findSheriffThatsNotMe()

    local needsRedraw = force
        or murderer ~= lastMurd
        or sheriff ~= lastSheriff
        or (murderer and murderer.Character and not murderer.Character:FindFirstChild("OutlineHighlight"))
        or (sheriff and sheriff.Character and not sheriff.Character:FindFirstChild("OutlineHighlight"))
    if not needsRedraw then return end

    lastMurd, lastSheriff = murderer, sheriff
    clearOutlines()
    clearBillboards()

    local lines = {}
    if murderer then
        outlinePlayer(murderer, true, COLOR_RED)
        addBillboard(murderer, "⚔ MURDERER", COLOR_RED)
        table.insert(lines, "🔪 " .. murderer.DisplayName .. " = MURDERER")
    else
        table.insert(lines, "🔪 No murderer found")
    end
    if sheriff then
        outlinePlayer(sheriff, true, COLOR_BLUE)
        addBillboard(sheriff, "🛡 SHERIFF", COLOR_BLUE)
        table.insert(lines, "🔫 " .. sheriff.DisplayName .. " = SHERIFF")
    else
        table.insert(lines, "🔫 No sheriff found")
    end
    setStatus(table.concat(lines, "\n"), COLOR_TEXT)
end

viewBothBtn.MouseButton1Click:Connect(function()
    viewBothOn = not viewBothOn
    viewBothGen = viewBothGen + 1
    local gen = viewBothGen
    if not viewBothOn then
        clearOutlines()
        clearBillboards()
        lastMurd, lastSheriff = nil, nil
        viewBothBtn.Text = "👁 VIEW BOTH"
        setToggleVisual(viewBothStroke, false)
        setStatus("View Both OFF")
        return
    end
    viewBothBtn.Text = "👁 HIDE BOTH"
    setToggleVisual(viewBothStroke, true)
    lastMurd, lastSheriff = nil, nil
    refreshViewBoth(true)
    task.spawn(function()
        while viewBothOn and gen == viewBothGen do
            task.wait(0.5)
            pcall(refreshViewBoth, false)
        end
    end)
end)

local seeAllOn = false
seeAllBtn.MouseButton1Click:Connect(function()
    seeAllOn = not seeAllOn
    clearOutlines()
    if not seeAllOn then
        seeAllBtn.Text = "◈ SEE ALL"
        setToggleVisual(seeAllStroke, false)
        setStatus("SEE ALL OFF")
        return
    end
    seeAllBtn.Text = "◈ HIDE ALL"
    setToggleVisual(seeAllStroke, true)
    local count = 0
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= player and plr.Character and not hasToolMatching(plr, "knife") then
            outlinePlayer(plr, true, COLOR_GREEN)
            count = count + 1
        end
    end
    setStatus("Outlined " .. count .. " innocent player" .. (count == 1 and "" or "s"), COLOR_GREEN)
end)

-- TRACERS
local tracersOn = false
local tracers = {}

local function destroyTracer(plr)
    local t = tracers[plr]
    if t then
        if t.beam then t.beam:Destroy() end
        if t.a0 then t.a0:Destroy() end
        if t.a1 then t.a1:Destroy() end
        tracers[plr] = nil
    end
end

local function clearAllTracers()
    for plr in pairs(tracers) do
        destroyTracer(plr)
    end
end

local function getLivingHRP(plr)
    local char = plr.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not char or not hum or hum.Health <= 0 then return nil end
    return char:FindFirstChild("HumanoidRootPart")
end

local function tracerColorFor(plr)
    if hasToolMatching(plr, "knife") then return COLOR_RED end
    if hasToolMatching(plr, "gun") then return COLOR_BLUE end
    return Color3.fromRGB(230, 230, 230)
end

local function ensureTracer(plr)
    local myHRP = getLivingHRP(player)
    local theirHRP = getLivingHRP(plr)
    if not myHRP or not theirHRP then
        destroyTracer(plr)
        return
    end

    local t = tracers[plr]
    if t and t.a0.Parent == myHRP and t.a1.Parent == theirHRP then
        t.beam.Color = ColorSequence.new(tracerColorFor(plr))
        return
    end

    destroyTracer(plr)
    local a0 = Instance.new("Attachment")
    a0.Name = "MM2_TracerA0"
    a0.Parent = myHRP
    local a1 = Instance.new("Attachment")
    a1.Name = "MM2_TracerA1"
    a1.Parent = theirHRP

    local beam = Instance.new("Beam")
    beam.Name = "MM2_Tracer"
    beam.Attachment0 = a0
    beam.Attachment1 = a1
    beam.Color = ColorSequence.new(tracerColorFor(plr))
    beam.Width0 = 0.12
    beam.Width1 = 0.12
    beam.FaceCamera = true
    beam.LightEmission = 1
    beam.Transparency = NumberSequence.new(0.2)
    beam.Parent = myHRP

    tracers[plr] = { beam = beam, a0 = a0, a1 = a1 }
end

local function refreshTracers()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= player then
            ensureTracer(plr)
        end
    end
    for plr in pairs(tracers) do
        if plr.Parent ~= Players or plr == player then
            destroyTracer(plr)
        end
    end
end

task.spawn(function()
    while true do
        task.wait(0.2)
        if tracersOn then
            pcall(refreshTracers)
        end
    end
end)

tracersBtn.MouseButton1Click:Connect(function()
    tracersOn = not tracersOn
    if tracersOn then
        tracersBtn.Text = "➳ HIDE TRACERS"
        setToggleVisual(tracersStroke, true)
        pcall(refreshTracers)
        setStatus("Tracers ON")
    else
        tracersBtn.Text = "➳ TRACERS"
        setToggleVisual(tracersStroke, false)
        clearAllTracers()
        setStatus("Tracers OFF")
    end
end)

-- ============================
-- COMBAT TAB
-- ============================
local toggleAimBtn, aimStroke = makeButton(combatPage, "◎ ENABLE AUTO AIM", 0, Color3.fromRGB(255, 60, 100))
local autoShootBtn, autoShootStroke = makeButton(combatPage, "🎯 AUTO SHOOT", 50, COLOR_BLUE)
local autoMurdWinBtn, murdWinStroke = makeButton(combatPage, "⚔ AUTO MURD WIN", 100, COLOR_RED)
local autoGunBtn, autoGunStroke = makeButton(combatPage, "🔫 AUTO GRAB GUN", 150, COLOR_BLUE)
local reachBtn, reachStroke = makeButton(combatPage, "📏 MURDER REACH", 200, Color3.fromRGB(0, 200, 180))

local scrollingFrame = Instance.new("ScrollingFrame")
scrollingFrame.Size = UDim2.new(1, 0, 0, 120)
scrollingFrame.Position = UDim2.new(0, 0, 0, 250)
scrollingFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 26)
scrollingFrame.BackgroundTransparency = 0.2
scrollingFrame.BorderSizePixel = 0
scrollingFrame.ScrollBarThickness = 4
scrollingFrame.ScrollBarImageColor3 = Color3.fromRGB(255, 60, 100)
scrollingFrame.ZIndex = 3
scrollingFrame.Parent = combatPage
corner(scrollingFrame, 8)

local listLayout = Instance.new("UIListLayout")
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Padding = UDim.new(0, 4)
listLayout.Parent = scrollingFrame

local listPad = Instance.new("UIPadding")
listPad.PaddingLeft = UDim.new(0, 6)
listPad.PaddingRight = UDim.new(0, 6)
listPad.PaddingTop = UDim.new(0, 6)
listPad.Parent = scrollingFrame

local aimEnabled = false
local target = nil

-- AUTO AIM
-- Locks your camera onto the selected target every frame (PC crosshair and
-- mobile shiftlock both follow the camera). While you hold the Gun it fires
-- at the target about every 0.15s, through the Shoot remote, or GunFired if
-- the Shoot remote can't be found.
local BULLET_SPEED = 250 -- assumed bullet speed (studs/sec) used for aim prediction
local AIM_BIND = "MM2HubAutoAim"
local aimBound = false
local aimShotTimer = 0
local gunFiredRemote = nil

local function findGunFiredRemote()
    for _, obj in ipairs(game:GetDescendants()) do
        if obj.Name == "GunFired" and obj:IsA("RemoteEvent") then
            return obj
        end
    end
    return nil
end

local function aimEquipGun()
    local char = player.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not char or not hum then return nil end
    if not char:FindFirstChild("Gun") then
        local bp = player.Backpack:FindFirstChild("Gun")
        if bp then
            hum:EquipTool(bp)
            task.wait(0.05)
        end
    end
    return char:FindFirstChild("Gun")
end

local function aimFire(pos)
    local gun = aimEquipGun()
    if not gun then return end

    local remote = gun:FindFirstChild("KnifeLocal")
        and gun.KnifeLocal:FindFirstChild("CreateBeam")
        and gun.KnifeLocal.CreateBeam:FindFirstChild("RemoteFunction")
    if remote then
        pcall(function()
            remote:InvokeServer(1, pos, "AH2")
        end)
    else
        if not gunFiredRemote then
            gunFiredRemote = findGunFiredRemote()
        end
        if gunFiredRemote then
            pcall(function()
                gunFiredRemote:FireServer(pos)
            end)
        end
    end
end

local function aimStep(dt)
    if not aimEnabled or not target then return end
    local tChar = target.Character
    local part = tChar and (tChar:FindFirstChild("Head") or tChar:FindFirstChild("HumanoidRootPart"))
    if not part or isDead(target) then return end

    -- Predict where the target will be when the shot arrives (velocity * travel time)
    local hrp = tChar:FindFirstChild("HumanoidRootPart")
    local velocity = hrp and hrp.AssemblyLinearVelocity or Vector3.zero
    local travelTime = (part.Position - camera.CFrame.Position).Magnitude / BULLET_SPEED
    local aimPos = part.Position + velocity * travelTime

    camera.CFrame = CFrame.lookAt(camera.CFrame.Position, aimPos)

    if hasLocalGun() then
        aimShotTimer = aimShotTimer + dt
        if aimShotTimer >= 0.15 then
            aimShotTimer = 0
            aimFire(aimPos)
        end
    end
end

local function setAimBound(on)
    if on and not aimBound then
        RunService:BindToRenderStep(AIM_BIND, Enum.RenderPriority.Camera.Value + 1, aimStep)
        aimBound = true
    elseif not on and aimBound then
        RunService:UnbindFromRenderStep(AIM_BIND)
        aimBound = false
    end
end

toggleAimBtn.MouseButton1Click:Connect(function()
    aimEnabled = not aimEnabled
    if aimEnabled then
        toggleAimBtn.Text = "◎ DISABLE AUTO AIM"
        setAimBound(true)
        if target then
            setStatus("◎ Locked on " .. target.DisplayName, Color3.fromRGB(255, 60, 100))
        else
            setStatus("◎ Aim on, pick a target below", Color3.fromRGB(255, 60, 100))
        end
    else
        toggleAimBtn.Text = "◎ ENABLE AUTO AIM"
        target = nil
        setAimBound(false)
        setStatus("AUTO AIM OFF")
    end
    setToggleVisual(aimStroke, aimEnabled)
end)

local function createPlayerButton(plr)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 36)
    btn.BackgroundColor3 = Color3.fromRGB(22, 22, 34)
    btn.BorderSizePixel = 0
    btn.Text = ""
    btn.ZIndex = 4
    btn.Parent = scrollingFrame
    corner(btn, 6)

    local btnStroke = Instance.new("UIStroke")
    btnStroke.Color = Color3.fromRGB(40, 40, 60)
    btnStroke.Thickness = 1
    btnStroke.Parent = btn

    local thumb = Instance.new("ImageLabel")
    thumb.Size = UDim2.new(0, 28, 0, 28)
    thumb.Position = UDim2.new(0, 6, 0.5, -14)
    thumb.BackgroundColor3 = Color3.fromRGB(30, 30, 48)
    thumb.BorderSizePixel = 0
    thumb.Image = "rbxthumb://type=AvatarHeadShot&id=" .. plr.UserId .. "&w=100&h=100"
    thumb.ZIndex = 5
    thumb.Parent = btn
    corner(thumb, 4)

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, -50, 1, 0)
    nameLabel.Position = UDim2.new(0, 42, 0, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = plr.DisplayName
    nameLabel.TextColor3 = COLOR_TEXT
    nameLabel.TextScaled = true
    nameLabel.Font = activeFont
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.ZIndex = 5
    nameLabel.Parent = btn

    btn.MouseButton1Click:Connect(function()
        target = plr
        for _, v in ipairs(scrollingFrame:GetChildren()) do
            if v:IsA("TextButton") then
                local s = v:FindFirstChildOfClass("UIStroke")
                if s then
                    s.Color = (v == btn) and Color3.fromRGB(255, 60, 100) or Color3.fromRGB(40, 40, 60)
                    s.Thickness = (v == btn) and 1.5 or 1
                end
                TweenService:Create(v, TweenInfo.new(0.1), {
                    BackgroundColor3 = (v == btn) and Color3.fromRGB(35, 20, 40) or Color3.fromRGB(22, 22, 34)
                }):Play()
            end
        end
        setStatus("◎ Targeting: " .. plr.DisplayName, Color3.fromRGB(255, 60, 100))
    end)
end

local function updatePlayerList()
    for _, v in ipairs(scrollingFrame:GetChildren()) do
        if v:IsA("TextButton") then v:Destroy() end
    end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= player then createPlayerButton(plr) end
    end
    scrollingFrame.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 14)
end
Players.PlayerAdded:Connect(updatePlayerList)
Players.PlayerRemoving:Connect(updatePlayerList)
updatePlayerList()

-- AUTO SHOOT (snippet logic)
local autoShootOn = false
local shootLoopRunning = false

local function autoShootStep()
    local char = player.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not hum or not root then return end

    local murderer = findMurderer() or findSheriffThatsNotMe()
    if not murderer then
        setStatus("MM2 Autoshoot - No murderer.")
        return
    end

    local murdererHRP = murderer.Character and murderer.Character:FindFirstChild("HumanoidRootPart")
    if not murdererHRP then return end

    local delta = murdererHRP.Position - root.Position
    if delta.Magnitude < 0.1 then return end

    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.FilterDescendantsInstances = { char }
    local hit = workspace:Raycast(root.Position, delta.Unit * 50, rayParams)

    if hit and hit.Instance.Parent ~= murderer.Character then
        return
    end

    local gun = char:FindFirstChild("Gun")
    if not gun then
        local backpackGun = player.Backpack:FindFirstChild("Gun")
        if not backpackGun then
            setStatus("You don't have the gun..?", COLOR_RED)
            return
        end
        hum:EquipTool(backpackGun)
        task.wait(0.1)
        gun = char:FindFirstChild("Gun")
        if not gun then return end
    end

    local remote = gun:FindFirstChild("KnifeLocal")
        and gun.KnifeLocal:FindFirstChild("CreateBeam")
        and gun.KnifeLocal.CreateBeam:FindFirstChild("RemoteFunction")
    if not remote then
        setStatus("Shoot remote not found on the Gun.", COLOR_RED)
        return
    end

    local predictedPosition = murdererHRP.Position
        + (murdererHRP.AssemblyLinearVelocity * Vector3.new(1, 0.5, 1)) * (SHOOT_OFFSET / 15)

    local ok, err = pcall(function()
        remote:InvokeServer(1, predictedPosition, "AH2")
    end)
    if ok then
        setStatus("Auto-shooting " .. murderer.DisplayName, COLOR_BLUE)
    else
        setStatus("Shoot failed: " .. tostring(err), COLOR_RED)
    end
end

local function startAutoShootLoop()
    if shootLoopRunning then return end
    shootLoopRunning = true
    task.spawn(function()
        while autoShootOn do
            task.wait(0.1)
            if hasLocalGun() then
                local ok, err = pcall(autoShootStep)
                if not ok then warn("[MM2 AutoShoot] " .. tostring(err)) end
            end
        end
        shootLoopRunning = false
    end)
end

autoShootBtn.MouseButton1Click:Connect(function()
    if not autoShootOn then
        if not hasLocalGun() then
            setStatus("You need the Gun tool to use Auto Shoot.", COLOR_RED)
            return
        end
        autoShootOn = true
        autoShootBtn.Text = "🎯 STOP AUTO SHOOT"
        setToggleVisual(autoShootStroke, true)
        setStatus("AUTO SHOOT ON", COLOR_BLUE)
        startAutoShootLoop()
    else
        autoShootOn = false
        autoShootBtn.Text = "🎯 AUTO SHOOT"
        setToggleVisual(autoShootStroke, false)
        setStatus("AUTO SHOOT OFF")
    end
end)

-- AUTO MURD WIN
local murdWinOn = false

local function murdWinLoop()
    while murdWinOn do
        task.wait(0.1)
        local char = player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hrp and hum then
            local knife = findOwnTool("knife")
            if not knife then
                setStatus("No knife detected bruh, get out", COLOR_RED)
                task.wait(2)
            else
                if knife.Parent ~= char then
                    hum:EquipTool(knife)
                end
                for _, plr in ipairs(Players:GetPlayers()) do
                    if not murdWinOn then break end
                    local tHRP = plr ~= player and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
                    if tHRP and not isDead(plr) then
                        hrp.CFrame = CFrame.new(tHRP.Position + Vector3.new(math.random(-3, 3), 0, math.random(-3, 3)))
                        pcall(function() knife:Activate() end)
                        task.wait(0.12)
                    end
                end
            end
        end
    end
end

autoMurdWinBtn.MouseButton1Click:Connect(function()
    murdWinOn = not murdWinOn
    if murdWinOn then
        autoMurdWinBtn.Text = "⚔ STOP MURD WIN"
        setToggleVisual(murdWinStroke, true)
        setStatus("AUTO MURD WIN ACTIVE", COLOR_RED)
        task.spawn(murdWinLoop)
    else
        autoMurdWinBtn.Text = "⚔ AUTO MURD WIN"
        setToggleVisual(murdWinStroke, false)
        setStatus("AUTO MURD WIN OFF")
    end
end)

-- AUTO GRAB GUN
local autoGunOn = false
local watchedHolder = nil
local lastHolderPos = nil -- last spot the Gun holder was seen alive
local gunSent = false -- already teleported for this death

local function findDroppedGun()
    for _, item in ipairs(workspace:GetDescendants()) do
        if item:IsA("Tool") and item.Name == "Gun" and item:FindFirstChild("Handle") then
            local p = item.Parent
            if p and not p:IsA("Backpack") and not p:FindFirstChildOfClass("Humanoid") then
                return item
            end
        end
    end
    return nil
end

local function autoGunLoop()
    while autoGunOn do
        task.wait(0.2)
        local char = player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")

        if hasLocalGun() then
            watchedHolder = nil
            gunSent = false
            setStatus("You have the gun!", Color3.fromRGB(100, 255, 100))
        else
            local holder = findSheriffThatsNotMe()
            if holder and not isDead(holder) then
                -- sheriff is alive: remember where they are and wait
                watchedHolder = holder
                gunSent = false
                local hh = holder.Character and holder.Character:FindFirstChild("HumanoidRootPart")
                if hh then
                    lastHolderPos = hh.Position
                end
                setStatus("Sheriff: " .. holder.DisplayName .. "\nWaiting for death...", COLOR_BLUE)
            elseif not gunSent then
                -- sheriff is dead (or was already dead when turned on):
                -- go to the dropped gun, or to the last spot the sheriff was seen
                local gunTool = findDroppedGun()
                local spot = nil
                if gunTool then
                    spot = gunTool.Handle.Position
                elseif lastHolderPos then
                    spot = lastHolderPos
                end

                if spot and hrp then
                    hrp.CFrame = CFrame.new(spot + Vector3.new(0, 4, 0))
                    gunSent = true
                    setStatus(gunTool and "Sheriff died, grabbing the gun!" or "Sheriff died here, going to last spot...", Color3.fromRGB(100, 255, 100))
                else
                    setStatus("No dropped gun or sheriff spot found yet", COLOR_RED)
                end
            end
        end
    end
end

autoGunBtn.MouseButton1Click:Connect(function()
    autoGunOn = not autoGunOn
    if autoGunOn then
        autoGunBtn.Text = "🔫 STOP AUTO GUN"
        setToggleVisual(autoGunStroke, true)
        watchedHolder = nil
        setStatus("AUTO GRAB GUN ACTIVE\nWaiting for sheriff...", COLOR_BLUE)
        task.spawn(autoGunLoop)
    else
        autoGunBtn.Text = "🔫 AUTO GRAB GUN"
        setToggleVisual(autoGunStroke, false)
        watchedHolder = nil
        setStatus("AUTO GRAB GUN OFF")
    end
end)

-- MURDER REACH
-- Enlarges other players' HumanoidRootPart and turns off collisions on their
-- parts, so you walk through the big hitbox instead of getting blocked by it.
-- Client-side: the server still decides what counts as a hit.
local reachOn = false
local reachRunning = false
local reachSize = math.clamp(tonumber(settings.reachSize) or 10, REACH_MIN, REACH_MAX)

local function reachVector()
    return Vector3.new(reachSize, reachSize, reachSize)
end
local reachOriginal = {} -- [Player] = { hrp, size, transparency, collide = {[part] = canCollide} }

local function setReach(plr, on)
    local char = plr.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local saved = reachOriginal[plr]

    if on then
        if not saved or saved.hrp ~= hrp then
            saved = { hrp = hrp, size = hrp.Size, transparency = hrp.Transparency, collide = {} }
            reachOriginal[plr] = saved
        end
        hrp.Size = reachVector()
        hrp.Transparency = 0.7
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                if saved.collide[part] == nil then
                    saved.collide[part] = part.CanCollide
                end
                part.CanCollide = false
            end
        end
    elseif saved and saved.hrp == hrp then
        hrp.Size = saved.size
        hrp.Transparency = saved.transparency
        for part, cc in pairs(saved.collide) do
            if part.Parent then
                part.CanCollide = cc
            end
        end
        reachOriginal[plr] = nil
    end
end

local function startReachLoop()
    if reachRunning then return end
    reachRunning = true
    task.spawn(function()
        while reachOn do
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= player then
                    pcall(setReach, plr, true)
                end
            end
            task.wait(0.5)
        end
        for _, plr in ipairs(Players:GetPlayers()) do
            pcall(setReach, plr, false)
        end
        reachRunning = false
    end)
end

reachBtn.MouseButton1Click:Connect(function()
    reachOn = not reachOn
    if reachOn then
        reachBtn.Text = "📏 STOP REACH"
        setToggleVisual(reachStroke, true)
        setStatus("MURDER REACH ON", Color3.fromRGB(0, 200, 180))
        startReachLoop()
    else
        reachBtn.Text = "📏 MURDER REACH"
        setToggleVisual(reachStroke, false)
        setStatus("MURDER REACH OFF")
    end
end)

do -- MURDER REACH SIZE POPUP (right-click the MURDER REACH button)
local reachPopup = Instance.new("Frame")
reachPopup.Name = "ReachPopup"
reachPopup.Size = UDim2.new(1, -24, 0, 170)
reachPopup.Position = UDim2.new(0, 12, 0, 96)
reachPopup.BackgroundColor3 = Color3.fromRGB(18, 18, 26)
reachPopup.BorderSizePixel = 0
reachPopup.Visible = false
reachPopup.ZIndex = 20
reachPopup.Parent = mainFrame
corner(reachPopup, 10)

local popStroke = Instance.new("UIStroke")
popStroke.Color = Color3.fromRGB(0, 200, 180)
popStroke.Thickness = 1.5
popStroke.Parent = reachPopup

local popTitle = Instance.new("TextLabel")
popTitle.Size = UDim2.new(1, -20, 0, 24)
popTitle.Position = UDim2.new(0, 10, 0, 8)
popTitle.BackgroundTransparency = 1
popTitle.Text = "MURDER REACH SIZE"
popTitle.TextColor3 = COLOR_TEXT
popTitle.TextScaled = true
popTitle.Font = activeFont
popTitle.ZIndex = 21
popTitle.Parent = reachPopup

local popValue = Instance.new("TextLabel")
popValue.Size = UDim2.new(1, -20, 0, 20)
popValue.Position = UDim2.new(0, 10, 0, 40)
popValue.BackgroundTransparency = 1
popValue.TextColor3 = Color3.fromRGB(0, 200, 180)
popValue.TextScaled = true
popValue.Font = activeFont
popValue.ZIndex = 21
popValue.Parent = reachPopup

local track = Instance.new("Frame")
track.Size = UDim2.new(1, -40, 0, 8)
track.Position = UDim2.new(0, 20, 0, 84)
track.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
track.BorderSizePixel = 0
track.ZIndex = 21
track.Parent = reachPopup
corner(track, 4)

local fill = Instance.new("Frame")
fill.Size = UDim2.new(0, 0, 1, 0)
fill.BackgroundColor3 = Color3.fromRGB(0, 200, 180)
fill.BorderSizePixel = 0
fill.ZIndex = 22
fill.Parent = track
corner(fill, 4)

local knob = Instance.new("TextButton")
knob.Size = UDim2.new(0, 18, 0, 18)
knob.AnchorPoint = Vector2.new(0.5, 0.5)
knob.Position = UDim2.new(0, 0, 0.5, 0)
knob.BackgroundColor3 = Color3.new(1, 1, 1)
knob.BorderSizePixel = 0
knob.AutoButtonColor = false
knob.Text = ""
knob.ZIndex = 23
knob.Parent = track
corner(knob, 9)

local draggingSlider = false

local function setReachSize(v)
    reachSize = math.clamp(math.floor(v + 0.5), REACH_MIN, REACH_MAX)
    settings.reachSize = reachSize
    saveSettings()
    local frac = (reachSize - REACH_MIN) / (REACH_MAX - REACH_MIN)
    fill.Size = UDim2.new(frac, 0, 1, 0)
    knob.Position = UDim2.new(frac, 0, 0.5, 0)
    popValue.Text = "Size: " .. reachSize .. " studs"
end

local function sliderFromX(x)
    local rel = (x - track.AbsolutePosition.X) / math.max(1, track.AbsoluteSize.X)
    setReachSize(REACH_MIN + math.clamp(rel, 0, 1) * (REACH_MAX - REACH_MIN))
end

local function beginSlide(input)
    if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
        return
    end
    draggingSlider = true
    rgbBorder.Draggable = false -- stop the window from moving while sliding
    sliderFromX(input.Position.X)
end

track.InputBegan:Connect(beginSlide)
knob.InputBegan:Connect(beginSlide)

UserInputService.InputChanged:Connect(function(input)
    if draggingSlider and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        sliderFromX(input.Position.X)
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if draggingSlider and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
        draggingSlider = false
        rgbBorder.Draggable = true
    end
end)

local reachDone = Instance.new("TextButton")
reachDone.Size = UDim2.new(0, 100, 0, 28)
reachDone.Position = UDim2.new(0.5, -50, 1, -40)
reachDone.BackgroundColor3 = Color3.fromRGB(24, 24, 36)
reachDone.BorderSizePixel = 0
reachDone.Text = "DONE"
reachDone.TextColor3 = COLOR_TEXT
reachDone.TextScaled = true
reachDone.Font = activeFont
reachDone.ZIndex = 21
reachDone.Parent = reachPopup
corner(reachDone, 6)

reachDone.MouseButton1Click:Connect(function()
    reachPopup.Visible = false
end)

reachBtn.MouseButton2Click:Connect(function()
    reachPopup.Visible = not reachPopup.Visible
end)

setReachSize(reachSize)

end -- MURDER REACH SIZE POPUP

-- ============================
-- PLAYER TAB
-- ============================
local noclipJumpBtn, noclipStroke = makeButton(playerPage, "⚡ NOCLIP / INF JUMP", 0, Color3.fromRGB(0, 200, 180))
local invisBtn, invisStroke = makeButton(playerPage, "◌ INVIS", 50, Color3.fromRGB(180, 80, 255))
local autoCoinBtn, autoCoinStroke = makeButton(playerPage, "🪙 AUTO COIN", 100, COLOR_GOLD)

-- AUTO COIN
-- Tweens to each Coin_Server part inside a model named CoinContainer at 50
-- studs/sec, nearest first. Waits for the CoinCollected remote before moving on.
local autoCoinOn = false
local coinRunning = false
local coinSignal = Instance.new("BindableEvent")

local function findRemoteNamed(name)
    for _, obj in ipairs(game:GetDescendants()) do
        if obj.Name == name and obj:IsA("RemoteEvent") then
            return obj
        end
    end
    return nil
end

local function getCoins()
    local list = {}
    for _, container in ipairs(workspace:GetDescendants()) do
        if container:IsA("Model") and container.Name == "CoinContainer" then
            for _, d in ipairs(container:GetDescendants()) do
                if d:IsA("BasePart") and d.Name == "Coin_Server" then
                    table.insert(list, d)
                end
            end
        end
    end
    return list
end

local function tweenToCoin(root, coin)
    local dist = (coin.Position - root.Position).Magnitude
    local duration = math.max(0.05, dist / COIN_SPEED)
    local tween = TweenService:Create(root, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
        CFrame = CFrame.new(coin.Position + Vector3.new(0, 3, 0)),
    })
    local done = false
    local conn = tween.Completed:Connect(function()
        done = true
    end)
    tween:Play()
    local t = 0
    while not done and autoCoinOn and coin.Parent and t < duration + 1 do
        task.wait(0.05)
        t = t + 0.05
    end
    conn:Disconnect()
    tween:Cancel()
end

local function autoCoinLoop()
    local remote = findRemoteNamed("CoinCollected")
    local remoteConn
    if remote then
        remoteConn = remote.OnClientEvent:Connect(function(...)
            coinSignal:Fire(...)
        end)
    else
        setStatus("CoinCollected remote not found, using coin removal instead.", Color3.fromRGB(255, 200, 50))
    end

    local skipped = {}
    while autoCoinOn do
        local char = player.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not root or not hum or hum.Health <= 0 then
            task.wait(0.5)
        else
            local coins = getCoins()
            local candidates = {}
            for _, c in ipairs(coins) do
                if c.Parent and not skipped[c] then
                    table.insert(candidates, c)
                end
            end

            if #coins == 0 then
                setStatus("No Coin_Server parts found in CoinContainer.", Color3.fromRGB(255, 200, 50))
                task.wait(1)
            elseif #candidates == 0 then
                skipped = {}
                task.wait(1)
            else
                table.sort(candidates, function(a, b)
                    return (a.Position - root.Position).Magnitude < (b.Position - root.Position).Magnitude
                end)
                local coin = candidates[1]

                local fired = false
                local fireConn = coinSignal.Event:Connect(function()
                    fired = true
                end)

                tweenToCoin(root, coin)

                local t = 0
                while not fired and coin.Parent and t < COIN_TIMEOUT and autoCoinOn do
                    task.wait(0.1)
                    t = t + 0.1
                end
                fireConn:Disconnect()

                local got = fired or coin.Parent == nil
                if not got then
                    skipped[coin] = true
                end
                setStatus("Auto Coin: " .. #candidates .. " coins left", COLOR_GOLD)
                task.wait(0.2)
            end
        end
    end

    if remoteConn then remoteConn:Disconnect() end
    coinRunning = false
end

autoCoinBtn.MouseButton1Click:Connect(function()
    autoCoinOn = not autoCoinOn
    if autoCoinOn then
        autoCoinBtn.Text = "🪙 STOP AUTO COIN"
        setToggleVisual(autoCoinStroke, true)
        if not coinRunning then
            coinRunning = true
            task.spawn(autoCoinLoop)
        end
    else
        autoCoinBtn.Text = "🪙 AUTO COIN"
        setToggleVisual(autoCoinStroke, false)
        setStatus("AUTO COIN OFF")
    end
end)

-- INVIS (camera can be moved with the mouse while invisible)
local invisActive = false
local invisSurface = nil
local invisCamCF = nil
local invisSinking = false
local invisRising = false
local wasInvisBeforeRespawn = false
local invisYaw, invisPitch = 0, 0

local function forceNoclipChar(char)
    for _, p in ipairs(char:GetDescendants()) do
        if p:IsA("BasePart") then p.CanCollide = false end
    end
end

local function restoreCollision(char)
    for _, p in ipairs(char:GetDescendants()) do
        if p:IsA("BasePart") then
            p.CanCollide = p.Name ~= "HumanoidRootPart"
        end
    end
end

local function applyInvis(char)
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not humanoid then return end

    humanoid.PlatformStand = true
    invisSurface = hrp.Position.Y
    invisCamCF = camera.CFrame
    humanoid.CameraOffset = Vector3.new(0, 0, 0)
    forceNoclipChar(char)
    invisSinking = true

    local targetCF = CFrame.new(hrp.Position.X, hrp.Position.Y - INVIS_DEPTH, hrp.Position.Z) * (hrp.CFrame - hrp.CFrame.Position)
    local sinkTween = TweenService:Create(hrp, TweenInfo.new(0.7, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { CFrame = targetCF })
    sinkTween:Play()
    sinkTween.Completed:Connect(function()
        invisSinking = false
        if invisActive then
            humanoid.PlatformStand = false
        end
    end)
end

local function removeInvis(char)
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not humanoid then return end

    humanoid.PlatformStand = true
    invisRising = true
    invisCamCF = camera.CFrame
    local surfaceY = invisSurface or (hrp.Position.Y + INVIS_DEPTH)
    local targetCF = CFrame.new(hrp.Position.X, surfaceY, hrp.Position.Z) * (hrp.CFrame - hrp.CFrame.Position)

    local riseTween = TweenService:Create(hrp, TweenInfo.new(0.6, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { CFrame = targetCF })
    riseTween:Play()
    riseTween.Completed:Connect(function()
        invisRising = false
        invisCamCF = nil
        invisSurface = nil
        if humanoid then
            humanoid.PlatformStand = false
        end
        task.wait(0.2)
        if char and char.Parent then
            restoreCollision(char)
            camera.CameraType = Enum.CameraType.Custom
        end
    end)
end

invisBtn.MouseButton1Click:Connect(function()
    invisActive = not invisActive
    local char = player.Character
    if invisActive then
        local rx, ry = camera.CFrame:ToOrientation()
        invisPitch = math.clamp(rx, -1.3, 1.3)
        invisYaw = ry
        invisBtn.Text = "◌ SHOW SELF"
        setToggleVisual(invisStroke, true)
        wasInvisBeforeRespawn = true
        setStatus("Under map\nWalk normally, move mouse to look", Color3.fromRGB(180, 80, 255))
        applyInvis(char)
    else
        invisBtn.Text = "◌ INVIS"
        setToggleVisual(invisStroke, false)
        wasInvisBeforeRespawn = false
        setStatus("Surfacing...")
        removeInvis(char)
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if invisActive and not invisSinking and not invisRising and input.UserInputType == Enum.UserInputType.MouseMovement then
        invisYaw = invisYaw - input.Delta.X * 0.004
        invisPitch = math.clamp(invisPitch - input.Delta.Y * 0.004, -1.3, 1.3)
    end
end)

player.CharacterAdded:Connect(function(char)
    if wasInvisBeforeRespawn and invisActive then
        task.wait(0.5)
        applyInvis(char)
    elseif not wasInvisBeforeRespawn then
        invisActive = false
        invisBtn.Text = "◌ INVIS"
        setToggleVisual(invisStroke, false)
    end
end)

RunService.RenderStepped:Connect(function()
    if not invisActive and not invisSinking and not invisRising then return end
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    if invisSinking or invisRising then
        if invisCamCF then
            camera.CameraType = Enum.CameraType.Scriptable
            camera.CFrame = invisCamCF
        end
    elseif invisActive then
        local hrpPos = hrp.Position
        local surfaceY = invisSurface or (hrpPos.Y + INVIS_DEPTH)
        local center = Vector3.new(hrpPos.X, surfaceY + 1.5, hrpPos.Z)
        camera.CameraType = Enum.CameraType.Scriptable
        camera.CFrame = CFrame.new(center) * CFrame.Angles(0, invisYaw, 0) * CFrame.Angles(invisPitch, 0, 0)
    end
end)

RunService.Stepped:Connect(function(_, dt)
    local char = player.Character
    if invisActive and not invisSinking and not invisRising and char then
        forceNoclipChar(char)
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        if hrp and humanoid then
            local targetY = (invisSurface or hrp.Position.Y) - INVIS_DEPTH + 3
            local diff = targetY - hrp.Position.Y
            if math.abs(diff) > 0.05 then
                hrp.CFrame = hrp.CFrame + Vector3.new(0, diff * math.min(dt * 20, 1), 0)
            end
        end
    end
end)

-- NOCLIP / INF JUMP
local noclip = false
local infiniteJump = false

local function setCollisionForChar(char, canCollide)
    if not char then return end
    for _, part in ipairs(char:GetChildren()) do
        if part:IsA("BasePart") then part.CanCollide = canCollide end
    end
end

noclipJumpBtn.MouseButton1Click:Connect(function()
    noclip = not noclip
    infiniteJump = not infiniteJump
    if noclip then
        setStatus("⚡ Noclip & Inf Jump ON", Color3.fromRGB(0, 200, 180))
        setToggleVisual(noclipStroke, true)
        setCollisionForChar(player.Character, false)
    else
        setStatus("⚡ Noclip & Inf Jump OFF")
        setToggleVisual(noclipStroke, false)
        setCollisionForChar(player.Character, true)
    end
end)

RunService.Stepped:Connect(function()
    if noclip then
        setCollisionForChar(player.Character, false)
    end
end)

UserInputService.JumpRequest:Connect(function()
    if infiniteJump then
        local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end
end)

-- ============================
-- GAMES (original mini-games that run on your client only)
-- ============================
local activeGame = nil
local startGame -- forward declaration

local function stopGame(silent)
    if activeGame then
        local cleanup = activeGame.cleanup
        activeGame = nil
        pcall(cleanup)
        if not silent then
            setStatus("Game stopped")
        end
    end
end

-- BLOCK STACK: click or press Space to drop the sliding block. Overlap keeps, rest is lost.
local function startBlockStack()
    local gui = Instance.new("ScreenGui")
    gui.Name = "MM2Hub_StackGame"
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 50
    gui.Parent = playerGui

    local W, H, BLOCK_H = 260, 300, 18

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, W + 190, 0, H + 60)
    frame.Position = UDim2.new(0.5, -(W + 190) / 2, 0.5, -(H + 60) / 2)
    frame.BackgroundColor3 = Color3.fromRGB(14, 14, 22)
    frame.BorderSizePixel = 0
    frame.Parent = gui
    corner(frame, 10)

    local stroke = Instance.new("UIStroke")
    stroke.Color = activeThemeDef.accent
    stroke.Thickness = 2
    stroke.Parent = frame

    local header = Instance.new("TextLabel")
    header.Size = UDim2.new(1, -16, 0, 22)
    header.Position = UDim2.new(0, 8, 0, 6)
    header.BackgroundTransparency = 1
    header.Text = "BLOCK STACK  |  click / Space to drop"
    header.TextColor3 = COLOR_TEXT
    header.TextScaled = true
    header.Font = activeFont
    header.Parent = frame

    local scoreLbl = Instance.new("TextLabel")
    scoreLbl.Size = UDim2.new(1, -16, 0, 18)
    scoreLbl.Position = UDim2.new(0, 8, 0, 30)
    scoreLbl.BackgroundTransparency = 1
    scoreLbl.Text = "Score: 0"
    scoreLbl.TextColor3 = COLOR_GOLD
    scoreLbl.TextScaled = true
    scoreLbl.Font = activeFont
    scoreLbl.Parent = frame

    local board = Instance.new("Frame")
    board.Size = UDim2.new(0, W, 0, H)
    board.Position = UDim2.new(0, 10, 0, 56)
    board.BackgroundColor3 = Color3.fromRGB(20, 20, 32)
    board.BorderSizePixel = 0
    board.ClipsDescendants = true
    board.Parent = frame
    corner(board, 6)

    local holder = Instance.new("Frame")
    holder.Size = UDim2.new(1, 0, 0, H)
    holder.BackgroundTransparency = 1
    holder.Parent = board

    local function rowY(row)
        return H - (row + 1) * BLOCK_H
    end

    local function blockColor(row)
        return Color3.fromHSV((row * 0.07) % 1, 0.7, 0.95)
    end

    local blocks = {} -- { left = px, width = px }
    local function addBlockFrame(row, left, width)
        local f = Instance.new("Frame")
        f.Size = UDim2.new(0, width, 0, BLOCK_H - 2)
        f.Position = UDim2.new(0, left, 0, rowY(row))
        f.BackgroundColor3 = blockColor(row)
        f.BorderSizePixel = 0
        f.Parent = holder
        corner(f, 3)
        return f
    end

    blocks[1] = { left = (W - 200) / 2, width = 200 }
    addBlockFrame(0, blocks[1].left, 200)

    local moving = addBlockFrame(1, 0, 200)
    local mx, mdir, mw = 0, 1, 200
    local speed = 140
    local over = false

    local function updateShift()
        local top = #blocks
        holder.Position = UDim2.new(0, 0, 0, math.max(0, (top + 1) * BLOCK_H - H))
    end

    -- LEADERBOARD: top scores saved on this device, with player icons
    local boardPanel = Instance.new("Frame")
    boardPanel.Size = UDim2.new(0, 160, 0, H)
    boardPanel.Position = UDim2.new(0, W + 30, 0, 56)
    boardPanel.BackgroundColor3 = Color3.fromRGB(20, 20, 32)
    boardPanel.BorderSizePixel = 0
    boardPanel.Parent = frame
    corner(boardPanel, 6)

    local boardTitle = Instance.new("TextLabel")
    boardTitle.Size = UDim2.new(1, -12, 0, 22)
    boardTitle.Position = UDim2.new(0, 6, 0, 4)
    boardTitle.BackgroundTransparency = 1
    boardTitle.Text = "🏆 LEADERBOARD"
    boardTitle.TextColor3 = COLOR_GOLD
    boardTitle.TextScaled = true
    boardTitle.Font = activeFont
    boardTitle.Parent = boardPanel

    local boardRows = Instance.new("Frame")
    boardRows.Size = UDim2.new(1, 0, 1, -30)
    boardRows.Position = UDim2.new(0, 0, 0, 30)
    boardRows.BackgroundTransparency = 1
    boardRows.Parent = boardPanel

    local function refreshBoard()
        for _, child in ipairs(boardRows:GetChildren()) do
            child:Destroy()
        end
        local list = settings.stackBoard or {}
        if #list == 0 then
            local none = Instance.new("TextLabel")
            none.Size = UDim2.new(1, -12, 0, 20)
            none.Position = UDim2.new(0, 6, 0, 10)
            none.BackgroundTransparency = 1
            none.Text = "No scores yet"
            none.TextColor3 = COLOR_DIM
            none.TextScaled = true
            none.Font = activeFont
            none.Parent = boardRows
        end
        for i = 1, math.min(5, #list) do
            local e = list[i]
            local row = Instance.new("Frame")
            row.Size = UDim2.new(1, -10, 0, 40)
            row.Position = UDim2.new(0, 5, 0, (i - 1) * 44)
            row.BackgroundColor3 = Color3.fromRGB(28, 28, 42)
            row.BorderSizePixel = 0
            row.Parent = boardRows
            corner(row, 6)

            local icon = Instance.new("ImageLabel")
            icon.Size = UDim2.new(0, 30, 0, 30)
            icon.Position = UDim2.new(0, 5, 0.5, -15)
            icon.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
            icon.BorderSizePixel = 0
            icon.Image = "rbxthumb://type=AvatarHeadShot&id=" .. tostring(e.userId or 0) .. "&w=100&h=100"
            icon.Parent = row
            corner(icon, 15)

            local nameLbl = Instance.new("TextLabel")
            nameLbl.Size = UDim2.new(1, -44, 0, 20)
            nameLbl.Position = UDim2.new(0, 40, 0, 3)
            nameLbl.BackgroundTransparency = 1
            nameLbl.Text = tostring(e.name or "?")
            nameLbl.TextColor3 = COLOR_TEXT
            nameLbl.TextScaled = true
            nameLbl.TextXAlignment = Enum.TextXAlignment.Left
            nameLbl.Font = activeFont
            nameLbl.Parent = row

            local scoreTxt = Instance.new("TextLabel")
            scoreTxt.Size = UDim2.new(1, -44, 0, 14)
            scoreTxt.Position = UDim2.new(0, 40, 0, 23)
            scoreTxt.BackgroundTransparency = 1
            scoreTxt.Text = "#" .. i .. "  •  " .. tostring(e.score or 0)
            scoreTxt.TextColor3 = COLOR_GOLD
            scoreTxt.TextScaled = true
            scoreTxt.TextXAlignment = Enum.TextXAlignment.Left
            scoreTxt.Font = activeFont
            scoreTxt.Parent = row
        end
    end

    local function recordScore(score)
        if score <= 0 then return end
        local list = settings.stackBoard or {}
        table.insert(list, { name = player.DisplayName, userId = player.UserId, score = score })
        table.sort(list, function(a, b)
            return (a.score or 0) > (b.score or 0)
        end)
        while #list > 10 do
            table.remove(list)
        end
        settings.stackBoard = list
        saveSettings()
        refreshBoard()
    end

    refreshBoard()

    local function placeMoving()
        local top = blocks[#blocks]
        local row = #blocks
        local left = math.max(top.left, mx)
        local right = math.min(top.left + top.width, mx + mw)
        if right - left < 3 then
            over = true
            moving.Visible = false
            scoreLbl.Text = "Game over! Score: " .. (#blocks - 1) .. "  (click to restart)"
            recordScore(#blocks - 1)
            return
        end
        blocks[#blocks + 1] = { left = left, width = right - left }
        addBlockFrame(row, left, right - left)
        mw = right - left
        mx = 0
        mdir = 1
        speed = 140 + #blocks * 6
        moving.Size = UDim2.new(0, mw, 0, BLOCK_H - 2)
        moving.BackgroundColor3 = blockColor(#blocks)
        moving.Position = UDim2.new(0, mx, 0, rowY(#blocks))
        scoreLbl.Text = "Score: " .. (#blocks - 1)
        updateShift()
    end

    moving.Size = UDim2.new(0, mw, 0, BLOCK_H - 2)
    moving.BackgroundColor3 = blockColor(1)
    moving.Position = UDim2.new(0, 0, 0, rowY(1))

    local heartConn = RunService.Heartbeat:Connect(function(dt)
        if over then return end
        mx = mx + mdir * speed * dt
        if mx < 0 then
            mx = 0
            mdir = 1
        elseif mx + mw > W then
            mx = W - mw
            mdir = -1
        end
        moving.Position = UDim2.new(0, mx, 0, rowY(#blocks))
        updateShift()
    end)

    local inputConn = UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.Space then
            if over then
                task.defer(function()
                    startGame("STACK")
                end)
            else
                placeMoving()
            end
        end
    end)

    setStatus("🧱 Block Stack: click or Space to drop blocks", COLOR_GOLD)

    return function()
        heartConn:Disconnect()
        inputConn:Disconnect()
        gui:Destroy()
    end
end

-- OBBY RUN: 25 platforms climbing in a zigzag high above the map. Falling sends you to your checkpoint.
local function startObbyGame()
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then
        setStatus("No character to play with.", COLOR_RED)
        return nil
    end
    local returnCF = root.CFrame

    local folder = Instance.new("Folder")
    folder.Name = "MM2Hub_Obby"
    folder.Parent = workspace

    local BASE = Vector3.new(0, 600, 0)
    local N = 25
    local platforms = {}
    for i = 1, N do
        local p = Instance.new("Part")
        p.Anchored = true
        p.Size = Vector3.new(10, 1, 10)
        p.Position = BASE + Vector3.new(math.sin(i * 0.5) * 8, i * 1.5, -i * 13)
        p.Color = (i == N) and COLOR_GOLD or Color3.fromHSV((i * 0.04) % 1, 0.6, 0.9)
        p.Material = Enum.Material.SmoothPlastic
        p.Parent = folder
        platforms[i] = p
    end

    root.CFrame = CFrame.new(platforms[1].Position + Vector3.new(0, 4, 0))

    local startT = os.clock()
    local checkpoint = 1
    local finished = false
    local lastStatus = 0

    local conn = RunService.Heartbeat:Connect(function()
        local c = player.Character
        local r = c and c:FindFirstChild("HumanoidRootPart")
        if not r or finished then return end

        local pos = r.Position
        for i = checkpoint + 1, math.min(N, checkpoint + 3) do
            local pp = platforms[i].Position
            local flat = Vector3.new(pos.X - pp.X, 0, pos.Z - pp.Z).Magnitude
            if flat < 8 and pos.Y > pp.Y - 4 then
                checkpoint = i
            end
        end

        if pos.Y < BASE.Y - 40 then
            r.CFrame = CFrame.new(platforms[checkpoint].Position + Vector3.new(0, 4, 0))
            setStatus("You fell! Back to checkpoint " .. checkpoint .. "/" .. N, COLOR_RED)
            return
        end

        if checkpoint >= N then
            finished = true
            setStatus(string.format("🏁 Obby finished in %.1fs! Pick OBBY to play again.", os.clock() - startT), COLOR_GOLD)
            return
        end

        if os.clock() - lastStatus > 0.5 then
            lastStatus = os.clock()
            setStatus(string.format("🏃 Obby: checkpoint %d/%d | %.1fs", checkpoint, N, os.clock() - startT), COLOR_TEXT)
        end
    end)

    return function()
        conn:Disconnect()
        folder:Destroy()
        local c = player.Character
        local rr = c and c:FindFirstChild("HumanoidRootPart")
        if rr then
            rr.CFrame = returnCF
        end
    end
end

-- LOOT RUSH: 30 glowing orbs in a 60-second arena, walk over them to grab them.
local function startLootGame()
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then
        setStatus("No character to play with.", COLOR_RED)
        return nil
    end
    local returnCF = root.CFrame

    local ARENA = Vector3.new(500, 800, 0)
    local folder = Instance.new("Folder")
    folder.Name = "MM2Hub_Loot"
    folder.Parent = workspace

    local floor = Instance.new("Part")
    floor.Anchored = true
    floor.Size = Vector3.new(200, 2, 200)
    floor.Position = ARENA
    floor.Color = Color3.fromRGB(30, 30, 40)
    floor.Material = Enum.Material.Slate
    floor.Parent = folder

    local orbs = {}
    for _ = 1, 30 do
        local orb = Instance.new("Part")
        orb.Shape = Enum.PartType.Ball
        orb.Size = Vector3.new(3, 3, 3)
        orb.Anchored = true
        orb.CanCollide = false
        orb.Material = Enum.Material.Neon
        orb.Color = Color3.fromHSV(math.random(), 0.8, 1)
        orb.Position = ARENA + Vector3.new(math.random(-90, 90), 3, math.random(-90, 90))
        orb.Parent = folder
        table.insert(orbs, orb)
    end

    root.CFrame = CFrame.new(ARENA + Vector3.new(0, 5, 0))

    local score, timeLeft, done = 0, 60, false
    local lastStatus = 0

    local conn = RunService.Heartbeat:Connect(function(dt)
        if done then return end
        local c = player.Character
        local r = c and c:FindFirstChild("HumanoidRootPart")
        if not r then return end

        timeLeft = timeLeft - dt
        local pos = r.Position
        for i = #orbs, 1, -1 do
            local o = orbs[i]
            if (o.Position - pos).Magnitude < 6 then
                o:Destroy()
                table.remove(orbs, i)
                score = score + 1
            end
        end

        if timeLeft <= 0 or #orbs == 0 then
            done = true
            setStatus("💰 Loot Rush over! Collected " .. score .. " orbs. Pick LOOT to play again.", COLOR_GOLD)
            return
        end

        if os.clock() - lastStatus > 0.25 then
            lastStatus = os.clock()
            setStatus(string.format("💰 Loot: %d collected | %ds left", score, math.ceil(timeLeft)), COLOR_GOLD)
        end
    end)

    return function()
        conn:Disconnect()
        folder:Destroy()
        local c = player.Character
        local rr = c and c:FindFirstChild("HumanoidRootPart")
        if rr then
            rr.CFrame = returnCF
        end
    end
end

do -- DODGE: red blocks fall from the sky, survive as long as you can
local function startDodgeGame()
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then
        setStatus("No character to play with.", COLOR_RED)
        return nil
    end
    local returnCF = root.CFrame

    local ARENA = Vector3.new(-500, 800, 0)
    local folder = Instance.new("Folder")
    folder.Name = "MM2Hub_Dodge"
    folder.Parent = workspace

    local floor = Instance.new("Part")
    floor.Anchored = true
    floor.Size = Vector3.new(120, 2, 120)
    floor.Position = ARENA
    floor.Color = Color3.fromRGB(30, 30, 40)
    floor.Material = Enum.Material.Slate
    floor.Parent = folder

    root.CFrame = CFrame.new(ARENA + Vector3.new(0, 5, 0))

    local falling = {}
    local alive = true
    local startT = os.clock()
    local spawnAcc = 0
    local lastStatus = 0

    local conn = RunService.Heartbeat:Connect(function(dt)
        if not alive then return end
        local c = player.Character
        local r = c and c:FindFirstChild("HumanoidRootPart")
        if not r then return end

        local elapsed = os.clock() - startT
        local interval = math.max(0.12, 0.4 - elapsed * 0.004) -- gets faster over time
        spawnAcc = spawnAcc + dt
        if spawnAcc >= interval then
            spawnAcc = 0
            local p = Instance.new("Part")
            p.Anchored = true
            p.CanCollide = false
            p.Size = Vector3.new(4, 4, 4)
            p.Material = Enum.Material.Neon
            p.Color = Color3.fromRGB(255, 60, 60)
            p.Position = ARENA + Vector3.new(math.random(-55, 55), 80, math.random(-55, 55))
            p.Parent = folder
            table.insert(falling, { part = p, speed = 40 + math.random() * 30 + elapsed * 0.5 })
        end

        local pos = r.Position
        for i = #falling, 1, -1 do
            local f = falling[i]
            f.part.Position = f.part.Position - Vector3.new(0, f.speed * dt, 0)
            if (f.part.Position - pos).Magnitude < 4 then
                alive = false
                setStatus(string.format("💥 Hit! Survived %.1fs. Pick DODGE to try again.", os.clock() - startT), COLOR_RED)
                return
            end
            if f.part.Position.Y < ARENA.Y - 5 then
                f.part:Destroy()
                table.remove(falling, i)
            end
        end

        if os.clock() - lastStatus > 0.25 then
            lastStatus = os.clock()
            setStatus(string.format("☄ Dodge: %.1fs survived", os.clock() - startT), COLOR_TEXT)
        end
    end)

    return function()
        conn:Disconnect()
        folder:Destroy()
        local c = player.Character
        local rr = c and c:FindFirstChild("HumanoidRootPart")
        if rr then
            rr.CFrame = returnCF
        end
    end
end

-- REACTION TEST: click the green pad as soon as it turns green, 5 rounds
local function startReactionGame()
    local gui = Instance.new("ScreenGui")
    gui.Name = "MM2Hub_ReactionGame"
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 50
    gui.Parent = playerGui

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 300, 0, 260)
    frame.Position = UDim2.new(0.5, -150, 0.5, -130)
    frame.BackgroundColor3 = Color3.fromRGB(14, 14, 22)
    frame.BorderSizePixel = 0
    frame.Parent = gui
    corner(frame, 10)

    local stroke = Instance.new("UIStroke")
    stroke.Color = activeThemeDef.accent
    stroke.Thickness = 2
    stroke.Parent = frame

    local head = Instance.new("TextLabel")
    head.Size = UDim2.new(1, -16, 0, 22)
    head.Position = UDim2.new(0, 8, 0, 8)
    head.BackgroundTransparency = 1
    head.Text = "REACTION TEST  |  5 rounds"
    head.TextColor3 = COLOR_TEXT
    head.TextScaled = true
    head.Font = activeFont
    head.Parent = frame

    local pad = Instance.new("TextButton")
    pad.Size = UDim2.new(1, -24, 0, 150)
    pad.Position = UDim2.new(0, 12, 0, 40)
    pad.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
    pad.BorderSizePixel = 0
    pad.AutoButtonColor = false
    pad.Text = "WAIT..."
    pad.TextColor3 = Color3.new(1, 1, 1)
    pad.TextScaled = true
    pad.Font = activeFont
    pad.Parent = frame
    corner(pad, 10)

    local info = Instance.new("TextLabel")
    info.Size = UDim2.new(1, -24, 0, 40)
    info.Position = UDim2.new(0, 12, 0, 200)
    info.BackgroundTransparency = 1
    info.Text = "Click the GREEN pad as soon as it turns green."
    info.TextColor3 = COLOR_DIM
    info.TextScaled = true
    info.TextWrapped = true
    info.Font = activeFont
    info.Parent = frame

    local round, times, ready, startT, gen = 0, {}, false, 0, 0

    local function setPad(text, color)
        pad.Text = text
        pad.BackgroundColor3 = color
    end

    local nextRound
    nextRound = function()
        gen = gen + 1
        local myGen = gen
        ready = false
        if round >= 5 then
            local sum = 0
            for _, t in ipairs(times) do sum = sum + t end
            local avg = math.floor(sum / math.max(1, #times))
            setPad("DONE! Click to play again", COLOR_GOLD)
            info.Text = string.format("Average reaction: %dms", avg)
            setStatus(string.format("⚡ Reaction average: %dms", avg), COLOR_GOLD)
            return
        end
        setPad("WAIT...", Color3.fromRGB(180, 40, 40))
        task.delay(math.random(15, 40) / 10, function()
            if myGen ~= gen then return end
            ready = true
            startT = os.clock()
            setPad("CLICK!", Color3.fromRGB(40, 200, 80))
        end)
    end

    pad.MouseButton1Click:Connect(function()
        if round >= 5 then
            round = 0
            times = {}
            info.Text = "Click the GREEN pad as soon as it turns green."
            nextRound()
            return
        end
        if not ready then
            gen = gen + 1
            local myGen = gen
            setPad("TOO EARLY!", COLOR_RED)
            info.Text = "Wait for green. Retrying..."
            task.delay(1, function()
                if myGen == gen then nextRound() end
            end)
            return
        end
        ready = false
        round = round + 1
        local ms = (os.clock() - startT) * 1000
        table.insert(times, ms)
        info.Text = string.format("Round %d: %dms", round, ms)
        gen = gen + 1
        local myGen = gen
        setPad("NICE!", Color3.fromRGB(60, 120, 220))
        task.delay(0.8, function()
            if myGen == gen then nextRound() end
        end)
    end)

    nextRound()

    return function()
        gen = gen + 1
        gui:Destroy()
    end
end

startGame = function(key)
    stopGame(true)
    local starters = {
        STACK = startBlockStack,
        OBBY = startObbyGame,
        LOOT = startLootGame,
        DODGE = startDodgeGame,
        REACTION = startReactionGame,
    }
    local ok, result = pcall(starters[key])
    if ok and result then
        activeGame = { key = key, cleanup = result }
    elseif not ok then
        setStatus("Game failed to start: " .. tostring(result), COLOR_RED)
    end
end

end -- mini-game definitions

local function toggleGame(key)
    if activeGame and activeGame.key == key then
        stopGame()
    else
        startGame(key)
    end
end

-- GAMES TAB
do -- game buttons (scoped to save local slots)
local stackBtn = makeButton(gamesPage, "🧱 BLOCK STACK", 0, COLOR_GOLD)
local obbyBtn = makeButton(gamesPage, "🏃 OBBY RUN", 50, Color3.fromRGB(80, 220, 120))
local lootBtn = makeButton(gamesPage, "💰 LOOT RUSH", 100, Color3.fromRGB(180, 80, 255))
local dodgeBtn = makeButton(gamesPage, "☄ DODGE", 150, COLOR_RED)
local reactionBtn = makeButton(gamesPage, "⚡ REACTION TEST", 200, COLOR_BLUE)
local stopGameBtn = makeButton(gamesPage, "■ STOP GAME", 250, COLOR_DIM)

stackBtn.MouseButton1Click:Connect(function() toggleGame("STACK") end)
obbyBtn.MouseButton1Click:Connect(function() toggleGame("OBBY") end)
lootBtn.MouseButton1Click:Connect(function() toggleGame("LOOT") end)
dodgeBtn.MouseButton1Click:Connect(function() toggleGame("DODGE") end)
reactionBtn.MouseButton1Click:Connect(function() toggleGame("REACTION") end)
stopGameBtn.MouseButton1Click:Connect(function() stopGame() end)
end

local gamesInfo = Instance.new("TextLabel")
gamesInfo.Size = UDim2.new(1, 0, 0, 80)
gamesInfo.Position = UDim2.new(0, 0, 0, 305)
gamesInfo.BackgroundTransparency = 1
gamesInfo.Text = "Original mini-games in the style of Block Blast, Stumble Guys and Steal a Brainrot. They run only on your client, so nobody else sees them. Your character is teleported during Obby and Loot Rush, and returns when you stop."
gamesInfo.TextColor3 = COLOR_DIM
gamesInfo.TextScaled = true
gamesInfo.TextWrapped = true
gamesInfo.Font = activeFont
gamesInfo.ZIndex = 3
gamesInfo.Parent = gamesPage

player.CharacterAdded:Connect(function()
    stopGame(true)
end)

-- ============================
-- SETTINGS TAB
-- ============================
local bgLabel = Instance.new("TextLabel")
bgLabel.Size = UDim2.new(1, 0, 0, 18)
bgLabel.Position = UDim2.new(0, 0, 0, 0)
bgLabel.BackgroundTransparency = 1
bgLabel.Text = "BACKGROUND IMAGE ID"
bgLabel.TextColor3 = COLOR_DIM
bgLabel.TextScaled = true
bgLabel.Font = activeFont
bgLabel.TextXAlignment = Enum.TextXAlignment.Left
bgLabel.ZIndex = 3
bgLabel.Parent = settingsPage

local bgBox = Instance.new("TextBox")
bgBox.Size = UDim2.new(1, 0, 0, 32)
bgBox.Position = UDim2.new(0, 0, 0, 22)
bgBox.BackgroundColor3 = Color3.fromRGB(18, 18, 26)
bgBox.BorderSizePixel = 0
bgBox.Text = settings.bgId or ""
bgBox.PlaceholderText = "Image asset ID (numbers only)"
bgBox.TextColor3 = COLOR_TEXT
bgBox.PlaceholderColor3 = Color3.fromRGB(90, 90, 120)
bgBox.TextScaled = true
bgBox.ClearTextOnFocus = false
bgBox.Font = activeFont
bgBox.ZIndex = 3
bgBox.Parent = settingsPage
corner(bgBox, 6)

local function applyBackground()
    local id = settings.bgId or ""
    bgImage.Image = (id ~= "") and ("rbxassetid://" .. id) or ""
end

local applyBgBtn = makeButton(settingsPage, "🖼 APPLY BACKGROUND", 62, COLOR_GOLD)
local resetBgBtn = makeButton(settingsPage, "↺ RESET BACKGROUND", 112, COLOR_DIM)

applyBgBtn.MouseButton1Click:Connect(function()
    local ContentProvider = game:GetService("ContentProvider")
    -- takes the first number in what's typed, so a full library URL or "rbxassetid://123" also works
    local digits = bgBox.Text:match("(%d+)")
    if not digits then
        setStatus("Type an image ID (the number from the Roblox asset URL)", COLOR_RED)
        return
    end
    settings.bgId = digits
    bgBox.Text = digits
    applyBackground()
    saveSettings()
    setStatus("Loading background " .. digits .. "...", COLOR_GOLD)
    task.spawn(function()
        pcall(function()
            ContentProvider:PreloadAsync({ bgImage })
        end)
        if bgImage.IsLoaded then
            setStatus("Background " .. digits .. " loaded", COLOR_GREEN)
        else
            setStatus("Background " .. digits .. " didn't load. It must be an Image asset ID.", COLOR_RED)
        end
    end)
end)

resetBgBtn.MouseButton1Click:Connect(function()
    settings.bgId = ""
    bgBox.Text = ""
    applyBackground()
    saveSettings()
    setStatus("Background reset")
end)

local themeBtn = makeButton(settingsPage, "🎨 THEME", 162, Color3.fromRGB(255, 120, 0))
local fontBtn = makeButton(settingsPage, "🔤 FONT", 212, Color3.fromRGB(180, 80, 255))

local function cycleValue(list, current)
    for i, v in ipairs(list) do
        if v == current then
            return list[(i % #list) + 1]
        end
    end
    return list[1]
end

local function updateChoiceLabels()
    local key = currentThemeKey()
    local themeText = settings.themeChoice == "AUTO" and ("AUTO (" .. key .. ")") or settings.themeChoice
    themeBtn.Text = "🎨 THEME: " .. themeText
    fontBtn.Text = "🔤 FONT: " .. settings.fontChoice
end

themeBtn.MouseButton1Click:Connect(function()
    settings.themeChoice = cycleValue(THEME_ORDER, settings.themeChoice)
    saveSettings()
    applyAll()
end)

fontBtn.MouseButton1Click:Connect(function()
    settings.fontChoice = cycleValue(FONT_ORDER, settings.fontChoice)
    saveSettings()
    applyAll()
end)

local settingsInfo = Instance.new("TextLabel")
settingsInfo.Size = UDim2.new(1, 0, 0, 40)
settingsInfo.Position = UDim2.new(0, 0, 0, 262)
settingsInfo.BackgroundTransparency = 1
settingsInfo.Text = "AUTO theme follows the month: Oct Halloween, Nov Thanksgiving, Dec Christmas, Jan New Year."
settingsInfo.TextColor3 = COLOR_DIM
settingsInfo.TextScaled = true
settingsInfo.TextWrapped = true
settingsInfo.Font = activeFont
settingsInfo.ZIndex = 3
settingsInfo.Parent = settingsPage

-- ============================
-- APPLY THEME
-- ============================
applyAll = function()
    local key = currentThemeKey()
    local theme = THEMES[key] or THEMES.DEFAULT
    activeThemeDef = theme

    if settings.fontChoice == "AUTO" or not FONT_CHOICES[settings.fontChoice] then
        activeFont = theme.font
    else
        activeFont = FONT_CHOICES[settings.fontChoice]
    end

    rgbCycle = theme.cycle == true
    rgbColors = theme.border
    mainFrame.BackgroundColor3 = theme.bg
    accentDot.BackgroundColor3 = theme.accent

    for _, d in ipairs(mainFrame:GetDescendants()) do
        if d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox") then
            d.Font = activeFont
        end
    end
    for _, d in ipairs(scrollingFrame:GetDescendants()) do
        if d:IsA("TextLabel") then d.Font = activeFont end
    end

    setTab(activeTab)
    updateChoiceLabels()
    startDecor(theme.deco)
end

-- ============================
-- ANIMATION (border + accent dot)
-- ============================
local gradAngle = 0
RunService.Heartbeat:Connect(function(dt)
    gradAngle = (gradAngle + dt * 60) % 360
    local t = tick()
    rgbGrad.Rotation = gradAngle

    if rgbCycle then
        rgbGrad.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromHSV((t * 0.15) % 1, 1, 1)),
            ColorSequenceKeypoint.new(0.5, Color3.fromHSV((t * 0.15 + 0.33) % 1, 1, 1)),
            ColorSequenceKeypoint.new(1, Color3.fromHSV((t * 0.15 + 0.66) % 1, 1, 1)),
        })
    else
        rgbGrad.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, rgbColors[1]),
            ColorSequenceKeypoint.new(0.5, rgbColors[2]),
            ColorSequenceKeypoint.new(1, rgbColors[3]),
        })
    end

    local pulse = math.sin(t * 4) * 0.5 + 0.5
    accentDot.Size = UDim2.new(0, 5 + pulse * 2, 0, 5 + pulse * 2)
    accentDot.Position = UDim2.new(0, 16 - pulse, 0.5, -3 - pulse)
end)

-- ============================
-- START
-- ============================
applyBackground()
applyAll()
setTab("ESP")

print("MM2 Helper v2.9 Loaded - tween coins, reach, live Show Both, games, free-look invis")
