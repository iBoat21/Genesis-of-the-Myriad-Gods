-- Player Inventory System
-- Handles the inventory/bag for the player

local PlayerInventory = {}
PlayerInventory.__index = PlayerInventory

function PlayerInventory:New()
    return setmetatable({}, { __index = self })
end

function PlayerInventory:GetBagItems()
    return self.bag
end

-- Add item to bag
function PlayerInventory:AddToBag(itemName, itemData)
    self.bag[itemName] = itemData
    print("Item added to bag: " .. tostring(itemName))
end

-- Remove item from bag
function PlayerInventory:RemoveFromBag(itemName)
    if self.bag[itemName] then
        self.bag[itemName] = nil
        print("Item removed from bag: " .. tostring(itemName))
    end
end

-- Check if item is in bag
function PlayerInventory:HasItem(itemName)
    return self.bag[itemName] ~= nil
end

-- Get item quantity in bag
function PlayerInventory:GetItemQuantity(itemName)
    local itemData = self.bag[itemName]
    if itemData then
        return itemData.Quantity or 1
    else
        return 0
    end
end

-- Open bag
function PlayerInventory:Open()
    print("Opening bag...")
end

-- Close bag
function PlayerInventory:Close()
    print("Closing bag...")
end

return PlayerInventory
