local GameConfig = {}

-- รายการขอบเขตพลังและสเตตัสประจำแต่ละขั้น
GameConfig.Realms = {
    {
        Name = "คนธรรมดา",
        Title = "มนุษย์ปุถุชน",
        RequiredExp = 0,
        BaseBreakthroughRate = 1.0, -- ขั้นเริ่มต้นไม่ต้องทะลวง
        Color = Color3.fromRGB(180, 180, 180),
        Stats = {
            MaxHealth = 100,
            MaxChi = 50,           -- พลังปราณสูงสุด (Chi/Mana)
            ChiRegen = 2,          -- อัตราฟื้นฟูปราณต่อวินาที
            TapasyaRegen = 10,     -- อัตราดูดซับตบะต่อวินาที (Passive Absorption)
            WalkSpeed = 16,
            AttackPower = 10,
            Defense = 0,
        },
        UnlockedZone = "หมู่บ้านปุถุชน (Mortal Village)",
        ZoneLevel = 1,
        Description = "ปุถุชนคนธรรมดา ร่างกายบอบบาง ยังมิได้เริ่มฝึกปรือเคล็ดวิชาลมปราณ"
    },
    {
        Name = "หลอมลมปราณ",
        Title = "ผู้ฝึกหลอมลมปราณ",
        RequiredExp = 1000,
        BaseBreakthroughRate = 0.70, -- อัตราสำเร็จพื้นฐาน 70% (ใช้ยาช่วยให้ถึง 100%)
        Color = Color3.fromRGB(85, 255, 127),
        Stats = {
            MaxHealth = 250,
            MaxChi = 150,
            ChiRegen = 5,
            TapasyaRegen = 25,     -- ดูดซับตบะเร็วขึ้นเป็น 25/วิ
            WalkSpeed = 18,
            AttackPower = 35,
            Defense = 15,
        },
        UnlockedZone = "หุบเขาหมอกวิญญาณ (Mist Spirit Valley)",
        ZoneLevel = 2,
        Description = "ชักนำปราณฟ้าดินเข้าสู่ร่าง ชำระเส้นชีพจร ก้าวพ้นขีดจำกัดมนุษย์ธรรมดา"
    },
    {
        Name = "แก่นแท้",
        Title = "ยอดคนแดนแก่นแท้",
        RequiredExp = 5000,
        BaseBreakthroughRate = 0.50, -- อัตราสำเร็จพื้นฐาน 50%
        Color = Color3.fromRGB(85, 170, 255),
        Stats = {
            MaxHealth = 600,
            MaxChi = 450,
            ChiRegen = 15,
            TapasyaRegen = 75,     -- ดูดซับตบะเร็วขึ้นเป็น 75/วิ
            WalkSpeed = 22,
            AttackPower = 90,
            Defense = 45,
        },
        UnlockedZone = "ถ้ำศิลาทองคำ (Golden Core Cavern)",
        ZoneLevel = 3,
        Description = "ควบแน่นลมปราณจนกลายเป็นแก่นพลัง ปราณหมุนเวียนคุ้มกายไม่ขาดสาย"
    },
    {
        Name = "กำเนิดวิญญาณ",
        Title = "ปรมาจารย์กำเนิดวิญญาณ",
        RequiredExp = 20000,
        BaseBreakthroughRate = 0.35, -- อัตราสำเร็จพื้นฐาน 35%
        Color = Color3.fromRGB(255, 170, 0),
        Stats = {
            MaxHealth = 1500,
            MaxChi = 1200,
            ChiRegen = 35,
            TapasyaRegen = 220,    -- ดูดซับตบะเร็วขึ้นเป็น 220/วิ
            WalkSpeed = 26,
            AttackPower = 250,
            Defense = 110,
        },
        UnlockedZone = "เกาะลอยฟ้าดวงจิตทิพย์ (Celestial Floating Isle)",
        ZoneLevel = 4,
        Description = "ก่อกำเนิดดวงจิตทิพย์ จิตวิญญาณแยกจากร่าง เหาะเหินเดินอากาศได้ดั่งใจ"
    },
    {
        Name = "คืนสู่สัจธรรม",
        Title = "มหาเซียนสัจธรรม",
        RequiredExp = 60000,
        BaseBreakthroughRate = 0.20, -- อัตราสำเร็จพื้นฐาน 20%
        Color = Color3.fromRGB(255, 85, 255),
        Stats = {
            MaxHealth = 4000,
            MaxChi = 3500,
            ChiRegen = 100,
            TapasyaRegen = 600,    -- ดูดซับตบะเร็วขึ้นเป็น 600/วิ
            WalkSpeed = 30,
            AttackPower = 650,
            Defense = 260,
        },
        UnlockedZone = "แดนบรรพกาลไร้ขอบเขต (Boundless Origin)",
        ZoneLevel = 5,
        Description = "กายและจิตหลอมรวมกับเต๋าแห่งจักรวาล ไร้ผู้ต่อกรสะท้านปฐพี"
    }
}

