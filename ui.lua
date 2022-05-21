-- recommend each chest only touching at most 1 modem
-- recommend flat wired modem for computer

local util = require "util"
local silo = require "silo"

local term = term or util.mock("term", "clear", "write", "getCursorPos", "setCursorPos", "getSize", "setCursorBlink", "clearLine")
-- local peripheral = peripheral or util.mock("peripheral")
local keys = keys or util.mock("keys", "getName")
local shell = shell or util.mock("shell", "run")

--os.pullEvent = function() return "key", 10, true end
--keys.getName = function() return "" end
--term.getCursorPos = function() return 10,10 end
--term.getSize = function() return 51, 16 end

local tArgs = {...}
local width, height = term.getSize()

if #tArgs > 0 then
  shell.run("clear")
  print("type to find items")
  print("press 1-9 to get that item")
  print("press tab to clear pickup/dropoff chests")
  error()
end

function startup()
  term.clear()
  term.setCursorPos(1,1)
  term.write("Search: ")
  term.setCursorBlink(true)
  
  silo.startup()
  silo.update_all_items()
  silo.load_recipes()
end

function backspace(num)
  num = num or 1
  local x,y = term.getCursorPos()
  if x-num <= 8 then
    return
  end
  term.setCursorPos(x-num,y)
  for _ = 1,num do
    term.write(" ")
  end
  term.setCursorPos(x-num,y)
end

function printWord(word)
  local x,y = term.getCursorPos()
  term.setCursorPos(1,y+1)
  term.clearLine()
  term.write("word: "..word)
  term.setCursorPos(x,y)
end

function notify(msg)
  local x,y = term.getCursorPos()
  for i=1,0,-1 do
    term.setCursorPos(1,height-i)
    term.clearLine()
  end
  term.write(msg)
  term.setCursorPos(x,y)
end

function getUserInput(prompt)
  local x,y = term.getCursorPos()
  for i = 2,0,-1 do
    term.setCursorPos(1,height-i)
    term.clearLine()
  end
  
  term.setCursorPos(1,height-1)    
  term.write(prompt)
  sleep(0.05)
  local input = io.read()
  term.setCursorPos(x,y)
  return input
end

function clearUnderSearch()
  local x,y = term.getCursorPos()
  for i=2,height do
    term.setCursorPos(1,i)
    term.clearLine()
  end
  term.setCursorPos(x,y)
end

function listItems(word)
  clearUnderSearch()
  local x,y = term.getCursorPos()
  local line = 1
  local itemChoices = {}
  for item, count in pairs(silo.dict) do
    if item:find(word) and (count ~= 0 or silo.show_crafts) then
      if line >= height-2 then
        term.setCursorPos(x,y)
        return itemChoices
      end
      term.setCursorPos(1,y+line)
      term.write(("%i) %ix %s"):format(line, count, item))
      itemChoices[line] = item
      line = line + 1
    end
  end
  term.setCursorPos(x,y)
  return itemChoices
end

startup()

local word = ""
local itemChoices = listItems(word)
while true do
  local eventData = {os.pullEvent()}
  if eventData[1] == "timer" then
    if silo.try_crafting_from_stack() then
      os.startTimer(5)
      silo.dump(silo.dump_chest)
      silo.dump(silo.pickup_chest)
      silo.update_all_items()
    end

  elseif eventData[1] == "key" then
    local keyCode, isHeld = eventData[2], eventData[3]
    local key = keys.getName(keyCode)
      
    if #key == 1 then
      word = word .. key
      term.write(key)
      itemChoices = listItems(word) 
    elseif key == "space" then
      word = word .. " "
      term.write(" ")
      itemChoices = listItems(word)
    elseif key == "backspace" then
      word = word:sub(1,#word-1)
      backspace()
      itemChoices = listItems(word)
    elseif key == "semicolon" then
      word = word .. ":"
      term.write(":")
      itemChoices = listItems(word)
    elseif key == "minus" then
      word = word .. "_"
      term.write("_")
      itemChoices = listItems(word)
    elseif key == "grave" then
      backspace(#word)
      word = ""
      itemChoices = listItems(word)
    elseif key == "capsLock" then
      if silo.show_crafts then
        silo.show_crafts = false
      else
        silo.show_crafts = true
      end
      if not word then
        word = ""
      end
      itemChoices = listItems(word)
    elseif key == "tab" then
      notify("dumping...")
      local a = silo.dump(silo.dump_chest)
      local b = silo.dump(silo.pickup_chest)
      if a and b then
        silo.update_all_items()
        
        itemChoices = listItems(word)
        notify("dump successful")
      else
        notify("dump failed")
      end    
    elseif 49 <= keyCode and keyCode <= 57 then
      local sel = keyCode - 48
      if sel <= #itemChoices then
        local item = itemChoices[sel]
        local count = silo.dict[item]
        if count and count > 64 then
          count = 64
        end
        if count == 0 then
          local potential, msg = silo.how_many(item)
          if potential == 0 then
            notify(msg)
          else   
            local prompt = ("how many? (max %i) "):format(potential)
            local num = getUserInput(prompt)
            num = tonumber(num)
            if num > potential then
              notify(("can only make up to %i"):format(potential))
            else
              notify(("crafting %i %s"):format(num, item))
              silo.push_to_crafting_stack(item, num)
              if silo.try_crafting_from_stack() then
                os.startTimer(5)
              end
            end
          end
        else
          silo.get_item(item, count)
          itemChoices = listItems(word)
          notify(("grabbed %ix %s"):format(count,item))
        end 
      else
        notify(("%i is not an option"):format(sel))
      end
    end
  end
end