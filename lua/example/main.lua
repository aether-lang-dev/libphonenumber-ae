-- A short tour of the Lua binding (ABI v2). Run it with the engine built:
--
--   aeb core/.build.ae
--   cd lua && cc -O2 -fPIC -shared -I/usr/include/lua5.4 \
--       src/phonenumber_ae.c -o phonenumber_ae_native.so -ldl
--   LUA_CPATH="./?.so;;" LUA_PATH="./src/?.lua;;" \
--       LIBPHONENUMBER_AE_LIB=../target/build/core/lib/libphonenumber_ae.so \
--       lua5.4 example/main.lua

local pn = require("phonenumber_ae")

print(string.format("engine: %s (ABI v%d)", pn.engine_path(), pn.abi_version()))

print("country code US: " .. pn.country_code("US"))            -- 1
print("is valid:        " .. tostring(
  pn.is_valid_number("US", "+1 201 555 0123")))                -- true

-- parse -> a ParsedNumber with accessors
local num = pn.parse("+1 201 555 0123 ext 42", "US")
print("national:        " .. num:national_number())           -- 2015550123
print("extension:       " .. num:extension())                 -- 42
print("region:          " .. num:region_code())               -- US

print("national fmt:    " .. pn.format("US", "2015550123", pn.NATIONAL))
print("intl fmt:        " .. pn.format("US", "2015550123", pn.INTERNATIONAL))
print("e164 fmt:        " .. pn.format("US", "2015550123", pn.E164))
print("rfc3966 fmt:     " .. pn.format("US", "2015550123", pn.RFC3966))

print("number type:     " .. pn.number_type("US", "2015550123"))  -- 0 (fixed line)

-- AsYouTypeFormatter, digit by digit
local ayt = pn.AsYouTypeFormatter.new("US")
local last
for c in ("2015550123"):gmatch(".") do last = ayt:input_digit(c) end
print("as-you-type:     " .. last)                            -- (201) 555-0123

-- find numbers in free text
for _, m in ipairs(pn.find_numbers("call 201-555-0123 or +1 202 555 0199", "US")) do
  print("found:           " .. m.raw)
end

local regs = pn.regions()
print(string.format("regions:         %d known (first: %s)", #regs, regs[1]))
