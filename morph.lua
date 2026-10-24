-- morph.lua
-- Separate from MM2_Helper.lua. Client-side disguise: wears another player's avatar
-- (with their animations) and changes your name on the leaderboard. Only you see the
-- avatar change; other players keep seeing your real character.

local Players = game:GetService("Players")
local player = Players.LocalPlayer

local M = {}
local current = nil      -- the username we are disguised as
local disguiseDesc = nil -- the HumanoidDescription we applied
local original = nil     -- { description = ..., label = "your original leaderboard text" }

-- Players -> PlayerGui -> MainGUI -> Game -> Leaderboard -> Container -> <frame with your name> -> PlayerLabel
local function leaderboardLabel()
    local pg = player:FindFirstChild("PlayerGui")
    local mainGui = pg and pg:FindFirstChild("MainGUI")
    local gameFrame = mainGui and mainGui:FindFirstChild("Game")
    local lb = gameFrame and gameFrame:FindFirstChild("Leaderboard")
    local container = lb and lb:FindFirstChild("Container")
    if not container then return nil end
    for _, frame in ipairs(container:GetChildren()) do
        if frame:IsA("Frame") then
            local lbl = frame:FindFirstChild("PlayerLabel")
            if lbl and (frame.Name == player.Name or frame.Name == player.DisplayName or lbl.Text == player.Name or lbl.Text == player.DisplayName) then
                return lbl
            end
        end
    end
    return nil
end

local function humanoid()
    local char = player.Character
    return char and char:FindFirstChildOfClass("Humanoid"), char
end

function M.disguise(name)
    name = string.match(tostring(name or ""), "^%s*@?(.-)%s*$")
    if name == "" then
        return false, "Type a username first"
    end

    local okId, userId = pcall(function()
        return Players:GetUserIdFromNameAsync(name)
    end)
    if not okId or not userId then
        return false, "No user named " .. name
    end

    local okDesc, desc = pcall(function()
        return Players:GetHumanoidDescriptionFromUserId(userId)
    end)
    if not okDesc or not desc then
        return false, "Couldn't load " .. name .. "'s avatar"
    end

    local hum = humanoid()
    if not hum then
        return false, "No character yet, try again"
    end

    if not original then
        local okOrig, applied = pcall(function()
            return hum:GetAppliedDescription()
        end)
        local lbl = leaderboardLabel()
        original = {
            description = okOrig and applied or nil,
            label = lbl and lbl.Text or nil,
        }
    end

    local okApply, errApply = pcall(function()
        hum:ApplyDescription(desc)
    end)
    if not okApply then
        return false, "Couldn't apply the avatar: " .. tostring(errApply)
    end

    current = name
    disguiseDesc = desc
    local lbl = leaderboardLabel()
    if lbl then
        lbl.Text = name
    end
    return true, "Disguised as " .. name
end

function M.reset()
    local hum = humanoid()
    if hum and original and original.description then
        pcall(function()
            hum:ApplyDescription(original.description)
        end)
    end
    local lbl = leaderboardLabel()
    if lbl and original and original.label then
        lbl.Text = original.label
    end
    current, disguiseDesc, original = nil, nil, nil
    return true, "Back to your original avatar and name"
end

function M.current()
    return current
end

-- keeps the disguise: re-applies the avatar after a respawn and keeps the leaderboard name
local token = {}
getgenv().MM2HubMorphToken = token
task.spawn(function()
    local appliedChar = nil
    while getgenv().MM2HubMorphToken == token do
        task.wait(0.5)
        if current then
            local hum, char = humanoid()
            if hum and char ~= appliedChar and disguiseDesc then
                pcall(function()
                    hum:ApplyDescription(disguiseDesc)
                end)
                appliedChar = char
            end
            local lbl = leaderboardLabel()
            if lbl and lbl.Text ~= current then
                lbl.Text = current
            end
        end
    end
end)

return M
