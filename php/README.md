# phonenumber_ae — PHP

A thin PHP binding over the shared, pure-Aether libphonenumber engine. All the
phone logic lives in the one engine (`core/phonenumber.ae`); this binding is just
ext-ffi marshalling over `libphonenumber_ae.so`. See the
[repo README](../README.md) for the whole picture.

## Use it

```php
use PhoneNumberAe\PhoneNumber;
use PhoneNumberAe\Carrier;
use PhoneNumberAe\Geocoder;

PhoneNumber::isValidNumber('US', '+1 201 555 0123');            // true
PhoneNumber::isPossibleNumber('GB', '1212345678');             // true
PhoneNumber::format('US', '2015550123', PhoneNumber::NATIONAL); // '(201) 555-0123'
PhoneNumber::format('US', '2015550123', PhoneNumber::E164);     // '+12015550123'
PhoneNumber::numberType('US', '2015550123');                   // 0 (TYPE_FIXED_LINE)
PhoneNumber::countryCode('JP');                                // '81'

$num = PhoneNumber::parse('+1 650 253 0000', 'US');
$num->nationalNumber();   // '6502530000'
$num->regionCode();       // 'US'

// side-libraries
Carrier::carrierNameForNumber('GB', '7106000000');       // 'O2'
Geocoder::geoDescriptionForNumber('US', '6502530000');   // 'Mountain View, CA'
```

## Install it in your project

Build the Composer package tarball (from the repo root), then require it — the
engine `.so` is vendored under `native/`, so nothing else is needed at runtime:

```sh
aeb core/.build.ae && aeb php/.dist.ae   # -> target/dist/phonenumber-ae-php.tar.gz
composer require libphonenumber-ae/phonenumber --dev \
    --repository '{"type":"artifact","url":"target/dist"}'
```

The tarball is current-OS-only (it vendors this platform's `.so`). The loader
finds the engine in this order: an explicit `PhoneNumberAe\Native::load($path)`,
`$LIBPHONENUMBER_AE_LIB`, the package's own `native/`, then the OS loader's
search path — so an installed package needs no configuration.
`PhoneNumber::nativeLibraryPath()` reports which candidate loaded. Requires
**PHP 8.1+** with **ext-ffi** enabled (`php -d ffi.enable=1`, or `ffi.enable=1`
in `php.ini`).

## Develop / test

From the repo, `aeb` builds the engine and runs the suite against the source
tree:

```sh
aeb php/.tests.ae      # the 47-check conformance suite
```
