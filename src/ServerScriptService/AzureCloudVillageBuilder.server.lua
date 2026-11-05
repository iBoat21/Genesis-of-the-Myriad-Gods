--[[
    AzureCloudVillageBuilder.server.lua
    สถาปัตยกรรมสร้างหมู่บ้านเริ่มต้น "Azure Cloud Village (หมู่บ้านเมฆาคราม)" แบบครบวงจร
    - แผนที่ระดับ 600x600 studs บน Y = 10 พร้อมภูเขาโอบล้อม ลำธารสะพานจันทร์เสี้ยว และโครงข่ายถนน
    - 5 ย่านสำคัญ: ลานต้นท้อใจกลาง, หอโอสถ & แปลงสมุนไพร, โรงตีเหล็ก & ตลาด, โรงเตี๊ยม & ลานประลอง, ประตูทิศใต้
    - สถาปัตยกรรมจีนโบราณแท้ (เสาคาน, ชายคาปีกนกกระเบื้อง Wedges, โคมไฟแดงเรืองแสง)
    - ประตูมิติเทเลพอร์ตคู่ทางทิศใต้ (PvE พฤกษาสวรรค์ / PvP หุบเขาอสูร) พร้อมแท่นบูชาวาร์ปกลับ
    - จัดเก็บโครงสร้างทั้งหมดไว้ใน Folder เดียว: workspace.AzureCloudVillage
]]

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local GameConfig = require(ReplicatedStorage:WaitForChild("SharedModules"):WaitForChild("GameConfig"))
local NetworkEvents = require(ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("NetworkEvents"))
local CultivationManager = require(ServerScriptService:WaitForChild("CultivationManager"))

-- ล้างโฟลเดอร์หรือชิ้นส่วนเดิมหากมีอยู่ เพื่อสร้างใหม่ให้เนียนตา
local existingVillage = Workspace:FindFirstChild("AzureCloudVillage")
if existingVillage then
    existingVillage:Destroy()
end

-- สร้าง Root Folder หลัก
local villageRoot = Instance.new("Folder")
villageRoot.Name = "AzureCloudVillage"
villageRoot.Parent = Workspace

-- โฟลเดอร์หมวดหมู่ย่อย
local terrainFolder = Instance.new("Folder")
terrainFolder.Name = "Terrain"
terrainFolder.Parent = villageRoot

local roadsFolder = Instance.new("Folder")
roadsFolder.Name = "Roads"
roadsFolder.Parent = villageRoot

local buildingsFolder = Instance.new("Folder")
buildingsFolder.Name = "Buildings"
buildingsFolder.Parent = villageRoot

local foliageFolder = Instance.new("Folder")
foliageFolder.Name = "Foliage"
foliageFolder.Parent = villageRoot

local npcsFolder = Instance.new("Folder")
npcsFolder.Name = "NPCs"
npcsFolder.Parent = villageRoot

local propsFolder = Instance.new("Folder")
propsFolder.Name = "Props"
propsFolder.Parent = villageRoot

local portalsFolder = Instance.new("Folder")
portalsFolder.Name = "Portals"
portalsFolder.Parent = villageRoot

--------------------------------------------------------------------------------
-- 0. ยูทิลิตี้ฟังก์ชันสร้างชิ้นส่วนเรขาคณิต (Architecture Primitives)
--------------------------------------------------------------------------------
local function createPart(name, size, cframe, color, material, parent, canCollide)
    local p = Instance.new("Part")
    p.Name = name or "Part"
    p.Size = size
    p.CFrame = cframe
    p.Color = color or Color3.fromRGB(200, 200, 200)
    p.Material = material or Enum.Material.SmoothPlastic
    p.Anchored = true
    p.CastShadow = true
    p.CanCollide = (canCollide ~= false)
    p.TopSurface = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    p.Parent = parent or villageRoot
    return p
end

local function createWedge(name, size, cframe, color, material, parent)
    local w = Instance.new("WedgePart")
    w.Name = name or "Wedge"
    w.Size = size
    w.CFrame = cframe
    w.Color = color or Color3.fromRGB(180, 180, 180)
    w.Material = material or Enum.Material.SmoothPlastic
    w.Anchored = true
    w.CastShadow = true
    w.CanCollide = true
    w.TopSurface = Enum.SurfaceType.Smooth
    w.BottomSurface = Enum.SurfaceType.Smooth
    w.Parent = parent or villageRoot
    return w
end

-- ฟังก์ชันสร้างหลังคาสถาปัตยกรรมจีนทรงปีกนก (Pagoda Flared Roof)
local function createPagodaRoof(centerCFrame, width, length, height, tileColor, parent)
    local roofModel = Instance.new("Model")
    roofModel.Name = "PagodaRoof"
    roofModel.Parent = parent

    -- ฐานหลังคาชั้นบน
    local ridgeSize = Vector3.new(width - 4, 1.2, length - 4)
    createPart("RidgeCap", ridgeSize, centerCFrame * CFrame.new(0, height, 0), Color3.fromRGB(45, 45, 50), Enum.Material.Slate, roofModel)

    -- ชายคาลาดเอียง 4 ทิศ (Sloped Roof Wedges)
    local overhang = 3
    -- ทิศเหนือ / ใต้
    local slopeN = createWedge("SlopeN", Vector3.new(width + overhang * 2, height, length / 2 + overhang),
        centerCFrame * CFrame.new(0, height / 2, -(length / 4 + overhang / 2)) * CFrame.Angles(0, math.rad(180), 0),
        tileColor, Enum.Material.Slate, roofModel)
    local slopeS = createWedge("SlopeS", Vector3.new(width + overhang * 2, height, length / 2 + overhang),
        centerCFrame * CFrame.new(0, height / 2, length / 4 + overhang / 2),
        tileColor, Enum.Material.Slate, roofModel)

    -- คานบัวปลายชายคาแอ่นขึ้น
    local eaveTrim = createPart("EaveTrim", Vector3.new(width + overhang * 2 + 1, 0.8, length + overhang * 2 + 1),
        centerCFrame * CFrame.new(0, 0.4, 0), Color3.fromRGB(180, 60, 45), Enum.Material.Wood, roofModel)

    return roofModel
end

