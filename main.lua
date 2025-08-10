--[[
    Dig & Jetpack Exploit - 0verflow Hub (With Farming)
    Advanced digging abuse script with auto farming and infinite jetpack fuel
    
    Author: buffer_0verflow
    Date: 2025-08-09
    Version: 3.0.2
    Time: 00:23:24 UTC
]]

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")

-- Player
local LocalPlayer = Players.LocalPlayer

-- Core Variables
local DigExploit = {
    Active = false,
    InstantDig = false,
    BypassChecks = false,
    MultiDig = false,
    AutoCash = false,
    AutoGems = false,
    DigSpeed = 0.01,
    CashSpeed = 0.05,
    GemsSpeed = 0.05,
    Toggles = {}
}

-- Jetpack Variables
local JetpackExploit = {
    InfiniteFuel = false,
    ActiveMethods = {},
    Toggles = {}
}

-- Spin Wheel Variables
local SpinExploit = {
    AutoSpin = false,
    AutoClaimFreeSpins = false,
    FreeSpinsActive = false,
    FreeSpinsCount = 0,
    SpinDelay = 0.1,
    FreeSpinClaimDelay = 1,
    Toggles = {}
}

-- Treasure Variables
local TreasureExploit = {
    AutoCollect = false,
    InstantCollect = false,
    BypassDebounce = false,
    CollectDelay = 0.05,
    Treasures = {},
    Connections = {},
    CollectedCount = 0,
    Toggles = {}
}

-- Auto Win Variables (integrated from standalone autowin.lua)
local AutoWin = {
    Active = false,
    CurrentWorld = 1,
    Connection = nil,
    Toggles = {}
}

-- Remote Events for farming
local RemoteCache = {
    DigEvent = nil, -- For cash
    GemEvent = nil  -- For gems
}

-- Cache remotes
local function CacheRemotes()
    pcall(function()
        RemoteCache.DigEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("DigEvent", 5)
        RemoteCache.GemEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("GemEvent", 5)
    end)
    
    return RemoteCache.DigEvent and RemoteCache.GemEvent
end

-- ========================================
-- SPIN WHEEL SYSTEM
-- ========================================

-- Get spin wheel components
local SpinScript, ScriptEnv, SpinPrizeEvent, FreeSpinEvent

local function InitializeSpinComponents()
    pcall(function()
        SpinScript = LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("Spins", 5)
        if SpinScript then
            ScriptEnv = getsenv(SpinScript)
        end
        
        local Remotes = ReplicatedStorage:WaitForChild("Remotes", 5)
        if Remotes then
            SpinPrizeEvent = Remotes:WaitForChild("SpinPrizeEvent", 5)
            FreeSpinEvent = Remotes:WaitForChild("FreeSpinEvent", 5)
        end
    end)
end

-- Reset spinning state
local function ResetSpinState()
    if not ScriptEnv then return end
    
    -- Reset all spinning variables
    for k, v in pairs(ScriptEnv) do
        local keyStr = tostring(k)
        if keyStr:find("var104") then -- Spinning state
            ScriptEnv[k] = false
        elseif keyStr:find("var141") then -- Timer active
            ScriptEnv[k] = false
        elseif keyStr:find("var142") then -- Timer cancelled
            ScriptEnv[k] = true
        elseif keyStr:find("var117") then -- Is spinning animation
            ScriptEnv[k] = false
        end
    end
    
    -- Reset player attribute
    LocalPlayer:SetAttribute("Spinning", false)
end

-- Instant spin function (bypasses animation and directly claims reward)
local function InstantSpin(forceSegment)
    if not SpinPrizeEvent then
        warn("[Spin] SpinPrizeEvent not found")
        return
    end
    
    -- Reset state first
    ResetSpinState()
    
    -- Determine segment
    local segment = forceSegment or math.random(1, 10)
    
    -- Fire the prize event directly
    SpinPrizeEvent:FireServer(segment)
    
    -- Play sounds for feedback
    pcall(function()
        local sounds = ReplicatedStorage:FindFirstChild("Sounds")
        if sounds then
            if sounds:FindFirstChild("RewardSound2") then sounds.RewardSound2:Play() end
            if sounds:FindFirstChild("WinSound2") then sounds.WinSound2:Play() end
        end
    end)
    
    print("[Spin] Claimed segment:", segment)
    
    -- Small delay before next action
    task.wait(0.1)
    ResetSpinState()
end

-- Free Spins function (10 instant jackpots)
local function ClaimFreeSpins()
    SpinExploit.FreeSpinsActive = true
    SpinExploit.FreeSpinsCount = 10
    
    spawn(function()
        print("[Free Spins] Claiming 10 jackpots...")
        
        for i = 1, 10 do
            if not SpinExploit.FreeSpinsActive then break end
            
            -- Always force segment 10 (jackpot) for free spins
            InstantSpin(10)
            
            SpinExploit.FreeSpinsCount = 10 - i
            
            -- Small delay between spins
            task.wait(SpinExploit.SpinDelay)
        end
        
        SpinExploit.FreeSpinsActive = false
        SpinExploit.FreeSpinsCount = 0
        print("[Free Spins] Completed!")
    end)
end

-- Auto Spin function (always uses instant spin)
local function StartAutoSpin()
    spawn(function()
        print("[Auto Spin] Started with instant spin enabled")
        
        while SpinExploit.AutoSpin do
            -- Don't spin if free spins are active
            if not SpinExploit.FreeSpinsActive then
                -- Check if we have spins available
                local spinsValue = LocalPlayer:FindFirstChild("Spins")
                if spinsValue and spinsValue.Value > 0 then
                    -- Use instant spin for auto spin
                    InstantSpin(nil) -- Random segment
                elseif spinsValue and spinsValue.Value == 0 and FreeSpinEvent then
                    -- Try to claim a free spin from timer
                    FreeSpinEvent:FireServer()
                    print("[Auto Spin] Attempting to claim timer spin...")
                end
            end
            
            task.wait(SpinExploit.SpinDelay)
        end
        
        print("[Auto Spin] Stopped")
    end)
end

-- Auto Claim Free Spins function (automatically uses ClaimFreeSpins)
local function StartAutoClaimFreeSpins()
    spawn(function()
        print("[Auto Claim] Started auto claiming free spins with ClaimFreeSpins")
        
        while SpinExploit.AutoClaimFreeSpins do
            -- Don't start new free spins if already active
            if not SpinExploit.FreeSpinsActive then
                print("[Auto Claim] Triggering ClaimFreeSpins (10 jackpots)")
                ClaimFreeSpins()
                
                -- Wait for the current ClaimFreeSpins to complete
                while SpinExploit.FreeSpinsActive do
                    task.wait(0.5)
                end
                
                print("[Auto Claim] ClaimFreeSpins completed, waiting before next cycle")
            end
            
            -- Wait before next claim cycle
            task.wait(SpinExploit.FreeSpinClaimDelay)
        end
        
        print("[Auto Claim] Stopped auto claiming")
    end)
