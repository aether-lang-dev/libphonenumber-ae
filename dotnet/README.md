# PhoneNumber (.NET)

Validate, parse and format international phone numbers.

This package is a **thin P/Invoke binding** over the monorepo's one shared
native engine — `core/native/libphonenumber_ae.so`, compiled from pure Aether
over Google libphonenumber's own metadata. It contains **no phone-number
logic**: every member marshals to an `aether_pn_embed_*` call. One engine, one
set of behaviours, N language surfaces. This is the **v3 ABI** (58 symbols, full
`PhoneNumberUtil` parity plus the `ShortNumberInfo` side-library).

| File | Role |
|---|---|
| `src/Native.cs` | the P/Invoke surface — the **only** place that knows the ABI |
| `src/PhoneNumber.cs` | the idiomatic C# API over it |
| `test/Conformance.cs` | the 40-check conformance suite, as a console runner |

Targets **net8.0**, with **zero NuGet dependencies** — which is also what lets
it build and test on a box with no network.

## Building

The engine is `dlopen`ed at run time, so nothing links against it — just build
it first:

```sh
aeb core/.build.ae
cd dotnet && dotnet build
```

Library resolution, in order:

1. an explicit path — `PhoneNumber.UseNativeLibrary("/path/to/libphonenumber_ae.so")`
2. `$LIBPHONENUMBER_AE_LIB` (what the in-tree `.tests.ae` leaf sets)
3. `native/` next to the assembly, then the assembly's own directory
4. `native/`, `../core/native/` and `../../core/native/` relative to the cwd
5. the OS loader's own probing (the runtime's default behaviour)

Implemented with `NativeLibrary.SetDllImportResolver`, so it applies to every
`DllImport` in the assembly at once. `PhoneNumber.NativeLibraryPath` reports
which candidate actually loaded.

## Usage

The stateless calls are static; the two stateful shapes the ABI grows — a
parsed number and an AsYouType formatter — are small objects whose state is the
caller-owned string the engine handed back.

```csharp
using PhoneNumbers;

// parse into a ParsedNumber, then read its fields
var num = PhoneNumber.Parse("+1 650 253 0000", "US");
num.NationalNumber;    // "6502530000"
num.CountryCode;       // "1"
num.RegionCode;        // "US"

PhoneNumber.IsValidNumber("US", "+1 201 555 0123");            // true
PhoneNumber.Format("US", "2015550123", FormatStyle.International); // "+1 201-555-0123"
PhoneNumber.NumberType("US", "2015550123");                   // PhoneNumberType.FixedLine

// format a number as it is typed
var ayt = new AsYouTypeFormatter("US");
string shown = "";
foreach (var c in "6502530000") shown = ayt.InputDigit(c);    // "(650) 253-0000"

// find numbers in free text
foreach (var m in PhoneNumber.FindNumbers("call 201-555-0123 today", "US"))
    Console.WriteLine($"{m.Raw} [{m.Start}..{m.End}]");

// short / emergency numbers (dialled as-is: raw short number + region)
PhoneNumber.IsEmergencyNumber("US", "911");                 // true
PhoneNumber.IsEmergencyNumber("GB", "999");                 // true
PhoneNumber.ShortIsValid("US", "911");                      // true
PhoneNumber.ShortExpectedCost("US", "911");                 // ShortNumberCost.TollFree
PhoneNumber.ShortExampleNumber("US");                       // "112"
```

The surface:

```csharp
// metadata
PhoneNumber.CountryCode(region)                 // string
PhoneNumber.ExampleNumber(region)               // string
PhoneNumber.ExampleNumberForType(region, type)  // string
PhoneNumber.InvalidExampleNumber(region)        // string
PhoneNumber.PossibleLengths(region)             // string
PhoneNumber.RegionCodeForCountryCode(cc)        // "44" -> "GB"
PhoneNumber.IsNanpaCountry(region)              // bool
PhoneNumber.NddPrefixForRegion(region, strip)   // string
PhoneNumber.RegionCount / RegionAt(i) / Regions() / SortedRegions()
PhoneNumber.RegionsForCountryCode(cc)           // "1" -> [US, CA, …]

// parse
PhoneNumber.Parse(input, region)                // ParsedNumber
PhoneNumber.NationalNumber(region, input)       // string
//   ParsedNumber: Region, CountryCode, NationalNumber, Extension,
//   ItalianLeadingZero, Source, Error, RegionCode,
//   NationalSignificantNumber, LengthOfNdc, LengthOfAreaCode, IsGeographical

// validation
PhoneNumber.IsPossibleNumber(region, input)             // bool
PhoneNumber.IsPossibleNumberWithReason(region, input)   // ValidationResult
PhoneNumber.IsValidNumber(region, input)                // bool
PhoneNumber.IsValidNumberForRegion(input, region)       // bool
PhoneNumber.NumberType(region, input)                   // PhoneNumberType
PhoneNumber.CanBeInternationallyDialled(region, input)  // bool

// formatting
PhoneNumber.Format(region, input, style)        // style defaults to National
PhoneNumber.FormatNational / FormatInternational / FormatE164 / FormatRfc3966
PhoneNumber.FormatOutOfCountry(region, input, callingFrom)
PhoneNumber.FormatInOriginal(parsed, callingFrom)

// relations / helpers
PhoneNumber.IsNumberMatch(a, b)                 // MatchType
PhoneNumber.TruncateTooLong(region, input)      // string
PhoneNumber.NormalizeDigitsOnly(s)              // string
PhoneNumber.ConvertAlphaCharacters(s)           // string
PhoneNumber.IsAlphaNumber(s)                    // bool

// stateful helpers
new AsYouTypeFormatter(region)                  // InputDigit(ch) / Result() / Clear()
PhoneNumber.FindNumbers(text, region, leniency) // IReadOnlyList<PhoneNumberMatch>

// short numbers (ShortNumberInfo)
PhoneNumber.ShortIsPossible(region, input)      // bool
PhoneNumber.ShortIsValid(region, input)         // bool
PhoneNumber.IsEmergencyNumber(region, input)    // bool
PhoneNumber.ConnectsToEmergencyNumber(region, input)  // bool
PhoneNumber.ShortIsCarrierSpecific(region, input)     // bool
PhoneNumber.ShortIsSmsService(region, input)          // bool
PhoneNumber.ShortExpectedCost(region, input)    // ShortNumberCost
PhoneNumber.ShortExampleNumber(region)          // string

PhoneNumber.AbiVersion                          // 3
```

