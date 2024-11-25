if not fs.exists("json") then
    shell.run("pastebin get 4nRg9CHU json")
end

os.loadAPI("json")

local defaultSourcePeripheral = "back" -- exchange interface
local configFolder = "config"
local monitorPeripheral = "left"

-- Reads configuration files from the config folder
local function readConfigFiles(folder)
    local configs = {}
    if fs.exists(folder) and fs.isDir(folder) then
        for _, file in ipairs(fs.list(folder)) do
            local filePath = fs.combine(folder, file)
            if fs.isDir(filePath) == false then
                local fileHandle = fs.open(filePath, "r")
                if fileHandle then
                    local content = fileHandle.readAll()
                    fileHandle.close()
                    local parsed = json.decode(content)
                    if parsed then
                        table.insert(configs, parsed)
                    end
                end
            end
        end
    end
    return configs
end

-- Displays missing items on the monitor
local function displayMissingResources(missingItems)
    local monitor = peripheral.wrap(monitorPeripheral)
    if not monitor then
        print("Error: Monitor not found. Missing resources will not be displayed.")
        return
    end

    monitor.clear()
    monitor.setCursorPos(1, 1)
    monitor.write("Missing Resources:")

    local width, height = monitor.getSize()
    local line = 2

    for _, item in ipairs(missingItems) do
        local text = "- " .. item.name .. ": " .. item.missing
        while #text > 0 do
            local chunk = text:sub(1, width) -- Split into chunks that fit the monitor width
            monitor.setCursorPos(1, line)
            monitor.write(chunk)
            text = text:sub(width + 1)
            line = line + 1

            if line > height then
                break -- Stop if the monitor height is exceeded
            end
        end
        if line > height then break end
    end
end

-- Checks for missing items in the source inventory
local function checkMissingItems(itemConfig)
    local missingItems = {}
    local source = peripheral.wrap(itemConfig.source or defaultSourcePeripheral)
    if not source then
        print("Error: Could not find source peripheral.")
        return missingItems, false
    end

    for _, item in ipairs(itemConfig.items) do
        local itemName = item.name
        local requiredQuantity = item.quantity or 1
        local availableQuantity = 0

        -- Check inventory for item and accumulate total countכא'
        for slot, itemDetail in pairs(source.list()) do
            if itemDetail.name == itemName then
                availableQuantity = availableQuantity + itemDetail.count
            end
        end

        -- Add to missing items if insufficient quantity
        if availableQuantity < requiredQuantity then
            table.insert(missingItems, {
                name = itemName,
                missing = requiredQuantity - availableQuantity
            })
        end
    end

    return missingItems, #missingItems == 0
end

-- Transfers items from source to destination
local function transferItems(itemConfig)
    local source = peripheral.wrap(itemConfig.source or defaultSourcePeripheral)
    local destination = peripheral.wrap(itemConfig.destination)
    if not source or not destination then
        print("Error: Could not find peripherals, verify your json names are correct.")
        return
    end

    for _, item in ipairs(itemConfig.items) do
        local itemName = item.name
        local requiredQuantity = item.quantity or 1

        for slot, itemDetail in pairs(source.list()) do
            if itemDetail.name == itemName then
                local toTransfer = math.min(requiredQuantity, itemDetail.count)
                source.pushItems(peripheral.getName(destination), slot, toTransfer)
                requiredQuantity = requiredQuantity - toTransfer
                if requiredQuantity <= 0 then break end
            end
        end
    end
end

-- Main logic to handle item transfer
local function main()
    local configFiles = readConfigFiles(configFolder)
    for _, config in ipairs(configFiles) do
        local missingItems, allAvailable = checkMissingItems(config)

        if not allAvailable then
            displayMissingResources(missingItems)
            if not config.forcePush then
                print("Item transfer aborted due to missing resources.")
                return
            else
                print("Missing items detected, but proceeding due to forcePush.")
            end
        end

        transferItems(config)
    end
    print("Item transfer complete.")
end

main()
