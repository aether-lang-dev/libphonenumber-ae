# resources/ — provenance

These metadata files are vendored verbatim from Google's **libphonenumber**
(<https://github.com/google/libphonenumber>), Apache License 2.0, © The
Libphonenumber Authors. They are the sole authority the Aether engine compiles
against; nothing here is hand-edited.

## What is vendored (and why)

The Aether build consumes exactly these paths — the engine's generators read
them directly (see `core/gen/`), and the generated `.ae` tables are build
artifacts, never committed:

| Path | Feeds |
|---|---|
| `PhoneNumberMetadata.xml` | core parse / validate / format (`generate.ae`) |
| `ShortNumberMetadata.xml` | ShortNumberInfo (`generate_short.ae`) |
| `PhoneNumberAlternateFormats.xml` | matcher grouping leniency (`generate_altformats.ae`) |
| `timezones/map_data.txt` | PhoneNumberToTimeZonesMapper (`generate_tz.ae`) |
| `carrier/<lang>/` | PhoneNumberToCarrierMapper (`generate_carrier.ae`) |
| `geocoding/<lang>/` | PhoneNumberOfflineGeocoder (`generate_geo.ae`) |

Google's own reference sources (Java/JS/C++ ports, `PhoneNumberUtilTest`,
`PhoneNumberMatcher`) are **not** vendored here — this repo is the Aether port,
not a fork of Google's tree. When a parity question needs the reference
implementation, read it from the Google mirror (the `master` branch of the
upstream repo, or a `git worktree` of it), not from here.

## Syncing a new Google release

`resources/` is refreshed from upstream by `sync-google-resources.sh`, which
copies only the paths above from the mirror branch and records which upstream
commit they came from — a plain file copy, never a git merge. After a sync,
`aeb core/.build.ae` regenerates every downstream table.

## Last synced

- Upstream commit: `bdd8406` — "Kkeshava maven update (#4077)"
- Release line: metadata updates for release **9.0.39** (parent pom 9.0.40-SNAPSHOT)
- Synced: 2026-09-10
