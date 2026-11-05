-- Inventory Manager Module
-- Handles item collection and bag storage for the player
-- This is a ModuleScript that can be required by both server and client scripts

local InventoryManager = {
    items = {},
    bag = {},
    player = nil
}

-- Add an item to the inventory
function InventoryManager:addItem(itemName, quantity)
    self.items[itemName] = (self.items[itemName] or 0) + quantity
    self.bag[itemName] = true
    print("Added " .. quantity .. " " .. itemName .. " to bag/inventory")
    return true
end

-- Remove an item from inventory
function InventoryManager:removeItem(itemName, quantity)
    if self.items[itemName] then
        self.items[itemName] = self.items[itemName] - quantity
        if self.items[itemName] <= 0 then
            self.items[itemName] = nil
            self.bag[itemName] = nil
        end
        print("Removed " .. quantity .. " " .. itemName .. " from bag/inventory")
    end
end

-- Get item count
function InventoryManager:getItemCount(itemName)
    return self.items[itemName] or 0
end

-- Open the bag (show inventory)
function InventoryManager:openBag()
    if not self.player then return end
    print("Bag opened")
    -- In a real implementation, this would show the inventory UI
end

-- Close the bag
function InventoryManager:closeBag()
    if not self.player then return end
    print("Bag closed")
end

-- Collect an item (simulate picking up herbs)
function InventoryManager:collectItem(itemName)
    if not self.player then return end
    -- Add the collected item to the inventory/bag
    local success = self:addItem(itemName, 1)
    if success then
        print("Collected " .. itemName .. " and added to bag successfully")
    end
    return success
end

-- Get all items
function InventoryManager:getAllItems()
    return self.items
end

-- Initialize with player
function InventoryManager:init(player)
    self.player = player
    self.items = {}
    self.bag = {}
end

return InventoryManager