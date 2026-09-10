--- Validate, parse and format international phone numbers (ABI v5).
---
--- The idiomatic Lua surface over the phonenumber engine. Carries no
--- phone-number logic — every function here marshals to the C extension in
--- `phonenumber_ae_native` (lua/src/phonenumber_ae.c), which in turn calls the
--- `aether_pn_embed_*` ABI. One engine, one set of behaviours, N language
--- surfaces.
---
---     local pn = require("phonenumber_ae")
---     local num = pn.parse("+1 650 253 0000", "US")
---     print(num:national_number())                       -- "6502530000"
---     print(pn.is_valid_number("US", "+1 650 253 0000"))  -- true
---     print(pn.format("US", "6502530000", pn.INTERNATIONAL)) -- "+1 650-253-0000"
---
---     local ayt = pn.AsYouTypeFormatter.new("US")
---     local last
---     for c in ("6502530000"):gmatch(".") do last = ayt:input_digit(c) end
---     -- last == "(650) 253-0000"
---
---     for _, m in ipairs(pn.find_numbers("call 201-555-0123 today", "US")) do
---       print(m.raw)                                      -- "201-555-0123"
---     end

local native = require("phonenumber_ae_native")

local M = {}

-- ---- ABI constants, re-exported (append only, never renumber) ----

--- Format styles. NOTE: in v2, E164 is 0 (it was 2 in v1).
M.E164          = native.E164
M.INTERNATIONAL = native.INTERNATIONAL
M.NATIONAL      = native.NATIONAL
M.RFC3966       = native.RFC3966

--- Number types (number_type result; -1 = unknown).
M.TYPE_UNKNOWN         = native.TYPE_UNKNOWN
M.TYPE_FIXED_LINE      = native.TYPE_FIXED_LINE
M.TYPE_MOBILE          = native.TYPE_MOBILE
M.TYPE_TOLL_FREE       = native.TYPE_TOLL_FREE
M.TYPE_PREMIUM_RATE    = native.TYPE_PREMIUM_RATE
M.TYPE_SHARED_COST     = native.TYPE_SHARED_COST
M.TYPE_VOIP            = native.TYPE_VOIP
M.TYPE_PERSONAL_NUMBER = native.TYPE_PERSONAL_NUMBER
M.TYPE_PAGER           = native.TYPE_PAGER
M.TYPE_UAN             = native.TYPE_UAN
M.TYPE_VOICEMAIL       = native.TYPE_VOICEMAIL
M.TYPE_FIXED_LINE_OR_MOBILE = native.TYPE_FIXED_LINE_OR_MOBILE

--- ValidationResult (is_possible_number_with_reason).
M.VR_IS_POSSIBLE            = native.VR_IS_POSSIBLE
M.VR_IS_POSSIBLE_LOCAL_ONLY = native.VR_IS_POSSIBLE_LOCAL_ONLY
M.VR_INVALID_COUNTRY_CODE   = native.VR_INVALID_COUNTRY_CODE
M.VR_TOO_SHORT              = native.VR_TOO_SHORT
M.VR_INVALID_LENGTH         = native.VR_INVALID_LENGTH
M.VR_TOO_LONG               = native.VR_TOO_LONG

--- MatchType (is_number_match).
M.MATCH_NOT_A_NUMBER = native.MATCH_NOT_A_NUMBER
M.MATCH_NO_MATCH     = native.MATCH_NO_MATCH
M.MATCH_SHORT_NSN    = native.MATCH_SHORT_NSN
M.MATCH_NSN          = native.MATCH_NSN
M.MATCH_EXACT        = native.MATCH_EXACT

--- CountryCodeSource (pn_source).
M.SRC_FROM_NUMBER_WITH_PLUS    = native.SRC_FROM_NUMBER_WITH_PLUS
M.SRC_FROM_NUMBER_WITH_IDD     = native.SRC_FROM_NUMBER_WITH_IDD
M.SRC_FROM_NUMBER_WITHOUT_PLUS = native.SRC_FROM_NUMBER_WITHOUT_PLUS
M.SRC_FROM_DEFAULT_COUNTRY     = native.SRC_FROM_DEFAULT_COUNTRY

