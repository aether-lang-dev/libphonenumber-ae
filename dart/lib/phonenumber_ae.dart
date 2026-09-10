/// Validate, parse and format international phone numbers (ABI v6).
///
/// A thin `dart:ffi` binding over the monorepo's one shared native engine
/// (`core/native/libphonenumber_ae.so`, compiled from pure Aether over Google
/// libphonenumber's own metadata). It contains **no phone-number logic**: every
/// member marshals to an `aether_pn_embed_*` call. One engine, one set of
/// behaviours, N language surfaces.
///
/// ```dart
/// import 'package:phonenumber_ae/phonenumber_ae.dart' as pn;
///
/// final num = pn.parse('+1 650 253 0000', 'US');
/// num.nationalNumber;                                     // '6502530000'
/// pn.isValidNumber('US', '+1 201 555 0123');              // true
/// pn.format('US', '2015550123', pn.PhoneFormat.international); // '+1 201-555-0123'
///
/// final ayt = pn.AsYouTypeFormatter('US');
/// for (final c in '6502530000'.split('')) ayt.inputDigit(c);   // '(650) 253-0000'
///
/// pn.findNumbers('call 201-555-0123 today', 'US');
/// ```
library;

export 'src/phonenumber.dart'
    show
        // enums / constant groups
        PhoneFormat,
        PhoneNumberType,
        ValidationResult,
        MatchType,
        CountryCodeSource,
        Leniency,
        ShortNumberCost,
        // metadata
        countryCode,
        exampleNumber,
        exampleNumberForType,
        invalidExampleNumber,
        possibleLengths,
        regionCodeForCountryCode,
        isNanpaCountry,
        nddPrefixForRegion,
        regions,
        ccRegionCount,
        regionsForCountryCode,
        // parse
        ParsedNumber,
        parse,
        nationalNumber,
        // validation
        isPossibleNumber,
        isPossibleNumberWithReason,
        isValidNumber,
        isValidNumberForRegion,
        numberType,
        canBeInternationallyDialled,
        // formatting
        format,
        formatNational,
        formatInternational,
        formatE164,
        formatRfc3966,
        formatOutOfCountry,
        // helpers
        isNumberMatch,
        truncateTooLong,
        normalizeDigitsOnly,
        convertAlphaCharacters,
        isAlphaNumber,
        abiVersion,
        nativeLibraryPath,
        // stateful / matcher
        AsYouTypeFormatter,
        PhoneNumberMatch,
        findNumbers,
        // short / emergency numbers
        ShortNumberInfo,
        // timezone + carrier + geocoder lookup
        TimeZones,
        Carrier,
        Geocoder;
