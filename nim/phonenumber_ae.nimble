# Package manifest for the Nim binding.
#
# Note this package LINKS the native engine (see src/phonenumber_ae.nim's
# {.passL.}), so `libphonenumber_ae.so` must be present at COMPILE time, not
# just at run time. `nim/.tests.ae` stages it into nim/native/; an in-tree
# checkout also has core/native/libphonenumber_ae.so once the engine is built,
# and both directories are on the link path and baked in as rpath.
#
# There is no `requires` beyond nim itself: a binding that marshals to a C ABI
# needs no third-party code, which keeps `nimble install` offline and the
# dependency surface at zero.

version       = "0.2.0"
author        = "Paul Hammant"
description   = "Validate and format international phone numbers — a thin binding over the shared native engine"
license       = "MIT"
srcDir        = "src"

requires "nim >= 1.6.0"

# `nimble test` compiles and runs every tests/t*.nim. The suite is equally
# runnable without nimble, which is how .tests.ae drives it:
#
#     nim c -r tests/tconformance.nim
task test, "Run the v5 (44-check) conformance suite":
  exec "nim c -r --hints:off tests/tconformance.nim"
