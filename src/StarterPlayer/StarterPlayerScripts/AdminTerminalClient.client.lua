--[[
    AdminTerminalClient.client.lua
    UI หน้าต่าง Terminal สำหรับ Admin และ Tester ในการทดสอบและตรวจหาบั๊ค
    รองรับการพิมพ์คำสั่งผ่าน Command Line และปุ่ม Quick Actions
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")
local NetworkEvents = require(ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("NetworkEvents"))

-- สร้าง ScreenGui
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AdminTerminalGui"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

local hasAccess = false
local currentRole = nil
local commandHistory = {}
local historyIndex = 0

--------------------------------------------------------------------------------
-- 1. ปุ่มเปิด/ปิด Terminal ลอยบนหน้าจอ (Floating Button)
--------------------------------------------------------------------------------
local toggleButton = Instance.new("TextButton")
toggleButton.Name = "ToggleTerminal"
toggleButton.Size = UDim2.new(0, 150, 0, 36)
toggleButton.Position = UDim2.new(1, -165, 0, 15)
toggleButton.BackgroundColor3 = Color3.fromRGB(25, 30, 40)
toggleButton.Text = "💻 Tester Console"
toggleButton.TextColor3 = Color3.fromRGB(85, 200, 255)
toggleButton.Font = Enum.Font.SourceSansBold
toggleButton.TextSize = 15
toggleButton.Visible = false
toggleButton.Parent = screenGui

local btnCorner = Instance.new("UICorner")
btnCorner.CornerRadius = UDim.new(0, 8)
btnCorner.Parent = toggleButton

local btnStroke = Instance.new("UIStroke")
btnStroke.Thickness = 1.5
btnStroke.Color = Color3.fromRGB(85, 200, 255)
btnStroke.Parent = toggleButton

--------------------------------------------------------------------------------
-- 2. หน้าต่าง Terminal Window
--------------------------------------------------------------------------------
local terminalFrame = Instance.new("Frame")
terminalFrame.Name = "TerminalFrame"
terminalFrame.Size = UDim2.new(0, 620, 0, 420)
terminalFrame.Position = UDim2.new(0.5, -310, 0.5, -210)
terminalFrame.BackgroundColor3 = Color3.fromRGB(15, 17, 22)
terminalFrame.BorderSizePixel = 0
terminalFrame.Visible = false
terminalFrame.ClipsDescendants = true
terminalFrame.Parent = screenGui

local frameCorner = Instance.new("UICorner")
frameCorner.CornerRadius = UDim.new(0, 12)
frameCorner.Parent = terminalFrame

local frameStroke = Instance.new("UIStroke")
frameStroke.Thickness = 2
frameStroke.Color = Color3.fromRGB(85, 200, 255)
frameStroke.Parent = terminalFrame

-- Title Bar (แถบหัวเรื่อง)
local titleBar = Instance.new("Frame")
titleBar.Name = "TitleBar"
titleBar.Size = UDim2.new(1, 0, 0, 36)
titleBar.BackgroundColor3 = Color3.fromRGB(22, 25, 33)
titleBar.BorderSizePixel = 0
titleBar.Parent = terminalFrame

local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "TitleLabel"
titleLabel.Size = UDim2.new(0.7, 0, 1, 0)
titleLabel.Position = UDim2.new(0, 12, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "⚡ DAOIST TERMINAL v1.0 [Role: Guest]"
titleLabel.TextColor3 = Color3.fromRGB(85, 200, 255)
titleLabel.Font = Enum.Font.Code
titleLabel.TextSize = 14
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = titleBar

local closeBtn = Instance.new("TextButton")
closeBtn.Name = "CloseBtn"
closeBtn.Size = UDim2.new(0, 30, 0, 26)
closeBtn.Position = UDim2.new(1, -36, 0, 5)
closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
closeBtn.Text = "✕"
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.Font = Enum.Font.SourceSansBold
closeBtn.TextSize = 15
closeBtn.Parent = titleBar

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 6)
closeCorner.Parent = closeBtn

local clearBtn = Instance.new("TextButton")
clearBtn.Name = "ClearBtn"
clearBtn.Size = UDim2.new(0, 65, 0, 26)
clearBtn.Position = UDim2.new(1, -110, 0, 5)
clearBtn.BackgroundColor3 = Color3.fromRGB(40, 44, 55)
clearBtn.Text = "ล้างจอ"
clearBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
clearBtn.Font = Enum.Font.SourceSans
clearBtn.TextSize = 13
clearBtn.Parent = titleBar

local clearCorner = Instance.new("UICorner")
clearCorner.CornerRadius = UDim.new(0, 6)
clearCorner.Parent = clearBtn

-- Quick Actions Toolbar (แถบปุ่มลัดเพื่อความสะดวกในการทดสอบ)
local quickBar = Instance.new("ScrollingFrame")
quickBar.Name = "QuickBar"
quickBar.Size = UDim2.new(1, -20, 0, 34)
quickBar.Position = UDim2.new(0, 10, 0, 42)
quickBar.BackgroundTransparency = 1
quickBar.ScrollBarThickness = 3
quickBar.CanvasSize = UDim2.new(0, 1050, 0, 0)
quickBar.Parent = terminalFrame

local quickLayout = Instance.new("UIListLayout")
quickLayout.FillDirection = Enum.FillDirection.Horizontal
quickLayout.Padding = UDim.new(0, 6)
quickLayout.SortOrder = Enum.SortOrder.LayoutOrder
quickLayout.Parent = quickBar

-- Console Log Output (กล่องแสดงประวัติคำสั่งและผลลัพธ์)
local logBox = Instance.new("ScrollingFrame")
logBox.Name = "LogBox"
logBox.Size = UDim2.new(1, -20, 0, 280)
logBox.Position = UDim2.new(0, 10, 0, 82)
logBox.BackgroundColor3 = Color3.fromRGB(10, 12, 16)
logBox.BorderSizePixel = 0
logBox.ScrollBarThickness = 6
logBox.CanvasSize = UDim2.new(0, 0, 0, 0)
logBox.Parent = terminalFrame

local logCorner = Instance.new("UICorner")
logCorner.CornerRadius = UDim.new(0, 8)
logCorner.Parent = logBox

local logLayout = Instance.new("UIListLayout")
logLayout.Padding = UDim.new(0, 4)
logLayout.SortOrder = Enum.SortOrder.LayoutOrder
logLayout.Parent = logBox

local logPadding = Instance.new("UIPadding")
logPadding.PaddingLeft = UDim.new(0, 8)
logPadding.PaddingRight = UDim.new(0, 8)
logPadding.PaddingTop = UDim.new(0, 8)
logPadding.PaddingBottom = UDim.new(0, 8)
logPadding.Parent = logBox

-- Command Input Bar (แถบพิมพ์คำสั่งด้านล่าง)
local inputBar = Instance.new("Frame")
inputBar.Name = "InputBar"
inputBar.Size = UDim2.new(1, -20, 0, 40)
inputBar.Position = UDim2.new(0, 10, 1, -48)
inputBar.BackgroundColor3 = Color3.fromRGB(22, 25, 33)
inputBar.BorderSizePixel = 0
inputBar.Parent = terminalFrame

local inputCorner = Instance.new("UICorner")
inputCorner.CornerRadius = UDim.new(0, 8)
inputCorner.Parent = inputBar

local promptLabel = Instance.new("TextLabel")
promptLabel.Size = UDim2.new(0, 24, 1, 0)
promptLabel.BackgroundTransparency = 1
promptLabel.Text = ">"
promptLabel.TextColor3 = Color3.fromRGB(85, 255, 127)
promptLabel.Font = Enum.Font.Code
promptLabel.TextSize = 18
promptLabel.Parent = inputBar

local inputBox = Instance.new("TextBox")
inputBox.Name = "InputBox"
inputBox.Size = UDim2.new(1, -95, 1, 0)
inputBox.Position = UDim2.new(0, 26, 0, 0)
inputBox.BackgroundTransparency = 1
inputBox.ClearTextOnFocus = false
inputBox.PlaceholderText = "พิมพ์คำสั่ง เช่น help, addtapasya 1000, setrealm 2, grant <name>..."
inputBox.PlaceholderColor3 = Color3.fromRGB(120, 125, 140)
inputBox.TextColor3 = Color3.fromRGB(255, 255, 255)
inputBox.Font = Enum.Font.Code
inputBox.TextSize = 14
inputBox.TextXAlignment = Enum.TextXAlignment.Left
inputBox.Parent = inputBar

local runBtn = Instance.new("TextButton")
runBtn.Name = "RunBtn"
runBtn.Size = UDim2.new(0, 60, 0, 28)
runBtn.Position = UDim2.new(1, -66, 0, 6)
runBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 220)
runBtn.Text = "RUN"
runBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
runBtn.Font = Enum.Font.SourceSansBold
runBtn.TextSize = 14
runBtn.Parent = inputBar

local runCorner = Instance.new("UICorner")
runCorner.CornerRadius = UDim.new(0, 6)
runCorner.Parent = runBtn

--------------------------------------------------------------------------------
-- 3. ฟังก์ชันบันทึกข้อความลง Console (Print to Terminal)
--------------------------------------------------------------------------------
local function appendLog(text, color)
    color = color or Color3.fromRGB(220, 220, 220)
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 0, 0)
    label.AutomaticSize = Enum.AutomaticSize.Y
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = color
    label.Font = Enum.Font.Code
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextWrapped = true
    label.Parent = logBox

    -- อัปเดตขนาดเลื่อนของ Canvas และเลื่อนลงล่างสุดอัตโนมัติ
    task.defer(function()
        logBox.CanvasSize = UDim2.new(0, 0, 0, logLayout.AbsoluteContentSize.Y + 20)
        logBox.CanvasPosition = Vector2.new(0, logBox.CanvasSize.Y.Offset)
    end)
