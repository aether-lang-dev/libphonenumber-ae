# phonenumber_ae (Ruby)

A thin Ruby binding over the shared, pure-Aether libphonenumber engine — the
full **v6 ABI** (full `PhoneNumberUtil` parity plus `ShortNumberInfo`, time
zones, carrier names and geocoding).

```ruby
require "phonenumber_ae"

# Parse a raw number into a ParsedNumber; read its fields on demand.
num = PhoneNumberAe.parse("+1 201 555 0123 ext 42", "US")
num.national_number     # => "2015550123"
num.extension           # => "42"
num.country_code        # => "1"
num.region_code         # => "US"
num.source              # => PhoneNumberAe::SRC_FROM_NUMBER_WITH_PLUS

# Validate and format.
PhoneNumberAe.is_valid_number("US", "+1 201 555 0123")               # => true
PhoneNumberAe.is_possible_number_with_reason("US", "201555")         # => TOO_SHORT
PhoneNumberAe.format("US", "2015550123", PhoneNumberAe::NATIONAL)    # => "(201) 555-0123"
PhoneNumberAe.format("US", "2015550123", PhoneNumberAe::E164)        # => "+12015550123"
PhoneNumberAe.format("US", "2015550123", PhoneNumberAe::INTERNATIONAL) # => "+1 201-555-0123"
PhoneNumberAe.format("US", "2015550123", PhoneNumberAe::RFC3966)     # => "tel:+1-201-555-0123"
PhoneNumberAe.number_type("US", "2015550123")                        # => TYPE_FIXED_LINE
PhoneNumberAe.country_code("JP")                                     # => "81"
```

### Format as you type

```ruby
ayt = PhoneNumberAe::AsYouTypeFormatter.new("US")
last = nil
"2015550123".each_char { |c| last = ayt.input_digit(c) }
last          # => "(201) 555-0123"
ayt.clear     # reset
```

### Find numbers in free text

```ruby
matches = PhoneNumberAe.find_numbers("call 201-555-0123 or +1 202 555 0199", "US")
matches.size          # => 2
matches[0].raw        # => "201-555-0123"
matches[0].start      # => byte offset of the match
matches[0].end        # => byte offset just past it
```

### Short and emergency numbers

```ruby
PhoneNumberAe::ShortNumber.is_emergency_number("US", "911")  # => true
PhoneNumberAe::ShortNumber.is_emergency_number("GB", "999")  # => true
PhoneNumberAe::ShortNumber.is_valid("US", "911")             # => true
PhoneNumberAe::ShortNumber.expected_cost("US", "911")        # => PhoneNumberAe::COST_TOLL_FREE
PhoneNumberAe::ShortNumber.example_number("US")              # => "112"
```

### Time zones

```ruby
PhoneNumberAe::TimeZones.time_zones_for_number("US", "2015550123")  # => ["America/New_York"]
PhoneNumberAe::TimeZones.time_zones_for_number("GB", "2070313000")  # => ["Europe/London"]
PhoneNumberAe::TimeZones.time_zone_count("US", "2015550123")        # => 1
PhoneNumberAe::TimeZones.unknown_time_zone                          # => "Etc/Unknown"
```

A number with no known zone maps to a single-element `["Etc/Unknown"]`.

### Carrier names

```ruby
PhoneNumberAe::Carrier.carrier_name_for_number("GB", "7106000000")        # => "O2"
PhoneNumberAe::Carrier.carrier_name_for_valid_number("GB", "7106000000")  # => "O2" (or "" if invalid)
```

Names are English only; `""` means no carrier is known for the number.

### Geocoding

```ruby
PhoneNumberAe::Geocoder.geo_description_for_number("US", "6502530000")        # => "Mountain View, CA"
PhoneNumberAe::Geocoder.geo_description_for_valid_number("US", "6502530000")  # => "Mountain View, CA" (or "" if invalid)
```

Descriptions are English only; `""` means no description is known for the number.

This gem is a **thin Fiddle binding** over the monorepo's one shared native
engine — `libphonenumber_ae.so`, compiled from pure Aether over Google
libphonenumber's own metadata. It contains **no** phone-number logic —
parsing, validation, number typing and formatting all live in the one shared
engine (`core/phonenumber.ae`). Every method marshals to an `aether_pn_embed_*`
call. That is deliberate: one engine, one set of behaviours, N language surfaces.

## Finding the engine

`PhoneNumberAe::Native.load` looks for the shared library in this order:

1. an explicit path — `PhoneNumberAe::Native.load("/path/to/lib.so")`
2. `$LIBPHONENUMBER_AE_LIB`
3. `native/` bundled next to the gem (`rake stage_native` puts it there)
4. the OS loader's own search path

Lib basenames: linux `libphonenumber_ae.so`, mac `libphonenumber_ae.dylib`,
windows `phonenumber_ae.dll`.

## Surface

Module functions on `PhoneNumberAe`:

```ruby
# metadata
country_code(region)
example_number(region)
example_number_for_type(region, type)
invalid_example_number(region)
possible_lengths(region)
region_code_for_country_code(cc)
is_nanpa_country(region)                         # => true / false
ndd_prefix_for_region(region, strip_non_digits: false)
region_at(index)
regions                                          # => ["US", "GB", …]
regions_for_country_code(cc)                     # => ["US", "CA", …]

# parse -> ParsedNumber (fields: region, country_code, national_number,
#   extension, italian_leading_zero?, source, error, region_code,
#   national_significant_number, length_of_ndc, length_of_area_code,
#   geographical?)
parse(input, region)                             # => PhoneNumberAe::ParsedNumber
national_number(region, input)

# validation
is_possible_number(region, input)                # => true / false
is_possible_number_with_reason(region, input)    # => a VR_* int
is_valid_number(region, input)                   # => true / false
is_valid_number_for_region(input, region)        # => true / false
number_type(region, input)                       # => a TYPE_* int (-1 unknown)
can_be_internationally_dialled(region, input)    # => true / false

# formatting  (style: E164 / INTERNATIONAL / NATIONAL / RFC3966)
format(region, input, style)
format_national(region, input)
format_international(region, input)
format_e164(region, input)
format_rfc3966(region, input)
format_out_of_country(region, input, calling_from)
format_in_original(parsed, calling_from)

# relations / helpers
is_number_match(a, b)                            # => a MATCH_* int
truncate_too_long(region, input)
normalize_digits_only(str)
convert_alpha_characters(str)
is_alpha_number(str)                             # => true / false
abi_version                                      # => 6
```

Short / emergency numbers live in the `PhoneNumberAe::ShortNumber` module
(cost values are `COST_TOLL_FREE` / `COST_STANDARD_RATE` / `COST_PREMIUM_RATE`
/ `COST_UNKNOWN`):

```ruby
PhoneNumberAe::ShortNumber.is_possible(region, input)                # => true / false
PhoneNumberAe::ShortNumber.is_valid(region, input)                   # => true / false
PhoneNumberAe::ShortNumber.is_emergency_number(region, input)        # => true / false
PhoneNumberAe::ShortNumber.connects_to_emergency_number(region, input) # => true / false
PhoneNumberAe::ShortNumber.is_carrier_specific(region, input)        # => true / false
PhoneNumberAe::ShortNumber.is_sms_service(region, input)             # => true / false
PhoneNumberAe::ShortNumber.expected_cost(region, input)              # => a COST_* int
PhoneNumberAe::ShortNumber.example_number(region)                    # => "112"
```

Time zones live in the `PhoneNumberAe::TimeZones` module, carrier names in
`PhoneNumberAe::Carrier`, geographic descriptions in `PhoneNumberAe::Geocoder`:

```ruby
PhoneNumberAe::TimeZones.time_zones_for_number(region, input)        # => ["America/New_York", …]
PhoneNumberAe::TimeZones.time_zone_count(region, input)              # => an Integer (0 = only the unknown zone)
PhoneNumberAe::TimeZones.unknown_time_zone                           # => "Etc/Unknown"
PhoneNumberAe::Carrier.carrier_name_for_number(region, input)        # => a name, or ""
PhoneNumberAe::Carrier.carrier_name_for_valid_number(region, input)  # => a name only if valid, else ""
PhoneNumberAe::Geocoder.geo_description_for_number(region, input)        # => a description, or ""
PhoneNumberAe::Geocoder.geo_description_for_valid_number(region, input)  # => a description only if valid, else ""
```

Classes: `PhoneNumberAe::ParsedNumber`, `PhoneNumberAe::AsYouTypeFormatter`
(`#input_digit`, `#result`, `#clear`), `PhoneNumberAe::Match` (`start`, `end`,
`raw`), and `PhoneNumberAe.find_numbers(text, region, leniency)`.

Constant groups:

- **Format**: `E164` (0), `INTERNATIONAL` (1), `NATIONAL` (2), `RFC3966` (3)
- **NumberType**: `TYPE_UNKNOWN`, `TYPE_FIXED_LINE`, `TYPE_MOBILE`,
  `TYPE_TOLL_FREE`, `TYPE_PREMIUM_RATE`, `TYPE_SHARED_COST`, `TYPE_VOIP`,
  `TYPE_PERSONAL_NUMBER`, `TYPE_PAGER`, `TYPE_UAN`, `TYPE_VOICEMAIL`
- **ValidationResult**: `VR_IS_POSSIBLE`, `VR_IS_POSSIBLE_LOCAL_ONLY`,
  `VR_INVALID_COUNTRY_CODE`, `VR_TOO_SHORT`, `VR_INVALID_LENGTH`, `VR_TOO_LONG`
- **MatchType**: `MATCH_NOT_A_NUMBER`, `MATCH_NO_MATCH`, `MATCH_SHORT_NSN`,
  `MATCH_NSN`, `MATCH_EXACT`
- **CountryCodeSource**: `SRC_FROM_NUMBER_WITH_PLUS`, `SRC_FROM_NUMBER_WITH_IDD`,
  `SRC_FROM_NUMBER_WITHOUT_PLUS`, `SRC_FROM_DEFAULT_COUNTRY`
- **Leniency**: `LENIENCY_POSSIBLE` (0), `LENIENCY_VALID` (1)

## Memory

Every `char*` the engine returns is caller-owned. `Native::Lib#take_string`
copies it into a Ruby String and frees it through `aether_pn_embed_free_string`
in an `ensure` block — leaking that buffer is the single easiest mistake in any
of these bindings, so all string reads go through that one method. A parsed
number and an AsYouType state are themselves caller-owned strings, threaded and
freed the same way.

## Testing

The v6 45-check conformance suite (`docs/conformance.md`) lives in
`spec/conformance_spec.rb`.

```sh
LIBPHONENUMBER_AE_LIB=/path/to/libphonenumber_ae.so rspec
```

Or via aeb, which builds the engine first and points the loader at it:

```sh
aeb ruby/.tests.ae
```

`rspec` is often a `--user-install` gem; `.tests.ae` prepends `Gem.user_dir/bin`
to `PATH` and invokes `ruby -S rspec` so no extra setup is needed.
