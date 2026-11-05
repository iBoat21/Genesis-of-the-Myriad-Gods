--[[
    CharacterStatusUI.client.lua
    หน้าต่างแสดงสเตตัสตัวละครและขีดจำกัด (Stats & Attribute System)
    กดปุ่ม 'P' หรือคลิกปุ่มบนหน้าจอเพื่อเปิด/ปิด
    แสดง HP, Chi, อัตราดูดซับตบะต่อวินาที, โจมตี, ป้องกัน, ความเร็ว และพื้นที่โซนที่ปลดล็อก
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local GameConfig = require(ReplicatedStorage:WaitForChild("SharedModules"):WaitForChild("GameConfig"))
local NetworkEvents = require(ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("NetworkEvents"))

-- สร้าง ScreenGui
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "CharacterStatusGui"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

--------------------------------------------------------------------------------
-- 1. ปุ่มลอยเปิดหน้าต่างตัวละครบนหน้าจอ (Shortcut Button)
--------------------------------------------------------------------------------
local toggleButton = Instance.new("TextButton")
toggleButton.Name = "ToggleStatus"
toggleButton.Size = UDim2.new(0, 50, 0, 50)
toggleButton.Position = UDim2.new(1, -60, 0.5, 95) -- วางใต้ปุ่มเตาหลอม
toggleButton.BackgroundColor3 = Color3.fromRGB(30, 35, 45)
toggleButton.Text = "👤"
toggleButton.TextSize = 28
toggleButton.Parent = screenGui

local tbCorner = Instance.new("UICorner")
tbCorner.CornerRadius = UDim.new(0, 25)
tbCorner.Parent = toggleButton

local tbStroke = Instance.new("UIStroke")
tbStroke.Thickness = 2
tbStroke.Color = Color3.fromRGB(85, 170, 255)
tbStroke.Parent = toggleButton

--------------------------------------------------------------------------------
-- 2. หน้าต่างหลัก Character Status Window
--------------------------------------------------------------------------------
local mainFrame = Instance.new("Frame")
mainFrame.Name = "StatusFrame"
mainFrame.Size = UDim2.new(0, 560, 0, 420)
mainFrame.Position = UDim2.new(0.5, -280, 0.5, -210)
mainFrame.BackgroundColor3 = Color3.fromRGB(18, 20, 26)
mainFrame.BorderSizePixel = 0
mainFrame.Visible = false
mainFrame.ClipsDescendants = true
mainFrame.Parent = screenGui

local frameCorner = Instance.new("UICorner")
frameCorner.CornerRadius = UDim.new(0, 14)
frameCorner.Parent = mainFrame

local frameStroke = Instance.new("UIStroke")
frameStroke.Thickness = 2
frameStroke.Color = Color3.fromRGB(85, 170, 255)
frameStroke.Parent = mainFrame

-- Title Bar
local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 40)
titleBar.BackgroundColor3 = Color3.fromRGB(26, 30, 40)
titleBar.BorderSizePixel = 0
titleBar.Parent = mainFrame

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(0.7, 0, 1, 0)
titleLabel.Position = UDim2.new(0, 16, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "👤 ข้อมูลตัวละครและสเตตัส (Character Status [P])"
titleLabel.TextColor3 = Color3.fromRGB(150, 210, 255)
titleLabel.Font = Enum.Font.SourceSansBold
titleLabel.TextSize = 17
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = titleBar

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 30, 0, 28)
closeBtn.Position = UDim2.new(1, -38, 0, 6)
closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
closeBtn.Text = "✕"
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.Font = Enum.Font.SourceSansBold
closeBtn.TextSize = 16
closeBtn.Parent = titleBar

local cbCorner = Instance.new("UICorner")
cbCorner.CornerRadius = UDim.new(0, 6)
cbCorner.Parent = closeBtn

--------------------------------------------------------------------------------
-- 3. ส่วนเนื้อหาภายในหน้าต่าง (Left Profile + Right Stats Grid)
--------------------------------------------------------------------------------
-- ด้านซ้าย: การ์ดโปรไฟล์ตัวละคร
local leftCard = Instance.new("Frame")
leftCard.Size = UDim2.new(0.36, 0, 1, -54)
leftCard.Position = UDim2.new(0, 12, 0, 46)
leftCard.BackgroundColor3 = Color3.fromRGB(13, 15, 20)
leftCard.BorderSizePixel = 0
leftCard.Parent = mainFrame

local lcCorner = Instance.new("UICorner")
lcCorner.CornerRadius = UDim.new(0, 8)
lcCorner.Parent = leftCard

-- รูปอวาตาร์ตัวละคร (Thumbnail)
local avatarImage = Instance.new("ImageLabel")
avatarImage.Size = UDim2.new(0, 90, 0, 90)
avatarImage.Position = UDim2.new(0.5, -45, 0, 15)
avatarImage.BackgroundColor3 = Color3.fromRGB(25, 30, 40)
avatarImage.BorderSizePixel = 0
avatarImage.Parent = leftCard

local aiCorner = Instance.new("UICorner")
aiCorner.CornerRadius = UDim.new(0, 45)
aiCorner.Parent = avatarImage

local aiStroke = Instance.new("UIStroke")
aiStroke.Thickness = 2
aiStroke.Color = Color3.fromRGB(85, 170, 255)
aiStroke.Parent = avatarImage

task.spawn(function()
    local content, isReady = Players:GetUserThumbnailAsync(localPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
    avatarImage.Image = content
end)

local nameLabel = Instance.new("TextLabel")
nameLabel.Size = UDim2.new(1, -10, 0, 22)
nameLabel.Position = UDim2.new(0, 5, 0, 115)
nameLabel.BackgroundTransparency = 1
nameLabel.Text = localPlayer.DisplayName
nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
nameLabel.Font = Enum.Font.SourceSansBold
nameLabel.TextSize = 17
nameLabel.Parent = leftCard

local userLabel = Instance.new("TextLabel")
userLabel.Size = UDim2.new(1, -10, 0, 18)
userLabel.Position = UDim2.new(0, 5, 0, 137)
userLabel.BackgroundTransparency = 1
userLabel.Text = "@" .. localPlayer.Name
userLabel.TextColor3 = Color3.fromRGB(140, 150, 170)
userLabel.Font = Enum.Font.SourceSans
userLabel.TextSize = 13
userLabel.Parent = leftCard

-- ฉายาและขอบเขต
local titleBadge = Instance.new("TextLabel")
titleBadge.Size = UDim2.new(1, -16, 0, 26)
titleBadge.Position = UDim2.new(0, 8, 0, 170)
titleBadge.BackgroundColor3 = Color3.fromRGB(25, 30, 42)
titleBadge.Text = "« มนุษย์ปุถุชน »"
titleBadge.TextColor3 = Color3.fromRGB(180, 180, 180)
titleBadge.Font = Enum.Font.SourceSansBold
titleBadge.TextSize = 14
titleBadge.Parent = leftCard

local tbC = Instance.new("UICorner")
tbC.CornerRadius = UDim.new(0, 6)
tbC.Parent = titleBadge

local realmBadge = Instance.new("TextLabel")
realmBadge.Size = UDim2.new(1, -16, 0, 26)
realmBadge.Position = UDim2.new(0, 8, 0, 202)
realmBadge.BackgroundColor3 = Color3.fromRGB(25, 30, 42)
realmBadge.Text = "☯ ขอบเขต: คนธรรมดา"
realmBadge.TextColor3 = Color3.fromRGB(85, 255, 127)
realmBadge.Font = Enum.Font.SourceSansBold
realmBadge.TextSize = 13
realmBadge.Parent = leftCard

local rbC = Instance.new("UICorner")
rbC.CornerRadius = UDim.new(0, 6)
rbC.Parent = realmBadge

-- ด้านขวา: กริดสเตตัสตัวละคร (Stats Grid)
local rightCard = Instance.new("ScrollingFrame")
rightCard.Size = UDim2.new(0.60, 0, 1, -54)
rightCard.Position = UDim2.new(0.38, 0, 0, 46)
rightCard.BackgroundColor3 = Color3.fromRGB(13, 15, 20)
rightCard.BorderSizePixel = 0
rightCard.ScrollBarThickness = 5
rightCard.CanvasSize = UDim2.new(0, 0, 0, 0)
rightCard.Parent = mainFrame

local rcCorner = Instance.new("UICorner")
rcCorner.CornerRadius = UDim.new(0, 8)
rcCorner.Parent = rightCard

local rcLayout = Instance.new("UIListLayout")
rcLayout.Padding = UDim.new(0, 6)
rcLayout.SortOrder = Enum.SortOrder.LayoutOrder
rcLayout.Parent = rightCard

local rcPadding = Instance.new("UIPadding")
rcPadding.PaddingTop = UDim.new(0, 8)
rcPadding.PaddingLeft = UDim.new(0, 8)
rcPadding.PaddingRight = UDim.new(0, 8)
rcPadding.PaddingBottom = UDim.new(0, 8)
rcPadding.Parent = rightCard

-- ฟังก์ชันสร้างแถวสเตตัส (Stat Row Item)
local statRows = {}
local function createStatRow(id, icon, labelText, valueText, color)
    local row = Instance.new("Frame")
    row.Name = id
    row.Size = UDim2.new(1, 0, 0, 36)
    row.BackgroundColor3 = Color3.fromRGB(22, 25, 34)
    row.BorderSizePixel = 0
    row.Parent = rightCard

    local rCorner = Instance.new("UICorner")
    rCorner.CornerRadius = UDim.new(0, 6)
    rCorner.Parent = row

    local iconLbl = Instance.new("TextLabel")
    iconLbl.Size = UDim2.new(0, 30, 1, 0)
    iconLbl.Position = UDim2.new(0, 6, 0, 0)
    iconLbl.BackgroundTransparency = 1
    iconLbl.Text = icon
    iconLbl.TextSize = 18
    iconLbl.Parent = row

    local nameLbl = Instance.new("TextLabel")
    nameLbl.Size = UDim2.new(0.45, 0, 1, 0)
    nameLbl.Position = UDim2.new(0, 38, 0, 0)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text = labelText
    nameLbl.TextColor3 = Color3.fromRGB(200, 210, 225)
    nameLbl.Font = Enum.Font.SourceSans
    nameLbl.TextSize = 14
    nameLbl.TextXAlignment = Enum.TextXAlignment.Left
    nameLbl.Parent = row

    local valLbl = Instance.new("TextLabel")
    valLbl.Name = "ValueLabel"
    valLbl.Size = UDim2.new(0.45, 0, 1, 0)
    valLbl.Position = UDim2.new(0.55, -8, 0, 0)
    valLbl.BackgroundTransparency = 1
    valLbl.Text = valueText
    valLbl.TextColor3 = color or Color3.fromRGB(255, 255, 255)
    valLbl.Font = Enum.Font.SourceSansBold
    valLbl.TextSize = 14
    valLbl.TextXAlignment = Enum.TextXAlignment.Right
    valLbl.Parent = row

    statRows[id] = valLbl
    return row
end

createStatRow("HP", "❤️", "พลังชีวิต (Health)", "100 / 100", Color3.fromRGB(255, 100, 100))
createStatRow("Chi", "🌀", "พลังปราณ (Chi/Mana)", "50 / 50 (+2/s)", Color3.fromRGB(85, 200, 255))
createStatRow("TapasyaRegen", "☯", "อัตราดูดซับตบะ (Passive)", "+10 แต้ม / วินาที", Color3.fromRGB(255, 215, 80))
createStatRow("Attack", "⚔️", "พลังโจมตี (Attack)", "10", Color3.fromRGB(255, 170, 80))
createStatRow("Defense", "🛡️", "พลังป้องกัน (Defense)", "0", Color3.fromRGB(150, 220, 255))
createStatRow("Speed", "🏃", "ความเร็วเดิน (WalkSpeed)", "16", Color3.fromRGB(140, 255, 140))
createStatRow("BreakthroughBuff", "💊", "บัฟโอสถเสริมทะลวง", "+0%", Color3.fromRGB(255, 170, 255))
createStatRow("Zone", "🗺️", "โซนที่ปลดล็อก", "หมู่บ้านปุถุชน", Color3.fromRGB(255, 230, 130))

rightCard.CanvasSize = UDim2.new(0, 0, 0, rcLayout.AbsoluteContentSize.Y + 20)

--------------------------------------------------------------------------------
-- 4. ฟังก์ชันอัปเดตข้อมูลสเตตัสในหน้าต่าง
--------------------------------------------------------------------------------
local function updateStatusUI()
    local char = localPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local realmIndex = localPlayer:GetAttribute("RealmIndex") or 1
    local realmData = GameConfig.Realms[realmIndex] or GameConfig.Realms[1]
    local stats = realmData.Stats

    local title = localPlayer:GetAttribute("Title") or realmData.Title
    titleBadge.Text = "« " .. tostring(title) .. " »"
    titleBadge.TextColor3 = realmData.Color or Color3.fromRGB(180, 180, 180)

    realmBadge.Text = "☯ ขอบเขต: " .. tostring(realmData.Name) .. " (ขั้นที่ " .. tostring(realmIndex) .. ")"
    realmBadge.TextColor3 = realmData.Color or Color3.fromRGB(85, 255, 127)

    -- HP
    local curHP = hum and math.floor(hum.Health) or stats.MaxHealth
    local maxHP = hum and math.floor(hum.MaxHealth) or stats.MaxHealth
    statRows["HP"].Text = string.format("%d / %d", curHP, maxHP)

    -- Chi
    local curChi = localPlayer:GetAttribute("Chi") or stats.MaxChi
    local maxChi = localPlayer:GetAttribute("MaxChi") or stats.MaxChi
    local chiRegen = localPlayer:GetAttribute("ChiRegen") or stats.ChiRegen
    statRows["Chi"].Text = string.format("%.0f / %.0f (+%d/s)", curChi, maxChi, chiRegen)

    -- Tapasya Regen
    local tapRegen = localPlayer:GetAttribute("TapasyaRegen") or stats.TapasyaRegen
    statRows["TapasyaRegen"].Text = string.format("+%d แต้ม / วินาที", tapRegen)

    -- Attack & Defense
    local atk = localPlayer:GetAttribute("AttackPower") or stats.AttackPower
    local def = localPlayer:GetAttribute("Defense") or stats.Defense
    statRows["Attack"].Text = tostring(atk)
    statRows["Defense"].Text = tostring(def)

    -- Speed
    local spd = hum and hum.WalkSpeed or stats.WalkSpeed
    statRows["Speed"].Text = tostring(spd)

    -- Buff
    local buff = (localPlayer:GetAttribute("BreakthroughBuff") or 0) * 100
    statRows["BreakthroughBuff"].Text = string.format("+%.0f%%", buff)

    -- Zone
    local zone = localPlayer:GetAttribute("UnlockedZone") or realmData.UnlockedZone
    statRows["Zone"].Text = tostring(zone)
end

local function toggleStatus()
    mainFrame.Visible = not mainFrame.Visible
    if mainFrame.Visible then
        updateStatusUI()
    end
end

toggleButton.MouseButton1Click:Connect(toggleStatus)
closeBtn.MouseButton1Click:Connect(function()
    mainFrame.Visible = false
end)

-- กดปุ่ม P เพื่อเปิด/ปิดหน้าต่างตัวละคร
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.P then
        toggleStatus()
    end
end)

-- อัปเดตสเตตัสแบบเรียลไทม์เมื่อมีการซิงก์
NetworkEvents.SyncCultivation.OnClientEvent:Connect(function()
    if mainFrame.Visible then
        updateStatusUI()
    end
end)

--------------------------------------------------------------------------------
-- 5. ป๊อปอัปแจ้งเตือนเมื่อสัมผัสม่านพลังที่ไม่สามารถผ่านได้ (Barrier Denied)
--------------------------------------------------------------------------------
local alertModal = Instance.new("Frame")
alertModal.Name = "BarrierAlert"
alertModal.Size = UDim2.new(0, 380, 0, 110)
alertModal.Position = UDim2.new(0.5, -190, 0.25, 0)
alertModal.BackgroundColor3 = Color3.fromRGB(30, 15, 18)
alertModal.BorderSizePixel = 0
alertModal.Visible = false
alertModal.ZIndex = 20
alertModal.Parent = screenGui

local amCorner = Instance.new("UICorner")
amCorner.CornerRadius = UDim.new(0, 10)
amCorner.Parent = alertModal

local amStroke = Instance.new("UIStroke")
amStroke.Thickness = 2
amStroke.Color = Color3.fromRGB(255, 80, 80)
amStroke.Parent = alertModal

local alertTitle = Instance.new("TextLabel")
alertTitle.Size = UDim2.new(1, 0, 0, 30)
alertTitle.Position = UDim2.new(0, 0, 0, 8)
alertTitle.BackgroundTransparency = 1
alertTitle.Text = "⛔ ค่ายกลม่านพลังปฏิเสธการเข้าถึง!"
alertTitle.TextColor3 = Color3.fromRGB(255, 100, 100)
alertTitle.Font = Enum.Font.SourceSansBold
alertTitle.TextSize = 18
alertTitle.ZIndex = 21
alertTitle.Parent = alertModal

local alertDesc = Instance.new("TextLabel")
alertDesc.Name = "AlertDesc"
alertDesc.Size = UDim2.new(1, -20, 0, 50)
alertDesc.Position = UDim2.new(0, 10, 0, 42)
alertDesc.BackgroundTransparency = 1
alertDesc.Text = "ต้องการขอบเขต [หลอมลมปราณ] ขึ้นไปเพื่อผ่านม่านพลังนี้"
alertDesc.TextColor3 = Color3.fromRGB(240, 220, 220)
alertDesc.Font = Enum.Font.SourceSans
alertDesc.TextSize = 15
alertDesc.TextWrapped = true
alertDesc.ZIndex = 21
alertDesc.Parent = alertModal

NetworkEvents.BarrierDenied.OnClientEvent:Connect(function(zone)
    alertDesc.Text = string.format("พื้นที่: %s\nต้องการขอบเขต [%s] ขึ้นไปจึงจะก้าวผ่านได้!", zone.Name, zone.RequiredRealm)
    alertModal.Visible = true

    task.delay(3, function()
        alertModal.Visible = false
    end)
end)

print("✅ [Client] Character Status UI (กด P หรือคลิก 👤) พร้อมทำงาน!")