end

-- ล้างประวัติข้อความ
clearBtn.MouseButton1Click:Connect(function()
    for _, child in ipairs(logBox:GetChildren()) do
        if child:IsA("TextLabel") then
            child:Destroy()
        end
    end
    logBox.CanvasSize = UDim2.new(0, 0, 0, 0)
    appendLog("--- Console Cleared ---", Color3.fromRGB(150, 150, 150))
end)

--------------------------------------------------------------------------------
-- 4. การรันคำสั่ง (Execute Command)
--------------------------------------------------------------------------------
local function executeCommand(cmdStr)
    if not cmdStr or string.match(cmdStr, "^%s*$") then return end
    cmdStr = string.gsub(cmdStr, "^%s+", "")
    cmdStr = string.gsub(cmdStr, "%s+$", "")

    -- บันทึกประวัติคำสั่ง
    table.insert(commandHistory, cmdStr)
    historyIndex = #commandHistory + 1

    -- แสดงข้อความที่ผู้ใช้พิมพ์ใน Console
    appendLog("> " .. cmdStr, Color3.fromRGB(85, 200, 255))
    inputBox.Text = ""

    -- เคลียร์ console หากพิมพ์ 'clear'
    if cmdStr:lower() == "clear" or cmdStr:lower() == "cls" then
        clearBtn:Click()
        return
    end

    -- ส่งคำสั่งไปยัง Server
    local success, response = NetworkEvents.AdminCommand:InvokeServer(cmdStr)
    if success then
        appendLog(tostring(response), Color3.fromRGB(85, 255, 127))
    else
        appendLog(tostring(response), Color3.fromRGB(255, 85, 85))
    end
