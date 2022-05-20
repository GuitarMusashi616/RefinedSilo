-- specify name of dump chest and pickup chest (all other chests connected to modem network will be used as storage)
local DUMP_CHEST_NAME = "minecraft:chest_2"
local PICKUP_CHEST_NAME = "minecraft:chest_3"

local util = require "util"
local peripheral = peripheral or util.mock("peripheral", "getNames")
local fs = fs or util.mock("fs", "list")

--peripheral.getNames = function() return {} end
--fs.list = function(dir) return {} end

local all, beginsWith, inc_tbl, forEach, t2f = util.all, util.beginsWith, util.inc_tbl, util.forEach, util.t2f

-- silo singleton code --
local silo = {
  dict = {},
  recipes = {},
  loc = {},
  perf_cache = {},
  chest_names = {},
  show_crafts = true,
  dump_chest = DUMP_CHEST_NAME,
  pickup_chest = PICKUP_CHEST_NAME,
}

-- scan through all connected chests and add to table
function silo.find_chests()
  silo.chest_names = {}
  for name in all(peripheral.getNames()) do
    if (beginsWith(name, "chest") or beginsWith(name, "ironchest")) and name ~= silo.dump_chest and name ~= silo.pickup_chest then
      table.insert(silo.chest_names, name)
    end
  end
end

-- add the item to the record
function silo.add(item)
  inc_tbl(silo.dict, item.name, item.count)
end

function silo.add_loc(item, target, slot)
  if not silo.loc[item.name] then
    silo.loc[item.name] = {}
  end
  local index = silo.get_peripheral_index(target)
  table.insert(silo.loc[item.name], index)
  table.insert(silo.loc[item.name], slot)
  table.insert(silo.loc[item.name], item.count)
end

-- scan through all invos and put into dict
function silo.update_all_items()
  local buffer = {}
  for k,v in pairs(silo.dict) do
    if v == 0 then
      buffer[k] = v
    end
  end
  
  silo.dict = buffer
  silo.loc = {}
  for name in all(silo.chest_names) do
    silo.update(name)
  end
end

function silo.update(target)
  local items = peripheral.call(target, "list")
  for i, item in pairs(items) do
    silo.add(item)
    silo.add_loc(item, target, i)
  end
end

function silo.startup()
  silo.find_chests()
end

function silo.grab(chest_name, slot, stack_size)
  peripheral.call(silo.pickup_chest, "pullItems", chest_name, slot, stack_size)
end

function silo.get_item(item_name, count, dest)  
  local rem = count
  dest = dest or silo.pickup_chest
  
  --assert(silo.loc[item_name], item_name .. " loc not recorded")
  local sources = silo.loc[item_name]
  while sources do
    local stack_size = table.remove(sources)
    local slot = table.remove(sources)
    local perf_index = table.remove(sources)
    local perf_name = silo.get_peripheral_name(perf_index)  
    
    local amount = math.min(stack_size, 64, rem)
    peripheral.call(perf_name, "pushItems", dest, slot, amount)
    stack_size = stack_size - amount
    if stack_size > 0 then
      table.insert(sources, perf_index)
      table.insert(sources, slot)
      table.insert(sources, stack_size)   
    end
    silo.dict[item_name] = silo.dict[item_name] - amount
    if silo.dict[item_name] <= 0 and not silo.recipes[item_name] then
      silo.dict[item_name] = nil
    end
    
    rem = rem - amount
    
    if rem <= 0 then
      break
    end
  end
  
  if rem > 0 then
    error(("Need %i more %s"):format(rem, item_name), 0)
  end  
end


-- go through all items and take the specified item until count rem <= 0
function silo.get_item_no_mem(item_name, count)
  local rem = count
  item_name = item_name:lower()
  for chest_name in all(silo.chest_names) do
    local items = peripheral.call(chest_name, "list")
    for i,item in pairs(items) do
      if item.name:find(item_name) then
        local amount = math.min(64, rem)
        silo.grab(chest_name, i, amount)
        rem = rem - amount
        if rem <= 0 then
          break
        end
      end
    end
  end
end


function silo.how_many(item_name)
  local yieldItemCount = silo.recipes[item_name]
  local craftable = {} 
  
  for i = 2,#yieldItemCount-1,2 do
    local item = yieldItemCount[i]
    local count = yieldItemCount[i + 1]
    if not silo.dict[item] then
      return 0, ("Need %i %s"):format(count, item)
    end
    if silo.dict[item] == 0 then
      return 0, ("Craft %i %s first"):format(count, item)
    end
    
    local can_make = math.floor(silo.dict[item] / count)
    table.insert(craftable, can_make)
  end
  
  return math.min(table.unpack(craftable)), "need more stuff"
end

function silo.craft(item_name, num)
  local yieldItemCount = silo.recipes[item_name]
  assert(yieldItemCount, "recipe for "..tostring(item_name).. " does not exist")
  -- grab the items required
  local perf_index = yieldItemCount[#yieldItemCount]
  local perf_name = silo.get_peripheral_name(perf_index)
  for i = 2,#yieldItemCount-1,2 do
    local item = yieldItemCount[i]
    local count = yieldItemCount[i+1] * num
    
    silo.get_item(item, count, perf_name)
  end
end

-- try to suck the slot of dump chest with storage chests
function silo.try_to_dump(slot, count, target)
  target = target or silo.dump_chest
  for chest_name in all(silo.chest_names) do
    local num = peripheral.call(target, "pushItems", chest_name, slot, count)
    if num >= count then
      return true
    end
  end
end

-- for all storage chest try to suck everythin in the dump chest
function silo.dump(target)
  target = target or silo.dump_chest
  local suck_this = peripheral.call(target, "list")
  for k,v in pairs(suck_this) do
    if not silo.try_to_dump(k,v.count,target) then
      return false
    end
  end
  return true
end

function silo.search(item_name)
  item_name = item_name:lower()
  for name in all(silo.chest_names) do
    local items = peripheral.call(name, "list")
    forEach(items, function(item) if item.name:find(item_name) then silo.add(item) end end)
  end
end

function silo.get_capacity()
  local total_slots = 0
  local used_slots = 0
  local used_items = 0
  
  for name in all(silo.chest_names) do
    total_slots = total_slots + peripheral.call(name, "size")
    local items = peripheral.call(name, "list")
    used_slots = used_slots + #items
    forEach(items, function(item) used_items = used_items + item.count end)
  end
  
  print("slots used ".. tostring(used_slots) .. "/" .. tostring(total_slots))
  print("items stored "..tostring(used_items) .. "/" .. tostring(total_slots*64))
end

function silo.get_peripheral_index(perf_name)  
  for i,name in pairs(peripheral.getNames()) do
    if name:find(perf_name) then
      return i
    end
  end
end

function silo.get_peripheral_name(index)
  local perfs = peripheral.getNames()
  assert(perfs[index], ("%i is not in %s"):format(index, table.concat(perfs,",")))
  return perfs[index]
end

function silo.load_recipes()
  -- run after loading items
  for _,file in pairs(fs.list("patterns")) do
    local fileRoot = file:sub(1,#file-4)
    local nameYieldItemCount = require("patterns/"..fileRoot)
    for name,yieldItemCount in pairs(nameYieldItemCount) do
      table.insert(yieldItemCount,silo.get_peripheral_index(fileRoot))
      silo.recipes[name] = yieldItemCount
      if not silo.dict[name] then
        silo.dict[name] = 0
      end
    end
  end
end

return silo