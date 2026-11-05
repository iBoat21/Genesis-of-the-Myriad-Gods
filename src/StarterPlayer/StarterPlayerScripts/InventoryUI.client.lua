local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local NetworkEvents = require(ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("NetworkEvents"))

-- สร้าง ScreenGui
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "InventoryGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

-- สร้าง Frame หลัก
local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 400, 0, 300)
mainFrame.Position = UDim2.new(0.5, -200, 0.5, -150)
mainFrame.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
mainFrame.BorderSizePixel = 0
mainFrame.Visible = false
mainFrame.Parent = screenGui

-- ใส่ UICorner ให้โค้งมน
local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(0, 10)
uiCorner.Parent = mainFrame

-- หัวข้อ (Title)
local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, 0, 0, 40)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "กระเป๋าสัมภาระ (Inventory)"
titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
titleLabel.TextSize = 20
titleLabel.Font = Enum.Font.SourceSansBold
titleLabel.Parent = mainFrame

-- ScrollingFrame สำหรับรายการไอเทม
local itemList = Instance.new("ScrollingFrame")
itemList.Name = "ItemList"
itemList.Size = UDim2.new(0.9, 0, 0.7, 0)
itemList.Position = UDim2.new(0.05, 0, 0.2, 0)
itemList.BackgroundTransparency = 0.9
itemList.CanvasSize = UDim2.new(0, 0, 0, 0)
itemList.ScrollBarThickness = 6
itemList.Parent = mainFrame

local uiListLayout = Instance.new("UIListLayout")
uiListLayout.Padding = UDim.new(0, 5)
uiListLayout.SortOrder = Enum.SortOrder.LayoutOrder
uiListLayout.Parent = itemList

-- แม่แบบ (Template) สำหรับแต่ละไอเทม
local function createItemEntry(name, count)
    local itemFrame = Instance.new("Frame")
    itemFrame.Name = name
    itemFrame.Size = UDim2.new(1, -10, 0, 40)
    itemFrame.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(0.7, 0, 1, 0)
    nameLabel.Position = UDim2.new(0.05, 0, 0, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = name
    nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.Font = Enum.Font.SourceSans
    nameLabel.TextSize = 18
    nameLabel.Parent = itemFrame

    local countLabel = Instance.new("TextLabel")
    countLabel.Size = UDim2.new(0.2, 0, 1, 0)
    countLabel.Position = UDim2.new(0.75, 0, 0, 0)
    countLabel.BackgroundTransparency = 1
    countLabel.Text = "x" .. tostring(count)
    countLabel.TextColor3 = Color3.fromRGB(0, 255, 127)
    countLabel.TextXAlignment = Enum.TextXAlignment.Right
    countLabel.Font = Enum.Font.SourceSansBold
    countLabel.TextSize = 18
    countLabel.Parent = itemFrame

    local entryCorner = Instance.new("UICorner")
    entryCorner.CornerRadius = UDim.new(0, 5)
    entryCorner.Parent = itemFrame

    return itemFrame
end

-- ฟังก์ชันอัปเดต UI เมื่อข้อมูลเปลี่ยน
local function updateInventoryUI(inventory)
    -- ล้างข้อมูลเก่า
    for _, child in ipairs(itemList:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end

    -- ใส่ข้อมูลใหม่
    for name, count in pairs(inventory) do
        if count > 0 then
            local itemEntry = createItemEntry(name, count)
            itemEntry.Parent = itemList
        end
    end
    
    -- ปรับขนาด Canvas อัตโนมัติ
    itemList.CanvasSize = UDim2.new(0, 0, 0, uiListLayout.AbsoluteContentSize.Y)
end

-- เชื่อมต่อ RemoteEvent
NetworkEvents.UpdateInventory.OnClientEvent:Connect(updateInventoryUI)

-- ขอข้อมูลครั้งแรกเมื่อโหลดเสร็จ
NetworkEvents.RequestInitialData:FireServer()

-- ปุ่มเปิด/ปิด (Hotkeys)
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.B then -- เปลี่ยนเป็นปุ่ม B
        mainFrame.Visible = not mainFrame.Visible
    end
end)

-- ปุ่มเปิด/ปิด สำหรับหน้าจอ (Mobile Friendly Button)
local toggleButton = Instance.new("TextButton")
toggleButton.Name = "ToggleInventory"
toggleButton.Size = UDim2.new(0, 50, 0, 50)
toggleButton.Position = UDim2.new(1, -60, 0.5, -25)
toggleButton.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
toggleButton.Text = "🎒"
toggleButton.TextSize = 30
toggleButton.Parent = screenGui

local btnCorner = Instance.new("UICorner")
btnCorner.CornerRadius = UDim.new(0, 25)
btnCorner.Parent = toggleButton

toggleButton.MouseButton1Click:Connect(function()
    mainFrame.Visible = not mainFrame.Visible
end)

print("✅ Inventory UI Initialized (Press 'B' or click 🎒 to open)")
