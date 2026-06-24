local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer

local Fsys = require(ReplicatedStorage:WaitForChild("Fsys"))
local LoadModule = Fsys.load

-- Get router client upvalue
local RouterClient = LoadModule("RouterClient")
local routerClientUpvalue = debug.getupvalue(RouterClient.init, 4)
local originalRoutes = {}

if not getgenv().OriginalRoutes_Loaded then
    for routeName, route in pairs(routerClientUpvalue) do
        if type(route) == "table" then -- skip functions from previous hook
            route.Name = routeName
            originalRoutes[routeName] = route
        end
    end
    getgenv().OriginalRoutes_Loaded = true
    getgenv().CachedOriginalRoutes = originalRoutes
else
    originalRoutes = getgenv().CachedOriginalRoutes
end

-- Load UI Manager and get trade license
local UIManager = LoadModule("UIManager")
local ClientData = LoadModule("ClientData")
local Maid = LoadModule("Maid")
local TweenPromise = LoadModule("TweenPromise")
local Promise = LoadModule("package:Promise")
local CharacterHider = LoadModule("CharacterHider")
local CharacterScale = LoadModule("CharacterScale")
local GameplayFX = LoadModule("GameplayFX")
local SoundPlayer = LoadModule("SoundPlayer")
local SoundDB = LoadModule("SoundDB")
local Music = LoadModule("Music")

local inventory = ClientData.get("inventory").toys
local tradeLicenseKey = nil
local fusionMaid = Maid.new()

for toyKey, toy in pairs(inventory) do
    if toy.id == "trade_license" then
        tradeLicenseKey = toyKey
        break
    end
end

-- ============================================================================
-- DYNAMIC SYSTEM CATEGORIES (9 CATEGORIES)
-- ============================================================================
local categories_list = {
    "pets",
    "toys",
    "food",
    "gifts",
    "roleplay",
    "stickers",
    "strollers",
    "transport",
    "pet_accessories"
}

-- Define internal tool handling behavior properties
local tool_categories = {
    ["toys"] = true,
    ["food"] = true,
    ["gifts"] = true,
    ["strollers"] = true,
    ["roleplay"] = true
}

-- Hook tool equip/unequip & network router interception layer
local routeHooks = {
    ["ToolAPI/Equip"] = function(self, uniqueId, options, ...)
        if uniqueId == tradeLicenseKey then
            UIManager.set_app_visibility("TradeHistoryApp", true)
        end
        -- Check tools/toys/foods/gifts/strollers/roleplay types first
        if _G._FakeToys and _G._FakeToys[uniqueId] then
            if _G._EquipFakeToy then _G._EquipFakeToy(_G._FakeToys[uniqueId]) end
            return true, { action = "equip", is_server = true }
        end
        -- Fall back to custom pet rendering maps
        if _G._ActivePets and _G._ActivePets[uniqueId] then
            local pet = _G._ActivePets[uniqueId]
            local equipAsLast = false
            if type(options) == "table" and options.equip_as_last then
                equipAsLast = true
            end
            if _G._EquipPet then _G._EquipPet(pet.data, equipAsLast) end
            return true, { action = "equip", is_server = true }
        end
        return originalRoutes["ToolAPI/Equip"](self, uniqueId, options, ...)
    end,
    ["ToolAPI/Unequip"] = function(self, uniqueId)
        if uniqueId == tradeLicenseKey then
            UIManager.set_app_visibility("TradeHistoryApp", false)
        end
        if _G._FakeToys and _G._FakeToys[uniqueId] then
            if _G._UnequipFakeToy then _G._UnequipFakeToy(uniqueId) end
            return true, { action = "unequip", is_server = true }
        end
        if _G._ActivePets and _G._ActivePets[uniqueId] then
            local pet = _G._ActivePets[uniqueId]
            if _G._UnequipPet then _G._UnequipPet(pet.data) end
            return true, { action = "unequip", is_server = true }
        end
        return originalRoutes["ToolAPI/Unequip"](self, uniqueId)
    end,
    ["AdoptAPI/RidePet"] = function(self, petData)
        if _G._ActivePets and _G._ActivePets[petData.pet_unique] then
            if _G._RidePet then _G._RidePet(petData.pet_unique) end
            return true
        end
        return originalRoutes["AdoptAPI/RidePet"](self, petData)
    end,
    ["AdoptAPI/FlyPet"] = function(self, petData)
        if _G._ActivePets and _G._ActivePets[petData.pet_unique] then
            if _G._FlyPet then _G._FlyPet(petData.pet_unique) end
            return true
        end
        return originalRoutes["AdoptAPI/FlyPet"](self, petData)
    end,
    ["AdoptAPI/ExitSeatStatesYield"] = function(self)
        if _G._RidingPetId and _G._ExitRidingPet then
            _G._ExitRidingPet()
            return true
        end
        return originalRoutes["AdoptAPI/ExitSeatStatesYield"](self)
    end,
    ["AdoptAPI/ExitSeatStates"] = function(self)
        if _G._RidingPetId and _G._ExitRidingPet then
            _G._ExitRidingPet()
            return true
        end
        return originalRoutes["AdoptAPI/ExitSeatStates"](self)
    end,
    ["SettingsAPI/SetPetRoleplayName"] = function(self, petUniqueId, newName)
        if _G._ActivePets and _G._ActivePets[petUniqueId] then
            local pet = _G._ActivePets[petUniqueId]
            local originalIdentity = get_thread_identity and get_thread_identity() or 8
            set_thread_identity(2)
            local inventory = ClientData.get("inventory")
            if inventory and inventory.pets and inventory.pets[petUniqueId] then
                inventory.pets[petUniqueId].properties.rp_name = newName
            end
            if pet.data then pet.data.properties.rp_name = newName end
            set_thread_identity(originalIdentity)
            if _G._PredictDataChange then
                _G._PredictDataChange("pet_char_wrappers", function(wrappers)
                    for i, wrapper in ipairs(wrappers) do
                        if wrapper.pet_unique == petUniqueId then
                            wrappers[i] = table.clone(wrapper)
                            wrappers[i].rp_name = newName
                            break
                        end
                    end
                    return wrappers
                end)
            end
            return true
        end
        return originalRoutes["SettingsAPI/SetPetRoleplayName"](self, petUniqueId, newName)
    end,
    ["ToolAPI/ServerUseTool"] = function(self, uniqueId, ...)
        if _G._FakeToys and _G._FakeToys[uniqueId] then return end
        return originalRoutes["ToolAPI/ServerUseTool"](self, uniqueId, ...)
    end
}

debug.setupvalue(RouterClient.init, 4, setmetatable(routeHooks, {
    __index = originalRoutes,
    __newindex = function(tbl, key, value)
        if routeHooks[key] then
            rawset(tbl, key, value)
        else
            originalRoutes[key] = value
        end
    end
}))

-- Trade history tracking
local TradeHistoryApp = UIManager.apps.TradeHistoryApp
local TradeApp = UIManager.apps.TradeApp

if TradeHistoryApp._ORIGINAL_create_trade_frame then TradeHistoryApp._create_trade_frame = TradeHistoryApp._ORIGINAL_create_trade_frame end
if TradeApp._ORIGINAL_change_local_trade_state then TradeApp._change_local_trade_state = TradeApp._ORIGINAL_change_local_trade_state end
if TradeApp._ORIGINAL_overwrite_local_trade_state then TradeApp._overwrite_local_trade_state = TradeApp._ORIGINAL_overwrite_local_trade_state end

TradeHistoryApp._ORIGINAL_create_trade_frame = TradeHistoryApp._create_trade_frame
TradeApp._ORIGINAL_change_local_trade_state = TradeApp._change_local_trade_state
TradeApp._ORIGINAL_overwrite_local_trade_state = TradeApp._overwrite_local_trade_state

local tradeCache = {}
local currentTradeItems = nil

function TradeApp._change_local_trade_state(self, changes, ...)
    local currentState = TradeApp.local_trade_state
    if currentState and currentState.trade_id then
        local isSender = currentState.sender == LocalPlayer
        local isRecipient = currentState.recipient == LocalPlayer
        if isSender and changes.sender_offer and changes.sender_offer.items then
            tradeCache[currentState.trade_id] = { items = table.clone(changes.sender_offer.items), isSender = true }
            currentTradeItems = changes.sender_offer.items
        elseif isRecipient and changes.recipient_offer and changes.recipient_offer.items then
            tradeCache[currentState.trade_id] = { items = table.clone(changes.recipient_offer.items), isSender = false }
            currentTradeItems = changes.recipient_offer.items
        end
    end
    return TradeApp._ORIGINAL_change_local_trade_state(self, changes, ...)
end

function TradeApp._overwrite_local_trade_state(self, tradeState, ...)
    if tradeState then
        local isSender = tradeState.sender == LocalPlayer
        local isRecipient = tradeState.recipient == LocalPlayer
        if isSender and tradeState.sender_offer and currentTradeItems then
            tradeState.sender_offer.items = currentTradeItems
        elseif isRecipient and tradeState.recipient_offer and currentTradeItems then
            tradeState.recipient_offer.items = currentTradeItems
        end
    else
        currentTradeItems = nil
        if TradeApp._last_trade_id then
            tradeCache[TradeApp._last_trade_id] = nil
            TradeApp._last_trade_id = nil
        end
    end
    return TradeApp._ORIGINAL_overwrite_local_trade_state(self, tradeState, ...)
end

