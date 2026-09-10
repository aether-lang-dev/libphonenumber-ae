"
The 47-check binding conformance suite (docs/conformance.md, v6), in Pharo.

I prove the Pharo binding marshals every value shape across the FFI. I am NOT a
phone-number test suite — the behavioural cases live in the engine's own tests
and run once, in Aether.

Unlike the Kotlin/Scala/Clojure/Groovy layers, which sit on the Java binding,
this is a REAL FFI, so these checks carry their full weight here: a leaked
caller-owned string, a wrong int width, or a NULL-vs-empty-string mix-up would
show up in exactly these tests.

Run headless:

```
pharo --headless PhonenumberAe.image test --junit-xml-output PhonenumberAe
```

or from a workspace: `PhonenumberAeConformanceTest suite run`.
"
Class {
	#name : 'PhonenumberAeConformanceTest',
	#superclass : 'TestCase',
	#category : 'PhonenumberAe',
	#package : 'PhonenumberAe'
}

{ #category : 'tests' }
PhonenumberAeConformanceTest >> test01CountryCodeUs [

	self assert: (PhonenumberAe countryCode: 'US') equals: '1'
]

{ #category : 'tests' }
PhonenumberAeConformanceTest >> test02CountryCodeGb [

	self assert: (PhonenumberAe countryCode: 'GB') equals: '44'
]

{ #category : 'tests' }
PhonenumberAeConformanceTest >> test03UnknownRegion [
	"The classic NULL-vs-empty-string marshalling bug."

	self assert: (PhonenumberAe countryCode: 'ZZ') equals: ''
]

{ #category : 'tests' }
PhonenumberAeConformanceTest >> test04ExampleNumber [

	self assert: (PhonenumberAe exampleNumber: 'US') equals: '2015550123'
]

{ #category : 'tests' }
PhonenumberAeConformanceTest >> test05PossibleLengths [

	self assert: (PhonenumberAe possibleLengths: 'US') equals: '10'
]

{ #category : 'tests' }
PhonenumberAeConformanceTest >> test06RegionForCc [

	self
		assert: (PhonenumberAe regionCodeForCountryCode: '44')
		equals: 'GB'
]

{ #category : 'tests' }
PhonenumberAeConformanceTest >> test07IsNanpa [

	self assert: (PhonenumberAe isNanpaCountry: 'US')
]

{ #category : 'tests' }
PhonenumberAeConformanceTest >> test08RegionEnumeration [
	"region_count >= 200 and region_at(0) is a 2-letter id. The item_at read
	 path, and the whole-list build agreeing with it."

	| regs |
	self assert: PhonenumberAe regionCount >= 200.
	regs := PhonenumberAe regions.
	self assert: regs size equals: PhonenumberAe regionCount.
	self assert: (regs at: 1) size equals: 2.
	self assert: (PhonenumberAe regionAt: 0) equals: (regs at: 1)
]

{ #category : 'tests' }
PhonenumberAeConformanceTest >> test09CcRegion [

	self assert: (PhonenumberAe ccRegionAt: '1' index: 0) equals: 'US'.
	self
		assert: (PhonenumberAe regionsForCountryCode: '1') first
		equals: 'US'
]

{ #category : 'tests' }
PhonenumberAeConformanceTest >> test10to14Parse [
	"parse returns a caller-owned parsed-number value; read its fields."

	| num |
	num := PhonenumberAe parse: '+1 201 555 0123 ext 42' region: 'US'.
	self assert: num error equals: ''.
	self assert: num nationalNumber equals: '2015550123'.
	self assert: num extension equals: '42'.
	self assert: num countryCode equals: '1'.
	self assert: num source equals: #fromNumberWithPlus.
	self assert: num regionCode equals: 'US'
]

{ #category : 'tests' }
PhonenumberAeConformanceTest >> test15ParseTrunkPrefix [

	| num |
	num := PhonenumberAe parse: '01212345678' region: 'GB'.
	self assert: num nationalNumber equals: '1212345678'
]

{ #category : 'tests' }
PhonenumberAeConformanceTest >> test16IsPossible [

	self assert: (PhonenumberAe isPossibleNumber: '2015550123' region: 'US')
]

{ #category : 'tests' }
PhonenumberAeConformanceTest >> test17ReasonTooShort [

	self
		assert: (PhonenumberAe isPossibleNumberWithReason: '201555' region: 'US')
		equals: #tooShort
]

{ #category : 'tests' }
PhonenumberAeConformanceTest >> test18IsValid [

	self assert: (PhonenumberAe isValidNumber: '2015550123' region: 'US')
]

{ #category : 'tests' }
PhonenumberAeConformanceTest >> test19InvalidShape [

	self deny: (PhonenumberAe isValidNumber: '1015550123' region: 'US')
]

{ #category : 'tests' }
PhonenumberAeConformanceTest >> test20ValidWithCc [

	self assert: (PhonenumberAe isValidNumber: '+12015550123' region: 'US')
]

{ #category : 'tests' }
PhonenumberAeConformanceTest >> test21NumberType [
	"The int result path, mapped to a Symbol; and the raw code alongside it."

	"US fixedLine==mobile -> #fixedLineOrMobile; GB has distinct patterns."
	self
		assert: (PhonenumberAe numberType: '2015550123' region: 'US')
		equals: #fixedLineOrMobile.
	self
		assert: (PhonenumberAe numberTypeCode: '2015550123' region: 'US')
		equals: 10.
	self
		assert: (PhonenumberAe numberType: '2070313000' region: 'GB')
		equals: #fixedLine.
	self
		assert: (PhonenumberAe numberTypeCode: '2070313000' region: 'GB')
		equals: 0
]

{ #category : 'tests' }
PhonenumberAeConformanceTest >> test22FormatNational [

	self
		assert: (PhonenumberAe format: '2015550123' region: 'US' style: #national)
		equals: '(201) 555-0123'
]

{ #category : 'tests' }
PhonenumberAeConformanceTest >> test23FormatE164 [

	self
		assert: (PhonenumberAe format: '2015550123' region: 'US' style: #e164)
		equals: '+12015550123'
]

{ #category : 'tests' }
PhonenumberAeConformanceTest >> test24FormatInternational [

	self
		assert: (PhonenumberAe format: '2015550123' region: 'US' style: #international)
		equals: '+1 201-555-0123'
]

{ #category : 'tests' }
PhonenumberAeConformanceTest >> test25FormatRfc3966 [

	self
		assert: (PhonenumberAe format: '2015550123' region: 'US' style: #rfc3966)
		equals: 'tel:+1-201-555-0123'
]

{ #category : 'tests' }
PhonenumberAeConformanceTest >> test26MatchExact [

	self
		assert: (PhonenumberAe isNumberMatch: '+12015550123' with: '+1 201 555 0123')
		equals: #exact
]

{ #category : 'tests' }
PhonenumberAeConformanceTest >> test27MatchNone [

	self
		assert: (PhonenumberAe isNumberMatch: '+12015550123' with: '+12025550123')
		equals: #noMatch
]

{ #category : 'tests' }
PhonenumberAeConformanceTest >> test28Normalize [

	self
		assert: (PhonenumberAe normalizeDigitsOnly: '+1 (201) 555.0123')
		equals: '12015550123'
]

{ #category : 'tests' }
PhonenumberAeConformanceTest >> test29Alpha [

	self
		assert: (PhonenumberAe convertAlphaCharacters: '1-800-FLOWERS')
		equals: '1-800-3569377'
]

{ #category : 'tests' }
PhonenumberAeConformanceTest >> test30Truncate [

	self
		assert: (PhonenumberAe truncateTooLong: '20155501239999' region: 'US')
		equals: '2015550123'
]

{ #category : 'tests' }
PhonenumberAeConformanceTest >> test31AsYouType [
	"Feed a number digit-by-digit; the state string is threaded through the FFI."

	| f last |
	f := PhonenumberAe asYouTypeFormatterFor: 'US'.
	last := ''.
	'2015550123' do: [ :c | last := f inputDigit: c asString ].
	self assert: last equals: '(201) 555-0123'.
	self assert: f result equals: '(201) 555-0123'
]

{ #category : 'tests' }
PhonenumberAeConformanceTest >> test32MatcherCount [

	| matches |
	matches := PhonenumberAe
		           findNumbers: 'call 201-555-0123 or +1 202 555 0199'
		           region: 'US'.
	self assert: matches size equals: 2
]

{ #category : 'tests' }
PhonenumberAeConformanceTest >> test33MatcherRaw [

	| matches |
	matches := PhonenumberAe
		           findNumbers: 'call 201-555-0123 now'
		           region: 'US'.
	self assert: matches first raw equals: '201-555-0123'
]

{ #category : 'tests' }
PhonenumberAeConformanceTest >> test34AbiVersion [

	self assert: PhonenumberAe abiVersion equals: 7
]

{ #category : 'tests - short numbers' }
PhonenumberAeConformanceTest >> test35ShortEmergencyUs [

	self assert: (PhonenumberAe isEmergencyNumber: '911' region: 'US')
]

{ #category : 'tests - short numbers' }
PhonenumberAeConformanceTest >> test36ShortNotEmergency [
	"999 is emergency in GB, not US."

	self deny: (PhonenumberAe isEmergencyNumber: '999' region: 'US')
]

{ #category : 'tests - short numbers' }
PhonenumberAeConformanceTest >> test37ShortEmergencyGb [

	self assert: (PhonenumberAe isEmergencyNumber: '999' region: 'GB')
]

{ #category : 'tests - short numbers' }
PhonenumberAeConformanceTest >> test38ShortValid [

	self assert: (PhonenumberAe shortIsValid: '911' region: 'US')
]

{ #category : 'tests - short numbers' }
PhonenumberAeConformanceTest >> test39ShortCost [
	"The int result path, mapped to a Symbol; and the raw code alongside it."

	self
		assert: (PhonenumberAe shortExpectedCost: '911' region: 'US')
		equals: #tollFree.
	self
		assert: (PhonenumberAe shortExpectedCostCode: '911' region: 'US')
		equals: 0
]

{ #category : 'tests - short numbers' }
PhonenumberAeConformanceTest >> test40ShortExample [

	self assert: (PhonenumberAe shortExampleNumber: 'US') equals: '112'
]

{ #category : 'tests - timezones + carrier' }
PhonenumberAeConformanceTest >> test41TimeZonesUs [
	"The list path: a single-zone number comes back as a one-element collection."

	self
		assert: (PhonenumberAe timeZonesForNumber: '2015550123' region: 'US')
			asArray
		equals: #( 'America/New_York' )
]

{ #category : 'tests - timezones + carrier' }
PhonenumberAeConformanceTest >> test42TimeZonesGb [

	self
		assert: (PhonenumberAe timeZonesForNumber: '2070313000' region: 'GB')
			asArray
		equals: #( 'Europe/London' )
]

{ #category : 'tests - timezones + carrier' }
PhonenumberAeConformanceTest >> test43UnknownTimeZone [

	self assert: PhonenumberAe unknownTimeZone equals: 'Etc/Unknown'
]

{ #category : 'tests - timezones + carrier' }
PhonenumberAeConformanceTest >> test44Carrier [

	self
		assert: (PhonenumberAe carrierNameForNumber: '7106000000' region: 'GB')
		equals: 'O2'
]

{ #category : 'tests - geocoder' }
PhonenumberAeConformanceTest >> test45Geocoder [

	self
		assert: (PhonenumberAe geoDescriptionForNumber: '6502530000' region: 'US')
		equals: 'Mountain View, CA'
]

{ #category : 'tests - grouping leniency' }
PhonenumberAeConformanceTest >> test46StrictGroupingAlternateFormat [
	"#46: the DE candidate's three-group split matches no MAIN format but is
	 legitimized by an alternate format, so #strictGrouping (2) accepts it."

	self
		assert: (PhonenumberAe
				 findNumbers: 'call 030 234 5678 now'
				 region: 'DE'
				 leniency: #strictGrouping) size
		equals: 1
]

{ #category : 'tests - grouping leniency' }
PhonenumberAeConformanceTest >> test47ExactGroupingRejectsIllegitimate [
	"#47: the US digits are a VALID number (they match at #valid) but their
	 grouping matches no US format, so #exactGrouping (3) rejects them."

	self
		assert: (PhonenumberAe
				 findNumbers: 'call 65 025 30000 today'
				 region: 'US'
				 leniency: #valid) size
		equals: 1.
	self
		assert: (PhonenumberAe
				 findNumbers: 'call 65 025 30000 today'
				 region: 'US'
				 leniency: #exactGrouping) size
		equals: 0
]

{ #category : 'tests - extras' }
PhonenumberAeConformanceTest >> testFormatHelpers [

	self
		assert: (PhonenumberAe formatNational: '2015550123' region: 'US')
		equals: '(201) 555-0123'.
	self
		assert: (PhonenumberAe formatE164: '2015550123' region: 'US')
		equals: '+12015550123'.
	self
		assert: (PhonenumberAe formatInternational: '2015550123' region: 'US')
		equals: '+1 201-555-0123'.
	self
		assert: (PhonenumberAe formatRfc3966: '2015550123' region: 'US')
		equals: 'tel:+1-201-555-0123'
]

{ #category : 'tests - extras' }
PhonenumberAeConformanceTest >> testMatchOffsets [
	"find_numbers carries start/end offsets alongside the raw text."

	| m |
	m := (PhonenumberAe findNumbers: 'call 201-555-0123 now' region: 'US') first.
	self assert: m raw equals: '201-555-0123'.
	self assert: m end > m start
]

{ #category : 'tests - extras' }
PhonenumberAeConformanceTest >> testUnknownStyleIsRejected [
	"A typo'd style must fail loudly, not silently pick a default."

	self
		should: [ PhonenumberAe format: '2015550123' region: 'US' style: #nonsense ]
		raise: Error
]

{ #category : 'tests - extras' }
PhonenumberAeConformanceTest >> testUnknownNumberTypeCodeDegrades [
	"The ABI's constants are append-only; a code this build has never seen must
	 become #unknown rather than raise."

	self assert: (PhonenumberAe numberTypeSymbolFor: 9999) equals: #unknown.
	self assert: (PhonenumberAe numberTypeSymbolFor: -1) equals: #unknown
]
