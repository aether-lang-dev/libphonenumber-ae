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

See [`docs/abi.md`](docs/abi.md) for the full 50-symbol surface and
[`docs/parity-plan.md`](docs/parity-plan.md) for the fidelity status against
Google's own test suite (24/25 of the sampled `PhoneNumberUtilTest` cases match
exactly; two documented rendering approximations).

Out of scope for this branch: the separate side-libraries (geocoder, carrier
mapper, timezone mapper, short-number info). Their metadata is already in-tree,
so they can be added later without a new fetch.

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

## Scope and known gaps

- Full core `PhoneNumberUtil` parity (parse, validation-with-reasons, region
  detection, all format styles, matching, AsYouType). Formatting now honors
  `leadingDigits` routing.
- Two documented rendering approximations (a parenthesized GB area code; US
  reported as FIXED_LINE rather than FIXED_LINE_OR_MOBILE) — see
  [`docs/parity-plan.md`](docs/parity-plan.md). Neither affects validation.
- The geocoder / carrier / timezone / short-number side-libraries are not built
  on this branch (their metadata is in-tree for a later pass).

## Credits and licence

The metadata, the possible-length and national-number rules, the number-type
taxonomy and the formats are all libphonenumber's — see
[`core/gen/PhoneNumberMetadata.xml.PROVENANCE`](core/gen/PhoneNumberMetadata.xml.PROVENANCE).
libphonenumber is Apache-2.0 (© The Libphonenumber Authors), and so is this
port; the repository's [`LICENSE`](LICENSE) is Apache-2.0.
