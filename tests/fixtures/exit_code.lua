-- Script that returns an exit code based on argument
local code = tonumber(arg[1]) or 0
os.exit(code)
