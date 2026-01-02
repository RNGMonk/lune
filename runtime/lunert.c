/*
 * lunert - Minimal LuaJIT runtime for fused Lune executables
 */

#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifdef __APPLE__
#include <mach-o/dyld.h>
#else
#include <unistd.h>
#endif

/* ZIP signatures */
#define ZIP_EOCD_SIG 0x06054b50
#define ZIP_LOCAL_SIG 0x04034b50

/* Get path to current executable */
static const char* get_executable_path(void) {
    static char path[4096];
#ifdef __APPLE__
    uint32_t size = sizeof(path);
    if (_NSGetExecutablePath(path, &size) == 0) {
        return path;
    }
#else
    ssize_t len = readlink("/proc/self/exe", path, sizeof(path) - 1);
    if (len != -1) {
        path[len] = '\0';
        return path;
    }
#endif
    return NULL;
}

/* Check if executable has a ZIP appended (quick check) */
static int is_fused(const char* exe_path) {
    FILE* f = fopen(exe_path, "rb");
    if (!f) return 0;

    /* Check last 4KB for EOCD signature */
    fseek(f, -4096, SEEK_END);
    if (ftell(f) < 0) fseek(f, 0, SEEK_SET);

    unsigned char buf[4096];
    size_t len = fread(buf, 1, sizeof(buf), f);
    fclose(f);

    /* Search for EOCD signature (0x06054b50 in little endian) */
    for (size_t i = 0; i + 4 <= len; i++) {
        if (buf[i] == 0x50 && buf[i+1] == 0x4B &&
            buf[i+2] == 0x05 && buf[i+3] == 0x06) {
            return 1;
        }
    }
    return 0;
}

/* Bootstrap Lua code for fused mode */
static const char FUSED_BOOTSTRAP[] =
"local exe_path = _LUNERT_EXE_PATH\n"
"local f = assert(io.open(exe_path, 'rb'))\n"
"local content = f:read('*a')\n"
"f:close()\n"
"\n"
"-- Simple uncompressed ZIP reader\n"
"local function find_file(data, name)\n"
"    local pos = 1\n"
"    while pos < #data - 30 do\n"
"        local sig = data:sub(pos, pos+3)\n"
"        if sig == 'PK\\x03\\x04' then\n"
"            local name_len = data:byte(pos+26) + data:byte(pos+27) * 256\n"
"            local extra_len = data:byte(pos+28) + data:byte(pos+29) * 256\n"
"            local comp_size = data:byte(pos+18) + data:byte(pos+19)*256 + data:byte(pos+20)*65536 + data:byte(pos+21)*16777216\n"
"            local fname = data:sub(pos+30, pos+29+name_len)\n"
"            local data_start = pos + 30 + name_len + extra_len\n"
"            if fname == name then\n"
"                return data:sub(data_start, data_start + comp_size - 1)\n"
"            end\n"
"            pos = data_start + comp_size\n"
"        else\n"
"            pos = pos + 1\n"
"        end\n"
"    end\n"
"end\n"
"\n"
"-- Custom module loader\n"
"table.insert(package.loaders, 2, function(mod)\n"
"    local mod_path = mod:gsub('%.', '/')\n"
"    local paths = {\n"
"        mod_path .. '.lua',\n"
"        mod_path .. '/init.lua',\n"
"        'lua_deps/share/lua/5.1/' .. mod_path .. '.lua',\n"
"        'lua_deps/share/lua/5.1/' .. mod_path .. '/init.lua',\n"
"    }\n"
"    for _, p in ipairs(paths) do\n"
"        local src = find_file(content, p)\n"
"        if src then return assert(loadstring(src, '@'..p)) end\n"
"    end\n"
"end)\n"
"\n"
"-- Run main.lua\n"
"local main = find_file(content, 'main.lua')\n"
"if not main then error('No main.lua in bundle') end\n"
"assert(loadstring(main, '@main.lua'))()\n";

/* Bootstrap for interpreter mode */
static const char INTERP_BOOTSTRAP[] =
"if arg[1] then\n"
"    local f, err = loadfile(arg[1])\n"
"    if f then\n"
"        f()\n"
"    else\n"
"        io.stderr:write('Error: ' .. tostring(err) .. '\\n')\n"
"        os.exit(1)\n"
"    end\n"
"else\n"
"    print('lunert - Lune Runtime')\n"
"    print('Usage: lunert <script.lua>')\n"
"end\n";

int main(int argc, char** argv) {
    lua_State* L = luaL_newstate();
    if (!L) {
        fprintf(stderr, "Failed to create Lua state\n");
        return 1;
    }
    luaL_openlibs(L);

    /* Setup arg table */
    lua_newtable(L);
    for (int i = 0; i < argc; i++) {
        lua_pushstring(L, argv[i]);
        lua_rawseti(L, -2, i);
    }
    lua_setglobal(L, "arg");

    /* Get exe path and check fused mode */
    const char* exe_path = get_executable_path();
    int fused = exe_path ? is_fused(exe_path) : 0;

    if (exe_path) {
        lua_pushstring(L, exe_path);
        lua_setglobal(L, "_LUNERT_EXE_PATH");
    }
    lua_pushboolean(L, fused);
    lua_setglobal(L, "_LUNERT_IS_FUSED");

    /* Run bootstrap */
    const char* code = fused ? FUSED_BOOTSTRAP : INTERP_BOOTSTRAP;
    if (luaL_dostring(L, code) != 0) {
        fprintf(stderr, "Error: %s\n", lua_tostring(L, -1));
        lua_close(L);
        return 1;
    }

    lua_close(L);
    return 0;
}