end

runBtn.MouseButton1Click:Connect(function()
    executeCommand(inputBox.Text)
end)

inputBox.FocusLost:Connect(function(enterPressed)
    if enterPressed then
        executeCommand(inputBox.Text)
    end
end)

-- ควบคุมประวัติคำสั่งด้วยปุ่มลูกศรขึ้น/ลง (Arrow Up/Down)
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not terminalFrame.Visible then return end

    if input.KeyCode == Enum.KeyCode.Up then
        if #commandHistory > 0 then
            historyIndex = math.clamp(historyIndex - 1, 1, #commandHistory)
            inputBox.Text = commandHistory[historyIndex] or ""
            inputBox.CursorPosition = #inputBox.Text + 1
        end
    elseif input.KeyCode == Enum.KeyCode.Down then
        if #commandHistory > 0 then
            historyIndex = math.clamp(historyIndex + 1, 1, #commandHistory + 1)
            if historyIndex > #commandHistory then
                inputBox.Text = ""
            else
                inputBox.Text = commandHistory[historyIndex] or ""
                inputBox.CursorPosition = #inputBox.Text + 1
            end
        end
    end
end)

--------------------------------------------------------------------------------
-- 5. สร้างปุ่ม Quick Actions ใน QuickBar
--------------------------------------------------------------------------------
local function createQuickButton(name, command, bgColor)
    local btn = Instance.new("TextButton")
    btn.Name = name
    btn.Size = UDim2.new(0, 100, 0, 28)
    btn.AutomaticSize = Enum.AutomaticSize.X
    btn.BackgroundColor3 = bgColor or Color3.fromRGB(35, 40, 52)
    btn.Text = "  " .. name .. "  "
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Font = Enum.Font.SourceSansBold
    btn.TextSize = 13
    btn.Parent = quickBar

    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 6)
    c.Parent = btn

    btn.MouseButton1Click:Connect(function()
        executeCommand(command)
    end)
    return btn
end

