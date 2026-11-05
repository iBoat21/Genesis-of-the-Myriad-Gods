--[[
    MerchantServer.server.lua
    ระบบร้านค้า NPC: ผู้อาวุโสชิง (หอโอสถเทวะ) และ ปรมาจารย์เถี่ย (หอศัสตราวุธเซียน)
    - รองรับการซื้อวัตถุดิบสมุนไพร, อุปกรณ์เซียน (เคียวตัดสมุนไพร, ยันต์คุ้มกายา, กระเป๋ามิติ)
    - รองรับการขายเม็ดยาโอสถที่ผู้เล่นหลอมขึ้น เพื่อแลกเป็นแต้มตบะ/ศิลาวิญญาณ
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local GameConfig = require(ReplicatedStorage:WaitForChild("SharedModules"):WaitForChild("GameConfig"))
local HerbDatabase = require(ReplicatedStorage:WaitForChild("SharedModules"):WaitForChild("HerbDatabase"))
local NetworkEvents = require(ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("NetworkEvents"))
local CultivationManager = require(ServerScriptService:WaitForChild("CultivationManager"))

-- ฟังก์ชันซื้อสินค้าจากร้านค้า
NetworkEvents.BuyShopItem.OnServerInvoke = function(player, merchantId, itemName)
    local merchantConfig = GameConfig.ShopConfig and GameConfig.ShopConfig[merchantId]
    if not merchantConfig then return false, "ไม่พบร้านค้านี้" end

    local targetItem = nil
    for _, item in ipairs(merchantConfig.Items) do
        if item.Name == itemName then
            targetItem = item
            break
        end
    end
    if not targetItem then return false, "ไม่พบสินค้ารายการนี้ในร้านค้า" end

    -- ตรวจสอบแต้มตบะ
    local currentTapasya = CultivationManager:GetPlayerTapasya(player)
    if currentTapasya < targetItem.Price then
        return false, string.format("แต้มตบะไม่เพียงพอ (ต้องการ %d แต้ม, คุณมี %d แต้ม)", targetItem.Price, currentTapasya)
    end

    -- หักแต้มตบะ
    CultivationManager:AddTapasya(player, -targetItem.Price)

    -- เพิ่มไอเทมเข้ากระเป๋า
    if _G.DaoistDataManager then
        _G.DaoistDataManager.AddHerb(player, targetItem.Name, 1)

        -- หากซื้อยันต์คุ้มกายา ให้เปิดใช้งานเกราะป้องกันทันที
        if targetItem.Type == "Talisman" then
            local char = player.Character
            if char then
                char:SetAttribute("TalismanShield", 500)
            end
        end
    end

    return true, string.format("ซื้อ '%s' สำเร็จ! (หัก %d ตบะ)", targetItem.Name, targetItem.Price)
end

-- ฟังก์ชันขายเม็ดยาโอสถ
NetworkEvents.SellPillItem.OnServerInvoke = function(player, pillName)
    if not _G.DaoistDataManager then return false, "ระบบข้อมูลไม่พร้อมทำงาน" end

    local inventory = _G.DaoistDataManager.GetInventory(player)
    local currentCount = inventory[pillName] or 0
    if currentCount <= 0 then
        return false, "คุณไม่มีเม็ดยานี้ในกระเป๋า"
    end

    -- ประเมินราคาขายของเม็ดยาตามคุณภาพและชื่อ
    local sellPrice = 120
    if string.find(pillName, "สมบูรณ์แบบ") or string.find(pillName, "ระดับเทพ") then
        sellPrice = 650
    elseif string.find(pillName, "ชั้นเลิศ") then
        sellPrice = 380
    elseif string.find(pillName, "เกื้อหนุน") or string.find(pillName, "มหา") then
        sellPrice = 240
    end

    -- หักเม็ดยาออกจากกระเป๋า 1 ชิ้น
    _G.DaoistDataManager.AddHerb(player, pillName, -1)

    -- มอบแต้มตบะตอบแทน
    CultivationManager:AddTapasya(player, sellPrice)

    return true, string.format("ขาย '%s' ให้หอโอสถเทวะ ได้รับ %+d แต้มตบะ!", pillName, sellPrice)
end

print("✅ [Server] ระบบร้านค้า NPC ผู้อาวุโสชิง & ปรมาจารย์เถี่ย พร้อมทำงาน!")

