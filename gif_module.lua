-- gif_module.lua

local RunService = game:GetService("RunService")

local M = {}
local conn = nil
local FOLDER = "MM2Hub_GIF"

local function le16(n)
    return string.char(n % 256, math.floor(n / 256) % 256)
end

local function le32(n)
    return string.char(
        n % 256,
        math.floor(n / 256) % 256,
        math.floor(n / 65536) % 256,
        math.floor(n / 16777216) % 256
    )
end

local function u16(s, p)
    return string.byte(s, p) + string.byte(s, p + 1) * 256
end

-- giphy page link -> direct GIF url (returns nil if the link isn't usable)
function M.resolveUrl(link)
    link = link:gsub("%s", "")
    if link:find("giphy%.com/gifs/") then
        local slug = link:match("giphy%.com/gifs/([^?#]+)")
        local id = slug and slug:match("([^%-/]+)/?$")
        if id then
            return "https://media.giphy.com/media/" .. id .. "/giphy.gif"
        end
        return nil
    elseif link:find("%.gif") then
        return link
    end
    return nil
end

-- LZW decoder for GIF image data. Returns an array of palette indices.
local function lzwDecode(data, minCode, pixelCount)
    local clear = math.floor(2 ^ minCode)
    local eoi = clear + 1
    local prefix, suffix, first, len = {}, {}, {}, {}
    for i = 0, clear - 1 do
        prefix[i] = -1
        suffix[i] = i
        first[i] = i
        len[i] = 1
    end

    local nextCode, codeSize = eoi + 1, minCode + 1
    local prev = -1
    local bitBuf, bitCnt, bp = 0, 0, 1
    local dlen = #data
    local out, outN = {}, 0
    local tmp = {}

    while outN < pixelCount do
        while bitCnt < codeSize and bp <= dlen do
            bitBuf = bitBuf + string.byte(data, bp) * (2 ^ bitCnt)
            bitCnt = bitCnt + 8
            bp = bp + 1
        end
        if bitCnt < codeSize then
            break
        end

        local scale = 2 ^ codeSize
        local code = math.floor(bitBuf % scale)
        bitBuf = math.floor(bitBuf / scale)
        bitCnt = bitCnt - codeSize

        if code == clear then
            nextCode = eoi + 1
            codeSize = minCode + 1
            prev = -1
        elseif code == eoi then
            break
        else
            local src = code
            local kwkwk = false
            if code >= nextCode then
                if code ~= nextCode or prev < 0 then
                    break -- corrupt data
                end
                kwkwk = true
                src = prev
            end

            local k = len[src]
            local c = src
            for idx = k, 1, -1 do
                tmp[idx] = suffix[c]
                c = prefix[c]
            end
            local seqLen = k
            if kwkwk then
                seqLen = k + 1
                tmp[seqLen] = first[prev]
            end
            for idx = 1, seqLen do
                out[outN + idx] = tmp[idx]
            end
            outN = outN + seqLen

            if prev >= 0 and nextCode < 4096 then
                prefix[nextCode] = prev
                suffix[nextCode] = tmp[1]
                first[nextCode] = first[prev]
                len[nextCode] = len[prev] + 1
                nextCode = nextCode + 1
                if nextCode >= 2 ^ codeSize and codeSize < 12 then
                    codeSize = codeSize + 1
                end
            end
            prev = code
        end
    end

    return out
end

-- reads GIF sub-blocks starting at pos, returns the position after them
local function skipSubBlocks(data, pos)
    while true do
        local sz = string.byte(data, pos)
        if not sz then
            return pos
        end
        pos = pos + 1
        if sz == 0 then
            return pos
        end
        pos = pos + sz
    end
end

local function readPalette(data, pos, size)
    local pal = {}
    for i = 0, size - 1 do
        local p = pos + i * 3
        pal[i] = { string.byte(data, p), string.byte(data, p + 1), string.byte(data, p + 2) }
    end
    return pal
end

-- writes the canvas (flat r,g,b array) as a 24-bit BMP string
local function bmpEncode(canvas, ow, oh)
    local rowBytes = ow * 3
    local parts = {
        "BM", le32(54 + rowBytes * oh), le32(0), le32(54),
        le32(40), le32(ow), le32(oh), le16(1), le16(24),
        le32(0), le32(rowBytes * oh), le32(2835), le32(2835), le32(0), le32(0),
    }
    for y = oh - 1, 0, -1 do
        local row, n = {}, 0
        local base = y * rowBytes
        for x = 0, ow - 1 do
            local p = base + x * 3 + 1
            row[n + 1] = canvas[p + 2] -- BMP stores blue first
            row[n + 2] = canvas[p + 1]
            row[n + 3] = canvas[p]
            n = n + 3
        end
        for i = 1, n, 200 do
            parts[#parts + 1] = string.char(table.unpack(row, i, math.min(i + 199, n)))
        end
    end
    return table.concat(parts)
end

-- decodes every frame of the GIF, draws it onto a canvas at ow x oh, and writes each as a BMP
local function renderGif(data, ow, oh, basePath)
    if data:sub(1, 3) ~= "GIF" then
        error("not a GIF file")
    end

    local W = u16(data, 7)
    local H = u16(data, 9)
    local packed = string.byte(data, 11)
    local pos = 14
    local gpal = nil
    if packed >= 128 then
        local size = math.floor(2 ^ ((packed % 8) + 1))
        gpal = readPalette(data, pos, size)
        pos = pos + size * 3
    end

    local sx, sy = ow / W, oh / H
    local canvas = {}
    for i = 1, ow * oh * 3 do
        canvas[i] = 0
    end

    local frames = {}
    local gce = { delay = 10, transparent = nil, disposal = 0 }
    local prevDisposal = 0

    while pos <= #data do
        local b = string.byte(data, pos)
        if b == 0x21 then -- extension
            local label = string.byte(data, pos + 1)
            if label == 0xF9 then -- graphic control: delay, transparency, disposal
                local p = string.byte(data, pos + 3)
                gce.disposal = math.floor(p / 4) % 8
                gce.delay = u16(data, pos + 4)
                if p % 2 == 1 then
                    gce.transparent = string.byte(data, pos + 6)
                end
            end
            pos = skipSubBlocks(data, pos + 2)

        elseif b == 0x2C then -- image
            local ix, iy = u16(data, pos + 1), u16(data, pos + 3)
            local iw, ih = u16(data, pos + 5), u16(data, pos + 7)
            local ip = string.byte(data, pos + 9)
            pos = pos + 10

            local pal = gpal
            if ip >= 128 then
                local size = math.floor(2 ^ ((ip % 8) + 1))
                pal = readPalette(data, pos, size)
                pos = pos + size * 3
            end

            local minCode = string.byte(data, pos)
            pos = pos + 1
            local chunks = {}
            while true do
                local sz = string.byte(data, pos)
                if not sz or sz == 0 then
                    pos = pos + 1
                    break
                end
                chunks[#chunks + 1] = data:sub(pos + 1, pos + sz)
                pos = pos + sz + 1
            end

            local indices = lzwDecode(table.concat(chunks), minCode, iw * ih)

            -- interlaced images store rows in 4 passes
            local interlaced = math.floor(ip / 64) % 2 == 1
            local rowOf = {}
            if interlaced then
                local r = 0
                for _, pass in ipairs({ { 0, 8 }, { 4, 8 }, { 2, 4 }, { 1, 2 } }) do
                    for y = pass[1], ih - 1, pass[2] do
                        rowOf[r] = y
                        r = r + 1
                    end
                end
            end

            if prevDisposal == 2 then
                for i = 1, ow * oh * 3 do
                    canvas[i] = 0
                end
            end

            local transIdx = gce.transparent
            for r = 0, ih - 1 do
                local fy = interlaced and rowOf[r] or r
                local oy = math.floor((iy + fy) * sy)
                local base = r * iw
                for x = 0, iw - 1 do
                    local idx = indices[base + x + 1]
                    if idx ~= nil and idx ~= transIdx then
                        local c = pal[idx]
                        if c then
                            local ox = math.floor((ix + x) * sx)
                            if ox >= 0 and ox < ow and oy >= 0 and oy < oh then
                                local p = (oy * ow + ox) * 3 + 1
                                canvas[p] = c[1]
                                canvas[p + 1] = c[2]
                                canvas[p + 2] = c[3]
                            end
                        end
                    end
                end
            end

            local n = #frames + 1
            local path = basePath .. "_" .. n .. ".bmp"
            writefile(path, bmpEncode(canvas, ow, oh))
            local d = gce.delay > 0 and gce.delay or 10
            frames[n] = { path = path, delay = math.max(0.02, d / 100) }

            prevDisposal = gce.disposal
            gce = { delay = 10, transparent = nil, disposal = 0 }

        else -- trailer (0x3B) or unknown data: stop
            break
        end
    end

    return frames
end

local function hashOf(s)
    local h = 0
    for i = 1, #s do
        h = (h * 31 + string.byte(s, i)) % 1000000007
    end
    return tostring(h)
end

function M.stop()
    if conn then
        conn:Disconnect()
        conn = nil
    end
end

-- Downloads the GIF behind `link`, decodes it at ow x oh, and starts playing it on imageLabel.
-- Returns true, or false and an error message.
function M.play(imageLabel, link, ow, oh)
    local url = M.resolveUrl(link)
    if not url then
        return false, "Paste a giphy.com/gifs link or a direct .gif link"
    end

    local env = getgenv and getgenv() or nil
    if env and env.MM2HubBg and env.MM2HubBg.stop then
        env.MM2HubBg.stop()
    end
    M.stop()

    local okGet, data = pcall(function()
        return game:HttpGet(url)
    end)
    if not okGet or type(data) ~= "string" or data:sub(1, 3) ~= "GIF" then
        return false, "Couldn't download a GIF from that link"
    end

    if makefolder and not (isfolder and isfolder(FOLDER)) then
        makefolder(FOLDER)
    end
    local base = FOLDER .. "/" .. hashOf(url) .. "_" .. ow .. "x" .. oh

    local okRender, frames = pcall(renderGif, data, ow, oh, base)
    if not okRender then
        return false, "Couldn't decode that GIF: " .. tostring(frames)
    end
    if #frames == 0 then
        return false, "That GIF has no frames"
    end

    local assets, delays = {}, {}
    for i, f in ipairs(frames) do
        assets[i] = getcustomasset(f.path)
        delays[i] = f.delay
    end

    imageLabel.ScaleType = Enum.ScaleType.Crop
    imageLabel.Image = assets[1]
    local idx, acc = 1, 0
    conn = RunService.Heartbeat:Connect(function(dt)
        acc = acc + dt
        if acc >= delays[idx] then
            acc = acc - delays[idx]
            idx = idx % #assets + 1
            imageLabel.Image = assets[idx]
        end
    end)

    return true, #assets .. " frames"
end

return M
