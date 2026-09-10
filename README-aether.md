# libphonenumber, in Aether — one engine, many thin bindings

Parse, validate and format international phone numbers, across many languages —
**one engine, many thin bindings, one build**.

This is an [Aether](https://github.com/aether-lang-dev/aether) port of the phone
logic in Google's [libphonenumber](https://github.com/google/libphonenumber)
(this repository's own upstream). Unlike libphonenumber's per-language ports
(each a separate reimplementation), here there is exactly **one** engine — a
pure-Aether module in [`core/`](core/) — built once as a native shared library
(`libphonenumber_ae.so`), and every language binding is a thin FFI wrapper over
that single artifact. Identical behaviour across languages is a build-time
guarantee, not a test target.

```python
import phonenumber_ae as pn

pn.is_valid_number("US", "+1 201 555 0123")   # True
pn.format("US", "2015550123", pn.NATIONAL)    # "(201) 555-0123"
pn.number_type("US", "2015550123")            # pn.TYPE_FIXED_LINE
pn.country_code("JP")                         # "81"
```

## Why one engine

libphonenumber's authority is one big metadata file
([`resources/PhoneNumberMetadata.xml`](resources/PhoneNumberMetadata.xml), ~250
territories). Every serious port compiles that metadata once into generated
code rather than parsing XML at runtime — and so do we. But where Google ships a
*separate engine per language* (Java, C++, JS, and community ports for the
rest), a per-language engine means per-language drift: a validation quirk fixed
in one is still present in the others until each is re-fixed.

Here there is one metadata table, one length checker, one national-number regex
matcher, one formatter. Fix a rule once and every binding has the fix the moment
it rebuilds.

## What it does

Full core `PhoneNumberUtil` parity — the same functional surface as Google's
own library:

- **`parse`** — real parsing: strips `+`/IDD/national-trunk prefixes (via the
  metadata's own regexes and transform rules), extracts extensions, records the
  `CountryCodeSource`. Yields a parsed number you read fields off.
- **`is_possible_number`** (with a `ValidationResult` reason) and
  **`is_valid_number`** / **`is_valid_number_for_region`** — the length check and
  the full national-number-regex check.
- **`number_type`** (fixed line / mobile / toll-free / …) and region detection
  (**`region_code_for_number`**, cc→region lists).
- The full **formatter** set — NATIONAL / INTERNATIONAL / E.164 / RFC3966, plus
  out-of-country and original-format — with correct `leadingDigits` routing.
- **`is_number_match`**, `truncate_too_long`, alpha-number conversion, NDC/area-
  code lengths, and more.
- An **`AsYouTypeFormatter`** (formats as digits are typed) and a
  **`find_numbers`** matcher (extracts numbers from free text).

Plus the full **side-libraries**: **ShortNumberInfo** (emergency/short codes),
**TimeZones**, **Carrier** and **Geocoder** (English). See
[`docs/abi.md`](docs/abi.md) for the full 66-symbol surface and
[`docs/parity-plan.md`](docs/parity-plan.md) for the fidelity status — 26/26 of
the sampled `PhoneNumberUtilTest` cases match Google's production output exactly.

Every functional component of the distribution is ported: PhoneNumberUtil,
ShortNumberInfo, TimeZones, Carrier, and Geocoder — one engine, ~20 bindings.

## How it's built

```
resources/PhoneNumberMetadata.xml     Google's metadata (this repo's upstream)
          │  core/gen/generate.ae  (offline: std.xml pull parser)
          ▼
core/metadata.ae                      GENERATED table — 254 territories,
                                      lengths + per-type national-number regexes
core/phonenumber.ae                   the engine (pure Aether + std.regex/PCRE2)
core/embed.ae + _embed_support.c      the flat aether_pn_embed_* C ABI
          │  ae build --emit=lib
          ▼
libphonenumber_ae.so                  the one artifact every binding loads
```

Regenerate the table when the metadata changes:

```
ae run core/gen/generate.ae > core/metadata.ae
```

## Layout

```
core/                the engine, the generator, the C ABI
core_tests/          two gates: probe.ae (engine) + abi_smoke.c (ABI over dlopen)
docs/                abi.md (the contract) + conformance.md (the 18 checks)
<language>/          one thin binding each, with its own README + .tests.ae
.presubmit.ae        the aggregate target set (everything green before a push)
bootstrap.sh         one-command dev setup (installs ae+aeb, builds what it can)
ci/versions.env      pinned toolchain versions
```

## Building and testing

```
./bootstrap.sh                 # install ae+aeb, build engine + every present binding
aeb core/.build.ae             # just the engine -> the .so
aeb core_tests/.abi.ae         # the C ABI gate
aeb python/.tests.ae           # one binding's suite
aeb .presubmit.ae              # everything
```

aeb's own exit status does not always reflect a leaf's PASS/FAIL — read
`target/.aeb/logs/<label>.log` for each node's verdict. A binding whose
toolchain is absent **skips loudly** and returns success, so a partial toolchain
set still gives a meaningful run; check for `SKIPPED` lines.

## Composable builds — pay only for what you use

The side-libraries bake large data tables into the `.so` (the geocoder blob
alone is ~7 MB). Validation is the base; each side-library is an additive
build-time opt-in. A **validation-only** build is ~320 KB; the **full** build is
~8 MB. Compose any subset with `core/gen/assemble_embed.sh` — see
[`docs/composable-builds.md`](docs/composable-builds.md).

- `aeb core/.build.ae` — the full library (default).
- `aeb core/validation.build.ae` — validation only.
- `core/gen/assemble_embed.sh core/embed_geo.ae geo` then build — any subset.

## Scope and known gaps

- Whole-distribution functional parity: PhoneNumberUtil (byte-exact vs Google's
  own test suite), ShortNumberInfo, TimeZones, Carrier, Geocoder.
- Carrier and geocoder carry the English (`en/`) name slice only; the other ~34
  language dirs can be added the same way (a generator repeat).
- Formatting honors `leadingDigits` routing; getNumberType matches upstream
  (incl. FIXED_LINE_OR_MOBILE). See [`docs/parity-plan.md`](docs/parity-plan.md).

## Credits and licence

The metadata, the possible-length and national-number rules, the number-type
taxonomy and the formats are all libphonenumber's — see
[`core/gen/PhoneNumberMetadata.xml.PROVENANCE`](core/gen/PhoneNumberMetadata.xml.PROVENANCE).
libphonenumber is Apache-2.0 (© The Libphonenumber Authors), and so is this
port; the repository's [`LICENSE`](LICENSE) is Apache-2.0.
