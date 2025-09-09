vRPc = {}
vRP = Proxy.getInterface("vRP")
Tunnel.bindInterface("BW_CallList",vRPc)
Proxy.addInterface("BW_CallList",vRPc)
ASserver = Tunnel.getInterface("BW_CallList","BW_CallList")

RegisterNetEvent("BW_CallList:openCalls")
AddEventHandler("BW_CallList:openCalls", function(rows, jobs)
    SendNUIMessage({
        status = "showCalls"
    })

    for i = 1, #rows, 1 do
        SendNUIMessage({
            status = "addRows",
            id =  rows[i].id,
            date = rows[i].dato,
            message = rows[i].message,
            number = rows[i].number,
            coords = rows[i].coords,
            service = rows[i].service,
            taken = rows[i].taken,
            deleted = tostring(rows[i].deleted),
            job = jobs
        })
    end
    SetTimeout(200, function()
    SetNuiFocus(true, true)
    end)
end)


RegisterNetEvent("BW_CallList:playSound")
AddEventHandler("BW_CallList:playSound", function(volume)
    -- Send the sound message to the UI
    SendNUIMessage({
        status = "playSound",
        volume = volume
    })

    -- ox_lib notification
end)

RegisterNetEvent("BW_CallList:notify")
AddEventHandler("BW_CallList:notify", function(message)
    lib.notify({
        title = 'Opkalds Liste',
        description = 'Nyt Opkald: ' .. message,
        type = 'inform'
    })
end)



RegisterNUICallback("closeCalls", function(data,cb)
    CloseCalls()
    cb("ok")
end)

RegisterNUICallback("takeCall", function(data,cb)
    local playername = GetPlayerName(PlayerId())
    TriggerServerEvent("BW_CallList:takeCall", data.id, playername)
    local coords = json.decode(data.coords)
    SetNewWaypoint(coords.x+0.0001,coords.y+0.0001)
    print(data.id,data.coords)
    cb("ok")
    Wait(50)


end)

RegisterCommand('clearcalls', function()
    -- Ask the server if the player has permission
    TriggerServerEvent('bw_calllist:checkPermission')
end)

RegisterNetEvent('bw_calllist:confirmClear', function()
    local result = lib.alertDialog({
        header = 'Bekræft sletning',
        content = 'Er du sikker på, at du vil slette alle opkald?',
        centered = true,
        cancel = true,
        size = 'md'
    })

    if result == 'confirm' then
        TriggerServerEvent('bw_calllist:clearAllCalls')
    end
end)


RegisterNUICallback("setCall", function(data,cb)
    local coords = json.decode(data.coords)
    SetNewWaypoint(coords.x+0.0001,coords.y+0.0001)
    cb("ok")
    Wait(50)
end)

RegisterNUICallback("deleteCall", function(data, cb)

    -- This will delete the call
    TriggerServerEvent("BW_CallList:deleteCall", data.id)

    -- This will tell the server to do whatever "initOpen2" does for this player

    cb("ok")
    Wait(50)
end)


function CloseCalls()
    SetNuiFocus(false, false)
    SendNUIMessage({status = "hideCalls"})
end

function vRPc.getCoords()
    local ped = GetPlayerPed(-1)
    local coords = GetEntityCoords(ped, true)
    return coords
end