-- MM2 Hub (WindUI version)
-- Opened from the UI tab of MM2 Helper. Same features as the main hub, built with WindUI.
-- Visual-only main-hub settings (themes, fonts, background image, animated border,
-- seasonal decorations, resize) are not ported: WindUI has its own styling.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")

local player = Players.LocalPlayer
local G = getgenv()

-- generation guard: every loop checks alive(), so a cleanup or a new run stops old loops
local GEN = (G.MM2HubWindUIGen or 0) + 1
G.MM2HubWindUIGen = GEN
local function alive()
    return G.MM2HubWindUIGen == GEN
end

local WindUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"))()

local COLOR_RED = Color3.fromRGB(220, 30, 60)
local COLOR_BLUE = Color3.fromRGB(30, 120, 255)
local COLOR_GREEN = Color3.fromRGB(80, 220, 120)
local COLOR_GOLD = Color3.fromRGB(255, 215, 0)
local COLOR_PURPLE = Color3.fromRGB(180, 80, 255)

-- restore functions run by cleanup() when the hub closes
local cleanups = {}
local function onCleanup(fn)
    table.insert(cleanups, fn)
end

local function notify(title, content)
    pcall(function()
        WindUI:Notify({ Title = title, Content = content, Duration = 3, CanClose = true })
    end)
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

-- PART 1: ROUND WATCH, ESP, COMBAT (aim, shoot, murd win, reach, sheriff hitbox, grab gun)
do
local camera = workspace.CurrentCamera
local playerGui = player:WaitForChild("PlayerGui")

local BULLET_SPEED = 250 -- assumed bullet speed (studs/sec) used for aim prediction
local AIM_RANGE = 90 -- max distance for a shot (main hub default)
local AIM_BIND = "MM2HubWindUIAutoAim"
local SHOOT_MIN, SHOOT_MAX = 40, 300
local REACH_MIN, REACH_MAX = 4, 30
local HITBOX = 14
local COLOR_DIM = Color3.fromRGB(120, 120, 150)
local COLOR_LIGHT = Color3.fromRGB(230, 230, 230)

-- connections made by this part; all disconnected in cleanup
local conns = {}
local function track(conn)
    table.insert(conns, conn)
    return conn
end
onCleanup(function()
    for _, c in ipairs(conns) do
        pcall(function() c:Disconnect() end)
    end
    conns = {}
end)

