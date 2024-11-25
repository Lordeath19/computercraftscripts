-- cokeOvenAutomation.lua

-- Configurations
local cokeOvenPeripheral = "immersiveengineering:cokeoven_dummy_0"  -- Replace with your Coke Oven's peripheral name
local sourcePeripheral = "storagenetwork:exchange_3"   -- Replace with the peripheral name for your storage chest
local emptyBucketSlot = 3         -- Slot where empty buckets are located in the chest
local fullBucketSlot = 4          -- Slot where full buckets are stored in the chest

-- Function to check if the Coke Oven has full buckets of creosote
local function checkForFullBuckets()
    local cokeOven = peripheral.wrap(cokeOvenPeripheral)
    local fullBuckets = {}

    local item = cokeOven.getItemDetail(fullBucketSlot)
    if item and item.name == "immersiveengineering:creosote_bucket" then
        table.insert(fullBuckets, fullBucketSlot)
    end

    return fullBuckets
end

-- Function to transfer full buckets from the Coke Oven to a source
local function transferFullBuckets(fullBuckets)
    local source = peripheral.wrap(sourcePeripheral)
    local cokeOven = peripheral.wrap(cokeOvenPeripheral)

    for _, slot in ipairs(fullBuckets) do
        local bucket = cokeOven.pushItems(peripheral.getName(source), slot, 1)
        if not bucket then
            print("Error transferring full bucket of creosote.")
        end
    end
end

-- Function to insert empty buckets back into the Coke Oven
local function insertEmptyBuckets()
    local source = peripheral.wrap(sourcePeripheral)
    local cokeOven = peripheral.wrap(cokeOvenPeripheral)

    local cokeBucket = cokeOven.getItemDetail(emptyBucketSlot)
    if cokeBucket then
        return
    end

    for slot, item in pairs(source.list()) do
        if item.name == "minecraft:bucket" and item.nbt == nil then
            source.pushItems(cokeOvenPeripheral, slot, 1, emptyBucketSlot)
            return
        end
    end

end

-- Main function to automate the Coke Oven process
local function automateCokeOven()
    while true do
        -- Step 1: Check for full buckets
        local fullBuckets = checkForFullBuckets()

        if #fullBuckets > 0 then
            -- Step 2: Transfer full buckets to storage chest
            transferFullBuckets(fullBuckets)
        end

        -- Step 3: Insert empty buckets back into the Coke Oven
        insertEmptyBuckets()

        -- Sleep for a while before checking again
        os.sleep(5)
    end
end

-- Start automation
automateCokeOven()