function TradeHistoryApp._create_trade_frame(self, tradeData, ...)
    if tradeData.trade_id and tradeCache[tradeData.trade_id] then
        local cachedData = tradeCache[tradeData.trade_id]
        local modifiedData = table.clone(tradeData)
        if cachedData.isSender then
            modifiedData.sender_items = table.clone(cachedData.items)
        else
            modifiedData.recipient_items = table.clone(cachedData.items)
        end
        return TradeHistoryApp._ORIGINAL_create_trade_frame(self, modifiedData, ...)
    end
    return TradeHistoryApp._ORIGINAL_create_trade_frame(self, tradeData, ...)
end

-- ============================================================================
-- SHARED STATE & ASSET CONTEXT
-- ============================================================================
local petHandlerEnabled = false
local SpawnedPets = {}
local SpawnedItems = {}
_G._FakeSpawnedItems = SpawnedItems

-- Spawning systems
task.spawn(function()
    set_thread_identity(2)
    local KindDB = LoadModule("KindDB")
    local DownloadClient = LoadModule("DownloadClient")
    local AnimationManager = LoadModule("AnimationManager")
    local PetRigs = LoadModule("new:PetRigs")
    local InventoryDB = LoadModule("InventoryDB")
    local AilmentsClient = LoadModule("new:AilmentsClient")
    local AilmentsDB = LoadModule("new:AilmentsDB")
    local DisplayStandHelper = LoadModule("DisplayStandHelper")
    local PetAvatarItemDB = LoadModule("PetAvatarItemDB")
    local PetAccessoryEquipHelper = LoadModule("PetAccessoryEquipHelper")
    local PetAvatarCategoriesDB = LoadModule("PetAvatarCategoriesDB")
    _G.InventoryDB = InventoryDB
    set_thread_identity(8)

    local completedAilments = {}
    local petModelCache = {}
    local activePets = {}
    _G._ActivePets = activePets
    local equippedPet = nil
    local ridingPetId = nil
    local rideAnimation = nil

    local fakeToys = {}
    _G._FakeToys = fakeToys
    local activeFakeTools = {}

    local fakePetAccessories = {}
    local updatePetSavedWornItems

    -- Dynamic table mappings dynamically across databases
    local CategoryFinders = {}
    for _, catName in ipairs(categories_list) do
        CategoryFinders[catName] = function(itemName)
            local targetDB = InventoryDB[catName]
            if not targetDB then return false end
            for _, itemInfo in pairs(targetDB) do
                if itemInfo.name and itemInfo.name:lower() == itemName:lower() then
                    return itemInfo.id
                end
            end
            return false
        end
    end

    local function GetItemByName(itemName)
        for _, catName in ipairs(categories_list) do
            local finderFunc = CategoryFinders[catName]
            if finderFunc then
                local itemId = finderFunc(itemName)
                if itemId then
                    return { name = catName, id = itemId }
                end
            end
        end
        return nil
    end

    local function ensurePetAvatarSlot(petUniqueId)
        pcall(function()
            set_thread_identity(2)
            local am = ClientData.get("avatar_manager") or {}
            local newAm = table.clone(am)
            newAm.pet = newAm.pet and table.clone(newAm.pet) or {}
            if not newAm.pet[petUniqueId] then
                local emptySlot = {}
                for categoryName, _ in pairs(PetAvatarCategoriesDB.categories) do
                    emptySlot[categoryName] = {}
                end
                newAm.pet[petUniqueId] = emptySlot
                ClientData.update("avatar_manager", newAm)
            end
            set_thread_identity(8)
        end)
    end

    local function ensurePetSavedWornItems(petUniqueId)
        pcall(function()
            set_thread_identity(2)
            local pswi = ClientData.get("pet_saved_worn_items") or {}
            if not pswi.accessory_to_pet_map then pswi.accessory_to_pet_map = {} end
            if not pswi.wearing_lists then pswi.wearing_lists = {} end
            if not pswi.wearing_lists[petUniqueId] then pswi.wearing_lists[petUniqueId] = {} end
            ClientData.update("pet_saved_worn_items", pswi)
            set_thread_identity(8)
        end)
    end

    local function downloadPetAccessoryAsset(modelHandle)
        if not modelHandle then return nil end
        local ok, asset = pcall(function()
            return DownloadClient.promise_download_copy("PetAvatarResources", modelHandle):expect()
        end)
        if ok and asset then return asset end
        return nil
    end

    local function applyAccessoryToFakePet(petUnique, category, accessoryUnique)
        ensurePetSavedWornItems(petUnique)
        local pet = activePets[petUnique]
        if not pet or not pet.model then return false end
        local accessoryItem = (ClientData.get("inventory") or {}).pet_accessories
        accessoryItem = accessoryItem and accessoryItem[accessoryUnique]
        if not accessoryItem then return false end
        local kindEntry = InventoryDB.pet_accessories[accessoryItem.id]
        if not kindEntry then return false end
        local baseAsset = downloadPetAccessoryAsset(kindEntry.model_handle)
        if not baseAsset then return false end
        local petModel = pet.model:FindFirstChild("PetModel") or pet.model
        fakePetAccessories[petUnique] = fakePetAccessories[petUnique] or {}
        if fakePetAccessories[petUnique][accessoryUnique] then return true end

        local ok, result = pcall(function()
            return PetAccessoryEquipHelper.equip_accessory({
                pet_model = petModel,
                accessory_base_asset = baseAsset,
                accessory_item_entry = kindEntry,
                asset_id = accessoryUnique,
                play_poof_effect = true,
                is_mannequin = false
            })
        end)
        if not ok then
            if baseAsset then baseAsset:Destroy() end
            return false
        end
        fakePetAccessories[petUnique][accessoryUnique] = {
            unequip = result.unequip,
            accessory = result.accessory,
            category = category
        }
        updatePetSavedWornItems(petUnique, accessoryUnique, true)
        return true
    end

    local function removeAccessoryFromFakePet(petUnique, accessoryUnique)
        local entry = fakePetAccessories[petUnique] and fakePetAccessories[petUnique][accessoryUnique]
        if not entry then return false end
        pcall(entry.unequip)
        fakePetAccessories[petUnique][accessoryUnique] = nil
        updatePetSavedWornItems(petUnique, accessoryUnique, false)
        return true
    end

    local function clearAllAccessoriesFromFakePet(petUnique)
        if not fakePetAccessories[petUnique] then return end
        for accUnique, entry in pairs(fakePetAccessories[petUnique]) do
            pcall(entry.unequip)
            updatePetSavedWornItems(petUnique, accUnique, false)
        end
        fakePetAccessories[petUnique] = nil
    end

    function updatePetSavedWornItems(petUnique, accessoryUnique, equip)
        pcall(function()
            set_thread_identity(2)
            local pswi = ClientData.get("pet_saved_worn_items") or {}
            local newPswi = table.clone(pswi)
            newPswi.accessory_to_pet_map = table.clone(newPswi.accessory_to_pet_map or {})
            newPswi.wearing_lists = table.clone(newPswi.wearing_lists or {})
            newPswi.wearing_lists[petUnique] = table.clone(newPswi.wearing_lists[petUnique] or {})
            local wearingList = newPswi.wearing_lists[petUnique]
            if equip then
                newPswi.accessory_to_pet_map[accessoryUnique] = petUnique
                wearingList[1] = wearingList[1] or {}
                local found = false
                for _, u in ipairs(wearingList[1]) do
                    if u == accessoryUnique then found = true; break end
                end
                if not found then table.insert(wearingList[1], accessoryUnique) end
            else
                newPswi.accessory_to_pet_map[accessoryUnique] = nil
                for _, sublist in pairs(wearingList) do
                    if type(sublist) == "table" then
                        for i = #sublist, 1, -1 do
                            if sublist[i] == accessoryUnique then table.remove(sublist, i) end
                        end
                    end
                end
            end
            ClientData.update("pet_saved_worn_items", newPswi)
            set_thread_identity(8)
        end)
    end

    local function predictDataChange(dataPath, updateFunction)
        local currentData = ClientData.get(dataPath)
        local clonedData = table.clone(currentData)
        ClientData.predict(dataPath, updateFunction(clonedData))
    end
    _G._PredictDataChange = predictDataChange

    local function generateUniqueId()
        return HttpService:GenerateGUID(false)
    end

    local originalGetServer = ClientData.get_server
    local cachedAilments = {}

    function ClientData.get_server(player, key, ...)
        local data = originalGetServer(player, key, ...)
        if key == "ailments_manager" and player == LocalPlayer then
            local clonedData = {}
            if data then
                for k, v in pairs(data) do
                    if type(v) == "table" then clonedData[k] = table.clone(v) else clonedData[k] = v end
                end
            end
            clonedData.ailments = clonedData.ailments or {}
            for petUniqueId, pet in pairs(activePets) do
                if cachedAilments[petUniqueId] then
                    clonedData.ailments[petUniqueId] = cachedAilments[petUniqueId]
                else
                    local ailmentTypes = {}
                    for kind, _ in pairs(AilmentsDB) do
                        if kind ~= "at_work" and kind ~= "mystery" and kind ~= "walking" then
                            table.insert(ailmentTypes, kind)
                        end
                    end
                    local numAilments = math.random(2, 4)
                    local ailments = {}
                    local usedTypes = {}
                    for i = 1, math.min(numAilments, #ailmentTypes) do
                        local ailmentType
                        repeat ailmentType = ailmentTypes[math.random(1, #ailmentTypes)] until not usedTypes[ailmentType]
                        usedTypes[ailmentType] = true
                        local ailmentId = generateUniqueId()
                        ailments[ailmentId] = {
                            components = {},
                            created_timestamp = os.time(),
                            kind = ailmentType,
                            progress = 0,
                            rate = 0,
                            rate_timestamp = os.time(),
                            sort_order = i * 100
                        }
                    end
                    cachedAilments[petUniqueId] = ailments
                    clonedData.ailments[petUniqueId] = ailments
                end
            end
            return clonedData
        end
        return data
    end

    local function downloadPetModel(petKind)
        if petModelCache[petKind] then return petModelCache[petKind] end
        local model = DownloadClient.promise_download_copy("Pets", petKind):expect()
        petModelCache[petKind] = model
        return model
    end

    local function applyNeonEffect(petModel, petData)
        local modelInstance = petModel:FindFirstChild("PetModel")
        if modelInstance and (petData.properties.neon or petData.properties.mega_neon) then
            local petKindData = KindDB[petData.id]
            for partName, properties in pairs(petKindData.neon_parts) do
                local geoPart = PetRigs.get(modelInstance).get_geo_part(modelInstance, partName)
                if geoPart then geoPart.Material = properties.Material; geoPart.Color = properties.Color end
            end
        end
    end

    local function findInArray(array, predicate)
        for index, item in pairs(array) do
            if predicate(item, index) then return index end
        end
        return nil
    end

    local newnessOrderGroups = {
        mega_neon_flyable_rideable = 900000, mega_neon_flyable = 800000, mega_neon_rideable = 700000, mega_neon = 600000,
        neon_flyable_rideable = 500000, neon_flyable = 400000, neon_rideable = 300000, neon = 200000,
        flyable_rideable = 100000, flyable = 90000, rideable = 80000, regular = 70000
    }

    local function getPropertyGroup(properties)
        local isMegaNeon = properties.mega_neon or false
        local isNeon = properties.neon or false
        local isFlyable = properties.flyable or false
        local isRideable = properties.rideable or false
        if isMegaNeon then
            if isFlyable and isRideable then return "mega_neon_flyable_rideable"
            elseif isFlyable then return "mega_neon_flyable"
            elseif isRideable then return "mega_neon_rideable"
            else return "mega_neon" end
        elseif isNeon then
            if isFlyable and isRideable then return "neon_flyable_rideable"
            elseif isFlyable then return "neon_flyable"
            elseif isRideable then return "neon_rideable"
            else return "neon" end
        else
            if isFlyable and isRideable then return "flyable_rideable"
            elseif isFlyable then return "flyable"
            elseif isRideable then return "rideable"
            else return "regular" end
        end
    end

    local nextToyOrder = 60000

    local function addPetCharacterWrapper(wrapperData)
        predictDataChange("pet_char_wrappers", function(wrappers)
            wrapperData.unique = #wrappers + 1
            wrapperData.index = #wrappers + 1
            wrappers[#wrappers + 1] = wrapperData
            return wrappers
        end)
    end

    local function addPetStateManager(stateManager)
        predictDataChange("pet_state_managers", function(managers)
            managers[#managers + 1] = stateManager
            return managers
        end)
    end

    local function removePetCharacterWrapper(petUniqueId)
        predictDataChange("pet_char_wrappers", function(wrappers)
            local wrapperIndex = findInArray(wrappers, function(wrapper) return wrapper.pet_unique == petUniqueId end)
            if wrapperIndex then
                table.remove(wrappers, wrapperIndex)
                for i = wrapperIndex, #wrappers do wrappers[i].unique = i; wrappers[i].index = i end
            end
            return wrappers
        end)
    end

    local function removePetStateManager(petUniqueId)
        local pet = activePets[petUniqueId]
        if not pet or not pet.model then return end
        predictDataChange("pet_state_managers", function(managers)
            local managerIndex = findInArray(managers, function(manager) return manager.char == pet.model end)
            if managerIndex then table.remove(managers, managerIndex) end
            return managers
        end)
    end

    local function clearPetStates(petUniqueId)
        local pet = activePets[petUniqueId]
        if not pet or not pet.model then return end
        predictDataChange("pet_state_managers", function(managers)
            local managerIndex = findInArray(managers, function(manager) return manager.char == pet.model end)
            if managerIndex then
                local updatedManagers = table.clone(managers)
                updatedManagers[managerIndex] = table.clone(updatedManagers[managerIndex])
                updatedManagers[managerIndex].states = {}
                return updatedManagers
            end
            return managers
        end)
    end

    local function setPetState(petUniqueId, stateId)
        local pet = activePets[petUniqueId]
        if not pet or not pet.model then return end
        predictDataChange("pet_state_managers", function(managers)
            local managerIndex = findInArray(managers, function(manager) return manager.char == pet.model end)
            if managerIndex then
                local updatedManagers = table.clone(managers)
                updatedManagers[managerIndex] = table.clone(updatedManagers[managerIndex])
                updatedManagers[managerIndex].states = {{ id = stateId }}
                return updatedManagers
            end
            return managers
        end)
    end

    local function clearPlayerStates()
        predictDataChange("state_manager", function(stateManager)
            local updatedManager = table.clone(stateManager)
            updatedManager.states = {}
            updatedManager.is_sitting = false
            return updatedManager
        end)
    end

    local function setPlayerState(stateId)
        predictDataChange("state_manager", function(stateManager)
            local updatedManager = table.clone(stateManager)
            updatedManager.states = {{ id = stateId }}
            updatedManager.is_sitting = true
            return updatedManager
        end)
    end

    local function attachRideConstraint(petModel)
        local character = LocalPlayer.Character
        if not character or not character.PrimaryPart then return false end
        local ridePosition = petModel:FindFirstChild("RidePosition", true)
        if not ridePosition then return false end
        local sourceAttachment = Instance.new("Attachment")
        sourceAttachment.Parent = ridePosition
        sourceAttachment.Position = Vector3.new(0, 1.237, 0)
        sourceAttachment.Name = "SourceAttachment"
        local rigidConstraint = Instance.new("RigidConstraint")
        rigidConstraint.Name = "StateConnection"
        rigidConstraint.Attachment0 = sourceAttachment
        rigidConstraint.Attachment1 = character.PrimaryPart.RootAttachment
        rigidConstraint.Parent = character
        return true
    end

    local function exitRidingPet()
        if not ridingPetId then return end
        local pet = activePets[ridingPetId]
        if not pet or not pet.model then ridingPetId = nil; return end
        if rideAnimation then rideAnimation:Stop(); rideAnimation:Destroy(); rideAnimation = nil end
        local sourceAttachment = pet.model:FindFirstChild("SourceAttachment", true)
        if sourceAttachment then sourceAttachment:Destroy() end
        local character = LocalPlayer.Character
        if character then
            for _, descendant in pairs(character:GetDescendants()) do
                if descendant:IsA("BasePart") and descendant:GetAttribute("HaveMass") then descendant.Massless = false end
            end
        end
        clearPetStates(ridingPetId)
        clearPlayerStates()
        pet.model:ScaleTo(1)
        ridingPetId = nil
    end
    _G._ExitRidingPet = exitRidingPet

    local function startRidingPet(petUniqueId, playerState, petState)
        local pet = activePets[petUniqueId]
        if not pet or not pet.model then return end
        local character = LocalPlayer.Character
        if not character or not character.PrimaryPart or not character:FindFirstChild("Humanoid") then return end
        ridingPetId = petUniqueId
        _G._RidingPetId = ridingPetId
        setPetState(petUniqueId, petState)
        setPlayerState(playerState)
        pet.model:ScaleTo(2)
        attachRideConstraint(pet.model)
        rideAnimation = character.Humanoid.Animator:LoadAnimation(AnimationManager.get_track("PlayerRidingPet"))
        character.Humanoid.Sit = true
        for _, descendant in pairs(character:GetDescendants()) do
            if descendant:IsA("BasePart") and descendant.Massless == false then
                descendant.Massless = true
                descendant:SetAttribute("HaveMass", true)
            end
        end
        rideAnimation:Play()
    end

    local function ridePet(petUniqueId) startRidingPet(petUniqueId, "PlayerRidingPet", "PetBeingRidden") end
    local function flyPet(petUniqueId) startRidingPet(petUniqueId, "PlayerFlyingPet", "PetBeingFlown") end
    _G._RidePet = ridePet
    _G._FlyPet = flyPet

    local equipCooldown = false
    local unequipCooldown = false
    local mainPetId = nil
    local altPetId = nil

    local function unequipPet(petData)
        if unequipCooldown then return end
        unequipCooldown = true
        local pet = activePets[petData.unique]
        if not pet or not pet.model then unequipCooldown = false; return end
        if ridingPetId == petData.unique then exitRidingPet() end
        removePetCharacterWrapper(petData.unique)
        removePetStateManager(petData.unique)
        clearAllAccessoriesFromFakePet(petData.unique)
        pet.model:Destroy()
        pet.model = nil
        if equippedPet and equippedPet.unique == petData.unique then equippedPet = nil end
        if mainPetId == petData.unique then mainPetId = nil end
        if altPetId == petData.unique then altPetId = nil end

        pcall(function()
            set_thread_identity(2)
            local em = ClientData.get("equip_manager") or {}
            em["pets"] = em["pets"] or {}
            for i = #em["pets"], 1, -1 do
                if em["pets"][i] and em["pets"][i].unique == petData.unique then table.remove(em["pets"], i) end
            end
            ClientData.predict("equip_manager", em)
            ClientData.update("equip_manager", em)
            set_thread_identity(8)
        end)
        cachedAilments[petData.unique] = nil
        task.wait(0.15)
        pcall(function()
            set_thread_identity(2)
            AilmentsClient.on_ailments_changed(LocalPlayer)
            set_thread_identity(8)
        end)
        pcall(function()
            set_thread_identity(2)
            local BackpackCategoryButtons = LoadModule("BackpackCategoryButtons")
            BackpackCategoryButtons.recalculate_equipped_cache()
            UIManager.apps.BackpackApp:refresh_rendered_items()
            set_thread_identity(8)
        end)
        task.wait(0.3)
        unequipCooldown = false
    end
    _G._UnequipPet = unequipPet

    local function equipPet(petData, equipAsLast)
        if equipCooldown then return end
        if petData.category ~= "pets" then return end
        equipCooldown = true

        if activePets[petData.unique] and activePets[petData.unique].model then
            unequipPet(petData)
            equipCooldown = false
            return
        end

        if petHandlerEnabled then
            if equipAsLast then
                if altPetId and activePets[altPetId] and activePets[altPetId].model then unequipPet(activePets[altPetId].data) end
            else
                if mainPetId and activePets[mainPetId] and activePets[mainPetId].model then unequipPet(activePets[mainPetId].data) end
            end
        else
            for petUniqueId, pet in pairs(activePets) do
                if pet.model and petUniqueId ~= petData.unique then
                    if ridingPetId == petUniqueId then exitRidingPet() end
                    removePetCharacterWrapper(petUniqueId)
                    removePetStateManager(petUniqueId)
                    pet.model:Destroy()
                    pet.model = nil
                    if equippedPet and equippedPet.unique == petUniqueId then equippedPet = nil end
                end
            end
            mainPetId = nil
            altPetId = nil

            local equipManager = ClientData.get("equip_manager") or {}
            local petsEquipped = equipManager["pets"] or {}
            local cleanedPets = {}
            for _, entry in pairs(petsEquipped) do
                if not activePets[entry.unique] then table.insert(cleanedPets, entry) end
            end
            local newEquipManager = table.clone(equipManager)
            newEquipManager["pets"] = cleanedPets
            ClientData.predict("equip_manager", newEquipManager)

            local currentWrappers = ClientData.get("pet_char_wrappers")
            for _, wrapper in pairs(currentWrappers) do
                if wrapper.controller == LocalPlayer and not activePets[wrapper.pet_unique] then
                    RouterClient.get("ToolAPI/Unequip"):InvokeServer(wrapper.pet_unique)
                end
            end
            task.wait()
        end

        if not activePets[petData.unique] then activePets[petData.unique] = { data = petData, model = nil } end
        local petModel = downloadPetModel(petData.kind):Clone()
        local petsFolder = workspace:FindFirstChild("Pets") or Instance.new("Folder", workspace)
        petsFolder.Name = "Pets"
        petModel.Parent = petsFolder
        game:GetService("CollectionService"):AddTag(petModel, "Pets")

        activePets[petData.unique].model = petModel
        applyNeonEffect(petModel, petData)
        equippedPet = petData

        if petHandlerEnabled then
            if equipAsLast then altPetId = petData.unique else mainPetId = petData.unique end
        else
            mainPetId = petData.unique; altPetId = nil
        end

        local isAltSlot = (petData.unique == altPetId)
        local followOffset = isAltSlot and Vector3.new(-3.5, 0, 0) or Vector3.new(3.5, 0, 0)
        petModel:SetAttribute("FollowOffset", followOffset)

        addPetCharacterWrapper({
            char = petModel, mega_neon = petData.properties.mega_neon or false, neon = petData.properties.neon or false,
            player = LocalPlayer, entity_controller = LocalPlayer, controller = LocalPlayer, rp_name = petData.properties.rp_name or "",
            pet_trick_level = petData.properties.pet_trick_level or 0, pet_unique = petData.unique, pet_id = petData.id, is_pet = true,
            transform_mode = 1, location = { full_destination_id = "housing", destination_id = "housing", house_owner = LocalPlayer },
            pet_progression = { age = petData.properties.age or 1, percentage = 0, xp = 0, friendship_level = petData.properties.friendship_level or 0 },
            are_colors_sealed = false
        })

        addPetStateManager({ char = petModel, player = LocalPlayer, store_key = "pet_state_managers", is_sitting = false, chars_connected_to_me = {}, states = {} })

        pcall(function()
            set_thread_identity(2)
            local em = ClientData.get("equip_manager") or {}
            em["pets"] = em["pets"] or {}
            for i = #em["pets"], 1, -1 do
                if em["pets"][i] and em["pets"][i].unique == petData.unique then table.remove(em["pets"], i) end
            end
            table.insert(em["pets"], petData)
            ClientData.predict("equip_manager", em)
            ClientData.update("equip_manager", em)
            set_thread_identity(8)
        end)

        task.wait(0.15)
        pcall(function()
            set_thread_identity(2)
            AilmentsClient.on_ailments_changed(LocalPlayer)
            set_thread_identity(8)
        end)

        pcall(function()
            set_thread_identity(2)
            local BackpackCategoryButtons = LoadModule("BackpackCategoryButtons")
            BackpackCategoryButtons.recalculate_equipped_cache()
            UIManager.apps.BackpackApp:refresh_rendered_items()
            set_thread_identity(8)
        end)

        task.spawn(function()
            task.wait(0.3)
            local am = ClientData.get("avatar_manager") or {}
            local petAvatar = am.pet and am.pet[petData.unique]
            if petAvatar then
                for category, items in pairs(petAvatar) do
                    if type(items) == "table" then
                        for _, item in ipairs(items) do
                            local accUnique = item.unique or item.asset_id
                            if accUnique then applyAccessoryToFakePet(petData.unique, category, accUnique) end
                        end
                    end
                end
            end
        end)

        task.wait(0.5)
        equipCooldown = false
    end
    _G._EquipPet = equipPet

    local function DownloadItemModel(itemId)
        return DownloadClient.promise_download_copy("Furniture", itemId):expect()
    end

    local function loadToolAnimation(animator, animName)
        if not animator or not animName then return nil end
        local ok, assetId = pcall(function() return AnimationManager.get_id(animName) end)
        if not ok or not assetId then return nil end
        local anim = Instance.new("Animation")
        anim.AnimationId = assetId
        local trackOk, track = pcall(function() return animator:LoadAnimation(anim) end)
        if trackOk and track then return track end
        return nil
    end

    local function unequipFakeToy(uniqueId)
        local info = activeFakeTools[uniqueId]
        if not info then return end
        if info.holdTrack then pcall(function() info.holdTrack:Stop(); info.holdTrack:Destroy() end) end
        if info.useTrack then pcall(function() info.useTrack:Stop(); info.useTrack:Destroy() end) end
        if info.tool and info.tool.Parent then info.tool:Destroy() end
        activeFakeTools[uniqueId] = nil

        pcall(function()
            set_thread_identity(2)
            local equipManager = ClientData.get("equip_manager") or {}
            if equipManager.toys then
                for i = #equipManager.toys, 1, -1 do
                    if equipManager.toys[i].unique == uniqueId then table.remove(equipManager.toys, i) end
                end
            end
            ClientData.predict("equip_manager", equipManager)
            set_thread_identity(8)
        end)
    end
    _G._UnequipFakeToy = unequipFakeToy

    local function equipFakeToy(itemData)
        local character = LocalPlayer.Character
        if not character or not character:FindFirstChild("Humanoid") then return end
        for uid, _ in pairs(activeFakeTools) do unequipFakeToy(uid) end

        local entry = InventoryDB[itemData.category] and InventoryDB[itemData.category][itemData.id]
        if not entry then return end
        local kindData = KindDB[itemData.id]

        local tool = Instance.new("Tool")
        tool.Name = entry.name or itemData.id
        tool.CanBeDropped = false
        tool.RequiresHandle = false

        local uniqueVal = Instance.new("StringValue")
        uniqueVal.Name = "unique"
        uniqueVal.Value = itemData.unique
        uniqueVal.Parent = tool

        local success, model = pcall(DownloadItemModel, itemData.id)
        if success and model then
            if model:IsA("Model") then model.Name = "ModelHandle"
            elseif model:IsA("BasePart") then
                local wrapper = Instance.new("Model")
                wrapper.Name = "ModelHandle"
                model.Parent = wrapper
                model = wrapper
            end
            model.Parent = tool
        end
        tool.Parent = LocalPlayer.Backpack
        character.Humanoid:EquipTool(tool)

        local modelHandle = tool:FindFirstChild("ModelHandle")
        if modelHandle then
            local rightHand = character:FindFirstChild("RightHand")
            if rightHand then
                local handle = modelHandle:FindFirstChild("Handle") or modelHandle.PrimaryPart or modelHandle:FindFirstChildWhichIsA("BasePart", true)
                if handle then
                    local gripCF = CFrame.new()
                    if kindData and kindData.grip then gripCF = kindData.grip end
                    local rightMount = modelHandle:FindFirstChild("RightMount")
                    if rightMount and rightMount:IsA("BasePart") then
                        gripCF = rightMount.CFrame:ToObjectSpace(handle.CFrame):Inverse()
                        handle = rightMount
                    end
                    local weld = Instance.new("Weld")
                    weld.Part0 = rightHand; weld.Part1 = handle; weld.C0 = gripCF; weld.C1 = CFrame.new(); weld.Parent = rightHand
                    for _, desc in ipairs(modelHandle:GetDescendants()) do
                        if desc:IsA("BasePart") and desc.Name:find("Mount") then desc.Transparency = 1 end
                    end
                end
            end
        end

        local holdTrack, useTrack = nil, nil
        local animator = character.Humanoid:FindFirstChild("Animator")
        if animator and kindData and kindData.anims then
            if kindData.anims.hold then
                holdTrack = loadToolAnimation(animator, kindData.anims.hold)
                if holdTrack then holdTrack.Priority = Enum.AnimationPriority.Action; holdTrack.Looped = true; holdTrack:Play() end
            end
            if kindData.anims.use then
                useTrack = loadToolAnimation(animator, kindData.anims.use)
                if useTrack then useTrack.Priority = Enum.AnimationPriority.Action2; useTrack.Looped = false end
            end
        end
        if tool and useTrack then
            tool.Activated:Connect(function() if useTrack and useTrack.IsPlaying == false then useTrack:Play() end end)
        end
        activeFakeTools[itemData.unique] = { tool = tool, holdTrack = holdTrack, useTrack = useTrack }

        pcall(function()
            set_thread_identity(2)
            local equipManager = ClientData.get("equip_manager") or {}
            local newEquipManager = table.clone(equipManager)
            newEquipManager.toys = newEquipManager.toys or {}
            local cleanedToys = {}
            for _, e in pairs(newEquipManager.toys) do
                if not fakeToys[e.unique] then table.insert(cleanedToys, e) end
            end
            table.insert(cleanedToys, itemData)
            newEquipManager.toys = cleanedToys
            ClientData.predict("equip_manager", newEquipManager)
            ClientData.update("equip_manager", newEquipManager)
            set_thread_identity(8)
        end)
    end
    _G._EquipFakeToy = equipFakeToy

    local function createItem(itemId, category, properties)
        local uniqueId = generateUniqueId()
        local itemKindData = KindDB[itemId]
        if not itemKindData then warn("Item ID not found: " .. itemId); return nil end
        properties = properties or {}
        local newnessOrder = nextToyOrder

        if category == "pets" then
            local groupKey = getPropertyGroup(properties)
            newnessOrderGroups[groupKey] = newnessOrderGroups[groupKey] - 1
            newnessOrder = newnessOrderGroups[groupKey]
            if properties.mega_neon and not properties.friendship_level then properties.friendship_level = 0 end
            if not properties.xp then properties.xp = 0 end
            if not properties.pet_trick_level then properties.pet_trick_level = 0 end
            if not properties.friendship_level then properties.friendship_level = 0 end
        else
            nextToyOrder = nextToyOrder - 1
            newnessOrder = nextToyOrder
        end

        local itemData = { unique = uniqueId, category = category, id = itemId, kind = itemKindData.kind, newness_order = newnessOrder, properties = properties }
        local originalIdentity = get_thread_identity and get_thread_identity() or 8
        set_thread_identity(2)
        local inventory = ClientData.get("inventory")
        if inventory and inventory[category] then inventory[category][uniqueId] = itemData end
        set_thread_identity(originalIdentity)

        if category == "pets" then
            activePets[uniqueId] = { data = itemData, model = nil }
            SpawnedPets[uniqueId] = activePets[uniqueId]
            SpawnedItems[uniqueId] = true
            ensurePetAvatarSlot(uniqueId)
        end
        if tool_categories[category] then
            fakeToys[uniqueId] = itemData
            SpawnedItems[uniqueId] = true
        end
        task.defer(function()
            pcall(function()
                set_thread_identity(2)
                UIManager.apps.BackpackApp:refresh_rendered_items()
                set_thread_identity(8)
            end)
        end)
        return itemData
    end

    _G.spawn_pet = function(petName, properties)
        local petId = CategoryFinders["pets"](petName)
        if petId then return createItem(petId, "pets", properties) end
        return nil
    end

    _G.spawn_item = function(itemName, category)
        local cat = category or "toys"
        local finder = CategoryFinders[cat]
        if finder then
            local itemId = finder(itemName)
            if itemId then return createItem(itemId, cat, {}) end
        end
        return nil
    end

    _G.equip_toy = function(toolName)
        for catName, _ in pairs(tool_categories) do
            local toolId = CategoryFinders[catName](toolName)
            if toolId then
                local uniqueId = generateUniqueId()
                local itemData = {
                    unique = uniqueId, category = catName, id = toolId,
                    kind = KindDB[toolId] and KindDB[toolId].kind or "toy",
                    newness_order = nextToyOrder, properties = {}
                }
                fakeToys[uniqueId] = itemData
                nextToyOrder = nextToyOrder - 1
                equipFakeToy(itemData)
                return itemData
            end
        end
        return nil
    end

    _G.unequip_toy = function()
        for uid in pairs(activeFakeTools) do unequipFakeToy(uid) end
    end

    _G.spawn_high_tier_pets = function(properties)
        local highTierPets = { "shadow_dragon", "bat_dragon", "giraffe", "frost_dragon", "owl", "parrot", "crow", "evil_unicorn" }
        local groupSnapshot = table.clone(newnessOrderGroups)
        local spawnedPets = {}
        for _, petKind in ipairs(highTierPets) do
            local item = createItem(petKind, "pets", properties)
            if item then table.insert(spawnedPets, item) end
        end
        for k, v in pairs(groupSnapshot) do newnessOrderGroups[k] = v end
        return spawnedPets
    end

    _G._PetHandler_Toggle = function(bool)
        petHandlerEnabled = bool
        if not petHandlerEnabled then
            if altPetId and activePets[altPetId] then unequipPet(activePets[altPetId].data) end
            altPetId = nil
        end
    end
end)

print("func loaded!")

-- ============================================================
-- SCREEN CONTAINER INITIALIZATION & RENDER
-- ============================================================
local screenGui = game:GetService("CoreGui"):FindFirstChild("AdoptMeSpawnerContext")
if screenGui then screenGui:Destroy() end

screenGui = Instance.new("ScreenGui")
screenGui.Name = "AdoptMeSpawnerContext"
screenGui.ResetOnSpawn = false

local success, err = pcall(function() screenGui.Parent = game:GetService("CoreGui") end)
if not success then screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

-- Age mapping tables
local normalAges = { ["Newborn"] = 1, ["Junior"] = 2, ["Pre-Teen"] = 3, ["Teen"] = 4, ["Post-Teen"] = 5, ["Full Grown"] = 6 }
local neonAges = { ["Reborn"] = 1, ["Twinkle"] = 2, ["Sparkle"] = 3, ["Flare"] = 4, ["Sunshine"] = 5, ["Luminous"] = 6 }
local normalAgeOrder = {"Newborn", "Junior", "Pre-Teen", "Teen", "Post-Teen", "Full Grown"}
local neonAgeOrder = {"Reborn", "Twinkle", "Sparkle", "Flare", "Sunshine", "Luminous"}

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

-- ==================== THEME COLORS ====================
local Theme = {
    bg_primary = Color3.fromRGB(255, 240, 245), bg_secondary = Color3.fromRGB(255, 228, 237),
    bg_input = Color3.fromRGB(255, 245, 248), topbar = Color3.fromRGB(255, 150, 180),
    topbar_dark = Color3.fromRGB(240, 120, 160), accent = Color3.fromRGB(255, 130, 170),
    accent_hover = Color3.fromRGB(255, 110, 155), text_primary = Color3.fromRGB(80, 50, 60),
    text_secondary = Color3.fromRGB(140, 100, 115), text_light = Color3.fromRGB(255, 255, 255),
    stroke = Color3.fromRGB(255, 180, 200), shadow = Color3.fromRGB(40, 10, 20), footer_bg = Color3.fromRGB(255, 210, 225)
}

local isMobile = UserInputService.TouchEnabled
local titleSize = isMobile and 14 or 16
local buttonHeight = isMobile and 28 or 34
local tabHeight = isMobile and 26 or 32
local toggleWidth = isMobile and 62 or 82
local toggleHeight = isMobile and 26 or 32
local topBarHeight = isMobile and 44 or 52

-- ==================== MAIN FRAME ====================
local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
if isMobile then
    mainFrame.Size = UDim2.new(0, 230, 0, 380)
    mainFrame.Position = UDim2.new(0.5, -115, 0.5, -190)
else
    mainFrame.Size = UDim2.new(0, 300, 0, 440)
    mainFrame.Position = UDim2.new(0.5, -150, 0.5, -220)
end
mainFrame.BackgroundColor3 = Theme.bg_primary
mainFrame.BorderSizePixel = 0
mainFrame.Parent = screenGui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 16)
mainCorner.Parent = mainFrame

local mainStroke = Instance.new("UIStroke")
mainStroke.Thickness = 2.5
mainStroke.Color = Theme.stroke
mainStroke.Transparency = 0.3
mainStroke.Parent = mainFrame

local mainGradient = Instance.new("UIGradient")
mainGradient.Color = ColorSequence.new {ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 245, 250)), ColorSequenceKeypoint.new(1, Color3.fromRGB(250, 230, 240))}
mainGradient.Rotation = 160
mainGradient.Parent = mainFrame

-- ==================== DROP SHADOW ====================
local shadow = Instance.new("Frame")
shadow.Name = "Shadow"
shadow.Size = UDim2.new(1, 12, 1, 12)
shadow.Position = UDim2.new(0, -6, 0, -2)
shadow.BackgroundColor3 = Theme.shadow
shadow.BackgroundTransparency = 0.7
shadow.BorderSizePixel = 0
shadow.ZIndex = -1
shadow.Parent = mainFrame

local shadowCorner = Instance.new("UICorner")
shadowCorner.CornerRadius = UDim.new(0, 20)
shadowCorner.Parent = shadow

-- ==================== TOP BAR ====================
local topBar = Instance.new("Frame")
topBar.Size = UDim2.new(1, 0, 0, topBarHeight)
topBar.BackgroundColor3 = Theme.topbar
topBar.BorderSizePixel = 0
topBar.Parent = mainFrame

local topCorner = Instance.new("UICorner")
topCorner.CornerRadius = UDim.new(0, 16)
topCorner.Parent = topBar

local topFix = Instance.new("Frame")
topFix.Size = UDim2.new(1, 0, 0, 16)
topFix.Position = UDim2.new(0, 0, 1, -16)
topFix.BackgroundColor3 = Theme.topbar
topFix.BorderSizePixel = 0
topFix.Parent = topBar

local topGradient = Instance.new("UIGradient")
topGradient.Color = ColorSequence.new {ColorSequenceKeypoint.new(0, Theme.topbar), ColorSequenceKeypoint.new(1, Theme.topbar_dark)}
topGradient.Rotation = 45
topGradient.Parent = topBar

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -50, 0, 22)
titleLabel.Position = UDim2.new(0, 14, 0, 8)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "✿ Adopt Me Spawner"
titleLabel.TextColor3 = Theme.text_light
titleLabel.TextSize = titleSize
titleLabel.Font = Enum.Font.GothamBlack
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.TextStrokeColor3 = Color3.fromRGB(200, 100, 140)
titleLabel.TextStrokeTransparency = 0.6
titleLabel.Parent = topBar

local subtitleLabel = Instance.new("TextLabel")
subtitleLabel.Size = UDim2.new(1, -50, 0, 16)
subtitleLabel.Position = UDim2.new(0, 14, 0, isMobile and 24 or 30)
subtitleLabel.BackgroundTransparency = 1
subtitleLabel.Text = "made by Mr. Stealer (replicated.storage)"
subtitleLabel.TextColor3 = Color3.fromRGB(255, 220, 230)
subtitleLabel.TextSize = isMobile and 8 or 9
subtitleLabel.Font = Enum.Font.GothamBold
subtitleLabel.TextXAlignment = Enum.TextXAlignment.Left
subtitleLabel.Parent = topBar

-- ==================== DRAG LOGIC ====================
local dragging, dragInput, dragStart, startPos
topBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = mainFrame.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then dragging = false end
        end)
    end
