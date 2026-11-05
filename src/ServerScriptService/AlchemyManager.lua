--[[
    AlchemyManager.lua
    โมดูลจัดการระบบเตาหลอมโอสถ & การปรุงยาอิสระ (Freeform Dynamic Alchemy)
    ประมวลผลผ่าน AlchemyEngine ตามสถาปัตยกรรม Dynamic Alchemical System
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local GameConfig = require(ReplicatedStorage:WaitForChild("SharedModules"):WaitForChild("GameConfig"))
local HerbDatabase = require(ReplicatedStorage:WaitForChild("SharedModules"):WaitForChild("HerbDatabase"))
local PillDatabase = require(ReplicatedStorage:WaitForChild("SharedModules"):WaitForChild("PillDatabase"))
local NetworkEvents = require(ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("NetworkEvents"))
local CultivationManager = require(ServerScriptService:WaitForChild("CultivationManager"))
local AlchemyEngine = require(ServerScriptService:WaitForChild("AlchemyEngine"))

local AlchemyManager = {}
local DynamicPillRegistry = {}

-- ดึงข้อมูลกระเป๋าของผู้เล่น
function AlchemyManager:GetInventory(player)
    if _G.DaoistDataManager and _G.DaoistDataManager.GetInventory then
        return _G.DaoistDataManager.GetInventory(player)
    end
    return {}
end

-- หลอมโอสถแบบอิสระตามเวกเตอร์คุณสมบัติวัตถุดิบและคะแนนมินิเกม
function AlchemyManager:CraftDynamicPill(player, ingredients, minigameScore)
    if not ingredients or type(ingredients) ~= "table" then
        return false, "กรุณาเลือกสมุนไพรที่จะใส่ลงในเตาหลอม"
    end

    local inventory = self:GetInventory(player)

    -- 1. ตรวจสอบว่ามีสมุนไพรในกระเป๋าพอหรือไม่
    for herbName, count in pairs(ingredients) do
        count = math.floor(tonumber(count) or 0)
        if count > 0 then
            local owned = inventory[herbName] or 0
            if owned < count then
                return false, string.format("สมุนไพร '%s' ในกระเป๋ามีไม่พอ (ต้องการ %d แต่มี %d)", herbName, count, owned)
            end
        end
    end

    -- 2. ประมวลผลผ่าน Brewing Pipeline ใน AlchemyEngine
    local success, message, pillData = AlchemyEngine:ProcessBrew(ingredients, minigameScore)

    -- 3. หักสมุนไพรออกจากกระเป๋าเสมอ (ไม่ว่าจะสำเร็จหรือหม้อระเบิด)
    for herbName, count in pairs(ingredients) do
        count = math.floor(tonumber(count) or 0)
        if count > 0 then
            inventory[herbName] = math.max(0, (inventory[herbName] or 0) - count)
        end
    end
    NetworkEvents.UpdateInventory:FireClient(player, inventory)

    -- หากเกิดกรณีหม้อระเบิด
    if not success and pillData and pillData.Exploded then
        if player.Character then
            local root = player.Character:FindFirstChild("HumanoidRootPart")
            local hum = player.Character:FindFirstChildOfClass("Humanoid")
            if hum then
                hum:TakeDamage(hum.MaxHealth * 0.5) -- ลดเลือด 50%
            end
            if root then
                root.AssemblyLinearVelocity = Vector3.new(math.random(-25, 25), 45, 60) -- กระเด็นถอยหลัง
                local expPart = Instance.new("Part")
                expPart.Size = Vector3.new(3, 3, 3)
                expPart.Position = root.Position + Vector3.new(0, 2, -3)
                expPart.Transparency = 1
                expPart.Anchored = true
                expPart.Parent = workspace

                local smoke = Instance.new("Smoke")
                smoke.Color = Color3.fromRGB(30, 30, 30)
                smoke.Size = 10
                smoke.RiseVelocity = 6
                smoke.Parent = expPart
                task.delay(2.5, function() expPart:Destroy() end)
            end
        end
        return false, message
    end

    if not success then
        return false, message
    end

    -- 4. บันทึกยาโอสถที่สร้างขึ้นลงในแคช, ปลดล็อกในสารบบตำรับยา และเพิ่มเข้ากระเป๋า
    DynamicPillRegistry[pillData.Name] = pillData
    inventory[pillData.Name] = (inventory[pillData.Name] or 0) + 1
    NetworkEvents.UpdateInventory:FireClient(player, inventory)

    -- บันทึกการค้นพบตำรับยา
    if _G.DaoistDataManager and _G.DaoistDataManager.AddDiscoveredPill then
        _G.DaoistDataManager.AddDiscoveredPill(player, pillData.BaseName or pillData.Name)
    end

    print(string.format("⚗️ [Alchemy Synthesis] %s ปรุงสำเร็จ: [%s] ตบะ +%d, ทะลวง +%.0f%% (เสถียร: %d%%)",
        player.DisplayName, pillData.Name, pillData.TapasyaBonus or 0, (pillData.BreakthroughBonus or 0) * 100, pillData.Stability or 100))

    return true, string.format("หลอม [%s] สำเร็จ! (ตบะ +%d | โอกาสทะลวง +%.0f%%)", pillData.Name, pillData.TapasyaBonus or 0, (pillData.BreakthroughBonus or 0) * 100), pillData
end

-- กินโอสถ / ใช้เม็ดยา (Consume Pill)
function AlchemyManager:UsePill(player, pillName)
    local pillConfig = DynamicPillRegistry[pillName]
    if not pillConfig then
        -- ค้นหาจาก PillDatabase
        local cleanName = string.gsub(pillName, "%s*%b()", "") -- ตัด (ระดับ...) ออกเพื่อค้นหาชื่อฐาน
        pillConfig = PillDatabase.Get(pillName) or PillDatabase.Get(cleanName)
    end
    if not pillConfig and GameConfig.Pills then
        pillConfig = GameConfig.Pills[pillName]
    end

    if not pillConfig then
        pillConfig = {
            Name = pillName,
            TapasyaBonus = 500,
            BreakthroughBonus = 0.25,
            Color = Color3.fromRGB(85, 255, 127)
        }
    end

    local inventory = self:GetInventory(player)
    local pillCount = inventory[pillName] or 0
    if pillCount <= 0 then
        return false, "ท่านไม่มี " .. pillName .. " ในกระเป๋า"
    end

    -- หักเม็ดยาออก 1 ชิ้น
    inventory[pillName] = pillCount - 1
    NetworkEvents.UpdateInventory:FireClient(player, inventory)

    -- 1. เพิ่มค่าตบะ
    if pillConfig.TapasyaBonus and pillConfig.TapasyaBonus > 0 then
        CultivationManager:AddTapasya(player, pillConfig.TapasyaBonus)
    end

    -- 2. เพิ่มบัฟอัตราความสำเร็จในการทะลวงขอบเขต
    local currentBuff = player:GetAttribute("BreakthroughBuff") or 0
    local newBuff = math.min(1.0, currentBuff + (pillConfig.BreakthroughBonus or 0))
    player:SetAttribute("BreakthroughBuff", newBuff)

    -- 3. เรียกใช้งานเอฟเฟกต์พิเศษตามตำรับยา (BuffEffect)
    local char = player.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")

    if pillConfig.BuffEffect and hum then
        local effect = pillConfig.BuffEffect
        local dur = pillConfig.Duration or 60

        if effect == "RegenHP" then
            task.spawn(function()
                for _ = 1, dur do
                    if hum and hum.Health > 0 then
                        hum.Health = math.min(hum.MaxHealth, hum.Health + (pillConfig.BuffValue or 25))
                    end
                    task.wait(1)
                end
            end)

        elseif effect == "InstantQi" then
            local maxChi = player:GetAttribute("MaxChi") or 100
            local curChi = player:GetAttribute("Chi") or 100
            local gain = math.floor(maxChi * (pillConfig.BuffValue or 0.5))
            player:SetAttribute("Chi", math.min(maxChi, curChi + gain))

        elseif effect == "WindStep" then
            local boost = pillConfig.BuffValue or 18
            hum.WalkSpeed = hum.WalkSpeed + boost
            hum.JumpHeight = hum.JumpHeight + 15
            task.delay(dur, function()
                if hum then
                    hum.WalkSpeed = math.max(16, hum.WalkSpeed - boost)
                    hum.JumpHeight = math.max(7.2, hum.JumpHeight - 15)
                end
            end)

        elseif effect == "VajraArmor" then
            player:SetAttribute("VajraArmor", true)
            task.delay(dur, function() player:SetAttribute("VajraArmor", nil) end)

        elseif effect == "ApeMight" then
            player:SetAttribute("AttackPowerBonus", pillConfig.BuffValue or 0.30)
            task.delay(dur, function() player:SetAttribute("AttackPowerBonus", nil) end)

        elseif effect == "PhoenixAutoRevive" then
            player:SetAttribute("PhoenixAutoRevive", true)

        elseif effect == "InvincibleEmperor" then
            player:SetAttribute("Invincible", true)
            player:SetAttribute("AttackPowerBonus", 5.0)
            task.delay(15, function()
                player:SetAttribute("Invincible", nil)
                player:SetAttribute("AttackPowerBonus", nil)
                -- หมดสติ 30 วินาที
                if hum then
                    hum.WalkSpeed = 0
                    task.delay(30, function() if hum then hum.WalkSpeed = 16 end end)
                end
            end)

        elseif effect == "MutatedSpeedHurt" then
            -- วิ่งเร็ว 100% แต่เลือดลด 5/วิ
            hum.WalkSpeed = hum.WalkSpeed + 25
            task.spawn(function()
                for _ = 1, dur do
                    if hum and hum.Health > 5 then
                        hum:TakeDamage(5)
                    end
                    task.wait(1)
                end
                if hum then hum.WalkSpeed = math.max(16, hum.WalkSpeed - 25) end
            end)

        elseif effect == "SlagDiarrhea" then
            hum.WalkSpeed = math.max(8, hum.WalkSpeed - 6)
            task.delay(20, function() if hum then hum.WalkSpeed = 16 end end)

        elseif effect == "CleanseAll" then
            player:SetAttribute("Poisoned", nil)
            player:SetAttribute("Bleeding", nil)
            if hum then hum.WalkSpeed = 16 end
        end
    end

    -- ซิงก์ข้อมูล Cultivation HUD
    CultivationManager:SyncToClient(player)

    -- เล่นเอฟเฟกต์แสงรอบตัวผู้เล่น
    if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
        local root = player.Character.HumanoidRootPart
        local light = Instance.new("PointLight")
        light.Color = pillConfig.Color or Color3.fromRGB(85, 255, 127)
        light.Range = 25
        light.Brightness = 8
        light.Parent = root
        task.delay(1.5, function() light:Destroy() end)
    end

    local msg = string.format("✨ กลืน [%s] ตบะเพิ่ม %+d แต้ม! ได้รับบัฟทะลวงขอบเขต +%.0f%%",
        pillName, pillConfig.TapasyaBonus or 0, (pillConfig.BreakthroughBonus or 0) * 100)
    print("💊 " .. player.DisplayName .. " " .. msg)
    return true, msg, newBuff
end

return AlchemyManager
