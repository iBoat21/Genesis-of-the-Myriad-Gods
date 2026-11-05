local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local NetworkEvents = require(ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("NetworkEvents"))
local GameConfig = require(ReplicatedStorage:WaitForChild("SharedModules"):WaitForChild("GameConfig"))
local HerbDatabase = require(ReplicatedStorage:WaitForChild("SharedModules"):WaitForChild("HerbDatabase"))
local CultivationManager = require(ServerScriptService:WaitForChild("CultivationManager"))

local ProfileStore
local success, err = pcall(function()
    ProfileStore = DataStoreService:GetDataStore("DaoistPlayerProfile_v1")
end)

if not success then
    warn("⚠️ ไม่สามารถเชื่อมต่อ DataStore ได้ (อาจยังไม่ได้ Publish เกม หรือเปิด Studio API Access): " .. tostring(err))
end

local PlayerData = {}

-- ฟังก์ชันโหลดข้อมูล
local function loadData(player)
    local userId = player.UserId
    print("🔍 กำลังโหลดข้อมูลให้: " .. player.Name)
    
    local inventory = {}
    local tapasya = 0
    local realmIndex = 1
    local discoveredPills = {}

    if ProfileStore then
        local success, data = pcall(function()
            return ProfileStore:GetAsync(tostring(userId))
        end)
        if success and data then
            if data.Inventory then
                -- รูปแบบเซฟใหม่
                inventory = data.Inventory or {}
                tapasya = data.Tapasya or 0
                realmIndex = data.RealmIndex or 1
                discoveredPills = data.DiscoveredPills or {}
            else
                -- รูปแบบเซฟเก่า (กระเป๋าอย่างเดียว)
                inventory = data
            end
        end
    end

    PlayerData[userId] = {
        Inventory = inventory,
        DiscoveredPills = discoveredPills,
    }

    -- ตั้งค่าตบะและขอบเขตให้กับผู้เล่น
    CultivationManager:SetupPlayer(player, tapasya, realmIndex)
    
    print("💾 ข้อมูลของ " .. player.Name .. " พร้อมใช้งาน (Session Data Loaded)")
    -- ส่งข้อมูลกระเป๋าและตำรับยาที่ค้นพบไปให้ Client
    NetworkEvents.UpdateInventory:FireClient(player, PlayerData[userId].Inventory)
    NetworkEvents.SyncDiscoveredPills:FireClient(player, PlayerData[userId].DiscoveredPills)
end

-- ฟังก์ชันเซฟข้อมูล
local function saveData(player)
    local userId = player.UserId
    if PlayerData[userId] and ProfileStore then
        local currentTapasya = CultivationManager:GetPlayerTapasya(player)
        local currentRealm = CultivationManager:GetPlayerRealmIndex(player)
        
        local dataToSave = {
            Inventory = PlayerData[userId].Inventory or {},
            DiscoveredPills = PlayerData[userId].DiscoveredPills or {},
            Tapasya = currentTapasya,
            RealmIndex = currentRealm
        }

        local success, err = pcall(function()
            ProfileStore:SetAsync(tostring(userId), dataToSave)
        end)
        if success then
            print("💾 เซฟข้อมูลทั้งหมดของ " .. player.Name .. " เรียบร้อย")
        else
            warn("❌ เซฟข้อมูลไม่สำเร็จ: " .. tostring(err))
        end
    end
end

-- เชื่อมต่อ Event ผู้เล่น
Players.PlayerAdded:Connect(loadData)
for _, player in ipairs(Players:GetPlayers()) do
    task.spawn(loadData, player)
end

Players.PlayerRemoving:Connect(function(player)
    saveData(player)
    PlayerData[player.UserId] = nil
end)

-- ปิดเกม (สำหรับ Studio หรือ Server ปิดตัว)
game:BindToClose(function()
    for _, player in ipairs(Players:GetPlayers()) do
        saveData(player)
    end
    task.wait(1)
end)

-- Client ขอข้อมูลล่าสุด
NetworkEvents.RequestInitialData.OnServerEvent:Connect(function(player)
    if PlayerData[player.UserId] then
        NetworkEvents.UpdateInventory:FireClient(player, PlayerData[player.UserId].Inventory)
    end
    CultivationManager:SyncToClient(player)
end)

-- ฟังก์ชันจัดการการเก็บสมุนไพร
NetworkEvents.GatherHerb.OnServerInvoke = function(player, herbPart)
    if not herbPart or not herbPart:IsA("BasePart") then return false end
    
    local herbName = herbPart:GetAttribute("HerbName")
    local isValidHerb = (HerbDatabase and HerbDatabase.Get(herbName)) or (GameConfig.Herbs and GameConfig.Herbs[herbName])
    if not herbName or not isValidHerb then return false end

    -- เช็คระยะห่าง
    local character = player.Character
    if character and character:FindFirstChild("HumanoidRootPart") then
        local distance = (character.HumanoidRootPart.Position - herbPart.Position).Magnitude
        if distance > 18 then return false, "ไกลเกินไป" end
    end

    -- ลบสมุนไพรออกจากแมพ
    herbPart:Destroy()

    -- เพิ่มเข้ากระเป๋าใน PlayerData
    if not PlayerData[player.UserId] then return false end
    
    local inventory = PlayerData[player.UserId].Inventory
    inventory[herbName] = (inventory[herbName] or 0) + 1

    -- แจ้ง Client ให้อัปเดต
    NetworkEvents.UpdateInventory:FireClient(player, inventory)

    return true
end

-- ให้ระบบอื่นและ AdminServer เรียกใช้งานข้อมูลกระเป๋าได้
_G.DaoistDataManager = {
    GetInventory = function(player)
        if PlayerData[player.UserId] then
            return PlayerData[player.UserId].Inventory
        end
        return {}
    end,

    AddHerb = function(player, herbName, count)
        if not PlayerData[player.UserId] then return false end
        local inventory = PlayerData[player.UserId].Inventory
        count = count or 1
        inventory[herbName] = (inventory[herbName] or 0) + count
        NetworkEvents.UpdateInventory:FireClient(player, inventory)
        return true, inventory[herbName]
    end,

    ClearInventory = function(player)
        if not PlayerData[player.UserId] then return false end
        PlayerData[player.UserId].Inventory = {}
        NetworkEvents.UpdateInventory:FireClient(player, PlayerData[player.UserId].Inventory)
        return true
    end,

    GetDiscoveredPills = function(player)
        if PlayerData[player.UserId] then
            return PlayerData[player.UserId].DiscoveredPills or {}
        end
        return {}
    end,

    AddDiscoveredPill = function(player, pillName)
        if not PlayerData[player.UserId] then return false end
        if not PlayerData[player.UserId].DiscoveredPills then
            PlayerData[player.UserId].DiscoveredPills = {}
        end
        PlayerData[player.UserId].DiscoveredPills[pillName] = true
        NetworkEvents.SyncDiscoveredPills:FireClient(player, PlayerData[player.UserId].DiscoveredPills)
        return true
    end,

    SaveData = function(player)
        saveData(player)
    end
}

NetworkEvents.GetDiscoveredPills.OnServerInvoke = function(player)
    if PlayerData[player.UserId] then
        return PlayerData[player.UserId].DiscoveredPills or {}
    end
    return {}
end