end

-- ========================================
-- TREASURE SYSTEM
-- ========================================

-- Get treasure components
local Treasure, TreasureEvent, ConfettiEvent, GemSound

local function InitializeTreasureComponents()
    pcall(function()
        Treasure = workspace:WaitForChild("Treasure", 5)
        
        local Remotes = ReplicatedStorage:WaitForChild("Remotes", 5)
        if Remotes then
            TreasureEvent = Remotes:FindFirstChild("TreasureEvent")
            ConfettiEvent = Remotes:FindFirstChild("ConfettiEvent")
        end
        
        local Sounds = ReplicatedStorage:FindFirstChild("Sounds")
        if Sounds then
            GemSound = Sounds:FindFirstChild("GemSound")
        end
    end)
end

-- Bypass debounce
local function BypassDebounce()
    if not TreasureExploit.BypassDebounce or not Treasure then return end
    
    for _, treasure in pairs(Treasure:GetChildren()) do
        if treasure:GetAttribute("Debounce") then
            treasure:SetAttribute("Debounce", false)
        end
    end
end

-- Collect treasure function
local function CollectTreasure(treasure)
    if not treasure then return end
    
    -- Method 1: Fire the remote directly
    if TreasureEvent then
        pcall(function()
            TreasureEvent:FireServer(treasure.Name)
        end)
    end
    
    -- Method 2: Simulate touch event
    pcall(function()
        local character = LocalPlayer.Character
        if character and character:FindFirstChild("HumanoidRootPart") then
            local part = treasure:IsA("Model") and treasure.PrimaryPart or treasure
            if part then
                firetouchinterest(character.HumanoidRootPart, part, 0)
                task.wait(0.01)
                firetouchinterest(character.HumanoidRootPart, part, 1)
            end
        end
    end)
    
    -- Method 3: Trigger confetti for visual effect
    if ConfettiEvent then
        pcall(function()
            ConfettiEvent:Fire()
        end)
    end
    
    -- Play sound locally
    if GemSound then
        pcall(function()
            GemSound:Play()
        end)
    end
    
    TreasureExploit.CollectedCount = TreasureExploit.CollectedCount + 1
    
    -- Remove debounce
    if TreasureExploit.BypassDebounce then
        treasure:SetAttribute("Debounce", false)
    end
    
    print("[Treasure] Collected:", treasure.Name)
end

-- Auto collect all treasures
local function StartAutoCollectTreasures()
    spawn(function()
        print("[Treasure] Auto collect started")
        
        while TreasureExploit.AutoCollect do
            BypassDebounce()
            
            if Treasure then
                for _, treasure in pairs(Treasure:GetChildren()) do
                    if not TreasureExploit.AutoCollect then break end
                    
                    local character = LocalPlayer.Character
                    if character and character:FindFirstChild("HumanoidRootPart") then
                        local part = treasure:IsA("Model") and treasure.PrimaryPart or treasure
                        if part then
                            local distance = (character.HumanoidRootPart.Position - part.Position).Magnitude
                            
                            -- Check if we should collect based on mode
                            local shouldCollect = false
                            
                            if TreasureExploit.InstantCollect then
                                shouldCollect = true -- Collect regardless of distance
                            elseif treasure.Name == "Shard" and distance <= 200 then
                                shouldCollect = true
                            elseif treasure.Name ~= "Shard" and distance <= 70 then
                                shouldCollect = true
                            end
                            
                            if shouldCollect then
                                CollectTreasure(treasure)
                                task.wait(TreasureExploit.CollectDelay)
                            end
                        end
                    end
                end
            end
            
            task.wait(0.1)
        end
        
        print("[Treasure] Auto collect stopped")
    end)
end

-- Monitor treasures
local function MonitorTreasures()
    if not Treasure then return end
    
    -- Initial scan
    for _, treasure in pairs(Treasure:GetChildren()) do
        table.insert(TreasureExploit.Treasures, treasure)
    end
    
    -- Monitor new treasures
    TreasureExploit.Connections.ChildAdded = Treasure.ChildAdded:Connect(function(treasure)
        table.insert(TreasureExploit.Treasures, treasure)
        
        -- Auto collect new treasure if enabled
        if TreasureExploit.AutoCollect and TreasureExploit.InstantCollect then
            CollectTreasure(treasure)
        end
    end)
    
    -- Clean up removed treasures
    TreasureExploit.Connections.ChildRemoved = Treasure.ChildRemoved:Connect(function(treasure)
        for i, t in pairs(TreasureExploit.Treasures) do
            if t == treasure then
                table.remove(TreasureExploit.Treasures, i)
                break
            end
        end
    end)
end

-- Collect all visible treasures
local function CollectAllTreasures()
    if not Treasure then return 0 end
    
    spawn(function()
        local count = 0
        for _, treasure in pairs(Treasure:GetChildren()) do
            CollectTreasure(treasure)
            count = count + 1
            task.wait(0.05)
        end
        print("[Treasure] Collected " .. count .. " treasures")
    end)
    
    return #Treasure:GetChildren()
end

-- Teleport to nearest treasure
local function TeleportToNearestTreasure()
    if not Treasure then return false end
    
    local character = LocalPlayer.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then return false end
    
    local nearest = nil
    local nearestDist = math.huge
    
    for _, treasure in pairs(Treasure:GetChildren()) do
        local part = treasure:IsA("Model") and treasure.PrimaryPart or treasure
        if part then
            local dist = (character.HumanoidRootPart.Position - part.Position).Magnitude
            if dist < nearestDist then
                nearest = treasure
                nearestDist = dist
            end
        end
    end
    
    if nearest then
        local part = nearest:IsA("Model") and nearest.PrimaryPart or nearest
        if part then
            character.HumanoidRootPart.CFrame = part.CFrame
            print("[Treasure] Teleported to " .. nearest.Name)
            return true
        end
    end
    
    return false
end

-- ========================================
-- JETPACK FUEL SYSTEM
-- ========================================

local UnlimitedFuelSystem = {}
UnlimitedFuelSystem.Methods = {}
UnlimitedFuelSystem.ActiveMethods = {}