-- ฟังก์ชันสร้างอาคารจีนแบบประกอบเสา-คาน-ผนัง (Composite Chinese Pavilion/Building)
local function createChineseBuilding(name, cframe, width, length, wallHeight, wallColor, beamColor, roofColor, parent)
    local bldg = Instance.new("Model")
    bldg.Name = name
    bldg.Parent = parent or buildingsFolder

    -- 1. ฐานรากแท่นหิน (Stone Foundation)
    local baseHeight = 2
    local foundation = createPart("Foundation", Vector3.new(width + 4, baseHeight, length + 4),
        cframe * CFrame.new(0, baseHeight / 2, 0), Color3.fromRGB(150, 155, 160), Enum.Material.Cobblestone, bldg)

    local floorY = baseHeight

    -- 2. เสาหลักไม้ 4 มุม (Corner Timber Pillars)
    local pillarSize = Vector3.new(1.8, wallHeight, 1.8)
    local halfW = width / 2
    local halfL = length / 2

    local pOffsets = {
        Vector3.new(-halfW, floorY + wallHeight / 2, -halfL),
        Vector3.new(halfW, floorY + wallHeight / 2, -halfL),
        Vector3.new(-halfW, floorY + wallHeight / 2, halfL),
        Vector3.new(halfW, floorY + wallHeight / 2, halfL)
    }
    for i, offset in ipairs(pOffsets) do
        createPart("Pillar_" .. i, pillarSize, cframe * CFrame.new(offset), beamColor, Enum.Material.Wood, bldg)
    end

    -- 3. ผนังปูนขาว 3 ด้าน (เว้นด้านหน้าสำหรับประตูเข้า)
    local wallThick = 0.8
    -- ผนังหลัง (North)
    createPart("WallBack", Vector3.new(width - 2, wallHeight - 0.5, wallThick),
        cframe * CFrame.new(0, floorY + (wallHeight - 0.5) / 2, -halfL), wallColor, Enum.Material.Plaster, bldg)
    -- ผนังซ้าย (West)
    createPart("WallWest", Vector3.new(wallThick, wallHeight - 0.5, length - 2),
        cframe * CFrame.new(-halfW, floorY + (wallHeight - 0.5) / 2, 0), wallColor, Enum.Material.Plaster, bldg)
    -- ผนังขวา (East)
    createPart("WallEast", Vector3.new(wallThick, wallHeight - 0.5, length - 2),
        cframe * CFrame.new(halfW, floorY + (wallHeight - 0.5) / 2, 0), wallColor, Enum.Material.Plaster, bldg)

    -- ซุ้มประตูด้านหน้า
    createPart("DoorBeamTop", Vector3.new(width, 1.5, 1.2),
        cframe * CFrame.new(0, floorY + wallHeight - 0.75, halfL), beamColor, Enum.Material.Wood, bldg)

    -- 4. หลังคาจีนทรงปีกนก (Pagoda Flared Roof)
    createPagodaRoof(cframe * CFrame.new(0, floorY + wallHeight, 0), width + 2, length + 2, 6, roofColor, bldg)

    return bldg
end

-- ฟังก์ชันสร้างโคมไฟกระดาษสีแดงเรืองแสง (Hanging Red Lantern)
local function createRedLantern(cframe, parent)
    local lantern = Instance.new("Model")
    lantern.Name = "Lantern"
    lantern.Parent = parent

    local body = createPart("LanternBody", Vector3.new(1.8, 2.2, 1.8), cframe, Color3.fromRGB(220, 45, 35), Enum.Material.Neon, lantern, false)
    createPart("LanternCapTop", Vector3.new(2, 0.4, 2), cframe * CFrame.new(0, 1.2, 0), Color3.fromRGB(35, 35, 40), Enum.Material.Wood, lantern, false)
    createPart("LanternCapBottom", Vector3.new(1.4, 0.4, 1.4), cframe * CFrame.new(0, -1.2, 0), Color3.fromRGB(255, 200, 50), Enum.Material.Fabric, lantern, false)

    local light = Instance.new("PointLight")
    light.Color = Color3.fromRGB(255, 150, 60)
    light.Range = 18
    light.Brightness = 1.8
    light.Parent = body

    return lantern
end

--------------------------------------------------------------------------------
-- 1. TERRAIN & SPATIAL BLUEPRINT (600x600 STUDS AT Y = 10)
--------------------------------------------------------------------------------
local function buildTerrainAndLandscape()
    print("🏞️ [AzureVillage] กำลังสร้างผืนดิน ลำธาร และทิวเขาโอบล้อม 600x600 studs...")

    -- 1.1 ผืนดินหลัก (Base Ground Plane 600x600 studs at Y = 10)
    local ground = createPart("BaseGrassTerrain", Vector3.new(600, 6, 600), CFrame.new(0, 7, 0),
        Color3.fromRGB(85, 145, 80), Enum.Material.Grass, terrainFolder)
    ground.Friction = 0.8

    -- 1.2 ทิวเขาโอบล้อมตามขอบ 4 ทิศ (Enclosing Mountains & Cliffs as Natural Boundary)
    local cliffThickness = 30
    local cliffHeight = 45

    -- หน้าผาเหนือ (North Mountains)
    createPart("MountainNorth", Vector3.new(620, cliffHeight, cliffThickness),
        CFrame.new(0, 10 + cliffHeight / 2, -300), Color3.fromRGB(75, 80, 85), Enum.Material.Rock, terrainFolder)
    -- หน้าผาใต้ (South Mountains - เว้นทางออกตรงกลาง)
    createPart("MountainSouthL", Vector3.new(260, cliffHeight, cliffThickness),
        CFrame.new(-170, 10 + cliffHeight / 2, 300), Color3.fromRGB(75, 80, 85), Enum.Material.Rock, terrainFolder)
    createPart("MountainSouthR", Vector3.new(260, cliffHeight, cliffThickness),
        CFrame.new(170, 10 + cliffHeight / 2, 300), Color3.fromRGB(75, 80, 85), Enum.Material.Rock, terrainFolder)
    -- หน้าผาตะวันตก (West Mountains)
    createPart("MountainWest", Vector3.new(cliffThickness, cliffHeight, 620),
        CFrame.new(-300, 10 + cliffHeight / 2, 0), Color3.fromRGB(70, 75, 80), Enum.Material.Slate, terrainFolder)
    -- หน้าผาตะวันออก (East Mountains)
    createPart("MountainEast", Vector3.new(cliffThickness, cliffHeight, 620),
        CFrame.new(300, 10 + cliffHeight / 2, 0), Color3.fromRGB(70, 75, 80), Enum.Material.Slate, terrainFolder)

    -- ยอดหินเหลี่ยมตามมุมเขาธรรมชาติ
    local cornerRocks = {
        Vector3.new(-270, 35, -270), Vector3.new(270, 35, -270),
        Vector3.new(-270, 35, 270), Vector3.new(270, 35, 270)
    }
    for i, rPos in ipairs(cornerRocks) do
        createPart("PeakRock_" .. i, Vector3.new(50, 70, 50), CFrame.new(rPos) * CFrame.Angles(0, math.rad(i * 35), 0),
            Color3.fromRGB(65, 70, 75), Enum.Material.Slate, terrainFolder)
    end

    -- 1.3 ลำธารน้ำใส (Central Stream & Moon Bridge)
    -- ลำธารน้ำแก้วพาดผ่านหมู่บ้านจาก ตะวันตกเฉียงเหนือ สู่ ตะวันออกเฉียงใต้
    local canalBed = createPart("CanalBed", Vector3.new(24, 1.5, 450), CFrame.new(35, 9.2, 0) * CFrame.Angles(0, math.rad(-25), 0),
        Color3.fromRGB(90, 85, 75), Enum.Material.Cobblestone, terrainFolder)
    local canalWater = createPart("CanalWater", Vector3.new(22, 1.2, 450), CFrame.new(35, 9.7, 0) * CFrame.Angles(0, math.rad(-25), 0),
        Color3.fromRGB(75, 195, 225), Enum.Material.Glass, terrainFolder, false)
    canalWater.Transparency = 0.35

    -- สะพานจันทร์เสี้ยว (Oriental Moon Bridge) ข้ามลำธารใกล้ใจกลางลาน
    local bridgeCenter = CFrame.new(30, 10.5, 15) * CFrame.Angles(0, math.rad(65), 0)
    local bridgeDeck = createPart("MoonBridgeDeck", Vector3.new(14, 2, 32), bridgeCenter * CFrame.new(0, 2, 0),
        Color3.fromRGB(150, 140, 130), Enum.Material.Cobblestone, terrainFolder)
    -- ราวสะพานสีแดงชาด
    createPart("RailLeft", Vector3.new(1, 3.5, 32), bridgeCenter * CFrame.new(-7, 4, 0),
        Color3.fromRGB(180, 45, 35), Enum.Material.Wood, terrainFolder)
    createPart("RailRight", Vector3.new(1, 3.5, 32), bridgeCenter * CFrame.new(7, 4, 0),
        Color3.fromRGB(180, 45, 35), Enum.Material.Wood, terrainFolder)
