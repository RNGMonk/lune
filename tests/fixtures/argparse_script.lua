-- Script that uses argparse (pure Lua dependency)
local argparse = require("argparse")

local parser = argparse("test", "A test script")
parser:option("-n --name", "Name to greet"):default("World")

local args = parser:parse()
print("Hello, " .. args.name .. "!")
