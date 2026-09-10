"
I am a parsed phone number.

I wrap the caller-owned parsed-number STRING that `aether_pn_embed_parse`
returns (the ABI has no opaque handles — the value IS the string). My accessors
pass that string back to the `pn_*` accessor calls on `PhonenumberAe`, each of
which is one FFI crossing whose returned `char*` routes through
`PhonenumberAe class >> takeString:`.

Create me with `PhonenumberAe parse: '...' region: '...'`.
"
Class {
	#name : 'PhonenumberAeParsedNumber',
	#superclass : 'Object',
	#instVars : [ 'pn' ],
	#category : 'PhonenumberAe',
	#package : 'PhonenumberAe'
}

{ #category : 'instance creation' }
PhonenumberAeParsedNumber class >> onString: aString [

	^ self new setRawString: aString
]

{ #category : 'private' }
PhonenumberAeParsedNumber >> setRawString: aString [

	pn := aString.
	^ self
]

{ #category : 'accessing' }
PhonenumberAeParsedNumber >> rawString [
	"The underlying caller-owned parsed-number string, for calls that take it
	 (e.g. PhonenumberAe formatInOriginal:callingFrom:)."

	^ pn
]

{ #category : 'accessing' }
PhonenumberAeParsedNumber >> error [
	"The parse error, or '' if the parse succeeded."

	^ PhonenumberAe takeString: (PhonenumberAe primPnError: pn)
]

{ #category : 'accessing' }
PhonenumberAeParsedNumber >> region [
	"The region the number was parsed for."

	^ PhonenumberAe takeString: (PhonenumberAe primPnRegion: pn)
]

{ #category : 'accessing' }
PhonenumberAeParsedNumber >> countryCode [
	"The country calling code."

	^ PhonenumberAe takeString: (PhonenumberAe primPnCountryCode: pn)
]

{ #category : 'accessing' }
PhonenumberAeParsedNumber >> nationalNumber [
	"The national number."

	^ PhonenumberAe takeString: (PhonenumberAe primPnNationalNumber: pn)
]

{ #category : 'accessing' }
PhonenumberAeParsedNumber >> extension [
	"The extension, or ''."

	^ PhonenumberAe takeString: (PhonenumberAe primPnExtension: pn)
]

{ #category : 'accessing' }
PhonenumberAeParsedNumber >> italianLeadingZero [
	"True if the number carried a significant leading zero."

	^ (PhonenumberAe primPnItalianLeadingZero: pn) ~= 0
]

{ #category : 'accessing' }
PhonenumberAeParsedNumber >> source [
	"The CountryCodeSource, as a Symbol (#fromNumberWithPlus, …)."

	^ PhonenumberAe countryCodeSourceSymbolFor: (PhonenumberAe primPnSource: pn)
]

{ #category : 'accessing' }
PhonenumberAeParsedNumber >> regionCode [
	"The region code the number belongs to."

	^ PhonenumberAe takeString: (PhonenumberAe primRegionCodeForNumber: pn)
]

{ #category : 'accessing' }
PhonenumberAeParsedNumber >> nationalSignificantNumber [
	"The national significant number."

	^ PhonenumberAe takeString:
		  (PhonenumberAe primNationalSignificantNumber: pn)
]

{ #category : 'accessing' }
PhonenumberAeParsedNumber >> lengthOfNdc [
	"The length of the national destination code."

	^ PhonenumberAe primLengthOfNdc: pn
]

{ #category : 'accessing' }
PhonenumberAeParsedNumber >> lengthOfAreaCode [
	"The length of the area code."

	^ PhonenumberAe primLengthOfAreaCode: pn
]

{ #category : 'accessing' }
PhonenumberAeParsedNumber >> isGeographical [
	"True if the number is geographical (tied to a place)."

	^ (PhonenumberAe primIsGeographical: pn) ~= 0
]
