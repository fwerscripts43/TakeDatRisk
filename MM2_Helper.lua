-- MM2 Helper v3.8 (tabbed, seasonal themes, games)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local playerGui = player:WaitForChild("PlayerGui")

-- RUN GENERATION: the updater bumps this on every reload. Loops and connections
-- from an older copy see the number changed and stop by themselves.
local HUB_GEN = (getgenv().MM2HubGen or 0) + 1
getgenv().MM2HubGen = HUB_GEN
getgenv().MM2HubBind = function(signal, fn)
    local c
    c = signal:Connect(function(...)
        if HUB_GEN ~= getgenv().MM2HubGen then
            if c then c:Disconnect() end
            return
        end
        return fn(...)
    end)
    return c
end

-- BUTTON GUARD: if a button's handler errors, the button shuts down and says so when pressed
getgenv().MM2HubClick = function(obj, evName, fn)
    local broken = false
    return obj[evName]:Connect(function(...)
        if broken then
            if obj:IsA("TextButton") then
                obj.Text = "FUNCTION NOT WORKING, TRY REFRESHING"
                task.delay(2.5, function()
                    if obj.Parent and broken then obj.Text = "BROKEN" end
                end)
            end
            return
        end
        local ok, err = pcall(fn, ...)
        if not ok then
            broken = true
            warn("MM2 Hub button error: " .. tostring(err))
            if obj:IsA("TextButton") then obj.Text = "BROKEN" end
        end
    end)
end

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

-- LOADING SCREEN: blur + loading bar (bottom-right) + caption, removed once the window is ready
local loadingFinish
if getgenv().MM2HubBoot then
    loadingFinish = getgenv().MM2HubBoot.finish
