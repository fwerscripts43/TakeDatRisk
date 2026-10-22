local RunService = game:GetService("RunService")

local M = {}

M.baseUrl = "" -- set by loader.lua (the raw GitHub URL of this repo, ending in "/")
M.frameCount = 66
M.frameTime = 0.07 -- seconds per frame (the GIF is 70 ms per frame)
M.folder = "MM2Hub_BG"
M.scaleType = Enum.ScaleType.Crop

local assets = {} -- frame index -> rbxasset url
local conn = nil

local function frameName(i)
    return string.format("frame_%03d.png", i)
end

local function fetchFrame(i)
    local name = frameName(i)
    local path = M.folder .. "/" .. name

    if not (isfile and isfile(path)) then
        if makefolder and not (isfolder and isfolder(M.folder)) then
            makefolder(M.folder)
        end
        local data = game:HttpGet(M.baseUrl .. "frames/" .. name)
        writefile(path, data)
    end

    return getcustomasset(path)
end

-- Downloads all frames (only the ones not saved yet are fetched)
function M.preload(onProgress)
    for i = 1, M.frameCount do
        if not assets[i] then
            local ok, result = pcall(fetchFrame, i)
            if ok then
                assets[i] = result
            else
                warn("[MM2 BG] frame " .. i .. " failed: " .. tostring(result))
            end
        end
        if onProgress then
            onProgress(i, M.frameCount)
        end
    end
    return #assets == M.frameCount
end

-- Starts cycling the frames on the given ImageLabel
function M.start(imageLabel)
    M.stop()

    if #assets < M.frameCount and not M.preload() then
        warn("[MM2 BG] Not all frames loaded, animation may skip")
    end
    if #assets == 0 then
        return false
    end

    imageLabel.ScaleType = M.scaleType
    local frame, acc = 1, 0
    conn = RunService.Heartbeat:Connect(function(dt)
        acc = acc + dt
        if acc >= M.frameTime then
            acc = acc - M.frameTime
            frame = frame % #assets + 1
            imageLabel.Image = assets[frame]
        end
    end)
    return true
end

-- Stops the animation
function M.stop()
    if conn then
        conn:Disconnect()
        conn = nil
    end
end

return M
