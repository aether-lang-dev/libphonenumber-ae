# frozen_string_literal: true

require_relative "lib/phonenumber_ae/version"

Gem::Specification.new do |spec|
  spec.name = "phonenumber_ae"
  spec.version = PhoneNumberAe::VERSION
  spec.authors = ["phonenumber_ae contributors"]
  spec.summary = "Validate and format international phone numbers — thin binding over one shared native engine"
  spec.description = <<~DESC
    A Fiddle binding over the shared libphonenumber engine (pure Aether,
    compiled to libphonenumber_ae.so). The gem carries no phone-number logic of
    its own — it only marshals values across the engine's C ABI, so every
    language binding in the monorepo behaves identically.
  DESC
  spec.homepage = "https://github.com/paul-hammant/libphonenumber-ae"
  spec.license = "Apache-2.0"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage

  spec.files = Dir[
    "lib/**/*.rb",
    "native/*.so", "native/*.dylib", "native/*.dll",
    "README.md"
  ]
  spec.require_paths = ["lib"]

  # fiddle is a default gem on Ruby 3.x; named so a future default-gem
  # extraction does not silently break the binding.
  spec.add_dependency "fiddle", ">= 1.0"

  spec.add_development_dependency "rake", ">= 13.0"
  spec.add_development_dependency "rspec", "~> 3.12"
end