--- Matcher leniency.
M.LENIENCY_POSSIBLE = native.LENIENCY_POSSIBLE
M.LENIENCY_VALID    = native.LENIENCY_VALID

--- ShortNumberCost (short_expected_cost).
M.COST_TOLL_FREE     = native.COST_TOLL_FREE
M.COST_STANDARD_RATE = native.COST_STANDARD_RATE
M.COST_PREMIUM_RATE  = native.COST_PREMIUM_RATE
M.COST_UNKNOWN       = native.COST_UNKNOWN

-- ---- metadata ----

--- The country calling code for a region ("1", "44", …), or "" if unknown.
function M.country_code(region)
  return native.country_code(region)
end

--- An example national number for the region, or "".
function M.example_number(region)
  return native.example_number(region)
end

--- An example national number of a given TYPE_* for the region, or "".
function M.example_number_for_type(region, ntype)
  return native.example_number_for_type(region, ntype)
end

--- An example number that is the right shape but invalid, or "".
function M.invalid_example_number(region)
  return native.invalid_example_number(region)
end

--- The possible-lengths spec for the region (e.g. "9,10"), or "".
function M.possible_lengths(region)
  return native.possible_lengths(region)
end

--- The main region for a country calling code ("44" -> "GB"), or "".
function M.region_code_for_country_code(cc)
  return native.region_code_for_country_code(tostring(cc))
end

--- True if the region is part of the North American Numbering Plan.
function M.is_nanpa_country(region)
  return native.is_nanpa_country(region)
end

--- The national-direct-dial prefix for a region (e.g. "0" or "1"), or "".
--- `strip_non_digits` is a boolean.
function M.ndd_prefix_for_region(region, strip_non_digits)
  return native.ndd_prefix_for_region(region, strip_non_digits and true or false)
end

--- How many region ids the metadata carries.
function M.region_count()
  return native.region_count()
end

--- The region id at a 1-based `index`, or "" when out of range. (The ABI is
--- 0-based; the C extension does the conversion so Lua stays 1-based.)
function M.region_at(index)
  return native.region_at(index)
end

--- Every region id the metadata carries, as a table (engine order).
function M.regions()
  local out = {}
  for i = 1, native.region_count() do
    out[i] = native.region_at(i)
  end
  return out
end

--- The regions, sorted — the deterministic version of `regions()`.
function M.sorted_regions()
  local out = M.regions()
  table.sort(out)
  return out
end

--- Every region that shares a country calling code ("1" -> {"US","CA",…}).
function M.regions_for_country_code(cc)
  cc = tostring(cc)
  local out = {}
  local n = native.cc_region_count(cc)
  for i = 1, n do
    out[i] = native.cc_region_at(cc, i)  -- C extension is 1-based here too
  end
  return out
end

-- ---- ParsedNumber ----

--- A parsed phone number. Wraps the caller-owned parsed-number string the ABI
--- returns; its fields are read on demand through the pn_* accessors.
local ParsedNumber = {}
ParsedNumber.__index = ParsedNumber
M.ParsedNumber = ParsedNumber

function ParsedNumber.new(pn_string)
  return setmetatable({ _pn = pn_string }, ParsedNumber)
end

function ParsedNumber:region()
  return native.pn_region(self._pn)
end

function ParsedNumber:country_code()
  return native.pn_country_code(self._pn)
end

function ParsedNumber:national_number()
  return native.pn_national_number(self._pn)
end

function ParsedNumber:extension()
  return native.pn_extension(self._pn)
end

function ParsedNumber:italian_leading_zero()
  return native.pn_italian_leading_zero(self._pn)
end

function ParsedNumber:source()
  return native.pn_source(self._pn)
end

function ParsedNumber:error()
  return native.pn_error(self._pn)
end

function ParsedNumber:region_code()
  return native.region_code_for_number(self._pn)
end

function ParsedNumber:national_significant_number()
  return native.national_significant_number(self._pn)
end

function ParsedNumber:length_of_ndc()
  return native.length_of_ndc(self._pn)