end

--------------------------------------------------------------------------------
-- 2. ROAD NETWORK (โครงข่ายถนนหินและทางเดินดิน)
--------------------------------------------------------------------------------
local function buildRoadNetwork()
    print("🛣️ [AzureVillage] สร้างโครงข่ายถนนหินศิลาเชื่อมต่อ 5 ย่าน...")

    -- ลานศิลากลมใจกลาง (Central Plaza Roundabout: เส้นผ่านศูนย์กลาง 80 studs)
    createPart("CentralPlazaCircle", Vector3.new(80, 0.4, 80), CFrame.new(0, 10.2, 0),
        Color3.fromRGB(165, 160, 150), Enum.Material.Cobblestone, roadsFolder)

    -- ถนนสายเหนือ -> หอโอสถ (North Road)
    createPart("RoadNorth", Vector3.new(18, 0.35, 130), CFrame.new(0, 10.2, -85),
        Color3.fromRGB(160, 155, 145), Enum.Material.Cobblestone, roadsFolder)

    -- ถนนสายตะวันออก -> โรงตีเหล็ก & ตลาด (East Road)
    createPart("RoadEast", Vector3.new(130, 0.35, 18), CFrame.new(85, 10.2, 0),
        Color3.fromRGB(160, 155, 145), Enum.Material.Cobblestone, roadsFolder)

    -- ถนนสายตะวันตก -> โรงเตี๊ยม & ลานประลอง (West Road)
    createPart("RoadWest", Vector3.new(130, 0.35, 18), CFrame.new(-85, 10.2, 0),
        Color3.fromRGB(160, 155, 145), Enum.Material.Cobblestone, roadsFolder)

    -- ถนนสายใต้ -> ซุ้มประตูทิศใต้ (South Road)
    createPart("RoadSouth", Vector3.new(22, 0.35, 180), CFrame.new(0, 10.2, 90),
        Color3.fromRGB(160, 155, 145), Enum.Material.Cobblestone, roadsFolder)

    -- ทางแยกซ้าย-ขวาหลังซุ้มประตูทิศใต้ (Pathways branching to Left/Right Portals)
    createPart("RoadForkLeft", Vector3.new(18, 0.35, 110), CFrame.new(-125, 10.2, 220) * CFrame.Angles(0, math.rad(45), 0),
        Color3.fromRGB(150, 145, 135), Enum.Material.Cobblestone, roadsFolder)
    createPart("RoadForkRight", Vector3.new(18, 0.35, 110), CFrame.new(125, 10.2, 220) * CFrame.Angles(0, math.rad(-45), 0),
        Color3.fromRGB(150, 145, 135), Enum.Material.Cobblestone, roadsFolder)
end

--------------------------------------------------------------------------------
-- 3. DISTRICTS & TRADITIONAL ARCHITECTURE
--------------------------------------------------------------------------------

-- 3.1 Central Square (ลานใจกลางหมู่บ้าน & ต้นท้อโบราณ)
local function buildCentralSquare()
    local sqModel = Instance.new("Model")
    sqModel.Name = "CentralSquare"
    sqModel.Parent = buildingsFolder

    -- จุดเกิดของผู้เล่น (SpawnLocation แนบสนิทกับพื้นหิน)
    local spawn = Instance.new("SpawnLocation")
    spawn.Name = "VillageSpawnLocation"
    spawn.Size = Vector3.new(16, 0.4, 16)
    spawn.Position = Vector3.new(0, 10.25, 18)
    spawn.Color = Color3.fromRGB(200, 185, 145)
    spawn.Material = Enum.Material.Sandstone
    spawn.Duration = 0
    spawn.Anchored = true
    spawn.Parent = sqModel

    -- ต้นท้อวิญญาณโบราณ (Ancient Spirit Peach Tree)
    local treePos = Vector3.new(0, 10, -6)
    local trunk = createPart("PeachTreeTrunk", Vector3.new(4, 18, 4), CFrame.new(treePos + Vector3.new(0, 9, 0)),
        Color3.fromRGB(65, 45, 30), Enum.Material.Wood, sqModel)

    -- กิ่งก้านและพุ่มดอกท้อสีชมพูบานสะพรั่ง (Peach Blossom Canopies)
    local blossomClusters = {
        Vector3.new(0, 19, 0), Vector3.new(-6, 17, 3), Vector3.new(6, 17, -3),
        Vector3.new(4, 18, 5), Vector3.new(-5, 18, -4), Vector3.new(0, 22, 0)
    }
    for i, offset in ipairs(blossomClusters) do
        local blossom = createPart("Blossom_" .. i, Vector3.new(12, 7, 12), CFrame.new(treePos + offset),
            Color3.fromRGB(255, 175, 195), Enum.Material.SmoothPlastic, sqModel, false)
        blossom.Shape = Enum.PartType.Ball
    end

    -- กลีบดอกท้อโปรยปราย (Falling Peach Petals Emitter)
    local petalEmitter = Instance.new("ParticleEmitter")
    petalEmitter.Color = ColorSequence.new(Color3.fromRGB(255, 180, 200), Color3.fromRGB(255, 220, 230))
    petalEmitter.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.6),
        NumberSequenceKeypoint.new(0.5, 0.8),
        NumberSequenceKeypoint.new(1, 0.3)
    })
    petalEmitter.Transparency = NumberSequence.new(0.1, 0.6)
    petalEmitter.Lifetime = NumberRange.new(3, 5.5)
    petalEmitter.Rate = 18
    petalEmitter.Speed = NumberRange.new(2, 5)
    petalEmitter.SpreadAngle = Vector2.new(180, 180)
    petalEmitter.Acceleration = Vector3.new(1.5, -2, 0.5)
    petalEmitter.Parent = trunk

    -- กระดานภารกิจประจำหมู่บ้าน (Village Notice Board)
    local boardPos = Vector3.new(16, 10, -18)
    local boardStand = createPart("NoticeBoardStand", Vector3.new(1, 7, 10), CFrame.new(boardPos + Vector3.new(0, 3.5, 0)),
        Color3.fromRGB(90, 60, 40), Enum.Material.Wood, sqModel)
    local paper = createPart("NoticePaper", Vector3.new(0.2, 5, 8), CFrame.new(boardPos + Vector3.new(-0.45, 3.5, 0)),
        Color3.fromRGB(245, 235, 210), Enum.Material.Paper, sqModel)

    local bGui = Instance.new("BillboardGui")
    bGui.Size = UDim2.new(0, 180, 0, 40)
    bGui.StudsOffset = Vector3.new(0, 4.5, 0)
    bGui.AlwaysOnTop = true
    bGui.MaxDistance = 35
    bGui.Parent = boardStand

    local bLbl = Instance.new("TextLabel")
    bLbl.Size = UDim2.new(1, 0, 1, 0)
    bLbl.BackgroundTransparency = 1
    bLbl.Text = "📜 กระดานภารกิจหมู่บ้านเมฆาคราม"
    bLbl.TextColor3 = Color3.fromRGB(255, 220, 100)
    bLbl.Font = Enum.Font.SourceSansBold
    bLbl.TextSize = 13
    bLbl.TextStrokeTransparency = 0.3
    bLbl.Parent = bGui
