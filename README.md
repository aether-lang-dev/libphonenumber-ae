# libphonenumber, in Aether

Parse, validate and format international phone numbers — **one core, many thin
bindings, one build**.

Google's [libphonenumber](https://github.com/google/libphonenumber) ships a
separate reimplementation per language. This is an
[Aether](https://github.com/aether-lang-dev/aether) port with exactly **one**
core — a pure-Aether module in [`core/`](core/), compiled once to a native
shared library (`libphonenumber_ae.so`) from Google's own metadata — and a thin
FFI binding per language over that single artifact. Fix a rule once and every
language has the fix. Identical behaviour is a build-time guarantee, not a test
target.

```python
import phonenumber_ae as pn
pn.is_valid_number("US", "+1 201 555 0123")   # True
pn.format("US", "2015550123", pn.NATIONAL)    # "(201) 555-0123"
pn.number_type("US", "2015550123")            # pn.TYPE_FIXED_LINE
```

## Quick start — use a binding (no Aether toolchain)

A binding needs only the core shared library, and it comes bundled — **no clone,
no aeb, no Aether**. Two no-toolchain paths, by what you're writing:

**An HLL binding (Python, Ruby, Go, …).** Install the self-contained package for
your language: the core library is bundled *inside* it, so there's nothing to
download and no `LIBPHONENUMBER_AE_LIB` to set. See the
[binding's own README](#bindings) for the one install line in that language (each
`<lang>/.dist.ae` builds that package, with the core already in it).

**An Aether program.** Add the released core as an `ae add` dependency — `ae`
fetches the prebuilt core for your platform from the
[release](https://github.com/aether-lang-dev/libphonenumber-ae/releases), verifies
its checksum, and installs it; you `import phonenumber_ae` and call its ABI. No
`.so` to place, no build:

```sh
ae add github.com/aether-lang-dev/libphonenumber-ae@<tag>
```

```aether
import phonenumber_ae
phonenumber_ae.pn_embed_is_valid_number("US", "2015550123")   // 1
```

(Cross-platform bundling: `ae add … --target <os>-<arch>` fetches a foreign
platform's core. Requires `ae` ≥ 0.696.)

## Build from source (contributors, or an unreleased platform)

**1. Install the build tool** ([`aeb`](https://github.com/aether-lang-dev/aeb)),
which also installs the Aether compiler it needs. One line, into `~/.local`, no
sudo — pinned to the versions this repo is tested on
([`ci/versions.env`](ci/versions.env)):

```sh
curl -fsSL https://raw.githubusercontent.com/aether-lang-dev/aeb/main/get.sh \
  | AE_PIN=0.706.0 AEB_REF=v0.324 sh
```

`get.sh` is also a sourceable library — a CI step can source it (with
`AEBGET_SOURCE_ONLY=1` so sourcing only *defines* the functions) then drive it:

```bash
AEBGET_SOURCE_ONLY=1 . <(curl -fsSL https://raw.githubusercontent.com/aether-lang-dev/aeb/main/get.sh)
AE_PIN=0.706.0 AEB_REF=v0.324 aeb_bootstrap
```

**2. Build the core, then your language's binding** (each needs only that
language's toolchain):

```sh
aeb core/.build.ae        # the core -> libphonenumber_ae.so
aeb python/.dist.ae       # your binding's distributable -> target/dist/
```

Swap `python` for `ruby`, `go`, `rust`, `java`, … (see the table). `.dist.ae`
produces a self-contained package with the core library bundled inside; `.tests.ae`
runs that binding's conformance suite instead. To cross-build and publish the
core library for every platform, see [`release/`](release/).

## Bindings

Twenty languages drive the byte-identical `libphonenumber_ae.so`. Pick yours:

| Language | FFI | Artifact | Docs |
|---|---|---|---|
| Python | ctypes | wheel | [python/](python/) |
| Ruby | Fiddle | gem | [ruby/](ruby/) |
| JavaScript (Node) | koffi | npm tarball | [javascript/](javascript/) |
| Java | Panama FFM | fat jar | [java/](java/) |
| Kotlin · Clojure · Groovy | JVM (over the Java jar) | jar | [kotlin/](kotlin/) · [clojure/](clojure/) · [groovy/](groovy/) |
| Go | cgo | module tarball | [go/](go/) |
| Rust | `extern "C"` | crate | [rust/](rust/) |
| Dart | `dart:ffi` | tarball | [dart/](dart/) |
| Nim · Zig · Lua | link-time / C ext | tarball | [nim/](nim/) · [zig/](zig/) · [lua/](lua/) |
| Erlang · Elixir · Gleam | one BEAM NIF | tarball / hex | [erlang/](erlang/) · [elixir/](elixir/) · [gleam/](gleam/) |
| Pharo | FFI | tarball | [pharo/](pharo/) |
| .NET (C#) · PHP · Haskell | P/Invoke · FFI · ccall | nupkg · tarball · sdist | [dotnet/](dotnet/) · [php/](php/) · [haskell/](haskell/) |

The Java/Kotlin/Clojure/Groovy bindings share one Panama FFM jar; Erlang/Elixir/
Gleam share one BEAM NIF — so one core reaches twenty languages over a handful
of FFI mechanisms.

## What it covers

Whole-distribution parity with libphonenumber, byte-exact against Google's own
`PhoneNumberUtilTest`:

- **Core** `PhoneNumberUtil` — parse, region detection, `isPossible`/`isValid`
  with reasons, `getNumberType`, every format style
  (E164/national/international/RFC3966), `isNumberMatch`, AsYouTypeFormatter,
  PhoneNumberMatcher.
- **Side-libraries** — ShortNumberInfo, TimeZones, Carrier, Geocoder (English
  name slice; other languages add the same way).

The C ABI is version 7 (66 exports) and **composable**: a validation-only build
is ~320 KB, the full build ~8 MB — see
[`docs/composable-builds.md`](docs/composable-builds.md). Every binding runs the
same [47-check conformance suite](docs/conformance.md).

## How it's built

`resources/PhoneNumberMetadata.xml` (Google's metadata, vendored — see
[`resources/PROVENANCE.md`](resources/PROVENANCE.md)) is compiled at build time
into generated tables, then into the core and the C ABI:

```
resources/  ──► core/gen/*  ──► core/*metadata*.ae ──► core/phonenumber.ae
(pristine)      (offline)       (BUILD ARTIFACTS,        + core/embed.ae + C ABI
                                 gitignored, never          │ ae build --emit=lib
                                 committed)                  ▼
                                                     libphonenumber_ae.so
```

The build regenerates the tables from `resources/`, so a fresh checkout carries
no generated `.ae`. Refresh `resources/` from a new Google release with
[`./sync-google-resources.sh`](sync-google-resources.sh) (a content copy from the
mirror branch, never a git merge).

## Repo map

```
core/                the phone-number core, generators, C ABI, embed fragments
core_tests/          core + ABI gates (probe, abi, parity, roundtrip, …, dist)
<language>/          one thin binding each — its README, .tests.ae, .dist.ae
resources/           Google's vendored metadata (the only thing from upstream)
docs/                abi.md · conformance.md · composable-builds.md · parity-plan.md
ci/versions.env      pinned aeb + ae versions — the single place to bump
bootstrap.sh         installs the pinned toolchain + builds every present binding
.presubmit.ae        every gate + binding, green before a push
.dist.ae             builds every binding's distributable into target/dist/
```

`aeb`'s exit status doesn't always reflect a leaf's verdict — read
`target/.aeb/logs/<label>.log`. A binding whose toolchain is absent **skips
loudly** and still returns success, so a partial toolchain set still gives a
meaningful run (look for `SKIPPED`).

## Credits

The metadata, the possible-length and national-number rules, the number-type
taxonomy and the formats are all libphonenumber's — see
[`resources/PROVENANCE.md`](resources/PROVENANCE.md). libphonenumber is Apache-2.0
(© The Libphonenumber Authors), and so is this port ([`LICENSE`](LICENSE)).

Siblings that share this one-core-many-bindings layout:
[`aether`](https://github.com/aether-lang-dev/aether) (the language),
[`aeb`](https://github.com/aether-lang-dev/aeb) (the build runner), `selenium`,
`servirtium-vcr`, `html-sanitizer`.
