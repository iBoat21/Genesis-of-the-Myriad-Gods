--[[
    MerchantUI.client.lua
    UI ร้านค้า NPC เทวะ: ผู้อาวุโสชิง (หอโอสถ) และ ปรมาจารย์เถี่ย (หอศัสตราวุธ)
    - รองรับการซื้อวัตถุดิบสมุนไพร, เคียวตัดสมุนไพร, กระเป๋ามิติ, ยันต์คุ้มกายา
    - แท็บ 'ขายโอสถ': นำเม็ดยาที่หลอมเองมาขายแลกเป็นแต้มตบะ
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local GameConfig = require(ReplicatedStorage:WaitForChild("SharedModules"):WaitForChild("GameConfig"))
local NetworkEvents = require(ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("NetworkEvents"))

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MerchantGui"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

-- หน้าต่างหลักของร้านค้า
local shopFrame = Instance.new("Frame")
shopFrame.Name = "ShopFrame"
shopFrame.Size = UDim2.new(0, 520, 0, 480)
shopFrame.Position = UDim2.new(0.5, -260, 0.5, -240)
shopFrame.BackgroundColor3 = Color3.fromRGB(16, 20, 28)
shopFrame.BorderSizePixel = 0
shopFrame.Visible = false
shopFrame.ClipsDescendants = true
shopFrame.Parent = screenGui

local sCorner = Instance.new("UICorner")
sCorner.CornerRadius = UDim.new(0, 12)
sCorner.Parent = shopFrame

local sStroke = Instance.new("UIStroke")
sStroke.Thickness = 2
sStroke.Color = Color3.fromRGB(255, 215, 80)
sStroke.Parent = shopFrame

-- แถบหัวเรื่อง
local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 48)
header.BackgroundColor3 = Color3.fromRGB(24, 30, 44)
header.BorderSizePixel = 0
header.Parent = shopFrame

local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "ShopTitle"
titleLabel.Size = UDim2.new(0.8, 0, 1, 0)
titleLabel.Position = UDim2.new(0, 16, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "🏛️ ร้านค้า NPC เทวะ"
titleLabel.TextColor3 = Color3.fromRGB(255, 220, 90)
titleLabel.Font = Enum.Font.SourceSansBold
titleLabel.TextSize = 16
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = header

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 32, 0, 32)
closeBtn.Position = UDim2.new(1, -40, 0, 8)
closeBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
closeBtn.Text = "✕"
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.Font = Enum.Font.SourceSansBold
closeBtn.TextSize = 16
closeBtn.Parent = header

local cbCorner = Instance.new("UICorner")
cbCorner.CornerRadius = UDim.new(0, 6)
cbCorner.Parent = closeBtn

-- แท็บเลือกโหมด (ซื้อสินค้า / ขายโอสถ)
local tabFrame = Instance.new("Frame")
tabFrame.Size = UDim2.new(1, -24, 0, 36)
tabFrame.Position = UDim2.new(0, 12, 0, 56)
tabFrame.BackgroundTransparency = 1
tabFrame.Parent = shopFrame

local buyTabBtn = Instance.new("TextButton")
buyTabBtn.Size = UDim2.new(0.48, 0, 1, 0)
buyTabBtn.BackgroundColor3 = Color3.fromRGB(35, 75, 120)
buyTabBtn.Text = "🛒 ซื้อสินค้า & วัตถุดิบ"
buyTabBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
buyTabBtn.Font = Enum.Font.SourceSansBold
buyTabBtn.TextSize = 14
buyTabBtn.Parent = tabFrame

local btc = Instance.new("UICorner")
btc.CornerRadius = UDim.new(0, 6)
btc.Parent = buyTabBtn

local sellTabBtn = Instance.new("TextButton")
sellTabBtn.Size = UDim2.new(0.48, 0, 1, 0)
sellTabBtn.Position = UDim2.new(0.52, 0, 0, 0)
sellTabBtn.BackgroundColor3 = Color3.fromRGB(28, 34, 48)
sellTabBtn.Text = "💰 ขายโอสถวิเศษ (รับตบะ)"
sellTabBtn.TextColor3 = Color3.fromRGB(180, 200, 220)
sellTabBtn.Font = Enum.Font.SourceSansBold
sellTabBtn.TextSize = 14
sellTabBtn.Parent = tabFrame

local stc = Instance.new("UICorner")
stc.CornerRadius = UDim.new(0, 6)
stc.Parent = sellTabBtn

-- พื้นที่แสดงรายการไอเทม Scroll
local itemScroll = Instance.new("ScrollingFrame")
itemScroll.Size = UDim2.new(1, -24, 1, -110)
itemScroll.Position = UDim2.new(0, 12, 0, 98)
itemScroll.BackgroundTransparency = 1
itemScroll.BorderSizePixel = 0
itemScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
itemScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
itemScroll.Parent = shopFrame

local uil = Instance.new("UIListLayout")
uil.Padding = UDim.new(0, 8)
uil.Parent = itemScroll

local currentMerchantId = "ElderQing"
local currentTab = "Buy"

-- ฟังก์ชันแสดงรายการซื้อ
local function renderBuyItems()
    for _, child in ipairs(itemScroll:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end

    local merchantConfig = GameConfig.ShopConfig and GameConfig.ShopConfig[currentMerchantId]
    if not merchantConfig then return end

    titleLabel.Text = merchantConfig.Title

    for _, item in ipairs(merchantConfig.Items) do
        local card = Instance.new("Frame")
        card.Size = UDim2.new(1, 0, 0, 64)
        card.BackgroundColor3 = Color3.fromRGB(24, 30, 42)
        card.Parent = itemScroll

        local cc = Instance.new("UICorner")
        cc.CornerRadius = UDim.new(0, 8)
        cc.Parent = card

        local nameLbl = Instance.new("TextLabel")
        nameLbl.Size = UDim2.new(0.65, 0, 0.45, 0)
        nameLbl.Position = UDim2.new(0, 12, 0, 6)
        nameLbl.BackgroundTransparency = 1
        nameLbl.Text = item.Name
        nameLbl.TextColor3 = Color3.fromRGB(255, 230, 140)
        nameLbl.Font = Enum.Font.SourceSansBold
        nameLbl.TextSize = 14
        nameLbl.TextXAlignment = Enum.TextXAlignment.Left
        nameLbl.Parent = card

        local descLbl = Instance.new("TextLabel")
        descLbl.Size = UDim2.new(0.65, 0, 0.45, 0)
        descLbl.Position = UDim2.new(0, 12, 0, 32)
        descLbl.BackgroundTransparency = 1
        descLbl.Text = item.Description
        descLbl.TextColor3 = Color3.fromRGB(160, 180, 200)
        descLbl.Font = Enum.Font.SourceSans
        descLbl.TextSize = 11
        descLbl.TextXAlignment = Enum.TextXAlignment.Left
        descLbl.Parent = card

        local buyBtn = Instance.new("TextButton")
        buyBtn.Size = UDim2.new(0.28, 0, 0.65, 0)
        buyBtn.Position = UDim2.new(0.7, 0, 0.175, 0)
        buyBtn.BackgroundColor3 = Color3.fromRGB(45, 120, 75)
        buyBtn.Text = string.format("ซื้อ (%d ตบะ)", item.Price)
        buyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        buyBtn.Font = Enum.Font.SourceSansBold
        buyBtn.TextSize = 12
        buyBtn.Parent = card

        local bbc = Instance.new("UICorner")
        bbc.CornerRadius = UDim.new(0, 6)
        bbc.Parent = buyBtn

        buyBtn.MouseButton1Click:Connect(function()
            local success, msg = NetworkEvents.BuyShopItem:InvokeServer(currentMerchantId, item.Name)
            if success then
                buyBtn.Text = "✓ สำเร็จ!"
                task.delay(1, function() buyBtn.Text = string.format("ซื้อ (%d ตบะ)", item.Price) end)
            else
                buyBtn.Text = "❌ ตบะไม่พอ"
                task.delay(1, function() buyBtn.Text = string.format("ซื้อ (%d ตบะ)", item.Price) end)
            end
        end)
    end
end

-- ฟังก์ชันแสดงรายการขายโอสถ
local function renderSellItems()
    for _, child in ipairs(itemScroll:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end

    if not _G.DaoistDataManager then return end
    local inv = _G.DaoistDataManager.GetInventory(localPlayer)

    local pillCount = 0
    for itemName, count in pairs(inv) do
        if count > 0 and (string.find(itemName, "ยา") or string.find(itemName, "โอสถ")) then
            pillCount = pillCount + 1

            local card = Instance.new("Frame")
            card.Size = UDim2.new(1, 0, 0, 60)
            card.BackgroundColor3 = Color3.fromRGB(28, 32, 44)
            card.Parent = itemScroll

            local cc = Instance.new("UICorner")
            cc.CornerRadius = UDim.new(0, 8)
            cc.Parent = card

            local nameLbl = Instance.new("TextLabel")
            nameLbl.Size = UDim2.new(0.65, 0, 0.5, 0)
            nameLbl.Position = UDim2.new(0, 12, 0, 6)
            nameLbl.BackgroundTransparency = 1
            nameLbl.Text = string.format("💊 %s (มี x%d)", itemName, count)
            nameLbl.TextColor3 = Color3.fromRGB(150, 220, 255)
            nameLbl.Font = Enum.Font.SourceSansBold
            nameLbl.TextSize = 13
            nameLbl.TextXAlignment = Enum.TextXAlignment.Left
            nameLbl.Parent = card

            local sellBtn = Instance.new("TextButton")
            sellBtn.Size = UDim2.new(0.28, 0, 0.65, 0)
            sellBtn.Position = UDim2.new(0.7, 0, 0.175, 0)
            sellBtn.BackgroundColor3 = Color3.fromRGB(160, 95, 35)
            sellBtn.Text = "ขายโอสถ"
            sellBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
            sellBtn.Font = Enum.Font.SourceSansBold
            sellBtn.TextSize = 13
            sellBtn.Parent = card

            local sbc = Instance.new("UICorner")
            sbc.CornerRadius = UDim.new(0, 6)
            sbc.Parent = sellBtn

            sellBtn.MouseButton1Click:Connect(function()
                local success, msg = NetworkEvents.SellPillItem:InvokeServer(itemName)
                if success then
                    renderSellItems()
                end
            end)
        end
    end

    if pillCount == 0 then
        local empty = Instance.new("TextLabel")
        empty.Size = UDim2.new(1, 0, 0, 80)
        empty.BackgroundTransparency = 1
        empty.Text = "ไม่มีเม็ดยาโอสถในกระเป๋าที่จะขาย\n(หลอมโอสถที่เตาหลอมเก้ามังกรโกลาหลเพื่อสร้างโอสถวิเศษ)"
        empty.TextColor3 = Color3.fromRGB(150, 160, 180)
        empty.Font = Enum.Font.SourceSansItalic
        empty.TextSize = 14
        empty.Parent = itemScroll
    end
end

-- สลับแท็บ
buyTabBtn.MouseButton1Click:Connect(function()
    currentTab = "Buy"
    buyTabBtn.BackgroundColor3 = Color3.fromRGB(35, 75, 120)
    sellTabBtn.BackgroundColor3 = Color3.fromRGB(28, 34, 48)
    renderBuyItems()
end)

sellTabBtn.MouseButton1Click:Connect(function()
    currentTab = "Sell"
    sellTabBtn.BackgroundColor3 = Color3.fromRGB(35, 75, 120)
    buyTabBtn.BackgroundColor3 = Color3.fromRGB(28, 34, 48)
    renderSellItems()
end)

-- รับ Event เปิดร้านค้าจากเซิร์ฟเวอร์
NetworkEvents.OpenMerchantShop.OnClientEvent:Connect(function(merchantId)
    currentMerchantId = merchantId or "ElderQing"
    shopFrame.Visible = true
    currentTab = "Buy"
    buyTabBtn.BackgroundColor3 = Color3.fromRGB(35, 75, 120)
    sellTabBtn.BackgroundColor3 = Color3.fromRGB(28, 34, 48)
    sellTabBtn.Visible = (currentMerchantId == "ElderQing") -- เฉพาะผู้อาวุโสชิงที่รับซื้อโอสถ
    renderBuyItems()
end)

closeBtn.MouseButton1Click:Connect(function()
    shopFrame.Visible = false
end)

print("✅ [Client] Merchant Shop UI พร้อมทำงาน!")