-- รายชื่อสมุนไพรและค่าพลังทางโอสถ (Alchemy Potency)
GameConfig.Herbs = {
    ["หญ้าวิญญาณเขียว"] = {
        Rarity = "Common",
        Description = "พบเห็นได้ทั่วไป ช่วยฟื้นฟูพลังเล็กน้อย",
        Color = Color3.fromRGB(85, 255, 127),
        Potency = 10,
        Element = "ธาตุไม้ (Wood)"
    },
    ["โสมร้อยปี"] = {
        Rarity = "Rare",
        Description = "สมุนไพรหายาก เพิ่มรากฐานพลัง",
        Color = Color3.fromRGB(255, 170, 0),
        Potency = 35,
        Element = "ธาตุดิน (Earth)"
    },
    ["บัวหิมะพันปี [ระดับเทพ]"] = {
        Rarity = "Legendary",
        Description = "สมุนไพรในตำนาน พลังมหาศาล!",
        Color = Color3.fromRGB(170, 255, 255),
        Potency = 120,
        Element = "ธาตุน้ำแข็งเทวะ (Divine Ice)"
    }
}

GameConfig.HerbSpawnInterval = 30 -- สปอนสมุนไพรทุกๆ 30 วินาที

-- รายชื่อพื้นที่และม่านพลัง (Zone Barriers)
GameConfig.Zones = {
    {
        Name = "หุบเขาหมอกวิญญาณ",
        RequiredRealm = "หลอมลมปราณ",
        RequiredRealmIndex = 2,
        Position = Vector3.new(0, 5, 80),
        BarrierSize = Vector3.new(40, 20, 4),
        Color = Color3.fromRGB(85, 255, 127),
        Description = "ต้องการขอบเขต [หลอมลมปราณ] ขึ้นไปเพื่อผ่านม่านพลังหมอก"
    },
    {
        Name = "ถ้ำศิลาทองคำ",
        RequiredRealm = "แก่นแท้",
        RequiredRealmIndex = 3,
        Position = Vector3.new(0, 5, 180),
        BarrierSize = Vector3.new(40, 20, 4),
        Color = Color3.fromRGB(85, 170, 255),
        Description = "ต้องการขอบเขต [แก่นแท้] ขึ้นไปเพื่อผ่านม่านพลังศิลาทองคำ"
    }
}

