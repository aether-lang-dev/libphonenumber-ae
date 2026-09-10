# The C ABI (`aether_pn_embed_*`) — v3: PhoneNumberUtil + ShortNumberInfo

The one seam every binding speaks to. Defined by
[`core/embed.ae`](../core/embed.ae) and the string bridge in
[`core/_embed_support.c`](../core/_embed_support.c).
[`core_tests/abi_smoke.c`](../core_tests/abi_smoke.c) is a complete C consumer.

## Ground rules

1. **Every returned `char*` is caller-owned.** Free it with
   `aether_pn_embed_free_string`.
2. **No opaque handles.** A parsed number and an AsYouType state are themselves
   caller-owned *strings*: you get one back, pass it to accessor calls, and free
   it like any other returned string. Every call is independent.
3. **Signatures are scalar-only** — `const char*` and `int`.
4. **Append-only.** ABI version is `3` (`aether_pn_embed_abi_version()`).

`region` is ISO-3166 alpha-2 (case-insensitive). `input` is a raw number a human
might type (digits + spaces/dashes/parens/dots, optional `+cc`, optional
extension `ext`/`x`/`;ext=`, optional vanity letters).

## Constants

**Format style** (`format` arg): `0` E164 · `1` INTERNATIONAL · `2` NATIONAL · `3` RFC3966
**Number type**: `-1` unknown · `0` fixed line · `1` mobile · `2` toll free · `3` premium rate · `4` shared cost · `5` VoIP · `6` personal · `7` pager · `8` UAN · `9` voicemail · `10` fixed-line-or-mobile
**ValidationResult** (`is_possible_number_with_reason`): `0` IS_POSSIBLE · `4` IS_POSSIBLE_LOCAL_ONLY · `1` INVALID_COUNTRY_CODE · `2` TOO_SHORT · `5` INVALID_LENGTH · `3` TOO_LONG
**MatchType** (`is_number_match`): `0` NOT_A_NUMBER · `1` NO_MATCH · `2` SHORT_NSN · `3` NSN · `4` EXACT
**CountryCodeSource** (`pn_source`): `1` FROM_NUMBER_WITH_PLUS · `5` FROM_NUMBER_WITH_IDD · `10` FROM_NUMBER_WITHOUT_PLUS · `20` FROM_DEFAULT_COUNTRY
**Matcher leniency** (`matcher_*`): `0` POSSIBLE · `1` VALID

## Symbols

### Lifecycle / metadata
| Symbol | Signature |
|---|---|
| `abi_version` | `int ()` → 3 |
| `free_string` | `void (char*)` |
| `country_code` | `char* (region)` |
| `example_number` | `char* (region)` |
| `example_number_for_type` | `char* (region, int type)` |
| `invalid_example_number` | `char* (region)` |
| `possible_lengths` | `char* (region)` |
| `region_code_for_country_code` | `char* (cc)` |
| `is_nanpa_country` | `int (region)` |
| `ndd_prefix_for_region` | `char* (region, int strip_non_digits)` |
| `region_count` | `int ()` |
| `region_at` | `char* (int index)` |
| `cc_region_count` | `int (cc)` |
| `cc_region_at` | `char* (cc, int index)` |

### Parse + parsed-number accessors
`parse(input, region)` returns a **caller-owned parsed-number string**. Pass it
to the accessors, then free it.
| Symbol | Signature |
|---|---|
| `parse` | `char* (input, region)` |
| `national_number` | `char* (region, input)` — NSN for a plain input |
| `pn_region` | `char* (pn)` |
| `pn_country_code` | `char* (pn)` |
| `pn_national_number` | `char* (pn)` |
| `pn_extension` | `char* (pn)` |
| `pn_italian_leading_zero` | `int (pn)` |
| `pn_source` | `int (pn)` — a CountryCodeSource |
| `pn_error` | `char* (pn)` — non-empty if parse failed |
| `region_code_for_number` | `char* (pn)` |
| `national_significant_number` | `char* (pn)` |
| `length_of_ndc` | `int (pn)` |
| `length_of_area_code` | `int (pn)` |
| `is_geographical` | `int (pn)` |

### Validation
| Symbol | Signature |
|---|---|
| `is_possible_number` | `int (region, input)` |
| `is_possible_number_with_reason` | `int (region, input)` → ValidationResult |
| `is_valid_number` | `int (region, input)` |
| `is_valid_number_for_region` | `int (input, region)` |
| `number_type` | `int (region, input)` |
| `can_be_internationally_dialled` | `int (region, input)` |

### Formatting
| Symbol | Signature |
|---|---|
| `format` | `char* (region, input, int fmt)` |
| `format_out_of_country` | `char* (region, input, calling_from)` |
| `format_in_original` | `char* (pn, calling_from)` |

### Relations / helpers
| Symbol | Signature |
|---|---|
| `is_number_match` | `int (a, b)` → MatchType |
| `truncate_too_long` | `char* (region, input)` |
| `normalize_digits_only` | `char* (s)` |
| `convert_alpha_characters` | `char* (s)` |
| `is_alpha_number` | `int (s)` |

### AsYouTypeFormatter (state threaded as a caller-owned string)
`ayt_new(region)` → state. `ayt_input(state, ch)` → a NEW state (free the old).
`ayt_result(state)` → the formatted-so-far string. `ayt_clear(state)` → reset.
| Symbol | Signature |
|---|---|
| `ayt_new` | `char* (region)` |
| `ayt_input` | `char* (state, ch)` |
| `ayt_result` | `char* (state)` |
| `ayt_clear` | `char* (state)` |

### PhoneNumberMatcher / findNumbers
| Symbol | Signature |
|---|---|
| `matcher_count` | `int (text, region, leniency)` |
| `matcher_start` | `int (text, region, leniency, idx)` |
| `matcher_end` | `int (text, region, leniency, idx)` |
| `matcher_raw` | `char* (text, region, leniency, idx)` |

### ShortNumberInfo (short / emergency numbers)

Short numbers are dialed as-is (no country code, no national prefix): the input
is the raw short number plus a region. **ShortNumberCost** (`short_expected_cost`):
`0` toll-free · `1` standard rate · `2` premium rate · `3` unknown.

| Symbol | Signature |
|---|---|
| `short_is_possible` | `int (region, input)` |
| `short_is_valid` | `int (region, input)` |
| `short_is_emergency` | `int (region, input)` |
| `short_connects_to_emergency` | `int (region, input)` |
| `short_is_carrier_specific` | `int (region, input)` |
| `short_is_sms_service` | `int (region, input)` |
| `short_expected_cost` | `int (region, input)` → ShortNumberCost |
| `short_example_number` | `char* (region)` |

## Example (C)

```c
char* p = aether_pn_embed_parse("+1 650 253 0000", "US");
char* nn = aether_pn_embed_pn_national_number(p);   /* "6502530000" */
aether_pn_embed_free_string(nn);
aether_pn_embed_free_string(p);

char* intl = aether_pn_embed_format("US", "6502530000", 1);  /* "+1 650-253-0000" */
aether_pn_embed_free_string(intl);
```

## Scope

Full core `PhoneNumberUtil` parity — byte-exact against Google's PRODUCTION
metadata on every sampled `PhoneNumberUtilTest` case (26/26, see
[`parity-plan.md`](parity-plan.md)). Side-libraries (geocoder, carrier,
timezone) are out of scope for this branch; ShortNumberInfo is now included.