end)
topBar.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then dragInput = input end
end)
UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        local delta = input.Position - dragStart
        mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.X.Scale, startPos.Y.Offset + delta.Y)
    end
end)

-- ==================== MINIMIZE SYSTEM ====================
local isMinimized = false
local originalSize = mainFrame.Size
local originalPos = mainFrame.Position
local minimizeButton = Instance.new("TextButton")
minimizeButton.Size = UDim2.new(0, 28, 0, 28)
minimizeButton.Position = UDim2.new(1, -36, 0.5, -14)
minimizeButton.BackgroundTransparency = 0
minimizeButton.BackgroundColor3 = Color3.fromRGB(255, 200, 215)
minimizeButton.Text = "×"
minimizeButton.TextSize = 18
minimizeButton.TextColor3 = Theme.text_primary
minimizeButton.Font = Enum.Font.GothamBlack
minimizeButton.Parent = topBar

local minCorner = Instance.new("UICorner")
minCorner.CornerRadius = UDim.new(0, 8)
minCorner.Parent = minimizeButton

local minimizedClickArea = Instance.new("TextButton")
minimizedClickArea.Size = UDim2.new(1, 0, 1, 0)
minimizedClickArea.BackgroundTransparency = 1
minimizedClickArea.Text = ""
minimizedClickArea.Visible = false
minimizedClickArea.Parent = mainFrame

