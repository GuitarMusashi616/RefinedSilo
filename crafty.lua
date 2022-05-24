local MODEM_SIDE = "right"

local crafter = {
  loc_to_slot = {1,2,3,5,6,7,9,10,11},
  queue = {}
}

function crafter.run()
  rednet.open(MODEM_SIDE)
  parallel.waitForAll(crafter.producer, crafter.consumer)  
end

function crafter.producer()
  while true do
    local msg = {rednet.receive()}
    table.insert(crafter.queue, msg)
    sleep(0.05)
  end  
end

function crafter.consumer()
  while true do
    if #crafter.queue > 0 then
      if crafter.handle(crafter.queue[1]) then
        table.remove(crafter.queue,1)
      end
    end
    sleep(0.05)
  end
end

function crafter.get_min_stack_size(data)
  if data[1] == 1 then
    return 64
  end
  local inv = peripheral.call("top","list")
  local min = 64
  for i,item in pairs(inv) do
    for j=2,#data-1,2 do
      if data[j] == item.name then
        local maxCount = peripheral.call("top","getItemDetail",i).maxCount
        min = math.min(min, maxCount)
      end
    end 
  end
  return min
end

function crafter.handle(msg)
  if not msg or type(msg) ~= "table" then
    return
  end
  
  local data = textutils.unserialize(msg[2])
  if not data or type(data) ~= "table" then
    return
  end
  
  local craft_x_times = data[1]
  local min_stack_size = crafter.get_min_stack_size(data)
  local rem = craft_x_times
  
  for _ = 1,craft_x_times,min_stack_size do
    local vol = math.min(rem, min_stack_size)
    crafter.craft(data, vol)
    rem = rem - vol
  end
  return true  
end

function crafter.move_from_top_to_bottom(item, amount)
  assert(amount <= 64)
  local rem = amount
  local inv = peripheral.call("top", "list")
  for i, invSlot in pairs(inv) do
    if invSlot.name == item then
      local vol = math.min(rem, invSlot.count)
      peripheral.call("top", "pushItems", "bottom", i, rem)
      rem = rem - vol
    end
    if rem <= 0 then
      return true
    end
  end
  return false
end

function crafter.grab(item, amount, location)
  assert(amount <= 64)
  local slot = crafter.loc_to_slot[location]
  turtle.select(slot)
  if crafter.move_from_top_to_bottom(item, amount) then
    turtle.suckDown()
  else
    error(("%i %s not found"):format(amount, item), 0)
  end
end

function crafter.craft(data, craft_x_times)
  for i=2,#data-1,2 do
    local item = data[i]
    local locations = data[i+1]
    for _, location in pairs(locations) do
      crafter.grab(item, craft_x_times, location)
    end  
  end
  
  turtle.craft()
  crafter.clearInv()
  return true
end

function crafter.clearInv()
  for slot=1,16 do
    turtle.select(slot)
    turtle.drop()
  end
end

function test()
  local data = {
  1, 
  "minecraft:gold_nugget",
  {1,9},
  "minecraft:redstone",
  {2,4,6,8},
  "emendatusenigmatica:gold_rod",
  {5},  
  }
  
  crafter.craft(data)
end

crafter.run()