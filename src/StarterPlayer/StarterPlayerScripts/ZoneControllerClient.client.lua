--[[
    ZoneControllerClient.client.lua
    ระบบควบคุมการเปลี่ยนบรรยากาศแสง (Lighting Presets), ป้ายประกาศเข้าโซน (Zone Banners),
    และตัวบ่งชี้เพื่อนร่วมปาร์ตี้ (Overhead Teammate Indicators)
    - City: แสงอรุณสีทองอุ่น (Celestial Dawn) ปลอดภัย
    - PvE: หมอกเขียวมรกตและฟ้าพาสเทลชวนฝัน (Dreamy Cyan/Emerald Fog) ปลอดภัย
    - PvP: ท้องฟ้าสนธยาสีเลือดและเมฆทมิฬ (Ominous Crimson Twilight) อันตราย
]]

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")
local GameConfig = require(ReplicatedStorage:WaitForChild("SharedModules"):WaitForChild("GameConfig"))

-- สร้าง ScreenGui สำหรับป้ายประกาศโซน
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ZoneControllerGui"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

-- แถบป้ายประกาศโซนแบบภาพยนตร์ (Cinematic Zone Banner)
local bannerFrame = Instance.new("Frame")
bannerFrame.Name = "ZoneBanner"
bannerFrame.Size = UDim2.new(0, 560, 0, 52)
bannerFrame.Position = UDim2.new(0.5, -280, 0, -80) -- ซ่อนอยู่เหนือจอ
bannerFrame.BackgroundColor3 = Color3.fromRGB(15, 18, 24)
bannerFrame.BorderSizePixel = 0
bannerFrame.ClipsDescendants = true
bannerFrame.Parent = screenGui

local bCorner = Instance.new("UICorner")
bCorner.CornerRadius = UDim.new(0, 10)
bCorner.Parent = bannerFrame

local bStroke = Instance.new("UIStroke")
bStroke.Thickness = 2
bStroke.Color = Color3.fromRGB(85, 200, 255)
bStroke.Parent = bannerFrame

local bannerLabel = Instance.new("TextLabel")
bannerLabel.Name = "BannerLabel"
bannerLabel.Size = UDim2.new(1, -20, 1, 0)
bannerLabel.Position = UDim2.new(0, 10, 0, 0)
bannerLabel.BackgroundTransparency = 1
bannerLabel.Text = "เข้าสู่พื้นที่ใหม่"
bannerLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
bannerLabel.Font = Enum.Font.SourceSansBold
bannerLabel.TextSize = 16
bannerLabel.TextWrapped = true
bannerLabel.Parent = bannerFrame

local currentZone = "None"
local bannerTween = nil

-- ฟังก์ชันแสดงป้ายประกาศโซน
local function showZoneBanner(text, strokeColor)
    bannerLabel.Text = text
    bStroke.Color = strokeColor or Color3.fromRGB(85, 200, 255)

    if bannerTween then bannerTween:Cancel() end
    bannerFrame.Position = UDim2.new(0.5, -280, 0, -80)

    -- เลื่อนลงมาแสดง
    local tweenIn = TweenService:Create(bannerFrame, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Position = UDim2.new(0.5, -280, 0, 25)
    })
    tweenIn:Play()

    -- เลื่อนกลับขึ้นไปหลังจาก 4.5 วินาที
    task.delay(4.5, function()
        if bannerFrame.Position.Y.Offset > 0 then
            TweenService:Create(bannerFrame, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                Position = UDim2.new(0.5, -280, 0, -80)
            }):Play()
        end
    end)
end