createQuickButton("+1,000 ตบะ", "addtapasya 1000", Color3.fromRGB(40, 90, 60))
createQuickButton("+10,000 ตบะ", "addtapasya 10000", Color3.fromRGB(40, 110, 70))
createQuickButton("⚡ ทะลวงขั้น", "breakthrough", Color3.fromRGB(180, 120, 20))
createQuickButton("🌿 เสกสมุนไพรทั้งหมด", "giveallherbs 5", Color3.fromRGB(30, 80, 110))
createQuickButton("💊 เสกโอสถทั้งหมด", "giveallpills 5", Color3.fromRGB(150, 80, 40))
createQuickButton("🌱 สปอนสมุนไพร x5", "spawnherb 5", Color3.fromRGB(40, 100, 100))
createQuickButton("💖 ฮีลเลือดเต็ม", "heal", Color3.fromRGB(140, 40, 40))
createQuickButton("🏃 ความเร็ว 32", "speed 32", Color3.fromRGB(110, 60, 130))
createQuickButton("🚶 ความเร็วปกติ 16", "speed 16", Color3.fromRGB(60, 60, 70))
createQuickButton("📊 ดูสเตตัส", "info", Color3.fromRGB(50, 70, 90))
createQuickButton("🏛️ วาร์ปไปเมือง", "tpzone city", Color3.fromRGB(80, 100, 140))
createQuickButton("🌿 วาร์ปไป PvE", "tpzone pve", Color3.fromRGB(40, 120, 90))
createQuickButton("⚔️ วาร์ปไป PvP", "tpzone pvp", Color3.fromRGB(140, 50, 50))
createQuickButton("👥 ดูรายชื่อ Tester", "testers", Color3.fromRGB(70, 50, 90))

--------------------------------------------------------------------------------
-- 6. การเปิด/ปิดหน้าต่างและการจัดการสิทธิ์
--------------------------------------------------------------------------------
local function toggleTerminal()
    if not hasAccess then return end
    terminalFrame.Visible = not terminalFrame.Visible
    if terminalFrame.Visible then
        inputBox:CaptureFocus()
    end
end

toggleButton.MouseButton1Click:Connect(toggleTerminal)
closeBtn.MouseButton1Click:Connect(function()
    terminalFrame.Visible = false
end)

-- กด F2 หรือปุ่ม `~` (Backquote) หรือ F4 เพื่อเปิด/ปิด Terminal
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed and input.KeyCode ~= Enum.KeyCode.F2 and input.KeyCode ~= Enum.KeyCode.Backquote then
        return
    end
    if input.KeyCode == Enum.KeyCode.F2 or input.KeyCode == Enum.KeyCode.Backquote or input.KeyCode == Enum.KeyCode.F4 then
        toggleTerminal()
    end
end)

-- อัปเดตสถานะสิทธิ์
local function updateAccess(access, role)
    hasAccess = access
    currentRole = role

    if hasAccess then
        toggleButton.Visible = true
        toggleButton.Text = string.format("💻 Terminal [%s]", role or "Tester")
        titleLabel.Text = string.format("⚡ DAOIST BOUNDLESS TERMINAL [Role: %s]", role or "Tester")
        appendLog(string.format("=== [สิทธิ์พร้อมใช้งาน: %s] กด F2 หรือคลิกปุ่มบนเพื่อเปิด/ปิด ===", role or "Tester"), Color3.fromRGB(85, 255, 127))
        appendLog("พิมพ์ 'help' เพื่อดูคำสั่งทั้งหมด หรือใช้ปุ่มลัดด้านบน", Color3.fromRGB(200, 200, 200))
    else
        toggleButton.Visible = false
        terminalFrame.Visible = false
    end
end

-- รับการแจ้งเตือนสิทธิ์แบบ Real-time จาก Admin
NetworkEvents.AdminStatusChanged.OnClientEvent:Connect(function(access, role)
    updateAccess(access, role)
    if access then
        -- แจ้งเตือนบนหน้าจอว่าได้รับสิทธิ์
        appendLog(string.format("🎉 คุณได้รับสิทธิ์ [%s] เรียบร้อยแล้ว!", role), Color3.fromRGB(255, 215, 0))
    end
end)

-- ตรวจสอบสิทธิ์เริ่มต้นเมื่อเข้าเกม
task.spawn(function()
    task.wait(1)
    local access, role = NetworkEvents.CheckAdminAccess:InvokeServer()
    updateAccess(access, role)
end)

print("✅ [Client] Admin & Tester Terminal UI พร้อมทำงาน! (กด F2 เพื่อเปิด)")

