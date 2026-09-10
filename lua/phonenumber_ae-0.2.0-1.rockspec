-- LuaRocks manifest for the phonenumber_ae Lua binding (ABI v2).
--
--   luarocks make phonenumber_ae-0.2.0-1.rockspec
--
-- The C extension `dlopen`s the shared engine at runtime rather than linking
-- it, so this rock has no external build dependency beyond Lua's own headers.
-- The engine must be findable at run time: set $LIBPHONENUMBER_AE_LIB, or
-- install libphonenumber_ae.so somewhere the OS loader looks.

package = "phonenumber_ae"
version = "0.2.0-1"

source = {
  url = "git+https://github.com/paul-hammant/libphonenumber-ae.git",
  dir = "libphonenumber-ae/lua",
}

description = {
  summary = "Validate, parse and format international phone numbers.",
  detailed = [[
    A thin Lua 5.4 C-extension binding over the shared phonenumber native
    engine (compiled from pure Aether, over Google libphonenumber's metadata).
    No phone-number logic lives in Lua or in the extension — every call
    marshals to an aether_pn_embed_* symbol. v2 is full PhoneNumberUtil
    parity: parse + accessors, AsYouTypeFormatter, findNumbers, and the full
    stateless surface.
  ]],
  homepage = "https://github.com/paul-hammant/libphonenumber-ae",
  license = "MIT",
}

dependencies = {
  "lua >= 5.4",
}

build = {
  type = "builtin",
  modules = {
    -- The idiomatic surface.
    phonenumber_ae = "src/phonenumber_ae.lua",
    -- The C extension it requires. `-ldl` for dlopen; the extension must NOT
    -- link liblua (the host interpreter supplies those symbols).
    phonenumber_ae_native = {
      sources = { "src/phonenumber_ae.c" },
      libraries = { "dl" },
    },
  },
}