end

-- 3.2 Herbalist Garden & Alchemy Pavilion (หอโอสถและสวนพฤกษาวิญญาณ - ทางเหนือ)
local function buildHerbalistDistrict()
    local hDistrict = Instance.new("Model")
    hDistrict.Name = "HerbalistDistrict"
    hDistrict.Parent = buildingsFolder

    local center = Vector3.new(0, 10, -165)

    -- อาคารหอโอสถหลังหลัก (Main Herbalist Manor)
    createChineseBuilding("HerbalistManor", CFrame.new(center), 44, 28, 14,
        Color3.fromRGB(245, 245, 240), Color3.fromRGB(55, 40, 30), Color3.fromRGB(60, 85, 95), hDistrict)

    -- สวนสมุนไพร 4 แปลงดินปลูก (4 Fenced Soil Plots)
    local gardenCenter = center + Vector3.new(0, 0, 35)
    for row = 0, 1 do
        for col = 0, 1 do
            local plotX = (col == 0 and -12 or 12)
            local plotZ = (row == 0 and -10 or 10)
            local plotPos = gardenCenter + Vector3.new(plotX, 0.4, plotZ)

            local soil = createPart("HerbalPlot_" .. (row * 2 + col + 1), Vector3.new(18, 0.8, 14), CFrame.new(plotPos),
                Color3.fromRGB(75, 55, 40), Enum.Material.Ground, hDistrict)

            -- รั้วไม้ล้อมแปลง
            createPart("PlotFenceN", Vector3.new(18, 1.8, 0.6), CFrame.new(plotPos + Vector3.new(0, 0.9, -7)),
                Color3.fromRGB(110, 80, 55), Enum.Material.Wood, hDistrict)
            createPart("PlotFenceS", Vector3.new(18, 1.8, 0.6), CFrame.new(plotPos + Vector3.new(0, 0.9, 7)),
                Color3.fromRGB(110, 80, 55), Enum.Material.Wood, hDistrict)
        end
    end

    -- เตาหลอมโอสถทองสัมฤทธิ์ประจำหมู่บ้าน (Large Village Bronze Cauldron)
    local cauldronPos = center + Vector3.new(-18, 1.5, 18)
    local cBase = createPart("VillageCauldronBase", Vector3.new(8, 2, 8), CFrame.new(cauldronPos),
        Color3.fromRGB(80, 65, 50), Enum.Material.CorrodedMetal, hDistrict)
    local cBowl = createPart("CauldronBowl", Vector3.new(11, 7, 11), CFrame.new(cauldronPos + Vector3.new(0, 3.5, 0)),
        Color3.fromRGB(95, 80, 60), Enum.Material.DiamondPlate, hDistrict)
    local cFire = createPart("CauldronFire", Vector3.new(7, 1, 7), CFrame.new(cauldronPos + Vector3.new(0, 6.5, 0)),
        Color3.fromRGB(85, 255, 200), Enum.Material.Neon, hDistrict, false)

    local fireParticles = Instance.new("ParticleEmitter")
    fireParticles.Color = ColorSequence.new(Color3.fromRGB(85, 255, 200), Color3.fromRGB(255, 220, 80))
    fireParticles.Size = NumberSequence.new(2, 0.4)
    fireParticles.Lifetime = NumberRange.new(0.8, 1.4)
    fireParticles.Rate = 35
    fireParticles.Speed = NumberRange.new(2, 5)
    fireParticles.Parent = cFire

    local cauldronPrompt = Instance.new("ProximityPrompt")
    cauldronPrompt.ObjectText = "เตาหลอมโอสถทองสัมฤทธิ์ (หมู่บ้านเมฆาคราม)"
    cauldronPrompt.ActionText = "เริ่มการหลอมโอสถ"
    cauldronPrompt.HoldDuration = 0.5
    cauldronPrompt.MaxActivationDistance = 15
    cauldronPrompt.Parent = cBowl

    cauldronPrompt.Triggered:Connect(function(player)
        NetworkEvents.OpenCauldronUI:FireClient(player, true)
    end)

    -- ซุ้มพ่อค้า NPC ผู้อาวุโสชิง (Elder Qing Merchant Booth)
    local npcPos = center + Vector3.new(16, 1, 20)
    local tableBooth = createPart("MerchantTable", Vector3.new(8, 3, 3), CFrame.new(npcPos + Vector3.new(0, 1.5, 0)),
        Color3.fromRGB(90, 55, 35), Enum.Material.Wood, hDistrict)

    -- ร่างจำลอง NPC ผู้อาวุโสชิง
    local npcRoot = createPart("HumanoidRootPart", Vector3.new(2, 4.5, 1.5), CFrame.new(npcPos + Vector3.new(0, 3.5, -2.5)),
        Color3.fromRGB(45, 120, 80), Enum.Material.Fabric, npcsFolder)
    createPart("ElderHead", Vector3.new(1.3, 1.3, 1.3), CFrame.new(npcPos + Vector3.new(0, 5.8, -2.5)),
        Color3.fromRGB(240, 215, 190), Enum.Material.SmoothPlastic, npcsFolder)

    local npcLbl = Instance.new("BillboardGui")
    npcLbl.Size = UDim2.new(0, 180, 0, 40)
    npcLbl.StudsOffset = Vector3.new(0, 3.5, 0)
    npcLbl.AlwaysOnTop = true
    npcLbl.Parent = npcRoot

    local nText = Instance.new("TextLabel")
    nText.Size = UDim2.new(1, 0, 1, 0)
    nText.BackgroundTransparency = 1
    nText.Text = "ผู้อาวุโสชิง [ร้านค้าโอสถ]"
    nText.TextColor3 = Color3.fromRGB(120, 255, 160)
    nText.Font = Enum.Font.SourceSansBold
    nText.TextSize = 14
    nText.Parent = npcLbl

    local qingPrompt = Instance.new("ProximityPrompt")
    qingPrompt.ObjectText = "ผู้อาวุโสชิง"
    qingPrompt.ActionText = "สนทนา / ค้าขายโอสถและสมุนไพร"
    qingPrompt.HoldDuration = 0.4
    qingPrompt.MaxActivationDistance = 14
    qingPrompt.Parent = npcRoot

    qingPrompt.Triggered:Connect(function(player)
        NetworkEvents.OpenMerchantShop:FireClient(player, "ElderQing")
    end)
