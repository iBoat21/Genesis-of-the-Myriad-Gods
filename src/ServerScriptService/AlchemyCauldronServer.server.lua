--[[
    AlchemyCauldronServer.server.lua
    จัดการการสปอนเตาหลอมโอสถส่วนตัว (Personal Spirit Cauldron) เมื่อผู้เล่นเริ่มหลอมยา
    และประมวลผลการหลอมยาอิสระ (Dynamic Alchemy) ร่วมกับมินิเกม
]]

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local NetworkEvents = require(ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("NetworkEvents"))
local AlchemyManager = require(ServerScriptService:WaitForChild("AlchemyManager"))

local PersonalCauldrons = {}

-- ฟังก์ชันสปอนเตาหลอมโอสถเฉพาะตัวตรงหน้าผู้เล่น (Spawn on Demand)
local function spawnPersonalCauldron(player)
    local char = player.Character
    if not char then return false, "ไม่พบตัวละคร" end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return false, "ไม่พบ HumanoidRootPart" end

    -- ลบเตาหลอมเก่าออกหากมีอยู่
    if PersonalCauldrons[player.UserId] then
        PersonalCauldrons[player.UserId]:Destroy()
        PersonalCauldrons[player.UserId] = nil
    end

    local cauldronModel = Instance.new("Model")
    cauldronModel.Name = "SpiritCauldron_" .. player.Name
    cauldronModel.Parent = Workspace

    -- ตำแหน่งด้านหน้าผู้เล่น 4.5 Studs และลอยขึ้นเล็กน้อย
    local spawnCFrame = root.CFrame * CFrame.new(0, -0.2, -4.5) * CFrame.Angles(0, math.rad(180), 0)

    -- ฐานเตาหลอมทองสัมฤทธิ์
    local base = Instance.new("Part")
    base.Name = "CauldronBase"
    base.Shape = Enum.PartType.Cylinder
    base.Size = Vector3.new(2.8, 3.8, 3.8)
    base.CFrame = spawnCFrame * CFrame.Angles(0, 0, math.rad(90))
    base.Color = Color3.fromRGB(120, 80, 50)
    base.Material = Enum.Material.CorrodedMetal
    base.Anchored = true
    base.CanCollide = false
    base.Parent = cauldronModel

    -- ปากเตาหลอมสีทองเรืองแสง
    local rim = Instance.new("Part")
    rim.Name = "CauldronRim"
    rim.Shape = Enum.PartType.Cylinder
    rim.Size = Vector3.new(0.8, 4.2, 4.2)
    rim.CFrame = (spawnCFrame * CFrame.new(0, 1.4, 0)) * CFrame.Angles(0, 0, math.rad(90))
    rim.Color = Color3.fromRGB(240, 180, 50)
    rim.Material = Enum.Material.Neon
    rim.Anchored = true
    rim.CanCollide = false
    rim.Parent = cauldronModel

    -- เปลวเพลิงวิญญาณโอสถ (Spirit Flame)
    local flamePart = Instance.new("Part")
    flamePart.Name = "SpiritFlame"
    flamePart.Size = Vector3.new(0.5, 0.5, 0.5)
    flamePart.CFrame = spawnCFrame * CFrame.new(0, 1.8, 0)
    flamePart.Transparency = 1
    flamePart.Anchored = true
    flamePart.CanCollide = false
    flamePart.Parent = cauldronModel

    local fire = Instance.new("Fire")
    fire.Color = Color3.fromRGB(85, 255, 180)
    fire.SecondaryColor = Color3.fromRGB(255, 220, 80)
    fire.Heat = 12
    fire.Size = 5
    fire.Parent = flamePart

    local light = Instance.new("PointLight")
    light.Color = Color3.fromRGB(85, 255, 180)
    light.Range = 16
    light.Brightness = 4
    light.Parent = flamePart

    -- ป้ายชื่อเตาหลอม
    local bill = Instance.new("BillboardGui")
    bill.Size = UDim2.new(0, 180, 0, 40)
    bill.StudsOffset = Vector3.new(0, 2.8, 0)
    bill.AlwaysOnTop = true
    bill.Parent = flamePart

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, 0, 1, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = "🔥 เตาหลอมโอสถแห่งจิต"
    nameLabel.TextColor3 = Color3.fromRGB(255, 215, 80)
    nameLabel.Font = Enum.Font.SourceSansBold
    nameLabel.TextSize = 17
    nameLabel.Parent = bill

    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 1.5
    stroke.Color = Color3.fromRGB(0, 0, 0)
    stroke.Parent = nameLabel

    PersonalCauldrons[player.UserId] = cauldronModel
    print("🔥 [Alchemy] สปอนเตาหลอมโอสถส่วนตัวให้: " .. player.DisplayName)
    return true
end

-- ฟังก์ชันสลายเตาหลอมโอสถ (Dismiss Cauldron)
local function dismissPersonalCauldron(player)
    local cauldron = PersonalCauldrons[player.UserId]
    if cauldron then
        cauldron:Destroy()
        PersonalCauldrons[player.UserId] = nil
        print("💨 [Alchemy] สลายเตาหลอมโอสถของ: " .. player.DisplayName)
    end
    return true
end

-- ผู้เล่นออกจากเกม -> ลบเตาหลอม
Players.PlayerRemoving:Connect(function(player)
    dismissPersonalCauldron(player)
end)

-- รีโมทสปอนและสลายเตาหลอมตามสั่ง
NetworkEvents.SpawnPersonalCauldron.OnServerInvoke = function(player)
    return spawnPersonalCauldron(player)
end

NetworkEvents.DismissPersonalCauldron.OnServerInvoke = function(player)
    return dismissPersonalCauldron(player)
end

-- รีโมทหลอมโอสถแบบอิสระพร้อมมินิเกม
NetworkEvents.CraftDynamicPill.OnServerInvoke = function(player, ingredients, minigameScore)
    return AlchemyManager:CraftDynamicPill(player, ingredients, minigameScore)
end

-- รีโมทกิน/ใช้โอสถ
NetworkEvents.UsePill.OnServerInvoke = function(player, pillName)
    return AlchemyManager:UsePill(player, pillName)
end

print("✅ [Server] ระบบเตาหลอมโอสถตามสั่ง (Spawn on Demand) พร้อมทำงาน!")
