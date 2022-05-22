
local shell = shell or {run=function(cmd) end}
local fs = fs or {exists=function(file) end}


local function wgit(repo, file, branch)
  branch = branch or "master"
  local cmd = ("wget https://raw.githubusercontent.com/GuitarMusashi616/%s/%s/%s"):format(repo, branch, file)
  shell.run(cmd)
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