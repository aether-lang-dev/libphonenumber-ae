"
I validate, parse and format international phone numbers (ABI v3).

```
PhonenumberAe countryCode: 'US'.                      ""-> '1'""
PhonenumberAe isValidNumber: '+1 201 555 0123' region: 'US'.  ""-> true""
PhonenumberAe format: '2015550123' region: 'US' style: #national.
""-> '(201) 555-0123'""
PhonenumberAe numberType: '2015550123' region: 'US'. ""-> #fixedLine""
(PhonenumberAe parse: '+1 201 555 0123 ext 42' region: 'US') nationalNumber.
""-> '2015550123'""
```

## No phone-number logic here

I am **marshalling only**. The engine — the metadata table, isPossible /
isValid, number typing and formatting — is the pure-Aether
`core/phonenumber.ae`, compiled from Google libphonenumber's own metadata,
shared by every language binding in this monorepo and reached through the
`aether_pn_embed_*` C ABI (`core/embed.ae`, docs/abi.md — 58 symbols, full
PhoneNumberUtil parity plus ShortNumberInfo). Naming: `core/embed.ae` declares `pn_embed_<name>`;
`--emit=lib` mangles that to `aether_pn_embed_<name>`, which is what the FFI
calls below name.

## The ONE ownership rule

**Every `char*` the ABI returns is caller-owned.** `takeString:` copies it and
frees it through `aether_pn_embed_free_string`. Anything else leaks — this is
the single most common bug in a binding of this ABI. It applies to the v2
additions too: parse, the pn_* accessors, format_*, the AsYouType state
strings, matcher_raw — every returned `char*` routes through `takeString:`.

## No opaque handles

The ABI has no handles. A parsed number and an as-you-type state are themselves
caller-owned STRINGS: `PhonenumberAeParsedNumber` and
`PhonenumberAeAsYouTypeFormatter` wrap those strings, but every call is one FFI
crossing. There is no callback surface either.
"
Class {
	#name : 'PhonenumberAe',
	#superclass : 'Object',
	#category : 'PhonenumberAe',
	#package : 'PhonenumberAe'
}

