# phonenumber_ae — JavaScript / Node

A thin Node binding over the shared, pure-Aether libphonenumber core. All the
phone logic lives in the one core (`core/phonenumber.ae`); this binding is just
[koffi](https://koffi.dev) FFI marshalling over `libphonenumber_ae.so`. See the
[repo README](../README.md) for the whole picture.

## Use it

```js
const pn = require('phonenumber_ae');

pn.isValidNumber('US', '+1 201 555 0123');       // true
pn.isPossibleNumber('GB', '1212345678');         // true
pn.format('US', '2015550123', pn.NATIONAL);      // '(201) 555-0123'
pn.format('US', '2015550123', pn.E164);          // '+12015550123'
pn.numberType('US', '2015550123');               // pn.TYPE_FIXED_LINE
pn.countryCode('JP');                            // '81'

// side-libraries
pn.Carrier.carrierNameForNumber('GB', '7106000000');       // 'O2'
pn.Geocoder.geoDescriptionForNumber('US', '6502530000');   // 'Mountain View, CA'
```

## Install it in your project

Build the npm tarball (from the repo root), then install it — the core `.so`
is bundled inside, so nothing else is needed at runtime:

```sh
aeb core/.build.ae && aeb javascript/.dist.ae   # -> target/dist/phonenumber_ae-*.tgz
npm install target/dist/phonenumber_ae-*.tgz
```

Building only this binding? Skip compiling the core — fetch the prebuilt one from
a [release](https://github.com/aether-lang-dev/libphonenumber-ae/releases) with
`--overrideDep`, which relabels the package's core dependency to the fetch node:

```sh
# (a) grab the prebuilt core from the release (nothing to compile):
aeb javascript/.dist.ae \
    --overrideDep core/.build.ae=core/.getFromGitHub.ae

# (b) build the core from source instead:
aeb core/.build.ae && aeb javascript/.dist.ae
```

Same package either way — the core bytes are identical. See
[`docs/Prebuilt-Core-Packaging.md`](../docs/Prebuilt-Core-Packaging.md) for the
`--overrideDep` fetch-node flow.

The tarball is current-OS-only (it bundles this platform's `.so`). The loader
finds the core in this order: an explicit
`require('phonenumber_ae/lib/native').load(path)`, `$LIBPHONENUMBER_AE_LIB`, the
`native/` dir the tarball ships, then the OS loader's search path — so an
installed package needs no configuration. `koffi` is a runtime dependency, pulled
in with the package.

## Develop / test

From the repo, `aeb` builds the core and runs the suite against the source
tree:

```sh
aeb javascript/.tests.ae      # the 47-check conformance suite
```
