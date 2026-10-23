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

local function runAll(bundle)
    local G = getgenv()
    local bgModule = loadstring(bundle["bg_module.lua"])()
    bgModule.baseUrl = BASE
    G.MM2HubBg = bgModule
    G.MM2HubGif = loadstring(bundle["gif_module.lua"])()
    local chunk, err = loadstring(bundle["MM2_Helper.lua"])
    if not chunk then error(err, 0) end
    chunk()
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
function U.refresh()
    local boot = makeBoot()
    boot.setStatus("CHECKING FOR UPDATES", 0.15)
    task.wait(PHASE_WAIT)

    local okF, src = pcall(fetchAll)
    if not okF then
        boot.abort()
        return false, "Couldn't reach GitHub"
    end
    if sameAs(getgenv().MM2HubSrc, src) then
        boot.abort()
        return true, "Already up to date"
    end

    local okD, fellBackOrErr = pcall(deploy, src, boot)
    if not okD then
        boot.abort()
        warn("MM2 Hub update failed: " .. tostring(fellBackOrErr))
        return false, "Update failed (see console)"
    end
    getgenv().MM2HubSrc = src
    getgenv().MM2HubNotice = fellBackOrErr and "New version had errors, loaded backup" or "Updated to the latest version"
    return true, "Updated"
end

getgenv().MM2HubRefresh = U.refresh

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
    boot.abort()
    warn("MM2 Hub: no connection and no backup yet")
else
    local okD, errD = pcall(deploy, src, boot)
    if okD then
        getgenv().MM2HubSrc = src
    else
        boot.abort()
        warn("MM2 Hub failed to load: " .. tostring(errD))
    end
end