end

-- 3.3 Blacksmith & Trade Stalls (โรงตีเหล็กและตลาดร้านค้า - ทางตะวันออก)
local function buildBlacksmithAndMarket()
    local bDistrict = Instance.new("Model")
    bDistrict.Name = "MarketDistrict"
    bDistrict.Parent = buildingsFolder

    local smithPos = Vector3.new(165, 10, -25)

    -- โรงตีเหล็กแบบเปิดโล่ง (Open-Air Smithy)
    createChineseBuilding("SmithyWorkshop", CFrame.new(smithPos), 36, 26, 13,
        Color3.fromRGB(80, 85, 90), Color3.fromRGB(65, 45, 35), Color3.fromRGB(150, 45, 40), bDistrict)

    -- เตาหลอมตีเหล็ก (Forge Furnace)
    local forgeFire = createPart("ForgeCore", Vector3.new(6, 4, 6), CFrame.new(smithPos + Vector3.new(6, 4, -4)),
        Color3.fromRGB(255, 120, 30), Enum.Material.Neon, bDistrict)
    local forgeLight = Instance.new("PointLight")
    forgeLight.Color = Color3.fromRGB(255, 140, 40)
    forgeLight.Range = 22
    forgeLight.Brightness = 2.2
    forgeLight.Parent = forgeFire

    -- ทั่งตีเหล็ก (Anvil)
    local anvil = createPart("Anvil", Vector3.new(2.5, 2.5, 4), CFrame.new(smithPos + Vector3.new(-4, 2.5, 2)),
        Color3.fromRGB(35, 35, 40), Enum.Material.Metal, bDistrict)

    -- NPC ปรมาจารย์เถี่ย (Master Tie)
    local tieRoot = createPart("HumanoidRootPart", Vector3.new(2, 4.5, 1.5), CFrame.new(smithPos + Vector3.new(-8, 3.5, 2)),
        Color3.fromRGB(130, 50, 40), Enum.Material.Fabric, npcsFolder)
    createPart("TieHead", Vector3.new(1.3, 1.3, 1.3), CFrame.new(smithPos + Vector3.new(-8, 5.8, 2)),
        Color3.fromRGB(235, 205, 180), Enum.Material.SmoothPlastic, npcsFolder)

    local tieLbl = Instance.new("BillboardGui")
    tieLbl.Size = UDim2.new(0, 180, 0, 40)
    tieLbl.StudsOffset = Vector3.new(0, 3.5, 0)
    tieLbl.AlwaysOnTop = true
    tieLbl.Parent = tieRoot

    local tText = Instance.new("TextLabel")
    tText.Size = UDim2.new(1, 0, 1, 0)
    tText.BackgroundTransparency = 1
    tText.Text = "ปรมาจารย์เถี่ย [ช่างตีเหล็กสวรรค์]"
    tText.TextColor3 = Color3.fromRGB(255, 180, 90)
    tText.Font = Enum.Font.SourceSansBold
    tText.TextSize = 14
    tText.Parent = tieLbl

    local tiePrompt = Instance.new("ProximityPrompt")
    tiePrompt.ObjectText = "ปรมาจารย์เถี่ย"
    tiePrompt.ActionText = "เลือกซื้ออุปกรณ์และศัสตราวุธเซียน"
    tiePrompt.HoldDuration = 0.4
    tiePrompt.MaxActivationDistance = 14
    tiePrompt.Parent = tieRoot

    tiePrompt.Triggered:Connect(function(player)
        NetworkEvents.OpenMerchantShop:FireClient(player, "MasterTie")
    end)

    -- แผงร้านค้าตลาด 3 แผงริมถนน (3 Trade Stalls with Fabric Awnings)
    local stallZOffsets = { 25, 55, 85 }
    for i, zOff in ipairs(stallZOffsets) do
        local stallPos = Vector3.new(125, 10, zOff)
        createPart("StallTable_" .. i, Vector3.new(10, 3, 5), CFrame.new(stallPos + Vector3.new(0, 1.5, 0)),
            Color3.fromRGB(120, 85, 55), Enum.Material.Wood, bDistrict)
        -- กันสาดผ้าใบสีแดงสลับขาว (Cloth Awning)
        createPart("Awning_" .. i, Vector3.new(12, 1, 7), CFrame.new(stallPos + Vector3.new(0, 6, 0)) * CFrame.Angles(0, 0, math.rad(10)),
            (i % 2 == 0) and Color3.fromRGB(180, 50, 40) or Color3.fromRGB(240, 225, 180), Enum.Material.Fabric, bDistrict)
    end
end

