--[[
    CultivationServer.server.lua
    เซิร์ฟเวอร์สคริปต์หลักสำหรับระบบตบะ, การฝึกตน AFK และการทะลวงขอบเขต
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local GameConfig = require(ReplicatedStorage:WaitForChild("SharedModules"):WaitForChild("GameConfig"))
local NetworkEvents = require(ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("NetworkEvents"))
local CultivationManager = require(ServerScriptService:WaitForChild("CultivationManager"))

-- ฟังก์ชันเมื่อผู้เล่นเข้าสู่เกม
local function onPlayerAdded(player)
    -- ติดตั้งค่าตบะและขอบเขตเบื้องต้น (หากยังไม่ได้เซ็ตจาก DataManager)
    CultivationManager:SetupPlayer(player, 0, 1)

    -- ลูป AFK นั่งสมาธิเพิ่มตบะอัตโนมัติตามสเตตัสขอบเขต (TapasyaRegen)
    -- และฟื้นฟูปราณ (ChiRegen) ทุกๆ 1 วินาที
    task.spawn(function()
        while player and player.Parent do
            task.wait(GameConfig.AfkInterval or 1)
            -- หากไม่มีการปิด AFK ไว้โดยคำสั่ง Admin
            if not player:GetAttribute("AfkDisabled") then
                local tapasyaGain = player:GetAttribute("TapasyaRegen") or 10
                CultivationManager:AddTapasya(player, tapasyaGain)

                -- ฟื้นฟูพลังปราณ (Chi Regeneration)
                local maxChi = player:GetAttribute("MaxChi") or 50
                local chiRegen = player:GetAttribute("ChiRegen") or 2
                local currentChi = player:GetAttribute("Chi") or maxChi
                if currentChi < maxChi then
                    local newChi = math.min(maxChi, currentChi + chiRegen)
                    player:SetAttribute("Chi", newChi)
                    if player.Character then
                        player.Character:SetAttribute("Chi", newChi)
                    end
                end
            end
        end
    end)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
    task.spawn(onPlayerAdded, player)
end

-- รับคำขอ "ทะลวงขอบเขต" จาก Client
NetworkEvents.Breakthrough.OnServerInvoke = function(player)
    return CultivationManager:AttemptBreakthrough(player)
end

print("✅ [Server] ระบบตบะและการทะลวงขอบเขต (Realm Breakthrough) พร้อมทำงานแล้ว!")
