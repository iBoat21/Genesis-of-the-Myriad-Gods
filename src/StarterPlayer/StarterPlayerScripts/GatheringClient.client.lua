local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NetworkEvents = require(ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("NetworkEvents"))

-- เมื่อกดปุ่มตามที่ ProximityPrompt กำหนด
ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
    local herbPart = prompt.Parent
    if herbPart and herbPart:GetAttribute("HerbName") then
        -- ทำให้สมุนไพรหายไปจากฝั่ง Client ทันทีเพื่อความลื่นไหล (Instant Feedback)
        local herbName = herbPart:GetAttribute("HerbName")
        herbPart.Transparency = 1
        herbPart.CanCollide = false
        if herbPart:FindFirstChild("ProximityPrompt") then
            herbPart.ProximityPrompt.Enabled = false
        end

        local success, message = NetworkEvents.GatherHerb:InvokeServer(herbPart)
        if success then
            print("เก็บสำเร็จ: " .. herbName)
        else
            -- ถ้าเซิร์ฟเวอร์บอกว่าเก็บไม่ได้ (เช่น โปร หรือผิดพลาด) ให้เอากลับคืนมา
            herbPart.Transparency = 0
            herbPart.CanCollide = true
            if herbPart:FindFirstChild("ProximityPrompt") then
                herbPart.ProximityPrompt.Enabled = true
            end
            print("เก็บไม่สำเร็จ: " .. (message or "Unknown error"))
        end
    end
end)

-- จัดการการอัปเดตกระเป๋า (UI)
NetworkEvents.UpdateInventory.OnClientEvent:Connect(function(inventory)
    -- ตรงนี้ในอนาคตจะเชื่อมกับ UI เพื่อแสดงจำนวนไอเทม
    print("--- กระเป๋าสัมภาระปัจจุบัน ---")
    for name, count in pairs(inventory) do
        print(name .. ": " .. count)
    end
end)
