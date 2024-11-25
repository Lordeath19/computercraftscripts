-- Add a wrapper function to run the main stock management cycle
local function runStockManagement()
    while true do
        shell.run("stocker.lua")
        os.sleep(10)
    end
end

local function runCokeOven()
    shell.run("coke_oven.lua")
end

-- Run both scripts in parallel
parallel.waitForAny(runStockManagement, runCokeOven)
