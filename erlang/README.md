# phonenumber_ae — Erlang

A thin Erlang binding over the shared, pure-Aether libphonenumber core. All the
phone logic lives in the one core (`core/phonenumber.ae`); this binding is just
a BEAM NIF marshalling over `libphonenumber_ae.so`. It is also the **canonical
BEAM binding** — Elixir and Gleam load this very same compiled NIF. See the
[repo README](../README.md) for the whole picture.

## Use it

```erlang
phonenumber_ae:is_valid_number(<<"US">>, <<"+1 201 555 0123">>).   %% true
phonenumber_ae:is_possible_number(<<"GB">>, <<"1212345678">>).     %% true
phonenumber_ae:format(<<"US">>, <<"2015550123">>, national).       %% <<"(201) 555-0123">>
phonenumber_ae:format_e164(<<"US">>, <<"2015550123">>).            %% <<"+12015550123">>
phonenumber_ae:number_type(<<"US">>, <<"2015550123">>).            %% fixed_line
phonenumber_ae:country_code(<<"JP">>).                             %% <<"81">>

%% side-libraries
phonenumber_ae:carrier_name_for_number(<<"GB">>, <<"7106000000">>).    %% <<"O2">>
phonenumber_ae:geo_description_for_number(<<"US">>, <<"6502530000">>). %% <<"Mountain View, CA">>
```

String inputs accept iodata (binary, string, or iolist); string results come back
as binaries. `abi_version/0` returns `7`.

## Install it in your project

Build the OTP application tarball (from the repo root), then drop it onto
`ERL_LIBS` — the core `.so` is vendored under `priv/`, so nothing else is needed
at runtime:

```sh
aeb core/.build.ae && aeb erlang/.dist.ae   # -> target/dist/phonenumber-ae-erlang.tar.gz
tar -xzf target/dist/phonenumber-ae-erlang.tar.gz -C /path/to/libs
ERL_LIBS=/path/to/libs erl                  # OTP finds the phonenumber_ae_nif app
```

The tarball is current-OS-only (it bundles this platform's `.so`). The NIF
`dlopen`s the core at load time in this order: `$LIBPHONENUMBER_AE_LIB`, then
`priv/` beside the app, then the OS loader's search path — so an unpacked app needs
no configuration.

## Develop / test

```sh
aeb erlang/.tests.ae      # the 47-check conformance suite
```
