# phonenumber_ae — Ruby

A thin Ruby binding over the shared, pure-Aether libphonenumber engine. All the
phone logic lives in the one engine (`core/phonenumber.ae`); this binding is just
Fiddle marshalling over `libphonenumber_ae.so`. See the
[repo README](../README.md) for the whole picture.

## Use it

```ruby
require "phonenumber_ae"

PhoneNumberAe.is_valid_number("US", "+1 201 555 0123")             # => true
PhoneNumberAe.is_possible_number("GB", "1212345678")              # => true
PhoneNumberAe.format("US", "2015550123", PhoneNumberAe::NATIONAL) # => "(201) 555-0123"
PhoneNumberAe.format("US", "2015550123", PhoneNumberAe::E164)     # => "+12015550123"
PhoneNumberAe.number_type("US", "2015550123")                    # => TYPE_FIXED_LINE
PhoneNumberAe.country_code("JP")                                 # => "81"

# side-libraries
PhoneNumberAe::Carrier.carrier_name_for_number("GB", "7106000000")    # => "O2"
PhoneNumberAe::Geocoder.geo_description_for_number("US", "6502530000") # => "Mountain View, CA"
```

## Install it in your project

Build the gem (from the repo root), then install it — the engine `.so` is
vendored inside, so nothing else is needed at runtime:

```sh
aeb core/.build.ae && aeb ruby/.dist.ae   # -> target/dist/phonenumber_ae-*.gem
gem install target/dist/phonenumber_ae-*.gem
```

The gem is current-OS-only (it bundles this platform's `.so`).
`PhoneNumberAe::Native.load` finds the engine in this order: an explicit
`PhoneNumberAe::Native.load(path)`, `$LIBPHONENUMBER_AE_LIB`, the `native/` dir
bundled in the gem, then the OS loader's search path — so an installed gem needs
no configuration.

## Develop / test

From the repo, `aeb` builds the engine and runs the suite against the source
tree:

```sh
aeb ruby/.tests.ae      # the 47-check conformance suite
```
