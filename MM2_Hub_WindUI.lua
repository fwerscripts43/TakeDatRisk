-- MM2 Hub (WindUI version) 
-- MM2_Hub_WindUI.Lua

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local G = getgenv()

-- generation guard: starting this hub again (or the main hub) stops the old loops
local GEN = (G.MM2HubWindUIGen or 0) + 1
G.MM2HubWindUIGen = GEN
local function alive()
    return G.MM2HubWindUIGen == GEN
end

local WindUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"))()

local COLOR_RED = Color3.fromRGB(220, 30, 60)
local COLOR_BLUE = Color3.fromRGB(30, 120, 255)
local COLOR_GREEN = Color3.fromRGB(80, 220, 120)

local function notify(title, content)
    pcall(function()
        WindUI:Notify({ Title = title, Content = content, Duration = 3, CanClose = true })
    end)
end

---------------------------------------------------------------
-- helpers
---------------------------------------------------------------
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

local function findPlayerByTool(keyword)
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= player and hasToolMatching(plr, keyword) then
            return plr
        end
    end
    return nil
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

---------------------------------------------------------------
-- window
---------------------------------------------------------------
local Window = WindUI:CreateWindow({
    Title = "MM2 Hub | WindUI",
    Folder = "MM2Hub",
    Icon = "solar:folder-2-bold-duotone",
    NewElements = true,
    HideSearchBar = false,
    OpenButton = {
        Title = "Open MM2 Hub",
        CornerRadius = UDim.new(1, 0),
        StrokeThickness = 3,
        Enabled = true,
        Draggable = true,
        OnlyMobile = false,
        Scale = 0.5,
    },
    Topbar = {
        Height = 44,
        ButtonsType = "Mac",
    },
})

---------------------------------------------------------------
-- ESP
---------------------------------------------------------------
local espSection = Window:Section({ Title = "ESP" })
local espTab = espSection:Tab({ Title = "Find", Icon = "solar:check-square-bold" })

espTab:Button({
    Title = "Find Murderer",
    Callback = function()
        clearOutlines()
        local murderer = findPlayerByTool("knife")
        if murderer then
            outlinePlayer(murderer, true, COLOR_RED)
            notify("Murderer", murderer.DisplayName .. " is the murderer")
        else
            notify("Murderer", "No murderer found")
        end
    end,
})

espTab:Button({
    Title = "Find Sheriff",
    Callback = function()
        clearOutlines()
        local sheriff = findPlayerByTool("gun")
        if sheriff then
            outlinePlayer(sheriff, true, COLOR_BLUE)
            notify("Sheriff", sheriff.DisplayName .. " is the sheriff")
        else
            notify("Sheriff", "No sheriff found")
        end
    end,
})

local seeAllOn = false
espTab:Toggle({
    Title = "See All (murderer red, innocent green)",
    Callback = function(value)
        seeAllOn = value and true or false
        clearOutlines()
        if not seeAllOn then return end
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= player and plr.Character then
                if hasToolMatching(plr, "knife") then
                    outlinePlayer(plr, true, COLOR_RED)
                else
                    outlinePlayer(plr, true, COLOR_GREEN)
                end
            end
        end
    end,
})

---------------------------------------------------------------
-- Player
---------------------------------------------------------------
local playerSection = Window:Section({ Title = "Player" })
local playerTab = playerSection:Tab({ Title = "Movement", Icon = "solar:bell-bold" })

local speedOn = false
local speedValue = 16
local baseWalk = setmetatable({}, { __mode = "k" })

local function currentHumanoid()
    local c = player.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

playerTab:Slider({
    Title = "Walk Speed",
    Step = 1,
    Value = { Min = 16, Max = 100, Default = 16 },
    Callback = function(value)
        speedValue = value
    end,
})

playerTab:Toggle({
    Title = "Apply Walk Speed",
    Callback = function(value)
        speedOn = value and true or false
        local h = currentHumanoid()
        if not speedOn and h then
            h.WalkSpeed = baseWalk[h] or 16
        end
    end,
})

local noclipOn = false
local infJumpOn = false

playerTab:Toggle({
    Title = "Noclip",
    Callback = function(value)
        noclipOn = value and true or false
        if not noclipOn and player.Character then
            for _, part in ipairs(player.Character:GetChildren()) do
                if part:IsA("BasePart") then part.CanCollide = true end
            end
        end
    end,
})

playerTab:Toggle({
    Title = "Infinite Jump",
    Callback = function(value)
        infJumpOn = value and true or false
    end,
})