-- Method 1: Direct Memory Manipulation
local function Method1_DirectMemoryHook()
    local success, err = pcall(function()
        -- Hook directly into the script environment
        local scriptEnv = getsenv(script)
        
        -- Create metatable hook for fuel variable
        local fuelMeta = {
            __index = function(t, k)
                if k == "var11_upvw" then
                    return 100 -- Always return max fuel
                end
                return rawget(t, k)
            end,
            __newindex = function(t, k, v)
                if k == "var11_upvw" then
                    rawset(t, k, 100) -- Force fuel to stay at 100
                    return
                end
                rawset(t, k, v)
            end
        }
        
        -- Apply metatable to environment
        setmetatable(scriptEnv, fuelMeta)
        
        -- Also hook the update function
        if scriptEnv.updateJetpack_upvr then
            local oldUpdate = scriptEnv.updateJetpack_upvr
            scriptEnv.updateJetpack_upvr = function(deltaTime)
                -- Temporarily set fuel to max before update
                local oldFuel = scriptEnv.var11_upvw
                scriptEnv.var11_upvw = 100
                
                -- Call original function
                local result = oldUpdate(deltaTime)
                
                -- Ensure fuel stays at max after update
                scriptEnv.var11_upvw = 100
                
                return result
            end
        end
        
        return true
    end)
    
    return success
end

-- Method 2: Constant Replacement Hook
local function Method2_ConstantReplacementHook()
    local success, err = pcall(function()
        -- Get all constants from the script
        local constants = debug.getconstants(getscriptclosure(script))
        
        -- Find and replace fuel-related constants
        for i, v in pairs(constants) do
            if type(v) == "number" then
                -- Replace fuel drain rate constants
                if v == 12 then -- Fuel drain rate
                    debug.setconstant(getscriptclosure(script), i, 0)
                elseif v == 10 then -- Fuel recharge rate
                    debug.setconstant(getscriptclosure(script), i, 1000)
                end
            end
        end
        
        -- Hook upvalues
        local upvalues = debug.getupvalues(getscriptclosure(script))
        for i, v in pairs(upvalues) do
            if type(v) == "number" and v <= 100 then
                debug.setupvalue(getscriptclosure(script), i, 100)
            end
        end
        
        return true
    end)
    
    return success
end

-- Method 3: Function Detouring
local function Method3_FunctionDetour()
    local success, err = pcall(function()
        local scriptEnv = getsenv(script)
        
        -- Find all functions that modify fuel
        for name, func in pairs(scriptEnv) do
            if type(func) == "function" then
                local info = debug.getinfo(func)
                local constants = debug.getconstants(func)
                
                -- Check if function contains fuel-related operations
                local isFuelFunction = false
                for _, constant in pairs(constants) do
                    if constant == "var11_upvw" or constant == 12 or constant == 100 then
                        isFuelFunction = true
                        break
                    end
                end
                
                if isFuelFunction then
                    -- Detour the function
                    local oldFunc = func
                    scriptEnv[name] = function(...)
                        -- Pre-execution: Set fuel to max
                        if scriptEnv.var11_upvw then
                            scriptEnv.var11_upvw = 100
                        end
                        
                        -- Execute original
                        local results = {oldFunc(...)}
                        
                        -- Post-execution: Restore fuel to max
                        if scriptEnv.var11_upvw then
                            scriptEnv.var11_upvw = 100
                        end
                        
                        return unpack(results)
                    end
                end
            end
        end
        
        return true
    end)
    
    return success
end

-- Method 4: UI Component Hijacking
local function Method5_UIHijack()
    local success, err = pcall(function()
        local MainGui = LocalPlayer.PlayerGui:WaitForChild("MainGui", 5)
        if MainGui then
            local JetpackFrame = MainGui:FindFirstChild("JetpackFrame")
            if JetpackFrame then
                local Stamina = JetpackFrame:FindFirstChild("Stamina")
                local StaminaText = JetpackFrame:FindFirstChild("StaminaText")
                
                -- Override UI updates to always show full
                if Stamina then
                    local mt = getmetatable(Stamina)
                    if not mt then mt = {} end
                    
                    mt.__newindex = function(t, k, v)
                        if k == "Size" then
                            rawset(t, k, UDim2.new(1, 0, 1, 0)) -- Always full bar
                        else
                            rawset(t, k, v)
                        end
                    end
                    
                    setmetatable(Stamina, mt)
                end
                
                if StaminaText then
                    local mt = getmetatable(StaminaText)
                    if not mt then mt = {} end
                    
                    mt.__newindex = function(t, k, v)
                        if k == "Text" then
                            rawset(t, k, "100%") -- Always show 100%
                        else
                            rawset(t, k, v)
                        end
                    end
                    
                    setmetatable(StaminaText, mt)
                end
            end
        end
        
        return true
    end)
    
    return success
end

-- Method 5: Remote Intercept (if fuel is server-sided)
local function Method6_RemoteIntercept()
    local success, err = pcall(function()
        local mt = getrawmetatable(game)
        local oldNamecall = mt.__namecall
        setreadonly(mt, false)
        
        mt.__namecall = newcclosure(function(self, ...)
            local args = {...}
            local method = getnamecallmethod()
            
            -- Intercept fuel-related remotes
            if method == "FireServer" or method == "InvokeServer" then
                local remoteName = tostring(self)
                
                -- Check for fuel-related remotes
                if remoteName:find("Fuel") or remoteName:find("Stamina") or remoteName:find("Jetpack") then
                    -- Modify arguments to always send max fuel
                    for i, arg in pairs(args) do
                        if type(arg) == "number" and arg <= 100 then
                            args[i] = 100
                        end
                    end
                    
                    return oldNamecall(self, unpack(args))
                end
            end
            
            return oldNamecall(self, ...)
        end)
        
        setreadonly(mt, true)
        return true
    end)
    
    return success
end

-- Method 6: Coroutine Injection
local function Method7_CoroutineInjection()
    local success, err = pcall(function()
        -- Create a coroutine that constantly resets fuel
        local fuelCoroutine = coroutine.create(function()
            while true do
                local scriptEnv = getsenv(script)
                
                -- Multiple fuel variable names that might be used
                local fuelVars = {"var11_upvw", "var11", "stamina", "fuel"}
                
                for _, varName in pairs(fuelVars) do
                    if scriptEnv[varName] ~= nil and type(scriptEnv[varName]) == "number" then
                        scriptEnv[varName] = 100
                    end
                end
                
                -- Also check for cooldown variables
                local cooldownVars = {"var13_upvw", "var13", "cooldown", "rechargeTime"}
                
                for _, varName in pairs(cooldownVars) do
                    if scriptEnv[varName] ~= nil and type(scriptEnv[varName]) == "number" then
                        scriptEnv[varName] = 0
                    end
                end
                
                coroutine.yield()
            end
        end)
        
        -- Resume coroutine every frame
        RunService.Heartbeat:Connect(function()
            if coroutine.status(fuelCoroutine) ~= "dead" then
                coroutine.resume(fuelCoroutine)
            end
        end)
        
        return true
    end)
    
    return success