local function addCorner(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = radius
    c.Parent = parent
end

-- values the sliders and toggles start from
local cfg = { aimMode = "REGULAR", shootRing = 110, shootAim = 100, reachSize = 10 }

-- ============================
-- ROUND WATCH
-- LoadingMap says the gamemode, KillEvent says who died.
-- State is on G.MM2HubWindUIState: killed (set of Players), infection (bool), zombies() (function).
-- Only ReplicatedStorage is scanned: walking the whole game on load causes the lag spike.
-- ============================
local RS = { killed = {}, infection = false }
G.MM2HubWindUIState = RS

local function toPlayer(v)
    if typeof(v) ~= "Instance" then return nil end
    if v:IsA("Player") then return v end
    return Players:GetPlayerFromCharacter(v)
end

local function hookKill(remote)
    if remote:IsA("RemoteEvent") then
        track(remote.OnClientEvent:Connect(function(...)
            for _, arg in ipairs({ ... }) do
                local p = toPlayer(arg)
                if p then RS.killed[p] = true end
            end
        end))
    end
end

local function hookLoading(remote)
    if remote:IsA("RemoteEvent") then
        track(remote.OnClientEvent:Connect(function(mode)
            table.clear(RS.killed) -- a new map means a new round
            local text = string.lower(tostring(mode or ""))
            RS.infection = string.find(text, "infection", 1, true) ~= nil
            if RS.infection then
                notify("Infection mode", "Everyone with a knife is a ZOMBIE")
            end
        end))
    end
end

local function scanRound(obj)
    if obj.Name == "KillEvent" then hookKill(obj) end
    if obj.Name == "LoadingMap" then hookLoading(obj) end
end

for _, d in ipairs(ReplicatedStorage:GetDescendants()) do
    scanRound(d)
end
track(ReplicatedStorage.DescendantAdded:Connect(scanRound))

-- ZOMBIES (Infection): anyone holding a knife. Empty unless the map is Infection.
RS.zombies = function()
    local list = {}
    if not RS.infection then return list end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= player and hasToolMatching(plr, "knife") then
            table.insert(list, plr)
        end
    end
    return list
end

local function findMurderer()
    return findPlayerByTool("knife", true)
end

local function findSheriff()
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

local function clearBillboards()
    for _, plr in ipairs(Players:GetPlayers()) do
        local bb = plr.Character and plr.Character:FindFirstChild("MM2_RoleLabel")
        if bb then bb:Destroy() end
    end
end
onCleanup(clearBillboards)
onCleanup(clearOutlines)

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
    addCorner(bg, UDim.new(0, 6))

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
    lbl.Font = Enum.Font.GothamBold
    lbl.Parent = bg
end

-- ============================
-- ESP
-- ============================
local espSection = Window:Section({ Title = "ESP" })
local espTab = espSection:Tab({ Title = "ESP", Icon = "solar:check-square-bold" })

espTab:Button({
    Title = "FIND MURDERER",
    Callback = function()
        clearOutlines()
        local zombies = RS.zombies()
        if #zombies > 0 then
            clearBillboards()
            for _, z in ipairs(zombies) do
                outlinePlayer(z, true, COLOR_GREEN)
                addBillboard(z, "🧟 ZOMBIE", COLOR_GREEN)
            end
            notify("Find murderer", #zombies .. " ZOMBIE(s) (Infection)")
            return
        end
        local murderer = findMurderer()
        if murderer then
            outlinePlayer(murderer, true, COLOR_RED)
            notify("Find murderer", murderer.DisplayName .. " is the MURDERER")
        else
            notify("Find murderer", "No murderer found.")
        end
    end,
})

espTab:Button({
    Title = "FIND SHERIFF",
    Callback = function()
        clearOutlines()
        local sheriff = findSheriff()
        if sheriff then
            outlinePlayer(sheriff, true, COLOR_BLUE)
            notify("Find sheriff", sheriff.DisplayName .. " is the SHERIFF")
        else
            notify("Find sheriff", "No sheriff found.")
        end
    end,
})

-- VIEW BOTH: keeps itself up to date. Redraws when the murderer, sheriff or zombies change.
local viewBothOn = false
local viewBothGen = 0
local lastMurd, lastSheriff = nil, nil
local lastZombies = {}

local function sameList(a, b)
    if #a ~= #b then return false end
    for i, v in ipairs(a) do
        if v ~= b[i] then return false end
    end
    return true
end

local function refreshViewBoth(force)
    local murderer = findMurderer()
    local sheriff = findSheriff()
    local zombies = RS.zombies()
    local zombiesChanged = not sameList(zombies, lastZombies)
    lastZombies = zombies

    local needsRedraw = force
        or zombiesChanged
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
    for _, z in ipairs(zombies) do
        outlinePlayer(z, true, COLOR_GREEN)
        addBillboard(z, "🧟 ZOMBIE", COLOR_GREEN)
        table.insert(lines, "🧟 " .. z.DisplayName .. " = ZOMBIE")
    end
    notify("View both", table.concat(lines, "\n"))
end

espTab:Toggle({
    Title = "VIEW BOTH",
    Callback = function(value)
        if value == viewBothOn then return end
        viewBothOn = value
        viewBothGen = viewBothGen + 1
        local gen = viewBothGen
        if not viewBothOn then
            clearOutlines()
            clearBillboards()
            lastMurd, lastSheriff = nil, nil
            notify("View both", "View Both OFF")
            return
        end
        lastMurd, lastSheriff = nil, nil
        refreshViewBoth(true)
        task.spawn(function()
            while viewBothOn and gen == viewBothGen and alive() do
                task.wait(0.5)
                pcall(refreshViewBoth, false)
            end
        end)
    end,
})

-- SEE ALL: highlights every other player once (red = has a knife, green = everyone else)
local seeAllOn = false
espTab:Toggle({
    Title = "SEE ALL",
    Callback = function(value)
        if value == seeAllOn then return end
        seeAllOn = value
        clearOutlines()
        if not seeAllOn then
            notify("See all", "SEE ALL OFF")
            return
        end
        local murderers, innocents = 0, 0
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= player and plr.Character then
                if hasToolMatching(plr, "knife") then
                    outlinePlayer(plr, true, COLOR_RED)
                    murderers = murderers + 1
                else
                    outlinePlayer(plr, true, COLOR_GREEN)
                    innocents = innocents + 1
                end
            end
        end
        notify("See all", "Highlighted " .. innocents .. " innocent, " .. murderers .. " murderer")
    end,
})

-- TRACERS: a beam from you to every other living player, colored by role
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
    return COLOR_LIGHT
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
    while alive() do
        task.wait(0.2)
        if tracersOn then
            pcall(refreshTracers)
        end
    end
end)

espTab:Toggle({
    Title = "TRACERS",
    Callback = function(value)
        if value == tracersOn then return end
        tracersOn = value
        if tracersOn then
            pcall(refreshTracers)
            notify("Tracers", "Tracers ON")
        else
            clearAllTracers()
            notify("Tracers", "Tracers OFF")
        end
    end,
})
onCleanup(function()
    tracersOn = false
    clearAllTracers()
end)

-- ============================
-- COMBAT: shared shot helpers
-- ============================
local combatSection = Window:Section({ Title = "Combat" })

local BULLET_REMOTE_CACHE = nil

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
        if not BULLET_REMOTE_CACHE then
            BULLET_REMOTE_CACHE = findGunFiredRemote()
        end
        if BULLET_REMOTE_CACHE then
            pcall(function()
                BULLET_REMOTE_CACHE:FireServer(pos)
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
    if offset.Magnitude > AIM_RANGE then return false end
    if tPos.Y < myRoot.Position.Y - 6 then return false end -- underground / far below you
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { myChar, tChar }
    return workspace:Raycast(origin, offset, params) == nil
end

-- ============================
-- COMBAT / AIM
-- Locks the camera onto the target every frame. While you hold the Gun it fires about
-- every 0.15s through the Shoot remote (or KnifeLocal / GunFired if that is missing).
-- ============================
local aimTab = combatSection:Tab({ Title = "Aim", Icon = "solar:check-square-bold" })

local aimEnabled = false
local aimBound = false
local aimShotTimer = 0
local target = nil
local targetIndex = 0

local function aimStep(dt)
    if not aimEnabled then return end
    if cfg.aimMode == "MURD" then
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
        if aimBound then
            pcall(function() RunService:UnbindFromRenderStep(AIM_BIND) end)
            aimBound = false
        end
        notify("Auto aim", "Target down, auto aim stopped")
        return
    end

    -- predict where the target will be when the shot arrives (velocity * travel time)
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
        pcall(function() RunService:UnbindFromRenderStep(AIM_BIND) end)
        aimBound = false
    end
end

onCleanup(function()
    aimEnabled = false
    target = nil
    setAimBound(false)
end)

aimTab:Toggle({
    Title = "AUTO AIM",
    Callback = function(value)
        if value == aimEnabled then return end
        aimEnabled = value
        if aimEnabled then
            setAimBound(true)
            if target then
                notify("Auto aim", "Locked on " .. target.DisplayName)
            else
                notify("Auto aim", "Aim on, pick a target first")
            end
        else
            target = nil
            setAimBound(false)
            notify("Auto aim", "AUTO AIM OFF")
        end
    end,
})

-- The main hub uses a scrolling player list. WindUI has no list element, so this button
-- steps through the other players instead.
aimTab:Button({
    Title = "NEXT TARGET",
    Callback = function()
        local others = {}
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= player then table.insert(others, plr) end
        end
        if #others == 0 then
            notify("Aim target", "No other players")
            return
        end
        targetIndex = targetIndex % #others + 1
        target = others[targetIndex]
        notify("Aim target", "Targeting: " .. target.DisplayName)
    end,
})

aimTab:Button({
    Title = "CLEAR TARGET",
    Callback = function()
        target = nil
        notify("Aim target", "Target cleared")
    end,
})

aimTab:Button({
    Title = "MODE: REGULAR (pick a target)",
    Callback = function()
        cfg.aimMode = "REGULAR"
        notify("Aim mode", "REGULAR (pick a target)")
    end,
})

aimTab:Button({
    Title = "MODE: AUTO AIM MURD (locks the knife holder)",
    Callback = function()
        cfg.aimMode = "MURD"
        notify("Aim mode", "AUTO AIM MURD (locks the knife holder)")
    end,
})

-- ============================
-- COMBAT / SHOOT
-- A ring around the cursor (screen center when the mouse is locked). When the murderer is
-- inside the ring, in clear line of sight, it fires at their predicted head position.
-- ============================
local shootTab = combatSection:Tab({ Title = "Shoot", Icon = "solar:bell-bold" })

local shootOn = false
local shootLoopRunning = false
local circleHidden = false
local ringGui, ringFrame, ringStroke = nil, nil, nil

local function destroyRing()
    if ringGui then
        pcall(function() ringGui:Destroy() end)
    end
    ringGui, ringFrame, ringStroke = nil, nil, nil
end

local function createRing()
    destroyRing()
    local g = Instance.new("ScreenGui")
    g.Name = "MM2Hub_WindUIRing"
    g.ResetOnSpawn = false
    g.IgnoreGuiInset = true
    g.DisplayOrder = 60
    g.Enabled = not circleHidden
    g.Parent = playerGui

    local ring = Instance.new("Frame")
    ring.Name = "Ring"
    ring.AnchorPoint = Vector2.new(0.5, 0.5)
    ring.Size = UDim2.fromOffset(cfg.shootRing * 2, cfg.shootRing * 2)
    ring.BackgroundTransparency = 1
    ring.Parent = g
    addCorner(ring, UDim.new(1, 0))

    local stroke = Instance.new("UIStroke")
    stroke.Color = COLOR_RED
    stroke.Thickness = 2
    stroke.Parent = ring

    ringGui, ringFrame, ringStroke = g, ring, stroke
end

onCleanup(destroyRing)

local function autoShootStep(canFire)
    local center = UserInputService:GetMouseLocation()
    if ringFrame then
        ringFrame.Position = UDim2.fromOffset(center.X, center.Y)
    end

    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root or not hasLocalGun() then
        if ringStroke then ringStroke.Color = COLOR_DIM end
        return
    end

    local murderer = findMurderer()
    local tChar = murderer and murderer.Character
    local tRoot = tChar and tChar:FindFirstChild("HumanoidRootPart")
    local head = tChar and tChar:FindFirstChild("Head")
    if not tRoot or not head or isDead(murderer) then
        if ringStroke then ringStroke.Color = COLOR_DIM end
        return
    end

    local screenPos = camera:WorldToViewportPoint(head.Position)
    local radius = cfg.shootRing
    local inside = screenPos.Z > 0 and (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude <= radius
    if ringStroke then
        ringStroke.Color = inside and COLOR_GREEN or COLOR_RED
    end
    if not inside or not clearShotAt(tChar, head.Position) then return end

    if canFire then
        local dist = (head.Position - camera.CFrame.Position).Magnitude
        local aim = math.clamp(cfg.shootAim / 100, 0, 1)
        local lead = 0.5 + 0.5 * aim -- WEAK leads only half the way, STRONG the full way
        local spread = (1 - aim) * 3 -- WEAK adds a few studs of random miss, STRONG has none
        local predicted = head.Position + tRoot.AssemblyLinearVelocity * (dist / BULLET_SPEED) * lead
        if spread > 0 then
            predicted = predicted + Vector3.new(math.random() * 2 - 1, math.random() * 2 - 1, math.random() * 2 - 1) * spread
        end
        aimFire(predicted)
    end
end

local function startShootLoop()
    if shootLoopRunning then return end
    shootLoopRunning = true
    task.spawn(function()
        local shotTimer = 0
        while shootOn and alive() do
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

onCleanup(function()
    shootOn = false
end)

shootTab:Toggle({
    Title = "AUTO SHOOT",
    Callback = function(value)
        if value == shootOn then return end
        if value then
            if not hasLocalGun() then
                notify("Auto shoot", "You need the Gun tool to use Auto Shoot.")
                return
            end
            shootOn = true
            createRing()
            notify("Auto shoot", "AUTO SHOOT ON: get the murderer inside the ring")
            startShootLoop()
        else
            shootOn = false
            destroyRing()
            notify("Auto shoot", "AUTO SHOOT OFF")
        end
    end,
})

shootTab:Toggle({
    Title = "HIDE CIRCLE",
    Callback = function(value)
        if value == circleHidden then return end
        circleHidden = value
        if ringGui then
            ringGui.Enabled = not circleHidden
        end
    end,
})

shootTab:Slider({
    Title = "CIRCLE SIZE (px)",
    Step = 1,
    Value = { Min = SHOOT_MIN, Max = SHOOT_MAX, Default = cfg.shootRing },
    Callback = function(value)
        local v = math.clamp(math.floor((tonumber(value) or cfg.shootRing) + 0.5), SHOOT_MIN, SHOOT_MAX)
        if v == cfg.shootRing then return end
        cfg.shootRing = v
        if ringFrame then
            ringFrame.Size = UDim2.fromOffset(v * 2, v * 2)
        end
    end,
})

shootTab:Slider({
    Title = "AIM (0 = weak, 100 = strong)",
    Step = 1,
    Value = { Min = 0, Max = 100, Default = cfg.shootAim },
    Callback = function(value)
        cfg.shootAim = math.clamp(math.floor((tonumber(value) or cfg.shootAim) + 0.5), 0, 100)
    end,
})

-- ============================
-- COMBAT / MURDER
-- ============================
local murderTab = combatSection:Tab({ Title = "Murder", Icon = "shredder" })

-- AUTO MURD WIN: teleports next to each living player and swings the knife
local murdWinOn = false
local murdWinRunning = false

local function startMurdWin()
    if murdWinRunning then return end
    murdWinRunning = true
    task.spawn(function()
        local ok, err = pcall(function()
            local warnedNoKnife = false
            while murdWinOn and alive() do
                task.wait(0.1)
                local char = player.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                if hrp and hum then
                    local knife = findOwnTool("knife")
                    if not knife then
                        if not warnedNoKnife then
                            notify("Murd win", "No knife detected bruh, get out")
                            warnedNoKnife = true
                        end
                        task.wait(2)
                    else
                        warnedNoKnife = false
                        if knife.Parent ~= char then
                            hum:EquipTool(knife)
                        end
                        for _, plr in ipairs(Players:GetPlayers()) do
                            if not murdWinOn or not alive() then break end
                            local tHRP = plr ~= player and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
                            if tHRP and not isDead(plr) and not RS.killed[plr] then
                                hrp.CFrame = CFrame.new(tHRP.Position + Vector3.new(math.random(-3, 3), 0, math.random(-3, 3)))
                                pcall(function() knife:Activate() end)
                                task.wait(0.12)
                                if isDead(plr) then RS.killed[plr] = true end
                            end
                        end
                    end
                end
            end
        end)
        murdWinRunning = false
        if not ok then warn("[MM2 MurdWin] " .. tostring(err)) end
    end)
end

onCleanup(function()
    murdWinOn = false
end)

murderTab:Toggle({
    Title = "AUTO MURD WIN",
    Callback = function(value)
        if value == murdWinOn then return end
        murdWinOn = value
        if murdWinOn then
            notify("Murd win", "AUTO MURD WIN ACTIVE")
            startMurdWin()
        else
            notify("Murd win", "AUTO MURD WIN OFF")
        end
    end,
})

-- MURDER REACH: enlarges other players' HumanoidRootPart and turns off their part collisions
-- so you walk through the big hitbox. Client-side only; the server still decides hits.
local reachOn = false
local reachRunning = false
local reachOriginal = {} -- [Player] = { hrp, size, transparency, collide = {[part] = canCollide} }

local function reachVector()
    return Vector3.new(cfg.reachSize, cfg.reachSize, cfg.reachSize)
end

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

local function restoreAllReach()
    for _, plr in ipairs(Players:GetPlayers()) do
        pcall(setReach, plr, false)
    end
end

local function startReachLoop()
    if reachRunning then return end
    reachRunning = true
    task.spawn(function()
        while reachOn and alive() do
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= player then
                    pcall(setReach, plr, true)
                end
            end
            task.wait(0.5)
        end
        restoreAllReach()
        reachRunning = false
    end)
end

onCleanup(function()
    reachOn = false
    restoreAllReach()
end)

murderTab:Toggle({
    Title = "MURDER REACH",
    Callback = function(value)
        if value == reachOn then return end
        reachOn = value
        if reachOn then
            notify("Murder reach", "MURDER REACH ON")
            startReachLoop()
        else
            notify("Murder reach", "MURDER REACH OFF")
        end
    end,
})

murderTab:Slider({
    Title = "HITBOX SIZE (studs)",
    Step = 1,
    Value = { Min = REACH_MIN, Max = REACH_MAX, Default = cfg.reachSize },
    Callback = function(value)
        -- the reach loop re-applies the size within 0.5s
        cfg.reachSize = math.clamp(math.floor((tonumber(value) or cfg.reachSize) + 0.5), REACH_MIN, REACH_MAX)
    end,
})

-- SHERIFF HITBOX EXPANDER: makes the murderer's hitbox bigger on your client.
-- (The server decides hits, so the gun's own beam hitbox can't be changed from here.)
local hbOn = false
local hbAcc = 0
local hbOriginals = setmetatable({}, { __mode = "k" }) -- HRP -> original values

local function restoreHitboxes()
    for hrp, o in pairs(hbOriginals) do
        if hrp.Parent then
            hrp.Size = o.size
            hrp.CanCollide = o.canCollide
        end
        hbOriginals[hrp] = nil
    end
end

track(RunService.Heartbeat:Connect(function(dt)
    if not hbOn then return end
    hbAcc = hbAcc + dt
    if hbAcc < 0.5 then return end
    hbAcc = 0
    restoreHitboxes()
    local m = findMurderer()
    local hrp = m and m.Character and m.Character:FindFirstChild("HumanoidRootPart")
    if hrp then
        hbOriginals[hrp] = { size = hrp.Size, canCollide = hrp.CanCollide }
        hrp.Size = Vector3.new(HITBOX, HITBOX, HITBOX)
        hrp.CanCollide = false
    end
end))

onCleanup(function()
    hbOn = false
    restoreHitboxes()
end)

murderTab:Toggle({
    Title = "SHERIFF HITBOX EXPANDER",
    Callback = function(value)
        if value == hbOn then return end
        hbOn = value
        if hbOn then
            notify("Hitbox expander", "Sheriff hitbox expander ON")
        else
            restoreHitboxes()
            notify("Hitbox expander", "Sheriff hitbox expander OFF")
        end
    end,
})

-- ============================
-- COMBAT / GUN
-- ============================
local gunTab = combatSection:Tab({ Title = "Gun", Icon = "solar:folder-2-bold-duotone" })

-- AUTO GRAB GUN: with no gun, finds the "GunDrop" part in a model in workspace, teleports
-- onto it for two physics steps to pick it up, then teleports you back
local autoGunOn = false
local autoGunRunning = false

local function findGunDrop()
    for _, m in ipairs(workspace:GetChildren()) do
        if m:IsA("Model") then
            local part = m:FindFirstChild("GunDrop", true)
            if part and part:IsA("BasePart") then
                return part
            end
        end
    end
    return nil
end

local function startAutoGun()
    if autoGunRunning then return end
    autoGunRunning = true
    task.spawn(function()
        local ok, err = pcall(function()
            while autoGunOn and alive() do
                task.wait(0.25)
                if not hasLocalGun() then
                    local drop = findGunDrop()
                    local char = player.Character
                    local hrp = char and char:FindFirstChild("HumanoidRootPart")
                    if drop and hrp then
                        local backCF = hrp.CFrame
                        hrp.CFrame = drop.CFrame + Vector3.new(0, 3, 0)
                        hrp.AssemblyLinearVelocity = Vector3.zero
                        -- wait two physics steps so the touch on the gun registers, then snap back
                        RunService.Heartbeat:Wait()
                        RunService.Heartbeat:Wait()
                        local nowChar = player.Character
                        local nowHrp = nowChar and nowChar:FindFirstChild("HumanoidRootPart")
                        if nowHrp then
                            nowHrp.CFrame = backCF
                            nowHrp.AssemblyLinearVelocity = Vector3.zero
                        end
                        task.wait(0.5) -- short pause so the pickup can finish before retrying
                    end
                end
            end
        end)
        autoGunRunning = false
        if not ok then warn("[MM2 AutoGun] " .. tostring(err)) end
    end)
end

onCleanup(function()
    autoGunOn = false
end)

gunTab:Toggle({
    Title = "AUTO GRAB GUN",
    Callback = function(value)
        if value == autoGunOn then return end
        autoGunOn = value
        if autoGunOn then
            notify("Auto grab gun", "AUTO GRAB GUN ON")
            startAutoGun()
        else
            notify("Auto grab gun", "AUTO GRAB GUN OFF")
        end
    end,
})

end -- PART 1


-- PART 2: PLAYER (speed, noclip / inf jump, invis, no anim, optimizer) and AUTO COIN
-- Logic ported from MM2_Helper.lua. Controls are WindUI sections, tabs, sliders, toggles and buttons.
do
    local INVIS_DEPTH = 500 -- studs the character sinks below the surface while invisible
    local COIN_SPEED = 50   -- default studs per second for Auto Coin
    local COIN_TIMEOUT = 2  -- seconds to wait for CoinCollected after arriving
    local SPEED_MIN, SPEED_MAX = 16, 200
    local COIN_MIN, COIN_MAX = 20, 200
    local camera = workspace.CurrentCamera

    -- every connection made in this block; disconnected first when the hub cleans up
    local conns = {}
    local function track(conn)
        table.insert(conns, conn)
        return conn
    end

    local playerSection = Window:Section({ Title = "Player" })
    local movementTab = playerSection:Tab({ Title = "Movement", Icon = "solar:bell-bold" })
    local characterTab = playerSection:Tab({ Title = "Character", Icon = "solar:folder-2-bold-duotone" })

    -- ========== SPEED ==========
    -- The slider sets the value. "Apply speed" keeps it on (also after respawn).
    -- "Reset speed" restores the original WalkSpeed.
    local speedOn = false
    local speedValue = 16
    local baseWalk = setmetatable({}, { __mode = "k" }) -- humanoid -> original WalkSpeed

    local function currentHumanoid()
        local c = player.Character
        return c and c:FindFirstChildOfClass("Humanoid")
    end

    -- remember each humanoid's original speed, and keep the chosen speed applied
    track(RunService.Heartbeat:Connect(function()
        local h = currentHumanoid()
        if not h then return end
        if baseWalk[h] == nil then
            baseWalk[h] = h.WalkSpeed
        end
        if speedOn and h.WalkSpeed ~= speedValue then
            h.WalkSpeed = speedValue
        end
    end))

    onCleanup(function()
        if speedOn then
            speedOn = false
            local h = currentHumanoid()
            if h then
                h.WalkSpeed = baseWalk[h] or 16
            end
        end
    end)

    movementTab:Slider({
        Title = "Speed",
        Step = 1,
        Value = { Min = SPEED_MIN, Max = SPEED_MAX, Default = 16 },
        Callback = function(value)
            speedValue = math.clamp(math.floor((tonumber(value) or speedValue) + 0.5), SPEED_MIN, SPEED_MAX)
        end,
    })
    movementTab:Button({
        Title = "Apply speed",
        Callback = function()
            speedOn = true
            notify("Speed", "Speed set to " .. speedValue)
        end,
    })
    movementTab:Button({
        Title = "Reset speed",
        Callback = function()
            speedOn = false
            local h = currentHumanoid()
            local original = (h and baseWalk[h]) or 16
            if h then
                h.WalkSpeed = original
            end
            notify("Speed", "Speed reset to " .. original)
        end,
    })

    -- ========== NOCLIP / INF JUMP ==========
    -- one flag drives both, as in the main hub
    local noclipOn = false

    local function setCollisionForChar(char, canCollide)
        if not char then return end
        for _, part in ipairs(char:GetChildren()) do
            if part:IsA("BasePart") then
                part.CanCollide = canCollide
            end
        end
    end

    track(RunService.Stepped:Connect(function()
        if noclipOn then
            setCollisionForChar(player.Character, false)
        end
    end))

    track(UserInputService.JumpRequest:Connect(function()
        if noclipOn then
            local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
            if humanoid then
                humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
            end
        end
    end))

    onCleanup(function()
        if noclipOn then
            noclipOn = false
            setCollisionForChar(player.Character, true)
        end
    end)

    movementTab:Toggle({
        Title = "Noclip & Inf Jump",
        Callback = function(value)
            if value == noclipOn then return end
            noclipOn = value
            if noclipOn then
                setCollisionForChar(player.Character, false)
                notify("Noclip & Inf Jump", "ON")
            else
                setCollisionForChar(player.Character, true)
                notify("Noclip & Inf Jump", "OFF")
            end
        end,
    })

    -- ========== INVIS (camera can be moved with the mouse while invisible) ==========
    local invisActive = false
    local invisSurface = nil
    local invisCamCF = nil
    local invisSinking = false
    local invisRising = false
    local wasInvisBeforeRespawn = false
    local invisYaw, invisPitch = 0, 0
    local invisTween = nil
    local invisOffset = nil -- { hum = humanoid, v = original CameraOffset }

    local function forceNoclipChar(char)
        for _, p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") then
                p.CanCollide = false
            end
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
        if not invisOffset or invisOffset.hum ~= humanoid then
            invisOffset = { hum = humanoid, v = humanoid.CameraOffset }
        end
        humanoid.CameraOffset = Vector3.new(0, 0, 0)
        forceNoclipChar(char)
        invisSinking = true

        local targetCF = CFrame.new(hrp.Position.X, hrp.Position.Y - INVIS_DEPTH, hrp.Position.Z) * (hrp.CFrame - hrp.CFrame.Position)
        local sinkTween = TweenService:Create(hrp, TweenInfo.new(0.7, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { CFrame = targetCF })
        invisTween = sinkTween
        sinkTween:Play()
        track(sinkTween.Completed:Connect(function()
            invisSinking = false
            if invisActive then
                humanoid.PlatformStand = false
            end
        end))
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
        invisTween = riseTween
        riseTween:Play()
        track(riseTween.Completed:Connect(function()
            invisRising = false
            invisCamCF = nil
            invisSurface = nil
            if humanoid then
                humanoid.PlatformStand = false
            end
            task.wait(0.2)
            if alive() and char and char.Parent then
                restoreCollision(char)
                camera.CameraType = Enum.CameraType.Custom
            end
        end))
    end

    local function setInvis(on)
        if on == invisActive then return end
        invisActive = on
        local char = player.Character
        if on then
            local rx, ry = camera.CFrame:ToOrientation()
            invisPitch = math.clamp(rx, -1.3, 1.3)
            invisYaw = ry
            wasInvisBeforeRespawn = true
            notify("Invis", "Under map. Walk normally, move mouse to look.")
            applyInvis(char)
        else
            wasInvisBeforeRespawn = false
            notify("Invis", "Surfacing...")
            removeInvis(char)
        end
    end

    track(UserInputService.InputChanged:Connect(function(input)
        if invisActive and not invisSinking and not invisRising and input.UserInputType == Enum.UserInputType.MouseMovement then
            invisYaw = invisYaw - input.Delta.X * 0.004
            invisPitch = math.clamp(invisPitch - input.Delta.Y * 0.004, -1.3, 1.3)
        end
    end))

    track(player.CharacterAdded:Connect(function(char)
        if wasInvisBeforeRespawn and invisActive then
            task.wait(0.5)
            if alive() then
                applyInvis(char)
            end
        elseif not wasInvisBeforeRespawn then
            invisActive = false
        end
    end))

    track(RunService.RenderStepped:Connect(function()
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
    end))

    track(RunService.Stepped:Connect(function(_, dt)
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
    end))

    onCleanup(function()
        local wasActive = invisActive or invisSinking or invisRising
        invisActive = false
        invisSinking = false
        invisRising = false
        wasInvisBeforeRespawn = false
        if invisTween then
            pcall(function() invisTween:Cancel() end)
            invisTween = nil
        end
        if wasActive then
            local char = player.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if hrp and invisSurface then
                -- bring the character back up to the surface it was on before going invisible
                hrp.CFrame = CFrame.new(hrp.Position.X, invisSurface, hrp.Position.Z) * (hrp.CFrame - hrp.CFrame.Position)
            end
            if hum then
                hum.PlatformStand = false
            end
            if char then
                restoreCollision(char)
            end
            camera.CameraType = Enum.CameraType.Custom
        end
        if invisOffset then
            pcall(function() invisOffset.hum.CameraOffset = invisOffset.v end)
            invisOffset = nil
        end
        invisSurface = nil
        invisCamCF = nil
    end)

    movementTab:Toggle({
        Title = "Invis",
        Callback = function(value)
            setInvis(value == true)
        end,
    })

    -- ========== NO ANIM ==========
    -- stops every animation on the character and keeps the Motors stiff
    local noAnimOn = false

    local function setAnimateDisabled(char, value)
        local animate = char and char:FindFirstChild("Animate")
        if animate and animate:IsA("LocalScript") then
            animate.Disabled = value
        end
    end

    track(RunService.Heartbeat:Connect(function()
        if not noAnimOn then return end
        local char = player.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local animator = hum and hum:FindFirstChildOfClass("Animator")
        if animator then
            for _, animTrack in ipairs(animator:GetPlayingAnimationTracks()) do
                animTrack:Stop(0)
            end
        end
        setAnimateDisabled(char, true)
        if char then
            for _, m in ipairs(char:GetDescendants()) do
                if m:IsA("Motor6D") then
                    m.Transform = CFrame.new() -- stiff: no pose offset from any animation
                end
            end
        end
    end))

    onCleanup(function()
        if noAnimOn then
            noAnimOn = false
            setAnimateDisabled(player.Character, false)
        end
    end)

    characterTab:Toggle({
        Title = "No Anim",
        Callback = function(value)
            if value == noAnimOn then return end
            noAnimOn = value
            if not noAnimOn then
                setAnimateDisabled(player.Character, false)
            end
            notify("No Anim", noAnimOn and "ON" or "OFF")
        end,
    })

    -- ========== OPTIMIZER ==========
    -- removes textures and materials from the world; restores everything when off or cleaned up
    local optOn = false
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
            if not alive() or not optOn then return end
            pcall(strip, o)
            count = count + 1
            if count % 400 == 0 then
                task.wait()
            end
        end
    end

    track(workspace.DescendantAdded:Connect(function(o)
        if optOn and alive() then
            pcall(strip, o)
        end
    end))

    onCleanup(function()
        optOn = false
        restoreAll()
    end)

    characterTab:Toggle({
        Title = "Optimizer (remove textures)",
        Callback = function(value)
            if value == optOn then return end
            optOn = value
            if optOn then
                task.spawn(applyAll)
                notify("Optimizer", "ON: textures and materials removed")
            else
                restoreAll()
                notify("Optimizer", "OFF: textures restored")
            end
        end,
    })

    -- ========== AUTO COIN ==========
    -- Tweens to each Coin_Server part inside a model named CoinContainer, nearest first.
    -- Waits for the CoinCollected remote before moving on (unless "Skip wait" is on).
    local coinSection = Window:Section({ Title = "Auto Coin" })
    local coinTab = coinSection:Tab({ Title = "Auto Coin", Icon = "solar:check-square-bold" })

    local coinOn = false
    local coinRunning = false
    local coinSpeed = COIN_SPEED
    local skipWait = false
    local coinSignal = Instance.new("BindableEvent")
    local activeCoinTween = nil
    local lastCoinNotice = nil

    local function coinNotice(msg)
        if msg ~= lastCoinNotice then
            lastCoinNotice = msg
            if msg then
                notify("Auto Coin", msg)
            end
        end
    end

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
        local duration = math.max(0.05, dist / coinSpeed)
        local tween = TweenService:Create(root, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
            CFrame = CFrame.new(coin.Position + Vector3.new(0, 3, 0)),
        })
        local done = false
        local conn = tween.Completed:Connect(function()
            done = true
        end)
        activeCoinTween = tween
        tween:Play()
        local t = 0
        while not done and coinOn and coin.Parent and t < duration + 1 and alive() do
            task.wait(0.05)
            t = t + 0.05
        end
        conn:Disconnect()
        tween:Cancel()
        activeCoinTween = nil
    end

    local function autoCoinLoop()
        local remote = findRemoteNamed("CoinCollected")
        local remoteConn
        if remote then
            remoteConn = track(remote.OnClientEvent:Connect(function(...)
                coinSignal:Fire(...)
            end))
        else
            coinNotice("CoinCollected remote not found, using coin removal instead.")
        end

        local skipped = {}
        while coinOn and alive() do
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
                    coinNotice("No Coin_Server parts found in CoinContainer.")
                    task.wait(1)
                elseif #candidates == 0 then
                    skipped = {}
                    task.wait(1)
                else
                    table.sort(candidates, function(a, b)
                        return (a.Position - root.Position).Magnitude < (b.Position - root.Position).Magnitude
                    end)
                    local coin = candidates[1]
                    coinNotice(nil)

                    local fired = false
                    local fireConn = coinSignal.Event:Connect(function()
                        fired = true
                    end)

                    tweenToCoin(root, coin)

                    local t = 0
                    while not skipWait and not fired and coin.Parent and t < COIN_TIMEOUT and coinOn and alive() do
                        task.wait(0.1)
                        t = t + 0.1
                    end
                    fireConn:Disconnect()

                    local got = fired or coin.Parent == nil
                    if not got then
                        skipped[coin] = true
                    end
                    task.wait(0.2)
                end
            end
        end

        if remoteConn then
            pcall(function() remoteConn:Disconnect() end)
        end
        coinRunning = false
    end

    onCleanup(function()
        coinOn = false
        if activeCoinTween then
            pcall(function() activeCoinTween:Cancel() end)
            activeCoinTween = nil
        end
        pcall(function() coinSignal:Destroy() end)
    end)

    coinTab:Toggle({
        Title = "Auto Coin",
        Callback = function(value)
            if value == coinOn then return end
            coinOn = value
            if coinOn then
                notify("Auto Coin", "ON")
                if not coinRunning then
                    coinRunning = true
                    task.spawn(autoCoinLoop)
                end
            else
                notify("Auto Coin", "OFF")
            end
        end,
    })
    coinTab:Slider({
        Title = "Coin speed",
        Step = 1,
        Value = { Min = COIN_MIN, Max = COIN_MAX, Default = COIN_SPEED },
        Callback = function(value)
            coinSpeed = math.clamp(math.floor((tonumber(value) or coinSpeed) + 0.5), COIN_MIN, COIN_MAX)
        end,
    })
    coinTab:Toggle({
        Title = "Skip wait for CoinCollected",
        Callback = function(value)
            skipWait = value == true
        end,
    })

    -- registered last, so it runs first: stop every connection before the restores above run
    onCleanup(function()
        for _, c in ipairs(conns) do
            pcall(function() c:Disconnect() end)
        end
        conns = {}
    end)
end


-- ============================
-- MINI GAMES (ported from the main hub: same rules, controls, scoring and timers)
-- Every game builds its own Instances under ONE ScreenGui and runs its own loop.
-- Only one game runs at a time; starting a game stops the running one.
-- ============================
do
    local CONFIG_PATH = "MM2Hub_settings.json" -- same file as the main hub (stack leaderboard is kept there)
    local playerGui = player:WaitForChild("PlayerGui")
    local COLOR_TEXT = Color3.fromRGB(220, 220, 240)
    local COLOR_DIM = Color3.fromRGB(120, 120, 150)
    local ACCENT = Color3.fromRGB(255, 60, 100) -- default accent of the main hub

    local function corner(parent, radius)
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, radius)
        c.Parent = parent
        return c
    end

    -- the one ScreenGui for every game; destroyed in onCleanup
    local gameGui = Instance.new("ScreenGui")
    gameGui.Name = "MM2Hub_WindUIGames"
    gameGui.ResetOnSpawn = false
    gameGui.DisplayOrder = 50
    gameGui.Parent = playerGui
    onCleanup(function()
        gameGui:Destroy()
    end)

    -- progress line at the top of the screen (the main hub's status bar)
    local statusLbl = Instance.new("TextLabel")
    statusLbl.Name = "GameStatus"
    statusLbl.AnchorPoint = Vector2.new(0.5, 0)
    statusLbl.Position = UDim2.new(0.5, 0, 0, 6)
    statusLbl.Size = UDim2.new(0, 520, 0, 24)
    statusLbl.BackgroundTransparency = 1
    statusLbl.Text = ""
    statusLbl.TextColor3 = COLOR_DIM
    statusLbl.TextScaled = true
    statusLbl.Font = Enum.Font.GothamBold
    statusLbl.Parent = gameGui

    local function gameStatus(text, color)
        statusLbl.Text = text
        statusLbl.TextColor3 = color or COLOR_DIM
    end

    -- full-screen transparent layer: a game's frames go in it, so destroying the layer removes the game
    local function makeLayer()
        local layer = Instance.new("Frame")
        layer.Name = "GameLayer"
        layer.Size = UDim2.new(1, 0, 1, 0)
        layer.BackgroundTransparency = 1
        layer.Parent = gameGui
        return layer
    end

    -- connection bookkeeping: each game keeps its connections in a list and drops them when it ends
    local function hook(conns, signal, fn)
        local c = signal:Connect(fn)
        table.insert(conns, c)
        return c
    end

    local function dropAll(conns)
        for _, c in ipairs(conns) do
            pcall(c.Disconnect, c)
        end
    end

    -- BLOCK STACK leaderboard: stored in the main hub's settings file (key stackBoard)
    local function readStackBoard()
        local ok, list = pcall(function()
            if isfile and isfile(CONFIG_PATH) then
                local data = HttpService:JSONDecode(readfile(CONFIG_PATH))
                return data.stackBoard
            end
        end)
        if ok and type(list) == "table" then
            return list
        end
        return {}
    end

    local function writeStackBoard(list)
        pcall(function()
            local data = {}
            if isfile and isfile(CONFIG_PATH) then
                local okD, d = pcall(function()
                    return HttpService:JSONDecode(readfile(CONFIG_PATH))
                end)
                if okD and type(d) == "table" then
                    data = d
                end
            end
            data.stackBoard = list
            if writefile then
                writefile(CONFIG_PATH, HttpService:JSONEncode(data))
            end
        end)
    end

    local GAMES = {} -- key -> starter; a starter returns a cleanup function, or nil on failure
    local activeGame = nil -- { key = ..., cleanup = fn }
    local startGame -- forward declaration

    local function stopGame(silent)
        if activeGame then
            local cleanupFn = activeGame.cleanup
            activeGame = nil
            pcall(cleanupFn)
            gameStatus("")
            if not silent then
                notify("Mini Games", "Game stopped")
            end
        end
    end

    -- shared window for the 2D games (drag the title bar to move, grip to resize)
    local function gameWindow(title, w, h)
        local layer = makeLayer()

        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(0, w, 0, h)
        frame.Position = UDim2.new(0.5, -math.floor(w / 2), 0.5, -math.floor(h / 2))
        frame.BackgroundColor3 = Color3.fromRGB(14, 14, 22)
        frame.BorderSizePixel = 0
        frame.Active = true
        frame.Draggable = true
        frame.Parent = layer
        corner(frame, 14)

        local grad = Instance.new("UIGradient")
        grad.Color = ColorSequence.new(Color3.fromRGB(34, 24, 56), Color3.fromRGB(12, 12, 18))
        grad.Rotation = 90
        grad.Parent = frame

        local stroke = Instance.new("UIStroke")
        stroke.Color = ACCENT
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
        head.Font = Enum.Font.GothamBold
        head.Parent = frame

        local close = Instance.new("TextButton")
        close.Size = UDim2.new(0, 30, 0, 26)
        close.Position = UDim2.new(1, -40, 0, 8)
        close.BackgroundColor3 = COLOR_RED
        close.BorderSizePixel = 0
        close.Text = "X"
        close.TextColor3 = Color3.new(1, 1, 1)
        close.TextScaled = true
        close.Font = Enum.Font.GothamBold
        close.Parent = frame
        corner(close, 6)
        close.MouseButton1Click:Connect(function()
            stopGame()
        end)

        local score = Instance.new("TextLabel")
        score.Size = UDim2.new(1, -24, 0, 22)
        score.Position = UDim2.new(0, 12, 0, 36)
        score.BackgroundTransparency = 1
        score.Text = ""
        score.TextColor3 = COLOR_GOLD
        score.TextScaled = true
        score.Font = Enum.Font.GothamBold
        score.Parent = frame

        -- bottom-right grip: resize width and height (drag the title bar to move)
        local grip = Instance.new("TextButton")
        grip.Size = UDim2.new(0, 16, 0, 16)
        grip.AnchorPoint = Vector2.new(1, 1)
        grip.Position = UDim2.new(1, -4, 1, -4)
        grip.BackgroundColor3 = ACCENT
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
        local c1 = UserInputService.InputChanged:Connect(function(input)
            if resizing and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                local m = UserInputService:GetMouseLocation()
                local nw = math.clamp(sW + (m.X - sMouse.X), 240, 700)
                local nh = math.clamp(sH + (m.Y - sMouse.Y), 220, 700)
                frame.Size = UDim2.new(0, nw, 0, nh)
            end
        end)
        local c2 = UserInputService.InputEnded:Connect(function(input)
            if resizing and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
                resizing = false
                frame.Draggable = true
            end
        end)
        -- the window's global input connections go away when its layer is destroyed (game end)
        layer.Destroying:Connect(function()
            c1:Disconnect()
            c2:Disconnect()
        end)

        return layer, frame, score
    end

    -- ---------------------------------------------------------------
    -- BLOCK STACK: click or press Space to drop the sliding block. Overlap keeps, rest is lost.
    -- ---------------------------------------------------------------
    local function startBlockStack()
        local gui = makeLayer()
        local conns = {}
        local board = readStackBoard()

        local W, H, BLOCK_H = 260, 300, 18

        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(0, W + 190, 0, H + 60)
        frame.Position = UDim2.new(0.5, -(W + 190) / 2, 0.5, -(H + 60) / 2)
        frame.BackgroundColor3 = Color3.fromRGB(14, 14, 22)
        frame.BorderSizePixel = 0
        frame.Parent = gui
        corner(frame, 10)

        local stroke = Instance.new("UIStroke")
        stroke.Color = ACCENT
        stroke.Thickness = 2
        stroke.Parent = frame

        local header = Instance.new("TextLabel")
        header.Size = UDim2.new(1, -16, 0, 22)
        header.Position = UDim2.new(0, 8, 0, 6)
        header.BackgroundTransparency = 1
        header.Text = "BLOCK STACK  |  click / Space to drop"
        header.TextColor3 = COLOR_TEXT
        header.TextScaled = true
        header.Font = Enum.Font.GothamBold
        header.Parent = frame

        local scoreLbl = Instance.new("TextLabel")
        scoreLbl.Size = UDim2.new(1, -16, 0, 18)
        scoreLbl.Position = UDim2.new(0, 8, 0, 30)
        scoreLbl.BackgroundTransparency = 1
        scoreLbl.Text = "Score: 0"
        scoreLbl.TextColor3 = COLOR_GOLD
        scoreLbl.TextScaled = true
        scoreLbl.Font = Enum.Font.GothamBold
        scoreLbl.Parent = frame

        local boardFrame = Instance.new("Frame")
        boardFrame.Size = UDim2.new(0, W, 0, H)
        boardFrame.Position = UDim2.new(0, 10, 0, 56)
        boardFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 32)
        boardFrame.BorderSizePixel = 0
        boardFrame.ClipsDescendants = true
        boardFrame.Parent = frame
        corner(boardFrame, 6)

        local holder = Instance.new("Frame")
        holder.Size = UDim2.new(1, 0, 0, H)
        holder.BackgroundTransparency = 1
        holder.Parent = boardFrame

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

        -- LEADERBOARD: top scores saved on this device
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
        boardTitle.Font = Enum.Font.GothamBold
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
            local list = board
            if #list == 0 then
                local none = Instance.new("TextLabel")
                none.Size = UDim2.new(1, -12, 0, 20)
                none.Position = UDim2.new(0, 6, 0, 10)
                none.BackgroundTransparency = 1
                none.Text = "No scores yet"
                none.TextColor3 = COLOR_DIM
                none.TextScaled = true
                none.Font = Enum.Font.GothamBold
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
                nameLbl.Font = Enum.Font.GothamBold
                nameLbl.Parent = row

                local scoreTxt = Instance.new("TextLabel")
                scoreTxt.Size = UDim2.new(1, -44, 0, 14)
                scoreTxt.Position = UDim2.new(0, 40, 0, 23)
                scoreTxt.BackgroundTransparency = 1
                scoreTxt.Text = "#" .. i .. "  •  " .. tostring(e.score or 0)
                scoreTxt.TextColor3 = COLOR_GOLD
                scoreTxt.TextScaled = true
                scoreTxt.TextXAlignment = Enum.TextXAlignment.Left
                scoreTxt.Font = Enum.Font.GothamBold
                scoreTxt.Parent = row
            end
        end

        local function recordScore(score)
            if score <= 0 then return end
            table.insert(board, { name = player.DisplayName, userId = player.UserId, score = score })
            table.sort(board, function(a, b)
                return (a.score or 0) > (b.score or 0)
            end)
            while #board > 10 do
                table.remove(board)
            end
            writeStackBoard(board)
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

        hook(conns, RunService.Heartbeat, function(dt)
            if over or not alive() then return end
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

        hook(conns, UserInputService.InputBegan, function(input, gp)
            if gp or not alive() then return end
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

        gameStatus("🧱 Block Stack: click or Space to drop blocks", COLOR_GOLD)

        return function()
            dropAll(conns)
            gui:Destroy()
        end
    end

    -- ---------------------------------------------------------------
    -- OBBY RUN: 25 platforms climbing in a zigzag high above the map. Falling sends you to your checkpoint.
    -- ---------------------------------------------------------------
    local function startObbyGame()
        local char = player.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not root then
            notify("Obby Run", "No character to play with.")
            return nil
        end
        local returnCF = root.CFrame
        local conns = {}

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

        hook(conns, RunService.Heartbeat, function()
            if finished or not alive() then return end
            local c = player.Character
            local r = c and c:FindFirstChild("HumanoidRootPart")
            if not r then return end

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
                gameStatus("You fell! Back to checkpoint " .. checkpoint .. "/" .. N, COLOR_RED)
                return
            end

            if checkpoint >= N then
                finished = true
                notify("Obby Run", string.format("🏁 Obby finished in %.1fs! Pick OBBY to play again.", os.clock() - startT))
                return
            end

            if os.clock() - lastStatus > 0.5 then
                lastStatus = os.clock()
                gameStatus(string.format("🏃 Obby: checkpoint %d/%d | %.1fs", checkpoint, N, os.clock() - startT), COLOR_TEXT)
            end
        end)

        return function()
            dropAll(conns)
            folder:Destroy()
            local c = player.Character
            local rr = c and c:FindFirstChild("HumanoidRootPart")
            if rr then
                rr.CFrame = returnCF
            end
        end
    end

    -- ---------------------------------------------------------------
    -- LOOT RUSH: 30 glowing orbs in a 60-second arena, walk over them to grab them.
    -- ---------------------------------------------------------------
    local function startLootGame()
        local char = player.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not root then
            notify("Loot Rush", "No character to play with.")
            return nil
        end
        local returnCF = root.CFrame
        local conns = {}

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

        hook(conns, RunService.Heartbeat, function(dt)
            if done or not alive() then return end
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
                notify("Loot Rush", "💰 Loot Rush over! Collected " .. score .. " orbs. Pick LOOT to play again.")
                return
            end

            if os.clock() - lastStatus > 0.25 then
                lastStatus = os.clock()
                gameStatus(string.format("💰 Loot: %d collected | %ds left", score, math.ceil(timeLeft)), COLOR_GOLD)
            end
        end)

        return function()
            dropAll(conns)
            folder:Destroy()
            local c = player.Character
            local rr = c and c:FindFirstChild("HumanoidRootPart")
            if rr then
                rr.CFrame = returnCF
            end
        end
    end

    -- ---------------------------------------------------------------
    -- DODGE: red blocks fall from the sky, survive as long as you can
    -- ---------------------------------------------------------------
    local function startDodgeGame()
        local char = player.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not root then
            notify("Dodge", "No character to play with.")
            return nil
        end
        local returnCF = root.CFrame
        local conns = {}

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
        local dodging = true -- false after a hit
        local startT = os.clock()
        local spawnAcc = 0
        local lastStatus = 0

        hook(conns, RunService.Heartbeat, function(dt)
            if not dodging or not alive() then return end
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
                    dodging = false
                    notify("Dodge", string.format("💥 Hit! Survived %.1fs. Pick DODGE to try again.", os.clock() - startT))
                    return
                end
                if f.part.Position.Y < ARENA.Y - 5 then
                    f.part:Destroy()
                    table.remove(falling, i)
                end
            end

            if os.clock() - lastStatus > 0.25 then
                lastStatus = os.clock()
                gameStatus(string.format("☄ Dodge: %.1fs survived", os.clock() - startT), COLOR_TEXT)
            end
        end)

        return function()
            dodging = false
            dropAll(conns)
            folder:Destroy()
            local c = player.Character
            local rr = c and c:FindFirstChild("HumanoidRootPart")
            if rr then
                rr.CFrame = returnCF
            end
        end
    end

    -- ---------------------------------------------------------------
    -- REACTION TEST: click the green pad as soon as it turns green, 5 rounds
    -- ---------------------------------------------------------------
    local function startReactionGame()
        local gui = makeLayer()
        local conns = {}

        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(0, 300, 0, 260)
        frame.Position = UDim2.new(0.5, -150, 0.5, -130)
        frame.BackgroundColor3 = Color3.fromRGB(14, 14, 22)
        frame.BorderSizePixel = 0
        frame.Parent = gui
        corner(frame, 10)

        local stroke = Instance.new("UIStroke")
        stroke.Color = ACCENT
        stroke.Thickness = 2
        stroke.Parent = frame

        local head = Instance.new("TextLabel")
        head.Size = UDim2.new(1, -16, 0, 22)
        head.Position = UDim2.new(0, 8, 0, 8)
        head.BackgroundTransparency = 1
        head.Text = "REACTION TEST  |  5 rounds"
        head.TextColor3 = COLOR_TEXT
        head.TextScaled = true
        head.Font = Enum.Font.GothamBold
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
        pad.Font = Enum.Font.GothamBold
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
        info.Font = Enum.Font.GothamBold
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
                notify("Reaction Test", string.format("⚡ Reaction average: %dms", avg))
                return
            end
            setPad("WAIT...", Color3.fromRGB(180, 40, 40))
            task.delay(math.random(15, 40) / 10, function()
                if myGen ~= gen or not alive() then return end
                ready = true
                startT = os.clock()
                setPad("CLICK!", Color3.fromRGB(40, 200, 80))
            end)
        end

        hook(conns, pad.MouseButton1Click, function()
            if not alive() then return end
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
                    if myGen == gen and alive() then nextRound() end
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
                if myGen == gen and alive() then nextRound() end
            end)
        end)

        nextRound()

        return function()
            gen = gen + 1
            dropAll(conns)
            gui:Destroy()
        end
    end

    -- ---------------------------------------------------------------
    -- TARGET RUSH (3D): click the floating neon balls before they vanish
    -- ---------------------------------------------------------------
    local function startTargetGame()
        local char = player.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not root then
            notify("Target Rush", "No character to play with.")
            return nil
        end
        local returnCF = root.CFrame
        local CENTER = Vector3.new(-800, 800, 0)
        local DURATION = 30
        local conns = {}

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
        local score, spawnAcc, live = 0, 0, true
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
            hook(conns, cd.MouseClick, function()
                if live and alive() and p.Parent then
                    score = score + 1
                    p:Destroy()
                end
            end)

            table.insert(targets, { part = p, born = os.clock(), life = math.max(0.9, 1.8 - score * 0.02) })
        end

        hook(conns, RunService.Heartbeat, function(dt)
            if not live or not alive() then return end
            local left = DURATION - (os.clock() - startT)
            if left <= 0 then
                live = false
                scoreLbl.Text = "Time's up! Score: " .. score .. "  (X to leave)"
                notify("Target Rush", "🎯 Target Rush score: " .. score)
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
            live = false
            dropAll(conns)
            folder:Destroy()
            gui:Destroy()
            local c = player.Character
            local rr = c and c:FindFirstChild("HumanoidRootPart")
            if rr then
                rr.CFrame = returnCF
            end
        end
    end

    -- ---------------------------------------------------------------
    -- SIMON PADS: watch the color order, then repeat it. It gets longer every round.
    -- ---------------------------------------------------------------
    local function startSimonGame()
        local gui, frame, scoreLbl = gameWindow("🟥 SIMON PADS", 300, 340)
        local conns = {}
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

        local sequence, input, showing, live, gen = {}, {}, false, true, 0

        local function flash(i, dur)
            pads[i].BackgroundColor3 = COLORS[i]
            task.delay(dur, function()
                if live and alive() then
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
                    if myGen ~= gen or not live or not alive() then return end
                    flash(idx, 0.35)
                    task.wait(0.55)
                end
                if myGen ~= gen or not live or not alive() then return end
                showing = false
                scoreLbl.Text = "Your turn! Round " .. #sequence
            end)
        end

        nextRound = function()
            table.insert(sequence, math.random(1, 4))
            playSequence()
        end

        for i, b in ipairs(pads) do
            hook(conns, b.MouseButton1Click, function()
                if showing or not live or not alive() then return end
                flash(i, 0.18)
                table.insert(input, i)
                local pos = #input
                if sequence[pos] ~= i then
                    live = false
                    showing = true
                    scoreLbl.Text = "Wrong! You reached round " .. (#sequence - 1) .. "  (X to leave)"
                    notify("Simon Pads", "🟥 Simon: round " .. (#sequence - 1))
                    return
                end
                if pos == #sequence then
                    showing = true
                    scoreLbl.Text = "Nice! Next round..."
                    task.delay(0.8, function()
                        if live and alive() then
                            nextRound()
                        end
                    end)
                end
            end)
        end

        nextRound()

        return function()
            live = false
            gen = gen + 1
            dropAll(conns)
            gui:Destroy()
        end
    end

    -- ---------------------------------------------------------------
    -- WHACK-A-MOLE: a mole pops up in one of 9 holes, hit it before it hides
    -- ---------------------------------------------------------------
    local function startWhackGame()
        local gui, frame, scoreLbl = gameWindow("🐹 WHACK-A-MOLE", 300, 330)
        local conns = {}
        local DURATION = 30
        local DIRT = Color3.fromRGB(60, 42, 26)
        local MOLE = Color3.fromRGB(150, 100, 40)
        local HIT = COLOR_GOLD
        local cells = {}
        local score, live = 0, true
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
            b.Font = Enum.Font.GothamBold
            b.Parent = frame
            corner(b, 42)
            hook(conns, b.MouseButton1Click, function()
                if not live or not alive() or litIndex ~= i then return end
                score = score + 1
                litIndex = nil
                b.Text = "💥"
                b.BackgroundColor3 = HIT
                task.delay(0.25, function()
                    if live and alive() and litIndex ~= i then
                        b.Text = ""
                        b.BackgroundColor3 = DIRT
                    end
                end)
            end)
            cells[i] = b
        end

        hook(conns, RunService.Heartbeat, function(dt)
            if not live or not alive() then return end
            local left = DURATION - (os.clock() - startT)
            if left <= 0 then
                live = false
                clearLit()
                scoreLbl.Text = "Time's up! Score: " .. score .. "  (X to leave)"
                notify("Whack-a-Mole", "🐹 Whack-a-Mole score: " .. score)
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
            live = false
            dropAll(conns)
            gui:Destroy()
        end
    end

    -- ---------------------------------------------------------------
    -- COLOR MATCH: the word says one color, its ink is another. Click the INK color.
    -- ---------------------------------------------------------------
    local function startColorGame()
        local gui, frame, scoreLbl = gameWindow("🎨 COLOR MATCH", 300, 300)
        local conns = {}
        local DURATION = 30
        local NAMES = { "RED", "GREEN", "BLUE", "GOLD" }
        local COLORS = {
            Color3.fromRGB(230, 50, 60),
            Color3.fromRGB(60, 210, 100),
            Color3.fromRGB(60, 130, 255),
            Color3.fromRGB(255, 210, 60),
        }
        local score, inkIdx, live = 0, 1, true
        local startT = os.clock()

        local word = Instance.new("TextLabel")
        word.Size = UDim2.new(1, -24, 0, 90)
        word.Position = UDim2.new(0, 12, 0, 70)
        word.BackgroundTransparency = 1
        word.Text = ""
        word.TextScaled = true
        word.Font = Enum.Font.GothamBold
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
            b.Font = Enum.Font.GothamBold
            b.Parent = frame
            corner(b, 10)
            hook(conns, b.MouseButton1Click, function()
                if not live or not alive() then return end
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

        hook(conns, RunService.Heartbeat, function()
            if not live or not alive() then return end
            local left = DURATION - (os.clock() - startT)
            if left <= 0 then
                live = false
                word.Text = "TIME!"
                word.TextColor3 = COLOR_GOLD
                scoreLbl.Text = "Final score: " .. score .. "  (X to leave)"
                notify("Color Match", "🎨 Color Match score: " .. score)
                return
            end
            scoreLbl.Text = string.format("Score %d   |   %ds left", score, math.ceil(left))
        end)

        return function()
            live = false
            dropAll(conns)
            gui:Destroy()
        end
    end

    -- ---------------------------------------------------------------
    -- BUBBLE POP: bubbles float up, click them before they escape
    -- ---------------------------------------------------------------
    local function startBubbleGame()
        local gui, frame, scoreLbl = gameWindow("🫧 BUBBLE POP", 320, 380)
        local conns = {}
        local field = Instance.new("Frame")
        field.Size = UDim2.new(0, 296, 0, 290)
        field.Position = UDim2.new(0, 12, 0, 74)
        field.BackgroundColor3 = Color3.fromRGB(8, 14, 26)
        field.BorderSizePixel = 0
        field.ClipsDescendants = true
        field.Parent = frame
        corner(field, 10)

        local DURATION = 30
        local score, live, spawnAcc = 0, true, 0
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
            hook(conns, b.MouseButton1Click, function()
                if not live or not alive() or not b.Parent then return end
                score = score + 1
                b:Destroy()
            end)
        end

        hook(conns, RunService.Heartbeat, function(dt)
            if not live or not alive() then return end
            local left = DURATION - (os.clock() - startT)
            if left <= 0 then
                live = false
                scoreLbl.Text = "Time's up! Score: " .. score .. "  (X to leave)"
                notify("Bubble Pop", "🫧 Bubble Pop score: " .. score)
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
            live = false
            dropAll(conns)
            gui:Destroy()
        end
    end

    -- ---------------------------------------------------------------
    -- MEMORY FLIP: find the 8 matching pairs
    -- ---------------------------------------------------------------
    local function startMemoryGame()
        local gui, frame, scoreLbl = gameWindow("🃏 MEMORY FLIP", 320, 380)
        local conns = {}
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
        local open, lock, matches, moves, live = {}, false, 0, 0, true
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
            b.Font = Enum.Font.GothamBold
            b.Parent = frame
            corner(b, 10)
            cards[i] = { ui = b, sym = deck[i], shown = false, done = false }

            hook(conns, b.MouseButton1Click, function()
                local card = cards[i]
                if not live or not alive() or lock or card.shown or card.done then return end
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
                            live = false
                            notify("Memory Flip", "🃏 Memory solved in " .. moves .. " moves!")
                        end
                    else
                        lock = true
                        task.delay(0.8, function()
                            if live and alive() then
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
            live = false
            dropAll(conns)
            gui:Destroy()
        end
    end

    -- ---------------------------------------------------------------
    -- SLIDE PUZZLE: slide the tiles back into order (empty tile is the last one)
    -- ---------------------------------------------------------------
    local function startPuzzleGame()
        local gui, frame, scoreLbl = gameWindow("🧩 SLIDE PUZZLE", 320, 380)
        local conns = {}
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
        local moves, live = 0, true
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
            b.Font = Enum.Font.GothamBold
            b.Parent = frame
            corner(b, 12)
            tiles[k] = b

            hook(conns, b.MouseButton1Click, function()
                if not live or not alive() then return end
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
                    live = false
                    scoreLbl.Text = "Solved in " .. moves .. " moves!  (X to leave)"
                    notify("Slide Puzzle", "🧩 Puzzle solved in " .. moves .. " moves")
                end
            end)
        end
        render()

        return function()
            live = false
            dropAll(conns)
            gui:Destroy()
        end
    end

    -- ---------------------------------------------------------------
    -- registry and start/stop
    -- ---------------------------------------------------------------
    GAMES.STACK = startBlockStack
    GAMES.OBBY = startObbyGame
    GAMES.LOOT = startLootGame
    GAMES.DODGE = startDodgeGame
    GAMES.REACTION = startReactionGame
    GAMES.TARGET = startTargetGame
    GAMES.SIMON = startSimonGame
    GAMES.WHACK = startWhackGame
    GAMES.COLOR = startColorGame
    GAMES.BUBBLE = startBubbleGame
    GAMES.MEMORY = startMemoryGame
    GAMES.PUZZLE = startPuzzleGame

    startGame = function(key)
        stopGame(true)
        local starter = GAMES[key]
        if not starter then return end
        local ok, result = pcall(starter)
        if ok and result then
            activeGame = { key = key, cleanup = result }
        elseif not ok then
            notify("Mini Games", "Game failed to start: " .. tostring(result))
        end
    end

    -- a new character (respawn) ends the running game, as in the main hub
    local charConn = player.CharacterAdded:Connect(function()
        stopGame(true)
    end)

    -- ---------------------------------------------------------------
    -- Games menu: one button per game, plus STOP GAME
    -- ---------------------------------------------------------------
    local ENTRIES = {
        { key = "STACK", title = "🧱 BLOCK STACK" },
        { key = "OBBY", title = "🏃 OBBY RUN" },
        { key = "LOOT", title = "💰 LOOT RUSH" },
        { key = "DODGE", title = "☄ DODGE" },
        { key = "REACTION", title = "⚡ REACTION TEST" },
        { key = "TARGET", title = "🎯 TARGET RUSH" },
        { key = "SIMON", title = "🟥 SIMON PADS" },
        { key = "WHACK", title = "🐹 WHACK-A-MOLE" },
        { key = "COLOR", title = "🎨 COLOR MATCH" },
        { key = "BUBBLE", title = "🫧 BUBBLE POP" },
        { key = "MEMORY", title = "🃏 MEMORY FLIP" },
        { key = "PUZZLE", title = "🧩 SLIDE PUZZLE" },
    }

    local gamesSection = Window:Section({ Title = "Games" })
    local gamesTab = gamesSection:Tab({ Title = "Mini Games", Icon = "solar:check-square-bold" })
    for _, e in ipairs(ENTRIES) do
        gamesTab:Button({
            Title = e.title,
            Callback = function()
                startGame(e.key)
            end,
        })
    end
    gamesTab:Button({
        Title = "STOP GAME",
        Callback = function()
            stopGame()
        end,
    })

    onCleanup(function()
        pcall(function() charConn:Disconnect() end)
        stopGame(true)
    end)
end


-- SETTINGS: version tools (same as the main hub's version changer and refresh)
do
    local settingsSection = Window:Section({ Title = "Settings" })
    local versionTab = settingsSection:Tab({ Title = "Versions", Icon = "solar:bell-bold" })
    versionTab:Button({
        Title = "Refresh (check for update)",
        Callback = function()
            if G.MM2HubRefresh then
                task.spawn(function()
                    local ok, msg = pcall(G.MM2HubRefresh)
                    notify("Refresh", tostring(msg or ok))
                end)
            end
        end,
    })
    versionTab:Button({
        Title = "Load previous version (3.10)",
        Callback = function()
            if G.MM2HubSwitch then
                task.spawn(function()
                    local ok, msg = G.MM2HubSwitch("3.10")
                    notify("Version", tostring(msg))
                end)
            end
        end,
    })
    versionTab:Button({
        Title = "Close Hub",
        Callback = function()
            if G.MM2HubWindUIClose then G.MM2HubWindUIClose() end
        end,
    })
end

-- CLEANUP: stops every feature and restores the character.
-- Also run by the main hub when it refreshes or switches versions (MM2HubWindUIClose).
local function cleanup()
    G.MM2HubWindUIGen = (G.MM2HubWindUIGen or 0) + 1
    for i = #cleanups, 1, -1 do
        pcall(cleanups[i])
    end
    cleanups = {}
end

G.MM2HubWindUIClose = function()
    cleanup()
    pcall(function() Window:Destroy() end)
    G.MM2HubWindUIClose = nil
end

notify("MM2 Hub", "WindUI hub loaded")
