--[[
    AlchemyUI.client.lua
    หอหลอมโอสถสวรรค์เก้าดารา (Nine Stars Celestial Alchemy Pavilion)
    ระบบสูตรยาพลวัต (Dynamic Pharmacopoeia Engine) & สารบบมหาตำราโอสถ 50 ขนาน
    
    คุณสมบัติหลัก:
    1. แก้ไขบั๊คสมุนไพร 3 ชนิด: ดึงข้อมูลครบทั้ง 100 ชนิดจาก HerbDatabase พร้อมตัวกรองและช่องค้นหา
    2. จุดเตาหลอม & มินิเกม 3 ขั้นตอน: ควบคุมความร้อน (Heat), กวนประสาน (Stir), ผนึกปราณ (Chi QTE)
    3. สารบบตำรับยาที่ค้นพบ: บันทึกความก้าวหน้า 50 ขนานยาตาม 6 สำนักใหญ่ พร้อมคำใบ้และราคาซื้อ/ขาย
    4. ย่ามเก็บโอสถ: แสดงเม็ดยาที่ครอบครอง พร้อมปุ่มกลืนโอสถรับบัฟตบะ พลังชีวิต และความเร็ว
    5. สปอนเตาหลอม 3D เมื่อเริ่มปรุงยา และสลายเตาหลอมเมื่อปิดหน้าต่าง
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local GameConfig = require(ReplicatedStorage:WaitForChild("SharedModules"):WaitForChild("GameConfig"))
local HerbDatabase = require(ReplicatedStorage:WaitForChild("SharedModules"):WaitForChild("HerbDatabase"))
local PillDatabase = require(ReplicatedStorage:WaitForChild("SharedModules"):WaitForChild("PillDatabase"))
local NetworkEvents = require(ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("NetworkEvents"))

--------------------------------------------------------------------------------
-- สถานะตัวแปรระบบ (Client State)
--------------------------------------------------------------------------------
local currentInventory = {}
local discoveredPills = {}
local selectedIngredients = {} -- { [herbName] = count }
local currentTab = "Craft" -- "Craft" | "Recipes" | "Pouch"
local isMinigameActive = false

-- ตัวกรองสมุนไพร
local herbSearchText = ""
local selectedTierFilter = 0 -- 0 = ทั้งหมด, 1-6
local showOnlyOwnedHerbs = true

-- ตัวกรองสารบบยา
local selectedSchoolFilter = 0 -- 0 = ทั้งหมด, 1-6

--------------------------------------------------------------------------------
-- 1. สร้าง ScreenGui & วิดเจ็ตหลัก
--------------------------------------------------------------------------------
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AlchemyGui"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

-- ปุ่มลอยเปิดเตาหลอมบนหน้าจอ (Floating Button)
local toggleButton = Instance.new("TextButton")
toggleButton.Name = "ToggleAlchemy"
toggleButton.Size = UDim2.new(0, 54, 0, 54)
toggleButton.Position = UDim2.new(1, -68, 0.5, 45)
toggleButton.BackgroundColor3 = Color3.fromRGB(35, 24, 18)
toggleButton.Text = "🔥"
toggleButton.TextSize = 28
toggleButton.Parent = screenGui

local tbCorner = Instance.new("UICorner")
tbCorner.CornerRadius = UDim.new(0, 27)
tbCorner.Parent = toggleButton

local tbStroke = Instance.new("UIStroke")
tbStroke.Thickness = 2
tbStroke.Color = Color3.fromRGB(255, 175, 45)
tbStroke.Parent = toggleButton

-- หน้าต่างหลัก (Main Frame)
local mainFrame = Instance.new("Frame")
mainFrame.Name = "AlchemyFrame"
mainFrame.Size = UDim2.new(0, 840, 0, 540)
mainFrame.Position = UDim2.new(0.5, -420, 0.5, -270)
mainFrame.BackgroundColor3 = Color3.fromRGB(16, 18, 24)
mainFrame.BorderSizePixel = 0
mainFrame.Visible = false
mainFrame.ClipsDescendants = true
mainFrame.Parent = screenGui

local frameCorner = Instance.new("UICorner")
frameCorner.CornerRadius = UDim.new(0, 14)
frameCorner.Parent = mainFrame

local frameStroke = Instance.new("UIStroke")
frameStroke.Thickness = 2
frameStroke.Color = Color3.fromRGB(220, 160, 45)
frameStroke.Parent = mainFrame

-- Title Bar (แถบหัวเรื่อง)
local titleBar = Instance.new("Frame")
titleBar.Name = "TitleBar"
titleBar.Size = UDim2.new(1, 0, 0, 44)
titleBar.BackgroundColor3 = Color3.fromRGB(26, 22, 28)
titleBar.BorderSizePixel = 0
titleBar.Parent = mainFrame

local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "TitleLabel"
titleLabel.Size = UDim2.new(0.65, 0, 1, 0)
titleLabel.Position = UDim2.new(0, 16, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "🔥 หอหลอมโอสถสวรรค์เก้าดารา (Nine Stars Alchemy Pavilion)"
titleLabel.TextColor3 = Color3.fromRGB(255, 215, 80)
titleLabel.Font = Enum.Font.SourceSansBold
titleLabel.TextSize = 17
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = titleBar

-- ปุ่มสารานุกรมสมุนไพรด้านบนขวา
local compendiumBtn = Instance.new("TextButton")
compendiumBtn.Name = "CompendiumBtn"
compendiumBtn.Size = UDim2.new(0, 140, 0, 30)
compendiumBtn.Position = UDim2.new(1, -190, 0, 7)
compendiumBtn.BackgroundColor3 = Color3.fromRGB(35, 75, 55)
compendiumBtn.Text = "📖 สมุดสมุนไพร 100 ชนิด"
compendiumBtn.TextColor3 = Color3.fromRGB(160, 255, 190)
compendiumBtn.Font = Enum.Font.SourceSansBold
compendiumBtn.TextSize = 13
compendiumBtn.Parent = titleBar

local compCorner = Instance.new("UICorner")
compCorner.CornerRadius = UDim.new(0, 6)
compCorner.Parent = compendiumBtn

compendiumBtn.MouseButton1Click:Connect(function()
    if _G.OpenHerbCompendium then
        _G.OpenHerbCompendium()
    end
end)

local closeBtn = Instance.new("TextButton")
closeBtn.Name = "CloseBtn"
closeBtn.Size = UDim2.new(0, 32, 0, 30)
closeBtn.Position = UDim2.new(1, -42, 0, 7)
closeBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
closeBtn.Text = "✕"
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.Font = Enum.Font.SourceSansBold
closeBtn.TextSize = 16
closeBtn.Parent = titleBar

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 6)
closeCorner.Parent = closeBtn

--------------------------------------------------------------------------------
-- 2. แถบเลือกแท็บเมนูหลัก (3 แท็บ)
--------------------------------------------------------------------------------
local tabFrame = Instance.new("Frame")
tabFrame.Name = "TabFrame"
tabFrame.Size = UDim2.new(1, -30, 0, 36)
tabFrame.Position = UDim2.new(0, 15, 0, 52)
tabFrame.BackgroundTransparency = 1
tabFrame.Parent = mainFrame

local tabCraft = Instance.new("TextButton")
tabCraft.Name = "TabCraft"
tabCraft.Size = UDim2.new(0.32, 0, 1, 0)
tabCraft.Position = UDim2.new(0, 0, 0, 0)
tabCraft.BackgroundColor3 = Color3.fromRGB(220, 140, 30)
tabCraft.Text = "⚗️ จุดเตาปรุงยาโอสถ"
tabCraft.TextColor3 = Color3.fromRGB(255, 255, 255)
tabCraft.Font = Enum.Font.SourceSansBold
tabCraft.TextSize = 14
tabCraft.Parent = tabFrame

local tc1 = Instance.new("UICorner")
tc1.CornerRadius = UDim.new(0, 8)
tc1.Parent = tabCraft

local tabRecipes = Instance.new("TextButton")
tabRecipes.Name = "TabRecipes"
tabRecipes.Size = UDim2.new(0.35, 0, 1, 0)
tabRecipes.Position = UDim2.new(0.33, 0, 0, 0)
tabRecipes.BackgroundColor3 = Color3.fromRGB(30, 35, 48)
tabRecipes.Text = "📜 สารบบตำรับยาที่ค้นพบ (0/50)"
tabRecipes.TextColor3 = Color3.fromRGB(180, 190, 210)
tabRecipes.Font = Enum.Font.SourceSansBold
tabRecipes.TextSize = 14
tabRecipes.Parent = tabFrame

local tc2 = Instance.new("UICorner")
tc2.CornerRadius = UDim.new(0, 8)
tc2.Parent = tabRecipes

local tabPouch = Instance.new("TextButton")
tabPouch.Name = "TabPouch"
tabPouch.Size = UDim2.new(0.31, 0, 1, 0)
tabPouch.Position = UDim2.new(0.69, 0, 0, 0)
tabPouch.BackgroundColor3 = Color3.fromRGB(30, 35, 48)
tabPouch.Text = "🎒 ย่ามเก็บโอสถ (0)"
tabPouch.TextColor3 = Color3.fromRGB(180, 190, 210)
tabPouch.Font = Enum.Font.SourceSansBold
tabPouch.TextSize = 14
tabPouch.Parent = tabFrame

local tc3 = Instance.new("UICorner")
tc3.CornerRadius = UDim.new(0, 8)
tc3.Parent = tabPouch

--------------------------------------------------------------------------------
-- 3. แท็บที่ 1: เตาหลอมโอสถ & มินิเกม (CraftView)
--------------------------------------------------------------------------------
local craftView = Instance.new("Frame")
craftView.Name = "CraftView"
craftView.Size = UDim2.new(1, -30, 1, -102)
craftView.Position = UDim2.new(0, 15, 0, 96)
craftView.BackgroundTransparency = 1
craftView.Parent = mainFrame

-- ด้านซ้าย: การเลือกสมุนไพรลงเตา (Herb Selector)
local leftHerbPanel = Instance.new("Frame")
leftHerbPanel.Name = "LeftHerbPanel"
leftHerbPanel.Size = UDim2.new(0.48, 0, 1, 0)
leftHerbPanel.BackgroundColor3 = Color3.fromRGB(12, 14, 20)
leftHerbPanel.BorderSizePixel = 0
leftHerbPanel.Parent = craftView

local lhpCorner = Instance.new("UICorner")
lhpCorner.CornerRadius = UDim.new(0, 10)
lhpCorner.Parent = leftHerbPanel

-- ช่องค้นหาสมุนไพร
local searchBar = Instance.new("TextBox")
searchBar.Name = "SearchBar"
searchBar.Size = UDim2.new(1, -16, 0, 32)
searchBar.Position = UDim2.new(0, 8, 0, 8)
searchBar.BackgroundColor3 = Color3.fromRGB(22, 26, 36)
searchBar.ClearTextOnFocus = false
searchBar.PlaceholderText = "🔍 ค้นหาชื่อสมุนไพร หรือธาตุ (เช่น ไฟ, เหมันต์)..."
searchBar.PlaceholderColor3 = Color3.fromRGB(120, 130, 150)
searchBar.TextColor3 = Color3.fromRGB(255, 255, 255)
searchBar.Font = Enum.Font.SourceSans
searchBar.TextSize = 13
searchBar.Parent = leftHerbPanel

local sbCorner = Instance.new("UICorner")
sbCorner.CornerRadius = UDim.new(0, 6)
sbCorner.Parent = searchBar

-- แถบตัวกรองระดับ & ตัวเลือกแสดงเฉพาะในย่าม
local filterRow = Instance.new("Frame")
filterRow.Size = UDim2.new(1, -16, 0, 26)
filterRow.Position = UDim2.new(0, 8, 0, 44)
filterRow.BackgroundTransparency = 1
filterRow.Parent = leftHerbPanel

local ownedToggleBtn = Instance.new("TextButton")
ownedToggleBtn.Size = UDim2.new(0, 135, 1, 0)
ownedToggleBtn.BackgroundColor3 = Color3.fromRGB(40, 120, 80)
ownedToggleBtn.Text = "✓ มีในย่ามเท่านั้น"
ownedToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ownedToggleBtn.Font = Enum.Font.SourceSansBold
ownedToggleBtn.TextSize = 12
ownedToggleBtn.Parent = filterRow

local otCorner = Instance.new("UICorner")
otCorner.CornerRadius = UDim.new(0, 5)
otCorner.Parent = ownedToggleBtn

local clearSelectionBtn = Instance.new("TextButton")
clearSelectionBtn.Size = UDim2.new(0, 85, 1, 0)
clearSelectionBtn.Position = UDim2.new(1, -85, 0, 0)
clearSelectionBtn.BackgroundColor3 = Color3.fromRGB(70, 40, 45)
clearSelectionBtn.Text = "🗑️ ล้างเตา"
clearSelectionBtn.TextColor3 = Color3.fromRGB(255, 180, 180)
clearSelectionBtn.Font = Enum.Font.SourceSansBold
clearSelectionBtn.TextSize = 12
clearSelectionBtn.Parent = filterRow

local csCorner = Instance.new("UICorner")
csCorner.CornerRadius = UDim.new(0, 5)
csCorner.Parent = clearSelectionBtn

-- กล่องเลื่อนรายการสมุนไพร 100 ชนิด
local herbScrollBox = Instance.new("ScrollingFrame")
herbScrollBox.Name = "HerbScrollBox"
herbScrollBox.Size = UDim2.new(1, -16, 1, -78)
herbScrollBox.Position = UDim2.new(0, 8, 0, 74)
herbScrollBox.BackgroundColor3 = Color3.fromRGB(16, 18, 26)
herbScrollBox.BorderSizePixel = 0
herbScrollBox.ScrollBarThickness = 5
herbScrollBox.CanvasSize = UDim2.new(0, 0, 0, 0)
herbScrollBox.Parent = leftHerbPanel

local hsbCorner = Instance.new("UICorner")
hsbCorner.CornerRadius = UDim.new(0, 6)
hsbCorner.Parent = herbScrollBox

local hsbLayout = Instance.new("UIListLayout")
hsbLayout.Padding = UDim.new(0, 6)
hsbLayout.SortOrder = Enum.SortOrder.LayoutOrder
hsbLayout.Parent = herbScrollBox

local hsbPadding = Instance.new("UIPadding")
hsbPadding.PaddingTop = UDim.new(0, 6)
hsbPadding.PaddingLeft = UDim.new(0, 6)
hsbPadding.PaddingRight = UDim.new(0, 6)
hsbPadding.PaddingBottom = UDim.new(0, 6)
hsbPadding.Parent = herbScrollBox

-- ด้านขวา: สถานะเตาหลอม & มินิเกม (Right Panel)
local rightCauldronPanel = Instance.new("Frame")
rightCauldronPanel.Name = "RightCauldronPanel"
rightCauldronPanel.Size = UDim2.new(0.50, 0, 1, 0)
rightCauldronPanel.Position = UDim2.new(0.50, 0, 0, 0)
rightCauldronPanel.BackgroundColor3 = Color3.fromRGB(12, 14, 20)
rightCauldronPanel.BorderSizePixel = 0
rightCauldronPanel.Parent = craftView

local rcpCorner = Instance.new("UICorner")
rcpCorner.CornerRadius = UDim.new(0, 10)
rcpCorner.Parent = rightCauldronPanel

-- หน้าสรุปส่วนผสมก่อนเริ่มหลอม (Prep View)
local prepView = Instance.new("Frame")
prepView.Name = "PrepView"
prepView.Size = UDim2.new(1, 0, 1, 0)
prepView.BackgroundTransparency = 1
prepView.Parent = rightCauldronPanel

local prepTitle = Instance.new("TextLabel")
prepTitle.Size = UDim2.new(1, -24, 0, 28)
prepTitle.Position = UDim2.new(0, 12, 0, 10)
prepTitle.BackgroundTransparency = 1
prepTitle.Text = "⚗️ เตาหลอมเก้ามังกรโกลาหล (Active Cauldron)"
prepTitle.TextColor3 = Color3.fromRGB(255, 215, 80)
prepTitle.Font = Enum.Font.SourceSansBold
prepTitle.TextSize = 16
prepTitle.TextXAlignment = Enum.TextXAlignment.Left
prepTitle.Parent = prepView

-- กล่องแสดงสมุนไพรที่ใส่ในเตา
local selectedHerbsBox = Instance.new("ScrollingFrame")
selectedHerbsBox.Size = UDim2.new(1, -24, 0, 110)
selectedHerbsBox.Position = UDim2.new(0, 12, 0, 42)
selectedHerbsBox.BackgroundColor3 = Color3.fromRGB(18, 22, 32)
selectedHerbsBox.BorderSizePixel = 0
selectedHerbsBox.ScrollBarThickness = 4
selectedHerbsBox.Parent = prepView

local shbCorner = Instance.new("UICorner")
shbCorner.CornerRadius = UDim.new(0, 6)
shbCorner.Parent = selectedHerbsBox

local shbLayout = Instance.new("UIListLayout")
shbLayout.Padding = UDim.new(0, 4)
shbLayout.SortOrder = Enum.SortOrder.LayoutOrder
shbLayout.Parent = selectedHerbsBox

local shbPadding = Instance.new("UIPadding")
shbPadding.PaddingTop = UDim.new(0, 6)
shbPadding.PaddingLeft = UDim.new(0, 6)
shbPadding.PaddingRight = UDim.new(0, 6)
shbPadding.PaddingBottom = UDim.new(0, 6)
shbPadding.Parent = selectedHerbsBox

-- กล่องข้อมูลและสถิติการปรุงยา
local statsCard = Instance.new("Frame")
statsCard.Size = UDim2.new(1, -24, 0, 150)
statsCard.Position = UDim2.new(0, 12, 0, 160)
statsCard.BackgroundColor3 = Color3.fromRGB(18, 22, 32)
statsCard.BorderSizePixel = 0
statsCard.Parent = prepView

local scCorner = Instance.new("UICorner")
scCorner.CornerRadius = UDim.new(0, 8)
scCorner.Parent = statsCard

local totalHerbsLabel = Instance.new("TextLabel")
totalHerbsLabel.Size = UDim2.new(0.5, -10, 0, 22)
totalHerbsLabel.Position = UDim2.new(0, 10, 0, 8)
totalHerbsLabel.BackgroundTransparency = 1
totalHerbsLabel.Text = "สมุนไพรในเตา: 0 ต้น"
totalHerbsLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
totalHerbsLabel.Font = Enum.Font.SourceSansBold
totalHerbsLabel.TextSize = 13
totalHerbsLabel.TextXAlignment = Enum.TextXAlignment.Left
totalHerbsLabel.Parent = statsCard

local totalPotencyLabel = Instance.new("TextLabel")
totalPotencyLabel.Size = UDim2.new(0.5, -10, 0, 22)
totalPotencyLabel.Position = UDim2.new(0.5, 0, 0, 8)
totalPotencyLabel.BackgroundTransparency = 1
totalPotencyLabel.Text = "พลังงานรวม: 0 หน่วย"
totalPotencyLabel.TextColor3 = Color3.fromRGB(85, 200, 255)
totalPotencyLabel.Font = Enum.Font.SourceSansBold
totalPotencyLabel.TextSize = 13
totalPotencyLabel.TextXAlignment = Enum.TextXAlignment.Left
totalPotencyLabel.Parent = statsCard

-- หลอดความเสถียรของเตาหลอม (Stability Bar)
local stabilityLabel = Instance.new("TextLabel")
stabilityLabel.Size = UDim2.new(1, -20, 0, 18)
stabilityLabel.Position = UDim2.new(0, 10, 0, 32)
stabilityLabel.BackgroundTransparency = 1
stabilityLabel.Text = "ความเสถียรของเตา: 100% (ปลอดภัย)"
stabilityLabel.TextColor3 = Color3.fromRGB(85, 255, 127)
stabilityLabel.Font = Enum.Font.SourceSans
stabilityLabel.TextSize = 12
stabilityLabel.TextXAlignment = Enum.TextXAlignment.Left
stabilityLabel.Parent = statsCard

local stabilityBarBg = Instance.new("Frame")
stabilityBarBg.Size = UDim2.new(1, -20, 0, 10)
stabilityBarBg.Position = UDim2.new(0, 10, 0, 52)
stabilityBarBg.BackgroundColor3 = Color3.fromRGB(30, 34, 45)
stabilityBarBg.BorderSizePixel = 0
stabilityBarBg.Parent = statsCard

local sbbCorner = Instance.new("UICorner")
sbbCorner.CornerRadius = UDim.new(0, 5)
sbbCorner.Parent = stabilityBarBg

local stabilityBarFill = Instance.new("Frame")
stabilityBarFill.Size = UDim2.new(1, 0, 1, 0)
stabilityBarFill.BackgroundColor3 = Color3.fromRGB(85, 255, 127)
stabilityBarFill.BorderSizePixel = 0
stabilityBarFill.Parent = stabilityBarBg

local sbfCorner = Instance.new("UICorner")
sbfCorner.CornerRadius = UDim.new(0, 5)
sbfCorner.Parent = stabilityBarFill

-- การคาดการณ์ผลลัพธ์โอสถ
local predictionHeader = Instance.new("TextLabel")
predictionHeader.Size = UDim2.new(1, -20, 0, 18)
predictionHeader.Position = UDim2.new(0, 10, 0, 68)
predictionHeader.BackgroundTransparency = 1
predictionHeader.Text = "🔮 คาดการณ์โอสถที่จะได้:"
predictionHeader.TextColor3 = Color3.fromRGB(255, 200, 80)
predictionHeader.Font = Enum.Font.SourceSansBold
predictionHeader.TextSize = 13
predictionHeader.TextXAlignment = Enum.TextXAlignment.Left
predictionHeader.Parent = statsCard

local targetPillPreview = Instance.new("TextLabel")
targetPillPreview.Size = UDim2.new(1, -20, 0, 36)
targetPillPreview.Position = UDim2.new(0, 10, 0, 88)
targetPillPreview.BackgroundTransparency = 1
targetPillPreview.Text = "ยังไม่ได้ใส่สมุนไพรลงในเตา"
targetPillPreview.TextColor3 = Color3.fromRGB(160, 165, 180)
targetPillPreview.Font = Enum.Font.SourceSansBold
targetPillPreview.TextSize = 14
targetPillPreview.TextWrapped = true
targetPillPreview.TextXAlignment = Enum.TextXAlignment.Left
targetPillPreview.Parent = statsCard

-- ป้ายเตือนอันตรายเตาระเบิดหรือกลายพันธุ์
local warningLabel = Instance.new("TextLabel")
warningLabel.Size = UDim2.new(1, -20, 0, 20)
warningLabel.Position = UDim2.new(0, 10, 0, 126)
warningLabel.BackgroundTransparency = 1
warningLabel.Text = "✨ สภาวะเตาหลอมพร้อมทำงาน"
warningLabel.TextColor3 = Color3.fromRGB(140, 200, 160)
warningLabel.Font = Enum.Font.SourceSans
warningLabel.TextSize = 12
warningLabel.TextXAlignment = Enum.TextXAlignment.Left
warningLabel.Parent = statsCard

-- ปุ่มเริ่มมินิเกมปรุงยา
local startMinigameBtn = Instance.new("TextButton")
startMinigameBtn.Name = "StartMinigameBtn"
startMinigameBtn.Size = UDim2.new(1, -24, 0, 48)
startMinigameBtn.Position = UDim2.new(0, 12, 1, -58)
startMinigameBtn.BackgroundColor3 = Color3.fromRGB(60, 65, 75)
startMinigameBtn.Text = "🔒 กรุณาเลือกสมุนไพรอย่างน้อย 1 ต้น"
startMinigameBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
startMinigameBtn.Font = Enum.Font.SourceSansBold
startMinigameBtn.TextSize = 15
startMinigameBtn.Parent = prepView

local smgCorner = Instance.new("UICorner")
smgCorner.CornerRadius = UDim.new(0, 8)
smgCorner.Parent = startMinigameBtn

--------------------------------------------------------------------------------
-- หน้าจอมินิเกม 3 ขั้นตอน (Minigame View)
--------------------------------------------------------------------------------
local minigameView = Instance.new("Frame")
minigameView.Name = "MinigameView"
minigameView.Size = UDim2.new(1, 0, 1, 0)
minigameView.BackgroundTransparency = 1
minigameView.Visible = false
minigameView.Parent = rightCauldronPanel

local mgStepTitle = Instance.new("TextLabel")
mgStepTitle.Size = UDim2.new(1, -24, 0, 30)
mgStepTitle.Position = UDim2.new(0, 12, 0, 16)
mgStepTitle.BackgroundTransparency = 1
mgStepTitle.Text = "ขั้นที่ 1: ควบคุมความร้อน (Heat Control)"
mgStepTitle.TextColor3 = Color3.fromRGB(255, 215, 80)
mgStepTitle.Font = Enum.Font.SourceSansBold
mgStepTitle.TextSize = 17
mgStepTitle.TextXAlignment = Enum.TextXAlignment.Left
mgStepTitle.Parent = minigameView

local mgStepInstruction = Instance.new("TextLabel")
mgStepInstruction.Size = UDim2.new(1, -24, 0, 36)
mgStepInstruction.Position = UDim2.new(0, 12, 0, 48)
mgStepInstruction.BackgroundTransparency = 1
mgStepInstruction.Text = "กดปุ่มเร่งไฟเพื่อรักษาอุณหภูมิให้อยู่ในแถบสีทอง!"
mgStepInstruction.TextColor3 = Color3.fromRGB(180, 190, 210)
mgStepInstruction.Font = Enum.Font.SourceSans
mgStepInstruction.TextSize = 13
mgStepInstruction.TextXAlignment = Enum.TextXAlignment.Left
mgStepInstruction.Parent = minigameView

-- ลู่เกจวัด (Minigame Gauge Track)
local gaugeTrack = Instance.new("Frame")
gaugeTrack.Size = UDim2.new(1, -36, 0, 32)
gaugeTrack.Position = UDim2.new(0, 18, 0, 100)
gaugeTrack.BackgroundColor3 = Color3.fromRGB(25, 28, 38)
gaugeTrack.BorderSizePixel = 0
gaugeTrack.Parent = minigameView

local gtCorner = Instance.new("UICorner")
gtCorner.CornerRadius = UDim.new(0, 8)
gtCorner.Parent = gaugeTrack

local targetZone = Instance.new("Frame")
targetZone.Size = UDim2.new(0.3, 0, 1, 0)
targetZone.Position = UDim2.new(0.35, 0, 0, 0)
targetZone.BackgroundColor3 = Color3.fromRGB(240, 180, 40)
targetZone.BorderSizePixel = 0
targetZone.Parent = gaugeTrack

local tzCorner = Instance.new("UICorner")
tzCorner.CornerRadius = UDim.new(0, 8)
tzCorner.Parent = targetZone

local needle = Instance.new("Frame")
needle.Size = UDim2.new(0, 6, 1, 8)
needle.Position = UDim2.new(0.5, -3, 0, -4)
needle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
needle.BorderSizePixel = 0
needle.Parent = gaugeTrack

local needleStroke = Instance.new("UIStroke")
needleStroke.Thickness = 1.5
needleStroke.Color = Color3.fromRGB(0, 200, 255)
needleStroke.Parent = needle

local mgTimerLabel = Instance.new("TextLabel")
mgTimerLabel.Size = UDim2.new(1, -36, 0, 24)
mgTimerLabel.Position = UDim2.new(0, 18, 0, 144)
mgTimerLabel.BackgroundTransparency = 1
mgTimerLabel.Text = "เวลาเหลือ: 3.0 วินาที"
mgTimerLabel.TextColor3 = Color3.fromRGB(255, 140, 40)
mgTimerLabel.Font = Enum.Font.SourceSansBold
mgTimerLabel.TextSize = 14
mgTimerLabel.Parent = minigameView

local scoreDisplay = Instance.new("TextLabel")
scoreDisplay.Size = UDim2.new(1, -36, 0, 24)
scoreDisplay.Position = UDim2.new(0, 18, 0, 172)
scoreDisplay.BackgroundTransparency = 1
scoreDisplay.Text = "ความแม่นยำ: 0%"
scoreDisplay.TextColor3 = Color3.fromRGB(85, 255, 127)
scoreDisplay.Font = Enum.Font.SourceSansBold
scoreDisplay.TextSize = 15
scoreDisplay.Parent = minigameView

local mgActionBtn = Instance.new("TextButton")
mgActionBtn.Size = UDim2.new(1, -36, 0, 50)
mgActionBtn.Position = UDim2.new(0, 18, 1, -70)
mgActionBtn.BackgroundColor3 = Color3.fromRGB(220, 140, 30)
mgActionBtn.Text = "🔥 เร่งไฟ (พัดลมปราณ)"
mgActionBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
mgActionBtn.Font = Enum.Font.SourceSansBold
mgActionBtn.TextSize = 16
mgActionBtn.Parent = minigameView

local mabCorner = Instance.new("UICorner")
mabCorner.CornerRadius = UDim.new(0, 8)
mabCorner.Parent = mgActionBtn

--------------------------------------------------------------------------------
-- 4. แท็บที่ 2: สารบบตำรับยาที่ค้นพบ (RecipeBookView - 50 ขนานยา)
--------------------------------------------------------------------------------
local recipeBookView = Instance.new("Frame")
recipeBookView.Name = "RecipeBookView"
recipeBookView.Size = UDim2.new(1, -30, 1, -102)
recipeBookView.Position = UDim2.new(0, 15, 0, 96)
recipeBookView.BackgroundTransparency = 1
recipeBookView.Visible = false
recipeBookView.Parent = mainFrame

-- แถบสถิติความก้าวหน้าการค้นพบ (Discovery Progress Bar)
local recipeProgressFrame = Instance.new("Frame")
recipeProgressFrame.Size = UDim2.new(1, 0, 0, 42)
recipeProgressFrame.BackgroundColor3 = Color3.fromRGB(12, 14, 20)
recipeProgressFrame.BorderSizePixel = 0
recipeProgressFrame.Parent = recipeBookView

local rpfCorner = Instance.new("UICorner")
rpfCorner.CornerRadius = UDim.new(0, 8)
rpfCorner.Parent = recipeProgressFrame

local discoveryCountLabel = Instance.new("TextLabel")
discoveryCountLabel.Size = UDim2.new(0.5, 0, 0, 20)
discoveryCountLabel.Position = UDim2.new(0, 12, 0, 6)
discoveryCountLabel.BackgroundTransparency = 1
discoveryCountLabel.Text = "มหาตำราโอสถเก้าสวรรค์: ค้นพบแล้ว 0 / 50 ขนานยา"
discoveryCountLabel.TextColor3 = Color3.fromRGB(255, 215, 80)
discoveryCountLabel.Font = Enum.Font.SourceSansBold
discoveryCountLabel.TextSize = 13
discoveryCountLabel.TextXAlignment = Enum.TextXAlignment.Left
discoveryCountLabel.Parent = recipeProgressFrame

local recipeProgressBarBg = Instance.new("Frame")
recipeProgressBarBg.Size = UDim2.new(1, -24, 0, 8)
recipeProgressBarBg.Position = UDim2.new(0, 12, 0, 28)
recipeProgressBarBg.BackgroundColor3 = Color3.fromRGB(28, 32, 44)
recipeProgressBarBg.BorderSizePixel = 0
recipeProgressBarBg.Parent = recipeProgressFrame

local rpbbCorner = Instance.new("UICorner")
rpbbCorner.CornerRadius = UDim.new(0, 4)
rpbbCorner.Parent = recipeProgressBarBg

local recipeProgressBarFill = Instance.new("Frame")
recipeProgressBarFill.Size = UDim2.new(0, 0, 1, 0)
recipeProgressBarFill.BackgroundColor3 = Color3.fromRGB(240, 180, 40)
recipeProgressBarFill.BorderSizePixel = 0
recipeProgressBarFill.Parent = recipeProgressBarBg

local rpbfCorner = Instance.new("UICorner")
rpbfCorner.CornerRadius = UDim.new(0, 4)
rpbfCorner.Parent = recipeProgressBarFill

-- แถบเลือกสำนักโอสถ (6 สำนักใหญ่)
local schoolScroll = Instance.new("ScrollingFrame")
schoolScroll.Size = UDim2.new(1, 0, 0, 36)
schoolScroll.Position = UDim2.new(0, 0, 0, 48)
schoolScroll.BackgroundTransparency = 1
schoolScroll.ScrollBarThickness = 3
schoolScroll.CanvasSize = UDim2.new(0, 950, 0, 0)
schoolScroll.Parent = recipeBookView

local schoolLayout = Instance.new("UIListLayout")
schoolLayout.FillDirection = Enum.FillDirection.Horizontal
schoolLayout.Padding = UDim.new(0, 6)
schoolLayout.Parent = schoolScroll

-- กล่องเลื่อนแสดงการ์ดตำรับยา (Recipe Cards Grid)
local recipeScrollBox = Instance.new("ScrollingFrame")
recipeScrollBox.Name = "RecipeScrollBox"
recipeScrollBox.Size = UDim2.new(1, 0, 1, -92)
recipeScrollBox.Position = UDim2.new(0, 0, 0, 90)
recipeScrollBox.BackgroundColor3 = Color3.fromRGB(12, 14, 20)
recipeScrollBox.BorderSizePixel = 0
recipeScrollBox.ScrollBarThickness = 6
recipeScrollBox.CanvasSize = UDim2.new(0, 0, 0, 0)
recipeScrollBox.Parent = recipeBookView

local rsbCorner = Instance.new("UICorner")
rsbCorner.CornerRadius = UDim.new(0, 8)
rsbCorner.Parent = recipeScrollBox

local rsbLayout = Instance.new("UIGridLayout")
rsbLayout.CellSize = UDim2.new(0.485, 0, 0, 126)
rsbLayout.CellPadding = UDim2.new(0.02, 0, 0, 8)
rsbLayout.SortOrder = Enum.SortOrder.LayoutOrder
rsbLayout.Parent = recipeScrollBox

local rsbPadding = Instance.new("UIPadding")
rsbPadding.PaddingTop = UDim.new(0, 8)
rsbPadding.PaddingLeft = UDim.new(0, 8)
rsbPadding.PaddingRight = UDim.new(0, 8)
rsbPadding.PaddingBottom = UDim.new(0, 8)
rsbPadding.Parent = recipeScrollBox

--------------------------------------------------------------------------------
-- 5. แท็บที่ 3: ย่ามเก็บโอสถ (PillPouchView)
--------------------------------------------------------------------------------
local pouchView = Instance.new("ScrollingFrame")
pouchView.Name = "PouchView"
pouchView.Size = UDim2.new(1, -30, 1, -102)
pouchView.Position = UDim2.new(0, 15, 0, 96)
pouchView.BackgroundColor3 = Color3.fromRGB(12, 14, 20)
pouchView.BorderSizePixel = 0
pouchView.ScrollBarThickness = 6
pouchView.Visible = false
pouchView.Parent = mainFrame

local pvCorner = Instance.new("UICorner")
pvCorner.CornerRadius = UDim.new(0, 8)
pvCorner.Parent = pouchView

local pvLayout = Instance.new("UIListLayout")
pvLayout.Padding = UDim.new(0, 8)
pvLayout.SortOrder = Enum.SortOrder.LayoutOrder
pvLayout.Parent = pouchView

local pvPadding = Instance.new("UIPadding")
pvPadding.PaddingTop = UDim.new(0, 10)
pvPadding.PaddingLeft = UDim.new(0, 10)
pvPadding.PaddingRight = UDim.new(0, 10)
pvPadding.PaddingBottom = UDim.new(0, 10)
pvPadding.Parent = pouchView

--------------------------------------------------------------------------------
-- 6. ฟังก์ชันคำนวณและแสดงผลรายการสมุนไพร 100 ชนิด
--------------------------------------------------------------------------------
local function updateHerbListUI()
    for _, child in ipairs(herbScrollBox:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end

    local totalHerbsInCauldron = 0
    local totalPotency = 0
    local totalStability = 100
    local elementCounts = {}
    local dominantElement = "Wood"
    local maxElemCount = 0

    local query = string.lower(herbSearchText)

    -- วนลูปสมุนไพรครบทั้ง 100 ชนิดจาก HerbDatabase
    for _, herb in ipairs(HerbDatabase.GetAll()) do
        local herbName = herb.Name
        local owned = currentInventory[herbName] or 0
        local chosen = selectedIngredients[herbName] or 0

        -- ตรวจสอบว่ามีจำนวนเกินที่มีในกระเป๋าหรือไม่
        if chosen > owned then
            chosen = owned
            selectedIngredients[herbName] = chosen
        end

        if chosen > 0 then
            totalHerbsInCauldron = totalHerbsInCauldron + chosen
            totalPotency = totalPotency + (chosen * (herb.Potency or 15))
            totalStability = totalStability + (chosen * (herb.Stability or 0))

            local elem = herb.Element or "Wood"
            elementCounts[elem] = (elementCounts[elem] or 0) + (chosen * (herb.Potency or 15))
            if elementCounts[elem] > maxElemCount then
                maxElemCount = elementCounts[elem]
                dominantElement = elem
            end
        end

        -- ตรวจสอบตัวกรอง (Filter Criteria)
        local matchesFilter = true
        if showOnlyOwnedHerbs and owned <= 0 then
            matchesFilter = false
        end

        if query ~= "" then
            local matchName = string.find(string.lower(herbName), query)
            local matchElem = string.find(string.lower(herb.Element or ""), query)
            local matchTier = string.find(string.lower(herb.TierName or ""), query)
            if not matchName and not matchElem and not matchTier then
                matchesFilter = false
            end
        end

        if matchesFilter then
            local card = Instance.new("Frame")
            card.Name = herbName
            card.Size = UDim2.new(1, 0, 0, 68)
            card.BackgroundColor3 = (chosen > 0) and Color3.fromRGB(28, 36, 50) or Color3.fromRGB(18, 22, 30)
            card.BorderSizePixel = 0
            card.Parent = herbScrollBox

            local cCorner = Instance.new("UICorner")
            cCorner.CornerRadius = UDim.new(0, 6)
            cCorner.Parent = card

            local cStroke = Instance.new("UIStroke")
            cStroke.Thickness = 1.2
            cStroke.Color = (chosen > 0) and Color3.fromRGB(240, 180, 40) or Color3.fromRGB(38, 44, 58)
            cStroke.Parent = card

            -- แถบสีธาตุด้านซ้าย
            local elemBar = Instance.new("Frame")
            elemBar.Size = UDim2.new(0, 4, 1, 0)
            elemBar.BackgroundColor3 = herb.Color or Color3.fromRGB(120, 200, 140)
            elemBar.BorderSizePixel = 0
            elemBar.Parent = card

            local ebCorner = Instance.new("UICorner")
            ebCorner.CornerRadius = UDim.new(0, 2)
            ebCorner.Parent = elemBar

            local nameLbl = Instance.new("TextLabel")
            nameLbl.Size = UDim2.new(0.60, 0, 0, 22)
            nameLbl.Position = UDim2.new(0, 12, 0, 6)
            nameLbl.BackgroundTransparency = 1
            nameLbl.Text = string.format("%s [ขั้น %d]", herbName, herb.Tier or 1)
            nameLbl.TextColor3 = herb.Color or Color3.fromRGB(255, 255, 255)
            nameLbl.Font = Enum.Font.SourceSansBold
            nameLbl.TextSize = 13
            nameLbl.TextXAlignment = Enum.TextXAlignment.Left
            nameLbl.Parent = card

            local statsLbl = Instance.new("TextLabel")
            statsLbl.Size = UDim2.new(0.60, 0, 0, 18)
            statsLbl.Position = UDim2.new(0, 12, 0, 26)
            statsLbl.BackgroundTransparency = 1
            statsLbl.Text = string.format("ธาตุ: %s | ฤทธิ์: +%d | เสถียร: %+d", herb.Element or "Wood", herb.Potency or 15, herb.Stability or 0)
            statsLbl.TextColor3 = Color3.fromRGB(150, 165, 185)
            statsLbl.Font = Enum.Font.SourceSans
            statsLbl.TextSize = 11
            statsLbl.TextXAlignment = Enum.TextXAlignment.Left
            statsLbl.Parent = card

            local ownedLbl = Instance.new("TextLabel")
            ownedLbl.Size = UDim2.new(0.60, 0, 0, 18)
            ownedLbl.Position = UDim2.new(0, 12, 0, 44)
            ownedLbl.BackgroundTransparency = 1
            ownedLbl.Text = string.format("มีในย่าม: %d ชิ้น", owned)
            ownedLbl.TextColor3 = (owned > 0) and Color3.fromRGB(85, 255, 127) or Color3.fromRGB(120, 125, 135)
            ownedLbl.Font = Enum.Font.SourceSans
            ownedLbl.TextSize = 11
            ownedLbl.TextXAlignment = Enum.TextXAlignment.Left
            ownedLbl.Parent = card

            -- ปุ่มควบคุมลด (-)
            local minusBtn = Instance.new("TextButton")
            minusBtn.Size = UDim2.new(0, 24, 0, 24)
            minusBtn.Position = UDim2.new(1, -95, 0.5, -12)
            minusBtn.BackgroundColor3 = Color3.fromRGB(45, 50, 65)
            minusBtn.Text = "-"
            minusBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
            minusBtn.Font = Enum.Font.SourceSansBold
            minusBtn.TextSize = 15
            minusBtn.Parent = card

            local mbCorner = Instance.new("UICorner")
            mbCorner.CornerRadius = UDim.new(0, 4)
            mbCorner.Parent = minusBtn

            local countLbl = Instance.new("TextLabel")
            countLbl.Size = UDim2.new(0, 28, 0, 24)
            countLbl.Position = UDim2.new(1, -68, 0.5, -12)
            countLbl.BackgroundTransparency = 1
            countLbl.Text = tostring(chosen)
            countLbl.TextColor3 = (chosen > 0) and Color3.fromRGB(85, 255, 127) or Color3.fromRGB(150, 150, 150)
            countLbl.Font = Enum.Font.SourceSansBold
            countLbl.TextSize = 14
            countLbl.Parent = card

            -- ปุ่มควบคุมเพิ่ม (+)
            local plusBtn = Instance.new("TextButton")
            plusBtn.Size = UDim2.new(0, 24, 0, 24)
            plusBtn.Position = UDim2.new(1, -38, 0.5, -12)
            plusBtn.BackgroundColor3 = (owned > chosen) and Color3.fromRGB(50, 100, 70) or Color3.fromRGB(45, 50, 65)
            plusBtn.Text = "+"
            plusBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
            plusBtn.Font = Enum.Font.SourceSansBold
            plusBtn.TextSize = 15
            plusBtn.Parent = card

            local pbCorner = Instance.new("UICorner")
            pbCorner.CornerRadius = UDim.new(0, 4)
            pbCorner.Parent = plusBtn

            minusBtn.MouseButton1Click:Connect(function()
                if chosen > 0 then
                    selectedIngredients[herbName] = chosen - 1
                    updateHerbListUI()
                end
            end)

            plusBtn.MouseButton1Click:Connect(function()
                if chosen < owned then
                    selectedIngredients[herbName] = chosen + 1
                    updateHerbListUI()
                end
            end)
        end
    end

    herbScrollBox.CanvasSize = UDim2.new(0, 0, 0, hsbLayout.AbsoluteContentSize.Y + 20)

    -- อัปเดตรายการสมุนไพรในเตา (Selected Herbs Box)
    for _, child in ipairs(selectedHerbsBox:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end

    for herbName, count in pairs(selectedIngredients) do
        if count > 0 then
            local herb = HerbDatabase.Get(herbName)
            local itemCard = Instance.new("Frame")
            itemCard.Size = UDim2.new(1, 0, 0, 26)
            itemCard.BackgroundColor3 = Color3.fromRGB(25, 30, 42)
            itemCard.BorderSizePixel = 0
            itemCard.Parent = selectedHerbsBox

            local icCorner = Instance.new("UICorner")
            icCorner.CornerRadius = UDim.new(0, 4)
            icCorner.Parent = itemCard

            local nameTxt = Instance.new("TextLabel")
            nameTxt.Size = UDim2.new(0.7, 0, 1, 0)
            nameTxt.Position = UDim2.new(0, 8, 0, 0)
            nameTxt.BackgroundTransparency = 1
            nameTxt.Text = string.format("🌿 %s (x%d)", herbName, count)
            nameTxt.TextColor3 = herb and herb.Color or Color3.fromRGB(240, 240, 240)
            nameTxt.Font = Enum.Font.SourceSansBold
            nameTxt.TextSize = 12
            nameTxt.TextXAlignment = Enum.TextXAlignment.Left
            nameTxt.Parent = itemCard

            local removeBtn = Instance.new("TextButton")
            removeBtn.Size = UDim2.new(0, 22, 0, 20)
            removeBtn.Position = UDim2.new(1, -26, 0.5, -10)
            removeBtn.BackgroundColor3 = Color3.fromRGB(150, 40, 40)
            removeBtn.Text = "✕"
            removeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
            removeBtn.Font = Enum.Font.SourceSansBold
            removeBtn.TextSize = 11
            removeBtn.Parent = itemCard

            local rcCorner = Instance.new("UICorner")
            rcCorner.CornerRadius = UDim.new(0, 3)
            rcCorner.Parent = removeBtn

            removeBtn.MouseButton1Click:Connect(function()
                selectedIngredients[herbName] = nil
                updateHerbListUI()
            end)
        end
    end

    selectedHerbsBox.CanvasSize = UDim2.new(0, 0, 0, shbLayout.AbsoluteContentSize.Y + 10)

    -- คำนวณความเสถียรและเตือนภัย
    totalStability = math.clamp(totalStability, 0, 100)
    totalHerbsLabel.Text = string.format("สมุนไพรในเตา: %d ต้น", totalHerbsInCauldron)
    totalPotencyLabel.Text = string.format("พลังงานรวม: %d หน่วย", totalPotency)
    stabilityLabel.Text = string.format("ความเสถียรของเตา: %d%%", totalStability)
    stabilityBarFill.Size = UDim2.new(totalStability / 100, 0, 1, 0)

    local fireEnergy = elementCounts["Fire"] or 0
    local iceEnergy = elementCounts["Ice"] or 0

    if fireEnergy >= 60 and iceEnergy >= 60 then
        stabilityBarFill.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
        warningLabel.Text = "💥 อันตราย: ธาตุไฟและเหมันต์ปะทะกันรุนแรง เตาอาจระเบิด!"
        warningLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
    elseif totalStability < 35 then
        stabilityBarFill.BackgroundColor3 = Color3.fromRGB(255, 140, 40)
        warningLabel.Text = "⚠️ ความไม่เสถียรสูง: มีโอกาสเกิดโอสถกลายพันธุ์ (Mutated Pill)!"
        warningLabel.TextColor3 = Color3.fromRGB(255, 160, 50)
    else
        stabilityBarFill.BackgroundColor3 = Color3.fromRGB(85, 255, 127)
        warningLabel.Text = "✨ สภาวะเตาหลอมสมดุลและปลอดภัย"
        warningLabel.TextColor3 = Color3.fromRGB(140, 220, 160)
    end

    -- คาดการณ์ผลลัพธ์โอสถ
    if totalHerbsInCauldron > 0 then
        -- สแกนสูตรมาตรฐานที่น่าจะตรง
        local predictedName = "โอสถพลังวิญญาณผ่าเหล่า (Procedural)"
        local matchedPill = nil
        for _, p in ipairs(PillDatabase.GetAll()) do
            if p.RequiredElement == dominantElement and totalPotency >= (p.MinPotency or 20) then
                matchedPill = p
                break
            end
        end

        if matchedPill then
            predictedName = matchedPill.Name .. " (" .. matchedPill.SchoolName:sub(1, 15) .. "...)"
        elseif totalPotency < 20 then
            predictedName = "โอสถขยะกากเดน (Slag Pellet)"
        end

        targetPillPreview.Text = "✨ " .. predictedName
        targetPillPreview.TextColor3 = Color3.fromRGB(255, 215, 80)

        startMinigameBtn.BackgroundColor3 = Color3.fromRGB(220, 140, 30)
        startMinigameBtn.Text = "🔥 สปอนเตาหลอม & เริ่มสมาธิปรุงยา"
        startMinigameBtn.AutoButtonColor = true
    else
        targetPillPreview.Text = "ยังไม่ได้เลือกสมุนไพรลงในเตา"
        targetPillPreview.TextColor3 = Color3.fromRGB(150, 155, 170)

        startMinigameBtn.BackgroundColor3 = Color3.fromRGB(50, 55, 65)
        startMinigameBtn.Text = "🔒 กรุณาเลือกสมุนไพรอย่างน้อย 1 ต้น"
        startMinigameBtn.AutoButtonColor = false
    end
end

-- สลับตัวกรอง "มีในย่ามเท่านั้น"
ownedToggleBtn.MouseButton1Click:Connect(function()
    showOnlyOwnedHerbs = not showOnlyOwnedHerbs
    if showOnlyOwnedHerbs then
        ownedToggleBtn.Text = "✓ มีในย่ามเท่านั้น"
        ownedToggleBtn.BackgroundColor3 = Color3.fromRGB(40, 120, 80)
    else
        ownedToggleBtn.Text = "🌐 แสดงสมุนไพรทั้งหมด"
        ownedToggleBtn.BackgroundColor3 = Color3.fromRGB(60, 70, 90)
    end
    updateHerbListUI()
end)

-- ล้างสมุนไพรในเตา
clearSelectionBtn.MouseButton1Click:Connect(function()
    selectedIngredients = {}
    updateHerbListUI()
end)

-- ช่องค้นหาเมื่อผู้เล่นพิมพ์
searchBar:GetPropertyChangedSignal("Text"):Connect(function()
    herbSearchText = searchBar.Text
    updateHerbListUI()
end)

--------------------------------------------------------------------------------
-- 7. ฟังก์ชันแสดงสารบบตำรับยาที่ค้นพบ (RecipeBookView)
--------------------------------------------------------------------------------
local function renderRecipeBookView()
    for _, child in ipairs(recipeScrollBox:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end

    local discoveredCount = 0
    local allPills = PillDatabase.GetAll()
    local totalPillsCount = #allPills

    for _, p in ipairs(allPills) do
        if discoveredPills[p.Name] or discoveredPills[p.NameEN] then
            discoveredCount = discoveredCount + 1
        end
    end

    -- อัปเดตแถบความก้าวหน้า
    tabRecipes.Text = string.format("📜 สารบบตำรับยาที่ค้นพบ (%d/%d)", discoveredCount, totalPillsCount)
    discoveryCountLabel.Text = string.format("มหาตำราโอสถเก้าสวรรค์: ค้นพบแล้ว %d / %d ขนานยา (%.0f%%)", 
        discoveredCount, totalPillsCount, (discoveredCount / totalPillsCount) * 100)
    recipeProgressBarFill.Size = UDim2.new(math.clamp(discoveredCount / totalPillsCount, 0, 1), 0, 1, 0)

    for _, pill in ipairs(allPills) do
        if selectedSchoolFilter == 0 or pill.School == selectedSchoolFilter then
            local isUnlocked = (discoveredPills[pill.Name] == true or discoveredPills[pill.NameEN] == true)

            local card = Instance.new("Frame")
            card.Size = UDim2.new(0, 0, 0, 126)
            card.BackgroundColor3 = isUnlocked and Color3.fromRGB(22, 26, 36) or Color3.fromRGB(15, 17, 24)
            card.BorderSizePixel = 0
            card.Parent = recipeScrollBox

            local cCorner = Instance.new("UICorner")
            cCorner.CornerRadius = UDim.new(0, 8)
            cCorner.Parent = card

            local cStroke = Instance.new("UIStroke")
            cStroke.Thickness = isUnlocked and 1.5 or 1
            cStroke.Color = isUnlocked and Color3.fromRGB(240, 180, 40) or Color3.fromRGB(40, 44, 56)
            cStroke.Parent = card

            if isUnlocked then
                -- ชื่อยาและชื่อภาษาอังกฤษ
                local nameLbl = Instance.new("TextLabel")
                nameLbl.Size = UDim2.new(1, -16, 0, 22)
                nameLbl.Position = UDim2.new(0, 10, 0, 6)
                nameLbl.BackgroundTransparency = 1
                nameLbl.Text = string.format("💊 %s (%s)", pill.Name, pill.NameEN or "")
                nameLbl.TextColor3 = pill.Color or Color3.fromRGB(255, 215, 80)
                nameLbl.Font = Enum.Font.SourceSansBold
                nameLbl.TextSize = 13
                nameLbl.TextXAlignment = Enum.TextXAlignment.Left
                nameLbl.Parent = card

                local tagLbl = Instance.new("TextLabel")
                tagLbl.Size = UDim2.new(1, -16, 0, 18)
                tagLbl.Position = UDim2.new(0, 10, 0, 28)
                tagLbl.BackgroundTransparency = 1
                tagLbl.Text = string.format("ระดับ %d | ธาตุ: %s | ตัวนำทาง: %s", pill.Tier or 1, pill.RequiredElement or "Wood", pill.Courier or "ตันเถียน")
                tagLbl.TextColor3 = Color3.fromRGB(85, 200, 255)
                tagLbl.Font = Enum.Font.SourceSans
                tagLbl.TextSize = 11
                tagLbl.TextXAlignment = Enum.TextXAlignment.Left
                tagLbl.Parent = card

                local descLbl = Instance.new("TextLabel")
                descLbl.Size = UDim2.new(1, -16, 0, 36)
                descLbl.Position = UDim2.new(0, 10, 0, 46)
                descLbl.BackgroundTransparency = 1
                descLbl.Text = pill.Description or ""
                descLbl.TextColor3 = Color3.fromRGB(180, 190, 205)
                descLbl.Font = Enum.Font.SourceSans
                descLbl.TextSize = 11
                descLbl.TextWrapped = true
                descLbl.TextXAlignment = Enum.TextXAlignment.Left
                descLbl.Parent = card

                local footLbl = Instance.new("TextLabel")
                footLbl.Size = UDim2.new(1, -16, 0, 18)
                footLbl.Position = UDim2.new(0, 10, 1, -22)
                footLbl.BackgroundTransparency = 1
                footLbl.Text = string.format("🌿 วัตถุดิบ: %s | ราคากลาง: %d เหรียญ", pill.KeyIngredients or "ความลับ", pill.Price or 500)
                footLbl.TextColor3 = Color3.fromRGB(140, 220, 160)
                footLbl.Font = Enum.Font.SourceSansBold
                footLbl.TextSize = 11
                footLbl.TextXAlignment = Enum.TextXAlignment.Left
                footLbl.Parent = card
            else
                -- ตำรับยาที่ยังไม่ค้นพบ
                local lockLbl = Instance.new("TextLabel")
                lockLbl.Size = UDim2.new(1, -16, 0, 24)
                lockLbl.Position = UDim2.new(0, 10, 0, 8)
                lockLbl.BackgroundTransparency = 1
                lockLbl.Text = string.format("🔒 ??? (ยังไม่ถูกค้นพบ) [ระดับ %d]", pill.Tier or 1)
                lockLbl.TextColor3 = Color3.fromRGB(160, 165, 180)
                lockLbl.Font = Enum.Font.SourceSansBold
                lockLbl.TextSize = 13
                lockLbl.TextXAlignment = Enum.TextXAlignment.Left
                lockLbl.Parent = card

                local schoolLbl = Instance.new("TextLabel")
                schoolLbl.Size = UDim2.new(1, -16, 0, 20)
                schoolLbl.Position = UDim2.new(0, 10, 0, 34)
                schoolLbl.BackgroundTransparency = 1
                schoolLbl.Text = "สำนัก: " .. (pill.SchoolName or "วิถีแห่งเต๋า")
                schoolLbl.TextColor3 = Color3.fromRGB(120, 125, 140)
                schoolLbl.Font = Enum.Font.SourceSans
                schoolLbl.TextSize = 11
                schoolLbl.TextXAlignment = Enum.TextXAlignment.Left
                schoolLbl.Parent = card

                local hintLbl = Instance.new("TextLabel")
                hintLbl.Size = UDim2.new(1, -16, 0, 36)
                hintLbl.Position = UDim2.new(0, 10, 0, 56)
                hintLbl.BackgroundTransparency = 1
                hintLbl.Text = string.format("💡 คำใบ้: ต้องใช้สมุนไพรธาตุ '%s' และพลังงานอย่างน้อย %d หน่วย", pill.RequiredElement or "Wood", pill.MinPotency or 20)
                hintLbl.TextColor3 = Color3.fromRGB(200, 180, 120)
                hintLbl.Font = Enum.Font.SourceSans
                hintLbl.TextSize = 11
                hintLbl.TextWrapped = true
                hintLbl.TextXAlignment = Enum.TextXAlignment.Left
                hintLbl.Parent = card

                local stateBadge = Instance.new("TextLabel")
                stateBadge.Size = UDim2.new(0, 95, 0, 20)
                stateBadge.Position = UDim2.new(1, -105, 1, -26)
                stateBadge.BackgroundColor3 = Color3.fromRGB(40, 44, 55)
                stateBadge.Text = "❌ ยังไม่ค้นพบ"
                stateBadge.TextColor3 = Color3.fromRGB(180, 180, 180)
                stateBadge.Font = Enum.Font.SourceSansBold
                stateBadge.TextSize = 11
                stateBadge.Parent = card

                local sbc = Instance.new("UICorner")
                sbc.CornerRadius = UDim.new(0, 4)
                sbc.Parent = stateBadge
            end
        end
    end

    recipeScrollBox.CanvasSize = UDim2.new(0, 0, 0, rsbLayout.AbsoluteContentSize.Y + 20)
end

-- สร้างปุ่มตัวกรองสำนักยา 6 สำนัก
local schoolButtons = {}
local function createSchoolFilterButtons()
    local btnAll = Instance.new("TextButton")
    btnAll.Size = UDim2.new(0, 75, 0, 26)
    btnAll.BackgroundColor3 = Color3.fromRGB(220, 140, 30)
    btnAll.Text = "ทั้งหมด"
    btnAll.TextColor3 = Color3.fromRGB(255, 255, 255)
    btnAll.Font = Enum.Font.SourceSansBold
    btnAll.TextSize = 12
    btnAll.Parent = schoolScroll

    local bAllCorner = Instance.new("UICorner")
    bAllCorner.CornerRadius = UDim.new(0, 5)
    bAllCorner.Parent = btnAll
    table.insert(schoolButtons, {Btn = btnAll, School = 0})

    btnAll.MouseButton1Click:Connect(function()
        selectedSchoolFilter = 0
        for _, b in ipairs(schoolButtons) do
            b.Btn.BackgroundColor3 = (b.School == 0) and Color3.fromRGB(220, 140, 30) or Color3.fromRGB(35, 40, 55)
        end
        renderRecipeBookView()
    end)

    for i = 1, 6 do
        local name = PillDatabase.Schools[i] or ("สำนักที่ " .. i)
        local shortName = string.match(name, "([^(]+)") or name

        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, 140, 0, 26)
        btn.BackgroundColor3 = Color3.fromRGB(35, 40, 55)
        btn.Text = shortName:sub(1, 24)
        btn.TextColor3 = Color3.fromRGB(220, 220, 220)
        btn.Font = Enum.Font.SourceSansBold
        btn.TextSize = 11
        btn.Parent = schoolScroll

        local bc = Instance.new("UICorner")
        bc.CornerRadius = UDim.new(0, 5)
        bc.Parent = btn
        table.insert(schoolButtons, {Btn = btn, School = i})

        btn.MouseButton1Click:Connect(function()
            selectedSchoolFilter = i
            for _, b in ipairs(schoolButtons) do
                b.Btn.BackgroundColor3 = (b.School == i) and Color3.fromRGB(220, 140, 30) or Color3.fromRGB(35, 40, 55)
            end
            renderRecipeBookView()
        end)
    end
end
createSchoolFilterButtons()

--------------------------------------------------------------------------------
-- 8. ฟังก์ชันแสดงรายการย่ามเก็บโอสถ (PillPouchView)
--------------------------------------------------------------------------------
local function renderPillPouchView()
    for _, child in ipairs(pouchView:GetChildren()) do
        if child:IsA("Frame") or child:IsA("TextLabel") then child:Destroy() end
    end

    local pillCount = 0
    for itemName, count in pairs(currentInventory) do
        if count > 0 and (string.find(itemName, "โอสถ") or string.find(itemName, "เม็ดยา") or string.find(itemName, "Pill")) then
            pillCount = pillCount + 1

            local baseName = string.gsub(itemName, "%s*%(.*%)", "")
            local pillData = PillDatabase.Get(baseName) or (GameConfig.Pills and GameConfig.Pills[baseName])

            local card = Instance.new("Frame")
            card.Size = UDim2.new(1, 0, 0, 74)
            card.BackgroundColor3 = Color3.fromRGB(22, 26, 36)
            card.BorderSizePixel = 0
            card.Parent = pouchView

            local cCorner = Instance.new("UICorner")
            cCorner.CornerRadius = UDim.new(0, 8)
            cCorner.Parent = card

            local cStroke = Instance.new("UIStroke")
            cStroke.Thickness = 1.2
            cStroke.Color = Color3.fromRGB(240, 180, 40)
            cStroke.Parent = card

            local nameLbl = Instance.new("TextLabel")
            nameLbl.Size = UDim2.new(0.65, 0, 0, 24)
            nameLbl.Position = UDim2.new(0, 12, 0, 8)
            nameLbl.BackgroundTransparency = 1
            nameLbl.Text = string.format("💊 %s (มี: %d เม็ด)", itemName, count)
            nameLbl.TextColor3 = Color3.fromRGB(255, 215, 80)
            nameLbl.Font = Enum.Font.SourceSansBold
            nameLbl.TextSize = 14
            nameLbl.TextXAlignment = Enum.TextXAlignment.Left
            nameLbl.Parent = card

            local descLbl = Instance.new("TextLabel")
            descLbl.Size = UDim2.new(0.65, 0, 0, 34)
            descLbl.Position = UDim2.new(0, 12, 0, 32)
            descLbl.BackgroundTransparency = 1
            descLbl.Text = pillData and pillData.Description or "โอสถวิเศษเปี่ยมด้วยปราณฟ้าดิน กลืนเพื่อรับตบะและเสริมสร้างรากฐาน"
            descLbl.TextColor3 = Color3.fromRGB(180, 205, 225)
            descLbl.Font = Enum.Font.SourceSans
            descLbl.TextSize = 12
            descLbl.TextWrapped = true
            descLbl.TextXAlignment = Enum.TextXAlignment.Left
            descLbl.Parent = card

            local useBtn = Instance.new("TextButton")
            useBtn.Size = UDim2.new(0, 115, 0, 36)
            useBtn.Position = UDim2.new(1, -125, 0.5, -18)
            useBtn.BackgroundColor3 = Color3.fromRGB(40, 140, 80)
            useBtn.Text = "กลืนโอสถ (ใช้)"
            useBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
            useBtn.Font = Enum.Font.SourceSansBold
            useBtn.TextSize = 13
            useBtn.Parent = card

            local ubCorner = Instance.new("UICorner")
            ubCorner.CornerRadius = UDim.new(0, 6)
            ubCorner.Parent = useBtn

            useBtn.MouseButton1Click:Connect(function()
                useBtn.Text = "กำลังกลืน..."
                local success, msg = NetworkEvents.UsePill:InvokeServer(itemName)
                if success then
                    useBtn.Text = "สำเร็จ!"
                    task.wait(0.5)
                    renderPillPouchView()
                else
                    useBtn.Text = "ล้มเหลว"
                    task.wait(1)
                    useBtn.Text = "กลืนโอสถ (ใช้)"
                end
            end)
        end
    end

    tabPouch.Text = string.format("🎒 ย่ามเก็บโอสถ (%d)", pillCount)

    if pillCount == 0 then
        local emptyLbl = Instance.new("TextLabel")
        emptyLbl.Size = UDim2.new(1, 0, 0, 70)
        emptyLbl.BackgroundTransparency = 1
        emptyLbl.Text = "ย่ามโอสถว่างเปล่า\n(เลือกสมุนไพรและเริ่มปรุงได้ในแท็บ 'จุดเตาปรุงยาโอสถ')"
        emptyLbl.TextColor3 = Color3.fromRGB(140, 150, 170)
        emptyLbl.Font = Enum.Font.SourceSans
        emptyLbl.TextSize = 14
        emptyLbl.Parent = pouchView
    end

    pouchView.CanvasSize = UDim2.new(0, 0, 0, pvLayout.AbsoluteContentSize.Y + 20)
end

--------------------------------------------------------------------------------
-- 9. ระบบมินิเกมการปรุงยา 3 ขั้นตอน (Heat -> Stir -> Chi Infusion)
--------------------------------------------------------------------------------
local function runAlchemyMinigame()
    if isMinigameActive then return end
    isMinigameActive = true

    -- สปอนเตาหลอมโอสถส่วนตัวในโลก 3D ทันที
    NetworkEvents.SpawnPersonalCauldron:InvokeServer()

    prepView.Visible = false
    minigameView.Visible = true

    local scoreStage1 = 0
    local scoreStage2 = 0
    local scoreStage3 = 0

    ------------------------------------------------------------------
    -- ขั้นที่ 1: ควบคุมความร้อน (Heat Control) - 3 วินาที
    ------------------------------------------------------------------
    mgStepTitle.Text = "ขั้นที่ 1: ควบคุมความร้อน (Heat Control)"
    mgStepInstruction.Text = "กดปุ่มเร่งไฟเพื่อรักษาอุณหภูมิให้อยู่ในแถบสีทอง!"
    mgActionBtn.Text = "🔥 เร่งไฟ (พัดลมปราณ)"
    mgActionBtn.BackgroundColor3 = Color3.fromRGB(220, 140, 30)

    targetZone.Position = UDim2.new(0.40, 0, 0, 0)
    targetZone.Size = UDim2.new(0.30, 0, 1, 0)

    local heat = 0.2
    local inZoneDuration = 0
    local stage1Duration = 3.0

    local btnConn = mgActionBtn.MouseButton1Click:Connect(function()
        heat = math.min(1.0, heat + 0.18)
    end)

    local startTime = os.clock()
    while os.clock() - startTime < stage1Duration do
        local dt = RunService.RenderStepped:Wait()
        heat = math.max(0.0, heat - (0.16 * dt))
        needle.Position = UDim2.new(heat, -3, 0, -4)

        if heat >= 0.40 and heat <= 0.70 then
            inZoneDuration = inZoneDuration + dt
        end

        local rem = math.max(0, stage1Duration - (os.clock() - startTime))
        mgTimerLabel.Text = string.format("เวลาเหลือ: %.1f วินาที", rem)
        scoreDisplay.Text = string.format("ความคงที่ของเปลวไฟ: %.0f%%", (inZoneDuration / stage1Duration) * 100)
    end
    btnConn:Disconnect()

    scoreStage1 = math.clamp((inZoneDuration / stage1Duration) * 100, 0, 100)
    task.wait(0.4)

    ------------------------------------------------------------------
    -- ขั้นที่ 2: กวนประสานเนื้อยา (Stirring Balance) - 3 วินาที
    ------------------------------------------------------------------
    mgStepTitle.Text = "ขั้นที่ 2: กวนประสานเนื้อยา (Stirring Balance)"
    mgStepInstruction.Text = "กดปุ่มเพื่อรักษาสมดุลไม้พายให้อยู่กึ่งกลาง!"
    mgActionBtn.Text = "🥄 กวนประสานเนื้อยา"
    mgActionBtn.BackgroundColor3 = Color3.fromRGB(70, 140, 210)

    targetZone.Position = UDim2.new(0.35, 0, 0, 0)
    targetZone.Size = UDim2.new(0.30, 0, 1, 0)

    local stirPos = 0.5
    local stirInZone = 0
    local stage2Duration = 3.0

    local stirConn = mgActionBtn.MouseButton1Click:Connect(function()
        stirPos = stirPos + (math.random(-1, 1) * 0.15)
        if stirPos < 0.2 then stirPos = 0.45 end
        if stirPos > 0.8 then stirPos = 0.55 end
    end)

    startTime = os.clock()
    while os.clock() - startTime < stage2Duration do
        local dt = RunService.RenderStepped:Wait()
        stirPos = math.clamp(stirPos + (math.sin(os.clock() * 6) * 0.25 * dt), 0.05, 0.95)
        needle.Position = UDim2.new(stirPos, -3, 0, -4)

        if stirPos >= 0.35 and stirPos <= 0.65 then
            stirInZone = stirInZone + dt
        end

        local rem = math.max(0, stage2Duration - (os.clock() - startTime))
        mgTimerLabel.Text = string.format("เวลาเหลือ: %.1f วินาที", rem)
        scoreDisplay.Text = string.format("ความเข้ากันของเนื้อยา: %.0f%%", (stirInZone / stage2Duration) * 100)
    end
    stirConn:Disconnect()

    scoreStage2 = math.clamp((stirInZone / stage2Duration) * 100, 0, 100)
    task.wait(0.4)

    ------------------------------------------------------------------
    -- ขั้นที่ 3: อัดฉีดลมปราณ (Chi Infusion QTE) - 2.5 วินาที
    ------------------------------------------------------------------
    mgStepTitle.Text = "ขั้นที่ 3: อัดฉีดลมปราณ (Chi Infusion QTE)"
    mgStepInstruction.Text = "กดให้ตรงจังหวะเมื่อเส้นพลังวิ่งมาถึงใจกลางสีทอง!"
    mgActionBtn.Text = "⚡ ผนึกปราณแท้ (กดให้ตรง!)"
    mgActionBtn.BackgroundColor3 = Color3.fromRGB(160, 80, 220)

    targetZone.Position = UDim2.new(0.44, 0, 0, 0)
    targetZone.Size = UDim2.new(0.12, 0, 1, 0)

    local sparkPos = 0.0
    local qteHit = false
    local stage3Duration = 2.5

    local qteConn
    qteConn = mgActionBtn.MouseButton1Click:Connect(function()
        if not qteHit then
            qteHit = true
            local diff = math.abs(sparkPos - 0.5)
            if diff <= 0.06 then
                scoreStage3 = 100
                scoreDisplay.Text = "🎯 จังหวะสมบูรณ์แบบ! (PERFECT +100%)"
            elseif diff <= 0.15 then
                scoreStage3 = 70
                scoreDisplay.Text = "✨ เข้าเป้าได้ดี! (GOOD +70%)"
            else
                scoreStage3 = 30
                scoreDisplay.Text = "⚠️ จังหวะคลาดเคลื่อน (+30%)"
            end
        end
    end)

    startTime = os.clock()
    while os.clock() - startTime < stage3Duration and not qteHit do
        local dt = RunService.RenderStepped:Wait()
        sparkPos = (os.clock() - startTime) / stage3Duration
        needle.Position = UDim2.new(sparkPos, -3, 0, -4)
        mgTimerLabel.Text = string.format("เวลาเหลือ: %.1f วินาที", math.max(0, stage3Duration - (os.clock() - startTime)))
    end
    qteConn:Disconnect()

    if not qteHit then scoreStage3 = 20 end

    ------------------------------------------------------------------
    -- สรุปคะแนนรวม และส่งให้ Server หลอมยา
    ------------------------------------------------------------------
    local finalScore = math.floor((scoreStage1 * 0.35) + (scoreStage2 * 0.35) + (scoreStage3 * 0.30))
    mgStepTitle.Text = "🌟 กำลังควบแน่นเม็ดยาโอสถ..."
    mgStepInstruction.Text = string.format("คะแนนสมาธิรวม: %d%%", finalScore)
    task.wait(1)

    local success, message, pillData = NetworkEvents.CraftDynamicPill:InvokeServer(selectedIngredients, finalScore)

    minigameView.Visible = false
    prepView.Visible = true
    isMinigameActive = false

    -- ล้างวัตถุดิบที่เลือก
    selectedIngredients = {}
    updateHerbListUI()

    -- แจ้งเตือนความสำเร็จ
    if success and pillData then
        targetPillPreview.Text = "🎉 หลอมสำเร็จ: " .. pillData.Name
        targetPillPreview.TextColor3 = pillData.Color or Color3.fromRGB(255, 215, 0)
        -- อัปเดตรายการตำรับยา
        if pillData.BaseName then
            discoveredPills[pillData.BaseName] = true
        end
        discoveredPills[pillData.Name] = true
        renderRecipeBookView()
    else
        targetPillPreview.Text = "❌ " .. tostring(message)
    end
end

startMinigameBtn.MouseButton1Click:Connect(function()
    local count = 0
    for _, c in pairs(selectedIngredients) do count = count + c end
    if count > 0 then
        runAlchemyMinigame()
    end
end)

--------------------------------------------------------------------------------
-- 10. แท็บสวิตช์ (Tab Switcher) & เปิด/ปิดหน้าต่าง
--------------------------------------------------------------------------------
local function switchTab(tabName)
    currentTab = tabName
    tabCraft.BackgroundColor3 = (tabName == "Craft") and Color3.fromRGB(220, 140, 30) or Color3.fromRGB(30, 35, 48)
    tabCraft.TextColor3 = (tabName == "Craft") and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(180, 190, 210)

    tabRecipes.BackgroundColor3 = (tabName == "Recipes") and Color3.fromRGB(220, 140, 30) or Color3.fromRGB(30, 35, 48)
    tabRecipes.TextColor3 = (tabName == "Recipes") and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(180, 190, 210)

    tabPouch.BackgroundColor3 = (tabName == "Pouch") and Color3.fromRGB(220, 140, 30) or Color3.fromRGB(30, 35, 48)
    tabPouch.TextColor3 = (tabName == "Pouch") and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(180, 190, 210)

    craftView.Visible = (tabName == "Craft")
    recipeBookView.Visible = (tabName == "Recipes")
    pouchView.Visible = (tabName == "Pouch")

    if tabName == "Craft" then
        updateHerbListUI()
    elseif tabName == "Recipes" then
        renderRecipeBookView()
    elseif tabName == "Pouch" then
        renderPillPouchView()
    end
end

tabCraft.MouseButton1Click:Connect(function() switchTab("Craft") end)
tabRecipes.MouseButton1Click:Connect(function() switchTab("Recipes") end)
tabPouch.MouseButton1Click:Connect(function() switchTab("Pouch") end)

local function toggleAlchemyUI()
    mainFrame.Visible = not mainFrame.Visible
    if mainFrame.Visible then
        switchTab(currentTab)
    else
        -- เมื่อปิดหน้าต่าง สลายเตาหลอมโอสถในโลก 3D ออก
        NetworkEvents.DismissPersonalCauldron:InvokeServer()
        if isMinigameActive then
            isMinigameActive = false
            minigameView.Visible = false
            prepView.Visible = true
        end
    end
end

toggleButton.MouseButton1Click:Connect(toggleAlchemyUI)
closeBtn.MouseButton1Click:Connect(toggleAlchemyUI)

-- ปุ่มลัดเปิดเตาหลอม: กด K
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.K then
        toggleAlchemyUI()
    end
end)

-- รับอีเวนต์เปิดเตาหลอมจาก Server (เช่น มีปฏิสัมพันธ์กับเตาหลอมในเมือง)
NetworkEvents.OpenCauldronUI.OnClientEvent:Connect(function()
    if not mainFrame.Visible then
        toggleAlchemyUI()
    end
end)

-- ซิงค์ข้อมูลกระเป๋า (UpdateInventory)
NetworkEvents.UpdateInventory.OnClientEvent:Connect(function(inventory)
    currentInventory = inventory or {}
    if mainFrame.Visible then
        if currentTab == "Craft" then
            updateHerbListUI()
        elseif currentTab == "Pouch" then
            renderPillPouchView()
        end
    end
end)

-- ซิงค์ข้อมูลตำรับยาที่ค้นพบ (SyncDiscoveredPills)
NetworkEvents.SyncDiscoveredPills.OnClientEvent:Connect(function(pillsData)
    discoveredPills = pillsData or {}
    if mainFrame.Visible and currentTab == "Recipes" then
        renderRecipeBookView()
    end
end)

-- ร้องขอข้อมูลตำรับยาและกระเป๋าเริ่มต้นเมื่อเข้าเกม
task.spawn(function()
    task.wait(1)
    local pData = NetworkEvents.GetDiscoveredPills:InvokeServer()
    if pData then
        discoveredPills = pData
    end
    updateHerbListUI()
    renderRecipeBookView()
end)

print("✅ [Client] Nine Stars Celestial Alchemy Pavilion UI พร้อมทำงาน! (กด K หรือคลิก 🔥)")
