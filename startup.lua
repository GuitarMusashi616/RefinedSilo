

local util = require "util"
local shell = shell or mock("shell", "run")
local fs = fs or mock("fs", "exists")

local files = {"helper.lua", "silo.lua", "ui.lua"}
local repo = "RefinedSilo"

for i=1,#files do
  local file = files[i]
  if fs.exists(file) then
    shell.run("rm "..file)
  end
  util.wgit(repo, file)
end