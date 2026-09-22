# phonenumber — Go

A thin Go binding over the shared, pure-Aether libphonenumber core. All the
phone logic lives in the one core (`core/phonenumber.ae`); this binding is just
cgo marshalling over `libphonenumber_ae.so`. See the
[repo README](../README.md) for the whole picture.

## Use it

Once the module is in your tree (see *Install* — it is **not** `go get`-able,
because cgo must link the Aether-built core `.so`, which `go get` cannot
produce):

```go
import pn "github.com/aether-lang-dev/libphonenumber-ae/go"

pn.IsValidNumber("US", "+1 201 555 0123")    // true
pn.IsPossibleNumber("GB", "1212345678")      // true
pn.Format("US", "2015550123", pn.NATIONAL)   // "(201) 555-0123"
pn.Format("US", "2015550123", pn.E164)       // "+12015550123"
pn.NumberType("US", "2015550123")            // pn.TypeFixedLine
pn.CountryCode("JP")                         // "81"

// side-libraries
pn.CarrierNameForNumber("GB", "7106000000")       // "O2"
pn.GeoDescriptionForNumber("US", "6502530000")    // "Mountain View, CA"
```

## Install it in your project

cgo **links** the core, so it must be present at build time. Build the module
tarball (from the repo root) — the core `.so` is vendored inside at `native/`,
the path the `#cgo LDFLAGS -L/-rpath` already reference:

```sh
aeb core/.build.ae && aeb go/.dist.ae   # -> target/dist/phonenumber-ae-go.tar.gz
tar xzf target/dist/phonenumber-ae-go.tar.gz   # unpack into your module tree, then `go build`
```

Building only this binding? Skip compiling the core — fetch the prebuilt one from
a [release](https://github.com/aether-lang-dev/libphonenumber-ae/releases) with
`--overrideDep`, which relabels the module's core dependency to the fetch node:

```sh
# (a) grab the prebuilt core from the release (nothing to compile):
aeb go/.dist.ae \
    --overrideDep core/.build.ae=core/.getFromGitHub.ae

# (b) build the core from source instead:
aeb core/.build.ae && aeb go/.dist.ae
```

Same module either way — the core bytes are identical. See
[`docs/Prebuilt-Core-Packaging.md`](../docs/Prebuilt-Core-Packaging.md) for the
`--overrideDep` fetch-node flow.

The tarball is current-OS-only (it vendors this platform's `.so`); with the
bundled `native/libphonenumber_ae.so`, the baked-in rpath resolves the core at
run time without the monorepo layout around it.

## Develop / test

From the repo, `aeb` builds the core, stages it into `go/native`, and runs
`go test`:

```sh
aeb go/.tests.ae      # the 47-check conformance suite
```