end

function ParsedNumber:length_of_area_code()
  return native.length_of_area_code(self._pn)
end

function ParsedNumber:is_geographical()
  return native.is_geographical(self._pn)
end

--- Parse a human-typed number in a default region, returning a ParsedNumber.
function M.parse(input, region)
  return ParsedNumber.new(native.parse(input, region))
end

--- The national number extracted from raw input (cc + punctuation stripped).
function M.national_number(region, input)
  return native.national_number(region, input)
end

-- ---- validation ----

--- True if the national number is a length the region allows.
function M.is_possible_number(region, input)
  return native.is_possible_number(region, input)
end

--- Why (or that) a number is possible — a VR_* ValidationResult integer.
function M.is_possible_number_with_reason(region, input)
  return native.is_possible_number_with_reason(region, input)
end

--- True if the number matches the region's national-number patterns.
function M.is_valid_number(region, input)
  return native.is_valid_number(region, input)
end

--- True if a number is valid *for the given region* specifically.
function M.is_valid_number_for_region(input, region)
  return native.is_valid_number_for_region(input, region)
end

--- The number type (a TYPE_* integer; -1 for unknown).
function M.number_type(region, input)
  return native.number_type(region, input)
end

--- True if the number can be dialled from outside its country.
function M.can_be_internationally_dialled(region, input)
  return native.can_be_internationally_dialled(region, input)
end

-- ---- formatting ----

--- Format the number in the given style (E164 / INTERNATIONAL / NATIONAL /
--- RFC3966). `style` defaults to NATIONAL.
function M.format(region, input, style)
  return native.format(region, input, style or M.NATIONAL)
end

function M.format_national(region, input)
  return native.format(region, input, M.NATIONAL)
end

function M.format_international(region, input)
  return native.format(region, input, M.INTERNATIONAL)
end

function M.format_e164(region, input)
  return native.format(region, input, M.E164)
end

function M.format_rfc3966(region, input)
  return native.format(region, input, M.RFC3966)
end

--- Format as dialled from `calling_from` to a number in `region`.
function M.format_out_of_country(region, input, calling_from)
  return native.format_out_of_country(region, input, calling_from)
end

--- Format a ParsedNumber the way it was originally entered, from `calling_from`.
function M.format_in_original(parsed, calling_from)
  local pn = getmetatable(parsed) == ParsedNumber and parsed._pn or parsed
  return native.format_in_original(pn, calling_from)
end

-- ---- relations / helpers ----

--- Compare two numbers — a MATCH_* MatchType integer.
function M.is_number_match(a, b)
  return native.is_number_match(a, b)
end

--- Truncate an over-long number to the longest valid prefix, or "".
function M.truncate_too_long(region, input)
  return native.truncate_too_long(region, input)
end

--- Keep only the digits in a string (also mapping wide/fullwidth digits).
function M.normalize_digits_only(s)
  return native.normalize_digits_only(s)
end

--- Convert vanity letters to their dial digits (1-800-FLOWERS -> 1-800-3569377).
function M.convert_alpha_characters(s)
  return native.convert_alpha_characters(s)
end

--- True if the string contains vanity letters.
function M.is_alpha_number(s)
  return native.is_alpha_number(s)
end

-- ---- AsYouTypeFormatter ----

--- Formats a number as it is typed, digit by digit. The formatter state is a
--- caller-owned string the ABI hands back on each keypress; this object keeps
--- the current one and swaps it as characters arrive.
local AsYouTypeFormatter = {}
AsYouTypeFormatter.__index = AsYouTypeFormatter
M.AsYouTypeFormatter = AsYouTypeFormatter

function AsYouTypeFormatter.new(region)
  return setmetatable({ _state = native.ayt_new(region) }, AsYouTypeFormatter)
end

--- Feed one character; return the formatted-so-far string.
function AsYouTypeFormatter:input_digit(ch)
  self._state = native.ayt_input(self._state, tostring(ch))
  return self:result()
end

--- The formatted-so-far string, without feeding anything.
function AsYouTypeFormatter:result()
  return native.ayt_result(self._state)
