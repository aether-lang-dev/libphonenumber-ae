# phonenumber_ae — Zig

A thin Zig binding over the shared, pure-Aether libphonenumber core. All the
phone logic lives in the one core (`core/phonenumber.ae`); this binding is just
FFI marshalling over `libphonenumber_ae.so` (ABI v7, 66 exports). See the
[repo README](../README.md) for the whole picture. Requires Zig 0.16.0 or newer.

## Use it

Every string result is caller-owned; free it with the allocator you passed in.

```zig
const pn = @import("phonenumber_ae");

const valid = try pn.isValidNumber(allocator, "US", "+1 201 555 0123");  // true

const nat = try pn.format(allocator, "US", "2015550123", .national);     // "(201) 555-0123"
defer allocator.free(nat);
const e164 = try pn.format(allocator, "US", "2015550123", .e164);        // "+12015550123"
defer allocator.free(e164);

const cc = try pn.countryCode(allocator, "JP");                          // "81"
defer allocator.free(cc);

// side-libraries
const carrier = try pn.carrierNameForNumber(allocator, "GB", "7106000000");    // "O2"
defer allocator.free(carrier);
const geo = try pn.geoDescriptionForNumber(allocator, "US", "6502530000");     // "Mountain View, CA"
defer allocator.free(geo);
```

## Install it in your project

Build the tarball (from the repo root), then unpack it — the core `.so` is
vendored at `native/` inside, so nothing else is needed at build or run time:

```sh
aeb core/.build.ae && aeb zig/.dist.ae   # -> target/dist/phonenumber-ae-zig.tar.gz
tar xzf target/dist/phonenumber-ae-zig.tar.gz   # -> build.zig, build.zig.zon, src/, native/
```

Building only this binding? Skip compiling the core — fetch the prebuilt one from
a [release](https://github.com/aether-lang-dev/libphonenumber-ae/releases) with
`--overrideDep`, which relabels the package's core dependency to the fetch node:

```sh
# (a) grab the prebuilt core from the release (nothing to compile):
aeb zig/.dist.ae \
    --overrideDep core/.build.ae=core/.getFromGitHubReleases.ae

# (b) build the core from source instead:
aeb core/.build.ae && aeb zig/.dist.ae
```

Same package either way — the core bytes are identical. See
[`docs/Prebuilt-Core-Packaging.md`](../docs/Prebuilt-Core-Packaging.md) for the
`--overrideDep` fetch-node flow.

Reference it as a dependency in your `build.zig.zon`, then in `build.zig`:

```zig
const dep = b.dependency("phonenumber_ae", .{});
exe.root_module.addImport("phonenumber_ae", dep.module("phonenumber_ae"));
// A Zig module carries source, not link flags — link the vendored core:
exe.linkLibC();
exe.addLibraryPath(.{ .cwd_relative = "native" });
exe.addRPath(.{ .cwd_relative = "native" });
exe.linkSystemLibrary("phonenumber_ae");
```

`build.zig` also honours `-Dengine=<path>` and `$LIBPHONENUMBER_AE_LIB`. The
tarball is current-OS-only (it vendors this platform's `.so`).

## Develop / test

From the repo, `aeb` builds the core, stages it, and runs the suite:

```sh
aeb zig/.tests.ae      # the 47-check conformance suite
```
