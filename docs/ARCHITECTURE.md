# Lune Architecture

Lune is a LuaJIT interpreter and package manager CLI, written in Lua itself.

## Overview

Lune provides three core features:

1. **`lune script.lua`** - Run Lua scripts with LuaJIT
2. **`lune install <package>`** - Install packages from luarocks.org to local `./lua_deps`
3. **`lune compile script.lua -o app`** - Compile projects to standalone executables

## Directory Structure

```
lune/
├── Makefile                    # Build system (lune, install, clean targets)
├── bin/lune                    # Bootstrap shell script (dev mode)
├── runtime/
│   ├── lunert.c                # Minimal C runtime (~275 lines)
│   └── lunert                  # Compiled runtime binary
├── src/
│   ├── main.lua                # Entry point & package.path setup
│   ├── cli/
│   │   ├── init.lua            # CLI framework & command dispatch
│   │   ├── run.lua             # Run command
│   │   ├── install.lua         # Install command
│   │   ├── compile.lua         # Compile command
│   │   └── init_project.lua    # Init command
│   ├── core/
│   │   ├── fs.lua              # Filesystem operations (LuaJIT FFI)
│   │   ├── paths.lua           # Path utilities
│   │   └── config.lua          # Configuration loading
│   ├── package/
│   │   ├── installer.lua       # Main install interface
│   │   ├── registry.lua        # luarocks.org API client
│   │   ├── rockspec.lua        # Rockspec parsing
│   │   ├── builder.lua         # Package building (Lua & C modules)
│   │   ├── archive.lua         # Archive extraction
│   │   └── http.lua            # HTTP client (curl wrapper)
│   ├── compile/
│   │   ├── bundler.lua         # ZIP bundle creation
│   │   └── fuser.lua           # ZIP fusion with runtime
│   └── runtime/
│       ├── loader.lua          # Custom package loader for lua_deps
│       └── fused.lua           # Fused executable detection
└── vendor/                     # Vendored Lua dependencies (currently empty)
```

## Key Components

### 1. CLI Framework (`src/cli/`)

The CLI dispatcher (`src/cli/init.lua`) handles argument parsing and routes to command modules:

- Implicit `run` for `.lua` files: `lune script.lua` → `cli/run.lua`
- Explicit commands: `lune install pkg` → `cli/install.lua`
- Commands are lazy-loaded to avoid circular dependencies

### 2. Core Utilities (`src/core/`)

**fs.lua** - Filesystem operations using LuaJIT FFI (no external dependencies):
- `exists()`, `is_dir()`, `is_file()`, `size()`
- `mkdir()`, `mkdir_p()`, `rmdir_r()`
- `read_file()`, `write_file()`, `copy_file()`
- `listdir()`, `walk()` - directory traversal

**paths.lua** - Path manipulation:
- `join()`, `dirname()`, `basename()`
- `get_lua_deps()` - returns `./lua_deps` path

### 3. Package Manager (`src/package/`)

**installer.lua** - Main installation logic:
- Fetches rockspecs from luarocks.org
- Resolves and installs dependencies recursively
- Supports both pure Lua and C modules
- Installs to `./lua_deps/` (luarocks-compatible structure)

**builder.lua** - Package building:
- `build_builtin()` - copies Lua files to correct locations
- `install_c_module()` - compiles C modules with auto-detected LuaJIT paths
- Uses `-undefined dynamic_lookup` on macOS for proper symbol resolution

**registry.lua** - luarocks.org API client:
- Fetches package manifests and rockspecs
- Resolves latest versions

### 4. Compilation System (`src/compile/`)

**bundler.lua** - Creates ZIP archives:
- `create_zip()` - generates uncompressed ZIP data
- `collect_lua_files()` - gathers Lua files from directories
- `collect_native_libs()` - finds .so/.dylib files in lua_deps
- `bundle()` - combines entry point + dependencies into ZIP

**fuser.lua** - ZIP fusion:
- `get_runtime_data()` - extracts runtime from self (when embedded) or reads from file
- `fuse()` - concatenates runtime + ZIP to create executable

### 5. C Runtime (`runtime/lunert.c`)

Minimal LuaJIT wrapper (~275 lines) that enables fused executables:

**Detection Logic:**
1. Check if executable has ZIP appended (scan for EOCD signature)
2. If fused, check for `src/cli/init.lua` → CLI mode (lune itself)
3. If fused, check for `main.lua` → App mode (compiled application)
4. Otherwise → Interpreter mode (run script from argv)

**Bootstrap Modes:**

