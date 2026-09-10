"
Metacello baseline for the PhonenumberAe Pharo binding.

Load from a checkout:

```
Metacello new
	baseline: 'PhonenumberAe';
	repository: 'tonel://<path-to-repo>/pharo/src';
	load.
```

The package has **no external dependencies** — UnifiedFFI and SUnit are both in
the base image. That is deliberate: the binding is marshalling only, and the
engine it marshals to is the shared `core/phonenumber.ae`, loaded at run time as
a shared library rather than pulled in as a Pharo package.
"
Class {
	#name : 'BaselineOfPhonenumberAe',
	#superclass : 'BaselineOf',
	#category : 'BaselineOfPhonenumberAe',
	#package : 'BaselineOfPhonenumberAe'
}

{ #category : 'baselines' }
BaselineOfPhonenumberAe >> baseline: spec [

	<baseline>
	spec for: #common do: [
		"One package: the FFI binding and the conformance tests. Split it only
		 if the tests ever need to ship separately."
		spec package: 'PhonenumberAe' ]
]