minimizeButton.MouseButton1Click:Connect(function()
    isMinimized = not isMinimized
    if isMinimized then
        originalSize = mainFrame.Size
        originalPos = mainFrame.Position
        topBar.Visible = false
        tabBar.Visible = false
        footer.Visible = false
        titleLabel.Visible = false
        subtitleLabel.Visible = false
        shadow.Visible = false
        for _, page in pairs(pages) do page.Visible = false end
        TweenService:Create(mainFrame, TweenInfo.new(0.4, Enum.EasingStyle.Back), {
            Position = UDim2.new(0, 10, 1, -65), Size = UDim2.new(0, 46, 0, 46),
            BackgroundColor3 = Theme.topbar, BackgroundTransparency = 0.1
        }):Play()
        mainGradient.Enabled = false
        TweenService:Create(mainCorner, TweenInfo.new(0.4), { CornerRadius = UDim.new(1, 0) }):Play()
        TweenService:Create(mainStroke, TweenInfo.new(0.4), { Transparency = 0.5 }):Play()
        minimizeButton.Text = "✿"
        minimizeButton.TextSize = 20
        minimizeButton.Size = UDim2.new(1, -6, 1, -6)
        minimizeButton.Position = UDim2.new(0, 3, 0, 3)
        minimizeButton.ZIndex = 10
        minimizeButton.BackgroundTransparency = 1
        minimizeButton.TextColor3 = Theme.text_light
        minimizedClickArea.Visible = true
    else
        minimizeButton.Size = UDim2.new(0, 28, 0, 28)
        minimizeButton.Position = UDim2.new(1, -36, 0.5, -14)
        minimizeButton.ZIndex = 1
        minimizeButton.BackgroundTransparency = 0
        minimizeButton.Text = "×"
        minimizeButton.TextSize = 18
        minimizeButton.TextColor3 = Theme.text_primary
        minimizeButton.BackgroundColor3 = Color3.fromRGB(255, 200, 215)
        topBar.Visible = true
        tabBar.Visible = true
        footer.Visible = true
        titleLabel.Visible = true
        subtitleLabel.Visible = true
        shadow.Visible = true
        for id, page in pairs(pages) do page.Visible = (id == currentTab) end
        TweenService:Create(mainFrame, TweenInfo.new(0.4, Enum.EasingStyle.Back), {
            Position = originalPos, Size = originalSize, BackgroundColor3 = Theme.bg_primary, BackgroundTransparency = 0
        }):Play()
        mainGradient.Enabled = true
        TweenService:Create(mainCorner, TweenInfo.new(0.4), { CornerRadius = UDim.new(0, 16) }):Play()
        TweenService:Create(mainStroke, TweenInfo.new(0.4), { Transparency = 0.3 }):Play()
        minimizedClickArea.Visible = false
    end
end)
minimizedClickArea.MouseButton1Click:Connect(function() minimizeButton:Click() end)

