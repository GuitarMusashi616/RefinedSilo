local helper = {}

-- helper functions --
function helper.all(tbl) 
  local prev_k = nil
  return function()
    local k,v = next(tbl, prev_k)
    prev_k = k
    return v
  end
end

function helper.inc_tbl(tbl, key, val)
  assert(key, "key cannot be false or nil")
  val = val or 1
  if not tbl[key] then
    tbl[key] = 0
  end
  tbl[key] = tbl[key] + val
end

function helper.beginsWith(string, beginning)
  return string:sub(1,#beginning) == beginning
end

function helper.forEach(tbl, func)
  for val in all(tbl) do
    func(val)
  end
end

function helper.t2f(tbl, filename)
  filename = filename or "output"
  local h = io.open(filename, "w")
  h:write(textutils.serialize(tbl))
  h:close()
  shell.run("edit "..tostring(filename))
end

return helper