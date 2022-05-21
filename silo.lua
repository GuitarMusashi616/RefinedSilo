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
  stack = {},
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


function silo.push_to_crafting_stack(item_name, amount)
  local item_counts = silo.get_item_counts(item_name, amount)
  table.insert(silo.stack, {item_name, amount})
  for item, count in pairs(item_counts) do
    if silo.recipes[item] then
      local stock = silo.dict[item] or 0
      local needed = count - stock
      

      if needed > 0 then
        table.insert(silo.stack, {item, needed})
      end
    end
  end
end

function silo.contains(item_counts)
  for ing, req in pairs(item_counts) do
    if silo.dict[ing] < req then
      return false
    end
  end
  return true
end

function silo.try_crafting_from_stack()
  while #silo.stack > 0 do
    local item, count = table.unpack(table.remove(silo.stack))
    local item_counts = silo.get_item_counts(item, count)
  -- if have enough materials then craft it, otherwise set timer and return
    if silo.contains(item_counts) then
      silo.craft(item, math.ceil(count))
    else
      os.startTimer(1)
      break
    end
  end
end

-- crafting item_name x times requires how much material?
function silo.get_item_counts(item_name, amount)
  local item_counts = {}
  local yieldItemCount = silo.recipes[item_name]
  assert(yieldItemCount, tostring(item_name) .. " recipe not found")
  local yield = yieldItemCount[1]

  for i=2,#yieldItemCount-1,2 do
    local item = yieldItemCount[i]
    local count = yieldItemCount[i+1]

    if not item_counts[item] then
      item_counts[item] = 0
    end
    item_counts[item] = item_counts[item] + (count * amount)/yield
  end

  return item_counts
end

function silo.check_for_craftable(item_counts)
  for item, count in pairs(item_counts) do
    if silo.recipes[item] then
      local stock = silo.dict[item] or 0
      local needed = count - stock
      if needed > 0 then
        return item, needed
      end
    end
  end
end

function silo.raw_item_counts(item_name)
  -- breaks down craftable components into base items

  local item_counts = silo.get_item_counts(item_name, 1)
  local yield = silo.recipes[item_name][1]
  local craftable_item, needed = silo.check_for_craftable(item_counts)
  while craftable_item do
    local new_item_counts = silo.get_item_counts(craftable_item, needed)
    item_counts[craftable_item] = item_counts[craftable_item] - needed
    if item_counts[craftable_item] <= 0 then
      item_counts[craftable_item] = nil
    end
    for item, count in pairs(new_item_counts) do
      if not item_counts[item] then
        item_counts[item] = 0
      end
      item_counts[item] = item_counts[item] + count/yield
    end
    craftable_item, needed = silo.check_for_craftable(item_counts)
  end
  
  return item_counts
end

function silo.how_many(item_name)
  local raw_item_counts = silo.raw_item_counts(item_name)
  local craftable = {}

  for item, count in pairs(raw_item_counts) do
    if not silo.dict[item] then
      return 0, ("Need %i %s"):format(count, item)
    end

    local can_make = math.floor(silo.dict[item] / count)
    table.insert(craftable, can_make)
  end

  local can_craft_x_times = math.min(table.unpack(craftable))

  return can_craft_x_times, "need more stuff"
end


function silo.how_many_deprecated(item_name)
  local yieldItemCount = silo.recipes[item_name]
  local craftable = {} 

  -- while there is a craftable recipe, break it down into non craftables
  
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
  local craft_x_times = math.ceil(num / yieldItemCount[1])

  local perf_index = yieldItemCount[#yieldItemCount]
  local perf_name = silo.get_peripheral_name(perf_index)

  for i = 2,#yieldItemCount-1,2 do
    local item = yieldItemCount[i]
    local count = yieldItemCount[i+1] * craft_x_times

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

local function test_how_many()
  silo.recipes["wire_copper"] = {5, "copper_plate", 4}
  silo.recipes["copper_plate"] = {3, "copper_ingot", 2}
  silo.dict["copper_ingot"] = 36
  local inv = silo.how_many("wire_copper")
  print(inv)
end

local function test_make_wire()
  silo.stack = {}
  -- each recipe found gets put on the stack
  -- the recipes on the stack start getting crafted
  -- when the recipe cannot be crafted a timer is set to try again in the future
  silo.recipes["wire_copper"] = {5, "copper_plate", 4}
  silo.recipes["copper_plate"] = {3, "copper_ingot", 2}
  silo.dict["copper_ingot"] = 20

  silo.push_to_crafting_stack("wire_copper", 14)
  print(silo.stack)
  -- stack["wire_copper", "copper_plate"]

  silo.try_crafting_from_stack()
  -- check copper plate, send items to machines
  -- check wire_copper, see theres not enough copper plate, set timer
  -- elsewhere try crafting from stack is called when timer event fires, so stack is attempted once more
end

return silo