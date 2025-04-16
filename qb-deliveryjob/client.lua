local QBCore = exports[Config.Core]:GetCoreObject()
local spawnedBoxes = {}
local spawnedVehicles = {}
local boxesAttached = false
local deliveryStarted = false
local deliveryLocation = nil
local deliveryBlip = nil
local returnBlip = nil
local forkliftEntity = nil
local jobNPC = nil
local deliveryNPC = nil
local targetBoxes = {}
local targetVehicles = {}


local function LoadModel(model)
    RequestModel(model)
    while not HasModelLoaded(model) do
        Wait(0)
    end
end

function SetupJobNPC()
    local npcCoords = Config.JobNPC.coords
    local model = GetHashKey(Config.JobNPC.model)
    
    LoadModel(model)
    
    if jobNPC and DoesEntityExist(jobNPC) then
        DeleteEntity(jobNPC)
    end
    
    jobNPC = CreatePed(4, model, npcCoords.x, npcCoords.y, npcCoords.z - 1.0, npcCoords.w, false, true)
    FreezeEntityPosition(jobNPC, true)
    SetEntityInvincible(jobNPC, true)
    SetBlockingOfNonTemporaryEvents(jobNPC, true)
    TaskStartScenarioInPlace(jobNPC, Config.JobNPC.scenario, 0, true)
    
    exports[Config.Target]:AddBoxZone("delivery_job_npc", vector3(npcCoords.x, npcCoords.y, npcCoords.z), 1.0, 1.0, {
        name = "delivery_job_npc",
        heading = npcCoords.w,
        debugPoly = Config.Debug,
    }, {
        options = {
            {
                type = "client",
                event = "delivery:client:openMenu",
                icon = "fas fa-box",
                label = "Talk to Delivery Manager",
            },
        },
        distance = 2.0
    })

    CreateThread(function()
        while DoesEntityExist(jobNPC) do
            local playerPed = PlayerPedId()
            local playerCoords = GetEntityCoords(playerPed)
            local npcCoords = GetEntityCoords(jobNPC)
            
            if #(playerCoords - npcCoords) < 3.0 then
                TaskTurnPedToFaceCoord(jobNPC, playerCoords.x, playerCoords.y, playerCoords.z, -1)
            end
            Wait(1000)
        end
    end)
end

function SpawnBoxes()
    for i = 1, #Config.Boxes.coords do
        local model = GetHashKey(Config.Boxes.models[i])
        LoadModel(model)
        
        local boxCoords = Config.Boxes.coords[i]
        local _, groundZ = GetGroundZFor_3dCoord(boxCoords.x, boxCoords.y, boxCoords.z, false)
        
        local box = CreateObject(model, boxCoords.x, boxCoords.y, groundZ or boxCoords.z, true, false, false)
        PlaceObjectOnGroundProperly(box)
        SetEntityHeading(box, boxCoords.w or 0.0)
        
        targetBoxes[i] = exports[Config.Target]:AddTargetEntity(box, {
            options = {
                {
                    type = "client",
                    event = "delivery:client:checkBoxStatus",
                    icon = "fas fa-search",
                    label = "Check Box",
                    boxId = i,
                },
            },
            distance = 5.0
        })
        
        spawnedBoxes[i] = box
    end
    
    QBCore.Functions.Notify("Boxes have been spawned. Use the forklift to pick them up.", "primary")
end

