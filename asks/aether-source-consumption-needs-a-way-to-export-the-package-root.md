# Aether-source consumers can't `ae add` the engine — the root can't be exported

**From:** the datastar-aether line, 2026-09-18. Against `reboot` @ `edb9716e`,
`ae` 0.681.0, after the `v0.1.0` release.
**Status:** ✅ RESOLVED via fix B. `ae` 0.691.0 (aether #2088) added the
explicit package-root export, spelled `modules = "."` (Paul's choice). Added
`aether.toml` with `modules = "."` (commit aaf8fc70); the `core.` prefix is
kept. Verified end-to-end: an `ae add` consumer resolves `import
core.phonenumber` with no `--lib`, all five nested `core.*` modules resolve, and
it fails without the opt-in. Fix A (drop the prefix) was considered and
declined. Upstream ask
`../aether/asks/modules-cannot-export-the-package-root-for-dotted-package-imports.md`
was actioned by the aether-toolchain session ('a').

## What I was doing

datastar-aether has a small phone component that wants to consume this
engine the **Aether-source way** — `import core.phonenumber`, compiled
in-process, no `.so` and no FFI (that path is for the language bindings).
Our own README already plans it: `validate/` becomes a thin adapter over
`core/phonenumber.ae`, upgrading from isPossibleNumber to isValidNumber.

The engine works. From a checkout with the repo ROOT on the lib path:

```sh
ae run x.ae --lib /home/paul/scm/libphonenumber-ae
# is_valid_number("US","2015550123") -> 1     ✓
```

## The blocker

To be a normal `ae add` dependency, a package declares `[package] modules`
in an `aether.toml`, and `ae` joins the parent directory of each named
module onto the consumer's search path. There is **no `aether.toml`** here
yet — but adding one does not solve it, for a structural reason:

**The engine imports with the `core.` package prefix.** `phonenumber.ae`
does `import core.metadata` / `import core.altformats_metadata`, and
consumers/tests do `import core.phonenumber`. A dotted `core.X` import
resolves only when the **repo ROOT** is on the search path (so `core/` is a
package subdirectory).

But `ae`'s `modules` mechanism can only put **subdirectories** on the path
— you name a module and its *parent* joins — and it deliberately never
joins the package root (`docs/module-system-design.md`: "the package root
is never joined speculatively"). Since there are no `.ae` modules at this
repo's root, **no `modules` entry can put the root on the path**, so no
manifest can make `import core.phonenumber` resolve for a consumer.

Verified every combination:

| lib path | `import core.phonenumber` |
|---|---|
| repo root | ✅ resolves |
| `core/` | ❌ "no module core.phonenumber" |
| `core/` + `import phonenumber` (flat) | ❌ fails on the engine's own internal `import core.metadata` |

The last row is the key one: even if a consumer imported flat, the engine's
*internal* dotted imports still need the root. So the requirement is
"the package root must be on the consumer's search path," full stop.

## Two ways to fix it — your call

**A — the engine drops the `core.` prefix (small, in-repo).**
Change `import core.metadata` → `import metadata` across the ~6 core files
that use it, and consumers do `import phonenumber`. Then a normal manifest
works exactly like selaenium's:

```toml
[package]
name = "libphonenumber-ae"
version = "0.1.0"
modules = "core/phonenumber"   # puts core/ on the path; import phonenumber, metadata, … resolve
```

Files that import `core.*` today: `core/phonenumber.ae` (2),
`core/embed.ae` (5), `core/carrier.ae`, `core/shortnumber.ae`,
`core/timezone.ae`, `core/geocoder.ae` (1 each). Contained.
Cost: the `core.` namespacing is nice for readers; losing it is a real
tradeoff, and it changes every binding/test that imports the engine.

**B — `ae` gains a way to export the package root (general, upstream).**
A `modules` entry that means "put the package root on the path" — e.g.
`modules = "."` or a dedicated key. Dotted package imports (`import
core.phonenumber`) are idiomatic and common; a package organised as
`core/*.ae` off the root currently has no way to be `ae add`-consumed at
all. This is the more general fix and would belong in an ask to `aether`,
not here — but it's this repo that surfaces the need, so noting it.

I lean toward **B being the right long-term fix** (the mechanism gap is
real and will bite any `core/`-organised package), with **A as the
pragmatic unblock** if you'd rather not wait on a toolchain change.

## What this is NOT

Not the FFI path. v0.1.0's release artifacts (the per-platform `.so` /
`.dylib` / `.dll` cores + `get-core.sh`) are for the language bindings that
`dlopen` the engine, and are unaffected by any of this. This ask is only
about the pure-Aether, compile-the-`.ae`-graph consumption path.

## Not asking for urgency

datastar-aether's phone component works today on its own isPossibleNumber
seed. This is the re-linkage that lets it become a thin adapter over the
real engine. It waits happily until you pick A or B.
