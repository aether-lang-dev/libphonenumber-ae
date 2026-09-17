# phonenumber_ae — Dart

A thin Dart binding over the shared, pure-Aether libphonenumber core. All the
phone logic lives in the one core (`core/phonenumber.ae`); this binding is just
`dart:ffi` marshalling over `libphonenumber_ae.so` (ABI v7, 66 exports). See the
[repo README](../README.md) for the whole picture.

## Use it

```dart
import 'package:phonenumber_ae/phonenumber_ae.dart' as pn;

pn.isValidNumber('US', '+1 201 555 0123');                   // true
pn.isPossibleNumber('GB', '1212345678');                     // true
pn.format('US', '2015550123', pn.PhoneFormat.national);      // '(201) 555-0123'
pn.format('US', '2015550123', pn.PhoneFormat.e164);          // '+12015550123'
pn.numberType('US', '2015550123');                           // PhoneNumberType.fixedLine
pn.countryCode('JP');                                        // '81'

// side-libraries
pn.Carrier.carrierNameForNumber('GB', '7106000000');         // 'O2'
pn.Geocoder.geoDescriptionForNumber('US', '6502530000');     // 'Mountain View, CA'
```

## Install it in your project

Build the tarball (from the repo root), then unpack it — the core `.so` is
vendored at `native/` inside, so nothing else is needed at runtime:

```sh
aeb core/.build.ae && aeb dart/.dist.ae   # -> target/dist/phonenumber-ae-dart.tar.gz
tar xzf target/dist/phonenumber-ae-dart.tar.gz   # -> phonenumber-ae-dart/
```

Add it as a path dependency in your `pubspec.yaml`
(`phonenumber_ae: {path: ../phonenumber-ae-dart}`) and `dart pub get`. The tarball
is current-OS-only (it vendors this platform's `.so`). The loader finds the core
in this order: an explicit `Api.open(path)`, `$LIBPHONENUMBER_AE_LIB`, the package's
own `native/` dir, then the OS loader's search path — so an unpacked tarball needs
no configuration.

## Develop / test

From the repo, `aeb` builds the core and runs the suite against the source
tree:

```sh
aeb dart/.tests.ae      # the 47-check conformance suite
```