-- ==================== TAB BAR ====================
local tabBar = Instance.new("Frame")
tabBar.Size = UDim2.new(1, -20, 0, tabHeight)
tabBar.Position = UDim2.new(0, 10, 0, topBarHeight + 8)
tabBar.BackgroundTransparency = 1
tabBar.Parent = mainFrame

local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
tabLayout.Padding = UDim.new(0, 6)
tabLayout.Parent = tabBar

-- ==================== PAGES CONTAINER ====================
local container = Instance.new("Frame")
container.Size = UDim2.new(1, -20, 1, -topBarHeight - tabHeight - 48)
container.Position = UDim2.new(0, 10, 0, topBarHeight + tabHeight + 16)
container.BackgroundTransparency = 1
container.Parent = mainFrame

local pages = {}
local currentTab = nil

local function createPage(id)
    local page = Instance.new("ScrollingFrame")
    page.Name = id .. "Page"
    page.Size = UDim2.new(1, 0, 1, 0)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.CanvasSize = UDim2.new(0, 0, 0, 0)
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.ScrollBarThickness = 3
    page.ScrollBarImageColor3 = Theme.accent
    page.Visible = false
    page.Parent = container

    local pageLayout = Instance.new("UIListLayout")
    pageLayout.FillDirection = Enum.FillDirection.Vertical
    pageLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    pageLayout.Padding = UDim.new(0, 8)
    pageLayout.Parent = page

    pages[id] = page
    return page
