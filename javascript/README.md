# phonenumber_ae — JavaScript / Node

A thin Node binding over the shared, pure-Aether libphonenumber engine. All the
phone logic lives in the one engine (`core/phonenumber.ae`); this binding is just
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

Build the npm tarball (from the repo root), then install it — the engine `.so`
is bundled inside, so nothing else is needed at runtime:

```sh
aeb core/.build.ae && aeb javascript/.dist.ae   # -> target/dist/phonenumber_ae-*.tgz
npm install target/dist/phonenumber_ae-*.tgz
```

The tarball is current-OS-only (it bundles this platform's `.so`). The loader
finds the engine in this order: an explicit
`require('phonenumber_ae/lib/native').load(path)`, `$LIBPHONENUMBER_AE_LIB`, the
`native/` dir the tarball ships, then the OS loader's search path — so an
installed package needs no configuration. `koffi` is a runtime dependency, pulled
in with the package.

## Develop / test

From the repo, `aeb` builds the engine and runs the suite against the source
tree:

```sh
aeb javascript/.tests.ae      # the 47-check conformance suite
```
