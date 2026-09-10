"
I am a phone number found in free text by `PhonenumberAe findNumbers:region:`.

I carry the `start` and `end` character offsets of the match within the text,
and its `raw` matched substring.
"
Class {
	#name : 'PhonenumberAeMatch',
	#superclass : 'Object',
	#instVars : [ 'start', 'end', 'raw' ],
	#category : 'PhonenumberAe',
	#package : 'PhonenumberAe'
}

{ #category : 'instance creation' }
PhonenumberAeMatch class >> start: aStart end: anEnd raw: aRaw [

	^ self new setStart: aStart end: anEnd raw: aRaw
]

{ #category : 'private' }
PhonenumberAeMatch >> setStart: aStart end: anEnd raw: aRaw [

	start := aStart.
	end := anEnd.
	raw := aRaw.
	^ self
]

{ #category : 'accessing' }
PhonenumberAeMatch >> start [
	"The 0-based character offset where the match begins."

	^ start
]

{ #category : 'accessing' }
PhonenumberAeMatch >> end [
	"The 0-based character offset just past the match."

	^ end
]

{ #category : 'accessing' }
PhonenumberAeMatch >> raw [
	"The raw matched substring."

	^ raw
]

{ #category : 'printing' }
PhonenumberAeMatch >> printOn: aStream [

	super printOn: aStream.
	aStream
		nextPutAll: '(';
		print: start;
		nextPutAll: '..';
		print: end;
		nextPutAll: ' ';
		print: raw;
		nextPutAll: ')'
]