end

local function switchTab(id)
    if currentTab == id then return end
    currentTab = id
    for tabId, page in pairs(pages) do page.Visible = (tabId == id) end
    for _, btn in ipairs(tabBar:GetChildren()) do
        if btn:IsA("TextButton") then
            if btn.Name == id .. "Tab" then
                TweenService:Create(btn, TweenInfo.new(0.2), { BackgroundColor3 = Theme.accent, TextColor3 = Theme.text_light }):Play()
            else
                TweenService:Create(btn, TweenInfo.new(0.2), { BackgroundColor3 = Theme.bg_secondary, TextColor3 = Theme.text_primary }):Play()
            end
        end
    end
end

local function addTabButton(id, title)
    local btn = Instance.new("TextButton")
    btn.Name = id .. "Tab"
    btn.Size = UDim2.new(0.31, 0, 1, 0)
    btn.BackgroundColor3 = Theme.bg_secondary
    btn.Text = title
    btn.TextSize = isMobile and 10 or 11
    btn.TextColor3 = Theme.text_primary
    btn.Font = Enum.Font.GothamBold
    btn.Parent = tabBar

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = btn

    btn.MouseButton1Click:Connect(function() switchTab(id) end)
end

-- Create Pages
local petPage = createPage("Pet")
local itemPage = createPage("Item")
local featuresPage = createPage("Features")

addTabButton("Pet", " Pets")
addTabButton("Item", " Items")
addTabButton("Features", " Info")

-- ==================== UI HELPER FUNCTIONS ====================
local function createSectionLabel(text, parent, order)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -6, 0, 18)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = Theme.text_primary
    lbl.TextSize = isMobile and 10 or 11
    lbl.Font = Enum.Font.GothamBold
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.LayoutOrder = order
    lbl.Parent = parent
    return lbl
end

local function createStyledInput(placeholder, parent, order)
    local input = Instance.new("TextBox")
    input.Size = UDim2.new(1, 0, 0, buttonHeight)
    input.BackgroundColor3 = Theme.bg_input
    input.PlaceholderText = placeholder
    input.Text = ""
    input.TextColor3 = Theme.text_primary
    input.PlaceholderColor3 = Theme.text_secondary
    input.TextSize = isMobile and 11 or 12
    input.Font = Enum.Font.GothamMedium
    input.LayoutOrder = order
    input.Parent = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = input

    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 1.5
    stroke.Color = Theme.stroke
    stroke.Transparency = 0.5
    stroke.Parent = input

    input.Focused:Connect(function() TweenService:Create(stroke, TweenInfo.new(0.15), { Color = Theme.accent, Transparency = 0.1 }):Play() end)
    input.FocusLost:Connect(function() TweenService:Create(stroke, TweenInfo.new(0.15), { Color = Theme.stroke, Transparency = 0.5 }):Play() end)
    return input
