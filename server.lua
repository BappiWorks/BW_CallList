local Tunnel = module("vrp", "lib/Tunnel")
local Proxy = module("vrp", "lib/Proxy")

vRPs = {}
vRP = Proxy.getInterface("vRP")
vRPclient = Tunnel.getInterface("vRP","BW_CallList")
vRP2client = Tunnel.getInterface("BW_CallList","BW_CallList")
Tunnel.bindInterface("BW_CallList",vRPs)
MySQL1 = module("vrp_mysql", "MySQL")


------------------- MySQL ----------------------
MySQL1.createCommand("vRP/BW_CallList_add_entry","INSERT INTO BW_CallList(dato,message,number,coords,service) VALUES(@dato,@message,@number,@coords,@service)")
MySQL1.createCommand("vRP/BW_CallList_update_taken","UPDATE BW_CallList SET taken = @takenby WHERE id = @id")
MySQL1.createCommand("vRP/BW_CallList_update_deleted","DELETE FROM `BW_CallList` WHERE id = @id")
MySQL1.createCommand("vRP/BW_CallList_get_entries","SELECT * FROM `BW_CallList` WHERE `deleted`=0")


--------------- VARIABLES ------------------
local timezone = 0 -- Config, du skal indsætte hvor mange timer du er foran eller bag UTC
local entries = {}


--------------- EVENTS -----------------
-- Server side TriggerEvent("BW_CallList:addTable", tostring(source) (VIGTIG!!!), message, service = PolitiJob eller EMS-Job)
-- Client side TriggerClientEvent("BW_CallList:addTable", source, message, service = PolitiJob eller EMS-Job)
RegisterServerEvent("BW_CallList:addTable")
AddEventHandler("BW_CallList:addTable", function(source, message, service)
    print("Kørt")
    print(source)
    local user_id = vRP.getUserId({source})
    vRP.getUserIdentity({user_id, function(identity)
        vRP2client.getCoords(source, {}, function(coords)
            local x, y, z = table.unpack(coords)
            coords = {["x"] = x, ["y"] = y, ["z"] = z}
            MySQL1.execute("vRP/BW_CallList_add_entry", {
                dato = getDateNow(false),
                message = tostring(message),
                number = tostring(identity.phone),
                coords = json.encode(coords),
                service = tostring(service)
            })

            if service == "PolitiJob" then
                if vRP.hasPermission({user_id, "police.menu"}) then
                    TriggerClientEvent("BW_CallList:playSound", source, 0.1)
                    TriggerClientEvent("BW_CallList:notify", source, message)
                end
            elseif service == "EMS-Job" then
                if vRP.hasPermission({user_id, "emergency.menu"}) then
                    TriggerClientEvent("BW_CallList:playSound", source, 0.1)
                    TriggerClientEvent("BW_CallList:notify", source, message)
                end
            end
        end)
    end})
end)

RegisterNetEvent('bw_calllist:checkPermission', function()
    local src = source
    local user_id = vRP.getUserId(src)
    if not user_id then return end

    if vRP.hasPermission(user_id, "tp.all") then
        -- Send back to client to show dialog
        TriggerClientEvent('bw_calllist:confirmClear', src)
    else
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Ingen adgang',
            description = 'Du har ikke tilladelse til at rydde opkald.',
            type = 'error'
        })
    end
end)

RegisterNetEvent('bw_calllist:clearAllCalls', function()
    -- Clear your stored call data here
    -- Example:
    -- CallList = {}
    TriggerEvent("BW_CallList:deleteAllCalls")
    -- Broadcast update to UIs
    TriggerClientEvent('bw_calllist:refresh', -1)

    -- Optional feedback
    TriggerClientEvent('ox_lib:notify', source, {
        title = 'Ryd Opkald',
        description = 'Alle opkald blev slettet.',
        type = 'success'
    })
end)


RegisterServerEvent("BW_CallList:deleteCall")
AddEventHandler("BW_CallList:deleteCall", function(id)
    MySQL1.execute("vRP/BW_CallList_update_deleted", {deleted = true, id = id})
end)

RegisterServerEvent("BW_CallList:deleteAllCalls")
AddEventHandler("BW_CallList:deleteAllCalls", function()
    MySQL.query("DELETE FROM BW_CallList")
end)



RegisterServerEvent("BW_CallList:takeCall")
AddEventHandler("BW_CallList:takeCall", function(id)
    local source = source
    local user_id = vRP.getUserId({source})
    if user_id then
        MySQL.Async.fetchScalar("SELECT badgeNumber FROM omik_polititabletan WHERE user_id = @user_id", {
            ['@user_id'] = user_id
        }, function(badgeNumber)
            if badgeNumber then
               MySQL1.execute("vRP/BW_CallList_update_taken", {takenby = badgeNumber, id = id})
            else
                print("⚠️ Kunne ikke finde badgeNumber for user_id:", user_id)
            end
        end)
    else
        print("⚠️ Kunne ikke finde user_id for source:", source)
    end
end)

RegisterServerEvent("BW_CallList:initOpen2")
AddEventHandler("BW_CallList:initOpen2", function()
    local src = source
    local user_id = vRP.getUserId({src})
    local jobs = ""
    getCalls(function(entries)
        if vRP.hasPermission({user_id,"police.menu"}) then
            jobs = "PolitiJob"
        elseif vRP.hasPermission({user_id,"emergency.menu"}) then
            jobs = "EMS-Job"
        end
        TriggerClientEvent("BW_CallList:openCalls", src, entries, jobs)
    end)
end)

