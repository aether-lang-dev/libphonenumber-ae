# Orientation for an LLM working on libphonenumber-ae (the Aether port)

Short, opinionated, for a future LLM picking up mid-task. The code is the source
of truth; this is the map so your *first* attempt lands clean. Read
`../aether/LLM.md` first (the language; its "Idioms that keep biting" section)
and `../html-sanitizer/LLM.md` (the sibling this repo's layout copies).

## What this is, in one paragraph

This repository is a fork of Google's **libphonenumber**. Its `master` branch is
upstream Google (Java/C++/JS + the metadata under `resources/`). The Aether port
lives on branch **feat/aether-port** as a one-engine-many-thin-bindings monorepo
(same shape as `../html-sanitizer` and `../servirtium-vcr`): one pure-Aether
phone-number engine, compiled once to `libphonenumber_ae.so`, with ~20 thin FFI
bindings over its flat C ABI. Built by **aeb**. The port's front-door doc is
`README-aether.md` (Google's own `README.md` is left untouched).

## Why it exists

Paul and Nic wanted a set of language bindings whose common factor is one Aether
`.so/.dylib/.dll`, faithfully using Google's own metadata
(`resources/PhoneNumberMetadata.xml`) — NOT Google's per-language reimplemented
engines. Seeded from the earlier phone work in
`../datastar-aether/harness/components/phone/` (which did only isPossibleNumber
for ~10 curated countries). End consumer: the datastar-aether credit-card
checkout demo.

## The pipeline (offline generate → engine → ABI → bindings)

```
resources/PhoneNumberMetadata.xml   Google's metadata (already in-tree; upstream)
        │  core/gen/generate.ae     std.xml pull parser, run OFFLINE:
        │                             ae run core/gen/generate.ae > core/metadata.ae
        ▼
core/metadata.ae     GENERATED, 254 territories. Rows are US-separated (0x1F)
                     fields; the formats field packs all display formats
                     0x1E-separated. Per-type fields are national-number regexes.
core/phonenumber.ae  the engine: is_possible_number, is_valid_number (per-type
                     regex, std.regex/PCRE2), number_type, format_*.
core/embed.ae        the flat aether_pn_embed_* C ABI (scalar-only).
core/_embed_support.c  ONE C helper: pn_raw_dup/pn_raw_free (caller-owned
                     strings). NO callbacks, NO trampolines — this ABI has none.
```

## The one structural rule

**Bindings carry no phone logic.** A binding declares the 12 `aether_pn_embed_*`
symbols, marshals strings/ints, and copies-then-frees every returned `char*`.
Anything smarter — a length check, a regex, a format decision — belongs in
`core/`. Duplicating it in a binding is the drift this layout exists to prevent.

## The C ABI (docs/abi.md is the full contract)

12 symbols, all scalar (`const char*` / `int`), append-only, ABI version 1.
No handle, no state, no callbacks — every call is an independent
`(region, input) -> answer`. Every returned `char*` is caller-owned; free it
with `aether_pn_embed_free_string`. `core_tests/abi_smoke.c` is the complete C
consumer; `docs/conformance.md` lists the 18 checks every binding runs.

## Traps that actually cost time here (all still live)

- **`\\\\` inside an interpolated Aether string collapses to ONE backslash.**
  Building escaped output with `"${out}\\..."` silently drops backslash-doubling,
  so every `\d` in a generated regex loses its backslash, reads back as a literal
  `d`, and every `isValidNumber` match fails. The generator's `esc()` builds
  output with `string.concat` + `string.from_char(92)` (an unambiguous literal
  backslash) for exactly this reason. Do not "simplify" it back to interpolation.
- **Dup a list element BEFORE `list.free`.** `list.free` releases the strings the
  list owns; a value read out and used after the free dangles (it returned
  garbage 6-byte strings from `region_at`). `pn_raw_dup` the bytes into a
  host-owned C string first, then free the list. See `pn_embed_region_at`.
- **`import` must be top-level**, never inside a function body (it's a reserved
  keyword there). Cost one confusing "reserved keyword" error in a scratch test.
- **Format templates keep their spaces; patterns don't.** The generator
  `squeeze()`s national-number *patterns* (they span indented XML lines) but only
  `trim()`s *format templates* (`($1) $2-$3` — the interior space is significant).
- **aeb's exit status is unreliable** re: a leaf's PASS/FAIL. Read
  `target/.aeb/logs/<label>.log` for the actual verdict. Never run two top-level
  `aeb` invocations concurrently (they clobber `target/`).

## Metadata row format (core/metadata.ae)

One row per territory, fields separated by **0x1F**, in this order:
`id | cc | natLengths | example | fmtPatterns | fmtTemplates | general | fixedLine
| mobile | tollFree | premiumRate | sharedCost | voip | personalNumber | pager |
uan | voicemail`. `fmtPatterns`/`fmtTemplates` each hold ALL formats, **0x1E**-
separated and positionally aligned. Per-type fields are national-number regexes
(the engine anchors them `^(?:...)$` for a full match) or "" if the territory
omits that type. Field indices live as `F_*` consts in `core/phonenumber.ae`.

## Build / test

```
./bootstrap.sh              install ae+aeb, build engine + every present binding
aeb core/.build.ae          just the engine -> target/build/core/lib/libphonenumber_ae.so
aeb core_tests/.tests.ae    engine behaviour (pure Aether)
aeb core_tests/.abi.ae      C ABI over dlopen (the gate the bindings trust)
aeb <lang>/.tests.ae        one binding
aeb .presubmit.ae           everything
```

Each binding's `.tests.ae` deps `core/.build.ae`, resolves the `shared_lib`
artifact, and points **LIBPHONENUMBER_AE_LIB** at it. A binding whose toolchain
is absent skips loudly and returns success.

## Regenerating metadata

`ae run core/gen/generate.ae > core/metadata.ae`. Needs no fetch — the whole XML
is already in `resources/`. Extending the generator to carry carrier/geocoding
data or leadingDigits routing is the natural next step and needs no new input.

## Upstream siblings

`../aether` (the language), `../aeb` (the build runner), `../html-sanitizer` and
`../servirtium-vcr` (the one-engine-many-bindings layout this copies),
`../datastar-aether` (the seed and the eventual consumer — its
`harness/components/phone/` was the ~10-country starting point).
