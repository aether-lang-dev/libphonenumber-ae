# phonenumber_ae — Pharo

A thin Pharo binding over the shared, pure-Aether libphonenumber core. All the
phone logic lives in the one core (`core/phonenumber.ae`); this binding is just
UnifiedFFI marshalling over `libphonenumber_ae.so`. Pharo is not a JVM, so it binds
the flat C ABI directly — no Java classpath, only the core `.so`. See the
[repo README](../README.md) for the whole picture.

## Use it

Every call is class-side — the core is stateless, so there is no handle to open
or close:

```smalltalk
PhonenumberAe isValidNumber: '+1 201 555 0123' region: 'US'.   "-> true"
PhonenumberAe isPossibleNumber: '1212345678' region: 'GB'.     "-> true"
PhonenumberAe format: '2015550123' region: 'US' style: #national. "-> '(201) 555-0123'"
PhonenumberAe formatE164: '2015550123' region: 'US'.           "-> '+12015550123'"
PhonenumberAe numberType: '2015550123' region: 'US'.           "-> #fixedLine"
PhonenumberAe countryCode: 'JP'.                               "-> '81'"

"side-libraries"
PhonenumberAe carrierNameForNumber: '7106000000' region: 'GB'.    "-> 'O2'"
PhonenumberAe geoDescriptionForNumber: '6502530000' region: 'US'. "-> 'Mountain View, CA'"
```

`PhonenumberAe abiVersion` returns `7`.

## Install it in your project

Build the source package (from the repo root), then unpack it and load the Tonel
sources into your image via the Metacello baseline:

```sh
aeb core/.build.ae && aeb pharo/.dist.ae   # -> target/dist/phonenumber-ae-pharo.tar.gz
tar -xzf target/dist/phonenumber-ae-pharo.tar.gz
```

```smalltalk
Metacello new
    baseline: 'PhonenumberAe';
    repository: 'tonel://<unpacked-dir>/src';
    load.
```

The core `.so` is vendored under the package's `native/` (current-OS-only). Point
the binding at it before the first FFI call — set `$LIBPHONENUMBER_AE_LIB`, or
`PhonenumberAeLibrary explicitPath: '/path/to/libphonenumber_ae.so'`; the loader
also checks `native/` beside the image, then the OS loader's search path.

## Develop / test

```sh
aeb pharo/.tests.ae      # the 47-check conformance suite
```