-- 3.4 Cloud Rest Inn, Sparring Ring & Bamboo Grove (โรงเตี๊ยมและลานประลองยุทธ์ - ทางตะวันตก)
local function buildInnAndSparringDistrict()
    local wDistrict = Instance.new("Model")
    wDistrict.Name = "InnDistrict"
    wDistrict.Parent = buildingsFolder

    local innCenter = Vector3.new(-165, 10, -25)

    -- โรงเตี๊ยมเมฆา 2 ชั้น (Two-Story Classic Chinese Inn)
    createChineseBuilding("CloudRestInn_1F", CFrame.new(innCenter), 42, 32, 14,
        Color3.fromRGB(240, 235, 225), Color3.fromRGB(50, 35, 25), Color3.fromRGB(180, 60, 45), wDistrict)
    -- ชั้นที่สอง
    createChineseBuilding("CloudRestInn_2F", CFrame.new(innCenter + Vector3.new(0, 15, 0)), 36, 26, 12,
        Color3.fromRGB(240, 235, 225), Color3.fromRGB(50, 35, 25), Color3.fromRGB(180, 60, 45), wDistrict)

    -- โคมไฟแดงแขวนตามชายคาโรงเตี๊ยม (Hanging Red Lanterns)
    createRedLantern(CFrame.new(innCenter + Vector3.new(-18, 12, 18)), wDistrict)
    createRedLantern(CFrame.new(innCenter + Vector3.new(18, 12, 18)), wDistrict)

    -- ลานประลองยุทธ์ยกพื้นหิน (Raised Sparring Ring) ข้างโรงเตี๊ยม
    local ringPos = Vector3.new(-145, 10, 50)
    createPart("SparringRingBase", Vector3.new(38, 1.8, 38), CFrame.new(ringPos + Vector3.new(0, 0.9, 0)),
        Color3.fromRGB(140, 125, 110), Enum.Material.Sandstone, wDistrict)

    -- ป่าไผ่และม้านั่งหินบำเพ็ญเพียร (Peaceful Bamboo Grove & Meditation Benches)
    local groveCenter = Vector3.new(-155, 10, 110)
    for i = 1, 35 do
        local rx = math.random(-35, 35)
        local rz = math.random(-30, 30)
        local bHeight = math.random(18, 30)
        createPart("Bamboo_" .. i, Vector3.new(1.2, bHeight, 1.2), CFrame.new(groveCenter + Vector3.new(rx, bHeight / 2, rz)),
            Color3.fromRGB(80, 175, 75), Enum.Material.Wood, foliageFolder)
    end

    -- ม้านั่งหินสมาธิ (Meditation Stone Benches granting Qi/Tapasya passive buff)
    local bench1 = createPart("MeditationBench1", Vector3.new(6, 1.8, 3), CFrame.new(groveCenter + Vector3.new(0, 0.9, 0)),
        Color3.fromRGB(120, 125, 130), Enum.Material.Slate, wDistrict)

    local mGui = Instance.new("BillboardGui")
    mGui.Size = UDim2.new(0, 180, 0, 35)
    mGui.StudsOffset = Vector3.new(0, 2.5, 0)
    mGui.AlwaysOnTop = true
    mGui.MaxDistance = 30
    mGui.Parent = bench1

    local mLbl = Instance.new("TextLabel")
    mLbl.Size = UDim2.new(1, 0, 1, 0)
    mLbl.BackgroundTransparency = 1
    mLbl.Text = "🧘 ม้านั่งหินบำเพ็ญเพียร\n(+20 ปราณ/ตบะต่อวิ)"
    mLbl.TextColor3 = Color3.fromRGB(140, 255, 180)
    mLbl.Font = Enum.Font.SourceSansBold
    mLbl.TextSize = 12
    mLbl.Parent = mGui
end

-- 3.5 The South Gate (ประตูทางออกสู่ยุทธภพ - ซุ้มประตูไผฟาง Paifang Archway)
local function buildSouthGate()
    local gateModel = Instance.new("Model")
    gateModel.Name = "SouthGate"
    gateModel.Parent = buildingsFolder

    local gatePos = Vector3.new(0, 10, 180)

    -- เสาซุ้มประตูสีแดง 2 เสาหลัก (Main Red Timber Columns)
    local colL = createPart("PaifangColL", Vector3.new(3.5, 26, 3.5), CFrame.new(gatePos + Vector3.new(-16, 13, 0)),
        Color3.fromRGB(175, 40, 35), Enum.Material.Wood, gateModel)
    local colR = createPart("PaifangColR", Vector3.new(3.5, 26, 3.5), CFrame.new(gatePos + Vector3.new(16, 13, 0)),
        Color3.fromRGB(175, 40, 35), Enum.Material.Wood, gateModel)

    -- คานซุ้มด้านบนและป้ายชื่อประตู
    local beam = createPart("PaifangBeam", Vector3.new(38, 3.5, 4), CFrame.new(gatePos + Vector3.new(0, 23, 0)),
        Color3.fromRGB(175, 40, 35), Enum.Material.Wood, gateModel)
    createPagodaRoof(CFrame.new(gatePos + Vector3.new(0, 24.5, 0)), 40, 8, 4.5, Color3.fromRGB(45, 60, 70), gateModel)

    -- ป้ายอักษรทองเหนือประตู
    local plaque = createPart("Plaque", Vector3.new(18, 4, 1), CFrame.new(gatePos + Vector3.new(0, 20.5, 0)),
        Color3.fromRGB(35, 35, 40), Enum.Material.Wood, gateModel)

    local pGui = Instance.new("BillboardGui")
    pGui.Size = UDim2.new(0, 240, 0, 45)
    pGui.StudsOffset = Vector3.new(0, 1, 0)
    pGui.AlwaysOnTop = true
    pGui.MaxDistance = 75
    pGui.Parent = plaque

    local pLbl = Instance.new("TextLabel")
    pLbl.Size = UDim2.new(1, 0, 1, 0)
    pLbl.BackgroundTransparency = 1
    pLbl.Text = "⛩️ ประตูเมฆาครามสู่ยุทธภพ ⛩️"
    pLbl.TextColor3 = Color3.fromRGB(255, 215, 80)
    pLbl.Font = Enum.Font.SourceSansBold
    pLbl.TextSize = 16
    pLbl.Parent = pGui

    -- รูปปั้นสิงโตหินผู้พิทักษ์ 2 ฝั่ง (Guardian Stone Beasts)
    createPart("LionLeft", Vector3.new(4, 7, 4), CFrame.new(gatePos + Vector3.new(-22, 3.5, -4)),
        Color3.fromRGB(90, 95, 100), Enum.Material.Slate, gateModel)
    createPart("LionRight", Vector3.new(4, 7, 4), CFrame.new(gatePos + Vector3.new(22, 3.5, -4)),
        Color3.fromRGB(90, 95, 100), Enum.Material.Slate, gateModel)

    -- ป้ายบอกทางแยกสู่ 2 ดินแดน (Direction Signposts)
    local signL = createPart("SignpostL", Vector3.new(1, 7, 1), CFrame.new(-35, 13.5, 205), Color3.fromRGB(90, 60, 40), Enum.Material.Wood, gateModel)
    local bL = Instance.new("BillboardGui")
    bL.Size = UDim2.new(0, 220, 0, 40)
    bL.StudsOffset = Vector3.new(0, 4, 0)
    bL.AlwaysOnTop = true
    bL.Parent = signL
    local tL = Instance.new("TextLabel")
    tL.Size = UDim2.new(1, 0, 1, 0)
    tL.BackgroundTransparency = 1
    tL.Text = "↖ ทางไป: แดนพฤกษาสวรรค์ [PvE Herb Sanctuary]"
    tL.TextColor3 = Color3.fromRGB(100, 255, 170)
    tL.Font = Enum.Font.SourceSansBold
    tL.TextSize = 13
    tL.Parent = bL

    local signR = createPart("SignpostR", Vector3.new(1, 7, 1), CFrame.new(35, 13.5, 205), Color3.fromRGB(90, 60, 40), Enum.Material.Wood, gateModel)
    local bR = Instance.new("BillboardGui")
    bR.Size = UDim2.new(0, 220, 0, 40)
    bR.StudsOffset = Vector3.new(0, 4, 0)
    bR.AlwaysOnTop = true
    bR.Parent = signR
    local tR = Instance.new("TextLabel")
    tR.Size = UDim2.new(1, 0, 1, 0)
    tR.BackgroundTransparency = 1
    tR.Text = "ทางไป: หุบเขาอสูรโลหิต [PvP Asura Valley] ↗"
    tR.TextColor3 = Color3.fromRGB(255, 90, 75)
    tR.Font = Enum.Font.SourceSansBold
    tR.TextSize = 13
    tR.Parent = bR
