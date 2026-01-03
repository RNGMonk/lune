-- Script that uses luafilesystem (native C dependency)
local lfs = require("lfs")

local cwd = lfs.currentdir()
print("Current directory: " .. cwd)
