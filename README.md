# Lune

Lune is a Luajit focused package and project management tool. It aims to fulfill a similar space to uv for Python or deno for Javascript by:
- Providing a single binary download
- Includes the Luajit runtime
- Includes Luarocks compatible package management
- Allows compiling of dependencies into a single binary

In addition I'm interested in providing first class integration for:
- Testing
- Benchmarking
- Fennel support
- Typechecking via Teal

Overall the goal of lune is to provide a first class developer experience for Lua based development and to make Lua a viable alternative to Node or Python.

Historically the focus of Lua has been on its ease of embeddability, but in my opinion this has lead to too much fragmentation in the ecosystem where each major Lua project is an island (e.g. Love2d, Openresty, Neovim). My vision is that Lune could unify the ecosystem and make invert the embeddability so that we could `lune install love` or `lune install <web-framework>` instead.

## Status

Note: Lune is still pre-alpha software so use at your own risk.
