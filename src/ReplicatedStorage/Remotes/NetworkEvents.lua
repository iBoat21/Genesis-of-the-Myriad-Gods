local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ตรวจสอบหรือสร้างโฟลเดอร์ Remotes
local RemotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
if not RemotesFolder then
    RemotesFolder = script.Parent
    if not RemotesFolder or RemotesFolder.Name ~= "Remotes" then
        RemotesFolder = Instance.new("Folder")
        RemotesFolder.Name = "Remotes"
        RemotesFolder.Parent = ReplicatedStorage
    end
end

local function getOrCreateRemote(className, name)
    local remote = RemotesFolder:FindFirstChild(name)
    if not remote then
        remote = Instance.new(className)
        remote.Name = name
        remote.Parent = RemotesFolder
    end
    return remote
end

local NetworkEvents = {
    -- ระบบกระเป๋าและสมุนไพร
    GatherHerb = getOrCreateRemote("RemoteFunction", "GatherHerb"),
    UpdateInventory = getOrCreateRemote("RemoteEvent", "UpdateInventory"),
    RequestInitialData = getOrCreateRemote("RemoteEvent", "RequestInitialData"),

    -- ระบบตบะและการข้ามขอบเขต (Breakthrough)
    Breakthrough = getOrCreateRemote("RemoteFunction", "Breakthrough"),
    BreakthroughEffect = getOrCreateRemote("RemoteEvent", "BreakthroughEffect"),
    SyncCultivation = getOrCreateRemote("RemoteEvent", "SyncCultivation"),

    -- ระบบสเตตัสตัวละคร & ม่านพลัง (Stats & Zone Barriers)
    SyncStats = getOrCreateRemote("RemoteEvent", "SyncStats"),
    BarrierDenied = getOrCreateRemote("RemoteEvent", "BarrierDenied"),

    -- ระบบเตาหลอมโอสถ & การปรุงยา (Alchemy System & Dynamic Minigame)
    CraftPill = getOrCreateRemote("RemoteFunction", "CraftPill"),
    CraftDynamicPill = getOrCreateRemote("RemoteFunction", "CraftDynamicPill"),
    SpawnPersonalCauldron = getOrCreateRemote("RemoteFunction", "SpawnPersonalCauldron"),
    DismissPersonalCauldron = getOrCreateRemote("RemoteFunction", "DismissPersonalCauldron"),
    UsePill = getOrCreateRemote("RemoteFunction", "UsePill"),
    OpenCauldronUI = getOrCreateRemote("RemoteEvent", "OpenCauldronUI"),
    SyncDiscoveredPills = getOrCreateRemote("RemoteEvent", "SyncDiscoveredPills"),
    GetDiscoveredPills = getOrCreateRemote("RemoteFunction", "GetDiscoveredPills"),

    -- ระบบ Admin & Tester Terminal
    AdminCommand = getOrCreateRemote("RemoteFunction", "AdminCommand"),
    AdminStatusChanged = getOrCreateRemote("RemoteEvent", "AdminStatusChanged"),
    CheckAdminAccess = getOrCreateRemote("RemoteFunction", "CheckAdminAccess"),

    -- ระบบสำรวจโลก & วาร์ปทวิภพ (World Exploration & Gateways)
    TeleportToZone = getOrCreateRemote("RemoteFunction", "TeleportToZone"),
    ZoneChanged = getOrCreateRemote("RemoteEvent", "ZoneChanged"),

    -- ระบบร้านค้าและโรงหลอม (Pill Master & Celestial Blacksmith Shops)
    OpenMerchantShop = getOrCreateRemote("RemoteEvent", "OpenMerchantShop"),
    BuyShopItem = getOrCreateRemote("RemoteFunction", "BuyShopItem"),
    SellPillItem = getOrCreateRemote("RemoteFunction", "SellPillItem"),

    -- ระบบปาร์ตี้และการต่อสู้ (Party & Combat Logic)
    CreateParty = getOrCreateRemote("RemoteFunction", "CreateParty"),
    InviteToParty = getOrCreateRemote("RemoteFunction", "InviteToParty"),
    AcceptPartyInvite = getOrCreateRemote("RemoteFunction", "AcceptPartyInvite"),
    LeaveParty = getOrCreateRemote("RemoteFunction", "LeaveParty"),
    KickPartyMember = getOrCreateRemote("RemoteFunction", "KickPartyMember"),
    SyncParty = getOrCreateRemote("RemoteEvent", "SyncParty"),
    PartyInviteReceived = getOrCreateRemote("RemoteEvent", "PartyInviteReceived"),
}

return NetworkEvents
