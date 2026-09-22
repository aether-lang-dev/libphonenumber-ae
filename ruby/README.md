# phonenumber_ae — Ruby

A thin Ruby binding over the shared, pure-Aether libphonenumber core. All the
phone logic lives in the one core (`core/phonenumber.ae`); this binding is just
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

Build the gem (from the repo root), then install it — the core `.so` is
vendored inside, so nothing else is needed at runtime:

```sh
aeb core/.build.ae && aeb ruby/.dist.ae   # -> target/dist/phonenumber_ae-*.gem
gem install target/dist/phonenumber_ae-*.gem
```

Building only this binding? Skip compiling the core — fetch the prebuilt one from
a [release](https://github.com/aether-lang-dev/libphonenumber-ae/releases) with
`--overrideDep`, which relabels the gem's core dependency to the fetch node:

```sh
# (a) grab the prebuilt core from the release (nothing to compile):
aeb ruby/.dist.ae \
    --overrideDep core/.build.ae=core/.getFromGitHub.ae

# (b) build the core from source instead:
aeb core/.build.ae && aeb ruby/.dist.ae
```

Same gem either way — the core bytes are identical. See
[`docs/Prebuilt-Core-Packaging.md`](../docs/Prebuilt-Core-Packaging.md) for the
`--overrideDep` fetch-node flow.

The gem is current-OS-only (it bundles this platform's `.so`).
`PhoneNumberAe::Native.load` finds the core in this order: an explicit
`PhoneNumberAe::Native.load(path)`, `$LIBPHONENUMBER_AE_LIB`, the `native/` dir
bundled in the gem, then the OS loader's search path — so an installed gem needs
no configuration.

## Develop / test

From the repo, `aeb` builds the core and runs the suite against the source
tree:

```sh
aeb ruby/.tests.ae      # the 47-check conformance suite
```
