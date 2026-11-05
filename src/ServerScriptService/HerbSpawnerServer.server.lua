--[[
    HerbSpawnerServer.server.lua
    ระบบสุ่มเกิดสมุนไพรในโลกยุทธภพตามระบบสารานุกรม 100 ชนิด
    รองรับการกระจายความหายากตามระดับ (Tier 1 - 6), แสงและเอฟเฟกต์ตามธาตุ, และ ProximityPrompt สำหรับเก็บเกี่ยว
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local GameConfig = require(ReplicatedStorage:WaitForChild("SharedModules"):WaitForChild("GameConfig"))
local HerbDatabase = require(ReplicatedStorage:WaitForChild("SharedModules"):WaitForChild("HerbDatabase"))
local NetworkEvents = require(ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("NetworkEvents"))

-- สร้างโฟลเดอร์สำหรับสมุนไพรใน Workspace เพื่อความเป็นระเบียบ
local herbFolder = Workspace:FindFirstChild("HerbFolder")
if not herbFolder then
    herbFolder = Instance.new("Folder")
    herbFolder.Name = "HerbFolder"
    herbFolder.Parent = Workspace
end

-- สีกำหนดตามธาตุ
local ElementColors = {
    Fire = Color3.fromRGB(255, 80, 40),
    Water = Color3.fromRGB(50, 160, 255),
    Earth = Color3.fromRGB(200, 140, 70),
    Wood = Color3.fromRGB(70, 210, 90),
    Wind = Color3.fromRGB(110, 240, 190),
    Lightning = Color3.fromRGB(240, 220, 60),
    Void = Color3.fromRGB(160, 60, 240),
    Holy = Color3.fromRGB(255, 225, 90),
    Ice = Color3.fromRGB(170, 230, 255)
}

-- สีตามระดับ Tier
local TierColors = {
    [1] = Color3.fromRGB(180, 200, 180), -- ร้อยปี (ขาว/เทา)
    [2] = Color3.fromRGB(80, 200, 120),  -- ห้าร้อยปี (เขียว)
    [3] = Color3.fromRGB(60, 150, 255),  -- พันปี (ฟ้า)
    [4] = Color3.fromRGB(180, 80, 240),  -- หมื่นปี (ม่วง)
    [5] = Color3.fromRGB(255, 140, 40),  -- แสนปี (ส้มทอง)
    [6] = Color3.fromRGB(255, 215, 0)    -- บรรพกาล/เซียน (ทองคำ)
}

-- ฟังก์ชันสุ่มเลือกสมุนไพรตามน้ำหนักระดับความหายาก (Tier-based weighted random)
local function getRandomHerb()
    local roll = math.random() * 100
    local targetTier = 1

    if roll <= 0.1 then
        targetTier = 6 -- บรรพกาล / เซียน (0.1%)
    elseif roll <= 1.0 then
        targetTier = 5 -- แสนปี (0.9%)
    elseif roll <= 5.0 then
        targetTier = 4 -- หมื่นปี (4%)
    elseif roll <= 15.0 then
        targetTier = 3 -- พันปี (10%)
    elseif roll <= 40.0 then
        targetTier = 2 -- ห้าร้อยปี (25%)
    else
        targetTier = 1 -- ร้อยปี (60%)
    end

    local pool = HerbDatabase.GetByTier(targetTier)
    if pool and #pool > 0 then
        return pool[math.random(1, #pool)]
    end

    local all = HerbDatabase.GetAll()
    return all[math.random(1, #all)]
end

-- ฟังก์ชันสปอนสมุนไพร
local function spawnHerb(specificHerbName, targetPosition)
    local herbData = nil
    if specificHerbName then
        herbData = HerbDatabase.Get(specificHerbName)
        if not herbData and GameConfig.Herbs and GameConfig.Herbs[specificHerbName] then
            local fallback = GameConfig.Herbs[specificHerbName]
            herbData = {
                Name = specificHerbName,
                Tier = fallback.Rarity or 1,
                TierName = "ทั่วไป",
                Element = "Wood",
                Color = fallback.Color or Color3.fromRGB(85, 255, 127)
            }
        end
    end

    if not herbData then
        herbData = getRandomHerb()
    end
    if not herbData then return nil end

    -- คำนวณตำแหน่งเกิดตามโซน
    local pos
    local inPvP = false
    if targetPosition then
        pos = targetPosition + Vector3.new(math.random(-6, 6), 1, math.random(-6, 6))
    else
        -- เลือกว่าจะเกิดในโซน PvE (65% chance) หรือ PvP (35% chance)
        local worldCoords = GameConfig.WorldCoordinates
        if worldCoords and math.random() < 0.35 then
            -- สปอนในแดนหุบเหวอสูรโลหิต (PvP Zone: -1500, 55, 0)
            inPvP = true
            local pvpCenter = worldCoords.PvPZone.Center
            local rx = math.random(-180, 180)
            local rz = math.random(-180, 180)
            pos = pvpCenter + Vector3.new(rx, 6, rz)
        elseif worldCoords then
            -- สปอนในแดนพฤกษาสวรรค์ (PvE Zone: 1500, 55, 0)
            local pveCenter = worldCoords.PvEZone.Center
            local rx = math.random(-200, 200)
            local rz = math.random(-200, 200)
            pos = pveCenter + Vector3.new(rx, 6, rz)
        else
            local randomX = math.random(-150, 150)
            local randomZ = math.random(-150, 150)
            pos = Vector3.new(randomX, 3, randomZ)
        end
    end

    -- ยิง Raycast ลงหาพื้นผิวจริง เพื่อให้สมุนไพรแนบสนิทกับ 3D Assets ไม่ลอยกลางอากาศ
    local rayOrigin = Vector3.new(pos.X, 300, pos.Z)
    local rayDirection = Vector3.new(0, -450, 0)
    local rayResult = Workspace:Raycast(rayOrigin, rayDirection)
    if rayResult then
        pos = rayResult.Position + Vector3.new(0, 1.1, 0)
    end

    local elementColor = ElementColors[herbData.Element] or TierColors[herbData.Tier] or Color3.fromRGB(85, 255, 127)

    -- สร้าง Part ตัวแทนต้นสมุนไพรวิญญาณ
    local herbModel = Instance.new("Model")
    herbModel.Name = "Herb_" .. herbData.Name

    local herbPart = Instance.new("Part")
    herbPart.Name = "HerbPart"
    herbPart:SetAttribute("HerbName", herbData.Name)
    herbPart:SetAttribute("Tier", herbData.Tier)
    herbPart:SetAttribute("Element", herbData.Element)
    herbPart.Size = Vector3.new(1.8, 2.2, 1.8)
    herbPart.Position = pos
    herbPart.Color = elementColor
    herbPart.Material = (herbData.Tier >= 3) and Enum.Material.Neon or Enum.Material.Grass
    herbPart.Anchored = true
    herbPart.CanCollide = false
    herbPart.Parent = herbModel

    -- ก้านต้นสมุนไพร (Stem)
    local stem = Instance.new("Part")
    stem.Name = "Stem"
    stem.Size = Vector3.new(0.4, 1.5, 0.4)
    stem.Position = pos - Vector3.new(0, 0.8, 0)
    stem.Color = Color3.fromRGB(40, 90, 40)
    stem.Material = Enum.Material.Wood
    stem.Anchored = true
    stem.CanCollide = false
    stem.Parent = herbModel

    -- ดวงแสงวิญญาณ (Light Aura)
    local light = Instance.new("PointLight")
    light.Color = elementColor
    light.Range = 6 + (herbData.Tier * 2)
    light.Brightness = 1 + (herbData.Tier * 0.5)
    light.Parent = herbPart

    -- เอฟเฟกต์ระยิบระยับสำหรับสมุนไพรระดับสูง (Tier 4+)
    if herbData.Tier >= 4 then
        local sparkles = Instance.new("Sparkles")
        sparkles.SparkleColor = elementColor
        sparkles.Parent = herbPart
    end

    -- ป้ายชื่อลอยเหนือต้น
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "HerbTag"
    billboard.Size = UDim2.new(0, 140, 0, 40)
    billboard.StudsOffset = Vector3.new(0, 2.5, 0)
    billboard.AlwaysOnTop = true
    billboard.MaxDistance = 35
    billboard.Parent = herbPart

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, 0, 0.6, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = herbData.Name
    nameLabel.TextColor3 = TierColors[herbData.Tier] or Color3.fromRGB(255, 255, 255)
    nameLabel.Font = Enum.Font.SourceSansBold
    nameLabel.TextSize = 13
    nameLabel.Parent = billboard

    local subLabel = Instance.new("TextLabel")
    subLabel.Size = UDim2.new(1, 0, 0.4, 0)
    subLabel.Position = UDim2.new(0, 0, 0.6, 0)
    subLabel.BackgroundTransparency = 1
    subLabel.Text = string.format("ระดับ: %s | ธาตุ: %s", herbData.TierName or "ทั่วไป", herbData.Element or "-")
    subLabel.TextColor3 = Color3.fromRGB(200, 220, 240)
    subLabel.Font = Enum.Font.SourceSans
    subLabel.TextSize = 10
    subLabel.Parent = billboard

    -- ProximityPrompt สำหรับการเก็บ
    local holdTime = 0.5
    if herbData.Tier == 2 or herbData.Tier == 3 then holdTime = 0.8
    elseif herbData.Tier >= 4 then holdTime = 1.2 end

    local prompt = Instance.new("ProximityPrompt")
    prompt.ObjectText = string.format("%s [%s]", herbData.Name, herbData.TierName or "ทั่วไป")
    prompt.ActionText = "เด็ดสมุนไพร"
    prompt.HoldDuration = holdTime
    prompt.MaxActivationDistance = 14
    prompt.Parent = herbPart

    -- ผูก Triggered Event ฝั่งเซิร์ฟเวอร์โดยตรง
    local collected = false
    prompt.Triggered:Connect(function(player)
        if collected then return end
        collected = true

        local char = player.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if root and (root.Position - herbPart.Position).Magnitude > 20 then
            collected = false
            return
        end

        -- คำนวณจำนวนผลผลิต (PvP Yields 2x-3x + Sickle Tool Bonus)
        local yieldAmount = 1
        local worldCoords = GameConfig.WorldCoordinates
        if worldCoords and (herbPart.Position - worldCoords.PvPZone.Center).Magnitude <= worldCoords.PvPZone.Radius then
            yieldAmount = math.random(2, 3) -- โบนัสโซนเสี่ยงภัย PvP ให้สมุนไพร x2 - x3 เท่า!
        end

        if _G.DaoistDataManager and _G.DaoistDataManager.GetInventory then
            local inv = _G.DaoistDataManager.GetInventory(player)
            if inv and inv["เคียวตัดสมุนไพรเทวะ"] then
                yieldAmount = yieldAmount + 1 -- โบนัสจากเคียวตัดสมุนไพร
            end
        end

        -- บันทึกเข้ากระเป๋า
        if _G.DaoistDataManager and _G.DaoistDataManager.AddHerb then
            _G.DaoistDataManager.AddHerb(player, herbData.Name, yieldAmount)
        end

        -- เอฟเฟกต์เก็บสมุนไพร
        herbPart.Transparency = 1
        stem.Transparency = 1
        prompt.Enabled = false
        billboard.Enabled = false

        task.delay(0.2, function()
            herbModel:Destroy()
        end)
    end)

    herbModel.PrimaryPart = herbPart
    herbModel.Parent = herbFolder

    -- ประกาศเตือนหากเป็นสมุนไพรหายากระดับสูง (Tier 5 - 6)
    if herbData.Tier >= 5 then
        print(string.format("📢 [สมุนไพรสวรรค์] ปรากฏ '%s' (%s) ที่พิกัด (%.0f, %.0f, %.0f)!",
            herbData.Name, herbData.TierName, pos.X, pos.Y, pos.Z))
    else
        print(string.format("🌱 สมุนไพรถือกำเนิด: %s [%s]", herbData.Name, herbData.TierName or "ทั่วไป"))
    end

    return herbPart
end

-- ลูปสปอนสมุนไพรตามรอบเวลา
task.spawn(function()
    -- สปอนกลุ่มแรก 15 ต้นเมื่อเซิร์ฟเวอร์เปิด
    task.wait(2)
    for _ = 1, 15 do
        spawnHerb()
        task.wait(0.2)
    end

    while true do
        task.wait(GameConfig.HerbSpawnInterval or 20)
        -- จำกัดจำนวนสมุนไพรในโลกไม่ให้เกิน 50 ชิ้น เพื่อ Performance
        local currentCount = #herbFolder:GetChildren()
        if currentCount < 45 then
            spawnHerb()
        end
    end
end)

-- ส่งออกให้ AdminServer และระบบอื่นเรียกใช้
_G.DaoistHerbSpawner = {
    SpawnHerb = spawnHerb
}

print("✅ [Server] ระบบสปอนสมุนไพร 100 ชนิดพร้อมทำงาน!")