end

--------------------------------------------------------------------------------
-- 4. FUNCTIONAL TELEPORTATION PORTALS & RETURN ALTARS
--------------------------------------------------------------------------------
local function buildTeleportPortals()
    print("🌀 [AzureVillage] ติดตั้งประตูมิติวาร์ปคู่ที่ปลายถนนทิศใต้...")

    local lastTeleportDebounce = {}

    -- 4.1 Left Portal - แดนพฤกษาสวรรค์ (PvE Sanctuary) ที่ Vector3.new(-250, 10, 250)
    local pvePos = Vector3.new(-250, 10, 250)
    local pvePortalModel = Instance.new("Model")
    pvePortalModel.Name = "PvE_Sanctuary_Portal"
    pvePortalModel.Parent = portalsFolder

    -- ซุ้มหินโบราณ
    createPart("PveArchL", Vector3.new(4, 22, 4), CFrame.new(pvePos + Vector3.new(-7, 11, 0)),
        Color3.fromRGB(60, 75, 70), Enum.Material.Slate, pvePortalModel)
    createPart("PveArchR", Vector3.new(4, 22, 4), CFrame.new(pvePos + Vector3.new(7, 11, 0)),
        Color3.fromRGB(60, 75, 70), Enum.Material.Slate, pvePortalModel)
    createPart("PveArchTop", Vector3.new(18, 4, 5), CFrame.new(pvePos + Vector3.new(0, 22, 0)),
        Color3.fromRGB(75, 90, 85), Enum.Material.Slate, pvePortalModel)

    -- แผ่นม่านพลังเรืองแสงสีเขียวมรกต/คราม (Translucent Neon Pad)
    local pvePad = createPart("PvEPortalPad", Vector3.new(10, 18, 1.2), CFrame.new(pvePos + Vector3.new(0, 10, 0)),
        Color3.fromRGB(80, 240, 180), Enum.Material.Neon, pvePortalModel, false)
    pvePad.Transparency = 0.35

    -- ละอองปราณใบไม้และสายลมลอยฟุ้ง
    local pveEmitter = Instance.new("ParticleEmitter")
    pveEmitter.Color = ColorSequence.new(Color3.fromRGB(100, 255, 180), Color3.fromRGB(180, 255, 230))
    pveEmitter.Size = NumberSequence.new(1.8, 0.4)
    pveEmitter.Lifetime = NumberRange.new(1, 1.8)
    pveEmitter.Rate = 45
    pveEmitter.Speed = NumberRange.new(2, 6)
    pveEmitter.SpreadAngle = Vector2.new(45, 45)
    pveEmitter.Parent = pvePad

    local pveLight = Instance.new("PointLight")
    pveLight.Color = Color3.fromRGB(90, 255, 190)
    pveLight.Range = 25
    pveLight.Brightness = 2
    pveLight.Parent = pvePad

    -- Touched Event สำหรับวาร์ปไปยัง PvE Sanctuary (Vector3.new(1500, 50, 0))
    pvePad.Touched:Connect(function(hit)
        local player = Players:GetPlayerFromCharacter(hit.Parent)
        if player then
            local now = os.clock()
            if not lastTeleportDebounce[player.UserId] or (now - lastTeleportDebounce[player.UserId] > 3) then
                lastTeleportDebounce[player.UserId] = now
                local root = hit.Parent:FindFirstChild("HumanoidRootPart")
                if root then
                    root.CFrame = CFrame.new(Vector3.new(1500, 52, 0))
                end
            end
        end
    end)

    -- 4.2 Right Portal - หุบเขาอสูรโลหิต (PvP Asura Valley) ที่ Vector3.new(250, 10, 250)
    local pvpPos = Vector3.new(250, 10, 250)
    local pvpPortalModel = Instance.new("Model")
    pvpPortalModel.Name = "PvP_Asura_Portal"
    pvpPortalModel.Parent = portalsFolder

    -- ซุ้มหินทมิฬขนาบด้วยคบเพลิงโลหิต
    createPart("PvpArchL", Vector3.new(4, 22, 4), CFrame.new(pvpPos + Vector3.new(-7, 11, 0)),
        Color3.fromRGB(35, 30, 35), Enum.Material.Basalt, pvpPortalModel)
    createPart("PvpArchR", Vector3.new(4, 22, 4), CFrame.new(pvpPos + Vector3.new(7, 11, 0)),
        Color3.fromRGB(35, 30, 35), Enum.Material.Basalt, pvpPortalModel)
    createPart("PvpArchTop", Vector3.new(18, 4, 5), CFrame.new(pvpPos + Vector3.new(0, 22, 0)),
        Color3.fromRGB(45, 35, 40), Enum.Material.Basalt, pvpPortalModel)

    -- คบเพลิงไฟโลหิต 2 ข้าง
    local torchL = createPart("TorchL", Vector3.new(1.5, 3, 1.5), CFrame.new(pvpPos + Vector3.new(-10, 14, 0)),
        Color3.fromRGB(255, 60, 40), Enum.Material.Neon, pvpPortalModel, false)
    local torchR = createPart("TorchR", Vector3.new(1.5, 3, 1.5), CFrame.new(pvpPos + Vector3.new(10, 14, 0)),
        Color3.fromRGB(255, 60, 40), Enum.Material.Neon, pvpPortalModel, false)

    -- แผ่นม่านพลังสีเลือด/ม่วงทมิฬ
    local pvpPad = createPart("PvPPortalPad", Vector3.new(10, 18, 1.2), CFrame.new(pvpPos + Vector3.new(0, 10, 0)),
        Color3.fromRGB(235, 45, 55), Enum.Material.Neon, pvpPortalModel, false)
    pvpPad.Transparency = 0.35

    local pvpEmitter = Instance.new("ParticleEmitter")
    pvpEmitter.Color = ColorSequence.new(Color3.fromRGB(255, 50, 50), Color3.fromRGB(150, 30, 120))
    pvpEmitter.Size = NumberSequence.new(1.8, 0.4)
    pvpEmitter.Lifetime = NumberRange.new(0.8, 1.5)
    pvpEmitter.Rate = 50
    pvpEmitter.Speed = NumberRange.new(3, 7)
    pvpEmitter.SpreadAngle = Vector2.new(45, 45)
    pvpEmitter.Parent = pvpPad

    local pvpLight = Instance.new("PointLight")
    pvpLight.Color = Color3.fromRGB(255, 60, 60)
    pvpLight.Range = 25
    pvpLight.Brightness = 2.2
    pvpLight.Parent = pvpPad

    -- Touched Event สำหรับวาร์ปไปยัง PvP Asura Valley (Vector3.new(-1500, 50, 0))
    pvpPad.Touched:Connect(function(hit)
        local player = Players:GetPlayerFromCharacter(hit.Parent)
        if player then
            local now = os.clock()
            if not lastTeleportDebounce[player.UserId] or (now - lastTeleportDebounce[player.UserId] > 3) then
                lastTeleportDebounce[player.UserId] = now
                local root = hit.Parent:FindFirstChild("HumanoidRootPart")
                if root then
                    root.CFrame = CFrame.new(Vector3.new(-1500, 52, 0))
                end
            end
        end
    end)

    -- 4.3 Return Altars: แท่นบูชาศิลาวาร์ปกลับหมู่บ้านที่พิกัด (1500, 50, 0) และ (-1500, 50, 0)
    local function createReturnShrine(shrinePos, labelText, lightColor)
        local shrineModel = Instance.new("Model")
        shrineModel.Name = "ReturnShrine"
        shrineModel.Parent = portalsFolder

        local shrineBase = createPart("ShrineBase", Vector3.new(14, 2, 14), CFrame.new(shrinePos + Vector3.new(0, 1, 0)),
            Color3.fromRGB(120, 125, 130), Enum.Material.Slate, shrineModel)
        local returnPad = createPart("ReturnPortalPad", Vector3.new(8, 0.6, 8), CFrame.new(shrinePos + Vector3.new(0, 2.2, 0)),
            lightColor, Enum.Material.Neon, shrineModel, false)

        local rGui = Instance.new("BillboardGui")
        rGui.Size = UDim2.new(0, 220, 0, 45)
        rGui.StudsOffset = Vector3.new(0, 6, 0)
        rGui.AlwaysOnTop = true
        rGui.MaxDistance = 60
        rGui.Parent = returnPad

        local rLbl = Instance.new("TextLabel")
        rLbl.Size = UDim2.new(1, 0, 1, 0)
        rLbl.BackgroundTransparency = 1
        rLbl.Text = labelText
        rLbl.TextColor3 = lightColor
        rLbl.Font = Enum.Font.SourceSansBold
        rLbl.TextSize = 15
        rLbl.Parent = rGui

        returnPad.Touched:Connect(function(hit)
            local player = Players:GetPlayerFromCharacter(hit.Parent)
            if player then
                local now = os.clock()
                if not lastTeleportDebounce[player.UserId] or (now - lastTeleportDebounce[player.UserId] > 3) then
                    lastTeleportDebounce[player.UserId] = now
                    local root = hit.Parent:FindFirstChild("HumanoidRootPart")
                    if root then
                        root.CFrame = CFrame.new(Vector3.new(0, 15, 0))
                    end
                end
            end
        end)
    end

    createReturnShrine(Vector3.new(1500, 50, 0), "⛩️ สัมผัสเพื่อกลับสู่หมู่บ้านเมฆาคราม", Color3.fromRGB(100, 220, 255))
    createReturnShrine(Vector3.new(-1500, 50, 0), "⛩️ สัมผัสเพื่อกลับสู่หมู่บ้านเมฆาคราม", Color3.fromRGB(255, 140, 80))
