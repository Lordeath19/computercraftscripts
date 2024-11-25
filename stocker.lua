if not fs.exists("json") then
    shell.run("pastebin get 4nRg9CHU json")
end

os.loadAPI("json")

local configFolder = "stock_config"
local monitorPeripheral = "top"

-- Reads configuration files
local function readConfigFiles(folder)
    local configs = {}
    if fs.exists(folder) and fs.isDir(folder) then
        for _, file in ipairs(fs.list(folder)) do
            local filePath = fs.combine(folder, file)
            if not fs.isDir(filePath) then
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

-- Checks the stock level of a product
local function checkStockLevel(itemName, destinationPeripheral)
    local stockPeripheral = peripheral.wrap(destinationPeripheral)
    if not stockPeripheral then
        print("Error: Could not find destination peripheral.")
        return 0
    end

    local currentStock = 0
    for _, item in pairs(stockPeripheral.list()) do
        if item.name == itemName then
            currentStock = currentStock + item.count
        end
    end
    return currentStock
end

-- Checks for missing items and calculates the largest possible batch
local function checkMissingItems(config)
    local missingItems = {}
    local maxBatchCount = math.huge  -- Start with an unlimited batch count and reduce as needed

    for _, ingredient in ipairs(config.ingredients) do
        local itemName = ingredient.name
        local requiredQuantity = ingredient.quantity or 1
        local availableQuantity = 0

        -- Determine the source for this specific ingredient
        local sourcePeripheral = peripheral.wrap(ingredient.source)
        if not sourcePeripheral then
            print("Error: Could not find source peripheral for " .. itemName)
            table.insert(missingItems, { name = itemName, missing = requiredQuantity })
            maxBatchCount = 0  -- If a source is missing, no batches can be created
        else
            -- Accumulate the count of the item in the source inventory
            for slot, itemDetail in pairs(sourcePeripheral.list()) do
                if itemDetail.name == itemName then
                    availableQuantity = availableQuantity + itemDetail.count
                end
            end

            -- Calculate max possible batches for this ingredient
            local maxIngredientBatches = math.floor(availableQuantity / requiredQuantity)
            if maxIngredientBatches < maxBatchCount then
                maxBatchCount = maxIngredientBatches
            end

            -- Add to missing items if quantity is insufficient for at least one batch
            if availableQuantity < requiredQuantity then
                table.insert(missingItems, {
                    name = itemName,
                    missing = requiredQuantity - availableQuantity
                })
            end
        end
    end

    -- Return the missing items and the largest possible batch count
    return missingItems, maxBatchCount
end

-- Transfers ingredients to the processing input peripheral
local function transferIngredients(ingredients, processingInput, batchCount)
    local inputPeripheral = peripheral.wrap(processingInput)
    if not inputPeripheral then
        print("Error: Could not find processing input peripheral.")
        return false
    end

    for _, ingredient in ipairs(ingredients) do
        local ingredientName = ingredient.name
        local quantity = (ingredient.quantity or 1) * batchCount
        local sourcePeripheral = peripheral.wrap(ingredient.source)

        if not sourcePeripheral then
            print("Error: Could not find source peripheral for " .. ingredientName)
            return false
        end

        for slot, item in pairs(inputPeripheral.list()) do
            if item.name == ingredientName then
                quantity = quantity - item.count
                if quantity <= 0 then 
                    print("Items are already being processed. waiting")
                    break
                end
            end
        end

        local actualTransferred = 0
        for slot, item in pairs(sourcePeripheral.list()) do
            if item.name == ingredientName then
                local toTransfer = math.min(quantity - actualTransferred, item.count)
                actualTransferred = actualTransferred + inputPeripheral.pullItems(peripheral.getName(sourcePeripheral), slot, toTransfer)
                if actualTransferred >= quantity then break end
            end
        end

        if actualTransferred < quantity then
            print("Couldn't place all " .. ingredientName .. " missing: " .. quantity - actualTransferred)
            return false
        end
    end
    return true
end