end

--- Reset the formatter to empty.
function AsYouTypeFormatter:clear()
  self._state = native.ayt_clear(self._state)
end

-- ---- PhoneNumberMatcher / find_numbers ----

--- Find phone numbers in free text. Returns a list of matches, each a table
--- { start = <byte offset>, ["end"] = <byte offset>, raw = <matched text> }.
--- Offsets are the ABI's own (0-based) byte offsets into `text`.
function M.find_numbers(text, region, leniency)
  leniency = leniency or M.LENIENCY_VALID
  local out = {}
  local n = native.matcher_count(text, region, leniency)
  for i = 0, n - 1 do
    out[i + 1] = {
      start = native.matcher_start(text, region, leniency, i),
      ["end"] = native.matcher_end(text, region, leniency, i),
      raw = native.matcher_raw(text, region, leniency, i),
    }
  end
  return out
end

-- ---- ShortNumberInfo (short / emergency numbers) ----
-- Short numbers are dialled as-is (no cc, no national prefix): the input is the
-- raw short number plus a region.

--- True if `input` is a possible short number for the region (right length).
function M.short_is_possible(region, input)
  return native.short_is_possible(region, input)
end

--- True if `input` matches a short-number pattern for the region.
function M.short_is_valid(region, input)
  return native.short_is_valid(region, input)
end

--- True if `input` is an emergency number for the region (e.g. US "911").
function M.is_emergency_number(region, input)
  return native.short_is_emergency(region, input)
end

--- True if dialling `input` connects to an emergency number for the region.
function M.connects_to_emergency_number(region, input)
  return native.short_connects_to_emergency(region, input)
end

--- True if the short number is specific to a single carrier.
function M.short_is_carrier_specific(region, input)
  return native.short_is_carrier_specific(region, input)
end

--- True if the short number is usable as an SMS service.
function M.short_is_sms_service(region, input)
  return native.short_is_sms_service(region, input)
end

--- The expected cost of dialling the short number (a COST_* integer).
function M.short_expected_cost(region, input)
  return native.short_expected_cost(region, input)
end

--- An example short number for the region, or "".
function M.short_example_number(region)
  return native.short_example_number(region)
end

-- ---- PhoneNumberToTimeZonesMapper (timezone lookup) ----
-- Longest-prefix match over the number's E.164 digits: pass a raw (region,
-- input) like everywhere else and the engine parses to E.164 itself. The
-- unknown-zone sentinel is "Etc/Unknown".

--- The unknown-timezone sentinel, "Etc/Unknown".
function M.unknown_time_zone()
  return native.tz_unknown()
end

--- How many timezones the number maps to (0 = only the unknown zone).
function M.time_zone_count(region, input)
  return native.tz_count(region, input)
end

--- The IANA timezone ids for a number, as a list (a 1-based table). A number
--- with no known zones comes back as a single-element list holding the unknown
--- zone, never empty — matching the other bindings.
function M.time_zones_for_number(region, input)
  local n = native.tz_count(region, input)
  if n == 0 then
    return { M.unknown_time_zone() }
  end
  local out = {}
  for i = 0, n - 1 do        -- ABI idx is 0-based; build a 1-based list
    out[i + 1] = native.tz_at(region, input, i)
  end
  return out
end

-- ---- PhoneNumberToCarrierMapper (English carrier names) ----
-- Longest-prefix match over the E.164 digits; English names only. "" when no
-- carrier is known for the number.

--- The carrier name for a number (English), or "" if none is known.
function M.carrier_name_for_number(region, input)
  return native.carrier_name(region, input)
end

--- The carrier name only when the number is valid, else "".
function M.carrier_name_for_valid_number(region, input)
  return native.carrier_name_for_valid(region, input)
end

-- ---- lifecycle ----

--- The engine's ABI revision.
function M.abi_version()
  return native.abi_version()
end

--- Where the engine `.so` was actually loaded from.
function M.engine_path()
  return native.engine_path()
end

--- Force the engine to load from an explicit path (before first use). Returns
--- the resolved path.
function M.load(path)
  return native.load(path)
end

return M