### Constants

`FormatStyle` is `E164 | International | National | Rfc3966` — note the ABI
renumbering: **`E164` is now `0`** (it was `2` under the v1 ABI),
`International` is `1`, `National` is `2`, `Rfc3966` is `3`. The other constant
groups are enums with the ABI's exact values: `PhoneNumberType`
(`Unknown` = -1, …), `ValidationResult`, `MatchType`, `CountryCodeSource`
(`ParsedNumber.Source`), `Leniency` (`Possible` = 0, `Valid` = 1) and
`ShortNumberCost` (`TollFree` = 0, `StandardRate` = 1, `PremiumRate` = 2,
`Unknown` = 3).

## Marshalling notes

Three decisions in `Native.cs` are load-bearing, and each corresponds to a real
bug avoided:

- **String returns are `IntPtr`, never `string`.** With a `string` return the
  default marshaller copies the buffer *and then frees it with
  `Marshal.FreeCoTaskMem`* — the wrong allocator for a `malloc`'d C string,
  which corrupts the heap. `Native.TakeString` copies with
  `Marshal.PtrToStringUTF8` and frees through `aether_pn_embed_free_string` in a
  `finally`. Every string result in the assembly goes through it — including the
  parsed-number and AsYouType-state strings, which are themselves just
  caller-owned strings, not opaque handles.
- **String arguments are `byte[]`, not `string`.** `DllImport`'s default
  `string` marshalling is ANSI on some platforms, which mangles non-ASCII input.
  The binding encodes UTF-8 itself in `Native.Encode`.
- **The number-type/count results are `int`, not `long`/`nint`.** The ABI is C
  `int` throughout; declaring `long` gets a 4-vs-8-byte mismatch on LP64. Every
  `DllImport` is also explicitly
  `[CallingConvention.Cdecl]`, since the platform default differs on 32-bit
  Windows.

Because this ABI has **no callbacks and no opaque handles**, the .NET-interop
hazards a callback-carrying binding faces (`UnmanagedFunctionPointer` delegates,
a keepalive list, `GetFunctionPointerForDelegate`) do not arise here.

## Tests

The 40-check conformance suite (`docs/conformance.md`) lives in
`test/Conformance.cs`, alongside a few surface extras and a 5,000-iteration loop
over the caller-owned-string contract (now exercising the parse accessors too).

### Why a console runner and not xunit/NUnit

Every .NET test framework arrives as a NuGet package, so `dotnet test` cannot
run without a restore — a network round trip, or a pre-warmed package cache,
before a single assertion executes. The rest of this monorepo's bindings test
with whatever is already on the box, so this one does too: `dotnet run` on a
self-contained runner, **no packages, no restore**, and the process exit code is
the result.

```sh
aeb dotnet/.tests.ae     # builds the engine, then runs the suite
# or, with the engine already built:
LIBPHONENUMBER_AE_LIB=../target/build/core/lib/libphonenumber_ae.so \
    dotnet run --project test/PhoneNumber.Tests.csproj
```

`.tests.ae` skips (exit 0, with a clear `dotnet: SKIPPED` line) when no `dotnet`
is on `PATH`, or when the `dotnet` present is runtime-only with no SDK — rather
than failing the build DAG for a missing toolchain.

> **Status on this checkout:** the .NET SDK is **not installed** on the
> development box these bindings were written on, so the C# has been reviewed but
> not compiled or executed here. `aeb dotnet/.tests.ae` reports
> `dotnet: SKIPPED` and exits 0. The engine ABI it targets is proven by the Nim,
> Zig and Lua bindings that do run against the same `.so`.
