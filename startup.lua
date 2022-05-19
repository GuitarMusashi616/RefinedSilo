function mock(lib_name, ...)
  local lib = {}
  local fnames = {...}
  for _, fname in pairs(fnames) do
    lib[fname] = function(...) 
      local args = {...}
      for k,v in pairs(args) do
        args[k] = "\"" .. v .. "\""
      end
      print(("%s.%s(%s)"):format(lib_name, fname, table.concat(args, ", ")))
    end
  end
  return lib
end


local shell = shell or mock("shell", "run")
local fs = fs or mock("fs", "exists")

function wgit(repo, file)
  local url = ("https://raw.githubusercontent.com/GuitarMusashi616/%s/master/%s"):format(repo, file)
  shell.run(url)
end

local files = {"helper.lua", "silo.lua", "ui.lua"}
local repo = "RefinedSilo"

for i=1,#files do
  local file = files[i]
  if fs.exists(file) then
    shell.run("rm "..file)
  end
  wgit(repo, file)
end