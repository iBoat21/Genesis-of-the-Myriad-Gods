--[[
    AdminServer.server.lua
    จัดการระบบสิทธิ์ Admin & Tester, ตรวจสอบคำสั่ง และประมวลผลคำสั่ง Terminal
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")

local GameConfig = require(ReplicatedStorage:WaitForChild("SharedModules"):WaitForChild("GameConfig"))
local HerbDatabase = require(ReplicatedStorage:WaitForChild("SharedModules"):WaitForChild("HerbDatabase"))
local PillDatabase = require(ReplicatedStorage:WaitForChild("SharedModules"):WaitForChild("PillDatabase"))
local NetworkEvents = require(ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("NetworkEvents"))
local CultivationManager = require(ServerScriptService:WaitForChild("CultivationManager"))
local AlchemyManager = require(ServerScriptService:WaitForChild("AlchemyManager"))

-- ตารางสิทธิ์ชั่วคราวขณะเซิร์ฟเวอร์รัน
local ActiveTesters = {}
local ActiveAdmins = {}

-- ตรวจสอบสิทธิ์ของผู้เล่น
local function getPlayerRole(player)
    if RunService:IsStudio() then
        return "SuperAdmin" -- ใน Roblox Studio ได้สิทธิ์สูงสุดเสมอเพื่อความสะดวกในการทดสอบ
    end
    if game.CreatorId ~= 0 and player.UserId == game.CreatorId then
        return "SuperAdmin"
    end
    if GameConfig.SuperAdmins[player.UserId] or GameConfig.SuperAdmins[player.Name] then
        return "SuperAdmin"
    end
    if ActiveAdmins[player.UserId] then
        return "Admin"
    end
    if ActiveTesters[player.UserId] then
        return "Tester"
    end
    return nil
end

local function hasPermission(player)
    return getPlayerRole(player) ~= nil
end

-- ฟังก์ชันค้นหาผู้เล่นจากชื่อ หรือ UserId
local function findPlayer(query, sender)
    if not query or query == "" or query:lower() == "me" then
        return sender
    end

    local queryLower = query:lower()
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Name:lower() == queryLower or p.DisplayName:lower() == queryLower then
            return p
        end
    end

    -- ค้นหาแบบบางส่วน (Prefix Match)
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Name:lower():sub(1, #queryLower) == queryLower or p.DisplayName:lower():sub(1, #queryLower) == queryLower then
            return p
        end
    end

    return nil
end

-- แปลงข้อความคำสั่งเป็น Arguments โดยรองรับเครื่องหมายคำพูด "..." หรือ '...'
local function parseArguments(str)
    local args = {}
    local i = 1
    local len = string.len(str)

    while i <= len do
        -- ข้ามช่องว่าง (Whitespace)
        while i <= len and string.match(string.sub(str, i, i), "%s") do
            i = i + 1
        end
        if i > len then break end

        local char = string.sub(str, i, i)
        if char == '"' or char == "'" then
            local quote = char
            i = i + 1
            local startIdx = i
            while i <= len and string.sub(str, i, i) ~= quote do
                i = i + 1
            end
            table.insert(args, string.sub(str, startIdx, i - 1))
            i = i + 1 -- ข้ามตัวปิด Quote
        else
            local startIdx = i
            while i <= len and not string.match(string.sub(str, i, i), "%s") do
                i = i + 1
            end
            table.insert(args, string.sub(str, startIdx, i - 1))
        end
    end

    return args
end

-- ส่งข้อมูลสิทธิ์เมื่อ Client สอบถาม
NetworkEvents.CheckAdminAccess.OnServerInvoke = function(player)
    local role = getPlayerRole(player)
    return (role ~= nil), role
end

-- ประมวลผลคำสั่งจาก Terminal
NetworkEvents.AdminCommand.OnServerInvoke = function(player, commandString)
    local role = getPlayerRole(player)
    if not role then
        return false, "⛔ [ACCESS DENIED] คุณไม่มีสิทธิ์ใช้งานคำสั่ง Admin หรือ Tester"
    end

    if not commandString or string.match(commandString, "^%s*$") then
        return false, "กรุณากรอกคำสั่ง (พิมพ์ 'help' เพื่อดูคำสั่งทั้งหมด)"
    end

    local args = parseArguments(commandString)
    local cmd = string.lower(table.remove(args, 1) or "")

    ----------------------------------------------------------------------
    -- 1. หมวดหมู่ช่วยเหลือและข้อมูล
    ----------------------------------------------------------------------
    if cmd == "help" then
        local helpText = [[
=== [DAOIST BOUNDLESS TERMINAL COMMANDS] ===
[ระบบตบะ & ขอบเขต]
- addtapasya <amount> [player]      : เพิ่มแต้มตบะ
- settapasya <amount> [player]      : กำหนดแต้มตบะ
- setrealm <index/name> [player]    : เปลี่ยนขอบเขต (1=คนธรรมดา, 2=หลอมลมปราณ, ฯลฯ)
- breakthrough [player]             : บังคับทะลวงขอบเขตทันที
- resettapasya [player]             : รีเซ็ตตบะเป็น 0
- afk <on/off> [player]             : เปิด/ปิดการเพิ่มตบะ AFK

[ระบบสมุนไพร, โอสถ & การปรุงยา]
- giveherb "<ชื่อ>" [จำนวน] [player] : เสกสมุนไพรเข้ากระเป๋า
- giveallherbs [จำนวน] [player]     : เสกสมุนไพรทุกชนิดเข้ากระเป๋า
- spawnherb [ชื่อ] [จำนวน]           : สปอนสมุนไพรใกล้ตัวในแมพ
- givepill "<ชื่อยา>" [จำนวน] [player] : เสกเม็ดยาโอสถเข้ากระเป๋า
- giveallpills [จำนวน] [player]     : เสกโอสถทุกตำรับเข้ากระเป๋า
- usepill "<ชื่อยา>" [player]        : บังคับกินโอสถทันที
- setbuff <percent> [player]        : กำหนดบัฟโอกาสทะลวง (เช่น setbuff 50)
- clearinv [player]                 : ล้างของในกระเป๋า

[ระบบตัวละคร & สเตตัส]
- heal [player]                     : ฟื้นฟูเลือดเต็ม
- speed <จำนวน> [player]            : ปรับความเร็วเดิน (ปกติ 16)
- sethp <จำนวน> [player]            : ปรับ MaxHP และ Health
- info [player]                     : ดูข้อมูลและสเตตัสตัวละคร

[การจัดการสิทธิ์ Tester (Admin Only)]
- grant <player>                    : มอบสิทธิ์ Tester ให้ผู้เล่น
- revoke <player>                   : ถอนสิทธิ์ Tester ของผู้เล่น
- testers                           : ดูรายชื่อ Admin และ Tester ทั้งหมด
]]
        return true, helpText

    elseif cmd == "info" then
        local target = findPlayer(args[1], player)
        if not target then return false, "❌ ไม่พบผู้เล่น: " .. tostring(args[1]) end
        
        local realmIndex = CultivationManager:GetPlayerRealmIndex(target)
        local realmData = GameConfig.Realms[realmIndex] or GameConfig.Realms[1]
        local tapasya = CultivationManager:GetPlayerTapasya(target)
        local title = target:GetAttribute("Title") or realmData.Title

        local char = target.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local hp = hum and string.format("%.0f/%.0f", hum.Health, hum.MaxHealth) or "N/A"
        local speed = hum and tostring(hum.WalkSpeed) or "N/A"

        local invStr = ""
        if _G.DaoistDataManager then
            local inv = _G.DaoistDataManager.GetInventory(target)
            for k, v in pairs(inv) do
                invStr = invStr .. string.format("\n   - %s: x%d", k, v)
            end
        end
        if invStr == "" then invStr = " (ว่างเปล่า)" end

        local infoText = string.format([[
[ข้อมูลผู้เล่น: %s (@%s)]
- ขอบเขต: %s (ขั้นที่ %d)
- ฉายา: %s
- ค่าตบะ: %d แต้ม
- พลังชีวิต: %s | ความเร็ว: %s
- พลังโจมตี: %s | พลังป้องกัน: %s
- สัมภาระในกระเป๋า:%s
]], target.DisplayName, target.Name, realmData.Name, realmIndex, title, tapasya, hp, speed,
    tostring(target:GetAttribute("AttackPower") or realmData.Stats.AttackPower),
    tostring(target:GetAttribute("Defense") or realmData.Stats.Defense),
    invStr)
        return true, infoText

    ----------------------------------------------------------------------
    -- 2. หมวดหมู่จัดการสิทธิ์ (Admin / SuperAdmin Only)
    ----------------------------------------------------------------------
    elseif cmd == "grant" or cmd == "addtester" then
        if role ~= "SuperAdmin" and role ~= "Admin" then
            return false, "⛔ เฉพาะ Admin เท่านั้นที่สามารถมอบสิทธิ์ Tester ได้"
        end
        local target = findPlayer(args[1], nil)
        if not target then return false, "❌ ระบุชื่อผู้เล่น เช่น: grant " .. player.Name end

        ActiveTesters[target.UserId] = true
        NetworkEvents.AdminStatusChanged:FireClient(target, true, "Tester")
        return true, string.format("🎉 มอบสิทธิ์ Tester ให้แก่ %s (@%s) เรียบร้อยแล้ว!", target.DisplayName, target.Name)

    elseif cmd == "revoke" or cmd == "removetester" then
        if role ~= "SuperAdmin" and role ~= "Admin" then
            return false, "⛔ เฉพาะ Admin เท่านั้นที่สามารถถอนสิทธิ์ได้"
        end
        local target = findPlayer(args[1], nil)
        if not target then return false, "❌ ไม่พบผู้เล่นที่จะถอนสิทธิ์" end

        ActiveTesters[target.UserId] = nil
        ActiveAdmins[target.UserId] = nil
        NetworkEvents.AdminStatusChanged:FireClient(target, false, nil)
        return true, string.format("🗑️ ถอนสิทธิ์ Tester ของ %s (@%s) สำเร็จ", target.DisplayName, target.Name)

    elseif cmd == "testers" then
        local list = "=== [รายชื่อ ADMIN & TESTER ปัจจุบัน] ==="
        for _, p in ipairs(Players:GetPlayers()) do
            local pRole = getPlayerRole(p)
            if pRole then
                list = list .. string.format("\n- %s (@%s) | บทบาท: [%s]", p.DisplayName, p.Name, pRole)
            end
        end
        return true, list

    ----------------------------------------------------------------------
    -- 3. หมวดหมู่ระบบตบะ & ขอบเขต
    ----------------------------------------------------------------------
    elseif cmd == "addtapasya" then
        local amount = tonumber(args[1])
        if not amount then return false, "❌ กรุณาระบุจำนวน เช่น: addtapasya 1000" end
        local target = findPlayer(args[2], player)
        if not target then return false, "❌ ไม่พบผู้เล่น" end

        CultivationManager:AddTapasya(target, amount)
        return true, string.format("✅ เพิ่มตบะให้ %s จำนวน %+d แต้ม (ตบะปัจจุบัน: %d)", 
            target.DisplayName, amount, CultivationManager:GetPlayerTapasya(target))

    elseif cmd == "settapasya" then
        local amount = tonumber(args[1])
        if not amount then return false, "❌ กรุณาระบุจำนวน เช่น: settapasya 5000" end
        local target = findPlayer(args[2], player)
        if not target then return false, "❌ ไม่พบผู้เล่น" end

        CultivationManager:SetTapasya(target, amount)
        return true, string.format("✅ ตั้งค่าตบะของ %s เป็น %d แต้ม", target.DisplayName, amount)

    elseif cmd == "resettapasya" then
        local target = findPlayer(args[1], player)
        if not target then return false, "❌ ไม่พบผู้เล่น" end
        CultivationManager:SetTapasya(target, 0)
        return true, string.format("🔄 รีเซ็ตค่าตบะของ %s เป็น 0 แต้มแล้ว", target.DisplayName)

    elseif cmd == "setrealm" then
        local realmArg = args[1]
        if not realmArg then return false, "❌ กรุณาระบุชื่อหรือเลขขอบเขต เช่น: setrealm 2 หรือ setrealm หลอมลมปราณ" end
        local target = findPlayer(args[2], player)
        if not target then return false, "❌ ไม่พบผู้เล่น" end

        local realmNum = tonumber(realmArg)
        local success, msg = CultivationManager:SetRealm(target, realmNum or realmArg)
        return success, (success and "✅ " or "❌ ") .. tostring(msg)

    elseif cmd == "breakthrough" then
        local target = findPlayer(args[1], player)
        if not target then return false, "❌ ไม่พบผู้เล่น" end

        local success, msg = CultivationManager:ForceBreakthrough(target)
        return success, (success and "⚡ " or "❌ ") .. tostring(msg)

    elseif cmd == "afk" then
        local switch = args[1] and args[1]:lower()
        local target = findPlayer(args[2], player)
        if not target then return false, "❌ ไม่พบผู้เล่น" end

        if switch == "off" or switch == "false" or switch == "0" then
            target:SetAttribute("AfkDisabled", true)
            return true, "⏸️ ปิดระบบ AFK ตบะของ " .. target.DisplayName
        else
            target:SetAttribute("AfkDisabled", nil)
            return true, "▶️ เปิดระบบ AFK ตบะของ " .. target.DisplayName
        end

    ----------------------------------------------------------------------
    -- 4. หมวดหมู่สมุนไพรและไอเทม
    ----------------------------------------------------------------------
    elseif cmd == "giveherb" then
        local herbName = args[1]
        local count = tonumber(args[2]) or 1
        local target = findPlayer(args[3], player)
        if not target then return false, "❌ ไม่พบผู้เล่น" end

        local herbData = HerbDatabase and HerbDatabase.Get(herbName)
        if not herbData and GameConfig.Herbs and GameConfig.Herbs[herbName] then
            herbData = GameConfig.Herbs[herbName]
        end

        -- หากไม่พบตรงตัว ให้ลองค้นหาแบบคำใกล้เคียง
        if not herbData and HerbDatabase then
            for _, h in ipairs(HerbDatabase.GetAll()) do
                if string.find(h.Name, herbName or "") then
                    herbName = h.Name
                    herbData = h
                    break
                end
            end
        end

        if not herbData then
            return false, "❌ ไม่พบสมุนไพรชื่อ: " .. tostring(herbName) .. " (เปิดสารานุกรมกด J เพื่อดูชื่อ)"
        end

        if _G.DaoistDataManager then
            _G.DaoistDataManager.AddHerb(target, herbName, count)
            return true, string.format("🌿 เพิ่ม '%s' x%d เข้ากระเป๋าของ %s สำเร็จ!", herbName, count, target.DisplayName)
        else
            return false, "❌ DataManager ยังไม่พร้อมทำงาน"
        end

    elseif cmd == "giveallherbs" then
        local count = tonumber(args[1]) or 5
        local target = findPlayer(args[2], player)
        if not target then return false, "❌ ไม่พบผู้เล่น" end

        if _G.DaoistDataManager then
            local totalTypes = 0
            if HerbDatabase then
                for _, herb in ipairs(HerbDatabase.GetAll()) do
                    _G.DaoistDataManager.AddHerb(target, herb.Name, count)
                    totalTypes = totalTypes + 1
                end
            end
            if GameConfig.Herbs then
                for name, _ in pairs(GameConfig.Herbs) do
                    if not HerbDatabase or not HerbDatabase.Get(name) then
                        _G.DaoistDataManager.AddHerb(target, name, count)
                        totalTypes = totalTypes + 1
                    end
                end
            end
            return true, string.format("🌱 เสกสมุนไพรครบทั้ง %d ชนิด ชนิดละ %d ชิ้นให้ %s เรียบร้อย!", totalTypes, count, target.DisplayName)
        end
        return false, "❌ DataManager ยังไม่พร้อมทำงาน"

    elseif cmd == "spawnherb" then
        local herbName = args[1]
        local count = tonumber(args[2]) or 1
        local isValid = false
        if herbName then
            if tonumber(herbName) then
                count = tonumber(herbName)
                herbName = nil
                isValid = true
            elseif (HerbDatabase and HerbDatabase.Get(herbName)) or (GameConfig.Herbs and GameConfig.Herbs[herbName]) then
                isValid = true
            end
        else
            isValid = true
        end

        if not isValid then
            return false, "❌ ไม่พบสมุนไพรชื่อ: " .. tostring(herbName)
        end

        local char = player.Character
        local rootPart = char and char:FindFirstChild("HumanoidRootPart")
        local basePos = rootPart and rootPart.Position or Vector3.new(0, 5, 0)

        if _G.DaoistHerbSpawner then
            for i = 1, count do
                _G.DaoistHerbSpawner.SpawnHerb(herbName, basePos)
            end
            return true, string.format("✨ สปอนสมุนไพร %d ต้น ใกล้ตัวเรียบร้อย!", count)
        end
        return false, "❌ HerbSpawner ยังไม่พร้อมทำงาน"

    elseif cmd == "givepill" then
        local pillName = args[1]
        local count = tonumber(args[2]) or 1
        local target = findPlayer(args[3], player)
        if not target then return false, "❌ ไม่พบผู้เล่น" end

        local pillData = PillDatabase.Get(pillName) or (GameConfig.Pills and GameConfig.Pills[pillName])
        if not pillData then
            return false, "❌ ไม่พบโอสถชื่อ: " .. tostring(pillName)
        end

        if _G.DaoistDataManager then
            _G.DaoistDataManager.AddHerb(target, pillName, count)
            return true, string.format("💊 เพิ่มโอสถ '%s' x%d เข้ากระเป๋าของ %s สำเร็จ!", pillName, count, target.DisplayName)
        end
        return false, "❌ DataManager ยังไม่พร้อมทำงาน"

    elseif cmd == "giveallpills" then
        local count = tonumber(args[1]) or 5
        local target = findPlayer(args[2], player)
        if not target then return false, "❌ ไม่พบผู้เล่น" end

        if _G.DaoistDataManager then
            local totalTypes = 0
            for name, _ in pairs(PillDatabase.List) do
                _G.DaoistDataManager.AddHerb(target, name, count)
                totalTypes = totalTypes + 1
            end
            if GameConfig.Pills then
                for name, _ in pairs(GameConfig.Pills) do
                    if not PillDatabase.Get(name) then
                        _G.DaoistDataManager.AddHerb(target, name, count)
                        totalTypes = totalTypes + 1
                    end
                end
            end
            return true, string.format("💊 เสกโอสถทั้ง %d ตำรับ ชนิดละ %d เม็ดให้ %s เรียบร้อย!", totalTypes, count, target.DisplayName)
        end
        return false, "❌ DataManager ยังไม่พร้อมทำงาน"

    elseif cmd == "usepill" then
        local pillName = args[1]
        local target = findPlayer(args[2], player)
        if not target then return false, "❌ ไม่พบผู้เล่น" end

        local success, msg = AlchemyManager:UsePill(target, pillName)
        return success, (success and "✅ " or "❌ ") .. tostring(msg)

    elseif cmd == "setbuff" then
        local percent = tonumber(args[1])
        if not percent then return false, "❌ ระบุเปอร์เซ็นต์ เช่น: setbuff 50 หรือ setbuff 100" end
        local target = findPlayer(args[2], player)
        if not target then return false, "❌ ไม่พบผู้เล่น" end

        local buffVal = math.clamp(percent / 100, 0, 1)
        target:SetAttribute("BreakthroughBuff", buffVal)
        CultivationManager:SyncToClient(target)
        return true, string.format("⚡ กำหนดบัฟโอกาสทะลวงของ %s เป็น +%.0f%% (รวมอัตราทะลวงจะเพิ่มขึ้นทันที)", target.DisplayName, percent)

    elseif cmd == "clearinv" then
        local target = findPlayer(args[1], player)
        if not target then return false, "❌ ไม่พบผู้เล่น" end

        if _G.DaoistDataManager then
            _G.DaoistDataManager.ClearInventory(target)
            return true, "🗑️ ล้างกระเป๋าของ " .. target.DisplayName .. " เรียบร้อย"
        end
        return false, "❌ DataManager ไม่พร้อมทำงาน"

    ----------------------------------------------------------------------
    -- 5. หมวดหมู่ตัวละครและสเตตัส
    ----------------------------------------------------------------------
    elseif cmd == "heal" then
        local target = findPlayer(args[1], player)
        if not target or not target.Character then return false, "❌ ไม่พบตัวละคร" end
        local hum = target.Character:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.Health = hum.MaxHealth
            local maxChi = target:GetAttribute("MaxChi") or 50
            target:SetAttribute("Chi", maxChi)
            if target.Character then target.Character:SetAttribute("Chi", maxChi) end
            return true, "💖 ฟื้นฟูเลือดและลมปราณของ " .. target.DisplayName .. " เต็มเปี่ยม"
        end
        return false, "❌ ไม่พบ Humanoid"

    elseif cmd == "setchi" then
        local chi = tonumber(args[1])
        if not chi then return false, "❌ ระบุจำนวนปราณ เช่น: setchi 500" end
        local target = findPlayer(args[2], player)
        if not target then return false, "❌ ไม่พบผู้เล่น" end

        target:SetAttribute("Chi", chi)
        if target.Character then target.Character:SetAttribute("Chi", chi) end
        CultivationManager:SyncToClient(target)
        return true, string.format("🌀 กำหนดพลังปราณ (Chi) ของ %s เป็น %d", target.DisplayName, chi)

    elseif cmd == "tpzone" then
        local zoneArg = args[1]
        local target = findPlayer(args[2], player)
        if not target or not target.Character then return false, "❌ ไม่พบตัวละคร" end
        local root = target.Character:FindFirstChild("HumanoidRootPart")
        if not root then return false, "❌ ไม่พบ HumanoidRootPart" end

        local targetPos
        local zLow = tostring(zoneArg or ""):lower()
        local worldCoords = GameConfig.WorldCoordinates

        if zLow == "city" or zLow == "spawn" or zLow == "เมือง" then
            targetPos = worldCoords and worldCoords.CitySpawn or Vector3.new(0, 105, 0)
        elseif zLow == "pve" or string.find(zLow, "mist") or string.find(zLow, "พฤกษา") then
            targetPos = worldCoords and worldCoords.PvEZone.Spawn or Vector3.new(1500, 55, -230)
        elseif zLow == "pvp" or string.find(zLow, "asura") or string.find(zLow, "อสูร") then
            targetPos = worldCoords and worldCoords.PvPZone.Spawn or Vector3.new(-1500, 55, -230)
        elseif tonumber(zoneArg) then
            local z = GameConfig.Zones and GameConfig.Zones[tonumber(zoneArg)]
            if z then targetPos = z.Position end
        elseif GameConfig.Zones then
            for _, z in ipairs(GameConfig.Zones) do
                if string.find(z.Name, tostring(zoneArg or "")) then
                    targetPos = z.Position
                    break
                end
            end
        end

        if targetPos then
            root.CFrame = CFrame.new(targetPos + Vector3.new(0, 3, 0))
            return true, "🚀 วาร์ป " .. target.DisplayName .. " ไปยังพิกัดเรียบร้อย (" .. tostring(zoneArg) .. ")"
        end
        return false, "❌ ไม่พบโซนที่ระบุ (ตัวเลือก: city, pve, pvp, หรือ 1, 2)"

    elseif cmd == "speed" then
        local speed = tonumber(args[1])
        if not speed then return false, "❌ ระบุความเร็ว เช่น: speed 32" end
        local target = findPlayer(args[2], player)
        if not target or not target.Character then return false, "❌ ไม่พบตัวละคร" end
        local hum = target.Character:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.WalkSpeed = speed
            return true, string.format("⚡ ปรับความเร็วเดินของ %s เป็น %d", target.DisplayName, speed)
        end
        return false, "❌ ไม่พบ Humanoid"

    elseif cmd == "sethp" then
        local hp = tonumber(args[1])
        if not hp then return false, "❌ ระบุพลังชีวิต เช่น: sethp 1000" end
        local target = findPlayer(args[2], player)
        if not target or not target.Character then return false, "❌ ไม่พบตัวละคร" end
        local hum = target.Character:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.MaxHealth = hp
            hum.Health = hp
            return true, string.format("🛡️ ปรับเลือดของ %s เป็น %d/%d", target.DisplayName, hp, hp)
        end
        return false, "❌ ไม่พบ Humanoid"

    else
        return false, "❓ ไม่รู้จักคำสั่ง '" .. cmd .. "' (พิมพ์ 'help' เพื่อดูคำสั่งทั้งหมด)"
    end
end

-- เมื่อมีผู้เล่นเข้ามา ตรวจสอบว่ามีสิทธิ์ Admin หรือไม่ และแจ้งเตือน
Players.PlayerAdded:Connect(function(player)
    local role = getPlayerRole(player)
    if role then
        print(string.format("🔑 [Admin System] ผู้เล่น %s (@%s) เข้าเกมด้วยสิทธิ์ [%s]", player.DisplayName, player.Name, role))
        task.delay(1.5, function()
            if player and player.Parent then
                NetworkEvents.AdminStatusChanged:FireClient(player, true, role)
            end
        end)
    end
end)

print("✅ [Server] ระบบ Admin & Tester Terminal พร้อมทำงาน!")

