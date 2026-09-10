# frozen_string_literal: true

# phonenumber_ae — validate, parse and format international phone numbers.
#
# A thin Fiddle binding over one shared native engine (pure Aether, compiled
# from Google libphonenumber's own metadata), the same artifact every other
# language binding in this monorepo uses. Cross-language behaviour is therefore
# identical by construction, not by test. No phone-number logic lives in this
# gem; it only marshals values across the C ABI (v6, full PhoneNumberUtil parity
# plus ShortNumberInfo, TimeZones, Carrier and Geocoder).
#
#     require "phonenumber_ae"
#
#     num = PhoneNumberAe.parse("+1 650 253 0000", "US")
#     num.national_number                       # => "6502530000"
#     PhoneNumberAe.is_valid_number("US", "+1 650 253 0000")   # => true
#     PhoneNumberAe.format("US", "6502530000", PhoneNumberAe::INTERNATIONAL)
#     # => "+1 650-253-0000"
#
#     ayt = PhoneNumberAe::AsYouTypeFormatter.new("US")
#     "6502530000".each_char { |c| ayt.input_digit(c) }
#     ayt.result                                # => "(650) 253-0000"
#
#     PhoneNumberAe.find_numbers("call 201-555-0123 today", "US")

require_relative "phonenumber_ae/version"
require_relative "phonenumber_ae/native"
require_relative "phonenumber_ae/phone_number"
