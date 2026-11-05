--[[
    CultivationManager.lua
    โมดูลจัดการระบบตบะ, ขอบเขตพลัง, ฉายา, สเตตัสตัวละคร และการทะลวงขอบเขต
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local GameConfig = require(ReplicatedStorage:WaitForChild("SharedModules"):WaitForChild("GameConfig"))
local NetworkEvents = require(ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("NetworkEvents"))

local CultivationManager = {}

-- ค้นหาข้อมูลขอบเขตจาก Index หรือ Name
function CultivationManager:GetRealmData(realmIndexOrName)
    if type(realmIndexOrName) == "number" then
        return GameConfig.Realms[realmIndexOrName]
    elseif type(realmIndexOrName) == "string" then
        for index, realm in ipairs(GameConfig.Realms) do
            if realm.Name == realmIndexOrName then
                return realm, index
            end
        end
    end
    return nil
end

-- ดึงค่า Realm Index ปัจจุบันของผู้เล่น
function CultivationManager:GetPlayerRealmIndex(player)
    local index = player:GetAttribute("RealmIndex")
    if not index or index < 1 or index > #GameConfig.Realms then
        return 1
    end
    return index
end

-- ดึงค่าตบะปัจจุบัน
function CultivationManager:GetPlayerTapasya(player)
    local leaderstats = player:FindFirstChild("leaderstats")
    if leaderstats then
        local exp = leaderstats:FindFirstChild("Tapasya")
        if exp then
            return exp.Value
        end
    end
    return 0
end

-- ดึงข้อมูลตบะและขอบเขตทั้งหมดของผู้เล่น
function CultivationManager:GetCultivationData(player)
    local realmIndex = self:GetPlayerRealmIndex(player)
    local currentRealm = GameConfig.Realms[realmIndex] or GameConfig.Realms[1]
    local nextRealm = GameConfig.Realms[realmIndex + 1]
    local tapasya = self:GetPlayerTapasya(player)

    local buff = player:GetAttribute("BreakthroughBuff") or 0
    local baseRate = nextRealm and (nextRealm.BaseBreakthroughRate or 1.0) or 1.0
    local totalChance = math.clamp(baseRate + buff, 0.05, 1.0)

    local stats = currentRealm.Stats
    local maxChi = stats.MaxChi or 50
    local chi = player:GetAttribute("Chi") or maxChi

    return {
        Tapasya = tapasya,
        RealmIndex = realmIndex,
        RealmName = currentRealm.Name,
        Title = currentRealm.Title,
        Stats = currentRealm.Stats,
        Color = currentRealm.Color,
        RequiredExp = nextRealm and nextRealm.RequiredExp or nil,
        NextRealmName = nextRealm and nextRealm.Name or nil,
        IsMaxRealm = (nextRealm == nil),
        BaseRate = baseRate,
        BreakthroughBuff = buff,
        TotalChance = totalChance,
        Chi = chi,
        MaxChi = maxChi,
        ChiRegen = stats.ChiRegen or 2,
        TapasyaRegen = stats.TapasyaRegen or 10,
        UnlockedZone = currentRealm.UnlockedZone,
        ZoneLevel = currentRealm.ZoneLevel or 1
    }
end

-- ส่งข้อมูลอัปเดตไปยัง Client
function CultivationManager:SyncToClient(player)
    local data = self:GetCultivationData(player)
    NetworkEvents.SyncCultivation:FireClient(player, data)
end

-- ติดตั้ง Overhead BillboardGui เหนือหัวตัวละคร (แสดง ชื่อ + ฉายา + ขอบเขต)
function CultivationManager:UpdateOverhead(player, character)
    if not character then return end
    local head = character:FindFirstChild("Head")
    if not head then return end

    local realmIndex = self:GetPlayerRealmIndex(player)
    local realmData = GameConfig.Realms[realmIndex] or GameConfig.Realms[1]

    local overhead = head:FindFirstChild("CultivationOverhead")
    if not overhead then
        overhead = Instance.new("BillboardGui")
        overhead.Name = "CultivationOverhead"
        overhead.Size = UDim2.new(0, 220, 0, 70)
        overhead.StudsOffset = Vector3.new(0, 3.2, 0)
        overhead.AlwaysOnTop = true
        overhead.MaxDistance = 80
        overhead.Parent = head

        local titleLabel = Instance.new("TextLabel")
        titleLabel.Name = "TitleLabel"
        titleLabel.Size = UDim2.new(1, 0, 0, 20)
        titleLabel.Position = UDim2.new(0, 0, 0, 0)
        titleLabel.BackgroundTransparency = 1
        titleLabel.Font = Enum.Font.SourceSansBold
        titleLabel.TextSize = 16
        titleLabel.Parent = overhead

        local titleStroke = Instance.new("UIStroke")
        titleStroke.Thickness = 1.5
        titleStroke.Color = Color3.fromRGB(0, 0, 0)
        titleStroke.Parent = titleLabel

        local nameLabel = Instance.new("TextLabel")
        nameLabel.Name = "NameLabel"
        nameLabel.Size = UDim2.new(1, 0, 0, 24)
        nameLabel.Position = UDim2.new(0, 0, 0, 20)
        nameLabel.BackgroundTransparency = 1
        nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        nameLabel.Font = Enum.Font.SourceSansBold
        nameLabel.TextSize = 18
        nameLabel.Text = player.DisplayName .. " (@" .. player.Name .. ")"
        nameLabel.Parent = overhead

        local nameStroke = Instance.new("UIStroke")
        nameStroke.Thickness = 1.5
        nameStroke.Color = Color3.fromRGB(0, 0, 0)
        nameStroke.Parent = nameLabel

        local realmLabel = Instance.new("TextLabel")
        realmLabel.Name = "RealmLabel"
        realmLabel.Size = UDim2.new(1, 0, 0, 20)
        realmLabel.Position = UDim2.new(0, 0, 0, 44)
        realmLabel.BackgroundTransparency = 1
        realmLabel.Font = Enum.Font.SourceSansItalic
        realmLabel.TextSize = 14
        realmLabel.Parent = overhead

        local realmStroke = Instance.new("UIStroke")
        realmStroke.Thickness = 1.2
        realmStroke.Color = Color3.fromRGB(0, 0, 0)
        realmStroke.Parent = realmLabel
    end

    local titleLabel = overhead:FindFirstChild("TitleLabel")
    if titleLabel then
        titleLabel.Text = "« " .. realmData.Title .. " »"
        titleLabel.TextColor3 = realmData.Color
    end

    local realmLabel = overhead:FindFirstChild("RealmLabel")
    if realmLabel then
        realmLabel.Text = "☯ ขอบเขต: " .. realmData.Name
        realmLabel.TextColor3 = realmData.Color
    end
end

-- เพิ่มหรืออัปเดตสเตตัสให้แก่ตัวละครตามขอบเขต
function CultivationManager:ApplyStats(player, character)
    if not character then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end

    local realmIndex = self:GetPlayerRealmIndex(player)
    local realmData = GameConfig.Realms[realmIndex] or GameConfig.Realms[1]
    local stats = realmData.Stats

    -- ปรับเลือดสูงสุดและฟื้นฟูเลือด
    local oldMaxHealth = humanoid.MaxHealth
    humanoid.MaxHealth = stats.MaxHealth
    if stats.MaxHealth > oldMaxHealth then
        humanoid.Health = math.clamp(humanoid.Health + (stats.MaxHealth - oldMaxHealth), 1, stats.MaxHealth)
    else
        humanoid.Health = math.clamp(humanoid.Health, 1, stats.MaxHealth)
    end

    -- ปรับความเร็วเดิน
    humanoid.WalkSpeed = stats.WalkSpeed

    -- Chi (พลังปราณ)
    local currentChi = player:GetAttribute("Chi") or stats.MaxChi
    player:SetAttribute("MaxChi", stats.MaxChi)
    player:SetAttribute("Chi", math.clamp(currentChi, 0, stats.MaxChi))
    player:SetAttribute("ChiRegen", stats.ChiRegen)

    -- Tapasya Regen & Unlocked Zone
    player:SetAttribute("TapasyaRegen", stats.TapasyaRegen)
    player:SetAttribute("UnlockedZone", realmData.UnlockedZone)
    player:SetAttribute("ZoneLevel", realmData.ZoneLevel or 1)

    -- ตั้ง Attribute ใน Character และ Player สำหรับระบบต่อสู้และ UI
    character:SetAttribute("MaxHealth", stats.MaxHealth)
    character:SetAttribute("MaxChi", stats.MaxChi)
    character:SetAttribute("Chi", player:GetAttribute("Chi"))
    character:SetAttribute("AttackPower", stats.AttackPower)
    character:SetAttribute("Defense", stats.Defense)
    character:SetAttribute("Realm", realmData.Name)
    character:SetAttribute("Title", realmData.Title)

    player:SetAttribute("MaxHealth", stats.MaxHealth)
    player:SetAttribute("AttackPower", stats.AttackPower)
    player:SetAttribute("Defense", stats.Defense)
    player:SetAttribute("Title", realmData.Title)

    -- อัปเดต Overhead
    self:UpdateOverhead(player, character)
end

-- สร้างเอฟเฟกต์การทะลวงขอบเขตบนตัวละคร
function CultivationManager:PlayBreakthroughVFX(character, realmData)
    if not character then return end
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end

    -- แสงสว่างจ้าชั่วขณะ
    local light = Instance.new("PointLight")
    light.Color = realmData.Color
    light.Range = 25
    light.Brightness = 8
    light.Parent = rootPart

    -- Tween แสงให้ค่อยๆ จางลง
    task.spawn(function()
        local tweenInfo = TweenInfo.new(2.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        local tween = TweenService:Create(light, tweenInfo, {Brightness = 0, Range = 0})
        tween:Play()
        tween.Completed:Wait()
        light:Destroy()
    end)

    -- อนุภาคปราณหมุนวนพวยพุ่งขึ้น
    local attachment = Instance.new("Attachment")
    attachment.Position = Vector3.new(0, -2, 0)
    attachment.Parent = rootPart

    local particles = Instance.new("ParticleEmitter")
    particles.Color = ColorSequence.new(realmData.Color, Color3.fromRGB(255, 255, 255))
    particles.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1.2),
        NumberSequenceKeypoint.new(1, 0.2)
    })
    particles.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.1),
        NumberSequenceKeypoint.new(1, 1)
    })
    particles.Lifetime = NumberRange.new(1.2, 2.0)
    particles.Rate = 80
    particles.Speed = NumberRange.new(8, 18)
    particles.SpreadAngle = Vector2.new(15, 15)
    particles.EmissionDirection = Enum.NormalId.Top
    particles.LightEmission = 1
    particles.Parent = attachment

    task.spawn(function()
        task.wait(2.2)
        particles.Enabled = false
        task.wait(2.5)
        attachment:Destroy()
    end)
