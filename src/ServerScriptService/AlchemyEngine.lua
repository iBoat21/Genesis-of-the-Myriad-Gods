--[[
    AlchemyEngine.lua
    สถาปัตยกรรมระบบสูตรยาพลวัต (Dynamic Pharmacopoeia Engine)
    - รองรับสารบบมหาตำราโอสถเก้าสวรรค์ 50 ขนานยามาตรฐาน (6 สำนักโอสถใหญ่)
    - ระบบ 5 หมวดหมู่สารออกฤทธิ์: ตัวยาหลัก (Monarch), ตัวยาเสริม (Minister), ตัวช่วยควบคุม (Assistant), ตัวนำทาง (Courier)
    - ระบบการหลอมพลาด & ยาผ่าเหล่า (Mutation System):
      * เตาหลอมระเบิด (Furnace Detonation) เมื่อธาตุข่มกันรุนแรงโดยไร้ตัวยาประสาน
      * โอสถกลายพันธุ์ (Mutated Pill) เมื่อธาตุตีกันจนเกิดผลลัพธ์ประหลาด
      * โอสถขยะกากเดน (Slag Pellet) เมื่อพลังงานต่ำหรือหักล้างหมด
      * โอสถผ่าเหล่าเฉพาะตัว (Custom Procedural Pill)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage:WaitForChild("SharedModules"):WaitForChild("GameConfig"))
local HerbDatabase = require(ReplicatedStorage:WaitForChild("SharedModules"):WaitForChild("HerbDatabase"))
local PillDatabase = require(ReplicatedStorage:WaitForChild("SharedModules"):WaitForChild("PillDatabase"))

local AlchemyEngine = {}

-- ปฏิกิริยาเสริมฤทธิ์และธาตุข่ม
local ElementSynergies = {
    ["Fire+Lightning"] = {Name = "พลาสมาเพลิงอัสนี", PotencyMult = 1.30, StabilityMod = -5},
    ["Water+Wood"]     = {Name = "หยาดพิรุณชุบชีวา", PotencyMult = 1.15, StabilityMod = 20},
    ["Earth+Holy"]     = {Name = "ศิลาศักดิ์สิทธิ์คุ้มกาย", PotencyMult = 1.20, StabilityMod = 25},
    ["Wind+Lightning"] = {Name = "วายุอัสนีบาตไร้เงา", PotencyMult = 1.25, StabilityMod = -10},
    ["Ice+Water"]      = {Name = "เหมันต์ธาราเยือกแข็ง", PotencyMult = 1.15, StabilityMod = 15},
    ["Holy+Wood"]      = {Name = "พฤกษาเทวะชุบวิญญาณ", PotencyMult = 1.25, StabilityMod = 30},
}

-- ค้นหาว่าส่วนผสมตรงกับ 50 ตำรับยามาตรฐานหรือไม่
local function matchStandardRecipe(elementalPool, totalPotency, usedHerbNames, dominantElement)
    local herbSet = {}
    for _, name in ipairs(usedHerbNames) do
        herbSet[name] = true
    end

    -- สแกนทั้ง 50 ขนานยาใน PillDatabase
    local bestMatch = nil
    local highestMatchScore = 0

    for _, recipe in ipairs(PillDatabase.GetAll()) do
        local matchScore = 0

        -- 1. ตรวจสอบชื่อสมุนไพรหลักที่แนะนำ (KeyIngredients)
        if recipe.KeyIngredients then
            for keyHerb, _ in pairs(herbSet) do
                if string.find(recipe.KeyIngredients, keyHerb) then
                    matchScore = matchScore + 40
                end
            end
        end

        -- 2. ตรวจสอบธาตุเด่นที่ตรงกัน
        if recipe.RequiredElement and recipe.RequiredElement == dominantElement then
            matchScore = matchScore + 35
        end

        -- 3. ตรวจสอบคะแนนพลังงานขั้นต่ำ
        if totalPotency >= (recipe.MinPotency or 20) then
            matchScore = matchScore + 25
        end

        if matchScore >= 65 and matchScore > highestMatchScore then
            highestMatchScore = matchScore
            bestMatch = recipe
        end
    end

    return bestMatch
end

-- ประมวลผลการปรุงยา (Brewing Pipeline)
function AlchemyEngine:ProcessBrew(ingredients, minigameScore)
    local elementalPool = {}
    local totalHerbs = 0
    local totalBasePotency = 0
    local baseStability = 100
    local usedHerbNames = {}
    local hasHarmonyAssistant = false

    -- [STAGE 1: AGGREGATION - รวบรวมเวกเตอร์คุณสมบัติสมุนไพรทั้งหมด]
    for herbName, count in pairs(ingredients) do
        count = math.floor(tonumber(count) or 0)
        if count > 0 then
            local herb = HerbDatabase.Get(herbName)
            if not herb and GameConfig.Herbs then
                local legacy = GameConfig.Herbs[herbName]
                if legacy then
                    herb = {
                        Name = herbName,
                        Element = "Wood",
                        Potency = legacy.Potency or 15,
                        Stability = 20,
                        Tier = 1,
                        TierName = "ร้อยปี",
                        Tags = {"Herb"}
                    }
                end
            end

            if herb then
                totalHerbs = totalHerbs + count
                totalBasePotency = totalBasePotency + (herb.Potency * count)
                baseStability = baseStability + ((herb.Stability or 15) * count)

                local elem = herb.Element or "Wood"
                elementalPool[elem] = (elementalPool[elem] or 0) + (herb.Potency * count)
                table.insert(usedHerbNames, herbName)

                -- ตรวจสอบตัวยาช่วยควบคุม (Assistant) ที่สมานธาตุข่ม
                if string.find(herbName, "หยินหยาง") or string.find(herbName, "ประสาน") or elem == "Holy" or herb.Stability > 30 then
                    hasHarmonyAssistant = true
                end
            end
        end
    end

    if totalHerbs <= 0 then
        return false, "เตาหลอมว่างเปล่า กรุณาเลือกใส่สมุนไพรในเตา"
    end

    -- [STAGE 2: CHEMICAL REACTIONS & CONFLICT - ตรวจสอบความขัดแย้งและโอกาสเตาระเบิด]
    local fire = elementalPool["Fire"] or 0
    local ice = (elementalPool["Ice"] or 0) + (elementalPool["Water"] or 0)

    -- กฎเตาระเบิด (Furnace Detonation): ไฟหมื่นปี + น้ำแข็งหมื่นปี โดยไร้ตัวยาประสานหยินหยาง
    if fire >= 80 and ice >= 80 and not hasHarmonyAssistant then
        return false, "💥 [เตาหลอมระเบิด!] ธาตุเพลิงสุริยันและเหมันต์ขั้วโลกหักล้างกันรุนแรงโดยไร้ตัวยาประสานหยินหยาง เตาหลอมระเบิดกระเด็น!", {
            Exploded = true,
            Damage = 50, -- ดาเมจ 50% ของเลือดสูงสุด
            Stability = 0
        }
    end

    -- ปฏิกิริยาการหักล้างทั่วไป (Cancellation)
    local clashPenalty = 0
    if fire > 0 and ice > 0 then
        local cancel = math.min(fire, ice)
        elementalPool["Fire"] = fire - cancel
        if elementalPool["Water"] then elementalPool["Water"] = math.max(0, elementalPool["Water"] - cancel) end
        if elementalPool["Ice"] then elementalPool["Ice"] = math.max(0, elementalPool["Ice"] - cancel) end
        clashPenalty = clashPenalty + (cancel * 0.4)
    end

    local voidVal = elementalPool["Void"] or 0
    local holyVal = (elementalPool["Holy"] or 0) + (elementalPool["Wood"] or 0)
    if voidVal > 0 and holyVal > 0 then
        local cancel = math.min(voidVal, holyVal)
        elementalPool["Void"] = voidVal - cancel
        if elementalPool["Holy"] then elementalPool["Holy"] = math.max(0, elementalPool["Holy"] - cancel) end
        if elementalPool["Wood"] then elementalPool["Wood"] = math.max(0, elementalPool["Wood"] - cancel) end
        clashPenalty = clashPenalty + (cancel * 0.5)
    end

    -- Synergy Bonus
    local synergyMult = 1.0
    for combo, syn in pairs(ElementSynergies) do
        local e1, e2 = string.match(combo, "(%a+)%+(%a+)")
        if (elementalPool[e1] or 0) > 0 and (elementalPool[e2] or 0) > 0 then
            synergyMult = synergyMult * syn.PotencyMult
            baseStability = baseStability + syn.StabilityMod
        end
    end

    -- [STAGE 3: DOMINANT ELEMENT EXTRACTION - สกัดธาตุเด่น]
    local sortedElements = {}
    for elem, val in pairs(elementalPool) do
        if val > 0 then
            table.insert(sortedElements, {Element = elem, Value = val})
        end
    end
    table.sort(sortedElements, function(a, b) return a.Value > b.Value end)

    local dominant = sortedElements[1] and sortedElements[1].Element or "Wood"
    local secondary = sortedElements[2] and sortedElements[2].Element or nil

    -- [STAGE 4: QUALITY EVALUATION & MINIGAME SCORE]
    minigameScore = math.clamp(tonumber(minigameScore) or 50, 0, 100)
    local minigameBonus = (minigameScore - 50) * 0.8
    local netStability = math.clamp(baseStability - clashPenalty + minigameBonus, 0, 200)

    local qualityTier
    if minigameScore >= 90 then
        qualityTier = {Name = "ระดับสมบูรณ์แบบ", Multiplier = 1.6, Color = Color3.fromRGB(255, 215, 0), ExtraBreakthrough = 0.15}
    elseif minigameScore >= 70 then
        qualityTier = {Name = "ระดับชั้นเลิศ", Multiplier = 1.3, Color = Color3.fromRGB(85, 170, 255), ExtraBreakthrough = 0.10}
    elseif minigameScore >= 45 then
        qualityTier = {Name = "ระดับปานกลาง", Multiplier = 1.0, Color = Color3.fromRGB(85, 255, 127), ExtraBreakthrough = 0.05}
    else
        qualityTier = {Name = "ระดับล่าง", Multiplier = 0.7, Color = Color3.fromRGB(160, 160, 160), ExtraBreakthrough = 0.0}
    end

    local finalPower = totalBasePotency * synergyMult * qualityTier.Multiplier

    -- [STAGE 5: RECIPE MATCHING OR MUTATION]
    local standardMatch = matchStandardRecipe(elementalPool, totalBasePotency, usedHerbNames, dominant)

    local pillData = {}

    if standardMatch then
        -- 🌟 ตรงกับ 50 ขนานยามาตรฐานในมหาตำราโอสถเก้าสวรรค์!
        pillData.Id = standardMatch.Id
        pillData.IsStandard = true
        pillData.BaseName = standardMatch.Name
        pillData.Name = string.format("%s (%s)", standardMatch.Name, qualityTier.Name)
        pillData.NameEN = standardMatch.NameEN
        pillData.School = standardMatch.School
        pillData.SchoolName = standardMatch.SchoolName
        pillData.Tier = standardMatch.Tier
        pillData.Quality = qualityTier.Name
        pillData.QualityColor = qualityTier.Color
        pillData.Description = standardMatch.Description
        pillData.Courier = standardMatch.Courier
        pillData.DominantElement = dominant
        pillData.Price = math.floor(standardMatch.Price * qualityTier.Multiplier)
        pillData.SellPrice = math.floor(standardMatch.SellPrice * qualityTier.Multiplier)
        pillData.TapasyaBonus = math.floor((standardMatch.BaseTapasya or 500) * qualityTier.Multiplier)
        pillData.BreakthroughBonus = math.clamp((standardMatch.BreakthroughBonus or 0.2) + qualityTier.ExtraBreakthrough, 0.1, 1.0)
        pillData.BuffEffect = standardMatch.BuffEffect
        pillData.BuffValue = standardMatch.BuffValue
        pillData.Duration = standardMatch.Duration
        pillData.Stability = netStability
        pillData.Color = standardMatch.Color or qualityTier.Color

        return true, string.format("🎉 หลอมสำเร็จตามสารบบตำรับยา: [%s] (สำนักที่ %d)", pillData.Name, pillData.School), pillData

    else
        -- 🌀 ไม่ตรงกับ 50 ตำรับมาตรฐาน -> คำนวณระบบยาผ่าเหล่า / ยาขยะ / ยาเฉพาะตัว
        if netStability < 20 and finalPower > 60 then
            -- ☠️ โอสถกลายพันธุ์ (Mutated Pill): ธาตุตีกันจนเกิดผลลัพธ์ประหลาด
            pillData.IsMutated = true
            pillData.BaseName = "โอสถกลายพันธุ์: วายุสูบวิญญาณ"
            pillData.Name = string.format("โอสถกลายพันธุ์: วายุสูบวิญญาณ (%s)", qualityTier.Name)
            pillData.Description = "ธาตุในเตาขัดแย้งกันอย่างรุนแรง กลายเป็นยาพิกลพิการ! กินแล้ววิ่งไวขึ้น 100% แต่วิญญาณฉีกขาด เลือดลดฮวบ 5 หน่วย/วินาที"
            pillData.Tier = 3
            pillData.Price = 800
            pillData.SellPrice = 400
            pillData.TapasyaBonus = math.floor(finalPower * 15)
            pillData.BreakthroughBonus = 0.15
            pillData.BuffEffect = "MutatedSpeedHurt"
            pillData.Duration = 60
            pillData.Quality = qualityTier.Name
            pillData.Color = Color3.fromRGB(200, 60, 180)
            pillData.Stability = netStability

            return true, "⚠️ เกิดการกลายพันธุ์ของธาตุ! ได้รับ [" .. pillData.Name .. "]", pillData

        elseif finalPower < 20 then
            -- 🗑️ โอสถขยะกากเดน (Slag Pellet): พลังงานต่ำเกินไปหรือหักล้างหมด
            pillData.IsSlag = true
            pillData.BaseName = "โอสถขยะกากเดน"
            pillData.Name = "โอสถขยะกากเดน (Slag Pellet)"
            pillData.Description = "กากเดนสมุนไพรไหม้เกรียม กลิ่นฉุนเหม็นไหม้ ไร้สรรพคุณทางยา กินแล้วท้องเสีย เอาไปปาหัวเล่นหรือขายราคาถูกได้"
            pillData.Tier = 1
            pillData.Price = 20
            pillData.SellPrice = 10
            pillData.TapasyaBonus = 10
            pillData.BreakthroughBonus = 0.01
            pillData.BuffEffect = "SlagDiarrhea"
            pillData.Quality = "ขยะกากเดน"
            pillData.Color = Color3.fromRGB(90, 85, 75)
            pillData.Stability = netStability

            return true, "🗑️ สมุนไพรไหม้เกรียม กลายเป็น [" .. pillData.Name .. "]", pillData

        else
            -- ✨ โอสถผ่าเหล่าเฉพาะตัว (Custom Procedural Pill)
            local elementTitles = {
                Fire = "อัคคีเพลิงผลาญ", Water = "วารีประสานจิต", Wood = "พฤกษาชีวิต",
                Earth = "ปฐพีทองคำ", Lightning = "อัสนีบาตสวรรค์", Wind = "วายุเร่งปราณ",
                Void = "สุญตาห้วงมิติ", Ice = "เหมันต์เยือกแข็ง", Holy = "มงคลเทวะจุติ"
            }
            local mainTitle = elementTitles[dominant] or "ลมปราณบริสุทธิ์"
            local subTitle = secondary and ("แห่ง" .. (elementTitles[secondary] or "")) or ""
            local customName = string.format("โอสถ%s%s (%s)", mainTitle, subTitle, qualityTier.Name)

            pillData.IsCustom = true
            pillData.BaseName = "โอสถ" .. mainTitle
            pillData.Name = customName
            pillData.Tier = math.clamp(math.floor(finalPower / 100) + 1, 1, 5)
            pillData.Quality = qualityTier.Name
            pillData.Price = math.floor(finalPower * 8)
            pillData.SellPrice = math.floor(finalPower * 4)
            pillData.Description = string.format("โอสถผ่าเหล่าจากการรังสรรค์อิสระ ธาตุเด่นคือ [%s] ให้พลังตบะและเสริมรากฐานการบำเพ็ญ", dominant)
            pillData.TapasyaBonus = math.floor(finalPower * 25)
            pillData.BreakthroughBonus = math.clamp(finalPower * 0.003, 0.10, 0.85)
            pillData.DominantElement = dominant
            pillData.Stability = netStability
            pillData.Color = qualityTier.Color

            return true, "✨ หลอมสำเร็จเป็นโอสถผ่าเหล่าเฉพาะตัว: [" .. pillData.Name .. "]", pillData
        end
    end
end

return AlchemyEngine
