# PhoneNumber.Aether — .NET

A thin .NET binding over the shared, pure-Aether libphonenumber core. All the
phone logic lives in the one core (`core/phonenumber.ae`); this binding is just
P/Invoke marshalling over `libphonenumber_ae.so`. See the
[repo README](../README.md) for the whole picture.

## Use it

```csharp
using PhoneNumbers;

PhoneNumber.IsValidNumber("US", "+1 201 555 0123");           // true
PhoneNumber.IsPossibleNumber("GB", "1212345678");             // true
PhoneNumber.Format("US", "2015550123", FormatStyle.National); // "(201) 555-0123"
PhoneNumber.Format("US", "2015550123", FormatStyle.E164);     // "+12015550123"
PhoneNumber.NumberType("US", "2015550123");                   // PhoneNumberType.FixedLine
PhoneNumber.CountryCode("JP");                                // "81"

var num = PhoneNumber.Parse("+1 650 253 0000", "US");
num.NationalNumber;   // "6502530000"
num.RegionCode;       // "US"

// side-libraries
PhoneNumber.CarrierNameForNumber("GB", "7106000000");         // "O2"
PhoneNumber.GeoDescriptionForNumber("US", "6502530000");      // "Mountain View, CA"
```

## Install it in your project

Build the NuGet package (from the repo root), then add it — the core `.so` is
bundled inside as a native asset, so nothing else is needed at runtime:

```sh
aeb core/.build.ae && aeb dotnet/.dist.ae   # -> target/dist/PhoneNumber.Aether.*.nupkg
dotnet add package PhoneNumber.Aether --source target/dist
```

Building only this binding? Skip compiling the core — fetch the prebuilt one from
a [release](https://github.com/aether-lang-dev/libphonenumber-ae/releases) with
`--overrideDep`, which relabels the NuGet package's core dependency to the fetch node:

```sh
# (a) grab the prebuilt core from the release (nothing to compile):
aeb dotnet/.dist.ae \
    --overrideDep core/.build.ae=core/.getFromGitHubReleases.ae

# (b) build the core from source instead:
aeb core/.build.ae && aeb dotnet/.dist.ae
```

Same NuGet package either way — the core bytes are identical. See
[`docs/Prebuilt-Core-Packaging.md`](../docs/Prebuilt-Core-Packaging.md) for the
`--overrideDep` fetch-node flow.

The package is current-OS-only (it bundles this platform's `.so`). The loader
finds the core in this order: an explicit
`PhoneNumber.UseNativeLibrary(path)`, `$LIBPHONENUMBER_AE_LIB`, the `native/`
dir next to the assembly, then the OS loader's own probing — so an installed
package needs no configuration. `PhoneNumber.NativeLibraryPath` reports which
candidate loaded.

## Develop / test

From the repo, `aeb` builds the core and runs the suite against the source
tree:

```sh
aeb dotnet/.tests.ae      # the 47-check conformance suite
```