else
do
    local blur = Instance.new("BlurEffect")
    blur.Name = "MM2Hub_Blur"
    blur.Size = 0
    blur.Parent = game:GetService("Lighting")
    TweenService:Create(blur, TweenInfo.new(0.4), { Size = 18 }):Play()

    local lg = Instance.new("ScreenGui")
    lg.Name = "MM2Hub_Loading"
    lg.ResetOnSpawn = false
    lg.DisplayOrder = 100
    lg.IgnoreGuiInset = true
    lg.Parent = playerGui

    local barBack = Instance.new("Frame")
    barBack.Size = UDim2.new(0, 220, 0, 10)
    barBack.AnchorPoint = Vector2.new(1, 1)
    barBack.Position = UDim2.new(1, -20, 1, -60)
    barBack.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    barBack.BorderSizePixel = 0
    barBack.Parent = lg
    corner(barBack, 5)

    local barFill = Instance.new("Frame")
    barFill.Size = UDim2.new(0, 0, 1, 0)
    barFill.BackgroundColor3 = Color3.fromRGB(255, 60, 100)
    barFill.BorderSizePixel = 0
    barFill.Parent = barBack
    corner(barFill, 5)

    local caption = Instance.new("TextLabel")
    caption.Size = UDim2.new(0, 220, 0, 22)
    caption.AnchorPoint = Vector2.new(1, 0)
    caption.Position = UDim2.new(1, -20, 1, -44)
    caption.BackgroundTransparency = 1
    caption.Text = "its cool, zurq"
    caption.TextColor3 = COLOR_TEXT
    caption.TextScaled = true
    caption.Font = Enum.Font.GothamBold
    caption.Parent = lg

    local LOAD_TIME = 2.5
    local progress, startT = 0, os.clock()
    local conn
    conn = getgenv().MM2HubBind(RunService.Heartbeat, function()
        progress = math.min(1, (os.clock() - startT) / LOAD_TIME)
        barFill.Size = UDim2.new(progress, 0, 1, 0)
    end)

    -- called at the end of the script: waits for the bar, then unblurs and shows the window
    loadingFinish = function(showMain)
        task.spawn(function()
            while progress < 1 do
                task.wait(0.05)
            end
            conn:Disconnect()
            TweenService:Create(caption, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
            TweenService:Create(barBack, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
            TweenService:Create(barFill, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
            TweenService:Create(blur, TweenInfo.new(0.5), { Size = 0 }):Play()
            task.wait(0.5)
            lg:Destroy()
            blur:Destroy()
            showMain()
        end)
    end
end
end

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
rgbBorder.Visible = false -- shown when the loading screen finishes

-- window scale: changed by the corner grips, animated by ANIMATED UI
local uiScale = Instance.new("UIScale")
uiScale.Scale = math.clamp(tonumber(settings.uiScale) or 1, 0.6, 1.6)
uiScale.Parent = rgbBorder

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
versionBadge.Text = "v3.8"
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
makePage("SETTINGS", true)

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
    getgenv().MM2HubClick(tb, "MouseButton1Click", function()
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

-- REFRESH: asks the updater whether GitHub has a newer version, reloads only if it does
do
    local refreshBtn = Instance.new("TextButton")
    refreshBtn.Size = UDim2.new(0, 58, 0, 20)
    refreshBtn.Position = UDim2.new(1, -116, 0.5, -10)
    refreshBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 48)
    refreshBtn.Text = "REFRESH"
    refreshBtn.TextColor3 = COLOR_DIM
    refreshBtn.TextScaled = true
    refreshBtn.Font = activeFont
    refreshBtn.AutoButtonColor = true
    refreshBtn.ZIndex = 4
    refreshBtn.Parent = headerBar
    corner(refreshBtn, 5)
    getgenv().MM2HubClick(refreshBtn, "MouseButton1Click", function()
        local refresh = getgenv().MM2HubRefresh
        if not refresh then
            setStatus("Refresh needs loader.lua", COLOR_RED)
            return
        end
        setStatus("Checking GitHub...")
        local ok, msg = refresh()
        if not ok then
            setStatus(msg, COLOR_RED)
        elseif msg ~= "Updated" then
            setStatus(msg, COLOR_DIM)
        end
    end)
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
        if settings.animatedUI then
            TweenService:Create(stroke, TweenInfo.new(0.06), { Thickness = 3.5 }):Play()
        end
    end)
    getgenv().MM2HubClick(btn, "MouseButton1Up", function()
        TweenService:Create(container, TweenInfo.new(0.12), { BackgroundColor3 = Color3.fromRGB(24, 24, 36) }):Play()
        TweenService:Create(stroke, TweenInfo.new(0.15), { Thickness = 1.5 }):Play()
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
        while gen == decorGen and HUB_GEN == getgenv().MM2HubGen do
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

getgenv().MM2HubClick(findMurderBtn, "MouseButton1Click", function()
    clearOutlines()
    local murderer = findMurderer()
    if murderer then
        outlinePlayer(murderer, true, COLOR_RED)
        setStatus("🔪 " .. murderer.DisplayName .. " is the MURDERER", COLOR_RED)
    else
        setStatus("No murderer found.")
    end
end)

getgenv().MM2HubClick(findSheriffBtn, "MouseButton1Click", function()
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

getgenv().MM2HubClick(viewBothBtn, "MouseButton1Click", function()
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
        while viewBothOn and gen == viewBothGen and HUB_GEN == getgenv().MM2HubGen do
            task.wait(0.5)
            pcall(refreshViewBoth, false)
        end
    end)
end)

local seeAllOn = false
getgenv().MM2HubClick(seeAllBtn, "MouseButton1Click", function()
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
    while HUB_GEN == getgenv().MM2HubGen do
        task.wait(0.2)
        if tracersOn then
            pcall(refreshTracers)
        end
    end
end)

getgenv().MM2HubClick(tracersBtn, "MouseButton1Click", function()
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

local aimMode = settings.aimMode == "MURD" and "MURD" or "REGULAR" -- REGULAR or MURD (auto aim the knife holder)
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

    -- the gun's Shoot remote (as GunClient uses it): origin CFrame + target CFrame
    local shoot = gun:FindFirstChild("Shoot")
    if shoot and shoot:IsA("RemoteEvent") then
        local char = player.Character
        local hrpNow = char and char:FindFirstChild("HumanoidRootPart")
        local att = hrpNow and hrpNow:FindFirstChild("GunRaycastAttachment")
        pcall(function()
            shoot:FireServer(att and att.WorldCFrame or nil, CFrame.new(pos))
        end)
        return
    end

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

-- a shot is only allowed when the target is close enough, above you, and not behind a wall
local function clearShotAt(tChar, tPos)
    local myChar = player.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myRoot or not tChar then return false end
    local origin = camera.CFrame.Position
    local offset = tPos - origin
    if offset.Magnitude > (settings.aimRange or 90) then return false end
    if tPos.Y < myRoot.Position.Y - 6 then return false end -- underground / far below you
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { myChar, tChar }
    return workspace:Raycast(origin, offset, params) == nil
end

local function aimStep(dt)
    if not aimEnabled then return end
    if aimMode == "MURD" then
        target = findMurderer()
    end
    if not target then return end
    local tChar = target.Character
    local part = tChar and (tChar:FindFirstChild("Head") or tChar:FindFirstChild("HumanoidRootPart"))
    if not part then return end
    if isDead(target) then
        -- the target was shot: stop auto aim
        aimEnabled = false
        target = nil
        RunService:UnbindFromRenderStep(AIM_BIND)
        aimBound = false
        toggleAimBtn.Text = "◎ ENABLE AUTO AIM"
        setToggleVisual(aimStroke, false)
        setStatus("🎯 Target down, auto aim stopped", COLOR_GOLD)
        return
    end

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
            if clearShotAt(tChar, part.Position) then
                aimFire(aimPos)
            end
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

getgenv().MM2HubClick(toggleAimBtn, "MouseButton1Click", function()
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

    getgenv().MM2HubClick(btn, "MouseButton1Click", function()
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
getgenv().MM2HubBind(Players.PlayerAdded, updatePlayerList)
getgenv().MM2HubBind(Players.PlayerRemoving, updatePlayerList)
updatePlayerList()

-- AUTO SHOOT: a ring around the crosshair. When the murderer is inside the ring, in clear
-- line of sight, it fires at their predicted position (the ring turns green).
local autoShootOn = false
local shootLoopRunning = false

local function autoShootStep(canFire)
    local ringGui = playerGui:FindFirstChild("MM2Hub_ShootRing")
    local ring = ringGui and ringGui:FindFirstChild("Ring")
    local stroke = ring and ring:FindFirstChildOfClass("UIStroke")
    local center = camera.ViewportSize / 2
    if ring then
        ring.Position = UDim2.fromOffset(center.X, center.Y)
    end

    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root or not hasLocalGun() then
        if stroke then stroke.Color = COLOR_DIM end
        return
    end

    local murderer = findMurderer()
    local tChar = murderer and murderer.Character
    local tRoot = tChar and tChar:FindFirstChild("HumanoidRootPart")
    local head = tChar and tChar:FindFirstChild("Head")
    if not tRoot or not head or isDead(murderer) then
        if stroke then stroke.Color = COLOR_DIM end
        return
    end

    local screenPos = camera:WorldToViewportPoint(head.Position)
    local radius = settings.shootRing or 110
    local inside = screenPos.Z > 0 and (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude <= radius
    if stroke then
        stroke.Color = inside and COLOR_GREEN or COLOR_RED
    end
    if not inside or not clearShotAt(tChar, head.Position) then return end

    if canFire then
        local dist = (head.Position - camera.CFrame.Position).Magnitude
        local predicted = head.Position + tRoot.AssemblyLinearVelocity * (dist / BULLET_SPEED)
        aimFire(predicted)
        setStatus("🎯 Auto shooting " .. murderer.DisplayName, COLOR_BLUE)
    end
end

local function startAutoShootLoop()
    if shootLoopRunning then return end
    shootLoopRunning = true
    task.spawn(function()
        local shotTimer = 0
        while autoShootOn and HUB_GEN == getgenv().MM2HubGen do
            local dt = task.wait()
            shotTimer = shotTimer + dt
            local canFire = shotTimer >= 0.15
            if canFire then
                shotTimer = 0
            end
            local ok, err = pcall(autoShootStep, canFire)
            if not ok then
                warn("[MM2 AutoShoot] " .. tostring(err))
            end
        end
        shootLoopRunning = false
    end)
end

getgenv().MM2HubClick(autoShootBtn, "MouseButton1Click", function()
    if not autoShootOn then
        if not hasLocalGun() then
            setStatus("You need the Gun tool to use Auto Shoot.", COLOR_RED)
            return
        end
        autoShootOn = true
        autoShootBtn.Text = "🎯 STOP AUTO SHOOT"
        setToggleVisual(autoShootStroke, true)

        -- the crosshair ring (IgnoreGuiInset so it lines up with the screen center)
        local g = Instance.new("ScreenGui")
        g.Name = "MM2Hub_ShootRing"
        g.ResetOnSpawn = false
        g.IgnoreGuiInset = true
        g.DisplayOrder = 60
        g.Parent = playerGui
        local radius = settings.shootRing or 110
        local ring = Instance.new("Frame")
        ring.Name = "Ring"
        ring.AnchorPoint = Vector2.new(0.5, 0.5)
        ring.Size = UDim2.fromOffset(radius * 2, radius * 2)
        ring.BackgroundTransparency = 1
        ring.Parent = g
        local rc = Instance.new("UICorner")
        rc.CornerRadius = UDim.new(1, 0)
        rc.Parent = ring
        local rs = Instance.new("UIStroke")
        rs.Color = COLOR_RED
        rs.Thickness = 2
        rs.Parent = ring

        setStatus("AUTO SHOOT ON: get the murderer inside the ring", COLOR_BLUE)
        startAutoShootLoop()
    else
        autoShootOn = false
        local old = playerGui:FindFirstChild("MM2Hub_ShootRing")
        if old then
            old:Destroy()
        end
        autoShootBtn.Text = "🎯 AUTO SHOOT"
        setToggleVisual(autoShootStroke, false)
        setStatus("AUTO SHOOT OFF")
    end
end)

-- AUTO MURD WIN
local murdWinOn = false

local function murdWinLoop()
    while murdWinOn and HUB_GEN == getgenv().MM2HubGen do
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

getgenv().MM2HubClick(autoMurdWinBtn, "MouseButton1Click", function()
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
    while autoGunOn and HUB_GEN == getgenv().MM2HubGen do
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
                    local returnCF = hrp.CFrame
                    hrp.CFrame = CFrame.new(spot + Vector3.new(0, 4, 0))
                    gunSent = true
                    -- give the touch a couple of frames to register, then snap back
                    task.spawn(function()
                        RunService.Heartbeat:Wait()
                        RunService.Heartbeat:Wait()
                        local c = player.Character
                        local h = c and c:FindFirstChild("HumanoidRootPart")
                        if h then
                            h.CFrame = returnCF
                        end
                    end)
                    setStatus(gunTool and "Sheriff died, grabbing the gun!" or "Sheriff died here, going to last spot...", Color3.fromRGB(100, 255, 100))
                else
                    setStatus("No dropped gun or sheriff spot found yet", COLOR_RED)
                end
            end
        end
    end
end

getgenv().MM2HubClick(autoGunBtn, "MouseButton1Click", function()
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
        while reachOn and HUB_GEN == getgenv().MM2HubGen do
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

getgenv().MM2HubClick(reachBtn, "MouseButton1Click", function()
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

-- RESIZE: drag a corner grip to scale the whole window; ANIMATED UI breathes and spins the border
do
    if settings.windowH then
        rgbBorder.Size = UDim2.new(0, 316, 0, settings.windowH)
        mainFrame.Size = UDim2.new(0, 308, 0, settings.windowH - 8)
    end

    local resizing = false
    local center0, d0, s0 = nil, 1, 1

    local function makeGrip(ax, ay)
        local g = Instance.new("TextButton")
        g.Size = UDim2.new(0, 14, 0, 14)
        g.Position = UDim2.new(ax, -7, ay, -7)
        g.BackgroundColor3 = activeThemeDef.accent
        g.BorderSizePixel = 0
        g.AutoButtonColor = false
        g.Text = ""
        g.ZIndex = 20
        g.Parent = rgbBorder
        corner(g, 7)
        g.InputBegan:Connect(function(input)
            if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
                return
            end
            resizing = true
            rgbBorder.Draggable = false
            center0 = rgbBorder.AbsolutePosition + rgbBorder.AbsoluteSize / 2
            d0 = math.max(1, (UserInputService:GetMouseLocation() - center0).Magnitude)
            s0 = uiScale.Scale
        end)
    end
    -- bottom-right grip: stretches the window's length (height) only
    local function makeLengthGrip()
        local g = Instance.new("TextButton")
        g.Size = UDim2.new(0, 14, 0, 14)
        g.Position = UDim2.new(1, -7, 1, -7)
        g.BackgroundColor3 = Color3.fromRGB(0, 200, 180)
        g.BorderSizePixel = 0
        g.AutoButtonColor = false
        g.Text = ""
        g.ZIndex = 20
        g.Parent = rgbBorder
        corner(g, 7)

        local dragging, startY, startH = false, 0, 478
        g.InputBegan:Connect(function(input)
            if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
                return
            end
            dragging = true
            rgbBorder.Draggable = false
            startY = UserInputService:GetMouseLocation().Y
            startH = rgbBorder.Size.Y.Offset
        end)
        getgenv().MM2HubBind(UserInputService.InputChanged, function(input)
            if not dragging then return end
            if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
                return
            end
            local dy = (UserInputService:GetMouseLocation().Y - startY) / uiScale.Scale
            local h = math.clamp(startH + dy, 380, 700)
            rgbBorder.Size = UDim2.new(0, 316, 0, h)
            mainFrame.Size = UDim2.new(0, 308, 0, h - 8)
            settings.windowH = h
        end)
        getgenv().MM2HubBind(UserInputService.InputEnded, function(input)
            if not dragging then return end
            if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
                return
            end
            dragging = false
            rgbBorder.Draggable = true
            saveSettings()
        end)
    end

    makeGrip(0, 0)
    makeGrip(1, 0)
    makeGrip(0, 1)
    makeLengthGrip()

    getgenv().MM2HubBind(UserInputService.InputChanged, function(input)
        if not resizing then return end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end
        local d = (UserInputService:GetMouseLocation() - center0).Magnitude
        local s = math.clamp(s0 * d / d0, 0.6, 1.6)
        settings.uiScale = s
        uiScale.Scale = s
    end)
    getgenv().MM2HubBind(UserInputService.InputEnded, function(input)
        if not resizing then return end
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end
        resizing = false
        rgbBorder.Draggable = true
        saveSettings()
    end)

    local t0 = os.clock()
    getgenv().MM2HubBind(RunService.Heartbeat, function()
        if resizing then return end
        local base = settings.uiScale or 1
        if settings.animatedUI then
            local t = os.clock() - t0
            uiScale.Scale = base * (1 + 0.015 * math.sin(t * 2.5))
            rgbGrad.Rotation = (t * 40) % 360
        else
            uiScale.Scale = base
        end
    end)
end

-- SHERIFF HITBOX EXPANDER: makes the murderer's hitbox bigger on your client.
-- (The server decides hits, so the gun's own beam hitbox can't be changed from here.)
do
    local HITBOX = 14
    local on = false
    local originals = setmetatable({}, { __mode = "k" }) -- HRP -> original values

    local hbBtn, hbStroke = makeButton(combatPage, "🎯 SHERIFF HITBOX EXPANDER", 250, COLOR_RED)

    local function restoreAll()
        for hrp, o in pairs(originals) do
            if hrp.Parent then
                hrp.Size = o.size
                hrp.CanCollide = o.canCollide
            end
            originals[hrp] = nil
        end
    end

    local acc = 0
    getgenv().MM2HubBind(RunService.Heartbeat, function(dt)
        if not on then return end
        acc = acc + dt
        if acc < 0.5 then return end
        acc = 0
        restoreAll()
        local m = findMurderer()
        local hrp = m and m.Character and m.Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            originals[hrp] = { size = hrp.Size, canCollide = hrp.CanCollide }
            hrp.Size = Vector3.new(HITBOX, HITBOX, HITBOX)
            hrp.CanCollide = false
        end
    end)

    getgenv().MM2HubClick(hbBtn, "MouseButton1Click", function()
        on = not on
        setToggleVisual(hbStroke, on)
        if on then
            setStatus("🎯 Sheriff hitbox expander ON", COLOR_RED)
        else
            restoreAll()
            setStatus("Sheriff hitbox expander OFF")
        end
    end)
end

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

getgenv().MM2HubBind(UserInputService.InputChanged, function(input)
    if draggingSlider and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        sliderFromX(input.Position.X)
    end
end)

getgenv().MM2HubBind(UserInputService.InputEnded, function(input)
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

getgenv().MM2HubClick(reachDone, "MouseButton1Click", function()
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
-- ============================
-- SIDE PANELS: SPEED (PLAYER tab) and AIM MODE (right-click AUTO AIM)
-- ============================
do
    -- forward declarations: the two panels open/close each other
    local setSpeedOpen, isSpeedOpen, setAimOpen, isAimOpen

    -- a panel that slides out from the right edge of the main window
    local function makeSidePanel(height)
        local panel = Instance.new("Frame")
        panel.Size = UDim2.new(0, 170, 0, height)
        panel.BackgroundColor3 = Color3.fromRGB(18, 18, 28)
        panel.BorderSizePixel = 0
        panel.Visible = false
        panel.ZIndex = 5
        panel.Parent = screenGui
        corner(panel, 12)

        local pStroke = Instance.new("UIStroke")
        pStroke.Color = activeThemeDef.accent
        pStroke.Thickness = 2
        pStroke.Parent = panel

        local progress, isOpen = 0, false
        getgenv().MM2HubBind(RunService.RenderStepped, function(dt)
            if not isOpen and progress <= 0 then
                panel.Visible = false
                return
            end
            local goal = isOpen and 1 or 0
            if progress < goal then
                progress = math.min(goal, progress + dt * 4)
            elseif progress > goal then
                progress = math.max(goal, progress - dt * 4)
            end
            local eased = 1 - (1 - progress) ^ 3
            local x = rgbBorder.AbsolutePosition.X
            local w = rgbBorder.AbsoluteSize.X
            local y = rgbBorder.AbsolutePosition.Y + 40
            local hiddenX = x + w - 24
            local shownX = x + w + 8
            panel.Position = UDim2.fromOffset(hiddenX + (shownX - hiddenX) * eased, y)
            panel.Visible = true
        end)

        local function setOpen(v)
            isOpen = v
        end
        local function getOpen()
            return isOpen
        end
        return panel, setOpen, getOpen
    end

    local function panelButton(parent, text, y, color)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(0, 140, 0, 32)
        b.Position = UDim2.new(0, 15, 0, y)
        b.BackgroundColor3 = color
        b.BorderSizePixel = 0
        b.AutoButtonColor = false
        b.Text = text
        b.TextColor3 = Color3.new(1, 1, 1)
        b.TextScaled = true
        b.Font = activeFont
        b.ZIndex = 6
        b.Parent = parent
        corner(b, 8)
        return b
    end

    local function panelTitle(parent, text, y)
        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(1, -20, 0, 24)
        l.Position = UDim2.new(0, 10, 0, y)
        l.BackgroundTransparency = 1
        l.Text = text
        l.TextColor3 = COLOR_TEXT
        l.TextScaled = true
        l.Font = activeFont
        l.ZIndex = 6
        l.Parent = parent
        return l
    end

    -- ========== SPEED ==========
    local SPEED_MIN, SPEED_MAX = 16, 200
    local speedOn = false
    local speedValue = math.clamp(tonumber(settings.walkSpeed) or 16, SPEED_MIN, SPEED_MAX)
    local baseWalk = setmetatable({}, { __mode = "k" }) -- humanoid -> original WalkSpeed

    local speedPanel
speedPanel, setSpeedOpen, isSpeedOpen = makeSidePanel(230)
    panelTitle(speedPanel, "SPEED", 8)
    local speedValueLbl = panelTitle(speedPanel, "", 40)

    local sTrack = Instance.new("Frame")
    sTrack.Size = UDim2.new(1, -40, 0, 8)
    sTrack.Position = UDim2.new(0, 20, 0, 80)
    sTrack.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
    sTrack.BorderSizePixel = 0
    sTrack.ZIndex = 6
    sTrack.Parent = speedPanel
    corner(sTrack, 4)

    local sFill = Instance.new("Frame")
    sFill.Size = UDim2.new(0, 0, 1, 0)
    sFill.BackgroundColor3 = activeThemeDef.accent
    sFill.BorderSizePixel = 0
    sFill.ZIndex = 7
    sFill.Parent = sTrack
    corner(sFill, 4)

    local sKnob = Instance.new("TextButton")
    sKnob.Size = UDim2.new(0, 18, 0, 18)
    sKnob.AnchorPoint = Vector2.new(0.5, 0.5)
    sKnob.Position = UDim2.new(0, 0, 0.5, 0)
    sKnob.BackgroundColor3 = Color3.new(1, 1, 1)
    sKnob.BorderSizePixel = 0
    sKnob.AutoButtonColor = false
    sKnob.Text = ""
    sKnob.ZIndex = 8
    sKnob.Parent = sTrack
    corner(sKnob, 9)

    local function setSpeedUI(v)
        speedValue = math.clamp(math.floor(v + 0.5), SPEED_MIN, SPEED_MAX)
        local frac = (speedValue - SPEED_MIN) / (SPEED_MAX - SPEED_MIN)
        sFill.Size = UDim2.new(frac, 0, 1, 0)
        sKnob.Position = UDim2.new(frac, 0, 0.5, 0)
        speedValueLbl.Text = "Speed: " .. speedValue
    end

    local draggingSpeed = false
    local function speedFromX(x)
        local rel = (x - sTrack.AbsolutePosition.X) / math.max(1, sTrack.AbsoluteSize.X)
        setSpeedUI(SPEED_MIN + math.clamp(rel, 0, 1) * (SPEED_MAX - SPEED_MIN))
    end
    local function beginSpeedDrag(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end
        draggingSpeed = true
        rgbBorder.Draggable = false
        speedFromX(input.Position.X)
    end
    sTrack.InputBegan:Connect(beginSpeedDrag)
    sKnob.InputBegan:Connect(beginSpeedDrag)
    getgenv().MM2HubBind(UserInputService.InputChanged, function(input)
        if draggingSpeed and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            speedFromX(input.Position.X)
        end
    end)
    getgenv().MM2HubBind(UserInputService.InputEnded, function(input)
        if draggingSpeed and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
            draggingSpeed = false
            rgbBorder.Draggable = true
        end
    end)

    local speedDone = panelButton(speedPanel, "DONE", 130, activeThemeDef.accent)
    local speedReset = panelButton(speedPanel, "RESET SPEED", 172, Color3.fromRGB(120, 40, 40))

    local speedBtn = makeButton(playerPage, "⚡ SPEED", 150, Color3.fromRGB(255, 200, 60))

    local function currentHumanoid()
        local c = player.Character
        return c and c:FindFirstChildOfClass("Humanoid")
    end

    -- remember each humanoid's original speed, and keep the chosen speed applied (also after respawn)
    getgenv().MM2HubBind(RunService.Heartbeat, function()
        local h = currentHumanoid()
        if not h then return end
        if baseWalk[h] == nil then
            baseWalk[h] = h.WalkSpeed
        end
        if speedOn and h.WalkSpeed ~= speedValue then
            h.WalkSpeed = speedValue
        end
    end)

    getgenv().MM2HubClick(speedBtn, "MouseButton1Click", function()
        setAimOpen(false)
        setSpeedOpen(not isSpeedOpen())
    end)
    getgenv().MM2HubClick(speedDone, "MouseButton1Click", function()
        speedOn = true
        settings.walkSpeed = speedValue
        saveSettings()
        speedBtn.Text = "⚡ SPEED: " .. speedValue
        setSpeedOpen(false)
        setStatus("Speed set to " .. speedValue, COLOR_GREEN)
    end)
    getgenv().MM2HubClick(speedReset, "MouseButton1Click", function()
        speedOn = false
        local h = currentHumanoid()
        local original = (h and baseWalk[h]) or 16
        if h then
            h.WalkSpeed = original
        end
        setSpeedUI(original)
        settings.walkSpeed = nil
        saveSettings()
        speedBtn.Text = "⚡ SPEED"
        setSpeedOpen(false)
        setStatus("Speed reset to " .. original)
    end)
    setSpeedUI(speedValue)

    -- ========== AIM MODE (right-click AUTO AIM) ==========
    local aimPanel
aimPanel, setAimOpen, isAimOpen = makeSidePanel(200)
    panelTitle(aimPanel, "AIM MODE", 8)
    local regBtn = panelButton(aimPanel, "REGULAR", 50, Color3.fromRGB(40, 40, 60))
    local murdBtn = panelButton(aimPanel, "AUTO AIM MURD", 96, Color3.fromRGB(40, 40, 60))
    local aimDone = panelButton(aimPanel, "DONE", 146, Color3.fromRGB(24, 24, 36))

    local function refreshAimModes()
        regBtn.BackgroundColor3 = (aimMode == "REGULAR") and activeThemeDef.accent or Color3.fromRGB(40, 40, 60)
        murdBtn.BackgroundColor3 = (aimMode == "MURD") and activeThemeDef.accent or Color3.fromRGB(40, 40, 60)
    end

    getgenv().MM2HubClick(regBtn, "MouseButton1Click", function()
        aimMode = "REGULAR"
        settings.aimMode = "REGULAR"
        saveSettings()
        refreshAimModes()
        setStatus("Aim mode: REGULAR (pick a target)", COLOR_BLUE)
    end)
    getgenv().MM2HubClick(murdBtn, "MouseButton1Click", function()
        aimMode = "MURD"
        settings.aimMode = "MURD"
        saveSettings()
        refreshAimModes()
        setStatus("Aim mode: AUTO AIM MURD (locks the knife holder)", COLOR_RED)
    end)
    getgenv().MM2HubClick(aimDone, "MouseButton1Click", function()
        setAimOpen(false)
    end)
    toggleAimBtn.MouseButton2Click:Connect(function()
        local nowOpen = not isAimOpen()
        setSpeedOpen(false)
        setAimOpen(nowOpen)
        if nowOpen then
            refreshAimModes()
        end
    end)
    refreshAimModes()
end

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
    local duration = math.max(0.05, dist / (settings.coinSpeed or COIN_SPEED))
    local tween = TweenService:Create(root, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
        CFrame = CFrame.new(coin.Position + Vector3.new(0, 3, 0)),
    })
    local done = false
    local conn = tween.Completed:Connect(function()
        done = true
    end)
    tween:Play()
    local t = 0
    while not done and autoCoinOn and coin.Parent and t < duration + 1 and HUB_GEN == getgenv().MM2HubGen do
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
    while autoCoinOn and HUB_GEN == getgenv().MM2HubGen do
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
                while settings.coinWait ~= false and not fired and coin.Parent and t < COIN_TIMEOUT and autoCoinOn do
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

-- AUTO COIN: tap/click toggles it on PC; right-click (or tap on mobile) opens the settings panel
do
    local function toggleCoin()
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
    end

    local COIN_MIN, COIN_MAX = 20, 200
    local isMobile = UserInputService.TouchEnabled and not UserInputService.MouseEnabled

    local panel = Instance.new("Frame")
    panel.Size = UDim2.new(0, 170, 0, 250)
    panel.BackgroundColor3 = Color3.fromRGB(18, 18, 28)
    panel.BorderSizePixel = 0
    panel.Visible = false
    panel.ZIndex = 5
    panel.Parent = screenGui
    corner(panel, 12)
    local pst = Instance.new("UIStroke")
    pst.Color = activeThemeDef.accent
    pst.Thickness = 2
    pst.Parent = panel

    local function plabel(y, text)
        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(1, -20, 0, 24)
        l.Position = UDim2.new(0, 10, 0, y)
        l.BackgroundTransparency = 1
        l.Text = text
        l.TextColor3 = COLOR_TEXT
        l.TextScaled = true
        l.Font = activeFont
        l.ZIndex = 6
        l.Parent = panel
        return l
    end
    local function pbtn(y, text, color)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(0, 140, 0, 32)
        b.Position = UDim2.new(0, 15, 0, y)
        b.BackgroundColor3 = color
        b.BorderSizePixel = 0
        b.AutoButtonColor = false
        b.Text = text
        b.TextColor3 = Color3.new(1, 1, 1)
        b.TextScaled = true
        b.Font = activeFont
        b.ZIndex = 6
        b.Parent = panel
        corner(b, 8)
        return b
    end

    plabel(8, "AUTO COIN")
    local valueLbl = plabel(40, "")

    local track = Instance.new("Frame")
    track.Size = UDim2.new(1, -40, 0, 8)
    track.Position = UDim2.new(0, 20, 0, 76)
    track.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
    track.BorderSizePixel = 0
    track.ZIndex = 6
    track.Parent = panel
    corner(track, 4)
    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(0, 0, 1, 0)
    fill.BackgroundColor3 = activeThemeDef.accent
    fill.BorderSizePixel = 0
    fill.ZIndex = 7
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
    knob.ZIndex = 8
    knob.Parent = track
    corner(knob, 9)

    local function setCoinSpeed(v)
        local value = math.clamp(math.floor(v + 0.5), COIN_MIN, COIN_MAX)
        settings.coinSpeed = value
        local frac = (value - COIN_MIN) / (COIN_MAX - COIN_MIN)
        fill.Size = UDim2.new(frac, 0, 1, 0)
        knob.Position = UDim2.new(frac, 0, 0.5, 0)
        valueLbl.Text = "Speed: " .. value
    end

    local dragging = false
    local function speedFromX(x)
        local rel = (x - track.AbsolutePosition.X) / math.max(1, track.AbsoluteSize.X)
        setCoinSpeed(COIN_MIN + math.clamp(rel, 0, 1) * (COIN_MAX - COIN_MIN))
    end
    local function beginDrag(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end
        dragging = true
        rgbBorder.Draggable = false
        speedFromX(input.Position.X)
    end
    track.InputBegan:Connect(beginDrag)
    knob.InputBegan:Connect(beginDrag)
    getgenv().MM2HubBind(UserInputService.InputChanged, function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            speedFromX(input.Position.X)
        end
    end)
    getgenv().MM2HubBind(UserInputService.InputEnded, function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
            dragging = false
            rgbBorder.Draggable = true
            saveSettings()
        end
    end)

    local onOffBtn = pbtn(122, "START", activeThemeDef.accent)
    local waitBtn = pbtn(164, "WAIT: ON", Color3.fromRGB(40, 40, 60))
    local doneBtn = pbtn(206, "DONE", Color3.fromRGB(24, 24, 36))

    local function refresh()
        onOffBtn.Text = autoCoinOn and "STOP" or "START"
        waitBtn.Text = "WAIT: " .. (settings.coinWait ~= false and "ON" or "OFF")
        setCoinSpeed(settings.coinSpeed or COIN_SPEED)
    end

    local progress, isOpen = 0, false
    getgenv().MM2HubBind(RunService.RenderStepped, function(dt)
        if not isOpen and progress <= 0 then
            panel.Visible = false
            return
        end
        local goal = isOpen and 1 or 0
        if progress < goal then
            progress = math.min(goal, progress + dt * 4)
        elseif progress > goal then
            progress = math.max(goal, progress - dt * 4)
        end
        local eased = 1 - (1 - progress) ^ 3
        local x = rgbBorder.AbsolutePosition.X
        local w = rgbBorder.AbsoluteSize.X
        local y = rgbBorder.AbsolutePosition.Y + 40
        local hiddenX = x + w - 24
        local shownX = x + w + 8
        panel.Position = UDim2.fromOffset(hiddenX + (shownX - hiddenX) * eased, y)
        panel.Visible = true
    end)

    local function openPanel()
        isOpen = true
        refresh()
    end

    getgenv().MM2HubClick(autoCoinBtn, "MouseButton1Click", function()
        if isMobile then
            openPanel()
        else
            toggleCoin()
        end
        refresh()
    end)
    autoCoinBtn.MouseButton2Click:Connect(openPanel)
    getgenv().MM2HubClick(onOffBtn, "MouseButton1Click", function()
        toggleCoin()
        refresh()
    end)
    getgenv().MM2HubClick(waitBtn, "MouseButton1Click", function()
        settings.coinWait = not (settings.coinWait ~= false)
        saveSettings()
        refresh()
    end)
    getgenv().MM2HubClick(doneBtn, "MouseButton1Click", function()
        isOpen = false
        saveSettings()
    end)
end

-- NO ANIM: stops every animation on your character (toggle)
do
    local on = settings.noAnim == true
    local noAnimBtn, noAnimStroke = makeButton(playerPage, "🚫 NO ANIM", 200, Color3.fromRGB(255, 90, 90))
    setToggleVisual(noAnimStroke, on)

    local function setAnimateDisabled(char, value)
        local animate = char and char:FindFirstChild("Animate")
        if animate and animate:IsA("LocalScript") then
            animate.Disabled = value
        end
    end

    getgenv().MM2HubBind(RunService.Heartbeat, function()
        if not on then return end
        local char = player.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local animator = hum and hum:FindFirstChildOfClass("Animator")
        if animator then
            for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
                track:Stop(0)
            end
        end
        setAnimateDisabled(char, true)
    end)

    getgenv().MM2HubClick(noAnimBtn, "MouseButton1Click", function()
        on = not on
        settings.noAnim = on
        saveSettings()
        setToggleVisual(noAnimStroke, on)
        if not on then
            setAnimateDisabled(player.Character, false)
        end
        setStatus(on and "No Anim ON" or "No Anim OFF", on and COLOR_RED or COLOR_DIM)
    end)
end

-- OPTIMIZER: removes textures and materials from the world (toggle, restores on off)
do
    local on = settings.optimizer == true
    local optBtn, optStroke = makeButton(playerPage, "⚙ OPTIMIZER", 250, Color3.fromRGB(120, 255, 160))
    setToggleVisual(optStroke, on)

    local saved = {} -- object -> original values

    local function strip(o)
        if saved[o] ~= nil then return end
        if o:IsA("BasePart") then
            local v = { kind = "part", material = o.Material }
            o.Material = Enum.Material.SmoothPlastic
            if o:IsA("MeshPart") then
                v.texture = o.TextureID
                o.TextureID = ""
            end
            saved[o] = v
        elseif o:IsA("Decal") or o:IsA("Texture") then
            saved[o] = { kind = "decal", transparency = o.Transparency }
            o.Transparency = 1
        elseif o:IsA("SpecialMesh") then
            saved[o] = { kind = "mesh", texture = o.TextureId }
            o.TextureId = ""
        elseif o:IsA("SurfaceAppearance") then
            saved[o] = { kind = "parent", parent = o.Parent }
            o.Parent = nil
        end
    end

    local function restoreAll()
        for o, v in pairs(saved) do
            pcall(function()
                if v.kind == "part" then
                    o.Material = v.material
                    if v.texture then o.TextureID = v.texture end
                elseif v.kind == "decal" then
                    o.Transparency = v.transparency
                elseif v.kind == "mesh" then
                    o.TextureId = v.texture
                elseif v.kind == "parent" then
                    o.Parent = v.parent
                end
            end)
            saved[o] = nil
        end
    end

    local function applyAll()
        local count = 0
        for _, o in ipairs(workspace:GetDescendants()) do
            pcall(strip, o)
            count = count + 1
            if count % 400 == 0 then
                task.wait()
            end
        end
    end

    getgenv().MM2HubBind(workspace.DescendantAdded, function(o)
        if on then
            pcall(strip, o)
        end
    end)

    getgenv().MM2HubClick(optBtn, "MouseButton1Click", function()
        on = not on
        settings.optimizer = on
        saveSettings()
        setToggleVisual(optStroke, on)
        if on then
            task.spawn(applyAll)
            setStatus("⚙ Optimizer ON: textures and materials removed", COLOR_GREEN)
        else
            restoreAll()
            setStatus("Optimizer OFF: textures restored")
        end
    end)

    if on then
        task.spawn(applyAll)
    end
end

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

getgenv().MM2HubClick(invisBtn, "MouseButton1Click", function()
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

getgenv().MM2HubBind(UserInputService.InputChanged, function(input)
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

getgenv().MM2HubBind(RunService.RenderStepped, function()
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

getgenv().MM2HubClick(noclipJumpBtn, "MouseButton1Click", function()
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

getgenv().MM2HubBind(UserInputService.JumpRequest, function()
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
local GAMES = {} -- key -> starter function, filled in below
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

    local heartConn = getgenv().MM2HubBind(RunService.Heartbeat, function(dt)
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

    local inputConn = getgenv().MM2HubBind(UserInputService.InputBegan, function(input, gp)
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

    local conn = getgenv().MM2HubBind(RunService.Heartbeat, function()
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

    local conn = getgenv().MM2HubBind(RunService.Heartbeat, function(dt)
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

    local conn = getgenv().MM2HubBind(RunService.Heartbeat, function(dt)
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

    getgenv().MM2HubClick(pad, "MouseButton1Click", function()
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

-- register the games (GAMES tab buttons call startGame(key))
GAMES.STACK = startBlockStack
GAMES.OBBY = startObbyGame
GAMES.LOOT = startLootGame
GAMES.DODGE = startDodgeGame
GAMES.REACTION = startReactionGame

startGame = function(key)
    stopGame(true)
    local starter = GAMES[key]
    if not starter then return end
    local ok, result = pcall(starter)
    if ok and result then
        activeGame = { key = key, cleanup = result }
    elseif not ok then
        setStatus("Game failed to start: " .. tostring(result), COLOR_RED)
    end
end

end -- mini-game definitions

-- ============================
-- MORE MINI GAMES (each one is registered in GAMES)
-- ============================
do
    -- shared window for the 2D games
    local function gameWindow(title, w, h)
        local gui = Instance.new("ScreenGui")
        gui.Name = "MM2Hub_Game"
        gui.ResetOnSpawn = false
        gui.DisplayOrder = 50
        gui.Parent = playerGui

        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(0, w, 0, h)
        frame.Position = UDim2.new(0.5, -math.floor(w / 2), 0.5, -math.floor(h / 2))
        frame.BackgroundColor3 = Color3.fromRGB(14, 14, 22)
        frame.BorderSizePixel = 0
        frame.Active = true
        frame.Draggable = true
        frame.Parent = gui
        corner(frame, 14)

        local grad = Instance.new("UIGradient")
        grad.Color = ColorSequence.new(Color3.fromRGB(34, 24, 56), Color3.fromRGB(12, 12, 18))
        grad.Rotation = 90
        grad.Parent = frame

        local stroke = Instance.new("UIStroke")
        stroke.Color = activeThemeDef.accent
        stroke.Thickness = 2
        stroke.Parent = frame

        local head = Instance.new("TextLabel")
        head.Size = UDim2.new(1, -60, 0, 26)
        head.Position = UDim2.new(0, 12, 0, 8)
        head.BackgroundTransparency = 1
        head.Text = title
        head.TextColor3 = COLOR_TEXT
        head.TextScaled = true
        head.TextXAlignment = Enum.TextXAlignment.Left
        head.Font = activeFont
        head.Parent = frame

        local close = Instance.new("TextButton")
        close.Size = UDim2.new(0, 30, 0, 26)
        close.Position = UDim2.new(1, -40, 0, 8)
        close.BackgroundColor3 = COLOR_RED
        close.BorderSizePixel = 0
        close.Text = "X"
        close.TextColor3 = Color3.new(1, 1, 1)
        close.TextScaled = true
        close.Font = activeFont
        close.Parent = frame
        corner(close, 6)
        getgenv().MM2HubClick(close, "MouseButton1Click", function()
            stopGame()
        end)

        local score = Instance.new("TextLabel")
        score.Size = UDim2.new(1, -24, 0, 22)
        score.Position = UDim2.new(0, 12, 0, 36)
        score.BackgroundTransparency = 1
        score.Text = ""
        score.TextColor3 = COLOR_GOLD
        score.TextScaled = true
        score.Font = activeFont
        score.Parent = frame

        -- bottom-right grip: resize width and height (drag the title bar to move)
        local grip = Instance.new("TextButton")
        grip.Size = UDim2.new(0, 16, 0, 16)
        grip.AnchorPoint = Vector2.new(1, 1)
        grip.Position = UDim2.new(1, -4, 1, -4)
        grip.BackgroundColor3 = activeThemeDef.accent
        grip.BorderSizePixel = 0
        grip.AutoButtonColor = false
        grip.Text = ""
        grip.ZIndex = 10
        grip.Parent = frame
        corner(grip, 5)

        local resizing, sMouse, sW, sH = false, Vector2.new(), w, h
        grip.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                resizing = true
                frame.Draggable = false
                sMouse = UserInputService:GetMouseLocation()
                sW, sH = frame.AbsoluteSize.X, frame.AbsoluteSize.Y
            end
        end)
        local c1 = getgenv().MM2HubBind(UserInputService.InputChanged, function(input)
            if resizing and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                local m = UserInputService:GetMouseLocation()
                local nw = math.clamp(sW + (m.X - sMouse.X), 240, 700)
                local nh = math.clamp(sH + (m.Y - sMouse.Y), 220, 700)
                frame.Size = UDim2.new(0, nw, 0, nh)
            end
        end)
        local c2 = getgenv().MM2HubBind(UserInputService.InputEnded, function(input)
            if resizing and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
                resizing = false
                frame.Draggable = true
            end
        end)
        gui.Destroying:Connect(function()
            c1:Disconnect()
            c2:Disconnect()
        end)

        return gui, frame, score
    end

    -- TARGET RUSH (3D): click the floating neon balls before they vanish
    GAMES.TARGET = function()
        local char = player.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not root then
            setStatus("No character to play with.", COLOR_RED)
            return nil
        end
        local returnCF = root.CFrame
        local CENTER = Vector3.new(-800, 800, 0)
        local DURATION = 30

        local folder = Instance.new("Folder")
        folder.Name = "MM2Hub_Target"
        folder.Parent = workspace

        local floor = Instance.new("Part")
        floor.Anchored = true
        floor.Size = Vector3.new(160, 2, 160)
        floor.Position = CENTER
        floor.Color = Color3.fromRGB(20, 40, 30)
        floor.Material = Enum.Material.Grass
        floor.Parent = folder

        root.CFrame = CFrame.new(CENTER + Vector3.new(0, 4, 0))

        local gui, frame, scoreLbl = gameWindow("🎯 TARGET RUSH", 300, 70)
        local score, spawnAcc, alive = 0, 0, true
        local targets = {}
        local startT = os.clock()

        local function spawnTarget()
            local p = Instance.new("Part")
            p.Shape = Enum.PartType.Ball
            p.Size = Vector3.new(4, 4, 4)
            p.Anchored = true
            p.CanCollide = false
            p.Material = Enum.Material.Neon
            p.Color = Color3.fromHSV(math.random(), 0.8, 1)
            local ang = math.random() * math.pi * 2
            local dist = math.random(4, 22)
            p.Position = CENTER + Vector3.new(math.cos(ang) * dist, 6 + math.random(-2, 10), math.sin(ang) * dist)
            p.Parent = folder

            local cd = Instance.new("ClickDetector")
            cd.MaxActivationDistance = 500
            cd.Parent = p
            cd.MouseClick:Connect(function()
                if alive and p.Parent then
                    score = score + 1
                    p:Destroy()
                end
            end)

            table.insert(targets, { part = p, born = os.clock(), life = math.max(0.9, 1.8 - score * 0.02) })
        end

        local conn
        conn = getgenv().MM2HubBind(RunService.Heartbeat, function(dt)
            if not alive then return end
            local left = DURATION - (os.clock() - startT)
            if left <= 0 then
                alive = false
                scoreLbl.Text = "Time's up! Score: " .. score .. "  (X to leave)"
                setStatus("🎯 Target Rush score: " .. score, COLOR_GOLD)
                return
            end
            scoreLbl.Text = string.format("Score %d   |   %ds left", score, math.ceil(left))

            spawnAcc = spawnAcc + dt
            if spawnAcc >= math.max(0.35, 0.9 - score * 0.01) then
                spawnAcc = 0
                spawnTarget()
            end
            for i = #targets, 1, -1 do
                local t = targets[i]
                if not t.part.Parent or os.clock() - t.born > t.life then
                    if t.part.Parent then
                        t.part:Destroy()
                    end
                    table.remove(targets, i)
                end
            end
        end)

        return function()
            alive = false
            conn:Disconnect()
            folder:Destroy()
            gui:Destroy()
            local c = player.Character
            local rr = c and c:FindFirstChild("HumanoidRootPart")
            if rr then
                rr.CFrame = returnCF
            end
        end
    end

    -- SIMON PADS: watch the color order, then repeat it. It gets longer every round.
    GAMES.SIMON = function()
        local gui, frame, scoreLbl = gameWindow("🟥 SIMON PADS", 300, 340)
        local COLORS = {
            Color3.fromRGB(230, 40, 60),
            Color3.fromRGB(40, 200, 90),
            Color3.fromRGB(40, 120, 255),
            Color3.fromRGB(255, 210, 40),
        }
        local DIM = {
            Color3.fromRGB(90, 20, 28),
            Color3.fromRGB(20, 80, 40),
            Color3.fromRGB(20, 50, 110),
            Color3.fromRGB(110, 90, 20),
        }

        local pads = {}
        for i = 1, 4 do
            local col = (i - 1) % 2
            local row = math.floor((i - 1) / 2)
            local b = Instance.new("TextButton")
            b.Size = UDim2.new(0, 126, 0, 120)
            b.Position = UDim2.new(0, 12 + col * 138, 0, 70 + row * 130)
            b.BackgroundColor3 = DIM[i]
            b.BorderSizePixel = 0
            b.AutoButtonColor = false
            b.Text = ""
            b.Parent = frame
            corner(b, 12)
            pads[i] = b
        end

        local sequence, input, showing, alive, gen = {}, {}, false, true, 0

        local function flash(i, dur)
            pads[i].BackgroundColor3 = COLORS[i]
            task.delay(dur, function()
                if alive then
                    pads[i].BackgroundColor3 = DIM[i]
                end
            end)
        end

        local nextRound
        local function playSequence()
            showing = true
            input = {}
            gen = gen + 1
            local myGen = gen
            scoreLbl.Text = "Watch... round " .. #sequence
            task.spawn(function()
                task.wait(0.6)
                for _, idx in ipairs(sequence) do
                    if myGen ~= gen or not alive then return end
                    flash(idx, 0.35)
                    task.wait(0.55)
                end
                if myGen ~= gen or not alive then return end
                showing = false
                scoreLbl.Text = "Your turn! Round " .. #sequence
            end)
        end

        nextRound = function()
            table.insert(sequence, math.random(1, 4))
            playSequence()
        end

        for i, b in ipairs(pads) do
            getgenv().MM2HubClick(b, "MouseButton1Click", function()
                if showing or not alive then return end
                flash(i, 0.18)
                table.insert(input, i)
                local pos = #input
                if sequence[pos] ~= i then
                    alive = false
                    showing = true
                    scoreLbl.Text = "Wrong! You reached round " .. (#sequence - 1) .. "  (X to leave)"
                    setStatus("🟥 Simon: round " .. (#sequence - 1), COLOR_RED)
                    return
                end
                if pos == #sequence then
                    showing = true
                    scoreLbl.Text = "Nice! Next round..."
                    task.delay(0.8, function()
                        if alive then
                            nextRound()
                        end
                    end)
                end
            end)
        end

        nextRound()

        return function()
            alive = false
            gen = gen + 1
            gui:Destroy()
        end
    end

    -- WHACK-A-MOLE: a mole pops up in one of 9 holes, hit it before it hides
    GAMES.WHACK = function()
        local gui, frame, scoreLbl = gameWindow("🐹 WHACK-A-MOLE", 300, 330)
        local DURATION = 30
        local DIRT = Color3.fromRGB(60, 42, 26)
        local MOLE = Color3.fromRGB(150, 100, 40)
        local HIT = COLOR_GOLD
        local cells = {}
        local score, alive = 0, true
        local litIndex, litLeft = nil, 0
        local waitAcc = 0
        local startT = os.clock()

        local function clearLit()
            if litIndex then
                cells[litIndex].Text = ""
                cells[litIndex].BackgroundColor3 = DIRT
                litIndex = nil
            end
        end

        for i = 1, 9 do
            local col = (i - 1) % 3
            local row = math.floor((i - 1) / 3)
            local b = Instance.new("TextButton")
            b.Size = UDim2.new(0, 84, 0, 84)
            b.Position = UDim2.new(0, 12 + col * 94, 0, 70 + row * 90)
            b.BackgroundColor3 = DIRT
            b.BorderSizePixel = 0
            b.AutoButtonColor = false
            b.Text = ""
            b.TextScaled = true
            b.Font = activeFont
            b.Parent = frame
            corner(b, 42)
            getgenv().MM2HubClick(b, "MouseButton1Click", function()
                if not alive or litIndex ~= i then return end
                score = score + 1
                litIndex = nil
                b.Text = "💥"
                b.BackgroundColor3 = HIT
                task.delay(0.25, function()
                    if alive and litIndex ~= i then
                        b.Text = ""
                        b.BackgroundColor3 = DIRT
                    end
                end)
            end)
            cells[i] = b
        end

        local conn
        conn = getgenv().MM2HubBind(RunService.Heartbeat, function(dt)
            if not alive then return end
            local left = DURATION - (os.clock() - startT)
            if left <= 0 then
                alive = false
                clearLit()
                scoreLbl.Text = "Time's up! Score: " .. score .. "  (X to leave)"
                setStatus("🐹 Whack-a-Mole score: " .. score, COLOR_GOLD)
                return
            end
            scoreLbl.Text = string.format("Score %d   |   %ds left", score, math.ceil(left))

            if litIndex then
                litLeft = litLeft - dt
                if litLeft <= 0 then
                    clearLit()
                end
            else
                waitAcc = waitAcc + dt
                if waitAcc >= math.max(0.25, 0.6 - score * 0.01) then
                    waitAcc = 0
                    local pick = math.random(1, 9)
                    if pick == litIndex then pick = (pick % 9) + 1 end
                    litIndex = pick
                    litLeft = math.max(0.45, 1.2 - score * 0.01)
                    cells[pick].Text = "🐹"
                    cells[pick].BackgroundColor3 = MOLE
                end
            end
        end)

        return function()
            alive = false
            conn:Disconnect()
            gui:Destroy()
        end
    end

    -- COLOR MATCH: the word says one color, its ink is another. Click the INK color.
    GAMES.COLOR = function()
        local gui, frame, scoreLbl = gameWindow("🎨 COLOR MATCH", 300, 300)
        local DURATION = 30
        local NAMES = { "RED", "GREEN", "BLUE", "GOLD" }
        local COLORS = {
            Color3.fromRGB(230, 50, 60),
            Color3.fromRGB(60, 210, 100),
            Color3.fromRGB(60, 130, 255),
            Color3.fromRGB(255, 210, 60),
        }
        local score, inkIdx, alive = 0, 1, true
        local startT = os.clock()

        local word = Instance.new("TextLabel")
        word.Size = UDim2.new(1, -24, 0, 90)
        word.Position = UDim2.new(0, 12, 0, 70)
        word.BackgroundTransparency = 1
        word.Text = ""
        word.TextScaled = true
        word.Font = activeFont
        word.Parent = frame

        local function newRound()
            local w = math.random(1, 4)
            inkIdx = math.random(1, 4)
            word.Text = NAMES[w]
            word.TextColor3 = COLORS[inkIdx]
        end

        for i = 1, 4 do
            local col = (i - 1) % 2
            local row = math.floor((i - 1) / 2)
            local b = Instance.new("TextButton")
            b.Size = UDim2.new(0, 130, 0, 60)
            b.Position = UDim2.new(0, 12 + col * 142, 0, 180 + row * 68)
            b.BackgroundColor3 = Color3.fromRGB(28, 28, 40)
            b.BorderSizePixel = 0
            b.AutoButtonColor = false
            b.Text = NAMES[i]
            b.TextColor3 = COLORS[i]
            b.TextScaled = true
            b.Font = activeFont
            b.Parent = frame
            corner(b, 10)
            getgenv().MM2HubClick(b, "MouseButton1Click", function()
                if not alive then return end
                if i == inkIdx then
                    score = score + 1
                    b.BackgroundColor3 = Color3.fromRGB(40, 110, 60)
                else
                    score = math.max(0, score - 1)
                    b.BackgroundColor3 = Color3.fromRGB(120, 30, 30)
                end
                task.delay(0.15, function()
                    b.BackgroundColor3 = Color3.fromRGB(28, 28, 40)
                end)
                newRound()
            end)
        end

        newRound()

        local conn
        conn = getgenv().MM2HubBind(RunService.Heartbeat, function()
            if not alive then return end
            local left = DURATION - (os.clock() - startT)
            if left <= 0 then
                alive = false
                word.Text = "TIME!"
                word.TextColor3 = COLOR_GOLD
                scoreLbl.Text = "Final score: " .. score .. "  (X to leave)"
                setStatus("🎨 Color Match score: " .. score, COLOR_GOLD)
                return
            end
            scoreLbl.Text = string.format("Score %d   |   %ds left", score, math.ceil(left))
        end)

        return function()
            alive = false
            conn:Disconnect()
            gui:Destroy()
        end
    end
    -- BUBBLE POP: bubbles float up, click them before they escape
    GAMES.BUBBLE = function()
        local gui, frame, scoreLbl = gameWindow("🫧 BUBBLE POP", 320, 380)
        local field = Instance.new("Frame")
        field.Size = UDim2.new(0, 296, 0, 290)
        field.Position = UDim2.new(0, 12, 0, 74)
        field.BackgroundColor3 = Color3.fromRGB(8, 14, 26)
        field.BorderSizePixel = 0
        field.ClipsDescendants = true
        field.Parent = frame
        corner(field, 10)

        local DURATION = 30
        local score, alive, spawnAcc = 0, true, 0
        local bubbles = {}
        local startT = os.clock()

        local function spawn()
            local size = math.random(34, 56)
            local b = Instance.new("TextButton")
            b.Size = UDim2.new(0, size, 0, size)
            b.Position = UDim2.new(0, math.random(0, 296 - size), 0, 290)
            b.BackgroundColor3 = Color3.fromHSV(math.random(), 0.55, 1)
            b.BackgroundTransparency = 0.1
            b.AutoButtonColor = false
            b.Text = ""
            b.Parent = field
            corner(b, math.floor(size / 2))
            local bb = { ui = b, y = 290, speed = math.random(40, 80) + score }
            table.insert(bubbles, bb)
            getgenv().MM2HubClick(b, "MouseButton1Click", function()
                if not alive or not b.Parent then return end
                score = score + 1
                b:Destroy()
            end)
        end

        local conn
        conn = getgenv().MM2HubBind(RunService.Heartbeat, function(dt)
            if not alive then return end
            local left = DURATION - (os.clock() - startT)
            if left <= 0 then
                alive = false
                scoreLbl.Text = "Time's up! Score: " .. score .. "  (X to leave)"
                setStatus("🫧 Bubble Pop score: " .. score, COLOR_GOLD)
                return
            end
            scoreLbl.Text = string.format("Score %d   |   %ds left", score, math.ceil(left))

            spawnAcc = spawnAcc + dt
            if spawnAcc >= math.max(0.25, 0.7 - score * 0.01) then
                spawnAcc = 0
                spawn()
            end
            for i = #bubbles, 1, -1 do
                local bb = bubbles[i]
                if bb.ui.Parent == nil then
                    table.remove(bubbles, i)
                else
                    bb.y = bb.y - bb.speed * dt
                    if bb.y < -60 then
                        bb.ui:Destroy()
                        table.remove(bubbles, i)
                    else
                        bb.ui.Position = UDim2.new(bb.ui.Position.X.Scale, bb.ui.Position.X.Offset, 0, bb.y)
                    end
                end
            end
        end)

        return function()
            alive = false
            conn:Disconnect()
            gui:Destroy()
        end
    end

    -- MEMORY FLIP: find the 8 matching pairs
    GAMES.MEMORY = function()
        local gui, frame, scoreLbl = gameWindow("🃏 MEMORY FLIP", 320, 380)
        local SYMBOLS = { "🎃", "👻", "🦇", "🍬", "🕷", "🧙", "💀", "🔮" }
        local deck = {}
        for _, sym in ipairs(SYMBOLS) do
            table.insert(deck, sym)
            table.insert(deck, sym)
        end
        for k = #deck, 2, -1 do
            local j = math.random(1, k)
            deck[k], deck[j] = deck[j], deck[k]
        end

        local cards = {}
        local open, lock, matches, moves, alive = {}, false, 0, 0, true
        local function update()
            scoreLbl.Text = "Moves " .. moves .. "   |   Pairs " .. matches .. "/8"
        end

        for i = 1, 16 do
            local col = (i - 1) % 4
            local row = math.floor((i - 1) / 4)
            local b = Instance.new("TextButton")
            b.Size = UDim2.new(0, 64, 0, 64)
            b.Position = UDim2.new(0, 12 + col * 74, 0, 74 + row * 74)
            b.BackgroundColor3 = Color3.fromRGB(60, 40, 90)
            b.BorderSizePixel = 0
            b.AutoButtonColor = false
            b.Text = "?"
            b.TextScaled = true
            b.TextColor3 = COLOR_TEXT
            b.Font = activeFont
            b.Parent = frame
            corner(b, 10)
            cards[i] = { ui = b, sym = deck[i], shown = false, done = false }

            getgenv().MM2HubClick(b, "MouseButton1Click", function()
                local card = cards[i]
                if not alive or lock or card.shown or card.done then return end
                card.shown = true
                b.Text = card.sym
                b.BackgroundColor3 = Color3.fromRGB(230, 200, 120)
                table.insert(open, i)
                if #open == 2 then
                    moves = moves + 1
                    local i1, i2 = open[1], open[2]
                    local a, c = cards[i1], cards[i2]
                    open = {}
                    if a.sym == c.sym then
                        a.done, c.done = true, true
                        matches = matches + 1
                        if matches == 8 then
                            alive = false
                            setStatus("🃏 Memory solved in " .. moves .. " moves!", COLOR_GOLD)
                        end
                    else
                        lock = true
                        task.delay(0.8, function()
                            if alive then
                                a.shown, c.shown = false, false
                                a.ui.Text = "?"
                                c.ui.Text = "?"
                                a.ui.BackgroundColor3 = Color3.fromRGB(60, 40, 90)
                                c.ui.BackgroundColor3 = Color3.fromRGB(60, 40, 90)
                            end
                            lock = false
                        end)
                    end
                    update()
                end
            end)
        end
        update()

        return function()
            alive = false
            gui:Destroy()
        end
    end

    -- SLIDE PUZZLE: slide the tiles back into order (empty tile is the last one)
    GAMES.PUZZLE = function()
        local gui, frame, scoreLbl = gameWindow("🧩 SLIDE PUZZLE", 320, 380)
        local grid = { 1, 2, 3, 4, 5, 6, 7, 8, 0 } -- 0 = empty

        local function emptyIndex()
            for k = 1, 9 do
                if grid[k] == 0 then return k end
            end
        end
        local function neighbors(k)
            local r, c = math.floor((k - 1) / 3), (k - 1) % 3
            local out = {}
            if r > 0 then table.insert(out, k - 3) end
            if r < 2 then table.insert(out, k + 3) end
            if c > 0 then table.insert(out, k - 1) end
            if c < 2 then table.insert(out, k + 1) end
            return out
        end

        -- scramble with legal moves so the puzzle is always solvable
        for _ = 1, 200 do
            local e = emptyIndex()
            local nb = neighbors(e)
            local pick = nb[math.random(1, #nb)]
            grid[e], grid[pick] = grid[pick], grid[e]
        end

        local tiles = {}
        local moves, alive = 0, true
        local function render()
            for k = 1, 9 do
                local v = grid[k]
                tiles[k].Text = v ~= 0 and tostring(v) or ""
                tiles[k].BackgroundColor3 = v ~= 0 and Color3.fromRGB(70, 60, 120) or Color3.fromRGB(14, 14, 22)
            end
            scoreLbl.Text = "Moves " .. moves
        end

        for k = 1, 9 do
            local col = (k - 1) % 3
            local row = math.floor((k - 1) / 3)
            local b = Instance.new("TextButton")
            b.Size = UDim2.new(0, 90, 0, 90)
            b.Position = UDim2.new(0, 12 + col * 98, 0, 74 + row * 98)
            b.BorderSizePixel = 0
            b.AutoButtonColor = false
            b.TextScaled = true
            b.TextColor3 = COLOR_TEXT
            b.Font = activeFont
            b.Parent = frame
            corner(b, 12)
            tiles[k] = b

            getgenv().MM2HubClick(b, "MouseButton1Click", function()
                if not alive then return end
                local e = emptyIndex()
                local adjacent = false
                for _, n in ipairs(neighbors(e)) do
                    if n == k then adjacent = true end
                end
                if not adjacent then return end
                grid[e], grid[k] = grid[k], grid[e]
                moves = moves + 1
                render()

                local solved = true
                for idx = 1, 8 do
                    if grid[idx] ~= idx then solved = false end
                end
                if solved and grid[9] == 0 then
                    alive = false
                    scoreLbl.Text = "Solved in " .. moves .. " moves!  (X to leave)"
                    setStatus("🧩 Puzzle solved in " .. moves .. " moves", COLOR_GOLD)
                end
            end)
        end
        render()

        return function()
            alive = false
            gui:Destroy()
        end
    end
end

local function toggleGame(key)
    if activeGame and activeGame.key == key then
        stopGame()
    else
        startGame(key)
    end
end

-- GAMES TAB
do -- game menu: a card for each game
    local ENTRIES = {
        { key = "STACK", icon = "🧱", name = "BLOCK STACK", desc = "Drop blocks onto the tower", color = COLOR_GOLD },
        { key = "OBBY", icon = "🏃", name = "OBBY RUN", desc = "Climb the platforms", color = Color3.fromRGB(80, 220, 120) },
        { key = "LOOT", icon = "💰", name = "LOOT RUSH", desc = "Grab orbs before time runs out", color = Color3.fromRGB(180, 80, 255) },
        { key = "DODGE", icon = "☄", name = "DODGE", desc = "Survive the falling blocks", color = COLOR_RED },
        { key = "REACTION", icon = "⚡", name = "REACTION TEST", desc = "How fast are your reflexes?", color = COLOR_BLUE },
        { key = "TARGET", icon = "🎯", name = "TARGET RUSH", desc = "Click the floating 3D targets", color = Color3.fromRGB(80, 220, 255) },
        { key = "SIMON", icon = "🟥", name = "SIMON PADS", desc = "Repeat the growing color pattern", color = Color3.fromRGB(255, 120, 0) },
        { key = "WHACK", icon = "🐹", name = "WHACK-A-MOLE", desc = "Smash the moles, fast", color = Color3.fromRGB(150, 110, 60) },
        { key = "COLOR", icon = "🎨", name = "COLOR MATCH", desc = "Click the ink color, not the word", color = Color3.fromRGB(255, 80, 180) },
        { key = "BUBBLE", icon = "🫧", name = "BUBBLE POP", desc = "Pop the bubbles before they escape", color = Color3.fromRGB(90, 200, 255) },
        { key = "MEMORY", icon = "🃏", name = "MEMORY FLIP", desc = "Find all 8 matching pairs", color = Color3.fromRGB(255, 170, 60) },
        { key = "PUZZLE", icon = "🧩", name = "SLIDE PUZZLE", desc = "Slide the tiles back in order", color = Color3.fromRGB(160, 255, 120) },
    }
    local CARD_H = 74

    for i, e in ipairs(ENTRIES) do
        local col = (i - 1) % 2
        local row = math.floor((i - 1) / 2)
        local card = Instance.new("TextButton")
        card.Size = UDim2.new(0.5, -10, 0, CARD_H - 8)
        card.Position = UDim2.new(col * 0.5, col == 0 and 6 or 4, 0, row * CARD_H + 4)
        card.BackgroundColor3 = Color3.fromRGB(26, 26, 40)
        card.BorderSizePixel = 0
        card.AutoButtonColor = false
        card.Text = ""
        card.Parent = gamesPage
        corner(card, 12)

        local cGrad = Instance.new("UIGradient")
        cGrad.Color = ColorSequence.new(Color3.fromRGB(44, 40, 70), Color3.fromRGB(16, 16, 26))
        cGrad.Rotation = 90
        cGrad.Parent = card

        local cStroke = Instance.new("UIStroke")
        cStroke.Color = e.color
        cStroke.Thickness = 1.5
        cStroke.Parent = card

        local icon = Instance.new("TextLabel")
        icon.Size = UDim2.new(0, 46, 0, 46)
        icon.Position = UDim2.new(0, 8, 0.5, -23)
        icon.BackgroundColor3 = e.color
        icon.BackgroundTransparency = 0.2
        icon.Text = e.icon
        icon.TextScaled = true
        icon.Parent = card
        corner(icon, 23)

        local title = Instance.new("TextLabel")
        title.Size = UDim2.new(1, -72, 0, 24)
        title.Position = UDim2.new(0, 64, 0, 8)
        title.BackgroundTransparency = 1
        title.Text = e.name
        title.TextColor3 = COLOR_TEXT
        title.TextScaled = true
        title.TextXAlignment = Enum.TextXAlignment.Left
        title.Font = activeFont
        title.Parent = card

        local sub = Instance.new("TextLabel")
        sub.Size = UDim2.new(1, -72, 0, 18)
        sub.Position = UDim2.new(0, 64, 0, 32)
        sub.BackgroundTransparency = 1
        sub.Text = e.desc
        sub.TextColor3 = COLOR_DIM
        sub.TextScaled = true
        sub.TextXAlignment = Enum.TextXAlignment.Left
        sub.Font = activeFont
        sub.Parent = card

        card.MouseButton1Down:Connect(function()
            TweenService:Create(cStroke, TweenInfo.new(0.06), { Thickness = 3.5 }):Play()
        end)
        getgenv().MM2HubClick(card, "MouseButton1Up", function()
            TweenService:Create(cStroke, TweenInfo.new(0.15), { Thickness = 1.5 }):Play()
        end)
        getgenv().MM2HubClick(card, "MouseButton1Click", function()
            toggleGame(e.key)
        end)
    end

    local rows = math.ceil(#ENTRIES / 2)
    local stopGameBtn = makeButton(gamesPage, "■ STOP GAME", rows * CARD_H + 4, COLOR_DIM)
    getgenv().MM2HubClick(stopGameBtn, "MouseButton1Click", function() stopGame() end)
    if gamesPage:IsA("ScrollingFrame") then
        gamesPage.CanvasSize = UDim2.new(0, 0, 0, rows * CARD_H + 120)
    end
end

local gamesInfo = Instance.new("TextLabel")
gamesInfo.Size = UDim2.new(1, 0, 0, 80)
gamesInfo.Position = UDim2.new(0, 0, 0, 500)
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
    -- a static image replaces any running animation
    local env = getgenv and getgenv() or nil
    if env and env.MM2HubGif then env.MM2HubGif.stop() end
    if env and env.MM2HubBg then env.MM2HubBg.stop() end
    local id = settings.bgId or ""
    bgImage.Image = (id ~= "") and ("rbxassetid://" .. id) or ""
end

-- filled in by the ANIMATED.. box (see BACKGROUND EXTRAS)
local animUI = {}

local applyBgBtn = makeButton(settingsPage, "🖼 APPLY BACKGROUND", 102, COLOR_GOLD)
local resetBgBtn = makeButton(settingsPage, "↺ RESET BACKGROUND", 202, COLOR_DIM)

getgenv().MM2HubClick(applyBgBtn, "MouseButton1Click", function()
    if animUI.box and animUI.box.Text ~= "" and animUI.play then
        animUI.play(animUI.box.Text)
        return
    end
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

getgenv().MM2HubClick(resetBgBtn, "MouseButton1Click", function()
    settings.bgId = ""
    bgBox.Text = ""
    applyBackground()
    saveSettings()
    setStatus("Background reset")
end)

-- ============================
-- BACKGROUND EXTRAS: RANDOM button and the Animated.. box
-- ============================
do
    -- RANDOM picks one of these image/decal asset IDs.
    -- Paste Creator Store decal IDs (the number in the decal's URL) between the braces, separated by commas.
    local RANDOM_BG_IDS = {}

    local animBox = Instance.new("TextBox")
    animBox.Size = UDim2.new(1, 0, 0, 32)
    animBox.Position = UDim2.new(0, 0, 0, 62)
    animBox.BackgroundColor3 = Color3.fromRGB(18, 18, 26)
    animBox.BorderSizePixel = 0
    animBox.Text = ""
    animBox.PlaceholderText = "Animated.."
    animBox.TextColor3 = COLOR_TEXT
    animBox.PlaceholderColor3 = Color3.fromRGB(90, 90, 120)
    animBox.TextScaled = true
    animBox.ClearTextOnFocus = false
    animBox.Font = activeFont
    animBox.ZIndex = 3
    animBox.Parent = settingsPage
    corner(animBox, 6)

    animUI.box = animBox

    animUI.play = function(link)
        local env = getgenv and getgenv() or nil
        if not (env and env.MM2HubGif) then
            setStatus("Animated backgrounds need loader.lua", COLOR_RED)
            return
        end
        setStatus("Loading animated background...", COLOR_GOLD)
        task.spawn(function()
            local ok, msg = env.MM2HubGif.play(bgImage, link, 308, 462)
            if ok then
                setStatus("Animated background on (" .. msg .. ")", COLOR_GREEN)
            else
                setStatus(msg, COLOR_RED)
            end
        end)
    end

    animBox.FocusLost:Connect(function(enterPressed)
        if enterPressed and animBox.Text ~= "" then
            animUI.play(animBox.Text)
        end
    end)

    local randomBtn = makeButton(settingsPage, "🎲 RANDOM", 152, Color3.fromRGB(255, 120, 200))
    getgenv().MM2HubClick(randomBtn, "MouseButton1Click", function()
        if #RANDOM_BG_IDS == 0 then
            setStatus("Add decal IDs to RANDOM_BG_IDS in the script first", COLOR_RED)
            return
        end
        local id = tostring(RANDOM_BG_IDS[math.random(1, #RANDOM_BG_IDS)])
        bgBox.Text = id
        settings.bgId = id
        applyBackground()
        saveSettings()
        setStatus("Random background: " .. id, COLOR_GREEN)
    end)
end

do -- ANIMATED UI toggle
    local animBtn, animStroke = makeButton(settingsPage, "✨ ANIMATED UI", 402, Color3.fromRGB(0, 200, 180))
    setToggleVisual(animStroke, settings.animatedUI == true)
    getgenv().MM2HubClick(animBtn, "MouseButton1Click", function()
        settings.animatedUI = not settings.animatedUI
        setToggleVisual(animStroke, settings.animatedUI)
        saveSettings()
        setStatus(settings.animatedUI and "Animated UI on" or "Animated UI off", COLOR_GREEN)
    end)
    if settingsPage:IsA("ScrollingFrame") then
        settingsPage.CanvasSize = UDim2.new(0, 0, 0, 510)
    end
end

do -- 3D UI toggle: parallax window with a drop shadow and a glossy edge
    local btn3d, stroke3d = makeButton(settingsPage, "🧊 3D UI", 452, Color3.fromRGB(120, 200, 255))
    setToggleVisual(stroke3d, settings.ui3d == true)

    local shadow = Instance.new("Frame")
    shadow.Name = "Shadow3D"
    shadow.BackgroundColor3 = Color3.new(0, 0, 0)
    shadow.BackgroundTransparency = 0.45
    shadow.BorderSizePixel = 0
    shadow.ZIndex = 1
    shadow.Visible = false
    shadow.Parent = rgbBorder
    corner(shadow, 12)

    local gloss = Instance.new("UIStroke")
    gloss.Color = Color3.new(1, 1, 1)
    gloss.Thickness = 2
    gloss.Transparency = 0.6
    gloss.Enabled = false
    gloss.Parent = mainFrame

    getgenv().MM2HubBind(RunService.Heartbeat, function()
        if not settings.ui3d then
            shadow.Visible = false
            gloss.Enabled = false
            mainFrame.Position = UDim2.new(0, 4, 0, 4)
            return
        end
        shadow.Visible = true
        gloss.Enabled = true
        local mouse = UserInputService:GetMouseLocation()
        local half = rgbBorder.AbsoluteSize / 2
        local center = rgbBorder.AbsolutePosition + half
        local dx = math.clamp((mouse.X - center.X) / math.max(1, half.X), -1, 1)
        local dy = math.clamp((mouse.Y - center.Y) / math.max(1, half.Y), -1, 1)
        local ox, oy = -dx * 6, -dy * 6
        mainFrame.Position = UDim2.new(0, 4 + ox, 0, 4 + oy)
        shadow.Position = UDim2.new(0, 4 + ox + 8, 0, 4 + oy + 10)
        shadow.Size = mainFrame.Size
    end)

    getgenv().MM2HubClick(btn3d, "MouseButton1Click", function()
        settings.ui3d = not settings.ui3d
        saveSettings()
        setToggleVisual(stroke3d, settings.ui3d)
        setStatus(settings.ui3d and "3D UI on" or "3D UI off", COLOR_GREEN)
    end)
end

local themeBtn = makeButton(settingsPage, "🎨 THEME", 252, Color3.fromRGB(255, 120, 0))
local fontBtn = makeButton(settingsPage, "🔤 FONT", 302, Color3.fromRGB(180, 80, 255))

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

getgenv().MM2HubClick(themeBtn, "MouseButton1Click", function()
    settings.themeChoice = cycleValue(THEME_ORDER, settings.themeChoice)
    saveSettings()
    applyAll()
end)

getgenv().MM2HubClick(fontBtn, "MouseButton1Click", function()
    settings.fontChoice = cycleValue(FONT_ORDER, settings.fontChoice)
    saveSettings()
    applyAll()
end)

local settingsInfo = Instance.new("TextLabel")
settingsInfo.Size = UDim2.new(1, 0, 0, 40)
settingsInfo.Position = UDim2.new(0, 0, 0, 352)
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
getgenv().MM2HubBind(RunService.Heartbeat, function(dt)
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

-- loading screen: reveal the window once everything is built
if loadingFinish then
    loadingFinish(function()
        rgbBorder.Visible = true
    end)
end

-- ANIMATED BACKGROUND: started only when loader.lua provided the module
do
    local env = getgenv and getgenv()
    if env and env.MM2HubBg then
        task.spawn(function()
            env.MM2HubBg.start(bgImage)
        end)
    end
end

if getgenv().MM2HubNotice then
    setStatus(getgenv().MM2HubNotice, COLOR_GOLD)
    getgenv().MM2HubNotice = nil
end

print("MM2 Helper v3.8 Loaded - tween coins, reach, live Show Both, games, free-look invis")
