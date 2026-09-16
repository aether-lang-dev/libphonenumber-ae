# phonenumber — Go

A thin Go binding over the shared, pure-Aether libphonenumber engine. All the
phone logic lives in the one engine (`core/phonenumber.ae`); this binding is just
cgo marshalling over `libphonenumber_ae.so`. See the
[repo README](../README.md) for the whole picture.

## Use it

Once the module is in your tree (see *Install* — it is **not** `go get`-able,
because cgo must link the Aether-built engine `.so`, which `go get` cannot
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

cgo **links** the engine, so it must be present at build time. Build the module
tarball (from the repo root) — the engine `.so` is vendored inside at `native/`,
the path the `#cgo LDFLAGS -L/-rpath` already reference:

```sh
aeb core/.build.ae && aeb go/.dist.ae   # -> target/dist/phonenumber-ae-go.tar.gz
tar xzf target/dist/phonenumber-ae-go.tar.gz   # unpack into your module tree, then `go build`
```

The tarball is current-OS-only (it vendors this platform's `.so`); with the
bundled `native/libphonenumber_ae.so`, the baked-in rpath resolves the engine at
run time without the monorepo layout around it.

## Develop / test

From the repo, `aeb` builds the engine, stages it into `go/native`, and runs
`go test`:

```sh
aeb go/.tests.ae      # the 47-check conformance suite
```