function SpawnVehicles()
    local forkliftConfig = Config.Vehicles.forklift
    local truckConfig = Config.Vehicles.truck
    local trailerConfig = Config.Vehicles.trailer
    
    QBCore.Functions.TriggerCallback('delivery:server:canStartJob', function(canStart)
        if not canStart then return end

        QBCore.Functions.SpawnVehicle(forkliftConfig.model, function(forklift)
            SetEntityHeading(forklift, forkliftConfig.heading)
            local plate = "DELJOB"..tostring(math.random(1000, 9999))
            SetVehicleNumberPlateText(forklift, plate)
            SetEntityAsMissionEntity(forklift, true, true)
            TriggerEvent("vehiclekeys:client:SetOwner", plate)
            exports[Config.FuelSystem]:SetFuel(forklift, 100.0)
            spawnedVehicles[#spawnedVehicles+1] = forklift
            forkliftEntity = forklift
        end, forkliftConfig.coords, true)
        
        QBCore.Functions.SpawnVehicle(truckConfig.model, function(truck)
            SetEntityHeading(truck, truckConfig.heading)
            local plate = "DELJOB"..tostring(math.random(1000, 9999))
            SetVehicleNumberPlateText(truck, plate)
            SetEntityAsMissionEntity(truck, true, true)
            TriggerEvent("vehiclekeys:client:SetOwner", plate)
            exports[Config.FuelSystem]:SetFuel(truck, 100.0)
            spawnedVehicles[#spawnedVehicles+1] = truck
            
            QBCore.Functions.SpawnVehicle(trailerConfig.model, function(trailer)
                SetEntityHeading(trailer, trailerConfig.heading)
                SetVehicleNumberPlateText(trailer, "TRLR"..tostring(math.random(1000, 9999)))
                SetEntityAsMissionEntity(trailer, true, true)
                spawnedVehicles[#spawnedVehicles+1] = trailer
                
                targetVehicles.trailer = exports[Config.Target]:AddTargetEntity(trailer, {
                    options = {
                        {
                            type = "client",
                            event = "delivery:client:secureBoxesToTrailer",
                            icon = "fas fa-lock",
                            label = "Secure Boxes to Trailer",
                        },
                    },
                    distance = 3.0
                })
            end, trailerConfig.coords, true)
        end, truckConfig.coords, true)
        
        QBCore.Functions.Notify("Vehicles have been spawned. Use the forklift to lift boxes and place them on the trailer.", "success")
    end)
end

function SelectDeliveryLocation()
    local randomIndex = math.random(1, #Config.DeliveryLocations)
    deliveryLocation = Config.DeliveryLocations[randomIndex]
    
    if deliveryBlip then
        RemoveBlip(deliveryBlip)
    end
    
    deliveryBlip = AddBlipForCoord(deliveryLocation.npcCoords.x, deliveryLocation.npcCoords.y, deliveryLocation.npcCoords.z)
    SetBlipSprite(deliveryBlip, deliveryLocation.blipSprite)
    SetBlipDisplay(deliveryBlip, 4)
    SetBlipScale(deliveryBlip, 0.8)
    SetBlipColour(deliveryBlip, deliveryLocation.blipColor)
    SetBlipAsShortRange(deliveryBlip, false)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Delivery Location")
    EndTextCommandSetBlipName(deliveryBlip)
    SetBlipRoute(deliveryBlip, true)
    
    QBCore.Functions.Notify("Delivery location has been marked on your GPS.", "success")
    
    local model = GetHashKey('a_m_y_business_01')
    LoadModel(model)
    
    if deliveryNPC and DoesEntityExist(deliveryNPC) then
        DeleteEntity(deliveryNPC)
    end
    
    deliveryNPC = CreatePed(4, model, deliveryLocation.npcCoords.x, deliveryLocation.npcCoords.y, deliveryLocation.npcCoords.z - 1.0, deliveryLocation.npcCoords.w, false, true)
    FreezeEntityPosition(deliveryNPC, true)
    SetEntityInvincible(deliveryNPC, true)
    SetBlockingOfNonTemporaryEvents(deliveryNPC, true)
    TaskStartScenarioInPlace(deliveryNPC, "WORLD_HUMAN_CLIPBOARD", 0, true)
    
    exports[Config.Target]:AddTargetEntity(deliveryNPC, {
        options = {
            {
                type = "client",
                event = "delivery:client:completeDelivery",
                icon = "fas fa-clipboard-check",
                label = "Complete Delivery",
            },
        },
        distance = 2.0
    })
    
    if forkliftEntity and DoesEntityExist(forkliftEntity) then
        DeleteVehicle(forkliftEntity)
        forkliftEntity = nil
    end
end

function SecureBoxesToTrailer()
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    
    local trailer = GetClosestVehicleOfType(playerCoords, 10.0, GetHashKey(Config.Vehicles.trailer.model))
    if not trailer or not DoesEntityExist(trailer) then
        QBCore.Functions.Notify("No trailer found nearby!", "error")
        return
    end
    
    local trailerCoords = GetEntityCoords(trailer)
    if #(playerCoords - trailerCoords) > 5.0 then
        QBCore.Functions.Notify("You need to be closer to the trailer to secure boxes!", "error")
        return
    end
    
    local boxesOnTrailer = 0
    local boxesFound = {}
    
    for i = 1, #spawnedBoxes do
        local box = spawnedBoxes[i]
        if DoesEntityExist(box) then
            local boxCoords = GetEntityCoords(box)
            local distToTrailer = #(boxCoords - trailerCoords)
            
            if distToTrailer < Config.Job.boxDetectionRange and 
               (boxCoords.z > (trailerCoords.z + 0.2)) and 
               (boxCoords.z < (trailerCoords.z + 1.5)) then
                boxesOnTrailer = boxesOnTrailer + 1
                boxesFound[#boxesFound+1] = {entity = box, index = i}
            end
        end
    end
    
    if boxesOnTrailer == 0 then
        QBCore.Functions.Notify("No boxes found on the trailer", "error")
        return
    end
    
    local trailerHeading = GetEntityHeading(trailer)
    local boxPositions = {
        vector3(-0.1, -2.0, 0.4),
        vector3(0.1, 0.0, 0.4),
        vector3(-0.1, 2.0, 0.4),
    }
    
    for i, boxData in ipairs(boxesFound) do
        if i <= #boxPositions then
            local box = boxData.entity
            local boxId = boxData.index
            local posOffset = boxPositions[i]
            
            DetachEntity(box, true, true)
            AttachEntityToEntity(box, trailer, 0, posOffset.x, posOffset.y, posOffset.z, 0.0, 0.0, 0.0, true, true, false, false, 2, true)
            
            if targetBoxes[boxId] then
                exports[Config.Target]:RemoveTargetEntity(box, targetBoxes[boxId])
            end
            
            targetBoxes[boxId] = exports[Config.Target]:AddTargetEntity(box, {
                options = {
                    {
                        type = "client",
                        event = "delivery:client:detachBox",
                        icon = "fas fa-unlock",
                        label = "Detach Box",
                        boxId = boxId,
                    },
                },
                distance = 5.0
            })
            
            QBCore.Functions.Notify("Box " .. boxId .. " secured to trailer!", "success")
        end
    end
    
    if boxesOnTrailer >= Config.Job.requiredBoxes and not deliveryStarted then
        boxesAttached = true
        QBCore.Functions.Notify("All boxes are secured! Head to the delivery location.", "success")
        SelectDeliveryLocation()
        deliveryStarted = true
    else
        QBCore.Functions.Notify("You have secured " .. boxesOnTrailer .. "/" .. Config.Job.requiredBoxes .. " boxes.", "primary")
    end
end

function CompleteDelivery()
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    
    if not deliveryLocation or #(playerCoords.xy - deliveryLocation.npcCoords.xy) > 5.0 then
        QBCore.Functions.Notify("You need to be closer to the delivery NPC!", "error")
        return
    end
    
    for i = 1, #spawnedBoxes do
        if DoesEntityExist(spawnedBoxes[i]) then
            local boxCoords = GetEntityCoords(spawnedBoxes[i])
            if #(boxCoords.xy - deliveryLocation.npcCoords.xy) > Config.Job.deliveryRange then
                QBCore.Functions.Notify("All boxes must be unloaded at the delivery point!", "error")
                return
            end
        end
    end
    
    if deliveryBlip then
        RemoveBlip(deliveryBlip)
        deliveryBlip = nil
    end
    
    for i = 1, #spawnedBoxes do
        if DoesEntityExist(spawnedBoxes[i]) then
            DeleteEntity(spawnedBoxes[i])
            if targetBoxes[i] then
                exports[Config.Target]:RemoveTargetEntity(spawnedBoxes[i], targetBoxes[i])
            end
        end
    end
    
    spawnedBoxes = {}
    targetBoxes = {}
    
    returnBlip = AddBlipForCoord(Config.JobNPC.coords.x, Config.JobNPC.coords.y, Config.JobNPC.coords.z)
    SetBlipSprite(returnBlip, 477)
    SetBlipDisplay(returnBlip, 4)
    SetBlipScale(returnBlip, 0.8)
    SetBlipColour(returnBlip, 5)
    SetBlipAsShortRange(returnBlip, false)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Return Truck")
    EndTextCommandSetBlipName(returnBlip)
    SetBlipRoute(returnBlip, true)
    
    QBCore.Functions.Notify("Delivery completed! Return the truck to the depot to get paid.", "success")
    
    local truck = GetClosestVehicleOfType(playerCoords, 20.0, GetHashKey(Config.Vehicles.truck.model))
    if truck then
        targetVehicles.truck = exports[Config.Target]:AddTargetEntity(truck, {
            options = {
                {
                    type = "client",
                    event = "delivery:client:returnTruck",
                    icon = "fas fa-truck",
                    label = "Return Truck",
                },
            },
            distance = 3.0
        })
    end
end

function DetachBox(data)
    local boxId = data.boxId
    local box = spawnedBoxes[boxId]
    
    if box and DoesEntityExist(box) then
        DetachEntity(box, true, true)
        if targetBoxes[boxId] then
            exports[Config.Target]:RemoveTargetEntity(box, targetBoxes[boxId])
            targetBoxes[boxId] = exports[Config.Target]:AddTargetEntity(box, {
                options = {
                    {
                        type = "client",
                        event = "delivery:client:checkBoxStatus",
                        icon = "fas fa-search",
                        label = "Check Box",
                        boxId = boxId,
                    },
                },
                distance = 5.0
            })
        end
        QBCore.Functions.Notify("Box detached from trailer.", "success")
    end
end

function ReturnTruck()
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local npcCoords = Config.JobNPC.coords
    
    if #(playerCoords.xy - npcCoords.xy) > 10.0 then
        QBCore.Functions.Notify("You need to be at the depot to return the truck!", "error")
        return
    end
    
    local vehicle = GetVehiclePedIsIn(playerPed, false)
    if not vehicle or GetEntityModel(vehicle) ~= GetHashKey(Config.Vehicles.truck.model) then
        QBCore.Functions.Notify("You must be in the delivery truck to return it!", "error")
        return
    end
    
    CleanupJob()
    
    if returnBlip then
        RemoveBlip(returnBlip)
        returnBlip = nil
    end
    
    TriggerServerEvent("delivery:server:giveReward")
    QBCore.Functions.Notify("Truck returned successfully! You have been paid. Talk to the manager to start a new delivery.", "success")
end

function CleanupJob(keepMenu)
    for i = 1, #spawnedBoxes do
        if DoesEntityExist(spawnedBoxes[i]) then
            DeleteEntity(spawnedBoxes[i])
            if targetBoxes[i] then
                exports[Config.Target]:RemoveTargetEntity(spawnedBoxes[i], targetBoxes[i])
            end
        end
    end
    spawnedBoxes = {}
    targetBoxes = {}
    
    for i = 1, #spawnedVehicles do
        if DoesEntityExist(spawnedVehicles[i]) then
            DeleteVehicle(spawnedVehicles[i])
        end
    end
    spawnedVehicles = {}

    for _, target in pairs(targetVehicles) do
        exports[Config.Target]:RemoveZone(target)
    end
    targetVehicles = {}
    
    if deliveryBlip then
        RemoveBlip(deliveryBlip)
        deliveryBlip = nil
    end
    
    if returnBlip then
        RemoveBlip(returnBlip)
        returnBlip = nil
    end
    
    if deliveryNPC and DoesEntityExist(deliveryNPC) then
        DeleteEntity(deliveryNPC)
        deliveryNPC = nil
    end
    

    deliveryStarted = false
    boxesAttached = false
    deliveryLocation = nil
    forkliftEntity = nil
    
    if not keepMenu then
        QBCore.Functions.Notify("Job cleaned up. All vehicles and boxes have been removed.", "success")
    end
end

function StartNewDelivery()
    CleanupJob(true)
    QBCore.Functions.Notify("Starting new delivery job...", "success")
    SpawnVehicles()
    SpawnBoxes()
end


RegisterNetEvent('delivery:client:openMenu', function()
    local deliveryMenu = {
        {
            header = "Delivery Job",
            isMenuHeader = true
        },
        {
            header = "Start Delivery Job",
            txt = "Begin work as a delivery driver",
            params = {
                event = "delivery:client:startJob",
            }
        },
        {
            header = "Complete Delivery",
            txt = "Finish the current delivery and start a new one",
            params = {
                event = "delivery:client:startNewDelivery",
            }
        },
        {
            header = "Cancel Current Job",
            txt = "Cancel your current delivery job",
            params = {
                event = "delivery:client:cancelJob",
            }
        },
        {
            header = "Close Menu",
            txt = "",
            params = {
                event = "qb-menu:client:closeMenu",
            }
        },
    }
    exports[Config.Menu]:openMenu(deliveryMenu)
end)

RegisterNetEvent('delivery:client:startJob', function()
    if not deliveryStarted then
        QBCore.Functions.Notify("Starting delivery job...", "success")
        SpawnVehicles()
        SpawnBoxes()
    else
        QBCore.Functions.Notify("You already have an active delivery job!", "error")
    end
end)

RegisterNetEvent('delivery:client:startNewDelivery', function()
    StartNewDelivery()
end)

RegisterNetEvent('delivery:client:cancelJob', function()
    if deliveryStarted or #spawnedBoxes > 0 or #spawnedVehicles > 0 then
        CleanupJob()
    else
        QBCore.Functions.Notify("You don't have an active delivery job to cancel.", "error")
    end
end)

RegisterNetEvent('delivery:client:secureBoxesToTrailer', function()
    SecureBoxesToTrailer()
end)

RegisterNetEvent('delivery:client:detachBox', function(data)
    DetachBox(data)
end)

RegisterNetEvent('delivery:client:completeDelivery', function()
    CompleteDelivery()
end)

RegisterNetEvent('delivery:client:returnTruck', function()
    ReturnTruck()
end)

RegisterNetEvent('delivery:client:cleanupJob', function()
    CleanupJob()
end)

function GetClosestVehicleOfType(coords, maxDistance, modelHash)
    local vehicles = GetGamePool('CVehicle')
    local closestVehicle = nil
    local closestDistance = maxDistance
    
    for _, vehicle in ipairs(vehicles) do
        if GetEntityModel(vehicle) == modelHash then
            local vehicleCoords = GetEntityCoords(vehicle)
            local distance = #(coords - vehicleCoords)
            
            if distance < closestDistance then
                closestVehicle = vehicle
                closestDistance = distance
            end
        end
    end
    
    return closestVehicle
end


AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        SetupJobNPC()
    end
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    SetupJobNPC()
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        CleanupJob()
        if jobNPC and DoesEntityExist(jobNPC) then
            DeleteEntity(jobNPC)
        end
    end
end)


RegisterCommand("delivery_debug", function()
    if not Config.Debug then
        QBCore.Functions.Notify("Debug mode is disabled in config", "error")
        return
    end
    
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    
    print("Player coords: " .. playerCoords.x .. ", " .. playerCoords.y .. ", " .. playerCoords.z)
    
    local trailer = GetClosestVehicleOfType(playerCoords, 50.0, GetHashKey(Config.Vehicles.trailer.model))
    
    if trailer then
        local trailerCoords = GetEntityCoords(trailer)
        print("Trailer found at: " .. trailerCoords.x .. ", " .. trailerCoords.y .. ", " .. trailerCoords.z)
        print("Distance to trailer: " .. #(playerCoords - trailerCoords))
        
        for i = 1, #spawnedBoxes do
            local box = spawnedBoxes[i]
            if DoesEntityExist(box) then
                local boxCoords = GetEntityCoords(box)
                local distToTrailer = #(boxCoords - trailerCoords)
                print("Box " .. i .. " coords: " .. boxCoords.x .. ", " .. boxCoords.y .. ", " .. boxCoords.z)
                print("Box " .. i .. " distance to trailer: " .. distToTrailer)
                print("Box " .. i .. " height diff: " .. (boxCoords.z - trailerCoords.z))
            else
                print("Box " .. i .. " does not exist")
            end
        end
    else
        print("No trailer found")
    end
    
    QBCore.Functions.Notify("Debug info printed to console (F8)", "primary")
end, false)