end

function UnlimitedFuelSystem:Initialize()
    print("[Unlimited Fuel] Initializing advanced fuel system...")
    
    -- Clear previous methods
    self.ActiveMethods = {}
    
    -- Try each method and track which ones succeed
    local methods = {
        {name = "Direct Memory Hook", func = Method1_DirectMemoryHook},
        {name = "Constant Replacement", func = Method2_ConstantReplacementHook},
        {name = "Function Detour", func = Method3_FunctionDetour},
        {name = "UI Hijack", func = Method5_UIHijack},
        {name = "Remote Intercept", func = Method6_RemoteIntercept},
        {name = "Coroutine Injection", func = Method7_CoroutineInjection}
    }
    
    for _, method in pairs(methods) do
        local success = method.func()
        if success then
            table.insert(self.ActiveMethods, method.name)
            print("[Unlimited Fuel] ✅ " .. method.name .. " activated successfully")
        else
            print("[Unlimited Fuel] ❌ " .. method.name .. " failed to activate")
        end
    end
    
    -- Additional runtime enforcement
    self:StartRuntimeEnforcement()
    
    print("[Unlimited Fuel] System initialized with " .. #self.ActiveMethods .. " active methods")
    return #self.ActiveMethods > 0
end

function UnlimitedFuelSystem:StartRuntimeEnforcement()
    -- Continuous enforcement to ensure fuel stays unlimited
    RunService.Heartbeat:Connect(function()
        if not JetpackExploit.InfiniteFuel then return end
        
        -- Method 1: Direct variable enforcement
        local scriptEnv = getsenv(script)
        if scriptEnv then
            if scriptEnv.var11_upvw and type(scriptEnv.var11_upvw) == "number" then
                scriptEnv.var11_upvw = 100
            end
            if scriptEnv.var13_upvw and type(scriptEnv.var13_upvw) == "number" then
                scriptEnv.var13_upvw = 0
            end
        end
        
        -- Method 2: Attribute enforcement
        if LocalPlayer:GetAttribute("InfiniteFuel") ~= true then
            LocalPlayer:SetAttribute("InfiniteFuel", true)
        end
        
        -- Method 3: UI enforcement
        local MainGui = LocalPlayer.PlayerGui:FindFirstChild("MainGui")
        if MainGui then
            local JetpackFrame = MainGui:FindFirstChild("JetpackFrame")
            if JetpackFrame then
                local Stamina = JetpackFrame:FindFirstChild("Stamina")
                if Stamina then
                    Stamina.Size = UDim2.new(1, 0, 1, 0)
                end
                
                local StaminaText = JetpackFrame:FindFirstChild("StaminaText")
                if StaminaText then
                    StaminaText.Text = "100%"
                end
            end
        end
        
        -- Update status text
        if JetpackExploit.InfiniteFuel then
            LocalPlayer:SetAttribute("InfiniteFuel", true)
        else
            LocalPlayer:SetAttribute("InfiniteFuel", false)
        end
    end)
end

function UnlimitedFuelSystem:Stop()
    JetpackExploit.InfiniteFuel = false
    LocalPlayer:SetAttribute("InfiniteFuel", false)
end

-- ========================================
-- DIG EXPLOIT FUNCTIONS (Original)
-- ========================================

-- Auto detect any tool in character
local function WaitForTool()
    local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    
    -- First, check if player is already holding a tool
    for _, item in pairs(character:GetChildren()) do
        if item:IsA("Tool") then
            return item
        end
    end
    
    -- If no tool equipped, check backpack
    local backpack = LocalPlayer:WaitForChild("Backpack", 5)
    if backpack then
        for _, item in pairs(backpack:GetChildren()) do
            if item:IsA("Tool") then
                -- Try to equip the tool
                pcall(function()
                    LocalPlayer.Character.Humanoid:EquipTool(item)
                end)
                return item
            end
        end
    end
    
    -- Wait for any tool to be equipped
    local connection
    local tool = nil
    
    connection = character.ChildAdded:Connect(function(child)
        if child:IsA("Tool") then
            tool = child
            connection:Disconnect()
        end
    end)
    
    -- Wait up to 10 seconds for a tool
    local startTime = tick()
    while not tool and tick() - startTime < 10 do
        task.wait(0.1)
    end
    
    if connection then
        connection:Disconnect()
    end
    
    if not tool then
        warn("[Dig Exploit] No tool found in character or backpack")
    end
    
    return tool
end

-- Get DigModule
local DigModule
pcall(function()
    DigModule = require(ReplicatedStorage:WaitForChild("DigModule"))
end)

-- Hook into AutoDig value
local function SetupAutoDigHook()
    -- Create AutoDig value if it doesn't exist
    if not LocalPlayer:FindFirstChild("AutoDig") then
        local autoDigValue = Instance.new("BoolValue")
        autoDigValue.Name = "AutoDig"
        autoDigValue.Value = false
        autoDigValue.Parent = LocalPlayer
    end
    
    -- Set InstantDig attribute
    LocalPlayer:SetAttribute("InstantDig", true)
end

-- Bypass terrain check
local function BypassTerrainCheck()
    local mt = getrawmetatable(game)
    local oldNamecall = mt.__namecall
    setreadonly(mt, false)
    
    mt.__namecall = newcclosure(function(self, ...)
        local method = getnamecallmethod()
        local args = {...}
        
        -- Intercept FindPartOnRayWithIgnoreList to always return valid terrain
        if method == "FindPartOnRayWithIgnoreList" and DigExploit.BypassChecks then
            return workspace.Terrain, Vector3.new(0, 0, 0), Vector3.new(0, 1, 0), Enum.Material.Grass
        end
        
        return oldNamecall(self, ...)
    end)
    
    setreadonly(mt, true)
end

-- Auto teleport under map
-- Auto teleport feature removed

-- Auto Cash Function
local function StartAutoCash()
    spawn(function()
        while DigExploit.AutoCash do
            if RemoteCache.DigEvent then
                pcall(function()
                    RemoteCache.DigEvent:FireServer("hello")
                end)
            end
            task.wait(DigExploit.CashSpeed)
        end
    end)
end

-- Auto Gems Function
local function StartAutoGems()
    spawn(function()
        while DigExploit.AutoGems do
            if RemoteCache.GemEvent then
                pcall(function()
                    RemoteCache.GemEvent:FireServer(14, "bye")
                end)
            end
            task.wait(DigExploit.GemsSpeed)
        end
    end)
end

-- ========================================
-- AUTO WIN SYSTEM (from autowin.lua)
-- ========================================

-- Detect current world (multiple heuristics)
local function GetCurrentWorld()
    local leaderstats = LocalPlayer:FindFirstChild("leaderstats")
    if leaderstats then
        local world = leaderstats:FindFirstChild("World") or leaderstats:FindFirstChild("Stage") or leaderstats:FindFirstChild("Level")
        if world and world.Value then
            return tonumber(world.Value) or 1
        end
    end

    local worldAttr = LocalPlayer:GetAttribute("CurrentWorld") or LocalPlayer:GetAttribute("World") or LocalPlayer:GetAttribute("Stage") or LocalPlayer:GetAttribute("Level")
    if worldAttr then
        return tonumber(worldAttr) or 1
    end

    for _, child in pairs(LocalPlayer:GetChildren()) do
        if child:IsA("IntValue") or child:IsA("NumberValue") then
            local name = child.Name:lower()
            if name:find("world") or name:find("stage") or name:find("level") or name:find("current") then
                return tonumber(child.Value) or 1
            end
        end
    end

    local character = LocalPlayer.Character
    if character and character:FindFirstChild("HumanoidRootPart") then
        local playerPos = character.HumanoidRootPart.Position
        local closestWorld, closestDistance = 1, math.huge
        for i = 1, 100 do
            local worldObj = workspace:FindFirstChild("World" .. i) or workspace:FindFirstChild("Stage" .. i) or workspace:FindFirstChild("Level" .. i)
            if worldObj then
                local worldPart = worldObj:FindFirstChildWhichIsA("BasePart", true)
                if worldPart then
                    local distance = (worldPart.Position - playerPos).Magnitude
                    if distance < closestDistance then
                        closestDistance = distance
                        closestWorld = i
                    end
                end
            end
        end
        if closestDistance < 1000 then
            return closestWorld
        end
    end

    pcall(function()
        local playerData = ReplicatedStorage:FindFirstChild("PlayerData") or ReplicatedStorage:FindFirstChild("Players")
        if playerData then
            local myData = playerData:FindFirstChild(LocalPlayer.Name)
            if myData then
                local world = myData:FindFirstChild("World") or myData:FindFirstChild("Stage")
                if world and world.Value then
                    AutoWin.CurrentWorld = tonumber(world.Value) or AutoWin.CurrentWorld
                end
            end
        end
    end)

    return AutoWin.CurrentWorld
end

-- Find win / finish part for a world
local function FindWinPart(worldNumber)
    local worldNames = {
        "World" .. worldNumber,
        "Stage" .. worldNumber,
        "Level" .. worldNumber,
        "Zone" .. worldNumber,
        "Area" .. worldNumber
    }
    for _, worldName in pairs(worldNames) do
        local worldObj = workspace:FindFirstChild(worldName)
        if worldObj then
            local winPartNames = {"WinPart","Win","EndPart","End","Finish","FinishPart","Goal","GoalPart","Complete","CompletePart","Exit","ExitPart","Victory","VictoryPart","Portal","Teleport","Next"}
            for _, partName in pairs(winPartNames) do
                local winPart = worldObj:FindFirstChild(partName, true)
                if winPart and winPart:IsA("BasePart") then
                    return winPart, worldObj
                end
            end
            for _, part in pairs(worldObj:GetDescendants()) do
                if part:IsA("BasePart") then
                    if part.BrickColor == BrickColor.new("Lime green") or part.BrickColor == BrickColor.new("Bright green") or part.Material == Enum.Material.Neon or (part.Size.Y < 2 and part.Size.X > 5 and part.Size.Z > 5) then
                        return part, worldObj
                    end
                end
            end
        end
    end
    return nil, nil
end

-- Continuous teleport
local function StartAutoWin()
    if AutoWin.Active then return end
    AutoWin.Active = true
    AutoWin.Connection = RunService.Heartbeat:Connect(function()
        if not AutoWin.Active then
            if AutoWin.Connection then AutoWin.Connection:Disconnect() AutoWin.Connection = nil end
            return
        end
        AutoWin.CurrentWorld = GetCurrentWorld()
        local winPart, worldObj = FindWinPart(AutoWin.CurrentWorld)
        if winPart then
            local character = LocalPlayer.Character
            if character and character:FindFirstChild("HumanoidRootPart") then
                local targetCFrame = winPart.CFrame + Vector3.new(0, winPart.Size.Y/2 + 3, 0)
                character.HumanoidRootPart.CFrame = targetCFrame
                character.HumanoidRootPart.Velocity = Vector3.new(0,0,0)
                -- fire touch interest a few times
                for i=1,2 do
                    pcall(function()
                        firetouchinterest(character.HumanoidRootPart, winPart, 0)
                        task.wait()
                        firetouchinterest(character.HumanoidRootPart, winPart, 1)
                    end)
                end
                for _, part in pairs(character:GetChildren()) do
                    if part:IsA("BasePart") and part ~= character.HumanoidRootPart then
                        pcall(function()
                            firetouchinterest(part, winPart, 0)
                            firetouchinterest(part, winPart, 1)
                        end)
                    end
                end
                -- Attempt to fire related remotes
                pcall(function()
                    local remotes = ReplicatedStorage:FindFirstChild("Remotes") or ReplicatedStorage
                    for _, remote in pairs(remotes:GetChildren()) do
                        if remote:IsA("RemoteEvent") then
                            local name = remote.Name:lower()
                            if name:find("win") or name:find("complete") or name:find("finish") or name:find("touch") then
                                remote:FireServer(AutoWin.CurrentWorld)
                                remote:FireServer(winPart)
                                remote:FireServer(worldObj)
                            end
                        end
                    end
                end)
            end
        end
    end)
end

local function StopAutoWin()
    AutoWin.Active = false
    if AutoWin.Connection then
        AutoWin.Connection:Disconnect()
        AutoWin.Connection = nil
    end
end

-- Enhanced dig function
local function PerformDig(tool)
    if not tool or not tool.Parent then
        return false
    end
    
    -- Method 1: Direct module call (if available)
    if DigModule then
        pcall(function()
            DigModule.Dig(LocalPlayer, tool, function() end)
            if DigModule.PlayAnimation then
                DigModule.PlayAnimation(tool)
            end
        end)
    end
    
    -- Method 2: Fire tool events directly
    pcall(function()
        if tool.Activated then
            tool.Activated:Fire()
        end
        task.wait(0.01)
        if tool.Deactivated then
            tool.Deactivated:Fire()
        end
    end)
    
    -- Method 3: Simulate tool activation
    pcall(function()
        if tool.Activate then
            tool:Activate()
        end
    end)
    
    -- Method 4: Fire RemoteEvents if tool has them
    pcall(function()
        for _, descendant in pairs(tool:GetDescendants()) do
            if descendant:IsA("RemoteEvent") and descendant.Name:lower():find("dig") then
                descendant:FireServer()
            elseif descendant:IsA("RemoteFunction") and descendant.Name:lower():find("dig") then
                descendant:InvokeServer()
            end
        end
    end)
    
    -- Method 5: Simulate mouse input for LocalScripts
    if DigExploit.InstantDig then
        pcall(function()
            for _, script in pairs(tool:GetDescendants()) do
                if script:IsA("LocalScript") then
                    local env = getsenv and getsenv(script)
                    if env then
                        -- Try common dig function names
                        local digFunctions = {"dig", "Dig", "startDig", "onActivated", "onClick"}
                        for _, funcName in pairs(digFunctions) do
                            if env[funcName] and type(env[funcName]) == "function" then
                                env[funcName]()
                                break
                            end
                        end
                    end
                end
            end
        end)
    end
    
    return true
end

-- Main dig loop
local function StartDigLoop()
    DigExploit.Active = true
    
    spawn(function()
        while DigExploit.Active do
            local tool = WaitForTool()
            
            if tool then
                PerformDig(tool)
            else
                -- If no tool found, wait a bit longer before trying again
                task.wait(1)
            end
            
            task.wait(DigExploit.DigSpeed)
        end
    end)
end

local function StopDigLoop()
    DigExploit.Active = false
    
    if LocalPlayer:FindFirstChild("AutoDig") then
        LocalPlayer.AutoDig.Value = false
    end
end

-- UI Creation with new API
local function CreateUI()
    -- Load improved 0verflow Hub UI
    local UILib = loadstring(game:HttpGet('https://raw.githubusercontent.com/pwd0kernel/0verflow/refs/heads/main/ui2.lua'))()
    local Window = UILib:CreateWindow("   Dig to Earth's Core")

    -- Main Tab (Dig Exploit)
    local MainTab = Window:Tab("Dig")
    
    -- Features Section
    local FeaturesSection = MainTab:Section("Core Features")
    
    DigExploit.Toggles.AutoDig = FeaturesSection:Toggle("Auto Dig", function(value)
        if value then
            StartDigLoop()
            Window:Notify("Auto Dig started", 2)
        else
            StopDigLoop()
            Window:Notify("Auto Dig stopped", 2)
        end
    end, {
        default = false,
        keybind = Enum.KeyCode.F1,
        color = Color3.fromRGB(80, 250, 150)
    })
    
    DigExploit.Toggles.InstantDig = FeaturesSection:Toggle("Instant Dig", function(value)
        DigExploit.InstantDig = value
        LocalPlayer:SetAttribute("InstantDig", value)
    end, {
        default = false,
        keybind = Enum.KeyCode.F2,
        color = Color3.fromRGB(255, 200, 100)
    })
    
    DigExploit.Toggles.BypassChecks = FeaturesSection:Toggle("Bypass Checks", function(value)
        DigExploit.BypassChecks = value
        if value then
            BypassTerrainCheck()
        end
    end, {
        default = false,
        keybind = Enum.KeyCode.F3,
        color = Color3.fromRGB(255, 100, 100)
    })
    
    -- Auto Teleport toggle removed
    
    -- Settings Section
    local SettingsSection = MainTab:Section("Settings")
    
    -- Sliders for settings
    SettingsSection:Slider("Dig Speed (ms)", 10, 1000, 10, function(value)
        DigExploit.DigSpeed = value / 1000
    end)
    
    -- Teleport Wait slider removed
    
    -- JETPACK TAB (NEW)
    local JetpackTab = Window:Tab("Jetpack")
    
    -- Jetpack Features Section
    local JetpackFeaturesSection = JetpackTab:Section("Jetpack Features")
    
    JetpackExploit.Toggles.InfiniteFuel = JetpackFeaturesSection:Toggle("Infinite Jetpack Fuel", function(value)
        JetpackExploit.InfiniteFuel = value
        if value then
            local success = UnlimitedFuelSystem:Initialize()
            if success then
                Window:Notify("Infinite Fuel activated with " .. #UnlimitedFuelSystem.ActiveMethods .. " methods!", 3)
            else
                Window:Notify("Failed to activate Infinite Fuel", 3)
            end
        else
            UnlimitedFuelSystem:Stop()
            Window:Notify("Infinite Fuel deactivated", 2)
        end
    end, {
        default = false,
        keybind = Enum.KeyCode.F8,
        color = Color3.fromRGB(100, 200, 255)
    })
    
    -- Quick Actions
    local JetpackQuickSection = JetpackTab:Section("Quick Actions")
    
    JetpackQuickSection:Button("Force Refresh Fuel System", function()
        if JetpackExploit.InfiniteFuel then
            UnlimitedFuelSystem:Initialize()
            Window:Notify("Fuel system refreshed", 2)
        else
            Window:Notify("Enable Infinite Fuel first", 2)
        end
    end)
    
    JetpackQuickSection:Button("Reset Fuel to Max", function()
        pcall(function()
            local scriptEnv = getsenv(script)
            if scriptEnv then
                scriptEnv.var11_upvw = 100
                scriptEnv.var13_upvw = 0
            end
            LocalPlayer:SetAttribute("InfiniteFuel", true)
        end)
        Window:Notify("Fuel reset to maximum", 2)
    end)
    
    -- FARMING TAB
    local FarmingTab = Window:Tab("Farming")
    
    -- Auto Farm Section
    local AutoFarmSection = FarmingTab:Section("Auto Farm")
    
    DigExploit.Toggles.AutoCash = AutoFarmSection:Toggle("Auto Cash", function(value)
        DigExploit.AutoCash = value
        if value then
            StartAutoCash()
            Window:Notify("Auto Cash farming started", 2)
        else
            Window:Notify("Auto Cash farming stopped", 2)
        end
    end, {
        default = false,
        keybind = Enum.KeyCode.F6,
        color = Color3.fromRGB(100, 255, 100)
    })
    
    DigExploit.Toggles.AutoGems = AutoFarmSection:Toggle("Auto Gems", function(value)
        DigExploit.AutoGems = value
        if value then
            StartAutoGems()
            Window:Notify("Auto Gems farming started", 2)
        else
            Window:Notify("Auto Gems farming stopped", 2)
        end
    end, {
        default = false,
        keybind = Enum.KeyCode.F7,
        color = Color3.fromRGB(100, 200, 255)
    })

    -- Auto Win Toggle (new)
    AutoWin.Toggles.AutoWin = AutoFarmSection:Toggle("Auto Win", function(value)
        if value then
            StartAutoWin()
            Window:Notify("Auto Win started", 2)
        else
            StopAutoWin()
            Window:Notify("Auto Win stopped", 2)
        end
    end, {
        default = false,
        color = Color3.fromRGB(180, 255, 120)
    })
    
    -- Informational label about Auto Win behavior
    AutoFarmSection:Label("Note: Auto Win has a server cooldown; progression may appear slow.")
    
    -- Farm Settings Section
    local FarmSettingsSection = FarmingTab:Section("Farm Settings")
    
    FarmSettingsSection:Slider("Cash Speed (ms)", 10, 1000, 50, function(value)
        DigExploit.CashSpeed = value / 1000
    end)
    
    FarmSettingsSection:Slider("Gems Speed (ms)", 10, 1000, 50, function(value)
        DigExploit.GemsSpeed = value / 1000
    end)
    
    -- Quick Actions
    local QuickActionsSection = FarmingTab:Section("Quick Actions")
    
    QuickActionsSection:Button("Enable All Farming", function()
        if DigExploit.Toggles.AutoCash then
            DigExploit.Toggles.AutoCash:Set(true)
        end
        if DigExploit.Toggles.AutoGems then
            DigExploit.Toggles.AutoGems:Set(true)
        end
        Window:Notify("All farming enabled", 2)
    end)
    
    QuickActionsSection:Button("Disable All Farming", function()
        if DigExploit.Toggles.AutoCash then
            DigExploit.Toggles.AutoCash:Set(false)
        end
        if DigExploit.Toggles.AutoGems then
            DigExploit.Toggles.AutoGems:Set(false)
        end
        Window:Notify("All farming disabled", 2)
    end)
    
    QuickActionsSection:Button("Ultra Fast Mode", function()
        DigExploit.CashSpeed = 0.01
        DigExploit.GemsSpeed = 0.01
        Window:Notify("Ultra fast mode enabled", 2)
    end)
    
    -- SPIN WHEEL TAB (NEW)
    local SpinTab = Window:Tab("Spin Wheel")
    
    -- Spin Features Section
    local SpinFeaturesSection = SpinTab:Section("Spin Features")
    
    SpinFeaturesSection:Button("Claim 10 Free Jackpots", function()
        if not SpinExploit.FreeSpinsActive then
            ClaimFreeSpins()
            Window:Notify("Claiming 10 jackpots...", 3)
        else
            Window:Notify("Already claiming! Wait...", 2)
        end
    end)
    
    SpinExploit.Toggles.AutoSpin = SpinFeaturesSection:Toggle("Auto Spin (Instant)", function(value)
        SpinExploit.AutoSpin = value
        if value then
            StartAutoSpin()
            Window:Notify("Auto Spin started (instant mode)", 2)
        else
            Window:Notify("Auto Spin stopped", 2)
        end
    end, {
        default = false,
        color = Color3.fromRGB(255, 150, 50)
    })
    
    SpinExploit.Toggles.AutoClaimFreeSpins = SpinFeaturesSection:Toggle("Auto Free Jackpots", function(value)
        SpinExploit.AutoClaimFreeSpins = value
        if value then
            StartAutoClaimFreeSpins()
            Window:Notify("Auto free jackpots started", 2)
        else
            Window:Notify("Auto free jackpots stopped", 2)
        end
    end, {
        default = false,
        color = Color3.fromRGB(150, 255, 150)
    })
    
    -- Quick Spin Actions Section
    local QuickSpinActionsSection = SpinTab:Section("Quick Actions")
    
    QuickSpinActionsSection:Button("Instant Spin (Random)", function()
        InstantSpin(nil)
        Window:Notify("Instant spin completed", 1)
    end)
    
    QuickSpinActionsSection:Button("Instant Jackpot", function()
        InstantSpin(8)
        Window:Notify("Jackpot claimed!", 2)
    end)
    
    QuickSpinActionsSection:Button("Instant OP Pet", function()
        InstantSpin(4)
        Window:Notify("OP Pet claimed!", 2)
    end)
    
    QuickSpinActionsSection:Button("Reset Spin State", function()
        ResetSpinState()
        Window:Notify("Spin state reset", 1)
    end)
    
    QuickSpinActionsSection:Button("Enable All Spin Features", function()
        if SpinExploit.Toggles.AutoSpin then
            SpinExploit.Toggles.AutoSpin:Set(true)
        end
        if SpinExploit.Toggles.AutoClaimFreeSpins then
            SpinExploit.Toggles.AutoClaimFreeSpins:Set(true)
        end
        Window:Notify("All spin features enabled", 2)
    end)
    
    QuickSpinActionsSection:Button("Disable All Spin Features", function()
        if SpinExploit.Toggles.AutoSpin then
            SpinExploit.Toggles.AutoSpin:Set(false)
        end
        if SpinExploit.Toggles.AutoClaimFreeSpins then
            SpinExploit.Toggles.AutoClaimFreeSpins:Set(false)
        end
        Window:Notify("All spin features disabled", 2)
    end)
    
    -- TREASURE TAB (NEW)
    local TreasureTab = Window:Tab("Treasure")
    
    -- Treasure Features Section
    local TreasureFeaturesSection = TreasureTab:Section("Treasure Features")
    
    TreasureExploit.Toggles.AutoCollect = TreasureFeaturesSection:Toggle("Auto Collect", function(value)
        TreasureExploit.AutoCollect = value
        if value then
            StartAutoCollectTreasures()
            Window:Notify("Auto Collect started", 2)
        else
            Window:Notify("Auto Collect stopped", 2)
        end
    end, {
        default = false,
        color = Color3.fromRGB(255, 215, 0)
    })
    
    TreasureExploit.Toggles.InstantCollect = TreasureFeaturesSection:Toggle("Instant Collect", function(value)
        TreasureExploit.InstantCollect = value
        Window:Notify(value and "Instant Collect enabled (no distance check)" or "Instant Collect disabled", 2)
    end, {
        default = false,
        color = Color3.fromRGB(255, 100, 100)
    })
    
    TreasureExploit.Toggles.BypassDebounce = TreasureFeaturesSection:Toggle("Bypass Debounce", function(value)
        TreasureExploit.BypassDebounce = value
        if value then
            BypassDebounce()
            Window:Notify("Debounce bypass enabled", 2)
        else
            Window:Notify("Debounce bypass disabled", 2)
        end
    end, {
        default = false,
        color = Color3.fromRGB(255, 150, 50)
    })
    
    -- Treasure Actions Section
    local TreasureActionsSection = TreasureTab:Section("Quick Actions")
    
    TreasureActionsSection:Button("Collect All Visible", function()
        local count = CollectAllTreasures()
        Window:Notify("Collecting " .. count .. " treasures...", 2)
    end)
    
    TreasureActionsSection:Button("Teleport to Nearest", function()
        local success = TeleportToNearestTreasure()
        if success then
            Window:Notify("Teleported to nearest treasure", 2)
        else
            Window:Notify("No treasures found", 2)
        end
    end)
    
    TreasureActionsSection:Button("Enable All Treasure Features", function()
        if TreasureExploit.Toggles.AutoCollect then
            TreasureExploit.Toggles.AutoCollect:Set(true)
        end
        if TreasureExploit.Toggles.InstantCollect then
            TreasureExploit.Toggles.InstantCollect:Set(true)
        end
        if TreasureExploit.Toggles.BypassDebounce then
            TreasureExploit.Toggles.BypassDebounce:Set(true)
        end
        Window:Notify("All treasure features enabled", 2)
    end)
    
    TreasureActionsSection:Button("Disable All Treasure Features", function()
        if TreasureExploit.Toggles.AutoCollect then
            TreasureExploit.Toggles.AutoCollect:Set(false)
        end
        if TreasureExploit.Toggles.InstantCollect then
            TreasureExploit.Toggles.InstantCollect:Set(false)
        end
        if TreasureExploit.Toggles.BypassDebounce then
            TreasureExploit.Toggles.BypassDebounce:Set(false)
        end
        Window:Notify("All treasure features disabled", 2)
    end)
    
    TreasureActionsSection:Button("Show Treasure Stats", function()
        local available = Treasure and #Treasure:GetChildren() or 0
        local statsMsg = string.format(
            "Collected: %d\nAvailable: %d\nAuto Collect: %s",
            TreasureExploit.CollectedCount,
            available,
            TreasureExploit.AutoCollect and "Active" or "Inactive"
        )
        Window:Notify(statsMsg, 4)
    end)
    
    -- Info Tab
    local InfoTab = Window:Tab("Info")
    
    local InfoSection = InfoTab:Section("Script Information")
    
    InfoSection:Label("0verflow Hub v1.0.0")
    InfoSection:Label("Author: buffer_0verflow")
    InfoSection:Label("Updated: 2025-08-09 00:23:24")
    InfoSection:Label("Features: Dig + Jetpack + Farming + Spin + Treasure")
    
    local ControlsSection = InfoTab:Section("Keybinds")
    
    ControlsSection:Label("F1 - Toggle Auto Dig")
    ControlsSection:Label("F2 - Toggle Instant Dig")
    ControlsSection:Label("F3 - Toggle Bypass")
    -- Removed F5 Auto Teleport keybind label
    ControlsSection:Label("F6 - Toggle Auto Cash")
    ControlsSection:Label("F7 - Toggle Auto Gems")
    ControlsSection:Label("F8 - Toggle Infinite Jetpack Fuel")
    
    -- Discord Section
    local DiscordSection = InfoTab:Section("Community")
    
    DiscordSection:Button("Join Our Discord", function()
        pcall(function()
            setclipboard("https://discord.gg/QmRXz3n9HQ")
            Window:Notify("Discord invite copied! Paste in browser to join.", 4)
        end)
    end)
    
    DiscordSection:Label("Discord: discord.gg/QmRXz3n9HQ")
    DiscordSection:Label("Get support, updates, and community!")
    
    return Window
end

-- Initialize
SetupAutoDigHook()
CacheRemotes()
InitializeSpinComponents()
InitializeTreasureComponents()
MonitorTreasures()
local UI = CreateUI()

-- Notify user
UI:Notify("0verflow Hub v1.0.0 Loaded", 3)

-- Auto-start if configured
if _G.AutoStartDig then
    StartDigLoop()
end

if _G.AutoStartFarm then
    if DigExploit.Toggles.AutoCash then
        DigExploit.Toggles.AutoCash:Set(true)
    end
    if DigExploit.Toggles.AutoGems then
        DigExploit.Toggles.AutoGems:Set(true)
    end
end

if _G.AutoStartJetpack then
    if JetpackExploit.Toggles.InfiniteFuel then
        JetpackExploit.Toggles.InfiniteFuel:Set(true)
    end
end

-- Return API for external use
return {
    -- Dig Functions
    Start = StartDigLoop,
    Stop = StopDigLoop,
    PerformDig = PerformDig,
    -- Farm Functions
    StartCash = function()
        DigExploit.AutoCash = true
        StartAutoCash()
    end,
    StopCash = function()
        DigExploit.AutoCash = false
    end,
    StartGems = function()
        DigExploit.AutoGems = true
        StartAutoGems()
    end,
    StopGems = function()
        DigExploit.AutoGems = false
    end,
    -- Jetpack Functions
    StartInfiniteFuel = function()
        JetpackExploit.InfiniteFuel = true
        return UnlimitedFuelSystem:Initialize()
    end,
    StopInfiniteFuel = function()
        UnlimitedFuelSystem:Stop()
    end,
    GetFuelStatus = function()
        return {
            active = JetpackExploit.InfiniteFuel,
            methods = UnlimitedFuelSystem.ActiveMethods
        }
    end,
    -- Spin Functions
    ClaimFreeSpins = ClaimFreeSpins,
    InstantSpin = InstantSpin,
    StartAutoSpin = function()
        SpinExploit.AutoSpin = true
        StartAutoSpin()
    end,
    StopAutoSpin = function()
        SpinExploit.AutoSpin = false
    end,
    StartAutoClaimFreeSpins = function()
        SpinExploit.AutoClaimFreeSpins = true
        StartAutoClaimFreeSpins()
    end,
    StopAutoClaimFreeSpins = function()
        SpinExploit.AutoClaimFreeSpins = false
    end,
    -- Treasure Functions
    StartTreasureCollect = function()
        TreasureExploit.AutoCollect = true
        StartAutoCollectTreasures()
    end,
    StopTreasureCollect = function()
        TreasureExploit.AutoCollect = false
    end,
    CollectAllTreasures = CollectAllTreasures,
    TeleportToNearestTreasure = TeleportToNearestTreasure,
    GetTreasureStats = function()
        return {
            collected = TreasureExploit.CollectedCount,
            available = Treasure and #Treasure:GetChildren() or 0,
            active = TreasureExploit.AutoCollect
        }
    end,
    -- Auto Win Functions
    StartAutoWin = function()
        AutoWin.Active = true
        StartAutoWin()
    end,
    StopAutoWin = function()
        StopAutoWin()
    end,
    GetCurrentWorld = function()
        return AutoWin.CurrentWorld
    end
}
