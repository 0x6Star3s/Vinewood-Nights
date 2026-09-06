RegisterServerEvent("jg-vehicleindicators:server:set-state", function(netId, value)
  if type(netId) ~= "number" or type(value) ~= "table" then return end
  if type(value[1]) ~= "boolean" or type(value[2]) ~= "boolean" or #value ~= 2 then return end

  local vehicle = NetworkGetEntityFromNetworkId(netId)
  if vehicle == 0 or not DoesEntityExist(vehicle) then return end
  -- tylko kierowca miga wlasnymi kierunkowskazami
  if GetPedInVehicleSeat(vehicle, -1) ~= GetPlayerPed(source) then return end

  Entity(vehicle).state.indicate = value
end)