local function waitForProduct(config, batchSize)
    local outputPeripheral = peripheral.wrap(config.processing_output)
    if not outputPeripheral then
        print("Error: Could not find processing output peripheral.")
        return
    end

    while true do
        local productCount = 0

        -- Count the total quantity of the product in the output peripheral
        for _, item in pairs(outputPeripheral.list()) do
            if item.name == config.product then
                productCount = productCount + item.count
            end
        end

        -- Check if the product count meets or exceeds the batch size
        if productCount >= batchSize then
            break
        end

        -- Wait before checking again
        os.sleep(1)
    end
end

-- Transfers finished products to the stock destination peripheral
local function transferProduct(productName, processingOutput, destination)
    local outputPeripheral = peripheral.wrap(processingOutput)
    local destinationPeripheral = peripheral.wrap(destination)

    if not outputPeripheral or not destinationPeripheral then
        print("Error: Could not find processing output or destination peripheral.")
        return
    end

    for slot, item in pairs(outputPeripheral.list()) do
        if item.name == productName then
            outputPeripheral.pushItems(peripheral.getName(destinationPeripheral), slot)
        end
    end
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
                -- Pause and clear monitor when space is exhausted
                os.sleep(2)
                monitor.clear()
                monitor.setCursorPos(1, 1)
                monitor.write("Missing Resources (cont'd):")
                line = 2
            end
        end

        -- Add a blank line between items for readability
        if line < height then
            line = line + 1
        else
            os.sleep(2)
            monitor.clear()
            monitor.setCursorPos(1, 1)
            monitor.write("Missing Resources (cont'd):")
            line = 2
        end
    end
end


-- Displays status on the monitor
local function displayStatus(config, currentStock, ingredientsReady, batchesAvailable)
    local monitor = peripheral.wrap(monitorPeripheral)
    if not monitor then
        print("Error: Monitor not found.")
        return
    end

    monitor.clear()
    monitor.setCursorPos(1, 1)
    monitor.write("Stock Management:")
    monitor.setCursorPos(1, 2)
    monitor.write("- Product: " .. config.product)
    monitor.setCursorPos(1, 3)
    monitor.write("- Required Stock: " .. config.stock)
    monitor.setCursorPos(1, 4)
    monitor.write("- Current Stock: " .. currentStock)
    monitor.setCursorPos(1, 5)
    monitor.write("- Ingredients Ready: " .. (ingredientsReady and "Yes" or "No"))
    monitor.setCursorPos(1, 6)
    monitor.write("- Batches Available: " .. batchesAvailable)
end

local function initializeDefaults(config)
    config.processing_output = config.processing_output or config.processing_input
    config.batch_size = config.batch_size or 1
    config.max_batch_size = config.max_batch_size or 64
    for _, ingredient in ipairs(config.ingredients) do
        ingredient.source = ingredient.source or config.destination
    end
end

-- Main logic
local function main()
    local configFiles = readConfigFiles(configFolder)
    for _, config in ipairs(configFiles) do
        initializeDefaults(config)
        local productName = config.product
        local requiredStock = config.stock
        local destination = config.destination
        local processingInput = config.processing_input
        local processingOutput = config.processing_output
        local ingredients = config.ingredients

        local currentStock = checkStockLevel(productName, destination)

        if currentStock < requiredStock then
            local missingItems, maxBatchCount = checkMissingItems(config)
            maxBatchCount = math.min(maxBatchCount, config.max_batch_size)
            local batchSize = math.min(requiredStock - currentStock, maxBatchCount)
            if batchSize > 0 then
                -- Transfer ingredients for the maximum number of batches possible
                local ingredientsReady = transferIngredients(ingredients, processingInput, batchSize)
                displayStatus(config, currentStock, ingredientsReady, batchSize)

                if ingredientsReady then
                    waitForProduct(config, batchSize)
                    transferProduct(productName, processingOutput, destination)
                else
                    print("Could not transfer all ingredients for " .. productName .. ", will retry later")
                end
            else
                displayMissingResources(missingItems)
            end
        end
    end
    print("Stock management cycle complete.")
end


while true do
    local monitor = peripheral.wrap(monitorPeripheral)
    if monitor then
        monitor.clear()
        monitor.setCursorPos(1, 1)
    end
    term.clear()
    term.setCursorPos(1,1)
    main()
    os.sleep(5)
end
