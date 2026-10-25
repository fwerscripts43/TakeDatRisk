-- updater.lua
-- Separate from MM2_Helper.lua. On every start and on REFRESH it:
--   CHECKING FOR UPDATES          fetches the hub files from GitHub
--   CHECKING FOR SYNTAX ERRORS    compiles them; a broken file is replaced by its backup
--   runs the hub; if it fails to start, the backup version is loaded instead
--   CHECKING FOR NON WORKING FUNCTIONS  the hub guards every button (a broken one shuts itself down)
-- The boot overlay (blur + status text above the bar + loading bar) shows during all of this.

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local BASE = getgenv().MM2HubBase or "https://raw.githubusercontent.com/fwerscripts43/TakeDatRisk/main/"
local FILES = { "bg_module.lua", "gif_module.lua", "MM2_Helper.lua" }
local BACKUP_PREFIX = "MM2Hub_backup_"
local PHASE_WAIT = 0.6

local U = {}

local function fetch(name)
    return game:HttpGet(BASE .. name .. "?cb=" .. tostring(os.time()) .. tostring(math.floor(os.clock() * 1000)))
end

local function fetchAll()
    local src = {}
    for _, name in ipairs(FILES) do
        src[name] = fetch(name)
    end
    return src
end

local function sameAs(last, src)
    if not last then return false end
    for _, name in ipairs(FILES) do
        if last[name] ~= src[name] then return false end
    end
    return true
end

