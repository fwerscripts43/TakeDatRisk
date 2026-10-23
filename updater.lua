-- updater.lua
-- Separate from MM2_Helper.lua. Fetches the hub files from GitHub, runs them,
-- and handles the REFRESH button: it reloads only when the repo has changed.

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

local BASE = getgenv().MM2HubBase or "https://raw.githubusercontent.com/fwerscripts43/TakeDatRisk/main/"
local FILES = { "bg_module.lua", "gif_module.lua", "MM2_Helper.lua" }

local U = {}

-- raw.githubusercontent caches for a few minutes, so each fetch uses a changing query string
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

-- stop everything the running copy started, so nothing stacks after a reload
local function teardown()
    local G = getgenv()
    if G.MM2HubBg then pcall(function() G.MM2HubBg.stop() end) end
    if G.MM2HubGif then pcall(function() G.MM2HubGif.stop() end) end
    pcall(function() RunService:UnbindFromRenderStep("MM2HubAutoAim") end)

    local player = Players.LocalPlayer
    local playerGui = player and player:FindFirstChildOfClass("PlayerGui")
    if playerGui then
        for _, name in ipairs({ "MM2_Helper_GUI", "MM2Hub_Loading", "MM2Hub_ShootRing", "MM2Hub_StackGame" }) do
            local g = playerGui:FindFirstChild(name)
            if g then g:Destroy() end
        end
    end
    local blur = Lighting:FindFirstChild("MM2Hub_Blur")
    if blur then blur:Destroy() end
end

local function runAll(src)
    local G = getgenv()
    local bgModule = loadstring(src["bg_module.lua"])()
    bgModule.baseUrl = BASE
    G.MM2HubBg = bgModule
    G.MM2HubGif = loadstring(src["gif_module.lua"])()
    local chunk, err = loadstring(src["MM2_Helper.lua"])
    if not chunk then error(err) end
    chunk()
end

local function sameAs(last, src)
    if not last then return false end
    for _, name in ipairs(FILES) do
        if last[name] ~= src[name] then return false end
    end
    return true
end

-- called by the REFRESH button: returns ok, message
function U.refresh()
    local okF, src = pcall(fetchAll)
    if not okF then
        return false, "Couldn't reach GitHub"
    end
    if sameAs(getgenv().MM2HubSrc, src) then
        return true, "Already up to date"
    end
    teardown()
    local okR, err = pcall(runAll, src)
    if not okR then
        warn("MM2 Hub update failed: " .. tostring(err))
        return false, "Update failed (see console)"
    end
    getgenv().MM2HubSrc = src
    getgenv().MM2HubNotice = "Updated to the latest version"
    return true, "Updated"
end

getgenv().MM2HubRefresh = U.refresh

-- first run
teardown()
local okS, errS = pcall(function()
    local src = fetchAll()
    runAll(src)
    getgenv().MM2HubSrc = src
end)
if not okS then
    warn("MM2 Hub failed to load: " .. tostring(errS))
end
