--[[
    CombatManager.lua
    ระบบคำนวณและตรวจสอบความเสียหาย (Combat & Party-Friendly Logic)
    - ตรวจสอบโซน: ห้ามโจมตีในเมืองเริ่มต้น (Safe Zone) และแดนพฤกษาสวรรค์ (PvE Zone)
    - ตรวจสอบปาร์ตี้: ในแดน PvP ผู้เล่นที่อยู่ปาร์ตี้เดียวกัน (PartyId ตรงกัน) จะไม่ได้รับความเสียหาย
    - ตรวจสอบสถานะกลิ้งหลบ: หากผู้เล่นอยู่ในสถานะ IsDodging จะไม่ได้รับความเสียหาย (I-Frames)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage:WaitForChild("SharedModules"):WaitForChild("GameConfig"))

local CombatManager = {}

-- ตรวจสอบว่าผู้โจมตีสามารถสร้างความเสียหายแก่เป้าหมายได้หรือไม่
function CombatManager.CanDamage(attacker, victim)
    if not attacker or not victim then return false, "ข้อมูลไม่ครบถ้วน" end
    if attacker == victim then return false, "ไม่สามารถโจมตีตัวเองได้" end

    -- 1. ตรวจสอบสถานะอมตะหรือกลิ้งหลบของเป้าหมาย
    local victimChar = victim.Character
    if victimChar and victimChar:GetAttribute("IsDodging") then
        return false, "เป้าหมายกำลังม้วนตัวกลิ้งหลบ (I-Frames)"
    end
    if victim:GetAttribute("Invincible") then
        return false, "เป้าหมายอยู่ในสถานะกายาอมตะจักรพรรดิ์ (Invincible)"
    end

    -- 2. ตรวจสอบตำแหน่งโซนของเป้าหมาย
    local root = victimChar and victimChar:FindFirstChild("HumanoidRootPart")
    if not root then return false, "ไม่พบตำแหน่งเป้าหมาย" end
    local pos = root.Position

    local worldCoords = GameConfig.WorldCoordinates
    if worldCoords then
        -- อยู่ในหมู่บ้านเมฆาคราม (Safe Zone)
        local distFromCity = (pos - worldCoords.CityCenter).Magnitude
        if distFromCity <= 320 then
            return false, "เขตหมู่บ้านเมฆาคราม [Safe Zone] ห้ามประลองยุทธ์"
        end

        -- อยู่ในแดนพฤกษาสวรรค์ (PvE Zone)
        local pve = worldCoords.PvEZone
        if pve and (pos - pve.Center).Magnitude <= pve.Radius then
            return false, "แดนพฤกษาสวรรค์ [PvE Zone] ปลอดภัยจากการต่อสู้ระหว่างผู้เล่น"
        end
    end

    -- 3. ตรวจสอบปาร์ตี้เดียวกัน (Party Immunity)
    local partyA = attacker:GetAttribute("PartyId")
    local partyB = victim:GetAttribute("PartyId")
    if partyA and partyB and partyA == partyB then
        return false, "สหายร่วมปาร์ตี้ไม่สามารถทำร้ายกันได้"
    end

    return true, "สามารถโจมตีได้"
end

-- ประมวลผลความเสียหายอย่างปลอดภัย
function CombatManager.ApplyDamage(attacker, victim, damageAmount)
    local canDmg, reason = CombatManager.CanDamage(attacker, victim)
    if not canDmg then
        return false, reason
    end

    local char = victim.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum and hum.Health > 0 then
        -- โบนัสพลังโจมตีจากโอสถ/บัฟของผู้โจมตี (AttackPowerBonus)
        local atkBonus = attacker and (attacker:GetAttribute("AttackPowerBonus") or 0) or 0
        if atkBonus > 0 then
            damageAmount = damageAmount * (1 + (atkBonus / 100))
        end

        -- บัฟกายาวชิระ (VajraArmor) ลดความเสียหายทางกายภาพ 60%
        if victim:GetAttribute("VajraArmor") then
            damageAmount = damageAmount * 0.4
        end

        -- เช็คยันต์คุ้มภัย (Talisman Shield)
        local shield = char:GetAttribute("TalismanShield") or 0
        if shield > 0 then
            local absorbed = math.min(shield, damageAmount)
            shield = shield - absorbed
            damageAmount = damageAmount - absorbed
            char:SetAttribute("TalismanShield", (shield > 0) and shield or nil)
            print(string.format("🛡️ ยันต์คุ้มกายาดูดซับความเสียหาย %d หน่วย (เหลือเกราะ %d)", absorbed, shield))
        end

        if damageAmount > 0 then
            hum:TakeDamage(damageAmount)
        end
        return true, "สร้างความเสียหายสำเร็จ"
    end

    return false, "เป้าหมายหมดสติแล้ว"
end

_G.DaoistCombatManager = CombatManager

return CombatManager

