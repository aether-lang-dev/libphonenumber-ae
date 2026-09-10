--- The 44-check binding conformance suite (docs/conformance.md, v5).
---
--- Proves the Lua binding marshals every value shape across the FFI. It is NOT
--- a phone-number test suite — the behavioural cases live in the engine's own
--- tests and run once, in Aether.
---
--- Lua 5.4 has no de-facto-standard test framework in its distribution, so this
--- is a plain assertion runner: no dependency to install, and the exit code is
--- the result.
---
---     lua5.4 -e 'package.cpath="./?.so;"..package.cpath' \
---            -e 'package.path="./src/?.lua;"..package.path' \
---            test/conformance.lua

local pn = require("phonenumber_ae")

-- ---- a minimal test harness ----

local passed, failed = 0, 0
local failures = {}

local function test(name, body)
  local ok, err = pcall(body)
  if ok then
    passed = passed + 1
    print("  PASS " .. name)
  else
    failed = failed + 1
    failures[#failures + 1] = name .. "\n      " .. tostring(err)
    print(string.format("  FAIL %s\n      %s", name, tostring(err)))
  end
end

local function eq(got, want, what)
  if got ~= want then
    error(string.format("%s:\n        got  %q\n        want %q",
      what or "value", tostring(got), tostring(want)), 2)
  end
end

local function is_true(got, what)
  if not got then error((what or "value") .. ": expected true, got " ..
    tostring(got), 2) end
end

local function is_false(got, what)
  if got then error((what or "value") .. ": expected false, got " ..
    tostring(got), 2) end
end

--- Assert a 1-based list equals `want` element-for-element.
local function eq_list(got, want, what)
  if #got ~= #want then
    error(string.format("%s: length got %d, want %d", what or "list",
      #got, #want), 2)
  end
  for i = 1, #want do
    if got[i] ~= want[i] then
      error(string.format("%s[%d]:\n        got  %q\n        want %q",
        what or "list", i, tostring(got[i]), tostring(want[i])), 2)
    end
  end
end

print("=== phonenumber_ae Lua binding conformance (v5) ===")
print(string.format("engine: %s (ABI v%d)", pn.engine_path(), pn.abi_version()))

-- ---- the forty ----

test("01 country_code US == 1", function()
  eq(pn.country_code("US"), "1")
end)

test("02 country_code GB == 44", function()
  eq(pn.country_code("GB"), "44")
end)

test("03 country_code ZZ == empty", function()
  eq(pn.country_code("ZZ"), "")
end)

test("04 example_number US", function()
  eq(pn.example_number("US"), "2015550123")
end)

test("05 possible_lengths US", function()
  eq(pn.possible_lengths("US"), "10")
end)

test("06 region_code_for_country_code 44 == GB", function()
  eq(pn.region_code_for_country_code("44"), "GB")
end)

test("07 is_nanpa_country US", function()
  is_true(pn.is_nanpa_country("US"), "is_nanpa_country")
end)

test("08 region enumeration", function()
  local regs = pn.regions()
  is_true(#regs >= 200, "region count >= 200")
  eq(#regs[1], 2, "first region id is 2 letters")
end)

test("09 cc_region_at 1[0] == US", function()
  eq(pn.regions_for_country_code("1")[1], "US")
end)

test("10-14 parse +1 201 555 0123 ext 42", function()
  local num = pn.parse("+1 201 555 0123 ext 42", "US")
  eq(num:error(), "", "parse error")
  eq(num:national_number(), "2015550123", "national_number")   -- 10
  eq(num:extension(), "42", "extension")                       -- 11
  eq(num:country_code(), "1", "country_code")                  -- 12
  eq(num:source(), pn.SRC_FROM_NUMBER_WITH_PLUS, "source")     -- 13
  eq(num:region_code(), "US", "region_code")                   -- 14
end)

test("15 parse trunk-prefix GB", function()
  eq(pn.parse("01212345678", "GB"):national_number(), "1212345678")
end)

test("16 is_possible yes", function()
  is_true(pn.is_possible_number("US", "2015550123"), "is_possible")
end)

test("17 reason TOO_SHORT", function()
  eq(pn.is_possible_number_with_reason("US", "201555"), pn.VR_TOO_SHORT, "reason")
end)

test("18 is_valid yes", function()
  is_true(pn.is_valid_number("US", "2015550123"), "is_valid")
end)

test("19 is_valid wrong shape", function()
  is_false(pn.is_valid_number("US", "1015550123"), "is_valid")
end)

test("20 is_valid with +cc", function()
  is_true(pn.is_valid_number("US", "+12015550123"), "is_valid")
end)

test("21 number_type fixed-line-or-mobile / fixed line", function()
  -- US fixedLine==mobile -> FIXED_LINE_OR_MOBILE; GB has distinct patterns
  eq(pn.number_type("US", "2015550123"), pn.TYPE_FIXED_LINE_OR_MOBILE, "number_type US")
  eq(pn.number_type("GB", "2070313000"), pn.TYPE_FIXED_LINE, "number_type GB")
end)

test("22 format NATIONAL", function()
  eq(pn.format("US", "2015550123", pn.NATIONAL), "(201) 555-0123")
end)

test("23 format E164", function()
  eq(pn.format("US", "2015550123", pn.E164), "+12015550123")
end)

test("24 format INTERNATIONAL", function()
  eq(pn.format("US", "2015550123", pn.INTERNATIONAL), "+1 201-555-0123")
end)

test("25 format RFC3966", function()
  eq(pn.format("US", "2015550123", pn.RFC3966), "tel:+1-201-555-0123")
end)

test("26 is_number_match EXACT", function()
  eq(pn.is_number_match("+12015550123", "+1 201 555 0123"), pn.MATCH_EXACT, "match")
end)

test("27 is_number_match NO_MATCH", function()
  eq(pn.is_number_match("+12015550123", "+12025550123"), pn.MATCH_NO_MATCH, "match")
end)

test("28 normalize_digits_only", function()
  eq(pn.normalize_digits_only("+1 (201) 555.0123"), "12015550123")
end)

test("29 convert_alpha_characters", function()
  eq(pn.convert_alpha_characters("1-800-FLOWERS"), "1-800-3569377")
end)

test("30 truncate_too_long", function()
  eq(pn.truncate_too_long("US", "20155501239999"), "2015550123")
end)

test("31 AsYouType 2015550123", function()
  local ayt = pn.AsYouTypeFormatter.new("US")
  local out = ""
  for c in ("2015550123"):gmatch(".") do
    out = ayt:input_digit(c)
  end
  eq(out, "(201) 555-0123", "as-you-type")
end)

test("32 matcher_count == 2", function()
  local matches = pn.find_numbers("call 201-555-0123 or +1 202 555 0199", "US",
                                  pn.LENIENCY_VALID)
  eq(#matches, 2, "match count")
end)

test("33 matcher_raw", function()
  local matches = pn.find_numbers("call 201-555-0123 now", "US", pn.LENIENCY_VALID)
  eq(matches[1].raw, "201-555-0123", "match raw")
end)

test("34 abi_version == 5", function()
  eq(pn.abi_version(), 5, "abi_version")
end)

test("35 short is_emergency US 911", function()
  is_true(pn.is_emergency_number("US", "911"), "is_emergency_number")
end)

test("36 short not-emergency US 999", function()
  is_false(pn.is_emergency_number("US", "999"), "is_emergency_number")
end)

test("37 short is_emergency GB 999", function()
  is_true(pn.is_emergency_number("GB", "999"), "is_emergency_number")
end)

test("38 short is_valid US 911", function()
  is_true(pn.short_is_valid("US", "911"), "short_is_valid")
end)

test("39 short expected_cost US 911 toll-free", function()
  eq(pn.short_expected_cost("US", "911"), pn.COST_TOLL_FREE, "short_expected_cost")
end)

test("40 short example_number US == 112", function()
  eq(pn.short_example_number("US"), "112")
end)

test("41 time_zones_for_number US == America/New_York", function()
  eq_list(pn.time_zones_for_number("US", "2015550123"),
          { "America/New_York" }, "time_zones US")
end)

test("42 time_zones_for_number GB == Europe/London", function()
  eq_list(pn.time_zones_for_number("GB", "2070313000"),
          { "Europe/London" }, "time_zones GB")
end)

test("43 unknown_time_zone == Etc/Unknown", function()
  eq(pn.unknown_time_zone(), "Etc/Unknown")
end)

test("44 carrier_name_for_number GB 7106000000 == O2", function()
  eq(pn.carrier_name_for_number("GB", "7106000000"), "O2")
end)

-- ---- a few surface extras ----

test("format style aliases agree", function()
  eq(pn.format_national("US", "2015550123"), "(201) 555-0123")
  eq(pn.format_international("US", "2015550123"), "+1 201-555-0123")
  eq(pn.format_e164("US", "2015550123"), "+12015550123")
  eq(pn.format_rfc3966("US", "2015550123"), "tel:+1-201-555-0123")
end)

test("region_at out of range is an empty string", function()
  eq(pn.region_at(1000000), "", "out of range")
  eq(pn.region_at(0), "", "below range (1-based)")
end)

test("sorted_regions is deterministic", function()
  local s = pn.sorted_regions()
  eq(#s, #pn.regions(), "same length")
  is_true(s[1] <= s[#s], "ordered")
end)

test("time_zone_count agrees with the list length", function()
  eq(pn.time_zone_count("US", "2015550123"), 1, "time_zone_count")
  eq(#pn.time_zones_for_number("US", "2015550123"), 1, "list length")
end)

test("carrier_name_for_valid agrees for a valid number", function()
  eq(pn.carrier_name_for_valid_number("GB", "7106000000"), "O2")
end)

test("many round trips do not leak", function()
  for _ = 1, 3000 do
    eq(pn.country_code("US"), "1")
  end
end)

-- ---- result ----

print(string.format("=== %d passed, %d failed ===", passed, failed))
if failed > 0 then
  print("failures:")
  for _, f in ipairs(failures) do print("  - " .. f) end
  os.exit(1)
end
os.exit(0)
