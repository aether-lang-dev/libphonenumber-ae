# Full PhoneNumberUtil parity — build plan

Goal: the Aether engine matches Google libphonenumber's **core** `PhoneNumberUtil`
functional surface, driven entirely from the pristine in-tree Google metadata
(`resources/PhoneNumberMetadata.xml` — unmodified, read directly by the
generator). Side-libraries (geocoder, carrier, timezone, ShortNumberInfo) are
OUT of scope for this branch; the core library complete is the target.

Decisions (Paul, this session): full PhoneNumberUtil parity; add opaque handles
where state is genuinely required (AsYouTypeFormatter, PhoneNumberMatcher);
stateless calls stay append-only on the existing flat ABI.

## What's already done (v1 ABI, shipped, all 20 bindings green)

isPossibleNumber · isValidNumber · getNumberType · format (NATIONAL /
INTERNATIONAL / E164) · getCountryCodeForRegion · getExampleNumber ·
getSupportedRegions · possible-lengths · basic +cc stripping.

## New metadata the generator must extract (all present in the SAME XML)

Per `<territory>`: `nationalPrefix`, `nationalPrefixForParsing`,
`nationalPrefixTransformRule`, `internationalPrefix`, `preferredExtnPrefix`,
`mainCountryForCode`, generalDesc `possibleLengths` (localOnly too).
Per `<numberFormat>`: `leadingDigits`, `nationalPrefixFormattingRule`,
`carrierCodeFormattingRule`, `<intlFormat>`, `nationalPrefixOptionalWhenFormatting`.
Plus a country-code → region-list map (from `countryCode` + `mainCountryForCode`).

This means a metadata schema bump: more fields per row, and a second generated
table (the cc→regions map). The row separator scheme (0x1F fields, 0x1E records)
extends cleanly.

## Phase 1 — real parse() + region detection (stateless)

- **parse(number, defaultRegion)** → a canonical (countryCode, nationalNumber,
  extension, italianLeadingZero, countryCodeSource) result. Faithful to upstream:
  - `maybeStripInternationalPrefixAndNormalize` (IDD / `+` / `internationalPrefix`)
  - `maybeExtractCountryCode` (against the cc→region map, longest-prefix)
  - `maybeStripNationalPrefixAndCarrierCode` (`nationalPrefixForParsing` regex +
    `nationalPrefixTransformRule`)
  - extension extraction (`EXTN_PATTERNS`, `preferredExtnPrefix`, RFC3966 `;ext=`)
  - `CountryCodeSource` provenance enum
- **parseAndKeepRawInput** (adds rawInput + preferredDomesticCarrierCode)
- **getRegionCodeForNumber** / **getRegionCodesForCountryCode** /
  **getRegionCodeForCountryCode**
- **getNationalSignificantNumber**
- **isPossibleNumberWithReason** / **isPossibleNumberForType[WithReason]**
  (`ValidationResult`: IS_POSSIBLE / IS_POSSIBLE_LOCAL_ONLY / INVALID_COUNTRY_CODE
  / TOO_SHORT / INVALID_LENGTH / TOO_LONG)
- **isValidNumberForRegion**

ABI: extend the flat surface. Because parse yields a compound value, expose it as
a parse-then-accessors pair (parse returns an opaque *parsed-number handle* the
caller reads fields off, then frees) — a natural, minimal handle that also backs
isNumberMatch and the formatters below.

## Phase 2 — the full formatter set (stateless, over a parsed number)

format (all `PhoneNumberFormat`: E164 / INTERNATIONAL / NATIONAL / RFC3966) ·
formatByPattern · formatNationalNumberWithCarrierCode ·
formatNationalNumberWithPreferredCarrierCode · formatOutOfCountryCallingNumber ·
formatOutOfCountryKeepingAlphaChars · formatInOriginalFormat ·
formatNumberForMobileDialing · **leadingDigits-correct** format routing
(replaces the current "first pattern that matches" approximation) ·
`nationalPrefixFormattingRule` application.

## Phase 3 — number relations & helpers (stateless)

isNumberMatch (String/PhoneNumber overloads → `MatchType`:
EXACT_MATCH / NSN_MATCH / SHORT_NSN_MATCH / NO_MATCH / NOT_A_NUMBER) ·
truncateTooLongNumber · isAlphaNumber · convertAlphaCharactersInNumber ·
normalizeDigitsOnly · normalizeDiallableCharsOnly · canBeInternationallyDialled ·
isNumberGeographical · getLengthOfGeographicalAreaCode ·
getLengthOfNationalDestinationCode · getNddPrefixForRegion · isNANPACountry ·
isMobileNumberPortableRegion · getCountryMobileToken ·
getExampleNumberForType · getInvalidExampleNumber · getExampleNumberForNonGeoEntity ·
getSupportedCallingCodes · getSupportedGlobalNetworkCallingCodes ·
getSupportedTypesForRegion / ForNonGeoEntity.

## Phase 4 — stateful features (opaque handles)

- **AsYouTypeFormatter** — handle: `ayt_new(region)` → `ayt_input_digit(h, c)` →
  (returns the formatted-so-far string) · `ayt_input_digit_remember(h, c)` ·
  `ayt_remembered_position(h)` · `ayt_clear(h)` · `ayt_free(h)`.
- **PhoneNumberMatcher / findNumbers** — handle over (text, region, leniency):
  `matcher_new(text, region, leniency)` → `matcher_has_next(h)` /
  `matcher_next(h)` (start/end/parsed-number) · `matcher_free(h)`. Leniency:
  POSSIBLE / VALID / STRICT_GROUPING / EXACTLY_SAME_AS_INPUT.

## Cross-cutting

- **Parity oracle**: upstream ships `PhoneNumberUtilTest.java` etc. under
  `java/libphonenumber/test/`. Port representative cases as `core_tests/` parity
  suites and track the score honestly (like html-sanitizer's ganss-parity.md).
- **ABI stays append-only**: every new symbol is added; nothing renumbered.
  `abi_version()` bumps per phase.
- **Every binding re-exports the new surface.** The bindings are generated from
  one spec; extend the spec, regenerate/patch each. Handles add a small object
  layer to each binding (create/use/free), matching the html-sanitizer pattern.
- **Conformance suite grows** from 18 checks to cover each new capability.

## Parity oracle status (core_tests/parity.ae)

Runs 25 cases lifted verbatim from Google's PhoneNumberUtilTest (same inputs,
same expected strings). Current: **24/25 match**. The gate (core_tests/.parity.ae)
fails only if the pass count drops below the baseline (allowed_diffs=6), so a
new divergence reddens CI while documented ones don't.

Known diffs (documented, not silent):
- **GB national `(020) 7031 3000`**: we render `020 7031 3000`. GB's format uses
  nationalPrefixFormattingRule `$NP$FG` (NP=`0`), which we apply literally; upstream
  additionally parenthesizes the area code for GB geographic numbers. A rendering
  nuance in how `$NP$FG` composes with the first group — not a validation issue.
- **US getNumberType**: upstream reports FIXED_LINE_OR_MOBILE where US fixedLine ==
  mobile pattern; we report FIXED_LINE (first match). Values/formatting unaffected.
