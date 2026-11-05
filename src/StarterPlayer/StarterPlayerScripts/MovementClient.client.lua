--[[
    MovementClient.client.lua
    ระบบเคลื่อนไหวและการกลิ้งหลบ (Martial Arts Roll-Dodge System)
    - กดปุ่ม LeftShift / RightShift หรือคลิกปุ่มบนหน้าจอเพื่อกลิ้งหลบ
    - ระยะพุ่งไกลขึ้น (~35 studs) พร้อมแอนิเมชันม้วนตัวตีลังกา 360 องศาแนบพื้น (Combat Roll)
    - มอบสถานะอมตะชั่วพริบตา (I-Frames: IsDodging = true) ขณะกลิ้งหลบการโจมตี
    - เอฟเฟกต์วงแหวนลมปราณระเบิดพื้น (Shockwave Dust Ring) และ Camera Tilt / FOV Punch
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local localPlayer = Players.LocalPlayer
local camera = Workspace.CurrentCamera
local playerGui = localPlayer:WaitForChild("PlayerGui")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MovementGui"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

-- ปุ่ม Dash / Roll ลอยสำหรับผู้เล่นบนมือถือ
local rollBtn = Instance.new("TextButton")
rollBtn.Name = "RollButton"
rollBtn.Size = UDim2.new(0, 68, 0, 68)
rollBtn.Position = UDim2.new(1, -90, 1, -155)
rollBtn.BackgroundColor3 = Color3.fromRGB(24, 32, 45)
rollBtn.Text = "🥋\nกลิ้งหลบ"
rollBtn.TextColor3 = Color3.fromRGB(150, 225, 255)
rollBtn.Font = Enum.Font.SourceSansBold
rollBtn.TextSize = 13
rollBtn.Parent = screenGui

local dbCorner = Instance.new("UICorner")
dbCorner.CornerRadius = UDim.new(0, 34)
dbCorner.Parent = rollBtn

local dbStroke = Instance.new("UIStroke")
dbStroke.Thickness = 2
dbStroke.Color = Color3.fromRGB(85, 200, 255)
dbStroke.Parent = rollBtn

local canRoll = true
local ROLL_COOLDOWN = 0.95
local ROLL_SPEED = 105      -- ความเร็วพุ่งไกลขึ้นอย่างเห็นได้ชัด
local ROLL_DURATION = 0.38   -- ระยะเวลาการม้วนตัวกลิ้ง

-- ค้นหา RootJoint ในตัวละคร (รองรับทั้ง R15 และ R6)
local function getRootJoint(char)
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return nil end

    local lowerTorso = char:FindFirstChild("LowerTorso")
    local torso = char:FindFirstChild("Torso")
    local target = lowerTorso or torso

    if target then
        for _, joint in ipairs(target:GetChildren()) do
            if joint:IsA("Motor6D") and (joint.Part0 == root or joint.Part1 == root) then
                return joint
            end
        end
    end
    for _, joint in ipairs(root:GetChildren()) do
        if joint:IsA("Motor6D") and (joint.Part0 == target or joint.Part1 == target) then
            return joint
        end
    end
    return nil
end

-- สร้างเอฟเฟกต์ละอองฝุ่นและคลื่นลมปราณใต้เท้า
local function createRollDustRing(cframe)
    local part = Instance.new("Part")
    part.Size = Vector3.new(2, 0.2, 2)
    part.CFrame = cframe * CFrame.new(0, -2, 0)
    part.Transparency = 1
    part.Anchored = true
    part.CanCollide = false
    part.Parent = Workspace

    -- วงแหวนละอองไอเซียนกระจายออก
    local emitter = Instance.new("ParticleEmitter")
    emitter.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(200, 240, 255)),
        ColorSequenceKeypoint.new(0.6, Color3.fromRGB(120, 200, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 140, 180))
    })
    emitter.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1.2),
        NumberSequenceKeypoint.new(0.5, 3.5),
        NumberSequenceKeypoint.new(1, 0)
    })
    emitter.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.2),
        NumberSequenceKeypoint.new(1, 1)
    })
    emitter.Lifetime = NumberRange.new(0.3, 0.5)
    emitter.Speed = NumberRange.new(15, 28)
    emitter.SpreadAngle = Vector2.new(10, 360)
    emitter.Rate = 200
    emitter.Parent = part

    emitter:Emit(40)
    task.delay(0.6, function()
        part:Destroy()
    end)
