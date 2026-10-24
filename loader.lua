-- loader.lua
-- Paste THIS file into your executor (or loadstring it).
-- It only points at updater.lua, which fetches the rest and handles the REFRESH button.

local BASE = "https://raw.githubusercontent.com/fwerscripts43/TakeDatRisk/main/"
getgenv().MM2HubBase = BASE

-- errors show on screen as well as in the console
local function showError(msg)
    warn("MM2 Hub: " .. msg)
    pcall(function()
        local playerGui = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui", 5)
        if not playerGui then return end
        local g = Instance.new("ScreenGui")
        g.Name = "MM2Hub_Error"
        g.ResetOnSpawn = false
        g.DisplayOrder = 200
        g.Parent = playerGui
        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(0, 420, 0, 60)
        l.Position = UDim2.new(0.5, -210, 0, 20)
        l.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
        l.TextColor3 = Color3.fromRGB(255, 90, 90)
        l.TextWrapped = true
        l.TextScaled = true
        l.Font = Enum.Font.GothamBold
        l.Text = "MM2 Hub: " .. string.sub(msg, 1, 140)
        l.Parent = g
        task.delay(20, function() g:Destroy() end)
    end)
end

local okGet, updaterSrc = pcall(game.HttpGet, game, BASE .. "updater.lua?cb=" .. tostring(os.time()))
if not okGet or type(updaterSrc) ~= "string" then
    showError("couldn't download updater.lua: " .. tostring(updaterSrc))
    return
end

local fn, err = loadstring(updaterSrc)
if not fn then
    showError("updater.lua has a syntax error: " .. tostring(err))
    return
end

fn()