-- พิกัดและข้อมูลโซนแผนที่โลก (World Coordinates & Biomes)
GameConfig.WorldCoordinates = {
    CityCenter = Vector3.new(0, 10, 0),         -- Azure Cloud Village (หมู่บ้านเมฆาคราม)
    CitySpawn = Vector3.new(0, 15, 0),
    CityPortals = {
        ToPvE = Vector3.new(-250, 10, 250),
        ToPvP = Vector3.new(250, 10, 250),
    },
    PvEZone = {
        Name = "แดนพฤกษาสวรรค์ (Empyrean Mist Forest)",
        Center = Vector3.new(1500, 50, 0),
        Spawn = Vector3.new(1500, 50, 0),
        ReturnPortal = Vector3.new(1500, 50, 0),
        Radius = 320,
        IsPvP = false,
        BannerText = "🌿 เข้าสู่แดนพฤกษาสวรรค์ [PvE Zone] - ปลอดภัยจากการต่อสู้",
        BannerColor = Color3.fromRGB(85, 255, 170),
        AtmosphereColor = Color3.fromRGB(160, 240, 220),
        FogColor = Color3.fromRGB(180, 255, 230),
        FogEnd = 350,
    },
    PvPZone = {
        Name = "หุบเหวอสูรโลหิต (Abyssal Asura Valley)",
        Center = Vector3.new(-1500, 50, 0),
        Spawn = Vector3.new(-1500, 50, 0),
        ReturnPortal = Vector3.new(-1500, 50, 0),
        Radius = 320,
        IsPvP = true,
        BannerText = "⚠️ เข้าสู่หุบเขาอสูรโลหิต [PvP Zone] - ผู้เล่นนอกปาร์ตี้สามารถโจมตีกันได้!",
        BannerColor = Color3.fromRGB(255, 80, 60),
        AtmosphereColor = Color3.fromRGB(220, 60, 40),
        FogColor = Color3.fromRGB(100, 25, 20),
        FogEnd = 260,
    }
}

-- รายการสินค้าในร้านค้า NPC (NPC Merchant Inventories)
GameConfig.ShopConfig = {
    ElderQing = {
        Title = "หอโอสถเทวะ - ผู้อาวุโสชิง เจ้าหอโอสถ",
        Description = "จำหน่ายสมุนไพรตั้งต้น และรับซื้อโอสถวิเศษที่ท่านหลอมขึ้น",
        Items = {
            { Name = "หญ้ากระดูกมังกรดิน", Type = "Herb", Price = 150, Currency = "Tapasya", Description = "สมุนไพรธาตุดิน 100 ปี เสริมความเสถียร" },
            { Name = "ดอกเพลิงกัลป์ป่า", Type = "Herb", Price = 180, Currency = "Tapasya", Description = "สมุนไพรธาตุไฟ 100 ปี พลังรุนแรง" },
            { Name = "ไผ่หยกเขียวขจี", Type = "Herb", Price = 150, Currency = "Tapasya", Description = "สมุนไพรธาตุวายุ 100 ปี ปราณไหลเวียน" },
            { Name = "ผลชะล้างไขกระดูก", Type = "Herb", Price = 250, Currency = "Tapasya", Description = "สมุนไพรปรับปรุงเส้นชีพจร ชำระสิ่งเจือปน" },
            { Name = "โสมร้อยปี", Type = "Herb", Price = 300, Currency = "Tapasya", Description = "สมุนไพรหายาก เพิ่มรากฐานพลัง" },
        }
    },
    MasterTie = {
        Title = "หอศัสตราวุธเซียน - ปรมาจารย์เถี่ย ช่างตีเหล็กสวรรค์",
        Description = "สร้างสรรค์เครื่องมือและศาสตราวุธเพื่อช่วยในการบำเพ็ญเพียร",
        Items = {
            { Name = "เคียวตัดสมุนไพรเทวะ", Type = "Tool", Price = 1200, Currency = "Tapasya", Description = "เคียวอาคม ช่วยเพิ่มผลผลิตการเด็ดสมุนไพร +1 ชิ้นทุกครั้ง!" },
            { Name = "กระเป๋ามิติร้อยช่อง", Type = "BagUpgrade", Price = 2500, Currency = "Tapasya", Description = "ขยายขนาดความจุกระเป๋าและช่องใส่ของ" },
            { Name = "ยันต์หยกคุ้มกายาสวรรค์", Type = "Talisman", Price = 800, Currency = "Tapasya", Description = "สร้างบาเรียป้องกันความเสียหาย 500 หน่วย เมื่อเข้าสู่แดน PvP" },
        }
    }
}

