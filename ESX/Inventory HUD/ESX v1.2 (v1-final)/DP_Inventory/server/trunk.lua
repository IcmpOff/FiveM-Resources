ESX = nil
Items = {}
local DataStoresIndex = {}
local DataStores = {}
local SharedDataStores = {}
local arrayWeight = Config.localWeight
local VehicleList = {}
local VehicleInventory = {}

local listPlate = Config.VehiclePlate

TriggerEvent("esx:getSharedObject", function(obj) ESX = obj end)

--AddEventHandler("onMySQLReady", function()
MySQL.ready(function()
	local result = MySQL.Sync.fetchAll("SELECT * FROM inventory_trunk")
	local data = nil
	if #result ~= 0 then
		for i = 1, #result, 1 do
			local plate = result[i].plate
			local owned = result[i].owned
			local data = (result[i].data == nil and {} or json.decode(result[i].data))
			local dataStore = CreateDataStoreTrunk(plate, owned, data)
			SharedDataStores[plate] = dataStore
		end
	end
	MySQL.Async.execute("DELETE FROM `inventory_trunk` WHERE `owned` = 0", {})
end)

function loadInventTrunk(plate)
	local result = MySQL.Sync.fetchAll("SELECT * FROM inventory_trunk WHERE plate = @plate", {
		["@plate"] = plate
	})
	local data = nil
	if #result ~= 0 then
		for i = 1, #result, 1 do
			local plate = result[i].plate
			local owned = result[i].owned
			local data = (result[i].data == nil and {} or json.decode(result[i].data))
			local dataStore = CreateDataStoreTrunk(plate, owned, data)
			SharedDataStores[plate] = dataStore
		end
	end
end

function getOwnedVehicle(plate)
	local found = false
	if listPlate then
		for k, v in pairs(listPlate) do
			if string.find(plate, v) ~= nil then
				found = true
				break
			end
		end
	end
	if not found then
		local result = MySQL.Sync.fetchAll("SELECT * FROM owned_vehicles")
		while result == nil do
			Wait(5)
		end
		if result ~= nil and #result > 0 then
			for _, v in pairs(result) do
				local vehicle = json.decode(v.vehicle)
				if vehicle.plate == plate then
				found = true
				break
				end
			end
		end
	end
	return found
end

function MakeDataStoreTrunk(plate)
	local data = {}
	local owned = getOwnedVehicle(plate)
	local dataStore = CreateDataStoreTrunk(plate, owned, data)
	SharedDataStores[plate] = dataStore
	MySQL.Async.execute("INSERT INTO inventory_trunk(plate,data,owned) VALUES (@plate,'{}',@owned)", {
		["@plate"] = plate,
		["@owned"] = owned
	})
	loadInventTrunk(plate)
end

function GetSharedDataStoreTrunk(plate)
	if SharedDataStores[plate] == nil then
		MakeDataStoreTrunk(plate)
	end
	return SharedDataStores[plate]
end

AddEventHandler("DP_Inventory_trunk:GetSharedDataStoreTrunk", function(plate, cb)
	cb(GetSharedDataStoreTrunk(plate))
end)

--[[RegisterServerEvent("DP_Inventory_trunk:getOwnedVehicle")
AddEventHandler("DP_Inventory_trunk:getOwnedVehicle", function()
	local vehicules = {}
	local _source = source
	local xPlayer = ESX.GetPlayerFromId(_source)
	MySQL.Async.fetchAll("SELECT * FROM owned_vehicles WHERE owner = @owner", {
		["@owner"] = xPlayer.identifier
	},
	function(result)
		if result ~= nil and #result > 0 then
			for _, v in pairs(result) do
				local vehicle = json.decode(v.vehicle)
				table.insert(vehicules, {plate = vehicle.plate})
			end
		end
		TriggerClientEvent("DP_Inventory_trunk:setOwnedVehicule", _source, vehicules)
	end)
end)]]

RegisterServerEvent("DP_Inventory_trunk:getOwnedVehicle")
AddEventHandler("DP_Inventory_trunk:getOwnedVehicle", function()
	local vehicules = {}
	local _source = source
	local result = MySQL.Sync.fetchAll("SELECT * FROM owned_vehicles")
	
	if #result ~= 0 then
		for i = 1, #result, 1 do
			local plate1 = result[i].plate
			table.insert(vehicules, {plate = plate1})
		end
	end
	TriggerClientEvent("DP_Inventory_trunk:setOwnedVehicule", _source, vehicules)
end)

function getItemWeight(item)
	local weight = 0
	local itemWeight = 0
	if item ~= nil then
		itemWeight = Config.DefaultWeight
		if arrayWeight[item] ~= nil then
		itemWeight = arrayWeight[item]
		end
	end
	return itemWeight
end

function getInventoryWeightTrunk(inventory)
	local weight = 0
	local itemWeight = 0
	if inventory ~= nil then
		for i = 1, #inventory, 1 do
			if inventory[i] ~= nil then
				itemWeight = Config.DefaultWeight
				if arrayWeight[inventory[i].name] ~= nil then
				itemWeight = arrayWeight[inventory[i].name]
				end
				weight = weight + (itemWeight * (inventory[i].count or 1))
			end
		end
	end
	return weight
end

function getTotalInventoryWeightTrunk(plate)
	local total
	TriggerEvent("DP_Inventory_trunk:GetSharedDataStoreTrunk", plate, function(store)
		local W_weapons = getInventoryWeightTrunk(store.get("weapons") or {})
		local W_coffre = getInventoryWeightTrunk(store.get("coffre") or {})
		local W_blackMoney = 0
		local blackAccount = (store.get("black_money")) or 0
		if blackAccount ~= 0 then
			W_blackMoney = blackAccount[1].amount / 10
		end

		local W_cashMoney = 0
		local cashAccount = (store.get("money")) or 0
		if cashAccount ~= 0 then
			W_cashMoney = cashAccount[1].amount / 10
		end
		total = W_weapons + W_coffre + W_blackMoney + W_cashMoney
		end)
	return total
end

ESX.RegisterServerCallback("DP_Inventory_trunk:getInventoryV", function(source, cb, plate)
	TriggerEvent("DP_Inventory_trunk:GetSharedDataStoreTrunk", plate, function(store)
		local blackMoney = 0
		local cashMoney = 0
		local items = {}
		local weapons = {}
		weapons = (store.get("weapons") or {})

		local blackAccount = (store.get("black_money")) or 0
		if blackAccount ~= 0 then
			blackMoney = blackAccount[1].amount
		end

		local cashAccount = (store.get("money")) or 0
		if cashAccount ~= 0 then
			cashMoney = cashAccount[1].amount
		end

		local coffre = (store.get("coffre") or {})
		for i = 1, #coffre, 1 do
			table.insert(items, {name = coffre[i].name, count = coffre[i].count, label = ESX.GetItemLabel(coffre[i].name)})
		end

		local weight = getTotalInventoryWeightTrunk(plate)
		cb({
			blackMoney = blackMoney,
			cashMoney = cashMoney,
			items = items,
			weapons = weapons,
			weight = weight
		})
	end)
end)

RegisterServerEvent("DP_Inventory_trunk:getItem")
AddEventHandler("DP_Inventory_trunk:getItem", function(plate, type, item, count, max, owned)
	local _source = source
	local xPlayer = ESX.GetPlayerFromId(_source)

	if type == "item_standard" then
		local targetItem = xPlayer.getInventoryItem(item)
		if xPlayer.canCarryItem(item, count) then
			TriggerEvent("DP_Inventory_trunk:GetSharedDataStoreTrunk", plate, function(store)
				local coffre = (store.get("coffre") or {})
				for i = 1, #coffre, 1 do
					if coffre[i].name == item then
						if (coffre[i].count >= count and count > 0) then
							if item == 'WEAPON_PISTOL' or item == 'WEAPON_FLASHLIGHT' or item == 'WEAPON_STUNGUN' or item == 'WEAPON_KNIFE' 
    						or item == 'WEAPON_BAT' or item == 'WEAPON_ADVANCEDRIFLE' or item == 'WEAPON_APPISTOL' or item == 'WEAPON_ASSAULTRIFLE'
    						or item == 'WEAPON_ASSAULTSHOTGUN' or item == 'WEAPON_ASSAULTSMG' or item == 'WEAPON_AUTOSHOTGUN' or item == 'WEAPON_CARBINERIFLE'
    						or item == 'WEAPON_COMBATPISTOL' or item == 'WEAPON_PUMPSHOTGUN' or item == 'WEAPON_SMG' then
								TriggerEvent('DP_Inventory:changeWeaponOwner',plate, xPlayer.identifier, item)
							end
							xPlayer.addInventoryItem(item, count)
							if (coffre[i].count - count) == 0 then
								table.remove(coffre, i)
							else
								coffre[i].count = coffre[i].count - count
							end
							break
						else
							TriggerClientEvent('tnotify:client:SendTextAlert', _source, {
								style  =  'success',
								duration  =  5500,
								message = _U("invalid_quantity"),
								sound  =  true
							})
						end
					end
				end

				store.set("coffre", coffre)

				local blackMoney = 0
				local cashMoney = 0
				local items = {}
				local weapons = {}
				weapons = (store.get("weapons") or {})

				local blackAccount = (store.get("black_money")) or 0
				if blackAccount ~= 0 then
					blackMoney = blackAccount[1].amount
				end

				local cashAccount = (store.get("money")) or 0
				if cashAccount ~= 0 then
					cashMoney = cashAccount[1].amount
				end

				local coffre = (store.get("coffre") or {})
				for i = 1, #coffre, 1 do
					table.insert(items, {name = coffre[i].name, count = coffre[i].count, label = ESX.GetItemLabel(coffre[i].name)})
				end

				local weight = getTotalInventoryWeightTrunk(plate)

				text = _U("trunk_info", plate, (weight / 100), (max / 100))
				data = {plate = plate, max = max, myVeh = owned, text = text}
				TriggerClientEvent("DP_Inventory:refreshTrunkInventory", _source, data, blackMoney, cashMoney, items, weapons)
			end)
		else
			TriggerClientEvent('tnotify:client:SendTextAlert', _source, {
				style  =  'success',
				duration  =  5500,
				message = _U("player_inv_no_space"),
				sound  =  true
			})
		end
	end

	if type == "item_account" then
		TriggerEvent("DP_Inventory_trunk:GetSharedDataStoreTrunk", plate, function(store)
			local blackMoney = store.get("black_money")
			if (blackMoney[1].amount >= count and count > 0) then
				blackMoney[1].amount = blackMoney[1].amount - count
				store.set("black_money", blackMoney)
				xPlayer.addAccountMoney(item, count)

				local blackMoney = 0
				local cashMoney = 0
				local items = {}
				local weapons = {}
				weapons = (store.get("weapons") or {})

				local blackAccount = (store.get("black_money")) or 0
				if blackAccount ~= 0 then
					blackMoney = blackAccount[1].amount
				end

				local cashAccount = (store.get("money")) or 0
				if cashAccount ~= 0 then
					cashMoney = cashAccount[1].amount
				end

				local coffre = (store.get("coffre") or {})
				for i = 1, #coffre, 1 do
					table.insert(items, {name = coffre[i].name, count = coffre[i].count, label = ESX.GetItemLabel(coffre[i].name)})
				end

				local weight = getTotalInventoryWeightTrunk(plate)

				text = _U("trunk_info", plate, (weight / 100), (max / 100))
				data = {plate = plate, max = max, myVeh = owned, text = text}
				TriggerClientEvent("DP_Inventory:refreshTrunkInventory", _source, data, blackMoney, cashMoney, items, weapons)
			else
				TriggerClientEvent('tnotify:client:SendTextAlert', _source, {
					style  =  'success',
					duration  =  5500,
					message = _U("invalid_amount"),
					sound  =  true
				})
			end
		end)
	end

	if type == "item_money" then
		TriggerEvent("DP_Inventory_trunk:GetSharedDataStoreTrunk", plate, function(store)
			local cashMoney = store.get("money")
			if (cashMoney[1].amount >= count and count > 0) then
				cashMoney[1].amount = cashMoney[1].amount - count
				store.set("money", cashMoney)
				xPlayer.addMoney(count)

				local blackMoney = 0
				local cashMoney = 0
				local items = {}
				local weapons = {}
				weapons = (store.get("weapons") or {})

				local blackAccount = (store.get("black_money")) or 0
				if blackAccount ~= 0 then
					blackMoney = blackAccount[1].amount
				end

				local cashAccount = (store.get("money")) or 0
				if cashAccount ~= 0 then
					cashMoney = cashAccount[1].amount
				end

				local coffres = (store.get("coffres") or {})
				for i = 1, #coffres, 1 do
					table.insert(items, {name = coffres[i].name, count = coffres[i].count, label = ESX.GetItemLabel(coffres[i].name)})
				end

				local weight = getTotalInventoryWeightTrunk(plate)

				text = _U("trunk_info", plate, (weight / 100), (max / 100))
				data = {plate = plate, max = max, myVeh = owned, text = text}
				TriggerClientEvent("DP_Inventory:refreshTrunkInventory", _source, data, blackMoney, cashMoney, items, weapons)
			else
				TriggerClientEvent("pNotify:SendNotification", _source, {
					text = _U("invalid_amount"),
					type = "error",
					queue = "trunk",
					timeout = 3000,
					layout = "bottomCenter"
				})
			end
		end)
	end
end)

RegisterServerEvent("DP_Inventory_trunk:putItem")
AddEventHandler("DP_Inventory_trunk:putItem", function(plate, type, item, count, max, owned, label)
	local _source = source
	local xPlayer = ESX.GetPlayerFromId(_source)
	local xPlayerOwner = ESX.GetPlayerFromIdentifier(owner)

	if type == "item_standard" then
		local playerItemCount = xPlayer.getInventoryItem(item).count

		if (playerItemCount >= count and count > 0) then
			TriggerEvent("DP_Inventory_trunk:GetSharedDataStoreTrunk", plate, function(store)
				local found = false
				local coffre = (store.get("coffre") or {})

				for i = 1, #coffre, 1 do
					if coffre[i].name == item then
						coffre[i].count = coffre[i].count + count
						found = true
					end
				end
				if not found then
					table.insert(coffre, {
						name = item,
						count = count
					})
				end
				if (getTotalInventoryWeightTrunk(plate) + (getItemWeight(item) * count)) > max then
					TriggerClientEvent('tnotify:client:SendTextAlert', _source, {
						style  =  'success',
						duration  =  5500,
						message = _U("insufficient_space"),
						sound  =  true
					})
				else
					store.set("coffre", coffre)
					if item == 'WEAPON_PISTOL' or item == 'WEAPON_FLASHLIGHT' or item == 'WEAPON_STUNGUN' or item == 'WEAPON_KNIFE' 
					or item == 'WEAPON_BAT' or item == 'WEAPON_ADVANCEDRIFLE' or item == 'WEAPON_APPISTOL' or item == 'WEAPON_ASSAULTRIFLE'
					or item == 'WEAPON_ASSAULTSHOTGUN' or item == 'WEAPON_ASSAULTSMG' or item == 'WEAPON_AUTOSHOTGUN' or item == 'WEAPON_CARBINERIFLE'
					or item == 'WEAPON_COMBATPISTOL' or item == 'WEAPON_PUMPSHOTGUN' or item == 'WEAPON_SMG' then
						TriggerEvent('DP_Inventory:changeWeaponOwner',xPlayer.identifier, plate, item)
					end
					xPlayer.removeInventoryItem(item, count)
					MySQL.Async.execute("UPDATE inventory_trunk SET owned = @owned WHERE plate = @plate", {
						["@plate"] = plate,
						["@owned"] = owned
					})
				end
			end)
		else
			TriggerClientEvent('tnotify:client:SendTextAlert', _source, {
				style  =  'success',
				duration  =  5500,
				message = _U("invalid_quantity"),
				sound  =  true
			})
		end
	end

	if type == "item_account" then
		local playerAccountMoney = xPlayer.getAccount(item).money
		if (playerAccountMoney >= count and count > 0) then
			TriggerEvent("DP_Inventory_trunk:GetSharedDataStoreTrunk", plate, function(store)
				local blackMoney = (store.get("black_money") or nil)
				if blackMoney ~= nil then
					blackMoney[1].amount = blackMoney[1].amount + count
				else
					blackMoney = {}
					table.insert(blackMoney, {amount = count})
				end
				if (getTotalInventoryWeightTrunk(plate) + (count / 10)) > max then
					TriggerClientEvent('tnotify:client:SendTextAlert', _source, {
						style  =  'success',
						duration  =  5500,
						message = _U("insufficient_space"),
						sound  =  true
					})
				else
					xPlayer.removeAccountMoney(item, count)
					store.set("black_money", blackMoney)
					MySQL.Async.execute("UPDATE inventory_trunk SET owned = @owned WHERE plate = @plate", {
						["@plate"] = plate,
						["@owned"] = owned
					})
				end
			end)
		else
			TriggerClientEvent('tnotify:client:SendTextAlert', _source, {
				style  =  'success',
				duration  =  5500,
				message = _U("invalid_amount"),
				sound  =  true
			})
		end
	end

	if type == "item_money" then
		local playerAccountMoney = xPlayer.getMoney()

		if (playerAccountMoney >= count and count > 0) then
			TriggerEvent("DP_Inventory_trunk:GetSharedDataStoreTrunk", plate, function(store)
				local cashMoney = (store.get("money") or nil)
				if cashMoney ~= nil then
					cashMoney[1].amount = cashMoney[1].amount + count
				else
					cashMoney = {}
					table.insert(cashMoney, {amount = count})
				end

				if (getTotalInventoryWeightTrunk(plate) + (count / 10)) > max then

					TriggerClientEvent('tnotify:client:SendTextAlert', _source, {
						style  =  'success',
						duration  =  5500,
						message = _U("insufficient_space"),
						sound  =  true
					})
				else
					xPlayer.removeMoney(count)
					store.set("money", cashMoney)
					MySQL.Async.execute("UPDATE inventory_trunk SET owned = @owned WHERE plate = @plate", {
						["@plate"] = plate,
						["@owned"] = owned
					})
				end
			end)
		else
			TriggerClientEvent('tnotify:client:SendTextAlert', _source, {
				style  =  'success',
				duration  =  5500,
				message = _U("invalid_amount"),
				sound  =  true
			})
		end
	end

	TriggerEvent("DP_Inventory_trunk:GetSharedDataStoreTrunk", plate, function(store)
		local blackMoney = 0
		local cashMoney = 0
		local items = {}
		local weapons = {}
		weapons = (store.get("weapons") or {})

		local blackAccount = (store.get("black_money")) or 0
		if blackAccount ~= 0 then
			blackMoney = blackAccount[1].amount
		end

		local cashAccount = (store.get("money")) or 0
		if cashAccount ~= 0 then
			cashMoney = cashAccount[1].amount
		end

		local coffre = (store.get("coffre") or {})
		for i = 1, #coffre, 1 do
			table.insert(items, {name = coffre[i].name, count = coffre[i].count, label = ESX.GetItemLabel(coffre[i].name)})
		end

		local weight = getTotalInventoryWeightTrunk(plate)

		text = _U("trunk_info", plate, (weight / 100), (max / 100))
		data = {plate = plate, max = max, myVeh = owned, text = text}
		TriggerClientEvent("DP_Inventory:refreshTrunkInventory", _source, data, blackMoney, cashMoney, items, weapons)
	end)
end)

ESX.RegisterServerCallback("DP_Inventory_trunk:getPlayerInventory", function(source, cb)
	local xPlayer = ESX.GetPlayerFromId(source)
	local blackMoney = xPlayer.getAccount("black_money").money
	local cashMoney = xPlayer.getMoney()
	local items = xPlayer.inventory
	cb({
		blackMoney = blackMoney,
		cashMoney = cashMoney,
		items = items
	})
end)

function all_trim(s)
	if s then
		return s:match "^%s*(.*)":match "(.-)%s*$"
	else
		return "noTagProvided"
	end
end

