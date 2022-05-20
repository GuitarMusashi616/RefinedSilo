local util = {}
local shell = shell or util.mock("shell", "run")
local textutils = textutils or util.mock("textutils", "serialize")

-- helper functions --
function util.all(tbl) 
  assert(type(tbl) == "table", tostring(tbl) .. " bad arg (table expected)")
  local prev_k = nil
  return function()
    local k,v = next(tbl, prev_k)
    prev_k = k
    return v
  end
end

function util.inc_tbl(tbl, key, val)
  assert(key, "key cannot be false or nil")
  val = val or 1
  if not tbl[key] then
    tbl[key] = 0
  end
  tbl[key] = tbl[key] + val
end

function util.beginsWith(string, beginning)
  return string:sub(1,#beginning) == beginning
end

function util.forEach(tbl, func)
  for val in util.all(tbl) do
    func(val)
  end
end

function util.t2f(tbl, filename)
  filename = filename or "output"
  local h = io.open(filename, "w")
  assert(h, tostring(filename).." could not be opened")
  h:write(textutils.serialize(tbl))
  h:close()
  shell.run("edit "..tostring(filename))
end

function util.mock(lib_name, ...)
  local lib = {}
  local fnames = {...}
  for _, fname in pairs(fnames) do
    lib[fname] = function(...) 
      local args = {...}
      for k,v in pairs(args) do
        args[k] = "\"" .. tostring(v) .. "\""
      end
      print(("%s.%s(%s)"):format(lib_name, fname, table.concat(args, ", ")))
    end
  end
  return lib
end

function util.wgit(repo, file)
  local cmd = ("wget https://raw.githubusercontent.com/GuitarMusashi616/%s/master/%s"):format(repo, file)
  shell.run(cmd)
end

return util