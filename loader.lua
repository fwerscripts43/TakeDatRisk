-- loader.lua
-- Paste THIS file into your executor (or loadstring it).

local BASE = "https://raw.githubusercontent.com/fwerscripts43/TakeDatRisk/main/"

-- default animation (the 66 frames in the frames/ folder)
local bgModule = loadstring(game:HttpGet(BASE .. "bg_module.lua"))()
bgModule.baseUrl = BASE
getgenv().MM2HubBg = bgModule

-- animated backgrounds from giphy / .gif links (the Animated.. box in Settings)
getgenv().MM2HubGif = loadstring(game:HttpGet(BASE .. "gif_module.lua"))()

loadstring(game:HttpGet(BASE .. "MM2_Helper.lua"))()