end

-- ฟังก์ชันการกลิ้งหลบ (Roll-Dodge)
local function performRollDodge()
    if not canRoll then return end

    local char = localPlayer.Character
    if not char then return end

    local hum = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    if not hum or not root or hum.Health <= 0 then return end

    canRoll = false
    char:SetAttribute("IsDodging", true) -- ให้สถานะ I-Frames อมตะชั่วขณะ

    -- ทิศทางกลิ้ง: ตามทิศที่กำลังก้าวเดิน (MoveDirection) หรือทิศที่ตัวละครหันหน้า
    local rollDir = hum.MoveDirection
    if rollDir.Magnitude < 0.1 then
        rollDir = root.CFrame.LookVector
    else
        rollDir = rollDir.Unit
    end

    -- หมุนตัวละครให้หันไปในทิศทางที่จะกลิ้งอย่างรวดเร็ว
    root.CFrame = CFrame.lookAt(root.Position, root.Position + Vector3.new(rollDir.X, 0, rollDir.Z))

    -- สร้างเอฟเฟกต์คลื่นลมใต้เท้า
    createRollDustRing(root.CFrame)

    -- เพิ่มความเร็วพุ่งตัวไปข้างหน้าแบบแนบพื้น
    local startTime = os.clock()
    local rootJoint = getRootJoint(char)
    local origC0 = rootJoint and rootJoint.C0

    -- ปรับ Camera FOV & Tilt ชั่วคราว
    local origFOV = camera and camera.FieldOfView or 70
    if camera then
        TweenService:Create(camera, TweenInfo.new(0.12, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
            FieldOfView = origFOV + 14
        }):Play()
    end

    -- Loop ควบคุมการเคลื่อนที่และม้วนตัว 360 องศา (Procedural Somersault Roll)
    local rollConn
    rollConn = RunService.RenderStepped:Connect(function()
        local elapsed = os.clock() - startTime
        local progress = math.clamp(elapsed / ROLL_DURATION, 0, 1)

        if progress < 1 and hum.Health > 0 then
            -- รักษาความเร็วพุ่งตัวไปข้างหน้า
            local currentSpeed = ROLL_SPEED * (1 - (progress * 0.4)) -- ชะลอเล็กน้อยช่วงปลาย
            local currentVelY = math.clamp(root.AssemblyLinearVelocity.Y, -30, 2)
            root.AssemblyLinearVelocity = Vector3.new(rollDir.X * currentSpeed, currentVelY, rollDir.Z * currentSpeed)

            -- แอนิเมชันตีลังกากลิ้ง 360 องศา พร้อมย่อตัวลงใกล้พื้น (Tuck & Roll)
            if rootJoint and origC0 then
                local rollAngle = progress * 360
                local tuckY = -math.sin(progress * math.pi) * 1.3 -- ย่อตัวลง 1.3 studs ช่วงกลาง
                rootJoint.C0 = origC0 
                    * CFrame.new(0, tuckY, 0)
                    * CFrame.Angles(-math.rad(rollAngle), 0, 0)
            end
        else
            -- จบระยะเวลาการกลิ้ง
            rollConn:Disconnect()
            char:SetAttribute("IsDodging", nil)

            -- คืนค่า Joint ให้กลับมาตั้งตรง
            if rootJoint and origC0 then
                TweenService:Create(rootJoint, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                    C0 = origC0
                }):Play()
            end

            -- คืนค่า Camera FOV
            if camera then
                TweenService:Create(camera, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                    FieldOfView = origFOV
                }):Play()
            end

            -- คลื่นลมกระจายตอนสปริงตัวลุกขึ้น
            createRollDustRing(root.CFrame)
        end
    end)

    -- คูลดาวน์ปุ่ม
    rollBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    rollBtn.TextColor3 = Color3.fromRGB(130, 130, 130)

    task.delay(ROLL_COOLDOWN, function()
        canRoll = true
        rollBtn.BackgroundColor3 = Color3.fromRGB(24, 32, 45)
        rollBtn.TextColor3 = Color3.fromRGB(150, 225, 255)
    end)
end

rollBtn.MouseButton1Click:Connect(performRollDodge)

-- ตรวจจับการกดปุ่ม Shift
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
        performRollDodge()
    end
end)

print("✅ [Client] Martial Arts Roll-Dodge System (Shift เพื่อกลิ้งหลบ) พร้อมทำงาน!")
