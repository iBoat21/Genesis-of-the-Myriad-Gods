--[[
    WeatherTimeServer.server.lua
    ระบบเวลา 12 ยามแห่งเต๋า (Day/Night 12 Watches) และระบบสภาพอากาศผันแปร (Dynamic Weather)
    ส่งผลต่อการเก็บเกี่ยวสมุนไพรและบรรยากาศในโลกเซียน
]]

local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local TIME_PERIODS = {
    {Start = 23, End = 1,  Name = "ยามจื่อ (เที่ยงคืน - หยินสูงสุด)", IsNight = true},
    {Start = 1,  End = 3,  Name = "ยามโฉ่ว (ดึกสงัด)", IsNight = true},
    {Start = 3,  End = 5,  Name = "ยามอิ๋น (ก่อนรุ่งสาง)", IsNight = true},
    {Start = 5,  End = 7,  Name = "ยามเหม่า (รุ่งอรุณ แสงแรกของวัน)", IsNight = false},
    {Start = 7,  End = 9,  Name = "ยามเฉิน (ยามสาย ลมพัดเย็น)", IsNight = false},
    {Start = 9,  End = 11, Name = "ยามซื่อ (ยามสาย แดดอ่อน)", IsNight = false},
    {Start = 11, End = 13, Name = "ยามอู่ (เที่ยงวัน - หยางสูงสุด)", IsNight = false},
    {Start = 13, End = 15, Name = "ยามเว่ย (บ่ายคล้อย)", IsNight = false},
    {Start = 15, End = 17, Name = "ยามเซิน (บ่ายแก่ๆ)", IsNight = false},
    {Start = 17, End = 19, Name = "ยามอิ่ว (พลบค่ำ ตะวันตกดิน)", IsNight = false},
    {Start = 19, End = 21, Name = "ยามซวี (หัวค่ำ ลมสงบ)", IsNight = true},
    {Start = 21, End = 23, Name = "ยามห้าย (ดึก ไอเย็นลอยต่ำ)", IsNight = true},
}

local WEATHERS = {
    {
        Name = "ฟ้าโปร่ง แดดอบอุ่น",
        FogEnd = 800,
        FogColor = Color3.fromRGB(190, 210, 240),
        Ambient = Color3.fromRGB(120, 120, 120),
        OutdoorAmbient = Color3.fromRGB(140, 140, 140)
    },
    {
        Name = "หมอกวิญญาณหนาทึบ",
        FogEnd = 120,
        FogColor = Color3.fromRGB(160, 200, 210),
        Ambient = Color3.fromRGB(90, 100, 110),
        OutdoorAmbient = Color3.fromRGB(100, 120, 130)
    },
    {
        Name = "ฝนโปรยปรายชุ่มฉ่ำ",
        FogEnd = 250,
        FogColor = Color3.fromRGB(120, 140, 160),
        Ambient = Color3.fromRGB(80, 85, 95),
        OutdoorAmbient = Color3.fromRGB(90, 95, 105)
    },
    {
        Name = "พายุอัสนีบาตฟ้าคะนอง",
        FogEnd = 180,
        FogColor = Color3.fromRGB(70, 60, 90),
        Ambient = Color3.fromRGB(60, 50, 80),
        OutdoorAmbient = Color3.fromRGB(70, 60, 90)
    },
    {
        Name = "หิมะโปรยปรายเยือกเย็น",
        FogEnd = 200,
        FogColor = Color3.fromRGB(220, 230, 255),
        Ambient = Color3.fromRGB(130, 140, 160),
        OutdoorAmbient = Color3.fromRGB(150, 160, 180)
    }
}

local currentWeather = WEATHERS[1]

local function getTimePeriod(clockTime)
    for _, p in ipairs(TIME_PERIODS) do
        if p.Start > p.End then
            -- ข้ามเที่ยงคืน (23 - 1)
            if clockTime >= p.Start or clockTime < p.End then
                return p
            end
        else
            if clockTime >= p.Start and clockTime < p.End then
                return p
            end
        end
    end
    return TIME_PERIODS[7]
end

local function applyWeather(w)
    currentWeather = w
    Lighting.FogEnd = w.FogEnd
    Lighting.FogColor = w.FogColor
    Lighting.Ambient = w.Ambient
    Lighting.OutdoorAmbient = w.OutdoorAmbient

    Workspace:SetAttribute("CurrentWeather", w.Name)
    print("🌤️ [Weather] สภาพอากาศเปลี่ยนเป็น: " .. w.Name)
end

-- ลูปควบคุมเวลาและสภาพอากาศ
task.spawn(function()
    Lighting.ClockTime = 8.0 -- เริ่มต้นยามเช้า
    applyWeather(WEATHERS[1])

    local weatherTimer = 0
    while true do
        task.wait(1)
        -- เดินเวลาไปข้างหน้า (1 นาทีจริง = ประมาณ 2 ชั่วโมงในเกม)
        Lighting.ClockTime = (Lighting.ClockTime + 0.05) % 24

        local period = getTimePeriod(Lighting.ClockTime)
        Workspace:SetAttribute("CurrentTimePeriod", period.Name)
        Workspace:SetAttribute("ClockTime", Lighting.ClockTime)

        -- สุ่มเปลี่ยนสภาพอากาศทุกๆ 120 วินาที
        weatherTimer = weatherTimer + 1
        if weatherTimer >= 120 then
            weatherTimer = 0
            local newW = WEATHERS[math.random(1, #WEATHERS)]
            applyWeather(newW)
        end
    end
end)

print("✅ [Server] ระบบเวลาและสภาพอากาศ (Weather & Time System) พร้อมทำงาน!")