-- ปรับเปลี่ยนบรรยากาศแสง (Scripted Lighting Presets)
local function applyLightingPreset(zoneType)
    if zoneType == "City" then
        TweenService:Create(Lighting, TweenInfo.new(1.2, Enum.EasingStyle.Sine), {
            ClockTime = 8.0,
            OutdoorAmbient = Color3.fromRGB(150, 130, 100),
            FogColor = Color3.fromRGB(240, 220, 190),
            FogEnd = 450,
            Brightness = 2.2
        }):Play()

    elseif zoneType == "PvE" then
        TweenService:Create(Lighting, TweenInfo.new(1.2, Enum.EasingStyle.Sine), {
            ClockTime = 12.0,
            OutdoorAmbient = Color3.fromRGB(100, 170, 140),
            FogColor = Color3.fromRGB(180, 255, 230),
            FogEnd = 300,
            Brightness = 2.0
        }):Play()

    elseif zoneType == "PvP" then
        TweenService:Create(Lighting, TweenInfo.new(1.2, Enum.EasingStyle.Sine), {
            ClockTime = 19.5, -- พลบค่ำน่าสะพรึงกลัว
            OutdoorAmbient = Color3.fromRGB(80, 25, 20),
            FogColor = Color3.fromRGB(90, 20, 15),
            FogEnd = 230,
            Brightness = 1.3
        }):Play()
    end
end

-- ตรวจสอบตำแหน่งผู้เล่นในโลกเพื่ออัปเดตโซน
task.spawn(function()
    while true do
        task.wait(0.5)
        local char = localPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if root then
            local pos = root.Position
            local worldCoords = GameConfig.WorldCoordinates
            if worldCoords then
                local distCity = (pos - worldCoords.CityCenter).Magnitude
                local distPvE = (pos - worldCoords.PvEZone.Center).Magnitude
                local distPvP = (pos - worldCoords.PvPZone.Center).Magnitude

                if distCity <= 320 and currentZone ~= "City" then
                    currentZone = "City"
                    showZoneBanner("🏯 เข้าสู่หมู่บ้านเมฆาคราม (Azure Cloud Village) [Safe Zone] - ดินแดนแห่งความสงบสุข", Color3.fromRGB(255, 215, 80))
                    applyLightingPreset("City")

                elseif distPvE <= worldCoords.PvEZone.Radius and currentZone ~= "PvE" then
                    currentZone = "PvE"
                    showZoneBanner(worldCoords.PvEZone.BannerText, worldCoords.PvEZone.BannerColor)
                    applyLightingPreset("PvE")

                elseif distPvP <= worldCoords.PvPZone.Radius and currentZone ~= "PvP" then
                    currentZone = "PvP"
                    showZoneBanner(worldCoords.PvPZone.BannerText, worldCoords.PvPZone.BannerColor)
                    applyLightingPreset("PvP")
                end
            end
        end
    end
end)

-- แสดงสัญลักษณ์สีเขียวเหนือศีรษะเพื่อนร่วมปาร์ตี้ (Overhead Teammate Tag)
RunService.RenderStepped:Connect(function()
    local myParty = localPlayer:GetAttribute("PartyId")
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer then
            local pChar = player.Character
            local pHead = pChar and pChar:FindFirstChild("Head")
            if pHead then
                local existingTag = pHead:FindFirstChild("PartyTag")
                local theirParty = player:GetAttribute("PartyId")

                if myParty and theirParty and myParty == theirParty then
                    -- อยู่ปาร์ตี้เดียวกัน
                    if not existingTag then
                        local tag = Instance.new("BillboardGui")
                        tag.Name = "PartyTag"
                        tag.Size = UDim2.new(0, 120, 0, 30)
                        tag.StudsOffset = Vector3.new(0, 2.5, 0)
                        tag.AlwaysOnTop = true
                        tag.MaxDistance = 80
                        tag.Parent = pHead

                        local lbl = Instance.new("TextLabel")
                        lbl.Size = UDim2.new(1, 0, 1, 0)
                        lbl.BackgroundTransparency = 1
                        lbl.Text = "🛡️ " .. player.DisplayName
                        lbl.TextColor3 = Color3.fromRGB(85, 255, 127)
                        lbl.Font = Enum.Font.SourceSansBold
                        lbl.TextSize = 13
                        lbl.Parent = tag
                    end
                else
                    if existingTag then
                        existingTag:Destroy()
                    end
                end
            end
        end
    end
end)

print("✅ [Client] Zone Controller & Cinematic Banner System พร้อมทำงาน!")