end

local function createToggle(text, parent, order, callback)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, toggleHeight)
    row.BackgroundTransparency = 1
    row.LayoutOrder = order
    row.Parent = parent

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -toggleWidth, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = Theme.text_secondary
    lbl.TextSize = isMobile and 10 or 11
    lbl.Font = Enum.Font.GothamBold
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = row

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, toggleWidth, 1, 0)
    btn.Position = UDim2.new(1, -toggleWidth, 0, 0)
    btn.BackgroundColor3 = Theme.bg_secondary
    btn.Text = "OFF"
    btn.TextSize = isMobile and 9 or 10
    btn.TextColor3 = Theme.text_secondary
    btn.Font = Enum.Font.GothamBlack
    btn.Parent = row

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = btn

    local active = false
    btn.MouseButton1Click:Connect(function()
        active = not active
        if active then
            btn.Text = "ON"
            TweenService:Create(btn, TweenInfo.new(0.15), { BackgroundColor3 = Theme.accent, TextColor3 = Theme.text_light }):Play()
        else
            btn.Text = "OFF"
            TweenService:Create(btn, TweenInfo.new(0.15), { BackgroundColor3 = Theme.bg_secondary, TextColor3 = Theme.text_secondary }):Play()
        end
        if callback then callback(active) end
    end)

    return { isOn = function() return active end, set = function(bool) active = bool; btn.Text = active and "ON" or "OFF"; btn.BackgroundColor3 = active and Theme.accent or Theme.bg_secondary; btn.TextColor3 = active and Theme.text_light or Theme.text_secondary end }
end

local function createStyledButton(text, color, parent, order)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(1, 0, 0, buttonHeight)
    button.BackgroundColor3 = color
    button.Text = text
    button.TextColor3 = Theme.text_light
    button.TextSize = isMobile and 11 or 12
    button.Font = Enum.Font.GothamBlack
    button.LayoutOrder = order
    button.Parent = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = button

    button.MouseEnter:Connect(function() TweenService:Create(button, TweenInfo.new(0.15), { BackgroundColor3 = Theme.accent_hover, Size = UDim2.new(1, 4, 0, buttonHeight + 2) }):Play() end)
    button.MouseLeave:Connect(function() TweenService:Create(button, TweenInfo.new(0.15), { BackgroundColor3 = color, Size = UDim2.new(1, 0, 0, buttonHeight) }):Play() end)
    button.MouseButton1Down:Connect(function() TweenService:Create(button, TweenInfo.new(0.05), { BackgroundColor3 = color:Darken(0.15), Size = UDim2.new(1, 0, 0, buttonHeight - 2) }):Play() end)
    button.MouseButton1Up:Connect(function() TweenService:Create(button, TweenInfo.new(0.15), { BackgroundColor3 = color, Size = UDim2.new(1, 0, 0, buttonHeight) }):Play() end)
    return button
end

-- ================================================================
-- ============= TAB 1: PET SPAWNER =============
-- ================================================================
createSectionLabel("Pet Name", petPage, 1)
local petNameInput = createStyledInput("Enter pet name...", petPage, 2)

createSectionLabel("Potions", petPage, 3)
local potionRow = Instance.new("Frame")
potionRow.Size = UDim2.new(1, 0, 0, toggleHeight)
potionRow.BackgroundTransparency = 1
potionRow.LayoutOrder = 4
potionRow.Parent = petPage

local potionLayout = Instance.new("UIListLayout")
potionLayout.FillDirection = Enum.FillDirection.Horizontal
potionLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
potionLayout.Padding = UDim.new(0, 6)
potionLayout.Parent = potionRow

local mfrToggle = createToggle("MFR", potionRow, 1)
local nfrToggle = createToggle("NFR", potionRow, 2)
local frToggle = createToggle("FR", potionRow, 3)

mfrToggle.Parent.Size = UDim2.new(0.31, 0, 1, 0)
nfrToggle.Parent.Size = UDim2.new(0.31, 0, 1, 0)
frToggle.Parent.Size = UDim2.new(0.31, 0, 1, 0)
mfrToggle.Parent.row.lbl.Visible = false
nfrToggle.Parent.row.lbl.Visible = false
frToggle.Parent.row.lbl.Visible = false
mfrToggle.Parent.row.btn.Size = UDim2.new(1, 0, 1, 0)
nfrToggle.Parent.row.btn.Size = UDim2.new(1, 0, 1, 0)
frToggle.Parent.row.btn.Size = UDim2.new(1, 0, 1, 0)

createSectionLabel("Options", petPage, 5)
local isAltToggle = createToggle("Equip as Alt Pet (Handler Only)", petPage, 6)

local spawnPetButton = createStyledButton("Spawn Pet", Theme.accent, petPage, 7)
local spawnHighButton = createStyledButton("Spawn All High Tiers", Color3.fromRGB(255, 105, 180), petPage, 8)
local spawnAllPetsButton = createStyledButton("★ Spawn ALL Game Pets ★", Color3.fromRGB(220, 20, 60), petPage, 9)

-- ================================================================
-- ============= TAB 2: ITEM SPAWNER =============
-- ================================================================
createSectionLabel("Item Name", itemPage, 1)
local itemNameInput = createStyledInput("Enter item name...", itemPage, 2)

createSectionLabel("Item Category", itemPage, 3)
local categoryDropdown = createStyledInput("toys / food / gifts / strollers / roleplay / stickers / transport / pet_accessories", itemPage, 4)

local spawnItemButton = createStyledButton("Spawn Item", Theme.accent, itemPage, 5)
local equipToyButton = createStyledButton("Equip Item Tool", Color3.fromRGB(240, 120, 160), itemPage, 6)
local unequipToyButton = createStyledButton("Unequip Fake Tools", Theme.text_secondary, itemPage, 7)

