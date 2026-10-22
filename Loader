-- loader.lua

local BASE = "https://raw.githubusercontent.com/fwerscripts43/TakeDatRisk/main/"

local bgModule = loadstring(game:HttpGet(BASE .. "bg_module.lua"))()
bgModule.baseUrl = BASE

-- The main script reads this and starts the animated background on its window
getgenv().MM2HubBg = bgModule

loadstring(game:HttpGet(BASE .. "MM2_Helper.lua"))()
