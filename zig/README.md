# phonenumber_ae (Zig)

Validate, parse and format international phone numbers.

This package is a **thin Zig binding** over the monorepo's one shared native
engine — `core/native/libphonenumber_ae.so`, compiled from pure Aether over
Google libphonenumber's own metadata. It contains **no phone-number logic**:
every function marshals to an `aether_pn_embed_*` call across the flat C ABI
described in `core/embed.ae`. One engine, one set of behaviours, N language
surfaces.

Speaks **ABI v2** (`abiVersion()` → 2): the full `PhoneNumberUtil` surface —
parse, validation with reasons, all four format styles, an
AsYouTypeFormatter, and a matcher that finds numbers in free text. The ABI is
scalar-only (`const char*` and `int`); there is no handle and no callbacks. Two
v2 constructs thread a *string* rather than an opaque handle: a parsed number
and the AsYouType state are each a caller-owned string you get back and free.

> **Format styles were renumbered in v2.** `e164` is now **`0`** (it was `2`);
> the styles are `.e164 = 0`, `.international = 1`, `.national = 2`,
> `.rfc3966 = 3`. Use the `Format` enum and this is a non-issue.

Requires **Zig 0.16.0** or newer.

## Building

Like Go's cgo binding (and unlike the dlopen-based Python/ctypes and
Rust/libloading ones), this binding **links** the engine, so the shared library
must exist at *build* time as well as run time. Build it first:

```sh
aeb core/.build.ae
# → target/build/core/lib/libphonenumber_ae.so
```

Then:

```sh
zig build test        # the 34-check v2 conformance suite
zig build example     # build and run the demo
```

`build.zig` looks for the engine in this order, first hit wins:

1. `-Dengine=<path>` — what `.tests.ae` passes, using the artifact path `aeb`
   published for `core/.build.ae`
2. `$LIBPHONENUMBER_AE_LIB` — the same env var every other binding honours
3. `zig/native/` — a staged local copy, for a distributable build
4. `../core/native/` — the in-tree monorepo layout

Either a directory **or** a full path to the `.so` is accepted for 1 and 2.
Each candidate directory is added as **both** `-L` and `rpath`. The rpath is
not optional: without it the binary links cleanly and then dies inside the
dynamic loader.

### Using it from another project

```zig
// build.zig
const dep = b.dependency("phonenumber_ae", .{});
exe.root_module.addImport("phonenumber_ae", dep.module("phonenumber_ae"));

// A Zig module carries source, not link flags — so YOU must link the engine:
exe.linkLibC();
exe.addLibraryPath(.{ .cwd_relative = "/path/to/core/native" });
exe.addRPath(.{ .cwd_relative = "/path/to/core/native" });
exe.linkSystemLibrary("phonenumber_ae");
```

## Usage

Every string result is caller-owned; free it with the allocator you passed in.

```zig
const std = @import("std");
const pn = @import("phonenumber_ae");

const cc = try pn.countryCode(allocator, "US");   // "1"
defer allocator.free(cc);

const valid = try pn.isValidNumber(allocator, "US", "+1 201 555 0123"); // true

// Format styles: .e164 (0), .international (1), .national (2), .rfc3966 (3)
const f = try pn.format(allocator, "US", "2015550123", .national);      // "(201) 555-0123"
defer allocator.free(f);
```

### Parsing

`parse` returns a `ParsedNumber` that owns the parsed-number string. Read fields
on demand; `deinit` frees it. Each string accessor returns an owned slice.

```zig
var num = try pn.parse(allocator, "+1 201 555 0123 ext 42", "US");
defer num.deinit();

const nsn = try num.nationalNumber(allocator);   // "2015550123"
defer allocator.free(nsn);
const ext = try num.extension(allocator);        // "42"
defer allocator.free(ext);
const src = try num.source(allocator);           // .from_number_with_plus
const rc  = try num.regionCode(allocator);       // "US"
defer allocator.free(rc);

const err = try num.parseError(allocator);       // "" on success
defer allocator.free(err);
```

### As-you-type formatting

The formatter's state is itself a caller-owned string; `inputDigit` feeds one
character and returns the formatted-so-far string.

```zig
var ayt = try pn.asYouTypeFormatter(allocator, "US");
defer ayt.deinit();

var last: []u8 = try allocator.dupe(u8, "");
defer allocator.free(last);
for ("2015550123") |ch| {
    allocator.free(last);
    last = try ayt.inputDigit(ch);   // ends at "(201) 555-0123"
}
```

### Finding numbers in free text

```zig
const matches = try pn.findNumbers(allocator, "call 201-555-0123 or +1 202 555 0199", "US", .valid);
defer pn.freeMatches(allocator, matches);
for (matches) |m| {
    // m.start, m.end are byte offsets; m.raw is the matched substring (owned)
    std.debug.print("[{d}..{d}) {s}\n", .{ m.start, m.end, m.raw });
}
```