RegisterServerEvent("BW_CallList:initOpen")
AddEventHandler("BW_CallList:initOpen", function(user_id)
    local source = vRP.getUserSource({user_id})
    local jobs = ""
    getCalls(function(entries)
        if vRP.hasPermission({user_id,"police.menu"}) then
            jobs = "PolitiJob"
        elseif vRP.hasPermission({user_id,"emergency.menu"}) then
            jobs = "EMS-Job"
        end
        TriggerClientEvent("BW_CallList:openCalls", source, entries, jobs)
    end)
end)

---------------- FUNCTIONS ----------------
function getCalls(cbr)
    local task = Task(cbr, {""}) -- if you actually need a default arg, keep it; otherwise pass {}.
    MySQL1.query("vRP/BW_CallList_get_entries", {}, function(rows, affected)
        local entries = {}

        if rows and #rows > 0 then
            for i = 1, #rows do
                local r = rows[i]
                entries[#entries+1] = {
                    id      = r.id,
                    dato    = r.dato,
                    message = r.message,
                    number  = r.number,
                    coords  = r.coords,
                    service = r.service,
                    taken   = r.taken,
                    deleted = r.deleted
                }
            end
        end

        -- ALWAYS call the callback, even when empty:
        task({ entries })
    end)
end


function getDateNow(seconds)
    local Hours = tonumber(os.date("%H", os.time() + timezone * 60 * 60))
    local Minutes = tonumber(os.date("%M"))
    local Seconds = tonumber(os.date("%S"))
    local Years = tonumber(os.date("%Y"))
    local Months = tonumber(os.date("%m"))
    local Days = tonumber(os.date("%d"))

    if string.len(Hours) == 1 then Hours = "0"..Hours end
    if string.len(Minutes) == 1 then Minutes = "0"..Minutes end
    if string.len(Seconds) == 1 then Seconds = "0"..Seconds end
    if string.len(Months) == 1 then Months = "0"..Months end
    if string.len(Days) == 1 then Days = "0"..Days end

    if seconds then
        return Days.."/"..Months.."/"..Years.." "..Hours..":"..Minutes..":"..Seconds -- D/M/Y H:M:S
    else
        return Days.."/"..Months.."/"..Years.." "..Hours..":"..Minutes
    end
end


---------------- F9 MENU -----------------
-- Kan findes i vrp>modules>police.lua linje 1228 og 1251
--[[
-- REGISTER POLICE MENU CHOICES
vRP.registerMenuBuilder({"main", function(add, data)
    local user_id = vRP.getUserId({data.player})
    if user_id ~= nil then
      local choices = {}
      if vRP.hasPermission({user_id,"police.menu"}) then
        choices["> OPKALDSLISTE"] = ch_opencallist
      end
      add(choices)
    end
end})

vRP.registerMenuBuilder({"ems", function(add, data)
    local user_id = vRP.getUserId({data.player})
    if user_id ~= nil then
      local choices = {}
      if vRP.hasPermission({user_id,"emergency.menu"}) then
        choices["G - OPKALDSLISTE"] = ch_opencallist
      end
      add(choices)
    end
end})

local ch_opencallist = {function(player,choice)
    local user_id = vRP.getUserId({player})
    getCalls(function(entries)
        local jobs = vRP.getUserGroupByType({user_id,"job"})
        TriggerClientEvent("BW_CallList:openCalls", player, entries, jobs)
    end)
end, "Åbner Opkaldslisten"}



]]
SetTimeout(2000, function()
    MySQL.query("DELETE FROM BW_CallList WHERE taken = 'none' OR deleted = 1")


    print("[BW_CallList] Opkald ryddet ved scriptstart.")
end)

-- Function to clear call list
local function clearCallList()
    MySQL.query("DELETE FROM BW_CallList WHERE taken = 'none' OR deleted = 1")
    print("[BW_CallList] Call list cleared.")
end

-- Function to start hourly clearing loop
local function startHourlyClear()
    SetTimeout(3600000, function()
        clearCallList()
        startHourlyClear() -- Schedule next run
    end)
end

-- Clear at script start
AddEventHandler("onMySQLReady", function()
    clearCallList()
    startHourlyClear()
end)


---------------- DEBUG ------------------
-- Register the existing command
RegisterCommand("114", function(source, args, rawCommand)
    local user_id = vRP.getUserId({source})
    if vRP.hasGroup({user_id, Config.Job}) then
        getCalls(function(entries)
            local jobs = vRP.getUserGroupByType({user_id,"job"})
            TriggerClientEvent("BW_CallList:openCalls", source, entries, jobs)
        end)
    end
end, false)

RegisterCommand("addentry", function(source, args, rawCommand)
    local user_id = vRP.getUserId({source})
    if not user_id then return end

    local count = tonumber(args[1]) or 1 -- hvis ikke angivet, default 1

    vRP.getUserIdentity({user_id, function(identity)
        vRP.prompt({source, "PolitiJob eller EMS-Job", "", function(source, service)
            vRP.prompt({source, "Indtast besked", "", function(source, message)
                for i = 1, count do
                    TriggerEvent("BW_CallList:addTable", tostring(source), message, service)
                end
                vRPclient.notify(source, {"~g~Tilføjede "..count.." entries til "..service.." listen."})
            end})
        end})
    end})
end, false)


-- RegisterCommand("testcall", function(source,args,rawCommand)
--     local user_id = vRP.getUserId({source})
--     local message = "TEST!"
--     local service = "PolitiJob"
--         TriggerEvent("BW_CallList:addTable",tostring(source),message,service)
-- end, false)