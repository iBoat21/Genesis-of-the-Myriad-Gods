--[[
    CultivationClient.client.lua
    จัดการ UI แสดงค่าตบะ, ขอบเขตพลัง, ฉายา, สเตตัส และปุ่ม "ทะลวงขอบเขต" (Breakthrough)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")
local GameConfig = require(ReplicatedStorage:WaitForChild("SharedModules"):WaitForChild("GameConfig"))
local NetworkEvents = require(ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("NetworkEvents"))

-- สร้าง ScreenGui สำหรับระบบตบะ
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "CultivationGui"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

--------------------------------------------------------------------------------
-- 1. สร้างหน้าต่าง Cultivation HUD (แถบแสดงตบะและขอบเขต ด้านบนกลางจอ)
--------------------------------------------------------------------------------
local hudFrame = Instance.new("Frame")
hudFrame.Name = "CultivationHUD"
hudFrame.Size = UDim2.new(0, 380, 0, 110)
hudFrame.Position = UDim2.new(0.5, -190, 0, 15)
hudFrame.BackgroundColor3 = Color3.fromRGB(24, 26, 32)
hudFrame.BorderSizePixel = 0
hudFrame.Parent = screenGui

local hudCorner = Instance.new("UICorner")
hudCorner.CornerRadius = UDim.new(0, 12)
hudCorner.Parent = hudFrame

local hudStroke = Instance.new("UIStroke")
hudStroke.Thickness = 2
hudStroke.Color = Color3.fromRGB(85, 255, 127)
hudStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
hudStroke.Parent = hudFrame

-- แถบหัวข้อ: ไอคอน + ฉายา + ขอบเขต
local headerFrame = Instance.new("Frame")
headerFrame.Size = UDim2.new(1, -20, 0, 30)
headerFrame.Position = UDim2.new(0, 10, 0, 8)
headerFrame.BackgroundTransparency = 1
headerFrame.Parent = hudFrame

local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "TitleLabel"
titleLabel.Size = UDim2.new(0.5, 0, 1, 0)
titleLabel.Position = UDim2.new(0, 0, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "« มนุษย์ปุถุชน »"
titleLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
titleLabel.Font = Enum.Font.SourceSansBold
titleLabel.TextSize = 17
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = headerFrame

local realmLabel = Instance.new("TextLabel")
realmLabel.Name = "RealmLabel"
realmLabel.Size = UDim2.new(0.5, 0, 1, 0)
realmLabel.Position = UDim2.new(0.5, 0, 0, 0)
realmLabel.BackgroundTransparency = 1
realmLabel.Text = "☯ ขอบเขต: คนธรรมดา"
realmLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
realmLabel.Font = Enum.Font.SourceSansBold
realmLabel.TextSize = 16
realmLabel.TextXAlignment = Enum.TextXAlignment.Right
realmLabel.Parent = headerFrame

-- แถบความคืบหน้าของตบะ (Progress Bar)
local progressBg = Instance.new("Frame")
progressBg.Name = "ProgressBg"
progressBg.Size = UDim2.new(1, -20, 0, 18)
progressBg.Position = UDim2.new(0, 10, 0, 42)
progressBg.BackgroundColor3 = Color3.fromRGB(40, 44, 52)
progressBg.BorderSizePixel = 0
progressBg.Parent = hudFrame

local progressCorner = Instance.new("UICorner")
progressCorner.CornerRadius = UDim.new(0, 9)
progressCorner.Parent = progressBg

local progressFill = Instance.new("Frame")
progressFill.Name = "ProgressFill"
progressFill.Size = UDim2.new(0, 0, 1, 0)
progressFill.BackgroundColor3 = Color3.fromRGB(85, 255, 127)
progressFill.BorderSizePixel = 0
progressFill.Parent = progressBg

local fillCorner = Instance.new("UICorner")
fillCorner.CornerRadius = UDim.new(0, 9)
fillCorner.Parent = progressFill

local progressText = Instance.new("TextLabel")
progressText.Name = "ProgressText"
progressText.Size = UDim2.new(1, 0, 1, 0)
progressText.BackgroundTransparency = 1
progressText.Text = "ตบะ: 0 / 1,000 (0%)"
progressText.TextColor3 = Color3.fromRGB(255, 255, 255)
progressText.Font = Enum.Font.SourceSansBold
progressText.TextSize = 13
progressText.ZIndex = 2
progressText.Parent = progressBg

local progressStroke = Instance.new("UIStroke")
progressStroke.Thickness = 1
progressStroke.Color = Color3.fromRGB(0, 0, 0)
progressStroke.Parent = progressText

-- ปุ่ม "ทะลวงขอบเขต" (Breakthrough Button)
local breakthroughBtn = Instance.new("TextButton")
breakthroughBtn.Name = "BreakthroughBtn"
breakthroughBtn.Size = UDim2.new(1, -20, 0, 32)
breakthroughBtn.Position = UDim2.new(0, 10, 0, 68)
breakthroughBtn.BackgroundColor3 = Color3.fromRGB(50, 52, 60)
breakthroughBtn.BorderSizePixel = 0
breakthroughBtn.Text = "🔒 ค่าตบะยังไม่เพียงพอต่อการทะลวง"
breakthroughBtn.TextColor3 = Color3.fromRGB(160, 160, 160)
breakthroughBtn.Font = Enum.Font.SourceSansBold
breakthroughBtn.TextSize = 15
breakthroughBtn.AutoButtonColor = false
breakthroughBtn.Parent = hudFrame

local btnCorner = Instance.new("UICorner")
btnCorner.CornerRadius = UDim.new(0, 8)
btnCorner.Parent = breakthroughBtn

local btnStroke = Instance.new("UIStroke")
btnStroke.Thickness = 1.5
btnStroke.Color = Color3.fromRGB(70, 72, 80)
btnStroke.Parent = breakthroughBtn

--------------------------------------------------------------------------------
-- 2. หน้าต่างป๊อปอัพแสดงความยินดีเมื่อทะลวงสำเร็จ (Celebration Modal)
--------------------------------------------------------------------------------
local modalFrame = Instance.new("Frame")
modalFrame.Name = "CelebrationModal"
modalFrame.Size = UDim2.new(0, 420, 0, 240)
modalFrame.Position = UDim2.new(0.5, -210, 0.5, -120)
modalFrame.BackgroundColor3 = Color3.fromRGB(20, 22, 28)
modalFrame.BorderSizePixel = 0
modalFrame.Visible = false
modalFrame.ZIndex = 10
modalFrame.Parent = screenGui

local modalCorner = Instance.new("UICorner")
modalCorner.CornerRadius = UDim.new(0, 16)
modalCorner.Parent = modalFrame

local modalStroke = Instance.new("UIStroke")
modalStroke.Thickness = 3
modalStroke.Color = Color3.fromRGB(255, 215, 0)
modalStroke.Parent = modalFrame

local modalHeader = Instance.new("TextLabel")
modalHeader.Size = UDim2.new(1, 0, 0, 40)
modalHeader.Position = UDim2.new(0, 0, 0, 10)
modalHeader.BackgroundTransparency = 1
modalHeader.Text = "🌟 ทะลวงขอบเขตสำเร็จ! 🌟"
modalHeader.TextColor3 = Color3.fromRGB(255, 215, 0)
modalHeader.Font = Enum.Font.SourceSansBold
modalHeader.TextSize = 24
modalHeader.ZIndex = 11
modalHeader.Parent = modalFrame

local modalRealm = Instance.new("TextLabel")
modalRealm.Name = "ModalRealm"
modalRealm.Size = UDim2.new(1, -20, 0, 30)
modalRealm.Position = UDim2.new(0, 10, 0, 52)
modalRealm.BackgroundTransparency = 1
modalRealm.Text = "ก้าวสู่ขอบเขต: [หลอมลมปราณ]"
modalRealm.TextColor3 = Color3.fromRGB(85, 255, 127)
modalRealm.Font = Enum.Font.SourceSansBold
modalRealm.TextSize = 20
modalRealm.ZIndex = 11
modalRealm.Parent = modalFrame

local modalTitle = Instance.new("TextLabel")
modalTitle.Name = "ModalTitle"
modalTitle.Size = UDim2.new(1, -20, 0, 25)
modalTitle.Position = UDim2.new(0, 10, 0, 84)
modalTitle.BackgroundTransparency = 1
modalTitle.Text = "ได้รับฉายาใหม่: «ผู้ฝึกหลอมลมปราณ»"
modalTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
modalTitle.Font = Enum.Font.SourceSans
modalTitle.TextSize = 17
modalTitle.ZIndex = 11
modalTitle.Parent = modalFrame

local modalStats = Instance.new("TextLabel")
modalStats.Name = "ModalStats"
modalStats.Size = UDim2.new(1, -30, 0, 50)
modalStats.Position = UDim2.new(0, 15, 0, 114)
modalStats.BackgroundTransparency = 1
modalStats.Text = "พลังชีวิตสูงสุด +150 | พลังโจมตี +25 | ป้องกัน +15 | ความเร็วเดินเพิ่มขึ้น!"
modalStats.TextColor3 = Color3.fromRGB(200, 230, 255)
modalStats.Font = Enum.Font.SourceSans
modalStats.TextSize = 15
modalStats.TextWrapped = true
modalStats.ZIndex = 11
modalStats.Parent = modalFrame

local closeBtn = Instance.new("TextButton")
closeBtn.Name = "CloseBtn"
closeBtn.Size = UDim2.new(0, 160, 0, 36)
closeBtn.Position = UDim2.new(0.5, -80, 0, 180)
closeBtn.BackgroundColor3 = Color3.fromRGB(220, 160, 20)
closeBtn.Text = "น้อมรับพลัง (ตกลง)"
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.Font = Enum.Font.SourceSansBold
closeBtn.TextSize = 16
closeBtn.ZIndex = 11
closeBtn.Parent = modalFrame

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 8)
closeCorner.Parent = closeBtn

closeBtn.MouseButton1Click:Connect(function()
    modalFrame.Visible = false
end)

--------------------------------------------------------------------------------
-- 3. ฟังก์ชันอัปเดต HUD ตามข้อมูลล่าสุด
--------------------------------------------------------------------------------
local currentCultivationData = nil
local pulsingTween = nil

local function updateHUD(data)
    if not data then return end
    currentCultivationData = data

    titleLabel.Text = "« " .. tostring(data.Title or "มนุษย์ปุถุชน") .. " »"
    titleLabel.TextColor3 = data.Color or Color3.fromRGB(180, 180, 180)
    realmLabel.Text = "☯ ขอบเขต: " .. tostring(data.RealmName or "คนธรรมดา")
    realmLabel.TextColor3 = data.Color or Color3.fromRGB(255, 255, 255)
    hudStroke.Color = data.Color or Color3.fromRGB(85, 255, 127)

    if data.IsMaxRealm then
        -- ขอบเขตสูงสุด
        progressFill.Size = UDim2.new(1, 0, 1, 0)
        progressFill.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
        progressText.Text = "👑 บรรลุขอบเขตสูงสุดแล้ว (ตบะ: " .. tostring(data.Tapasya) .. ")"
        breakthroughBtn.Text = "👑 บรรลุขอบเขตสูงสุดในปัจจุบัน"
        breakthroughBtn.BackgroundColor3 = Color3.fromRGB(45, 48, 55)
        breakthroughBtn.TextColor3 = Color3.fromRGB(150, 150, 150)
        breakthroughBtn.AutoButtonColor = false
        btnStroke.Color = Color3.fromRGB(60, 62, 70)
        if pulsingTween then pulsingTween:Cancel() end
    else
        local current = data.Tapasya or 0
        local required = data.RequiredExp or 1000
        local ratio = math.clamp(current / required, 0, 1)

        -- แอนิเมชันแถบหลอดตบะ
        local fillTween = TweenService:Create(progressFill, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Size = UDim2.new(ratio, 0, 1, 0)
        })
        fillTween:Play()

        local percent = math.floor(ratio * 100)
        progressText.Text = string.format("ตบะ: %d / %d (%d%%)", current, required, percent)

        if current >= required then
            -- ปลดล็อกปุ่มทะลวงขอบเขต!
            progressFill.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
            local totalChance = (data.TotalChance or 1.0) * 100
            local buff = (data.BreakthroughBuff or 0) * 100
            local chanceStr = ""
            if buff > 0 then
                chanceStr = string.format(" (โอกาส %.0f%% 💊+%.0f%%)", totalChance, buff)
            else
                chanceStr = string.format(" (โอกาส %.0f%%)", totalChance)
            end

            breakthroughBtn.Text = "⚡ ทะลวงสู่ [" .. tostring(data.NextRealmName) .. "]" .. chanceStr .. " ⚡"
            breakthroughBtn.BackgroundColor3 = Color3.fromRGB(220, 150, 15)
            breakthroughBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
            breakthroughBtn.AutoButtonColor = true
            btnStroke.Color = Color3.fromRGB(255, 230, 100)

            -- แอนิเมชันกระพริบดึงดูดสายตา
            if not pulsingTween then
                pulsingTween = TweenService:Create(btnStroke, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
                    Thickness = 3,
                    Color = Color3.fromRGB(255, 255, 255)
                })
                pulsingTween:Play()
            end
        else
            -- ตบะยังไม่พอ (ปุ่มล็อกอยู่)
            progressFill.BackgroundColor3 = data.Color or Color3.fromRGB(85, 255, 127)
            local diff = required - current
            breakthroughBtn.Text = string.format("🔒 ตบะยังไม่พอทะลวง (ขาดอีก %d แต้ม)", diff)
            breakthroughBtn.BackgroundColor3 = Color3.fromRGB(45, 48, 55)
            breakthroughBtn.TextColor3 = Color3.fromRGB(150, 150, 150)
            breakthroughBtn.AutoButtonColor = false
            btnStroke.Color = Color3.fromRGB(60, 62, 70)
            btnStroke.Thickness = 1.5

            if pulsingTween then
                pulsingTween:Cancel()
                pulsingTween = nil
            end
        end
    end