end

--------------------------------------------------------------------------------
-- 5. ENVIRONMENT, ATMOSPHERE & TECHNICAL INTEGRITY
--------------------------------------------------------------------------------
local function configureAtmosphereAndLighting()
    print("🌅 [AzureVillage] กำหนดค่าระบบแสง Future Lighting และบรรยากาศอรุณรุ่ง...")

    pcall(function()
        Lighting.Technology = Enum.Technology.Future
        Lighting.TimeOfDay = "07:30:00"
        Lighting.Brightness = 2.2
        Lighting.OutdoorAmbient = Color3.fromRGB(140, 130, 110)
        Lighting.ClockTime = 7.5
    end)

    -- ปรับแต่ง Atmosphere
    local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
    if not atmosphere then
        atmosphere = Instance.new("Atmosphere")
        atmosphere.Parent = Lighting
    end
    atmosphere.Density = 0.3
    atmosphere.Haze = 1.5
    atmosphere.Color = Color3.fromRGB(255, 240, 215)
    atmosphere.Decay = Color3.fromRGB(180, 195, 210)

    -- ปรับแต่ง ColorCorrection
    local cc = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
    if not cc then
        cc = Instance.new("ColorCorrectionEffect")
        cc.Parent = Lighting
    end
    cc.Saturation = 0.15
    cc.Contrast = 0.1
    cc.TintColor = Color3.fromRGB(255, 252, 245)

    -- เพลงบรรเลงจีนโบราณใน SoundService
    local bgm = SoundService:FindFirstChild("VillageBGM")
    if not bgm then
        bgm = Instance.new("Sound")
        bgm.Name = "VillageBGM"
        bgm.SoundId = "rbxassetid://1837849285" -- เสียงดนตรีบรรเลงขลุ่ยไม้ไผ่โบราณ
        bgm.Volume = 0.35
        bgm.Looped = true
        bgm.Parent = SoundService
        bgm:Play()
    end
end

--------------------------------------------------------------------------------
-- 6. ระบบฟื้นฟูลมปราณและตบะบริเวณม้านั่งหินสมาธิ (+20 ตบะ/ปราณ ต่อวินาที)
--------------------------------------------------------------------------------
task.spawn(function()
    while true do
        task.wait(1.5)
        local meditationPos = Vector3.new(-155, 10, 110)
        for _, player in ipairs(Players:GetPlayers()) do
            local char = player.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            if root and (root.Position - meditationPos).Magnitude <= 35 then
                CultivationManager:AddTapasya(player, 30)
                local curChi = player:GetAttribute("Chi") or 100
                local maxChi = player:GetAttribute("MaxChi") or 100
                player:SetAttribute("Chi", math.min(maxChi, curChi + 25))
            end
        end
    end
end)

--------------------------------------------------------------------------------
-- เริ่มต้นกระบวนการก่อสร้างหมู่บ้านทั้งหมด
--------------------------------------------------------------------------------
task.spawn(function()
    buildTerrainAndLandscape()
    buildRoadNetwork()
    buildCentralSquare()
    buildHerbalistDistrict()
    buildBlacksmithAndMarket()
    buildInnAndSparringDistrict()
    buildSouthGate()
    buildTeleportPortals()
    configureAtmosphereAndLighting()
    print("🌸 [AzureVillage] สถาปัตยกรรมหมู่บ้านเมฆาคราม (Azure Cloud Village) สร้างสำเร็จสมบูรณ์ 100%!")
end)

