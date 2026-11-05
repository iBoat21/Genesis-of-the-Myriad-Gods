--[[
    HerbCompendiumUI.client.lua
    หน้าต่างสารานุกรมสมุดรวมสมุนไพรทั้ง 100 ชนิด (Herb Compendium)
    - สามารถเปิดได้จากปุ่มในหน้าต่างเตาหลอมโอสถ หรือกดปุ่ม 'J'
    - กรองตามระดับขั้น (ร้อยปี / พันปี / หมื่นปี / แสนปี / ล้านปี / ระดับเทพ)
    - ค้นหาตามชื่อ, ธาตุ, สภาพอากาศ, และเวลาเก็บเกี่ยว
    - แสดงจำนวนที่มีในย่ามปัจจุบัน
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local HerbDatabase = require(ReplicatedStorage:WaitForChild("SharedModules"):WaitForChild("HerbDatabase"))
local NetworkEvents = require(ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("NetworkEvents"))

-- สร้าง ScreenGui
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "HerbCompendiumGui"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

local currentFilterTier = 0 -- 0 = ทั้งหมด, 1-6
local searchQuery = ""
local playerInventory = {}

--------------------------------------------------------------------------------
-- 1. หน้าต่างหลักสารานุกรม (Compendium Frame)
--------------------------------------------------------------------------------
local mainFrame = Instance.new("Frame")
mainFrame.Name = "CompendiumFrame"
mainFrame.Size = UDim2.new(0, 760, 0, 520)
mainFrame.Position = UDim2.new(0.5, -380, 0.5, -260)
mainFrame.BackgroundColor3 = Color3.fromRGB(20, 24, 30)
mainFrame.BorderSizePixel = 0
mainFrame.Visible = false
mainFrame.ClipsDescendants = true
mainFrame.Parent = screenGui

local frameCorner = Instance.new("UICorner")
frameCorner.CornerRadius = UDim.new(0, 14)
frameCorner.Parent = mainFrame

local frameStroke = Instance.new("UIStroke")
frameStroke.Thickness = 2
frameStroke.Color = Color3.fromRGB(85, 255, 127)
frameStroke.Parent = mainFrame

-- Title Bar
local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 42)
titleBar.BackgroundColor3 = Color3.fromRGB(28, 35, 45)
titleBar.BorderSizePixel = 0
titleBar.Parent = mainFrame

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(0.7, 0, 1, 0)
titleLabel.Position = UDim2.new(0, 16, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "📖 สารานุกรมสมุนไพรฟ้าดิน (สมุดรวม 100 ชนิด)"
titleLabel.TextColor3 = Color3.fromRGB(150, 255, 180)
titleLabel.Font = Enum.Font.SourceSansBold
titleLabel.TextSize = 18
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = titleBar

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 32, 0, 30)
closeBtn.Position = UDim2.new(1, -40, 0, 6)
closeBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
closeBtn.Text = "✕"
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.Font = Enum.Font.SourceSansBold
closeBtn.TextSize = 16
closeBtn.Parent = titleBar

local cbCorner = Instance.new("UICorner")
cbCorner.CornerRadius = UDim.new(0, 6)
cbCorner.Parent = closeBtn

-- Search Bar & Filter Tabs Row
local filterBar = Instance.new("Frame")
filterBar.Size = UDim2.new(1, -30, 0, 36)
filterBar.Position = UDim2.new(0, 15, 0, 48)
filterBar.BackgroundTransparency = 1
filterBar.Parent = mainFrame

local searchBox = Instance.new("TextBox")
searchBox.Size = UDim2.new(0.32, 0, 1, 0)
searchBox.BackgroundColor3 = Color3.fromRGB(30, 36, 48)
searchBox.PlaceholderText = "🔍 ค้นหาชื่อสมุนไพรหรือธาตุ..."
searchBox.PlaceholderColor3 = Color3.fromRGB(130, 145, 165)
searchBox.TextColor3 = Color3.fromRGB(255, 255, 255)
searchBox.Font = Enum.Font.SourceSans
searchBox.TextSize = 14
searchBox.ClearTextOnFocus = false
searchBox.Parent = filterBar

local sbCorner = Instance.new("UICorner")
sbCorner.CornerRadius = UDim.new(0, 6)
sbCorner.Parent = searchBox

-- แถบปุ่มกรองระดับ (Tier Buttons)
local tierScroll = Instance.new("ScrollingFrame")
tierScroll.Size = UDim2.new(0.66, 0, 1, 0)
tierScroll.Position = UDim2.new(0.34, 0, 0, 0)
tierScroll.BackgroundTransparency = 1
tierScroll.ScrollBarThickness = 2
tierScroll.CanvasSize = UDim2.new(0, 640, 0, 0)
tierScroll.Parent = filterBar

local tsLayout = Instance.new("UIListLayout")
tsLayout.FillDirection = Enum.FillDirection.Horizontal
tsLayout.Padding = UDim.new(0, 6)
tsLayout.SortOrder = Enum.SortOrder.LayoutOrder
tsLayout.Parent = tierScroll

-- รายการสมุนไพร (Herb List Scroll)
local herbList = Instance.new("ScrollingFrame")
herbList.Size = UDim2.new(1, -30, 1, -96)
herbList.Position = UDim2.new(0, 15, 0, 90)
herbList.BackgroundColor3 = Color3.fromRGB(15, 17, 24)
herbList.BorderSizePixel = 0
herbList.ScrollBarThickness = 6
herbList.CanvasSize = UDim2.new(0, 0, 0, 0)
herbList.Parent = mainFrame

local hlCorner = Instance.new("UICorner")
hlCorner.CornerRadius = UDim.new(0, 8)
hlCorner.Parent = herbList

local hlLayout = Instance.new("UIListLayout")
hlLayout.Padding = UDim.new(0, 8)
hlLayout.SortOrder = Enum.SortOrder.LayoutOrder
hlLayout.Parent = herbList

local hlPadding = Instance.new("UIPadding")
hlPadding.PaddingTop = UDim.new(0, 8)
hlPadding.PaddingBottom = UDim.new(0, 8)
hlPadding.PaddingLeft = UDim.new(0, 8)
hlPadding.PaddingRight = UDim.new(0, 8)
hlPadding.Parent = herbList

--------------------------------------------------------------------------------
-- 2. ฟังก์ชันแสดงผลและค้นหาสมุนไพร
--------------------------------------------------------------------------------
local function renderHerbList()
    for _, child in ipairs(herbList:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end

    local countShown = 0
    local q = string.lower(searchQuery)

    for _, herb in ipairs(HerbDatabase.GetAll()) do
        -- กรองตาม Tier
        local matchTier = (currentFilterTier == 0) or (herb.Tier == currentFilterTier)

        -- กรองตามคำค้นหา
        local matchSearch = (q == "") or string.find(string.lower(herb.Name), q)
            or string.find(string.lower(herb.Element), q)
            or string.find(string.lower(herb.Habitat), q)

        if matchTier and matchSearch then
            countShown = countShown + 1

            local card = Instance.new("Frame")
            card.Name = herb.Name
            card.Size = UDim2.new(1, 0, 0, 88)
            card.BackgroundColor3 = Color3.fromRGB(24, 28, 38)
            card.BorderSizePixel = 0
            card.Parent = herbList

            local cCorner = Instance.new("UICorner")
            cCorner.CornerRadius = UDim.new(0, 8)
            cCorner.Parent = card

            local cStroke = Instance.new("UIStroke")
            cStroke.Thickness = 1
            cStroke.Color = herb.Color or Color3.fromRGB(70, 80, 95)
            cStroke.Parent = card

            -- แถวบน: ลำดับ + ชื่อสมุนไพร + ระดับขั้น + ธาตุ
            local titleTxt = Instance.new("TextLabel")
            titleTxt.Size = UDim2.new(0.7, 0, 0, 24)
            titleTxt.Position = UDim2.new(0, 10, 0, 6)
            titleTxt.BackgroundTransparency = 1
            titleTxt.Text = string.format("#%03d  %s  [%s]", herb.Id, herb.Name, herb.TierName)
            titleTxt.TextColor3 = herb.Color or Color3.fromRGB(255, 255, 255)
            titleTxt.Font = Enum.Font.SourceSansBold
            titleTxt.TextSize = 16
            titleTxt.TextXAlignment = Enum.TextXAlignment.Left
            titleTxt.Parent = card

            -- จำนวนในย่าม
            local ownedCount = playerInventory[herb.Name] or 0
            local ownedBadge = Instance.new("TextLabel")
            ownedBadge.Size = UDim2.new(0.28, 0, 0, 24)
            ownedBadge.Position = UDim2.new(0.7, 0, 0, 6)
            ownedBadge.BackgroundTransparency = 1
            ownedBadge.Text = (ownedCount > 0) and string.format("🎒 ในย่าม: x%d", ownedCount) or "🎒 ยังไม่มี"
            ownedBadge.TextColor3 = (ownedCount > 0) and Color3.fromRGB(85, 255, 127) or Color3.fromRGB(140, 145, 160)
            ownedBadge.Font = Enum.Font.SourceSansBold
            ownedBadge.TextSize = 14
            ownedBadge.TextXAlignment = Enum.TextXAlignment.Right
            ownedBadge.Parent = card

            -- แถวกลาง: ถิ่นกำเนิด & สภาพอากาศ
            local locTxt = Instance.new("TextLabel")
            locTxt.Size = UDim2.new(1, -20, 0, 20)
            locTxt.Position = UDim2.new(0, 10, 0, 32)
            locTxt.BackgroundTransparency = 1
            locTxt.Text = string.format("🏞️ แหล่งที่พบ: %s  |  🌦️ สภาพอากาศ: %s", herb.Habitat, herb.Weather)
            locTxt.TextColor3 = Color3.fromRGB(180, 195, 215)
            locTxt.Font = Enum.Font.SourceSans
            locTxt.TextSize = 13
            locTxt.TextXAlignment = Enum.TextXAlignment.Left
            locTxt.Parent = card

            -- แถวล่าง: เวลาที่เหมาะสม + ธาตุ + ฤทธิ์ยา
            local statTxt = Instance.new("TextLabel")
            statTxt.Size = UDim2.new(1, -20, 0, 20)
            statTxt.Position = UDim2.new(0, 10, 0, 56)
            statTxt.BackgroundTransparency = 1
            statTxt.Text = string.format("⏰ เวลาเก็บเกี่ยว: %s  |  ⚡ ธาตุ: %s  |  ✨ ฤทธิ์ยา: +%d", herb.BestTime, herb.Element, herb.Potency)
            statTxt.TextColor3 = Color3.fromRGB(255, 215, 100)
            statTxt.Font = Enum.Font.SourceSansItalic
            statTxt.TextSize = 13
            statTxt.TextXAlignment = Enum.TextXAlignment.Left
            statTxt.Parent = card
        end
    end

    herbList.CanvasSize = UDim2.new(0, 0, 0, hlLayout.AbsoluteContentSize.Y + 20)
end

-- สร้างปุ่มกรองระดับ 0 ถึง 6
local tierFilters = {
    {Tier = 0, Name = "ทั้งหมด (100)"},
    {Tier = 1, Name = "ร้อยปี (20)"},
    {Tier = 2, Name = "พันปี (20)"},
    {Tier = 3, Name = "หมื่นปี (20)"},
    {Tier = 4, Name = "แสนปี (20)"},
    {Tier = 5, Name = "ล้านปี (10)"},
    {Tier = 6, Name = "ระดับเทพ (10)"},
}

for _, tf in ipairs(tierFilters) do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 95, 1, 0)
    btn.BackgroundColor3 = (currentFilterTier == tf.Tier) and Color3.fromRGB(50, 150, 90) or Color3.fromRGB(35, 40, 52)
    btn.Text = tf.Name
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Font = Enum.Font.SourceSansBold
    btn.TextSize = 13
    btn.Parent = tierScroll

    local bCorner = Instance.new("UICorner")
    bCorner.CornerRadius = UDim.new(0, 6)
    bCorner.Parent = btn

    btn.MouseButton1Click:Connect(function()
        currentFilterTier = tf.Tier
        for _, other in ipairs(tierScroll:GetChildren()) do
            if other:IsA("TextButton") then other.BackgroundColor3 = Color3.fromRGB(35, 40, 52) end
        end
        btn.BackgroundColor3 = Color3.fromRGB(50, 150, 90)
        renderHerbList()
    end)
end

searchBox:GetPropertyChangedSignal("Text"):Connect(function()
    searchQuery = searchBox.Text
    renderHerbList()
end)

--------------------------------------------------------------------------------
-- 3. การเปิด/ปิดหน้าต่าง
--------------------------------------------------------------------------------
local function toggleCompendium()
    mainFrame.Visible = not mainFrame.Visible
    if mainFrame.Visible then
        renderHerbList()
    end
end

closeBtn.MouseButton1Click:Connect(function()
    mainFrame.Visible = false
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.J then
        toggleCompendium()
    end
end)

NetworkEvents.UpdateInventory.OnClientEvent:Connect(function(inv)
    playerInventory = inv or {}
    if mainFrame.Visible then
        renderHerbList()
    end
end)

-- ส่งฟังก์ชันให้ภายนอกเรียกเปิดได้ (เช่น จากปุ่มใน AlchemyUI)
_G.OpenHerbCompendium = function()
    mainFrame.Visible = true
    renderHerbList()
end

print("✅ [Client] Herb Compendium UI (สมุดรวมสมุนไพร 100 ชนิด [J]) พร้อมทำงาน!")