end

-- ตั้งค่าผู้เล่นเมื่อเข้าเกมครั้งแรกหรือโหลดเซฟ
function CultivationManager:SetupPlayer(player, initialTapasya, initialRealmIndex)
    local realmIndex = math.clamp(initialRealmIndex or 1, 1, #GameConfig.Realms)
    local tapasya = math.max(0, initialTapasya or 0)
    local realmData = GameConfig.Realms[realmIndex]

    -- Leaderstats
    local leaderstats = player:FindFirstChild("leaderstats")
    if not leaderstats then
        leaderstats = Instance.new("Folder")
        leaderstats.Name = "leaderstats"
        leaderstats.Parent = player
    end

    local exp = leaderstats:FindFirstChild("Tapasya")
    if not exp then
        exp = Instance.new("IntValue")
        exp.Name = "Tapasya"
        exp.Parent = leaderstats
    end
    exp.Value = tapasya

    local realm = leaderstats:FindFirstChild("Realm")
    if not realm then
        realm = Instance.new("StringValue")
        realm.Name = "Realm"
        realm.Parent = leaderstats
    end
    realm.Value = realmData.Name

    -- Attributes
    player:SetAttribute("RealmIndex", realmIndex)
    player:SetAttribute("Title", realmData.Title)
    player:SetAttribute("AttackPower", realmData.Stats.AttackPower)
    player:SetAttribute("Defense", realmData.Stats.Defense)
    player:SetAttribute("MaxHealth", realmData.Stats.MaxHealth)
    player:SetAttribute("WalkSpeed", realmData.Stats.WalkSpeed)

    -- เชื่อมต่อเมื่อตัวละครเกิด
    if player.Character then
        self:ApplyStats(player, player.Character)
    end

    player.CharacterAdded:Connect(function(character)
        task.wait(0.1) -- รอให้ Humanoid โหลดสมบูรณ์
        self:ApplyStats(player, character)
    end)

    -- อัปเดตเมื่อค่า Tapasya เปลี่ยน
    exp.Changed:Connect(function()
        self:SyncToClient(player)
    end)

    self:SyncToClient(player)
end

-- เพิ่มค่าตบะ
function CultivationManager:AddTapasya(player, amount)
    local leaderstats = player:FindFirstChild("leaderstats")
    if not leaderstats then return false end
    local exp = leaderstats:FindFirstChild("Tapasya")
    if not exp then return false end

    exp.Value = exp.Value + amount
    self:SyncToClient(player)
    return true, exp.Value
end

-- ตั้งค่าตบะตามระบุ
function CultivationManager:SetTapasya(player, amount)
    local leaderstats = player:FindFirstChild("leaderstats")
    if not leaderstats then return false end
    local exp = leaderstats:FindFirstChild("Tapasya")
    if not exp then return false end

    exp.Value = math.max(0, amount)
    self:SyncToClient(player)
    return true, exp.Value
end

-- เปลี่ยนขอบเขตพลังโดยตรง (สำหรับ Admin/Tester หรือเควสต์)
function CultivationManager:SetRealm(player, realmIndexOrName)
    local realmData, realmIndex
    if type(realmIndexOrName) == "number" then
        realmIndex = math.clamp(realmIndexOrName, 1, #GameConfig.Realms)
        realmData = GameConfig.Realms[realmIndex]
    else
        realmData, realmIndex = self:GetRealmData(realmIndexOrName)
    end

    if not realmData or not realmIndex then
        return false, "ไม่พบขอบเขตที่ระบุ"
    end

    player:SetAttribute("RealmIndex", realmIndex)
    player:SetAttribute("Title", realmData.Title)

    local leaderstats = player:FindFirstChild("leaderstats")
    if leaderstats and leaderstats:FindFirstChild("Realm") then
        leaderstats.Realm.Value = realmData.Name
    end

    if player.Character then
        self:ApplyStats(player, player.Character)
        self:PlayBreakthroughVFX(player.Character, realmData)
    end

    self:SyncToClient(player)
    return true, "เปลี่ยนขอบเขตเป็น: " .. realmData.Name .. " (" .. realmData.Title .. ")"
end

-- ดำเนินการทะลวงขอบเขต (Breakthrough)
function CultivationManager:AttemptBreakthrough(player)
    local currentIndex = self:GetPlayerRealmIndex(player)
    if currentIndex >= #GameConfig.Realms then
        return false, "ท่านได้บรรลุขอบเขตสูงสุดในปัจจุบันแล้ว!"
    end

    local nextIndex = currentIndex + 1
    local nextRealm = GameConfig.Realms[nextIndex]
    local currentTapasya = self:GetPlayerTapasya(player)

    -- เช็กว่าตบะถึงเกณฑ์หรือไม่
    if currentTapasya < nextRealm.RequiredExp then
        return false, string.format("ค่าตบะยังไม่เพียงพอ! ต้องการ %d แต้ม (ปัจจุบันมี %d แต้ม ขาดอีก %d)", 
            nextRealm.RequiredExp, currentTapasya, nextRealm.RequiredExp - currentTapasya)
    end

    -- คำนวณอัตราความสำเร็จจากอัตราพื้นฐาน + บัฟจากเม็ดยาโอสถ
    local baseRate = nextRealm.BaseBreakthroughRate or 1.0
    local buff = player:GetAttribute("BreakthroughBuff") or 0
    local totalChance = math.clamp(baseRate + buff, 0.05, 1.0)

    -- สุ่มทอยอัตราความสำเร็จ
    local roll = math.random()
    if roll > totalChance then
        -- ทะลวงล้มเหลว (ลมปราณติดขัด / ธาตุไฟเข้าแทรก)
        player:SetAttribute("BreakthroughBuff", 0) -- ใช้บัฟไปแล้ว
        self:SyncToClient(player)

        -- เอฟเฟกต์ควันดำล้มเหลว
        if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local root = player.Character.HumanoidRootPart
            local att = Instance.new("Attachment")
            att.Parent = root
            local p = Instance.new("ParticleEmitter")
            p.Color = ColorSequence.new(Color3.fromRGB(60, 60, 60))
            p.Size = NumberSequence.new(1.5, 0.2)
            p.Lifetime = NumberRange.new(0.8, 1.2)
            p.Rate = 50
            p.Speed = NumberRange.new(3, 6)
            p.Parent = att
            task.delay(1.5, function() att:Destroy() end)
        end

        local failMsg = string.format("💥 ลมปราณติดขัด ทะลวงขอบเขตไม่สำเร็จ! (โอกาสสำเร็จ: %.0f%%) สามารถใช้ 'โอสถ' ช่วยเสริมโอกาสให้ถึง 100%% ได้", totalChance * 100)
        return false, failMsg
    end

    -- รีเซ็ตบัฟยาโอสถเมื่อทะลวงสำเร็จ
    player:SetAttribute("BreakthroughBuff", 0)

    -- เลื่อนขั้นสำเร็จ
    player:SetAttribute("RealmIndex", nextIndex)
    player:SetAttribute("Title", nextRealm.Title)

    local leaderstats = player:FindFirstChild("leaderstats")
    if leaderstats and leaderstats:FindFirstChild("Realm") then
        leaderstats.Realm.Value = nextRealm.Name
    end

    -- อัปเดตสเตตัสและฉายาตัวละครทันที
    if player.Character then
        self:ApplyStats(player, player.Character)
        self:PlayBreakthroughVFX(player.Character, nextRealm)
    end

    -- แจ้งเตือนเอฟเฟกต์ไปยังผู้เล่นทุกคนในเซิร์ฟเวอร์
    if player.Character then
        NetworkEvents.BreakthroughEffect:FireAllClients(player.Character, nextRealm)
    end

    -- ซิงก์ข้อมูลอัปเดตกลับไปยังเจ้าตัว
    self:SyncToClient(player)

    -- ประกาศข้อความยินดี (Server Broadcast)
    local announcement = string.format("📢 [ประกาศฟ้าดิน] ผู้บำเพ็ญ '%s' ได้ทะลวงขอบเขตสู่ [%s] สำเร็จ! ได้รับฉายา «%s»",
        player.DisplayName, nextRealm.Name, nextRealm.Title)
    print(announcement)

    return true, "ทะลวงขอบเขตสำเร็จ! ก้าวสู่ " .. nextRealm.Name, nextRealm
end

-- บังคับทะลวงขอบเขตโดยไม่สนเงื่อนไขตบะ (สำหรับ Admin Test)
function CultivationManager:ForceBreakthrough(player)
    local currentIndex = self:GetPlayerRealmIndex(player)
    if currentIndex >= #GameConfig.Realms then
        return false, "ท่านอยู่ในขอบเขตสูงสุดแล้ว"
    end

    local nextIndex = currentIndex + 1
    local nextRealm = GameConfig.Realms[nextIndex]

    player:SetAttribute("RealmIndex", nextIndex)
    player:SetAttribute("Title", nextRealm.Title)

    local leaderstats = player:FindFirstChild("leaderstats")
    if leaderstats and leaderstats:FindFirstChild("Realm") then
        leaderstats.Realm.Value = nextRealm.Name
    end

    if player.Character then
        self:ApplyStats(player, player.Character)
        self:PlayBreakthroughVFX(player.Character, nextRealm)
        NetworkEvents.BreakthroughEffect:FireAllClients(player.Character, nextRealm)
    end

    self:SyncToClient(player)
    return true, "บังคับทะลวงขอบเขตสู่: " .. nextRealm.Name .. " สำเร็จ"
end

return CultivationManager

