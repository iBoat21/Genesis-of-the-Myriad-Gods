--[[
    PartyManager.lua
    ระบบจัดการปาร์ตี้ (Party System) สำหรับการผจญภัยและป้องกันการฟันพวกเดียวกันในเขต PvP
    - รองรับ: สร้างปาร์ตี้, เชิญเพื่อน, ตอบรับ, ออกจากปาร์ตี้, เตะสมาชิก
    - ซิงค์สถานะปาร์ตี้และพลังชีวิตของสมาชิกแบบเรียลไทม์
    - กำหนด Attribute: PartyId และ IsPartyLeader เพื่อใช้ในระบบคำนวณการต่อสู้ (Combat Damage)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local NetworkEvents = require(ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("NetworkEvents"))

local PartyManager = {}
local Parties = {} -- [partyId] = { Leader = player, Members = {player1, player2, ...} }
local PlayerPartyMap = {} -- [player.UserId] = partyId

-- ค้นหาปาร์ตี้ของผู้เล่น
function PartyManager.GetPlayerParty(player)
    local partyId = PlayerPartyMap[player.UserId]
    if partyId and Parties[partyId] then
        return partyId, Parties[partyId]
    end
    return nil, nil
end

-- ซิงค์ข้อมูลปาร์ตี้ให้สมาชิกทุกคน
local function syncPartyData(partyId)
    local party = Parties[partyId]
    if not party then return end

    local memberList = {}
    for _, member in ipairs(party.Members) do
        if member and member.Parent then
            local hum = member.Character and member.Character:FindFirstChildOfClass("Humanoid")
            local hp = hum and hum.Health or 100
            local maxHp = hum and hum.MaxHealth or 100
            table.insert(memberList, {
                UserId = member.UserId,
                Name = member.Name,
                DisplayName = member.DisplayName,
                IsLeader = (member == party.Leader),
                Health = hp,
                MaxHealth = maxHp
            })
        end
    end

    for _, member in ipairs(party.Members) do
        if member and member.Parent then
            NetworkEvents.SyncParty:FireClient(member, partyId, memberList)
        end
    end
end

-- สร้างปาร์ตี้ใหม่
function PartyManager.CreateParty(leader)
    if PlayerPartyMap[leader.UserId] then
        return false, "คุณมีปาร์ตี้อยู่แล้ว"
    end

    local partyId = "PARTY_" .. string.sub(HttpService:GenerateGUID(false), 1, 8)
    Parties[partyId] = {
        Id = partyId,
        Leader = leader,
        Members = { leader }
    }
    PlayerPartyMap[leader.UserId] = partyId

    leader:SetAttribute("PartyId", partyId)
    leader:SetAttribute("IsPartyLeader", true)

    syncPartyData(partyId)
    return true, "สร้างปาร์ตี้สำเร็จ"
end

-- ส่งคำเชิญเข้าปาร์ตี้
function PartyManager.InvitePlayer(leader, targetPlayer)
    local partyId, party = PartyManager.GetPlayerParty(leader)
    if not partyId then
        local success, msg = PartyManager.CreateParty(leader)
        if not success then return false, msg end
        partyId, party = PartyManager.GetPlayerParty(leader)
    end

    if party.Leader ~= leader then
        return false, "เฉพาะหัวหน้าปาร์ตี้เท่านั้นที่สามารถเชิญผู้เล่นได้"
    end

    if #party.Members >= 5 then
        return false, "ปาร์ตี้เต็มแล้ว (สูงสุด 5 คน)"
    end

    if PlayerPartyMap[targetPlayer.UserId] then
        return false, "ผู้เล่นเป้าหมายมีปาร์ตี้อยู่แล้ว"
    end

    -- ส่งคำเชิญไปยังผู้เล่นเป้าหมาย
    NetworkEvents.PartyInviteReceived:FireClient(targetPlayer, leader.DisplayName, partyId)
    return true, "ส่งคำเชิญไปยัง " .. targetPlayer.DisplayName .. " แล้ว"
end

-- ตอบรับคำเชิญ
function PartyManager.AcceptInvite(player, partyId)
    if PlayerPartyMap[player.UserId] then
        return false, "คุณมีปาร์ตี้อยู่แล้ว"
    end

    local party = Parties[partyId]
    if not party then
        return false, "ปาร์ตี้ไม่มีอยู่แล้ว"
    end

    if #party.Members >= 5 then
        return false, "ปาร์ตี้นี้เต็มแล้ว"
    end

    table.insert(party.Members, player)
    PlayerPartyMap[player.UserId] = partyId
    player:SetAttribute("PartyId", partyId)
    player:SetAttribute("IsPartyLeader", false)

    syncPartyData(partyId)
    return true, "เข้าร่วมปาร์ตี้เรียบร้อยแล้ว"
end

-- ออกจากปาร์ตี้
function PartyManager.LeaveParty(player)
    local partyId, party = PartyManager.GetPlayerParty(player)
    if not partyId then
        return false, "คุณไม่ได้อยู่ในปาร์ตี้"
    end

    -- นำออกจากสมาชิก
    for i, member in ipairs(party.Members) do
        if member == player then
            table.remove(party.Members, i)
            break
        end
    end

    PlayerPartyMap[player.UserId] = nil
    player:SetAttribute("PartyId", nil)
    player:SetAttribute("IsPartyLeader", nil)
    NetworkEvents.SyncParty:FireClient(player, nil, {})

    -- หากไม่มีสมาชิกเหลือ ให้ยุบปาร์ตี้
    if #party.Members == 0 then
        Parties[partyId] = nil
    else
        -- ถ้าหัวหน้าออก ให้สมาชิกคนถัดไปเป็นหัวหน้าแทน
        if party.Leader == player then
            party.Leader = party.Members[1]
            party.Leader:SetAttribute("IsPartyLeader", true)
        end
        syncPartyData(partyId)
    end

    return true, "ออกจากปาร์ตี้แล้ว"
end

-- หัวหน้าเตะสมาชิก
function PartyManager.KickMember(leader, memberName)
    local partyId, party = PartyManager.GetPlayerParty(leader)
    if not partyId or party.Leader ~= leader then
        return false, "เฉพาะหัวหน้าปาร์ตี้เท่านั้นที่เตะสมาชิกได้"
    end

    local targetMember = nil
    for _, m in ipairs(party.Members) do
        if m.Name:lower() == memberName:lower() or m.DisplayName:lower() == memberName:lower() then
            targetMember = m
            break
        end
    end

    if not targetMember then
        return false, "ไม่พบสมาชิกนี้ในปาร์ตี้"
    end
    if targetMember == leader then
        return false, "ไม่สามารถเตะตัวเองได้ (ใช้ออกจากปาร์ตี้แทน)"
    end

    PartyManager.LeaveParty(targetMember)
    return true, "เตะ " .. targetMember.DisplayName .. " ออกจากปาร์ตี้แล้ว"
end

-- เชื่อมต่อ RemoteFunction
NetworkEvents.CreateParty.OnServerInvoke = function(player)
    return PartyManager.CreateParty(player)
end

NetworkEvents.InviteToParty.OnServerInvoke = function(player, targetName)
    local target = nil
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Name:lower() == tostring(targetName):lower() or p.DisplayName:lower() == tostring(targetName):lower() then
            target = p
            break
        end
    end
    if not target then return false, "ไม่พบผู้เล่นชื่อ: " .. tostring(targetName) end
    return PartyManager.InvitePlayer(player, target)
end

NetworkEvents.AcceptPartyInvite.OnServerInvoke = function(player, partyId)
    return PartyManager.AcceptInvite(player, partyId)
end

NetworkEvents.LeaveParty.OnServerInvoke = function(player)
    return PartyManager.LeaveParty(player)
end

NetworkEvents.KickPartyMember.OnServerInvoke = function(player, memberName)
    return PartyManager.KickMember(player, memberName)
end

-- เมื่อผู้เล่นออกจากเกม
Players.PlayerRemoving:Connect(function(player)
    if PlayerPartyMap[player.UserId] then
        PartyManager.LeaveParty(player)
    end
end)

-- ลูปอัปเดตเลือดเพื่อนในปาร์ตี้ทุก 1 วินาที
task.spawn(function()
    while true do
        task.wait(1)
        for partyId, _ in pairs(Parties) do
            syncPartyData(partyId)
        end
    end
end)

return PartyManager

