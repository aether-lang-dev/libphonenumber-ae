# Packaging a binding with the prebuilt core (`--overrideDep`)

Every binding's distributable — a wheel, gem, crate, jar, tarball — bundles the
core shared library *inside* it, so an installed package runs with no external
`.so` and no `LIBPHONENUMBER_AE_LIB`. That core normally comes from
`core/.build.ae`, which **compiles it from Aether source**. But a binding
developer building only *their* language's package doesn't need to build the
core at all — a prebuilt one is published on every
[release](https://github.com/aether-lang-dev/libphonenumber-ae/releases).

`aeb`'s `--overrideDep` relabels the core dependency to a **fetch node**, so the
package is built around the *downloaded* core instead of a compiled one:

```sh
# (a) grab the prebuilt core from the release (nothing to compile):
aeb <lang>/.dist.ae \
    --overrideDep core/.build.ae=core/.getFromGitHubReleases.ae

# (b) build the core from source instead:
aeb <lang>/.dist.ae
```

Same package either way — the core bytes are identical (the release asset *is*
the `core/.build.ae` output for that platform). The Java binding uses
`java/.jar.ae` in place of `<lang>/.dist.ae`; everything else is `<lang>/.dist.ae`.

## The fetch node

[`core/.getFromGitHubReleases.ae`](../core/.getFromGitHubReleases.ae) is a pure-Aether build node
(no shell-out): it resolves the release asset for this host
(`libphonenumber_ae-<tag>-<os>-<arch>.<ext>`), **downloads** it over
`std.http.client`, **verifies** it against the published `.sha256`, **caches** it
under `$XDG_CACHE_HOME/libphonenumber-ae/<tag>/`, and stages it — publishing the
same `shared_lib` artifact edge `core/.build.ae` does. So a binding's dist node,
which reads `dep_artifact("core/.build.ae", "shared_lib")`, transparently gets
the fetched core when the dep is overridden. No core source is compiled.

- **Tag.** The node fetches the tag in the repo-root
  [`VERSION`](../VERSION) file — the single source of truth the release also
  stamps into its asset names, so fetched and published can't drift. A release
  for that tag must exist (the node fails loudly otherwise).
- **Platform.** The asset is named for the running host
  (`os.platform()`/`os.arch()`), so you get your own platform's core. A package
  bundling a foreign platform's core is a cross-build concern, out of scope here.
- **Requires** `aeb` ≥ v0.314 (the `--overrideDep` node-substitution flag).

## When to use which

- **Build the core from source** (b) when you're working *on* the core, on an
  unreleased commit, or on a platform no release covers.
- **Fetch the prebuilt core** (a) when you only want to cut your language's
  package and don't want the core's build toolchain in the loop — CI for a
  single binding, a registry-publish step, a contributor who only touches the
  binding.

## Not to be confused with

- **`ae add …@<tag>`** — for an **Aether program** that *consumes* the core (it
  installs the prebuilt core into the `ae` package cache and you
  `import phonenumber_ae`). That's a consumer path, not a package-build path.
- **The bundled published package** — an end user of a binding just installs the
  wheel/gem/… with the core already inside; they never run aeb at all.