end

-- เมื่อกดปุ่มทะลวงขอบเขต
breakthroughBtn.MouseButton1Click:Connect(function()
    if not currentCultivationData then return end
    if currentCultivationData.IsMaxRealm then return end

    local current = currentCultivationData.Tapasya or 0
    local required = currentCultivationData.RequiredExp or 1000
    if current < required then
        -- แอนิเมชันสั่นปุ่มเบาๆ แจ้งเตือนว่ายังกดไม่ได้
        local origPos = breakthroughBtn.Position
        local shake1 = TweenService:Create(breakthroughBtn, TweenInfo.new(0.05), {Position = origPos + UDim2.new(0, -6, 0, 0)})
        local shake2 = TweenService:Create(breakthroughBtn, TweenInfo.new(0.05), {Position = origPos + UDim2.new(0, 6, 0, 0)})
        local shake3 = TweenService:Create(breakthroughBtn, TweenInfo.new(0.05), {Position = origPos})
        shake1:Play()
        shake1.Completed:Wait()
        shake2:Play()
        shake2.Completed:Wait()
        shake3:Play()
        return
    end

    -- ส่งคำขอไปยังเซิร์ฟเวอร์
    breakthroughBtn.Text = "⏳ กำลังรวบรวมลมปราณทะลวงขอบเขต..."
    local success, message, newRealm = NetworkEvents.Breakthrough:InvokeServer()

    if success and newRealm then
        -- แสดงป๊อปอัปความยินดี
        modalRealm.Text = "ก้าวสู่ขอบเขต: [" .. tostring(newRealm.Name) .. "]"
        modalRealm.TextColor3 = newRealm.Color or Color3.fromRGB(85, 255, 127)
        modalTitle.Text = "ได้รับฉายาใหม่: «" .. tostring(newRealm.Title) .. "»"
        modalStats.Text = string.format("พลังชีวิตสูงสุด %d | วิ่งเร็วขึ้น %d | พลังโจมตี %d | ป้องกัน %d",
            newRealm.Stats.MaxHealth, newRealm.Stats.WalkSpeed, newRealm.Stats.AttackPower, newRealm.Stats.Defense)
        modalFrame.Visible = true

        -- สั่นหน้าจอเบาๆ เพื่ออรรถรส
        local char = localPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then
            local origCameraOffset = hum.CameraOffset
            task.spawn(function()
                for i = 1, 6 do
                    hum.CameraOffset = origCameraOffset + Vector3.new(math.random(-1, 1) * 0.2, math.random(-1, 1) * 0.2, 0)
                    task.wait(0.04)
                end
                hum.CameraOffset = origCameraOffset
            end)
        end
    else
        breakthroughBtn.Text = "❌ " .. tostring(message or "ทะลวงขอบเขตล้มเหลว")
        task.wait(3.5)
        if currentCultivationData then updateHUD(currentCultivationData) end
    end
end)