-- boot overlay: blur, status text above the bar, loading bar
local function makeBoot()
    local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

    local blur = Instance.new("BlurEffect")
    blur.Name = "MM2Hub_BootBlur"
    blur.Size = 0
    blur.Parent = Lighting
    TweenService:Create(blur, TweenInfo.new(0.4), { Size = 18 }):Play()

    local lg = Instance.new("ScreenGui")
    lg.Name = "MM2Hub_Boot"
    lg.ResetOnSpawn = false
    lg.DisplayOrder = 100
    lg.IgnoreGuiInset = true
    lg.Parent = playerGui

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0, 320, 0, 18)
    label.AnchorPoint = Vector2.new(1, 1)
    label.Position = UDim2.new(1, -20, 1, -76)
    label.BackgroundTransparency = 1
    label.Text = ""
    label.TextColor3 = Color3.fromRGB(235, 235, 245)
    label.TextScaled = true
    label.Font = Enum.Font.GothamBold
    label.TextXAlignment = Enum.TextXAlignment.Right
    label.Parent = lg

    local barBack = Instance.new("Frame")
    barBack.Size = UDim2.new(0, 220, 0, 10)
    barBack.AnchorPoint = Vector2.new(1, 1)
    barBack.Position = UDim2.new(1, -20, 1, -60)
    barBack.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    barBack.BorderSizePixel = 0
    barBack.Parent = lg

    local barFill = Instance.new("Frame")
    barFill.Size = UDim2.new(0, 0, 1, 0)
    barFill.BackgroundColor3 = Color3.fromRGB(255, 60, 100)
    barFill.BorderSizePixel = 0
    barFill.Parent = barBack

    local boot = { ready = false }

    function boot.setStatus(text, progress)
        label.Text = text
        if progress then
            TweenService:Create(barFill, TweenInfo.new(0.3), { Size = UDim2.new(progress, 0, 1, 0) }):Play()
        end
    end

    local disposed = false
    function boot.abort()
        if disposed then return end
        disposed = true
        pcall(function() lg:Destroy() end)
        pcall(function() blur:Destroy() end)
    end

    -- shows an error on the overlay so it can be read without the console
    function boot.showError(msg)
        label.TextColor3 = Color3.fromRGB(255, 90, 90)
        label.Text = "ERROR: " .. string.sub(tostring(msg), 1, 140)
        task.delay(20, boot.abort)
    end

    -- called by the hub once its window exists: waits for the checks, then fades out and shows it
    function boot.finish(showMain)
        task.spawn(function()
            while not boot.ready do task.wait(0.05) end
            TweenService:Create(label, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
            TweenService:Create(barBack, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
            TweenService:Create(barFill, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
            TweenService:Create(blur, TweenInfo.new(0.5), { Size = 0 }):Play()
            task.wait(0.5)
            boot.abort()
            if showMain then showMain() end
        end)
    end

    return boot
end

-- stop everything the running copy started, so nothing stacks after a reload
local function teardown()
    local G = getgenv()
    if G.MM2HubWindUIClose then pcall(G.MM2HubWindUIClose) end -- closes the WindUI hub if it's open
    G.MM2HubGen = (G.MM2HubGen or 0) + 1 -- every loop from the running copy sees this and stops
    if G.MM2HubBg then pcall(function() G.MM2HubBg.stop() end) end
    if G.MM2HubGif then pcall(function() G.MM2HubGif.stop() end) end
    pcall(function() RunService:UnbindFromRenderStep("MM2HubAutoAim") end)

    local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if playerGui then
        for _, name in ipairs({ "MM2_Helper_GUI", "MM2Hub_Loading", "MM2Hub_ShootRing", "MM2Hub_StackGame" }) do
            local g = playerGui:FindFirstChild(name)
            if g then g:Destroy() end
        end
    end
    local blur = Lighting:FindFirstChild("MM2Hub_Blur")
    if blur then blur:Destroy() end
end

getgenv().MM2HubTeardown = teardown

-- VERSIONS: the repo's versions/ folder (newest first), with a check of which ones work
local FALLBACK_VERSIONS = { "2.8", "2.9", "3.0", "3.2", "3.4", "3.5", "3.6", "3.8", "3.9", "3.10", "3.11", "3.12", "3.13", "3.14", "3.15", "3.16", "3.17", "3.18" }

local function versionKey(v)
    local a, b = string.match(v, "^(%d+)%.(%d+)")
    return (tonumber(a) or 0) * 1000 + (tonumber(b) or 0)
end

local function listVersions()
    local found = {}
    local okA, body = pcall(game.HttpGet, game, "https://api.github.com/repos/fwerscripts43/TakeDatRisk/contents/versions")
    if okA and type(body) == "string" then
        local okJ, data = pcall(function()
            return game:GetService("HttpService"):JSONDecode(body)
        end)
        if okJ and type(data) == "table" then
            for _, file in ipairs(data) do
                local v = type(file) == "table" and type(file.name) == "string" and string.match(file.name, "^MM2_Helper_v(.+)%.lua$")
                if v then table.insert(found, v) end
            end
        end
    end
    if #found == 0 then
        for _, v in ipairs(FALLBACK_VERSIONS) do table.insert(found, v) end
    end
    table.sort(found, function(x, y) return versionKey(x) > versionKey(y) end)
    return found
end

-- WORKING = downloads and compiles; NOT WORKING = downloads but has a syntax error; UNAVAILABLE = not in the repo
local function checkVersion(ver)
    local okF, src = pcall(fetch, "versions/MM2_Helper_v" .. ver .. ".lua")
    if not okF or type(src) ~= "string" or #src < 500 then
        return "UNAVAILABLE"
    end
    if not loadstring(src) then
        return "NOT WORKING"
    end
    return "WORKING"
end

local STATUS_COLORS = {
    WORKING = Color3.fromRGB(100, 255, 120),
    ["NOT WORKING"] = Color3.fromRGB(255, 90, 90),
    UNAVAILABLE = Color3.fromRGB(255, 90, 90),
    LATEST = Color3.fromRGB(120, 200, 255),
    CHECKING = Color3.fromRGB(150, 150, 165),
}

-- SWITCH VERSION: a corner button that slides up a list of versions (searchable, clickable)
local function attachSwitcher()
    pcall(function()
        local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui", 5)
        if not playerGui then return end
        local old = playerGui:FindFirstChild("MM2Hub_Switch")
        if old then old:Destroy() end

        local g = Instance.new("ScreenGui")
        g.Name = "MM2Hub_Switch"
        g.ResetOnSpawn = false
        g.DisplayOrder = 150
        g.IgnoreGuiInset = true
        g.Parent = playerGui

        local button = Instance.new("TextButton")
        button.Size = UDim2.fromOffset(130, 26)
        button.Position = UDim2.new(0, 10, 1, -40)
        button.BackgroundColor3 = Color3.fromRGB(30, 30, 48)
        button.BorderSizePixel = 0
        button.Text = "⇄ SWITCH VERSION"
        button.TextColor3 = Color3.fromRGB(230, 230, 240)
        button.TextScaled = true
        button.Font = Enum.Font.GothamBold
        button.Parent = g

        local PANEL_H = 360
        local shownPos = UDim2.new(0, 10, 1, -(PANEL_H + 46))
        local hiddenPos = UDim2.new(0, 10, 1, 10)

        local panel = Instance.new("Frame")
        panel.Name = "VersionList"
        panel.Size = UDim2.fromOffset(280, PANEL_H)
        panel.Position = hiddenPos
        panel.BackgroundColor3 = Color3.fromRGB(18, 18, 26)
        panel.BorderSizePixel = 0
        panel.Visible = false
        panel.Parent = g
        local panelCorner = Instance.new("UICorner")
        panelCorner.CornerRadius = UDim.new(0, 8)
        panelCorner.Parent = panel

        local search = Instance.new("TextBox")
        search.Size = UDim2.new(1, -16, 0, 28)
        search.Position = UDim2.fromOffset(8, 8)
        search.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
        search.BorderSizePixel = 0
        search.Text = ""
        search.PlaceholderText = "search versions..."
        search.TextColor3 = Color3.fromRGB(230, 230, 240)
        search.TextScaled = true
        search.ClearTextOnFocus = false
        search.Parent = panel

        local listFrame = Instance.new("ScrollingFrame")
        listFrame.Size = UDim2.new(1, -16, 1, -92)
        listFrame.Position = UDim2.fromOffset(8, 44)
        listFrame.BackgroundTransparency = 1
        listFrame.BorderSizePixel = 0
        listFrame.ScrollBarThickness = 4
        listFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
        listFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
        listFrame.Parent = panel
        local layout = Instance.new("UIListLayout")
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.Padding = UDim.new(0, 4)
        layout.Parent = listFrame

        local footer = Instance.new("TextLabel")
        footer.Size = UDim2.new(1, -110, 0, 32)
        footer.Position = UDim2.new(0, 8, 1, -40)
        footer.BackgroundTransparency = 1
        footer.Text = ""
        footer.TextColor3 = Color3.fromRGB(200, 200, 210)
        footer.TextScaled = true
        footer.TextXAlignment = Enum.TextXAlignment.Left
        footer.Parent = panel

        local recheck = Instance.new("TextButton")
        recheck.Size = UDim2.fromOffset(92, 30)
        recheck.Position = UDim2.new(1, -100, 1, -38)
        recheck.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
        recheck.BorderSizePixel = 0
        recheck.Text = "↻ RECHECK"
        recheck.TextColor3 = Color3.fromRGB(230, 230, 240)
        recheck.TextScaled = true
        recheck.Font = Enum.Font.GothamBold
        recheck.Parent = panel

        local statusLabels = {}

        local function setStatusLabel(lbl, status)
            lbl.Text = status
            lbl.TextColor3 = STATUS_COLORS[status] or STATUS_COLORS.CHECKING
        end

        local function makeRow(ver, order, status)
            local b = Instance.new("TextButton")
            b.Name = ver
            b.LayoutOrder = order
            b.Size = UDim2.new(1, -4, 0, 34)
            b.BackgroundColor3 = Color3.fromRGB(30, 30, 44)
            b.BorderSizePixel = 0
            b.Text = ""
            b.Parent = listFrame

            local name = Instance.new("TextLabel")
            name.Size = UDim2.new(0.55, -8, 1, 0)
            name.Position = UDim2.fromOffset(8, 0)
            name.BackgroundTransparency = 1
            name.Text = ver == "current" and "current (latest)" or ("v" .. ver)
            name.TextColor3 = Color3.fromRGB(235, 235, 245)
            name.TextScaled = true
            name.Font = Enum.Font.GothamBold
            name.TextXAlignment = Enum.TextXAlignment.Left
            name.Parent = b

            local st = Instance.new("TextLabel")
            st.Size = UDim2.new(0.45, -8, 1, 0)
            st.Position = UDim2.new(0.55, 0, 0, 0)
            st.BackgroundTransparency = 1
            st.TextScaled = true
            st.Font = Enum.Font.GothamBold
            st.TextXAlignment = Enum.TextXAlignment.Right
            st.Parent = b
            setStatusLabel(st, status)
            statusLabels[ver] = st

            b.MouseButton1Click:Connect(function()
                footer.Text = "Loading " .. name.Text .. "..."
                local _, msg = U.switch(ver)
                footer.Text = tostring(msg)
            end)
            return b
        end

        local buildRows
        buildRows = function(force)
            if force then getgenv().MM2HubVersionCache = nil end
            for _, child in ipairs(listFrame:GetChildren()) do
                if child:IsA("TextButton") then child:Destroy() end
            end
            statusLabels = {}

            local cache = getgenv().MM2HubVersionCache
            if not cache then
                cache = { list = listVersions(), status = {} }
                getgenv().MM2HubVersionCache = cache
            end

            local pending = {}
            makeRow("current", 0, "LATEST")
            for i, ver in ipairs(cache.list) do
                local status = cache.status[ver]
                if not status then
                    table.insert(pending, ver)
                    status = "CHECKING"
                end
                makeRow(ver, i, status)
            end

            if #pending > 0 then
                footer.Text = "Checking versions..."
                task.spawn(function()
                    for _, ver in ipairs(pending) do
                        local status = checkVersion(ver)
                        cache.status[ver] = status
                        local lbl = statusLabels[ver]
                        if lbl then setStatusLabel(lbl, status) end
                    end
                    footer.Text = "Click a version to switch"
                end)
            else
                footer.Text = "Click a version to switch"
            end
        end

        local open = false
        local function setOpen(v)
            open = v
            if v then
                panel.Visible = true
                buildRows(false)
            end
            TweenService:Create(panel, TweenInfo.new(0.25, Enum.EasingStyle.Quad), {
                Position = v and shownPos or hiddenPos,
            }):Play()
            if not v then
                task.delay(0.26, function()
                    if not open then panel.Visible = false end
                end)
            end
        end
        button.MouseButton1Click:Connect(function()
            setOpen(not open)
        end)
        recheck.MouseButton1Click:Connect(function()
            buildRows(true)
        end)

        search:GetPropertyChangedSignal("Text"):Connect(function()
            local q = string.lower(search.Text):gsub("^%s*v?", ""):gsub("%s+$", "")
            for _, child in ipairs(listFrame:GetChildren()) do
                if child:IsA("TextButton") then
                    child.Visible = q == "" or string.find(string.lower(child.Name), q, 1, true) ~= nil
                end
            end
        end)
    end)
end

local function runAll(bundle)
    local G = getgenv()
    local bgModule = loadstring(bundle["bg_module.lua"])()
    bgModule.baseUrl = BASE
    G.MM2HubBg = bgModule
    G.MM2HubGif = loadstring(bundle["gif_module.lua"])()
    local chunk, err = loadstring(bundle["MM2_Helper.lua"])
    if not chunk then error(err, 0) end
    chunk()
    attachSwitcher()
end

-- backups: the last copy that started successfully
local function readBackup(name)
    local path = BACKUP_PREFIX .. name
    local ok, data = pcall(function()
        if isfile and isfile(path) then return readfile(path) end
    end)
    if ok and type(data) == "string" and #data > 0 then return data end
    return nil
end

local function backupBundle()
    local b = {}
    for _, name in ipairs(FILES) do
        local data = readBackup(name)
        if not data then return nil end
        b[name] = data
    end
    return b
end

local function writeBackup(bundle)
    for _, name in ipairs(FILES) do
        pcall(writefile, BACKUP_PREFIX .. name, bundle[name])
    end
end

-- compile every file (no running); a file with a syntax error is swapped for its backup
local function checkSyntax(src)
    local bundle, fellBack = {}, false
    for _, name in ipairs(FILES) do
        local fn, err = loadstring(src[name])
        if fn then
            bundle[name] = src[name]
        else
            warn("MM2 Hub: syntax error in " .. name .. ": " .. tostring(err))
            local backup = readBackup(name)
            if not backup then
                error("syntax error in " .. name .. " and no backup exists: " .. tostring(err), 0)
            end
            bundle[name] = backup
            fellBack = true
        end
    end
    return bundle, fellBack
end

local function deploy(src, boot)
    boot.setStatus("CHECKING FOR SYNTAX ERRORS", 0.4)
    task.wait(PHASE_WAIT)
    local bundle, fellBack = checkSyntax(src)

    teardown()
    getgenv().MM2HubBoot = boot
    boot.setStatus("LOADING HUB", 0.7)
    task.wait(PHASE_WAIT)

    local ok, err = pcall(runAll, bundle)
    if not ok then
        warn("MM2 Hub: new version failed to start: " .. tostring(err))
        local backup = backupBundle()
        if not backup then error("new version failed and no backup exists: " .. tostring(err), 0) end
        teardown()
        boot.setStatus("LOADING BACKUP VERSION", 0.8)
        task.wait(PHASE_WAIT)
        runAll(backup)
        fellBack = true
    end

    if not fellBack then writeBackup(bundle) end

    boot.setStatus("CHECKING FOR NON WORKING FUNCTIONS", 0.9)
    task.wait(1)
    boot.setStatus("READY", 1)
    boot.ready = true
    task.delay(3, boot.abort)
    return fellBack
end

-- REFRESH button: ok, message
function U.refresh(force)
    local boot = makeBoot()
    boot.setStatus("CHECKING FOR UPDATES", 0.15)
    task.wait(PHASE_WAIT)

    local okF, src = pcall(fetchAll)
    if not okF then
        boot.abort()
        return false, "Couldn't reach GitHub"
    end
    if not force and sameAs(getgenv().MM2HubSrc, src) then
        boot.abort()
        return true, "Already up to date"
    end

    local okD, fellBackOrErr = pcall(deploy, src, boot)
    if not okD then
        warn("MM2 Hub update failed: " .. tostring(fellBackOrErr))
        boot.showError(fellBackOrErr)
        return false, "Update failed (see the error on screen)"
    end
    getgenv().MM2HubSrc = src
    getgenv().MM2HubNotice = fellBackOrErr and "New version had errors, loaded backup" or "Updated to the latest version"
    return true, "Updated"
end

getgenv().MM2HubRefresh = U.refresh

-- VERSION CHANGER: "2.8", "3.4", ... load repo versions/MM2_Helper_v<ver>.lua; "current" = latest
-- returns ok, message. Old versions use the same backgrounds and GIF module as the current one.
function U.switch(input)
    local ver = tostring(input or ""):match("^%s*[vV]?(.-)%s*$")
    if ver == "" then
        return false, "Type a version like 2.8 or current"
    end
    if ver:lower() == "current" or ver:lower() == "latest" then
        return U.refresh(true)
    end

    local okD, helper = pcall(fetch, "versions/MM2_Helper_v" .. ver .. ".lua")
    if not okD or type(helper) ~= "string" or #helper < 500 then
        return false, "v" .. ver .. " isn't in the repo's versions folder"
    end
    local fn, err = loadstring(helper)
    if not fn then
        getgenv().MM2HubLastError = { ver = ver, source = helper, error = tostring(err) }
        warn("MM2 Hub: v" .. ver .. " syntax error: " .. tostring(err))
        return false, "v" .. ver .. " has a syntax error!"
    end

    local cur = getgenv().MM2HubSrc
    if not cur then
        local okS, s = pcall(fetchAll)
        if not okS then return false, "Couldn't reach GitHub" end
        cur = s
    end
    local bundle = {
        ["bg_module.lua"] = cur["bg_module.lua"],
        ["gif_module.lua"] = cur["gif_module.lua"],
        ["MM2_Helper.lua"] = helper,
    }

    getgenv().MM2HubBoot = nil
    teardown()
    local ok, e = pcall(runAll, bundle)
    getgenv().MM2HubSrc = nil -- the next REFRESH reloads the repo's current version
    if ok then
        getgenv().MM2HubLastError = nil
        return true, "Loaded v" .. ver
    end

    getgenv().MM2HubLastError = { ver = ver, source = helper, error = tostring(e) }
    warn("MM2 Hub: v" .. ver .. " failed to start: " .. tostring(e))
    teardown()
    getgenv().MM2HubNotice = "v" .. ver .. " failed to start, restored the current version"
    local okB, eB = pcall(runAll, cur)
    if not okB then warn("MM2 Hub: restore failed: " .. tostring(eB)) end
    return false, "v" .. ver .. " failed to start"
end
getgenv().MM2HubSwitch = U.switch

-- first run
local boot = makeBoot()
boot.setStatus("CHECKING FOR UPDATES", 0.15)
task.wait(PHASE_WAIT)

local okF, src = pcall(fetchAll)
if not okF then
    warn("MM2 Hub: couldn't reach GitHub, using the backup: " .. tostring(src))
    src = backupBundle()
end

if not src then
    boot.showError("couldn't reach GitHub and there is no backup yet")
else
    local okD, errD = pcall(deploy, src, boot)
    if okD then
        getgenv().MM2HubSrc = src
    else
        warn("MM2 Hub failed to load: " .. tostring(errD))
        boot.showError(errD)
    end
end
