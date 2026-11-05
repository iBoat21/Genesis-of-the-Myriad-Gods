-- Local Script: Button Input Handler
-- Handles Button B (open bag) and Button E (collect herbs)

local InventoryManager = require(game.ReplicatedStorage.InventoryManager)

-- Get local player
local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer

-- Initialize inventory manager with player
local inventoryManager = InventoryManager
inventoryManager:init(localPlayer)

-- Define button actions
local Actions = {
    B = function() -- Open Bag
        if inventoryManager then
            inventoryManager:openBag()
        end
    end,

    E = function() -- Collect Herb
        if inventoryManager then
            inventoryManager:collectItem("herb_" .. math.random(1, 10))
        end
    end
}

-- Setup input handling using UserInputService
local UserInputService = game:GetService("UserInputService")

local function onKeyboardKeyPressed(input, gameProcessed)
    if gameProcessed then return end
    
    local keyCode = input.KeyCode
    if keyCode == Enum.KeyCode.B then
        Actions["B"]()
    elseif keyCode == Enum.KeyCode.E then
        Actions["E"]()
    end
end

UserInputService.InputBegan:Connect(onKeyboardKeyPressed)

print("Local button script initialized - B: Open Bag, E: Collect Herb")