- **CLI Mode** - Sets `LUNE_EMBEDDED=true`, loads embedded `cli` module
- **App Mode** - Sets up `package.cpath` for lib/, loads embedded `main.lua`
- **Interpreter Mode** - Runs script passed as argument

## Data Flow

### Running Scripts (`lune script.lua`)

```
bin/lune (shell) → luajit src/main.lua
                        ↓
                   cli/init.lua (dispatch)
                        ↓
                   cli/run.lua
                        ↓
                   runtime/loader.lua (setup lua_deps paths)
                        ↓
                   loadfile(script.lua)
```

### Installing Packages (`lune install argparse`)

```
cli/install.lua
      ↓
package/installer.lua
      ├── registry.lua (fetch rockspec from luarocks.org)
      ├── rockspec.lua (parse dependencies)
      ├── http.lua + archive.lua (download & extract source)
      └── builder.lua (build & install to lua_deps/)
```

### Compiling Executables (`lune compile app.lua -o myapp`)

```
cli/compile.lua
      ↓
compile/bundler.lua
      ├── collect Lua files
      ├── collect native libs (.so/.dylib)
      └── create_zip() → ZIP data
      ↓
compile/fuser.lua
      ├── get_runtime_data() (extract from self or read lunert)
      └── fuse() → runtime + ZIP → myapp executable
      ↓
Copy native libs to lib/ folder alongside executable
```

### Running Compiled Executables (`./myapp`)

```
myapp (fused: lunert + ZIP)
      ↓
lunert.c detects ZIP, runs FUSED_APP_BOOTSTRAP
      ↓
Lua bootstrap:
      ├── Sets package.cpath to lib/ folder
      ├── Installs custom package.loaders for ZIP reading
      └── Loads and runs main.lua from embedded ZIP
```

## ZIP Fusion Technique

Lune uses the "LÖVE-style" ZIP fusion approach:

1. ZIP files are valid when read from the end (EOCD record points backward)
2. Executable files are valid when read from the beginning
3. Concatenating `executable + ZIP` creates a file that is both valid

```
┌─────────────────────┐
│   lunert binary     │  ← OS loads this as executable
│   (statically       │
│    linked LuaJIT)   │
├─────────────────────┤
│   ZIP archive       │  ← ZIP readers find EOCD at end
│   - main.lua        │
│   - lua_deps/...    │
│   - EOCD record     │
└─────────────────────┘
```

## Native Module Handling

Native C modules (.so/.dylib) cannot be loaded from inside a ZIP because the OS dynamic loader (`dlopen`) requires filesystem access.

**Solution: Side-by-Side Libraries**

```
myapp           # Fused executable
lib/
  lfs.so        # Native modules copied here
  socket/
    core.so
```

The runtime bootstrap configures `package.cpath`:
```lua
package.cpath = exe_dir .. 'lib/?.so;' .. exe_dir .. 'lib/?.dylib;' .. package.cpath
```

## Build Process

### Building Lune (`make`)

```
1. Compile lunert.c → runtime/lunert
   (statically links LuaJIT library)

2. Create source bundle:
   zip -r -0 lune-src.zip src/ vendor/

3. Fuse:
   cat runtime/lunert lune-src.zip > runtime/lune

4. Result: ~630KB self-contained binary
```

### Installation (`make install`)

```
cp runtime/lune /usr/local/bin/lune
```

## lua_deps Structure

Packages are installed in a luarocks-compatible layout:

```
lua_deps/
├── share/lua/5.1/          # Pure Lua modules
│   ├── argparse.lua
│   └── socket/
│       └── http.lua
├── lib/lua/5.1/            # Native modules
│   ├── lfs.so
│   └── socket/
│       └── core.so
└── lib/luarocks/rocks-5.1/ # Installation manifests
    └── argparse/
        └── 0.7.1-1/
            └── rock_manifest
```

## Key Technical Decisions

1. **LuaJIT FFI for filesystem** - No external dependencies, works everywhere LuaJIT runs

2. **Parse rockspecs directly** - Rockspecs are Lua files, loaded in sandbox environment

3. **Uncompressed ZIP** - Simpler reading code in lunert.c (no zlib dependency)

4. **Static LuaJIT linking** - Single binary with no runtime dependencies

5. **Side-by-side native libs** - Practical solution for OS dynamic loader constraints

## Environment Requirements

**Building from source:**
- C compiler (cc/gcc/clang)
- LuaJIT headers and static library
- zip command (for creating bundles)

**Using compiled lune binary:**
- No dependencies required

**For packages with native modules:**
- C compiler (at install time)
- LuaJIT development headers