### The surface

```zig
abiVersion() i32

// metadata
countryCode(alloc, region) ![]u8
exampleNumber(alloc, region) ![]u8
exampleNumberForType(alloc, region, NumberType) ![]u8
invalidExampleNumber(alloc, region) ![]u8
possibleLengths(alloc, region) ![]u8
regionCodeForCountryCode(alloc, cc) ![]u8
isNanpaCountry(alloc, region) !bool
nddPrefixForRegion(alloc, region, strip_non_digits) ![]u8
regionCount() usize
regionAt(alloc, index) ![]u8                      // "" when out of range
regions(alloc) ![][]u8                            // caller frees via freeRegions
ccRegionCount(alloc, cc) !usize
ccRegionAt(alloc, cc, index) ![]u8
regionsForCountryCode(alloc, cc) ![][]u8          // caller frees via freeRegions
freeRegions(alloc, list)

// parse
parse(alloc, input, region) !ParsedNumber         // .deinit() when done
nationalNumber(alloc, region, input) ![]u8
// ParsedNumber: region, countryCode, nationalNumber, extension,
//   italianLeadingZero, source, parseError, regionCode,
//   nationalSignificantNumber, lengthOfNdc, lengthOfAreaCode, isGeographical

// validation
isPossibleNumber(alloc, region, input) !bool
isPossibleNumberWithReason(alloc, region, input) !ValidationResult
isValidNumber(alloc, region, input) !bool
isValidNumberForRegion(alloc, input, region) !bool
numberType(alloc, region, input) !NumberType      // .unknown | .fixed_line | …
canBeInternationallyDialled(alloc, region, input) !bool

// formatting
format(alloc, region, input, Format) ![]u8        // .e164 | .international | .national | .rfc3966
formatOutOfCountry(alloc, region, input, calling_from) ![]u8
formatInOriginal(alloc, *ParsedNumber, calling_from) ![]u8

// relations / helpers
isNumberMatch(alloc, a, b) !MatchType
truncateTooLong(alloc, region, input) ![]u8
normalizeDigitsOnly(alloc, s) ![]u8
convertAlphaCharacters(alloc, s) ![]u8
isAlphaNumber(alloc, s) !bool

// as-you-type
asYouTypeFormatter(alloc, region) !AsYouType       // .deinit() when done
// AsYouType: inputDigit(ch), result(), clear()

// matcher / find numbers
matcherCount(alloc, text, region, Leniency) !usize
findNumbers(alloc, text, region, Leniency) ![]Match   // caller frees via freeMatches
freeMatches(alloc, list)
```

The constant groups are exposed as non-exhaustive enums — `Format`,
`NumberType` (`.unknown` at `-1`), `ValidationResult`, `MatchType`,
`CountryCodeSource`, `Leniency` — and also as bare `c_int` aliases
(`E164`/`INTERNATIONAL`/`NATIONAL`/`RFC3966`, `TYPE_*`, `VR_*`, `MATCH_*`,
`SRC_*`, `LENIENCY_*`) for a caller who prefers the wire value.

## Memory and ownership

**Every `char*` the ABI returns is caller-owned.** It came from a plain
`malloc` inside the engine and must go back through
`aether_pn_embed_free_string`. The binding routes *every* returned string
through one helper, `takeString`, which copies into your allocator and frees the
C buffer in a `defer`. There is exactly one `free_string` call site — grep for
it.

The two v2 stateful wrappers own a string too: a `ParsedNumber` owns its
parsed-number string and an `AsYouType` owns its state string; both have
`deinit`. `findNumbers` returns a slice of `Match`, each owning its `raw`
substring — free the lot with `freeMatches`.

Every Zig-side result is therefore yours to free. The conformance suite runs
entirely on `std.testing.allocator`, which fails the test on a leak, so this is
checked by the tests rather than trusted.

An interior NUL in a `region` or `input` is an **error** (`error.InteriorNul`),
not a silent truncation: Zig slices carry NULs happily and C strings do not.

## Conformance

The 34-check v2 suite (`docs/conformance.md`) lives in `src/conformance.zig`,
pulled into `zig build test` by a `test` block at the bottom of `src/root.zig`.
It samples every value shape that crosses the FFI — parse accessors, all four
format styles, the AsYouTypeFormatter, and the matcher — plus a few Zig-specific
extras (out-of-range `regionAt` returning an owned `""`, interior-NUL rejection,
`clear`, and a several-thousand round-trip loop under the leak-checking test
allocator).

```sh
aeb zig/.tests.ae     # builds the engine, stages it, runs zig build test
# or, with the engine already built:
zig build test
zig build test --summary all    # see the count
```
