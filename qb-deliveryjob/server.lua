local QBCore = exports[Config.Core]:GetCoreObject()
local activePlayers = {}

RegisterNetEvent('delivery:server:giveReward', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    if not activePlayers[src] then
        DropPlayer(src, "Attempted exploit detection")
        return
    end

    local reward = math.random(Config.Job.rewardMin, Config.Job.rewardMax)
    Player.Functions.AddMoney('bank', reward, "delivery-job-payment")
    
    if Config.Job.reputationEnabled then
        Player.Functions.AddReputation('delivery', Config.Job.reputationReward)
    end
    
    TriggerClientEvent('QBCore:Notify', src, "You received $"..reward.." for completing the delivery!", "success")
    activePlayers[src] = nil
end)

QBCore.Functions.CreateCallback('delivery:server:canStartJob', function(source, cb)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then 
        cb(false) 
        return 
    end

    if Config.Job.requireItems then
        for _, item in pairs(Config.Job.requiredItems) do
            if not Player.Functions.GetItemByName(item) then
                TriggerClientEvent('QBCore:Notify', src, "You're missing required items!", "error")
                cb(false)
                return
            end
        end
    end
    
    if Config.Job.requireJob and Player.PlayerData.job.name ~= Config.Job.requiredJob then
        TriggerClientEvent('QBCore:Notify', src, "You don't have the required job!", "error")
        cb(false)
        return
    end

    activePlayers[src] = true
    cb(true)
end)

RegisterNetEvent('delivery:server:trackDelivery', function(deliveryTime, boxesDelivered)
    local src = source
    if not activePlayers[src] then return end
end)

QBCore.Commands.Add('resetdelivery', 'Reset delivery job (Admin Only)', {}, false, function(source, args)
    local src = source
    if QBCore.Functions.HasPermission(src, 'admin') then
        TriggerClientEvent('delivery:client:cleanupJob', src)
        TriggerClientEvent('QBCore:Notify', src, "Delivery job has been reset.", "success")
    else
        TriggerClientEvent('QBCore:Notify', src, "You don't have permission for this.", "error")
    end
end, 'admin')

AddEventHandler('playerDropped', function(reason)
    local src = source
    activePlayers[src] = nil
end)