-- รับข้อมูลซิงก์จากเซิร์ฟเวอร์
NetworkEvents.SyncCultivation.OnClientEvent:Connect(function(data)
    updateHUD(data)
end)

-- เอฟเฟกต์ทะลวงขอบเขตสำหรับแสดงผลผู้เล่นทุกคน
NetworkEvents.BreakthroughEffect.OnClientEvent:Connect(function(character, realmData)
    if not character then return end
    local head = character:FindFirstChild("Head")
    if not head then return end

    -- สร้างข้อความลอยเหนือหัว "突破! ทะลวงขอบเขตสำเร็จ!"
    local bill = Instance.new("BillboardGui")
    bill.Size = UDim2.new(0, 200, 0, 50)
    bill.StudsOffset = Vector3.new(0, 4.5, 0)
    bill.AlwaysOnTop = true
    bill.Parent = head

    local txt = Instance.new("TextLabel")
    txt.Size = UDim2.new(1, 0, 1, 0)
    txt.BackgroundTransparency = 1
    txt.Text = "⚡ ทะลวงขอบเขตสำเร็จ! ⚡"
    txt.TextColor3 = realmData.Color or Color3.fromRGB(255, 215, 0)
    txt.Font = Enum.Font.SourceSansBold
    txt.TextSize = 22
    txt.Parent = bill

    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 2
    stroke.Color = Color3.fromRGB(0, 0, 0)
    stroke.Parent = txt

    -- ลอยขึ้นและจางหายไป
    local moveTween = TweenService:Create(bill, TweenInfo.new(2.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        StudsOffset = Vector3.new(0, 7.5, 0)
    })
    local fadeTween = TweenService:Create(txt, TweenInfo.new(2.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        TextTransparency = 1
    })
    local strokeFade = TweenService:Create(stroke, TweenInfo.new(2.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Transparency = 1
    })

    moveTween:Play()
    fadeTween:Play()
    strokeFade:Play()

    task.delay(2.6, function()
        bill:Destroy()
    end)
end)

-- สังเกตการณ์การเปลี่ยนแปลงของ Leaderstats เป็น fallback
local function watchLeaderstats()
    local leaderstats = localPlayer:WaitForChild("leaderstats", 10)
    if leaderstats then
        local exp = leaderstats:WaitForChild("Tapasya", 5)
        if exp then
            exp.Changed:Connect(function(newVal)
                if currentCultivationData then
                    currentCultivationData.Tapasya = newVal
                    updateHUD(currentCultivationData)
                end
            end)
        end
    end
end
task.spawn(watchLeaderstats)

-- ขอข้อมูลรอบแรก
NetworkEvents.RequestInitialData:FireServer()

print("✅ [Client] Cultivation & Breakthrough Client UI พร้อมทำงาน!")