{ #category : 'constants - format' }
PhonenumberAe class >> styleE164 [ ^ 0 ]

{ #category : 'constants - format' }
PhonenumberAe class >> styleInternational [ ^ 1 ]

{ #category : 'constants - format' }
PhonenumberAe class >> styleNational [ ^ 2 ]

{ #category : 'constants - format' }
PhonenumberAe class >> styleRfc3966 [ ^ 3 ]

{ #category : 'constants - format' }
PhonenumberAe class >> styleFor: aSymbol [
	"Map a friendly symbol onto the ABI's integer format selector (v2:
	 #e164 is 0, not 2)."

	^ aSymbol
		  caseOf: {
			  [ #e164 ] -> [ self styleE164 ].
			  [ #international ] -> [ self styleInternational ].
			  [ #national ] -> [ self styleNational ].
			  [ #rfc3966 ] -> [ self styleRfc3966 ] }
		  otherwise: [
			  self error: 'unknown format style ' , aSymbol printString
				  , ' (expected one of #e164 #international #national #rfc3966)' ]
]

{ #category : 'constants - leniency' }
PhonenumberAe class >> leniencyPossible [ ^ 0 ]

{ #category : 'constants - leniency' }
PhonenumberAe class >> leniencyValid [ ^ 1 ]

{ #category : 'constants - leniency' }
PhonenumberAe class >> leniencyFor: aSymbol [
	"Map a leniency symbol onto the ABI's integer code."

	^ aSymbol
		  caseOf: {
			  [ #possible ] -> [ self leniencyPossible ].
			  [ #valid ] -> [ self leniencyValid ] }
		  otherwise: [
			  self error: 'unknown leniency ' , aSymbol printString
				  , ' (expected #possible or #valid)' ]
]

{ #category : 'constants - number type' }
PhonenumberAe class >> numberTypeSymbolFor: anInteger [
	"The ABI number-type code as a Symbol. The constants are append-only, so a
	 code this build does not know becomes #unknown rather than an error, and
	 -1 is the engine's own 'unknown' sentinel."

	^ anInteger
		  caseOf: {
			  [ -1 ] -> [ #unknown ].
			  [ 0 ] -> [ #fixedLine ].
			  [ 1 ] -> [ #mobile ].
			  [ 2 ] -> [ #tollFree ].
			  [ 3 ] -> [ #premiumRate ].
			  [ 4 ] -> [ #sharedCost ].
			  [ 5 ] -> [ #voip ].
			  [ 6 ] -> [ #personalNumber ].
			  [ 7 ] -> [ #pager ].
			  [ 8 ] -> [ #uan ].
			  [ 9 ] -> [ #voicemail ].
			  [ 10 ] -> [ #fixedLineOrMobile ] }
		  otherwise: [ #unknown ]
]

{ #category : 'constants - number type' }
PhonenumberAe class >> numberTypeCodeFor: aSymbol [
	"A number-type Symbol as the ABI's integer code."

	^ aSymbol
		  caseOf: {
			  [ #unknown ] -> [ -1 ].
			  [ #fixedLine ] -> [ 0 ].
			  [ #mobile ] -> [ 1 ].
			  [ #tollFree ] -> [ 2 ].
			  [ #premiumRate ] -> [ 3 ].
			  [ #sharedCost ] -> [ 4 ].
			  [ #voip ] -> [ 5 ].
			  [ #personalNumber ] -> [ 6 ].
			  [ #pager ] -> [ 7 ].
			  [ #uan ] -> [ 8 ].
			  [ #voicemail ] -> [ 9 ].
			  [ #fixedLineOrMobile ] -> [ 10 ] }
		  otherwise: [
			  self error: 'unknown number type ' , aSymbol printString ]
]

{ #category : 'constants - validation' }
PhonenumberAe class >> validationResultSymbolFor: anInteger [
	"The ABI ValidationResult code as a Symbol."

	^ anInteger
		  caseOf: {
			  [ 0 ] -> [ #isPossible ].
			  [ 4 ] -> [ #isPossibleLocalOnly ].
			  [ 1 ] -> [ #invalidCountryCode ].
			  [ 2 ] -> [ #tooShort ].
			  [ 5 ] -> [ #invalidLength ].
			  [ 3 ] -> [ #tooLong ] }
		  otherwise: [ #invalidLength ]
]

{ #category : 'constants - match' }
PhonenumberAe class >> matchTypeSymbolFor: anInteger [
	"The ABI MatchType code as a Symbol."

	^ anInteger
		  caseOf: {
			  [ 0 ] -> [ #notANumber ].
			  [ 1 ] -> [ #noMatch ].
			  [ 2 ] -> [ #shortNsn ].
			  [ 3 ] -> [ #nsn ].
			  [ 4 ] -> [ #exact ] }
		  otherwise: [ #noMatch ]
]

{ #category : 'constants - source' }
PhonenumberAe class >> countryCodeSourceSymbolFor: anInteger [
	"The ABI CountryCodeSource code as a Symbol."

	^ anInteger
		  caseOf: {
			  [ 1 ] -> [ #fromNumberWithPlus ].
			  [ 5 ] -> [ #fromNumberWithIdd ].
			  [ 10 ] -> [ #fromNumberWithoutPlus ].
			  [ 20 ] -> [ #fromDefaultCountry ] }
		  otherwise: [ #unspecified ]
]

{ #category : 'constants - short cost' }
PhonenumberAe class >> shortNumberCostSymbolFor: anInteger [
	"The ABI ShortNumberCost code as a Symbol (0 toll-free, 1 standard,
	 2 premium, 3 unknown). Append-only, so an unseen code becomes #unknown
	 rather than an error."

	^ anInteger
		  caseOf: {
			  [ 0 ] -> [ #tollFree ].
			  [ 1 ] -> [ #standardRate ].
			  [ 2 ] -> [ #premiumRate ].
			  [ 3 ] -> [ #unknown ] }
		  otherwise: [ #unknown ]
]

{ #category : 'private - ffi' }
PhonenumberAe class >> ffiLibrary [

	^ PhonenumberAeLibrary
]

{ #category : 'private - ffi lifecycle' }
PhonenumberAe class >> primFreeString: aPointer [

	^ self ffiCall: #( void aether_pn_embed_free_string ( void * aPointer ) )
]

{ #category : 'private - ffi lifecycle' }
PhonenumberAe class >> primAbiVersion [

	^ self ffiCall: #( int aether_pn_embed_abi_version ( void ) )
]

{ #category : 'private - ffi metadata' }
PhonenumberAe class >> primCountryCode: region [

	^ self ffiCall: #( void * aether_pn_embed_country_code ( char * region ) )
]

{ #category : 'private - ffi metadata' }
PhonenumberAe class >> primExampleNumber: region [

	^ self ffiCall: #( void * aether_pn_embed_example_number ( char * region ) )
]

{ #category : 'private - ffi metadata' }
PhonenumberAe class >> primExampleNumberForType: region type: type [

	^ self ffiCall: #( void * aether_pn_embed_example_number_for_type (
		    char * region, int type ) )
]

{ #category : 'private - ffi metadata' }
PhonenumberAe class >> primInvalidExampleNumber: region [

	^ self ffiCall: #( void * aether_pn_embed_invalid_example_number (
		    char * region ) )
]

{ #category : 'private - ffi metadata' }
PhonenumberAe class >> primPossibleLengths: region [

	^ self ffiCall: #( void * aether_pn_embed_possible_lengths ( char * region ) )
]

{ #category : 'private - ffi metadata' }
PhonenumberAe class >> primRegionCodeForCountryCode: cc [

	^ self ffiCall: #( void * aether_pn_embed_region_code_for_country_code (
		    char * cc ) )
]

{ #category : 'private - ffi metadata' }
PhonenumberAe class >> primIsNanpaCountry: region [

	^ self ffiCall: #( int aether_pn_embed_is_nanpa_country ( char * region ) )
]

{ #category : 'private - ffi metadata' }
PhonenumberAe class >> primNddPrefixForRegion: region strip: strip [

	^ self ffiCall: #( void * aether_pn_embed_ndd_prefix_for_region (
		    char * region, int strip ) )
]

{ #category : 'private - ffi regions' }
PhonenumberAe class >> primRegionCount [

	^ self ffiCall: #( int aether_pn_embed_region_count ( void ) )
]

{ #category : 'private - ffi regions' }
PhonenumberAe class >> primRegionAt: index [

	^ self ffiCall: #( void * aether_pn_embed_region_at ( int index ) )
]

{ #category : 'private - ffi regions' }
PhonenumberAe class >> primCcRegionCount: cc [

	^ self ffiCall: #( int aether_pn_embed_cc_region_count ( char * cc ) )
]

{ #category : 'private - ffi regions' }
PhonenumberAe class >> primCcRegionAt: cc index: index [

	^ self ffiCall: #( void * aether_pn_embed_cc_region_at (
		    char * cc, int index ) )
]

{ #category : 'private - ffi parse' }
PhonenumberAe class >> primParse: input region: region [

	^ self ffiCall: #( void * aether_pn_embed_parse (
		    char * input, char * region ) )
]

{ #category : 'private - ffi parse' }
PhonenumberAe class >> primNationalNumber: region input: input [

	^ self ffiCall: #( void * aether_pn_embed_national_number (
		    char * region, char * input ) )
]

{ #category : 'private - ffi parse' }
PhonenumberAe class >> primPnRegion: pn [

	^ self ffiCall: #( void * aether_pn_embed_pn_region ( char * pn ) )
]

{ #category : 'private - ffi parse' }
PhonenumberAe class >> primPnCountryCode: pn [

	^ self ffiCall: #( void * aether_pn_embed_pn_country_code ( char * pn ) )
]

{ #category : 'private - ffi parse' }
PhonenumberAe class >> primPnNationalNumber: pn [

	^ self ffiCall: #( void * aether_pn_embed_pn_national_number ( char * pn ) )
]

{ #category : 'private - ffi parse' }
PhonenumberAe class >> primPnExtension: pn [

	^ self ffiCall: #( void * aether_pn_embed_pn_extension ( char * pn ) )
]

{ #category : 'private - ffi parse' }
PhonenumberAe class >> primPnItalianLeadingZero: pn [

	^ self ffiCall: #( int aether_pn_embed_pn_italian_leading_zero ( char * pn ) )
]

{ #category : 'private - ffi parse' }
PhonenumberAe class >> primPnSource: pn [

	^ self ffiCall: #( int aether_pn_embed_pn_source ( char * pn ) )
]

{ #category : 'private - ffi parse' }
PhonenumberAe class >> primPnError: pn [

	^ self ffiCall: #( void * aether_pn_embed_pn_error ( char * pn ) )
]

{ #category : 'private - ffi parse' }
PhonenumberAe class >> primRegionCodeForNumber: pn [

	^ self ffiCall: #( void * aether_pn_embed_region_code_for_number ( char * pn ) )
]

{ #category : 'private - ffi parse' }
PhonenumberAe class >> primNationalSignificantNumber: pn [

	^ self ffiCall: #( void * aether_pn_embed_national_significant_number (
		    char * pn ) )
]

{ #category : 'private - ffi parse' }
PhonenumberAe class >> primLengthOfNdc: pn [

	^ self ffiCall: #( int aether_pn_embed_length_of_ndc ( char * pn ) )
]

{ #category : 'private - ffi parse' }
PhonenumberAe class >> primLengthOfAreaCode: pn [

	^ self ffiCall: #( int aether_pn_embed_length_of_area_code ( char * pn ) )
]

{ #category : 'private - ffi parse' }
PhonenumberAe class >> primIsGeographical: pn [

	^ self ffiCall: #( int aether_pn_embed_is_geographical ( char * pn ) )
]

{ #category : 'private - ffi validation' }
PhonenumberAe class >> primIsPossibleNumber: region input: input [

	^ self ffiCall: #( int aether_pn_embed_is_possible_number (
		    char * region, char * input ) )
]

{ #category : 'private - ffi validation' }
PhonenumberAe class >> primIsPossibleNumberWithReason: region input: input [

	^ self ffiCall: #( int aether_pn_embed_is_possible_number_with_reason (
		    char * region, char * input ) )
]

{ #category : 'private - ffi validation' }
PhonenumberAe class >> primIsValidNumber: region input: input [

	^ self ffiCall: #( int aether_pn_embed_is_valid_number (
		    char * region, char * input ) )
]

{ #category : 'private - ffi validation' }
PhonenumberAe class >> primIsValidNumberForRegion: input region: region [

	^ self ffiCall: #( int aether_pn_embed_is_valid_number_for_region (
		    char * input, char * region ) )
]

{ #category : 'private - ffi validation' }
PhonenumberAe class >> primNumberType: region input: input [

	^ self ffiCall: #( int aether_pn_embed_number_type (
		    char * region, char * input ) )
]

{ #category : 'private - ffi validation' }
PhonenumberAe class >> primCanBeInternationallyDialled: region input: input [

	^ self ffiCall: #( int aether_pn_embed_can_be_internationally_dialled (
		    char * region, char * input ) )
]

{ #category : 'private - ffi formatting' }
PhonenumberAe class >> primFormat: region input: input style: style [

	^ self ffiCall: #( void * aether_pn_embed_format (
		    char * region, char * input, int style ) )
]

{ #category : 'private - ffi formatting' }
PhonenumberAe class >> primFormatOutOfCountry: region input: input callingFrom: callingFrom [

	^ self ffiCall: #( void * aether_pn_embed_format_out_of_country (
		    char * region, char * input, char * callingFrom ) )
]

{ #category : 'private - ffi formatting' }
PhonenumberAe class >> primFormatInOriginal: pn callingFrom: callingFrom [

	^ self ffiCall: #( void * aether_pn_embed_format_in_original (
		    char * pn, char * callingFrom ) )
]

{ #category : 'private - ffi helpers' }
PhonenumberAe class >> primIsNumberMatch: a with: b [

	^ self ffiCall: #( int aether_pn_embed_is_number_match (
		    char * a, char * b ) )
]

{ #category : 'private - ffi helpers' }
PhonenumberAe class >> primTruncateTooLong: region input: input [

	^ self ffiCall: #( void * aether_pn_embed_truncate_too_long (
		    char * region, char * input ) )
]

{ #category : 'private - ffi helpers' }
PhonenumberAe class >> primNormalizeDigitsOnly: s [

	^ self ffiCall: #( void * aether_pn_embed_normalize_digits_only ( char * s ) )
]

{ #category : 'private - ffi helpers' }
PhonenumberAe class >> primConvertAlphaCharacters: s [

	^ self ffiCall: #( void * aether_pn_embed_convert_alpha_characters (
		    char * s ) )
]

{ #category : 'private - ffi helpers' }
PhonenumberAe class >> primIsAlphaNumber: s [

	^ self ffiCall: #( int aether_pn_embed_is_alpha_number ( char * s ) )
]

{ #category : 'private - ffi ayt' }
PhonenumberAe class >> primAytNew: region [

	^ self ffiCall: #( void * aether_pn_embed_ayt_new ( char * region ) )
]

{ #category : 'private - ffi ayt' }
PhonenumberAe class >> primAytInput: state ch: ch [

	^ self ffiCall: #( void * aether_pn_embed_ayt_input (
		    char * state, char * ch ) )
]

{ #category : 'private - ffi ayt' }
PhonenumberAe class >> primAytResult: state [

	^ self ffiCall: #( void * aether_pn_embed_ayt_result ( char * state ) )
]

{ #category : 'private - ffi ayt' }
PhonenumberAe class >> primAytClear: state [

	^ self ffiCall: #( void * aether_pn_embed_ayt_clear ( char * state ) )
]

{ #category : 'private - ffi matcher' }
PhonenumberAe class >> primMatcherCount: text region: region leniency: leniency [

	^ self ffiCall: #( int aether_pn_embed_matcher_count (
		    char * text, char * region, int leniency ) )
]

{ #category : 'private - ffi matcher' }
PhonenumberAe class >> primMatcherStart: text region: region leniency: leniency idx: idx [

	^ self ffiCall: #( int aether_pn_embed_matcher_start (
		    char * text, char * region, int leniency, int idx ) )
]

{ #category : 'private - ffi matcher' }
PhonenumberAe class >> primMatcherEnd: text region: region leniency: leniency idx: idx [

	^ self ffiCall: #( int aether_pn_embed_matcher_end (
		    char * text, char * region, int leniency, int idx ) )
]

{ #category : 'private - ffi matcher' }
PhonenumberAe class >> primMatcherRaw: text region: region leniency: leniency idx: idx [

	^ self ffiCall: #( void * aether_pn_embed_matcher_raw (
		    char * text, char * region, int leniency, int idx ) )
]

{ #category : 'private - ffi short' }
PhonenumberAe class >> primShortIsPossible: region input: input [

	^ self ffiCall: #( int aether_pn_embed_short_is_possible (
		    char * region, char * input ) )
]

{ #category : 'private - ffi short' }
PhonenumberAe class >> primShortIsValid: region input: input [

	^ self ffiCall: #( int aether_pn_embed_short_is_valid (
		    char * region, char * input ) )
]

{ #category : 'private - ffi short' }
PhonenumberAe class >> primShortIsEmergency: region input: input [

	^ self ffiCall: #( int aether_pn_embed_short_is_emergency (
		    char * region, char * input ) )
]

{ #category : 'private - ffi short' }
PhonenumberAe class >> primShortConnectsToEmergency: region input: input [

	^ self ffiCall: #( int aether_pn_embed_short_connects_to_emergency (
		    char * region, char * input ) )
]

{ #category : 'private - ffi short' }
PhonenumberAe class >> primShortIsCarrierSpecific: region input: input [

	^ self ffiCall: #( int aether_pn_embed_short_is_carrier_specific (
		    char * region, char * input ) )
]

{ #category : 'private - ffi short' }
PhonenumberAe class >> primShortIsSmsService: region input: input [

	^ self ffiCall: #( int aether_pn_embed_short_is_sms_service (
		    char * region, char * input ) )
]

{ #category : 'private - ffi short' }
PhonenumberAe class >> primShortExpectedCost: region input: input [

	^ self ffiCall: #( int aether_pn_embed_short_expected_cost (
		    char * region, char * input ) )
]

{ #category : 'private - ffi short' }
PhonenumberAe class >> primShortExampleNumber: region [

	^ self ffiCall: #( void * aether_pn_embed_short_example_number (
		    char * region ) )
]

{ #category : 'private - strings' }
PhonenumberAe class >> takeString: aPointer [
	"Copy an ABI-returned string out and free it through the ABI.

	 EVERY char* this ABI returns is caller-owned. Reading it without the free
	 below is a leak, and it is the easiest mistake to make here — so the decode
	 is wrapped in an ensure:, or a malformed byte sequence would leak the
	 buffer on its way out."

	| result |
	(aPointer isNil or: [ aPointer isNull ]) ifTrue: [ ^ '' ].
	result := [ aPointer utf8StringFromCString ]
		          ensure: [ self primFreeString: aPointer ].
	^ result
]

{ #category : 'region facts' }
PhonenumberAe class >> countryCode: aRegion [
	"The country calling code for a region ('1', '44', …), or '' if unknown."

	^ self takeString: (self primCountryCode: (aRegion ifNil: [ '' ]))
]

{ #category : 'region facts' }
PhonenumberAe class >> exampleNumber: aRegion [
	"An example national number for the region, or ''."

	^ self takeString: (self primExampleNumber: (aRegion ifNil: [ '' ]))
]

{ #category : 'region facts' }
PhonenumberAe class >> exampleNumberForType: aTypeSymbol region: aRegion [
	"An example national number of a given type (#mobile, …), or ''."

	^ self takeString: (self
			   primExampleNumberForType: (aRegion ifNil: [ '' ])
			   type: (self numberTypeCodeFor: aTypeSymbol))
]

{ #category : 'region facts' }
PhonenumberAe class >> invalidExampleNumber: aRegion [
	"An example number that is invalid for the region, or ''."

	^ self takeString: (self primInvalidExampleNumber: (aRegion ifNil: [ '' ]))
]

{ #category : 'region facts' }
PhonenumberAe class >> possibleLengths: aRegion [
	"The possible-lengths spec for the region (e.g. '9,10'), or ''."

	^ self takeString: (self primPossibleLengths: (aRegion ifNil: [ '' ]))
]

{ #category : 'region facts' }
PhonenumberAe class >> regionCodeForCountryCode: aCc [
	"The (main) region for a country calling code, e.g. '44' -> 'GB'."

	^ self takeString:
		  (self primRegionCodeForCountryCode: (aCc ifNil: [ '' ]) asString)
]

{ #category : 'region facts' }
PhonenumberAe class >> isNanpaCountry: aRegion [
	"True if the region is part of the North American Numbering Plan."

	^ (self primIsNanpaCountry: (aRegion ifNil: [ '' ])) ~= 0
]

{ #category : 'region facts' }
PhonenumberAe class >> nddPrefixForRegion: aRegion [
	"The national-direct-dialling prefix for the region."

	^ self nddPrefixForRegion: aRegion stripNonDigits: false
]

{ #category : 'region facts' }
PhonenumberAe class >> nddPrefixForRegion: aRegion stripNonDigits: aBoolean [
	"The national-direct-dialling prefix; formatting characters removed when
	 aBoolean is true."

	^ self takeString: (self
			   primNddPrefixForRegion: (aRegion ifNil: [ '' ])
			   strip: (aBoolean ifTrue: [ 1 ] ifFalse: [ 0 ]))
]

{ #category : 'region facts' }
PhonenumberAe class >> nationalNumber: anInput region: aRegion [
	"The national number extracted from raw input (cc + punctuation stripped)."

	^ self takeString: (self
			   primNationalNumber: (aRegion ifNil: [ '' ])
			   input: (anInput ifNil: [ '' ]))
]

{ #category : 'regions' }
PhonenumberAe class >> regionCount [
	"How many regions the metadata carries."

	^ self primRegionCount
]

{ #category : 'regions' }
PhonenumberAe class >> regionAt: anIndex [
	"The region id at anIndex (0-based)."

	^ self takeString: (self primRegionAt: anIndex)
]

{ #category : 'regions' }
PhonenumberAe class >> regions [
	"Every region id the metadata carries, as an OrderedCollection of ISO-3166
	 codes in the engine's own order."

	| n out |
	n := self primRegionCount.
	out := OrderedCollection new.
	0 to: n - 1 do: [ :i | out add: (self regionAt: i) ].
	^ out
]

{ #category : 'regions' }
PhonenumberAe class >> ccRegionCount: aCc [
	"How many regions share a country calling code."

	^ self primCcRegionCount: (aCc ifNil: [ '' ]) asString
]

{ #category : 'regions' }
PhonenumberAe class >> ccRegionAt: aCc index: anIndex [
	"The region id at anIndex among those sharing a country calling code."

	^ self takeString:
		  (self primCcRegionAt: (aCc ifNil: [ '' ]) asString index: anIndex)
]

{ #category : 'regions' }
PhonenumberAe class >> regionsForCountryCode: aCc [
	"Every region sharing a country calling code, e.g. '1' -> ('US' ...)."

	| cc n out |
	cc := (aCc ifNil: [ '' ]) asString.
	n := self primCcRegionCount: cc.
	out := OrderedCollection new.
	0 to: n - 1 do: [ :i |
		out add: (self takeString: (self primCcRegionAt: cc index: i)) ].
	^ out
]

{ #category : 'parsing' }
PhonenumberAe class >> parse: anInput region: aRegion [
	"Parse raw input into a PhonenumberAeParsedNumber. Read its fields with the
	 instance accessors; #error is non-empty when the parse failed."

	^ PhonenumberAeParsedNumber onString: (self takeString: (self
				    primParse: (anInput ifNil: [ '' ])
				    region: (aRegion ifNil: [ '' ])))
]

{ #category : 'validity' }
PhonenumberAe class >> isPossibleNumber: anInput region: aRegion [
	"True if the national number is a length the region allows."

	^ (self
		   primIsPossibleNumber: (aRegion ifNil: [ '' ])
		   input: (anInput ifNil: [ '' ])) ~= 0
]

{ #category : 'validity' }
PhonenumberAe class >> isPossibleNumberWithReason: anInput region: aRegion [
	"The ValidationResult as a Symbol (#isPossible, #tooShort, …)."

	^ self validationResultSymbolFor: (self
			   primIsPossibleNumberWithReason: (aRegion ifNil: [ '' ])
			   input: (anInput ifNil: [ '' ]))
]

{ #category : 'validity' }
PhonenumberAe class >> isValidNumber: anInput region: aRegion [
	"True if the number matches the region's national-number patterns."

	^ (self
		   primIsValidNumber: (aRegion ifNil: [ '' ])
		   input: (anInput ifNil: [ '' ])) ~= 0
]

{ #category : 'validity' }
PhonenumberAe class >> isValidNumberForRegion: anInput region: aRegion [
	"True if the number is valid for the specific region (not just its cc)."

	^ (self
		   primIsValidNumberForRegion: (anInput ifNil: [ '' ])
		   region: (aRegion ifNil: [ '' ])) ~= 0
]

{ #category : 'validity' }
PhonenumberAe class >> numberTypeCode: anInput region: aRegion [
	"The raw ABI type code (-1 unknown, 0 fixedLine, …)."

	^ self
		  primNumberType: (aRegion ifNil: [ '' ])
		  input: (anInput ifNil: [ '' ])
]

{ #category : 'validity' }
PhonenumberAe class >> numberType: anInput region: aRegion [
	"The number type as a Symbol (#fixedLine, #mobile, …; #unknown for -1)."

	^ self numberTypeSymbolFor: (self numberTypeCode: anInput region: aRegion)
]

{ #category : 'validity' }
PhonenumberAe class >> canBeInternationallyDialled: anInput region: aRegion [
	"True if the number can be dialled from outside its country."

	^ (self
		   primCanBeInternationallyDialled: (aRegion ifNil: [ '' ])
		   input: (anInput ifNil: [ '' ])) ~= 0
]

{ #category : 'formatting' }
PhonenumberAe class >> format: anInput region: aRegion style: aStyleSymbol [
	"Format the number in the given style
	 (#e164 #international #national #rfc3966)."

	^ self takeString: (self
			   primFormat: (aRegion ifNil: [ '' ])
			   input: (anInput ifNil: [ '' ])
			   style: (self styleFor: aStyleSymbol))
]

{ #category : 'formatting' }
PhonenumberAe class >> formatNational: anInput region: aRegion [

	^ self format: anInput region: aRegion style: #national
]

{ #category : 'formatting' }
PhonenumberAe class >> formatInternational: anInput region: aRegion [

	^ self format: anInput region: aRegion style: #international
]

{ #category : 'formatting' }
PhonenumberAe class >> formatE164: anInput region: aRegion [

	^ self format: anInput region: aRegion style: #e164
]

{ #category : 'formatting' }
PhonenumberAe class >> formatRfc3966: anInput region: aRegion [

	^ self format: anInput region: aRegion style: #rfc3966
]

{ #category : 'formatting' }
PhonenumberAe class >> formatOutOfCountry: anInput region: aRegion callingFrom: aCallingFrom [
	"Format as it would be dialled from aCallingFrom (the region dialling out)."

	^ self takeString: (self
			   primFormatOutOfCountry: (aRegion ifNil: [ '' ])
			   input: (anInput ifNil: [ '' ])
			   callingFrom: (aCallingFrom ifNil: [ '' ]))
]

{ #category : 'formatting' }
PhonenumberAe class >> formatInOriginal: aParsedNumber callingFrom: aCallingFrom [
	"Format a parsed number the way it was originally dialled."

	^ self takeString: (self
			   primFormatInOriginal: aParsedNumber rawString
			   callingFrom: (aCallingFrom ifNil: [ '' ]))
]

{ #category : 'helpers' }
PhonenumberAe class >> isNumberMatch: a with: b [
	"Compare two numbers; a MatchType Symbol (#exact, #noMatch, …)."

	^ self matchTypeSymbolFor:
		  (self primIsNumberMatch: (a ifNil: [ '' ]) with: (b ifNil: [ '' ]))
]

{ #category : 'helpers' }
PhonenumberAe class >> truncateTooLong: anInput region: aRegion [
	"Drop digits past the region's maximum possible length."

	^ self takeString: (self
			   primTruncateTooLong: (aRegion ifNil: [ '' ])
			   input: (anInput ifNil: [ '' ]))
]

{ #category : 'helpers' }
PhonenumberAe class >> normalizeDigitsOnly: aString [
	"Keep only the digits of a string (Unicode digits normalised to 0-9)."

	^ self takeString: (self primNormalizeDigitsOnly: (aString ifNil: [ '' ]))
]

{ #category : 'helpers' }
PhonenumberAe class >> convertAlphaCharacters: aString [
	"Convert vanity letters to their dial-pad digits (keeping punctuation)."

	^ self takeString: (self primConvertAlphaCharacters: (aString ifNil: [ '' ]))
]

{ #category : 'helpers' }
PhonenumberAe class >> isAlphaNumber: aString [
	"True if the string contains any vanity letters."

	^ (self primIsAlphaNumber: (aString ifNil: [ '' ])) ~= 0
]

{ #category : 'as-you-type' }
PhonenumberAe class >> asYouTypeFormatterFor: aRegion [
	"A fresh PhonenumberAeAsYouTypeFormatter for a region."

	^ PhonenumberAeAsYouTypeFormatter forRegion: aRegion
]

{ #category : 'find numbers' }
PhonenumberAe class >> findNumbers: aText region: aRegion [
	"Find phone numbers in free text (default leniency #valid). Answers an
	 OrderedCollection of PhonenumberAeMatch (start / end / raw)."

	^ self findNumbers: aText region: aRegion leniency: #valid
]

{ #category : 'find numbers' }
PhonenumberAe class >> findNumbers: aText region: aRegion leniency: aLeniencySymbol [
	"Find phone numbers in free text with the given leniency
	 (#possible or #valid). Answers an OrderedCollection of PhonenumberAeMatch."

	| text region len n out |
	text := aText ifNil: [ '' ].
	region := aRegion ifNil: [ '' ].
	len := self leniencyFor: aLeniencySymbol.
	n := self primMatcherCount: text region: region leniency: len.
	out := OrderedCollection new.
	0 to: n - 1 do: [ :i |
		out add: (PhonenumberAeMatch
				 start: (self primMatcherStart: text region: region leniency: len idx: i)
				 end: (self primMatcherEnd: text region: region leniency: len idx: i)
				 raw: (self takeString:
						  (self primMatcherRaw: text region: region leniency: len idx: i))) ].
	^ out
]

{ #category : 'short numbers' }
PhonenumberAe class >> shortIsPossible: anInput region: aRegion [
	"True if the short number is a possible length for the region. Short numbers
	 are dialled as-is: no country code, no national prefix."

	^ (self
		   primShortIsPossible: (aRegion ifNil: [ '' ])
		   input: (anInput ifNil: [ '' ])) ~= 0
]

{ #category : 'short numbers' }
PhonenumberAe class >> shortIsValid: anInput region: aRegion [
	"True if the short number is valid (carrier-independent) for the region."

	^ (self
		   primShortIsValid: (aRegion ifNil: [ '' ])
		   input: (anInput ifNil: [ '' ])) ~= 0
]

{ #category : 'short numbers' }
PhonenumberAe class >> isEmergencyNumber: anInput region: aRegion [
	"True if the short number is an emergency number for the region."

	^ (self
		   primShortIsEmergency: (aRegion ifNil: [ '' ])
		   input: (anInput ifNil: [ '' ])) ~= 0
]

{ #category : 'short numbers' }
PhonenumberAe class >> connectsToEmergencyNumber: anInput region: aRegion [
	"True if dialling the number would connect to an emergency service."

	^ (self
		   primShortConnectsToEmergency: (aRegion ifNil: [ '' ])
		   input: (anInput ifNil: [ '' ])) ~= 0
]

{ #category : 'short numbers' }
PhonenumberAe class >> shortIsCarrierSpecific: anInput region: aRegion [
	"True if the short number is carrier-specific in the region."

	^ (self
		   primShortIsCarrierSpecific: (aRegion ifNil: [ '' ])
		   input: (anInput ifNil: [ '' ])) ~= 0
]

{ #category : 'short numbers' }
PhonenumberAe class >> shortIsSmsService: anInput region: aRegion [
	"True if the short number is for an SMS service in the region."

	^ (self
		   primShortIsSmsService: (aRegion ifNil: [ '' ])
		   input: (anInput ifNil: [ '' ])) ~= 0
]

{ #category : 'short numbers' }
PhonenumberAe class >> shortExpectedCostCode: anInput region: aRegion [
	"The raw ABI ShortNumberCost code (0 tollFree, …)."

	^ self
		  primShortExpectedCost: (aRegion ifNil: [ '' ])
		  input: (anInput ifNil: [ '' ])
]

{ #category : 'short numbers' }
PhonenumberAe class >> shortExpectedCost: anInput region: aRegion [
	"The expected cost as a Symbol (#tollFree #standardRate #premiumRate
	 #unknown)."

	^ self shortNumberCostSymbolFor:
		  (self shortExpectedCostCode: anInput region: aRegion)
]

{ #category : 'short numbers' }
PhonenumberAe class >> shortExampleNumber: aRegion [
	"An example short number for the region, or ''."

	^ self takeString: (self primShortExampleNumber: (aRegion ifNil: [ '' ]))
]

{ #category : 'introspection' }
PhonenumberAe class >> abiVersion [
	"The engine's ABI revision (3)."

	^ self primAbiVersion
]