---------------------------------------------------------------
-- Auto Coin
---------------------------------------------------------------
local coinSection = Window:Section({ Title = "Auto Coin" })
local coinTab = coinSection:Tab({ Title = "Coins", Icon = "solar:check-square-bold" })

local coinOn = false
local coinRunning = false
local coinSpeed = 50
local coinFires = 0

local function findRemoteNamed(name)
    for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
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

local function coinLoop()
    local remote = findRemoteNamed("CoinCollected")
    local conn
    if remote then
        conn = remote.OnClientEvent:Connect(function()
            coinFires = coinFires + 1
        end)
    else
        notify("Auto Coin", "CoinCollected remote not found, coins may not count")
    end

    local skipped = {}
    while coinOn and alive() do
        local char = player.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not root or not hum or hum.Health <= 0 then
            task.wait(0.5)
        else
            local candidates = {}
            for _, c in ipairs(getCoins()) do
                if c.Parent and not skipped[c] then
                    table.insert(candidates, c)
                end
            end
            if #candidates == 0 then
                skipped = {}
                task.wait(1)
            else
                table.sort(candidates, function(a, b)
                    return (a.Position - root.Position).Magnitude < (b.Position - root.Position).Magnitude
                end)
                local coin = candidates[1]
                local dist = (coin.Position - root.Position).Magnitude
                local duration = math.max(0.05, dist / coinSpeed)
                local before = coinFires

                local tween = TweenService:Create(root, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
                    CFrame = CFrame.new(coin.Position + Vector3.new(0, 3, 0)),
                })
                tween:Play()
                task.wait(duration)
                tween:Cancel()

                if remote then
                    local waited = 0
                    while coinFires == before and waited < 2 and coin.Parent and coinOn and alive() do
                        task.wait(0.1)
                        waited = waited + 0.1
                    end
                    if coinFires == before then
                        skipped[coin] = true
                    end
                elseif coin.Parent then
                    skipped[coin] = true
                end
                task.wait(0.2)
            end
        end
    end

    if conn then conn:Disconnect() end
    coinRunning = false
end

coinTab:Slider({
    Title = "Coin Speed (studs/sec)",
    Step = 5,
    Value = { Min = 20, Max = 200, Default = 50 },
    Callback = function(value)
        coinSpeed = value
    end,
})

coinTab:Toggle({
    Title = "Auto Coin",
    Callback = function(value)
        coinOn = value and true or false
        if coinOn and not coinRunning then
            coinRunning = true
            task.spawn(coinLoop)
        end
    end,
})

---------------------------------------------------------------
-- Heartbeat: keep walk speed, noclip, and infinite jump applied
---------------------------------------------------------------
local heartbeat = RunService.Heartbeat:Connect(function()
    if not alive() then return end
    local h = currentHumanoid()
    if h then
        if baseWalk[h] == nil then baseWalk[h] = h.WalkSpeed end
        if speedOn and h.WalkSpeed ~= speedValue then h.WalkSpeed = speedValue end
    end
    if noclipOn and player.Character then
        for _, part in ipairs(player.Character:GetChildren()) do
            if part:IsA("BasePart") then part.CanCollide = false end
        end
    end
end)

local jumpConn = UserInputService.JumpRequest:Connect(function()
    if not alive() or not infJumpOn then return end
    local h = currentHumanoid()
    if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
end)

---------------------------------------------------------------
-- close / cleanup (also called when the main hub is refreshed or switched)
---------------------------------------------------------------
local function cleanup()
    coinOn = false
    speedOn = false
    noclipOn = false
    infJumpOn = false
    seeAllOn = false
    clearOutlines()
    local h = currentHumanoid()
    if h and baseWalk[h] then h.WalkSpeed = baseWalk[h] end
    if heartbeat then heartbeat:Disconnect() end
    if jumpConn then jumpConn:Disconnect() end
    G.MM2HubWindUIGen = (G.MM2HubWindUIGen or 0) + 1
end

G.MM2HubWindUIClose = function()
    cleanup()
    pcall(function() Window:Destroy() end)
    G.MM2HubWindUIClose = nil
end

local aboutSection = Window:Section({ Title = "About" })
local aboutTab = aboutSection:Tab({ Title = "Hub", Icon = "solar:bell-bold" })
aboutTab:Button({
    Title = "Close Hub",
    Callback = function()
        if G.MM2HubWindUIClose then G.MM2HubWindUIClose() end
    end,
})

notify("MM2 Hub", "WindUI hub loaded")
