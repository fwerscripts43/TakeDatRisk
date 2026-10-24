-- loader.lua
-- Paste THIS file into your executor (or loadstring it).
-- It only points at updater.lua, which fetches the rest and handles the REFRESH button.

local BASE = "https://raw.githubusercontent.com/fwerscripts43/TakeDatRisk/main/"
getgenv().MM2HubBase = BASE

local okGet, updaterSrc = pcall(game.HttpGet, game, BASE .. "updater.lua?cb=" .. tostring(os.time()))
if not okGet or type(updaterSrc) ~= "string" then
    warn("MM2 Hub: couldn't download updater.lua from GitHub: " .. tostring(updaterSrc))
    return
end

local fn, err = loadstring(updaterSrc)
if not fn then
    warn("MM2 Hub: updater.lua has a syntax error: " .. tostring(err))
    return
end

fn()
