"
I format a number as it is typed, digit by digit.

My state is the caller-owned STRING that the `ayt_*` ABI calls thread (the ABI
has no opaque handles). `inputDigit:` replaces my state with the fresh string
the ABI returns each keystroke and answers the formatted-so-far result. Every
returned `char*` routes through `PhonenumberAe class >> takeString:`.

```
| f |
f := PhonenumberAe asYouTypeFormatterFor: 'US'.
'2015550123' do: [ :c | f inputDigit: c asString ].
f result.  ""-> '(201) 555-0123'""
```
"
Class {
	#name : 'PhonenumberAeAsYouTypeFormatter',
	#superclass : 'Object',
	#instVars : [ 'state' ],
	#category : 'PhonenumberAe',
	#package : 'PhonenumberAe'
}

{ #category : 'instance creation' }
PhonenumberAeAsYouTypeFormatter class >> forRegion: aRegion [

	^ self new initRegion: aRegion
]

{ #category : 'initialization' }
PhonenumberAeAsYouTypeFormatter >> initRegion: aRegion [

	state := PhonenumberAe takeString:
		         (PhonenumberAe primAytNew: (aRegion ifNil: [ '' ])).
	^ self
]

{ #category : 'input' }
PhonenumberAeAsYouTypeFormatter >> inputDigit: aCharacterString [
	"Feed one character. Replaces my state with the fresh one the ABI returns
	 and answers the formatted-so-far string."

	state := PhonenumberAe takeString:
		         (PhonenumberAe primAytInput: state ch: (aCharacterString ifNil: [ '' ])).
	^ self result
]

{ #category : 'accessing' }
PhonenumberAeAsYouTypeFormatter >> result [
	"The formatted-so-far string."

	^ PhonenumberAe takeString: (PhonenumberAe primAytResult: state)
]

{ #category : 'operations' }
PhonenumberAeAsYouTypeFormatter >> clear [
	"Reset the formatter for the same region."

	state := PhonenumberAe takeString: (PhonenumberAe primAytClear: state).
	^ self
]
