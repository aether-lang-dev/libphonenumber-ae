"
I am the FFI library handle for the shared libphonenumber engine.

I am the ONLY class in this package that knows where the shared library lives.
Everything else reaches the engine through `PhonenumberAe`, which sends its FFI
calls with `self ffiLibrary: PhonenumberAeLibrary`.

## The engine

No phone-number logic lives in this package. The engine — the metadata table,
isPossible / isValid, number typing and formatting — is the pure-Aether
`core/phonenumber.ae`, compiled from Google libphonenumber's own metadata,
shared by every language binding in this monorepo and reached through the
`aether_pn_embed_*` C ABI (`core/embed.ae`).

Unlike the Kotlin/Scala/Clojure/Groovy layers, which sit on the Java binding,
this IS a real FFI: Pharo is not a JVM, so it binds the C ABI directly with
UnifiedFFI.

## Resolution order

Matching every other binding in the monorepo:

1. an explicit path — `PhonenumberAeLibrary explicitPath: '/path/to/lib.so'`
2. `$LIBPHONENUMBER_AE_LIB`
3. `native/` beside the image
4. the OS loader's own search path
"
Class {
	#name : 'PhonenumberAeLibrary',
	#superclass : 'FFILibrary',
	#classVars : [ 'ExplicitPath' ],
	#category : 'PhonenumberAe',
	#package : 'PhonenumberAe'
}

{ #category : 'accessing' }
PhonenumberAeLibrary class >> explicitPath [
	"An explicit engine path, or nil to use the usual search."

	^ ExplicitPath
]

{ #category : 'accessing' }
PhonenumberAeLibrary class >> explicitPath: aStringOrNil [
	"Pin the engine to one path. Pass nil to go back to the usual search.
	 Set this BEFORE the first FFI call: UnifiedFFI caches the resolved
	 handle, so a later change does not move an already-bound session."

	ExplicitPath := aStringOrNil
]

{ #category : 'accessing' }
PhonenumberAeLibrary class >> libraryName [

	^ self new libraryName
]

{ #category : 'accessing - platform' }
PhonenumberAeLibrary >> macModuleName [

	^ self resolvedPathFor: 'libphonenumber_ae.dylib'
]

{ #category : 'accessing - platform' }
PhonenumberAeLibrary >> unix64ModuleName [

	^ self resolvedPathFor: 'libphonenumber_ae.so'
]

{ #category : 'accessing - platform' }
PhonenumberAeLibrary >> unixModuleName [

	^ self resolvedPathFor: 'libphonenumber_ae.so'
]

{ #category : 'accessing - platform' }
PhonenumberAeLibrary >> win32ModuleName [

	^ self resolvedPathFor: 'phonenumber_ae.dll'
]

{ #category : 'private' }
PhonenumberAeLibrary >> resolvedPathFor: aFileName [
	"The engine's path, by the monorepo's standard resolution order. Falls
	 back to the bare file name, which lets the OS loader search its own
	 paths — so a system-installed engine still works."

	| explicit env bundled |
	explicit := self class explicitPath.
	(explicit isNil or: [ explicit isEmpty ]) ifFalse: [ ^ explicit ].

	env := OSEnvironment current at: 'LIBPHONENUMBER_AE_LIB' ifAbsent: [ nil ].
	(env isNil or: [ env isEmpty ]) ifFalse: [ ^ env ].

	bundled := FileLocator imageDirectory / 'native' / aFileName.
	bundled exists ifTrue: [ ^ bundled fullName ].

	^ aFileName
]
