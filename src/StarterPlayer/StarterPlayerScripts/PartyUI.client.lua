--[[
    PartyUI.client.lua
    UI จัดการปาร์ตี้ (Party HUD & Management System)
    - แสดงสถานะและหลอดเลือดของเพื่อนร่วมปาร์ตี้แบบเรียลไทม์
    - รองรับ: สร้างปาร์ตี้, เชิญเพื่อน, ออกจากปาร์ตี้, เตะสมาชิก
    - หน้าต่างแจ้งเตือนคำเชิญเข้าปาร์ตี้ (Party Invitation Popup)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")
local NetworkEvents = require(ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("NetworkEvents"))

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "PartyGui"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

-- ปุ่มเปิด/ปิดหน้าต่างปาร์ตี้ลอยมุมซ้ายบน
local toggleBtn = Instance.new("TextButton")
toggleBtn.Name = "PartyToggleBtn"
toggleBtn.Size = UDim2.new(0, 110, 0, 36)
toggleBtn.Position = UDim2.new(0, 15, 0, 75)
toggleBtn.BackgroundColor3 = Color3.fromRGB(24, 30, 42)
toggleBtn.Text = "👥 ปาร์ตี้"
toggleBtn.TextColor3 = Color3.fromRGB(85, 200, 255)
toggleBtn.Font = Enum.Font.SourceSansBold
toggleBtn.TextSize = 14
toggleBtn.Parent = screenGui

local tCorner = Instance.new("UICorner")
tCorner.CornerRadius = UDim.new(0, 8)
tCorner.Parent = toggleBtn

local tStroke = Instance.new("UIStroke")
tStroke.Thickness = 1.5
tStroke.Color = Color3.fromRGB(85, 200, 255)
tStroke.Parent = toggleBtn

-- หน้าต่าง Party Window
local partyFrame = Instance.new("Frame")
partyFrame.Name = "PartyFrame"
partyFrame.Size = UDim2.new(0, 340, 0, 420)
partyFrame.Position = UDim2.new(0, 15, 0, 120)
partyFrame.BackgroundColor3 = Color3.fromRGB(18, 22, 30)
partyFrame.BorderSizePixel = 0
partyFrame.Visible = false
partyFrame.ClipsDescendants = true
partyFrame.Parent = screenGui

local fCorner = Instance.new("UICorner")
fCorner.CornerRadius = UDim.new(0, 10)
fCorner.Parent = partyFrame

local fStroke = Instance.new("UIStroke")
fStroke.Thickness = 2
fStroke.Color = Color3.fromRGB(85, 200, 255)
fStroke.Parent = partyFrame

-- Title
local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 40)
title.BackgroundColor3 = Color3.fromRGB(25, 32, 45)
title.Text = "🛡️ ระบบสหายร่วมรบ (Party)"
title.TextColor3 = Color3.fromRGB(85, 200, 255)
title.Font = Enum.Font.SourceSansBold
title.TextSize = 15
title.Parent = partyFrame

-- รายชื่อสมาชิก Scroll
local memberScroll = Instance.new("ScrollingFrame")
memberScroll.Size = UDim2.new(1, -20, 0, 240)
memberScroll.Position = UDim2.new(0, 10, 0, 50)
memberScroll.BackgroundTransparency = 1
memberScroll.BorderSizePixel = 0
memberScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
memberScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
memberScroll.Parent = partyFrame

local uil = Instance.new("UIListLayout")
uil.Padding = UDim.new(0, 6)
uil.Parent = memberScroll

-- ส่วนล่าง: ปุ่มการทำงาน
local bottomBar = Instance.new("Frame")
bottomBar.Size = UDim2.new(1, -20, 0, 115)
bottomBar.Position = UDim2.new(0, 10, 1, -125)
bottomBar.BackgroundTransparency = 1
bottomBar.Parent = partyFrame

local inviteInput = Instance.new("TextBox")
inviteInput.Size = UDim2.new(0.68, 0, 0, 32)
inviteInput.BackgroundColor3 = Color3.fromRGB(28, 35, 48)
inviteInput.PlaceholderText = "พิมพ์ชื่อผู้เล่น..."
inviteInput.Text = ""
inviteInput.TextColor3 = Color3.fromRGB(255, 255, 255)
inviteInput.Font = Enum.Font.SourceSans
inviteInput.TextSize = 13
inviteInput.Parent = bottomBar

local iCorner = Instance.new("UICorner")
iCorner.CornerRadius = UDim.new(0, 6)
iCorner.Parent = inviteInput

local inviteBtn = Instance.new("TextButton")
inviteBtn.Size = UDim2.new(0.3, 0, 0, 32)
inviteBtn.Position = UDim2.new(0.7, 0, 0, 0)
inviteBtn.BackgroundColor3 = Color3.fromRGB(40, 110, 70)
inviteBtn.Text = "เชิญ"
inviteBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
inviteBtn.Font = Enum.Font.SourceSansBold
inviteBtn.TextSize = 13
inviteBtn.Parent = bottomBar

local ibCorner = Instance.new("UICorner")
ibCorner.CornerRadius = UDim.new(0, 6)
ibCorner.Parent = inviteBtn

local createPartyBtn = Instance.new("TextButton")
createPartyBtn.Size = UDim2.new(1, 0, 0, 34)
createPartyBtn.Position = UDim2.new(0, 0, 0, 38)
createPartyBtn.BackgroundColor3 = Color3.fromRGB(35, 80, 130)
createPartyBtn.Text = "✨ สร้างปาร์ตี้ใหม่"
createPartyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
createPartyBtn.Font = Enum.Font.SourceSansBold
createPartyBtn.TextSize = 14
createPartyBtn.Parent = bottomBar

local cpCorner = Instance.new("UICorner")
cpCorner.CornerRadius = UDim.new(0, 6)
cpCorner.Parent = createPartyBtn

local leavePartyBtn = Instance.new("TextButton")
leavePartyBtn.Size = UDim2.new(1, 0, 0, 34)
leavePartyBtn.Position = UDim2.new(0, 0, 0, 78)
leavePartyBtn.BackgroundColor3 = Color3.fromRGB(140, 45, 45)
leavePartyBtn.Text = "🚪 ออกจากปาร์ตี้"
leavePartyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
leavePartyBtn.Font = Enum.Font.SourceSansBold
leavePartyBtn.TextSize = 14
leavePartyBtn.Visible = false
leavePartyBtn.Parent = bottomBar

local lpCorner = Instance.new("UICorner")
lpCorner.CornerRadius = UDim.new(0, 6)
lpCorner.Parent = leavePartyBtn

-- ฟังก์ชันอัปเดตสมาชิกในหน้าต่าง
local currentPartyMembers = {}

local function renderPartyList(partyId, members)
    currentPartyMembers = members or {}
    for _, child in ipairs(memberScroll:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end

    if not partyId or #currentPartyMembers == 0 then
        createPartyBtn.Visible = true
        leavePartyBtn.Visible = false
        inviteBtn.Visible = false
        inviteInput.Visible = false

        local emptyLabel = Instance.new("TextLabel")
        emptyLabel.Size = UDim2.new(1, 0, 0, 60)
        emptyLabel.BackgroundTransparency = 1
        emptyLabel.Text = "คุณยังไม่มีสหายร่วมรบ\nคลิก 'สร้างปาร์ตี้ใหม่' เพื่อเริ่มทีม"
        emptyLabel.TextColor3 = Color3.fromRGB(150, 160, 175)
        emptyLabel.Font = Enum.Font.SourceSansItalic
        emptyLabel.TextSize = 14
        emptyLabel.Parent = memberScroll
        return
    end

    createPartyBtn.Visible = false
    leavePartyBtn.Visible = true
    inviteBtn.Visible = true
    inviteInput.Visible = true

    for _, member in ipairs(currentPartyMembers) do
        local mCard = Instance.new("Frame")
        mCard.Size = UDim2.new(1, 0, 0, 48)
        mCard.BackgroundColor3 = Color3.fromRGB(24, 30, 40)
        mCard.Parent = memberScroll

        local mcCorner = Instance.new("UICorner")
        mcCorner.CornerRadius = UDim.new(0, 6)
        mcCorner.Parent = mCard

        local mName = Instance.new("TextLabel")
        mName.Size = UDim2.new(0.65, 0, 0.45, 0)
        mName.Position = UDim2.new(0, 10, 0, 4)
        mName.BackgroundTransparency = 1
        mName.Text = (member.IsLeader and "👑 " or "👤 ") .. member.DisplayName
        mName.TextColor3 = member.IsLeader and Color3.fromRGB(255, 215, 80) or Color3.fromRGB(220, 235, 255)
        mName.Font = Enum.Font.SourceSansBold
        mName.TextSize = 13
        mName.TextXAlignment = Enum.TextXAlignment.Left
        mName.Parent = mCard

        -- แถบเลือด HP Bar
        local hpBg = Instance.new("Frame")
        hpBg.Size = UDim2.new(0.65, 0, 0, 8)
        hpBg.Position = UDim2.new(0, 10, 0, 28)
        hpBg.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
        hpBg.BorderSizePixel = 0
        hpBg.Parent = mCard

        local hpFill = Instance.new("Frame")
        local hpPercent = math.clamp(member.Health / math.max(1, member.MaxHealth), 0, 1)
        hpFill.Size = UDim2.new(hpPercent, 0, 1, 0)
        hpFill.BackgroundColor3 = Color3.fromRGB(85, 255, 127)
        hpFill.BorderSizePixel = 0
        hpFill.Parent = hpBg

        local hpLabel = Instance.new("TextLabel")
        hpLabel.Size = UDim2.new(0.3, 0, 0, 20)
        hpLabel.Position = UDim2.new(0.68, 0, 0, 22)
        hpLabel.BackgroundTransparency = 1
        hpLabel.Text = string.format("%.0f/%.0f", member.Health, member.MaxHealth)
        hpLabel.TextColor3 = Color3.fromRGB(180, 200, 220)
        hpLabel.Font = Enum.Font.SourceSans
        hpLabel.TextSize = 10
        hpLabel.Parent = mCard
    end
end

-- รับข้อมูลซิงค์ปาร์ตี้จากเซิร์ฟเวอร์
NetworkEvents.SyncParty.OnClientEvent:Connect(function(partyId, members)
    renderPartyList(partyId, members)
end)

-- ปุ่มคลิกต่างๆ
toggleBtn.MouseButton1Click:Connect(function()
    partyFrame.Visible = not partyFrame.Visible
end)

createPartyBtn.MouseButton1Click:Connect(function()
    NetworkEvents.CreateParty:InvokeServer()
end)

leavePartyBtn.MouseButton1Click:Connect(function()
    NetworkEvents.LeaveParty:InvokeServer()
end)

inviteBtn.MouseButton1Click:Connect(function()
    if inviteInput.Text ~= "" then
        NetworkEvents.InviteToParty:InvokeServer(inviteInput.Text)
        inviteInput.Text = ""
    end
end)

-- หน้าต่าง Popup แจ้งเตือนเมื่อมีคนเชิญเข้าปาร์ตี้
NetworkEvents.PartyInviteReceived.OnClientEvent:Connect(function(leaderName, partyId)
    local popup = Instance.new("Frame")
    popup.Size = UDim2.new(0, 320, 0, 120)
    popup.Position = UDim2.new(0.5, -160, 0.35, 0)
    popup.BackgroundColor3 = Color3.fromRGB(20, 25, 35)
    popup.Parent = screenGui

    local pCorner = Instance.new("UICorner")
    pCorner.CornerRadius = UDim.new(0, 10)
    pCorner.Parent = popup

    local pStroke = Instance.new("UIStroke")
    pStroke.Thickness = 2
    pStroke.Color = Color3.fromRGB(85, 200, 255)
    pStroke.Parent = popup

    local msg = Instance.new("TextLabel")
    msg.Size = UDim2.new(1, -20, 0, 50)
    msg.Position = UDim2.new(0, 10, 0, 10)
    msg.BackgroundTransparency = 1
    msg.Text = string.format("✉️ %s เชิญคุณเข้าร่วมปาร์ตี้!", leaderName)
    msg.TextColor3 = Color3.fromRGB(255, 255, 255)
    msg.Font = Enum.Font.SourceSansBold
    msg.TextSize = 14
    msg.Parent = popup

    local acceptBtn = Instance.new("TextButton")
    acceptBtn.Size = UDim2.new(0.45, 0, 0, 32)
    acceptBtn.Position = UDim2.new(0.04, 0, 0, 70)
    acceptBtn.BackgroundColor3 = Color3.fromRGB(40, 140, 70)
    acceptBtn.Text = "✓ ยอมรับ"
    acceptBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    acceptBtn.Font = Enum.Font.SourceSansBold
    acceptBtn.Parent = popup

    local declineBtn = Instance.new("TextButton")
    declineBtn.Size = UDim2.new(0.45, 0, 0, 32)
    declineBtn.Position = UDim2.new(0.51, 0, 0, 70)
    declineBtn.BackgroundColor3 = Color3.fromRGB(150, 45, 45)
    declineBtn.Text = "✕ ปฏิเสธ"
    declineBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    declineBtn.Font = Enum.Font.SourceSansBold
    declineBtn.Parent = popup

    local function closePopup()
        popup:Destroy()
    end

    acceptBtn.MouseButton1Click:Connect(function()
        NetworkEvents.AcceptPartyInvite:InvokeServer(partyId)
        closePopup()
    end)

    declineBtn.MouseButton1Click:Connect(closePopup)
    task.delay(15, function()
        if popup and popup.Parent then closePopup() end
    end)
end)

print("✅ [Client] Party UI & Teammate HUD พร้อมทำงาน!")

