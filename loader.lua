-- loader.lua
-- Paste THIS file into your executor (or loadstring it).
-- It only points at updater.lua, which fetches the rest and handles the REFRESH button.

local BASE = "https://raw.githubusercontent.com/fwerscripts43/TakeDatRisk/main/"
getgenv().MM2HubBase = BASE

loadstring(game:HttpGet(BASE .. "updater.lua?cb=" .. tostring(os.time())))()