-- คัมภีร์ตำรับโอสถโบราณฉบับปฐมบท (Beginner Alchemy Treatise)
GameConfig.AlchemyTreatise = [[
📜 [คัมภีร์ตำรับโอสถปฐมบทแห่งบรรพชน]
"เตาหลอมเกิดจากจิตวิญญาณ โอสถสวรรค์หามีสูตรตายตัวไม่!
ใส่สมุนไพรสิ่งใดลงไป พลังแห่งตัวยาย่อมหลอมรวมตามสิ่งนั้น
ทว่าความบริสุทธิ์และระดับของเม็ดยา ล้วนขึ้นอยู่กับ 4 ขั้นตอน:
1. การเลือกส่วนผสม: สมุนไพรล้ำค่าให้ฤทธิ์ยาเข้มข้น
2. การจุดไฟ & เลี้ยงเปลวเพลิง: คุมไฟให้อยู่ในโซนทองคำ มิต่ำไปมิสูงไป
3. การกวนประสานเนื้อยา: รักษาสมดุลไม้พายมิให้ปราณกระจายตัว
4. การส่งลมปราณตามจังหวะ: ถ่ายทอดปราณแท้ในชั่วพริบตาแห่งความสมบูรณ์!

หากทำได้ไร้ที่ติ โอสถจักเลื่อนระดับสู่ 'ระดับสมบูรณ์แบบ' 
ส่งผลให้ตบะและโอกาสทะลวงขอบเขตพุ่งทะยานสูงสุด!"
]]

-- ระดับคุณภาพของยาโอสถที่ได้จากการปรุง
GameConfig.PillQualityTiers = {
    {Name = "ระดับล่าง", Multiplier = 0.7, Color = Color3.fromRGB(160, 160, 160)},
    {Name = "ระดับกลาง", Multiplier = 1.0, Color = Color3.fromRGB(85, 255, 127)},
    {Name = "ระดับสูง", Multiplier = 1.4, Color = Color3.fromRGB(85, 170, 255)},
    {Name = "ระดับสมบูรณ์แบบ", Multiplier = 2.0, Color = Color3.fromRGB(255, 215, 0)}
}

-- ตำรับยาสำเร็จรูปมาตรฐาน (Standard Recipes - ไว้ใช้อ้างอิงหรือเสกผ่าน Admin)
GameConfig.Pills = {
    ["เม็ดยารวบรวมลมปราณ"] = {
        Name = "เม็ดยารวบรวมลมปราณ",
        Rarity = "Common",
        Color = Color3.fromRGB(85, 255, 127),
        Description = "ช่วยควบแน่นปราณ เพิ่มตบะ +300 แต้ม และเพิ่มโอกาสทะลวงขอบเขต +20%",
        TapasyaBonus = 300,
        BreakthroughBonus = 0.20,
    },
    ["เม็ดยาทะลวงชีพจร"] = {
        Name = "เม็ดยาทะลวงชีพจร",
        Rarity = "Rare",
        Color = Color3.fromRGB(85, 170, 255),
        Description = "ชำระไขกระดูกและทะลวงจุดชีพจร เพิ่มตบะ +1,000 แต้ม และเพิ่มโอกาสทะลวงขอบเขต +35%",
        TapasyaBonus = 1000,
        BreakthroughBonus = 0.35,
    },
    ["เม็ดยาแก่นทองคำ"] = {
        Name = "เม็ดยาแก่นทองคำ",
        Rarity = "Epic",
        Color = Color3.fromRGB(255, 170, 0),
        Description = "ยาโอสถล้ำค่า ช่วยป้องกันธาตุไฟเข้าแทรก เพิ่มตบะ +3,000 แต้ม และเพิ่มโอกาสทะลวงขอบเขต +50%",
        TapasyaBonus = 3000,
        BreakthroughBonus = 0.50,
    },
    ["เม็ดยาสัจธรรมเทวะ"] = {
        Name = "เม็ดยาสัจธรรมเทวะ",
        Rarity = "Legendary",
        Color = Color3.fromRGB(255, 85, 255),
        Description = "โอสถระดับเทพจุติ พลังฟ้าดินบริสุทธิ์ เพิ่มตบะ +10,000 แต้ม และการันตีทะลวงขอบเขตสำเร็จ 100%!",
        TapasyaBonus = 10000,
        BreakthroughBonus = 1.00,
    }
}

-- อัตราการได้รับตบะพื้นฐาน
GameConfig.AfkInterval = 1 -- ทุกๆ กี่วินาที

-- รายชื่อ Admin ถาวร
GameConfig.SuperAdmins = {
    [1] = true,
}

return GameConfig
