-- Configurations
local woodSlot = 1                 -- Slot where wood is stored in the chest
local creosoteSlot = 2             -- Slot where creosote buckets are stored in the chest
local maxCraftAmount = 64          -- Max amount of treated wood to craft (optional, can be adjusted)

local modemPeripheral = "bottom"
local sourcePeripheral = "storagenetwork:exchange_4"

local modem = peripheral.wrap(modemPeripheral)
local turtleName = modem.getNameLocal()


local function createWood(source)
    local success = false
    for sourceSlot, item in pairs(source.list()) do
        if item.name == "minecraft:oak_log" and item.count > 0 then
            local transferred = source.pushItems(turtleName, sourceSlot, 64, targetSlot)
            if transferred > 0 then
                success = true
                break
            end
        end
    end
    turtle.craft()
    return success
end

local function getWood(source)
    local slots = {1, 2, 3, 5, 7, 9, 10, 11}

    for _, targetSlot in ipairs(slots) do
        local success = false

        for sourceSlot, item in pairs(source.list()) do
            if item.name == "minecraft:oak_planks" and item.count > 0 then
                local transferred = source.pushItems(turtleName, sourceSlot, 1, targetSlot)
                if transferred > 0 then
                    success = true
                    break
                end
            end
        end

        if not success then
            -- Try to create more planks for later crafts
            createWood(source)
            return false
        end
    end

    return true
end



local function getCreosote(source)
    for slot, item in pairs(source.list()) do
        if item.name == "immersiveengineering:creosote_bucket" then
            source.pushItems(turtleName, slot, 1, 6)
            return true
        end
    end
    return false
end

local function getIngredients()
    local source = peripheral.wrap(sourcePeripheral)

    local wood = getWood(source)
    local creosote = getCreosote(source)

    return wood, creosote
end

local function moveToCraftingGrid(woodSlot, creosoteSlot)
    local source = peripheral.wrap(sourcePeripheral)
    turtle.craft()
end

local function cleanupItems()
    local source = peripheral.wrap(sourcePeripheral)
    for slot=1,16 do
        source.pullItems(turtleName, slot)
    end
end

local function automateTreatedWood()
    while true do
        local woodSlot, creosoteSlot = getIngredients()

        if woodSlot and creosoteSlot then
            moveToCraftingGrid(woodSlot, creosoteSlot)
        else
            os.sleep(2)
        end
        cleanupItems()
    end
end

automateTreatedWood()