-- ================================================================
-- ============= TAB 3: FEATURES / LABELS =============
-- ================================================================
local function createFeatureItem(text, parent, order)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 22)
    row.BackgroundTransparency = 1
    row.LayoutOrder = order
    row.Parent = parent
    local dot = Instance.new("TextLabel")
    dot.Size = UDim2.new(0, 14, 1, 0)
    dot.BackgroundTransparency = 1
    dot.Text = "✿"
    dot.TextColor3 = Theme.accent
    dot.TextSize = isMobile and 8 or 10
    dot.Font = Enum.Font.GothamBold
    dot.Parent = row
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -18, 1, 0)
    lbl.Position = UDim2.new(0, 18, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = Theme.text_primary
    lbl.TextSize = isMobile and 10 or 11
    lbl.Font = Enum.Font.GothamMedium
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = row
end

local function createDivider(parent, order)
    local div = Instance.new("Frame")
    div.Size = UDim2.new(1, 0, 0, 2)
    div.BackgroundColor3 = Theme.stroke
    div.BackgroundTransparency = 0.6
    div.BorderSizePixel = 0
    div.LayoutOrder = order
    div.Parent = parent
end

createSectionLabel("Pet Handler Settings", featuresPage, 1)
local handlerRow = Instance.new("Frame")
handlerRow.Size = UDim2.new(1, 0, 0, buttonHeight)
handlerRow.BackgroundTransparency = 1
handlerRow.LayoutOrder = 2
handlerRow.Parent = featuresPage

local handlerToggleBtn = Instance.new("TextButton")
handlerToggleBtn.Size = UDim2.new(0.6, -4, 1, 0)
handlerToggleBtn.BackgroundColor3 = Theme.bg_secondary
handlerToggleBtn.Text = "Pet Handler: OFF"
handlerToggleBtn.TextColor3 = Theme.text_secondary
handlerToggleBtn.TextSize = isMobile and 10 or 11
handlerToggleBtn.Font = Enum.Font.GothamBlack
handlerToggleBtn.Parent = handlerRow

local hCorner = Instance.new("UICorner")
hCorner.CornerRadius = UDim.new(0, 8)
hCorner.Parent = handlerToggleBtn

local certBtn = Instance.new("TextButton")
certBtn.Size = UDim2.new(0.4, -4, 1, 0)
certBtn.Position = UDim2.new(0.6, 4, 0, 0)
certBtn.BackgroundColor3 = Theme.accent
certBtn.Text = "Show Cert"
certBtn.TextColor3 = Theme.text_light
certBtn.TextSize = isMobile and 10 or 11
certBtn.Font = Enum.Font.GothamBlack
certBtn.Parent = handlerRow

local cCorner = Instance.new("UICorner")
cCorner.CornerRadius = UDim.new(0, 8)
cCorner.Parent = certBtn

createDivider(featuresPage, 3)
createSectionLabel("Features Menu", featuresPage, 5)
createFeatureItem("Rideable and Flyable!", featuresPage, 6)
createFeatureItem("Tradeable!", featuresPage, 7)
createFeatureItem("Shows in the Trading License!", featuresPage, 8)
createFeatureItem("Pet Handler: Equip 2 pets at once!", featuresPage, 9)
createFeatureItem("Spawn & equip toys with animations!", featuresPage, 10)
createFeatureItem("Spawn Pet Wear (accessories)!", featuresPage, 11)
createDivider(featuresPage, 12)

local comingSoon = Instance.new("TextLabel")
comingSoon.Size = UDim2.new(1, 0, 0, 36)
comingSoon.BackgroundTransparency = 1
comingSoon.Text = "Will add more features in the future!\nDon't forget to share and enjoy! ✿"
comingSoon.TextColor3 = Theme.text_secondary
comingSoon.TextSize = isMobile and 8 or 10
comingSoon.Font = Enum.Font.GothamBold
comingSoon.TextWrapped = true
comingSoon.LayoutOrder = 14
comingSoon.Parent = featuresPage

-- ==================== FOOTER ====================
local footer = Instance.new("Frame")
footer.Size = UDim2.new(1, 0, 0, 26)
footer.Position = UDim2.new(0, 0, 1, -26)
footer.BackgroundColor3 = Theme.footer_bg
footer.BorderSizePixel = 0
footer.Parent = mainFrame

local footerCorner = Instance.new("UICorner")
footerCorner.CornerRadius = UDim.new(0, 16)
footerCorner.Parent = footer

local footerFix = Instance.new("Frame")
footerFix.Size = UDim2.new(1, 0, 0, 12)
footerFix.BackgroundColor3 = Theme.footer_bg
footerFix.BorderSizePixel = 0
footerFix.Parent = footer

local credits = Instance.new("TextLabel")
credits.Size = UDim2.new(1, 0, 1, 0)
credits.BackgroundTransparency = 1
credits.Text = "✿ replicated.storage on Discord ✿"
credits.TextColor3 = Theme.text_secondary
credits.TextSize = isMobile and 8 or 9
credits.Font = Enum.Font.GothamBold
credits.Parent = footer

-- ================================================================
-- ACTION CONNECTIONS & CONTROLS
-- ================================================================
spawnPetButton.MouseButton1Click:Connect(function()
    if _G.spawn_pet then
        local petName = petNameInput.Text
        if petName == "" then return end
        local isMegaNeon = mfrToggle.isOn()
        local isNeon = nfrToggle.isOn() or mfrToggle.isOn()
        local isRideable = mfrToggle.isOn() or nfrToggle.isOn() or frToggle.isOn()
        local isFlyable = mfrToggle.isOn() or nfrToggle.isOn() or frToggle.isOn()
        local options = {
            neon = isNeon and not isMegaNeon, mega_neon = isMegaNeon, rideable = isRideable, flyable = isFlyable,
            trick_level = 5, age = isMegaNeon and 6 or math.random(1, 6), friendship_level = isMegaNeon and math.random(1, 20) or nil, rp_name = ""
        }
        local spawned = _G.spawn_pet(petName, options)
        if spawned and isAltToggle.isOn() and _G._EquipPet then
            task.wait(0.1)
            _G._EquipPet(spawned, true)
        end
    end
end)

spawnHighButton.MouseButton1Click:Connect(function()
    if _G.spawn_high_tier_pets then
        local isMegaNeon = mfrToggle.isOn()
        local isNeon = nfrToggle.isOn() or mfrToggle.isOn()
        local isRideable = mfrToggle.isOn() or nfrToggle.isOn() or frToggle.isOn()
        local isFlyable = mfrToggle.isOn() or nfrToggle.isOn() or frToggle.isOn()
        local options = {
            neon = isNeon and not isMegaNeon, mega_neon = isMegaNeon, rideable = isRideable, flyable = isFlyable,
            trick_level = 5, age = isMegaNeon and 6 or math.random(1, 6), friendship_level = isMegaNeon and math.random(1, 20) or nil, rp_name = ""
        }
        local pets = _G.spawn_high_tier_pets(options)
        print("Spawned " .. #pets .. " high tier pets!")
    end
end)

spawnAllPetsButton.MouseButton1Click:Connect(function()
    if _G.spawn_pet and _G.InventoryDB then
        local spawnedCount = 0
        local isMegaNeon = mfrToggle.isOn()
        local isNeon = nfrToggle.isOn() or mfrToggle.isOn()
        local isRideable = mfrToggle.isOn() or nfrToggle.isOn() or frToggle.isOn()
        local isFlyable = mfrToggle.isOn() or nfrToggle.isOn() or frToggle.isOn()
        local options = {
            neon = isNeon and not isMegaNeon, mega_neon = isMegaNeon, rideable = isRideable, flyable = isFlyable,
            trick_level = 5, age = isMegaNeon and 6 or math.random(1, 6), friendship_level = isMegaNeon and math.random(1, 20) or nil, rp_name = ""
        }
        local groupSnapshot = table.clone(newnessOrderGroups)
        for petId, _ in pairs(_G.InventoryDB.pets) do
            local item = _G.spawn_pet(petId, options)
            if item then spawnedCount = spawnedCount + 1 end
            if spawnedCount % 40 == 0 then task.wait(0.1) end
        end
        for k, v in pairs(groupSnapshot) do newnessOrderGroups[k] = v end
    end
end)

spawnItemButton.MouseButton1Click:Connect(function()
    if _G.spawn_item then
        local name = itemNameInput.Text
        local cat = categoryDropdown.Text:lower()
        if name == "" or cat == "" then return end
        _G.spawn_item(name, cat)
    end
end)

equipToyButton.MouseButton1Click:Connect(function()
    if _G.equip_toy then
        local name = itemNameInput.Text
        if name == "" then return end
        _G.equip_toy(name)
    end
end)

unequipToyButton.MouseButton1Click:Connect(function()
    if _G.unequip_toy then _G.unequip_toy() end
end)

local handlerIsOn = false
handlerToggleBtn.MouseButton1Click:Connect(function()
    handlerIsOn = not handlerIsOn
    if handlerIsOn then
        handlerToggleBtn.Text = "Pet Handler: ON"
        TweenService:Create(handlerToggleBtn, TweenInfo.new(0.15), { BackgroundColor3 = Theme.accent, TextColor3 = Theme.text_light }):Play()
        if _G._PetHandler_Toggle then _G._PetHandler_Toggle(true) end
        game:GetService("StarterGui"):SetCore("SendNotification", { Title = "Pet Handler", Text = "Enabled - Multi-Spawning Activated", Duration = 3 })
    else
        handlerToggleBtn.Text = "Pet Handler: OFF"
        TweenService:Create(handlerToggleBtn, TweenInfo.new(0.15), { BackgroundColor3 = Theme.bg_secondary, TextColor3 = Theme.text_secondary }):Play()
        if _G._PetHandler_Toggle then _G._PetHandler_Toggle(false) end
        game:GetService("StarterGui"):SetCore("SendNotification", { Title = "Pet Handler", Text = "Disabled - back to 1 pet", Duration = 3 })
    end
end)

certBtn.MouseButton1Click:Connect(function()
    if not handlerIsOn then
        game:GetService("StarterGui"):SetCore("SendNotification", { Title = "Pet Handler", Text = "Enable Pet Handler first!", Duration = 3 })
        return
    end
    if _G._PetHandler_ShowCert then _G._PetHandler_ShowCert() end
end)

handlerToggleBtn.MouseEnter:Connect(function() TweenService:Create(handlerToggleBtn, TweenInfo.new(0.15), { Size = UDim2.new(0.6, -4, 1, 3) }):Play() end)
handlerToggleBtn.MouseLeave:Connect(function() TweenService:Create(handlerToggleBtn, TweenInfo.new(0.15), { Size = UDim2.new(0.6, -4, 1, 0) }):Play() end)
certBtn.MouseEnter:Connect(function() TweenService:Create(certBtn, TweenInfo.new(0.15), { Size = UDim2.new(0.4, -4, 1, 3) }):Play() end)
certBtn.MouseLeave:Connect(function() TweenService:Create(certBtn, TweenInfo.new(0.15), { Size = UDim2.new(0.4, -4, 1, 0) }):Play() end)

-- UI Glow & Styling Transitions
container.ChildAdded:Connect(function(child)
    if child:IsA("TextButton") then
        child.MouseEnter:Connect(function() TweenService:Create(child, TweenInfo.new(0.2), { BackgroundTransparency = 0 }):Play() end)
        child.MouseLeave:Connect(function() TweenService:Create(child, TweenInfo.new(0.2), { BackgroundTransparency = child.Name:find("Tab") and 0 or 0.2 }):Play() end)
    end
end)

local function applyGlowEffects(child)
    if child:IsA("Frame") or child:IsA("ScrollingFrame") then
        if child.Name ~= "TopBar" and child.Name ~= "TabBar" and child.Name ~= "Shadow" then
            local target = (child.BackgroundTransparency == 1) and 1 or 0
            TweenService:Create(child, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = target }):Play()
        end
    end
    if child:IsA("UIStroke") then
        local target = (child.Parent and child.Parent:IsA("TextBox")) and 0.5 or 0.3
        TweenService:Create(child, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Transparency = target }):Play()
    end
end

local titleGlowDir, titleGlowVal = 1, 0.6
RunService.RenderStepped:Connect(function(delta)
    titleGlowVal = titleGlowVal + (delta * 0.8 * titleGlowDir)
    if titleGlowVal >= 0.7 then titleGlowDir = -1 elseif titleGlowVal <= 0.3 then titleGlowDir = 1 end
    titleLabel.TextStrokeTransparency = titleGlowVal
    titleLabel.TextStrokeColor3 = Color3.fromRGB(255, 130, 180)
end)

local footerGlowDir, footerGlowVal = -1, 0.4
RunService.RenderStepped:Connect(function(delta)
    footerGlowVal = footerGlowVal + (delta * 0.5 * footerGlowDir)
    if footerGlowVal >= 0.6 then footerGlowDir = -1 elseif footerGlowVal <= 0.2 then footerGlowDir = 1 end
    credits.TextTransparency = footerGlowVal
end)

switchTab("Pet")
