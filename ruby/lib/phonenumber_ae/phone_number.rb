# frozen_string_literal: true

# Idiomatic Ruby surface over the phonenumber engine (ABI v3).
#
# Carries no phone-number logic — see the monorepo's one rule in LLM.md. Every
# method here marshals to an `aether_pn_embed_*` call in `native.rb`.

require_relative "native"

module PhoneNumberAe
  # ---- format styles (re-exported from the ABI seam) ----
  E164 = Native::E164
  INTERNATIONAL = Native::INTERNATIONAL
  NATIONAL = Native::NATIONAL
  RFC3966 = Native::RFC3966

  # ---- number types (number_type result; -1 = unknown) ----
  TYPE_UNKNOWN = Native::TYPE_UNKNOWN
  TYPE_FIXED_LINE = Native::TYPE_FIXED_LINE
  TYPE_MOBILE = Native::TYPE_MOBILE
  TYPE_TOLL_FREE = Native::TYPE_TOLL_FREE
  TYPE_PREMIUM_RATE = Native::TYPE_PREMIUM_RATE
  TYPE_SHARED_COST = Native::TYPE_SHARED_COST
  TYPE_VOIP = Native::TYPE_VOIP
  TYPE_PERSONAL_NUMBER = Native::TYPE_PERSONAL_NUMBER
  TYPE_PAGER = Native::TYPE_PAGER
  TYPE_UAN = Native::TYPE_UAN
  TYPE_VOICEMAIL = Native::TYPE_VOICEMAIL
  TYPE_FIXED_LINE_OR_MOBILE = Native::TYPE_FIXED_LINE_OR_MOBILE

  # ---- ValidationResult (is_possible_number_with_reason) ----
  VR_IS_POSSIBLE = Native::VR_IS_POSSIBLE
  VR_IS_POSSIBLE_LOCAL_ONLY = Native::VR_IS_POSSIBLE_LOCAL_ONLY
  VR_INVALID_COUNTRY_CODE = Native::VR_INVALID_COUNTRY_CODE
  VR_TOO_SHORT = Native::VR_TOO_SHORT
  VR_INVALID_LENGTH = Native::VR_INVALID_LENGTH
  VR_TOO_LONG = Native::VR_TOO_LONG

  # ---- MatchType (is_number_match) ----
  MATCH_NOT_A_NUMBER = Native::MATCH_NOT_A_NUMBER
  MATCH_NO_MATCH = Native::MATCH_NO_MATCH
  MATCH_SHORT_NSN = Native::MATCH_SHORT_NSN
  MATCH_NSN = Native::MATCH_NSN
  MATCH_EXACT = Native::MATCH_EXACT

  # ---- CountryCodeSource (pn_source) ----
  SRC_FROM_NUMBER_WITH_PLUS = Native::SRC_FROM_NUMBER_WITH_PLUS
  SRC_FROM_NUMBER_WITH_IDD = Native::SRC_FROM_NUMBER_WITH_IDD
  SRC_FROM_NUMBER_WITHOUT_PLUS = Native::SRC_FROM_NUMBER_WITHOUT_PLUS
  SRC_FROM_DEFAULT_COUNTRY = Native::SRC_FROM_DEFAULT_COUNTRY

  # ---- matcher leniency ----
  LENIENCY_POSSIBLE = Native::LENIENCY_POSSIBLE
  LENIENCY_VALID = Native::LENIENCY_VALID

  # ---- ShortNumberCost (short_expected_cost) ----
  COST_TOLL_FREE = Native::COST_TOLL_FREE
  COST_STANDARD_RATE = Native::COST_STANDARD_RATE
  COST_PREMIUM_RATE = Native::COST_PREMIUM_RATE
  COST_UNKNOWN = Native::COST_UNKNOWN

  module_function

  # The engine, loaded (and cached) on first use. Pass native_lib: to override.
  def _lib(native_lib = nil)
    Native.load(native_lib)
  end
  private_class_method :_lib

  def _enc(str)
    (str || "").to_s.dup.force_encoding(Encoding::UTF_8)
  end
  private_class_method :_enc

  # Marshal a string-returning ABI call (name + already-encoded args).
  def _s(name, *args)
    lib = _lib
    lib.take_string(lib.call(name, *args))
  end
  private_class_method :_s

  # ---- metadata ----

  # The country calling code for a region ("1", "44", …), or "" if unknown.
  def country_code(region)
    _s("aether_pn_embed_country_code", _enc(region))
  end

  # An example national number for the region, or "".
  def example_number(region)
    _s("aether_pn_embed_example_number", _enc(region))
  end

  # An example national number of the given type for the region, or "".
  def example_number_for_type(region, type)
    _s("aether_pn_embed_example_number_for_type", _enc(region), type.to_i)
  end

  # An example number that is invalid for the region, or "".
  def invalid_example_number(region)
    _s("aether_pn_embed_invalid_example_number", _enc(region))
  end

  # The possible-lengths spec for the region (e.g. "9,10"), or "".
  def possible_lengths(region)
    _s("aether_pn_embed_possible_lengths", _enc(region))
  end

  # The region id owning a country calling code, or "" (e.g. "44" -> "GB").
  def region_code_for_country_code(cc)
    _s("aether_pn_embed_region_code_for_country_code", _enc(cc.to_s))
  end

  # True if the region is part of the North American Numbering Plan.
  def is_nanpa_country(region)
    _lib.call("aether_pn_embed_is_nanpa_country", _enc(region)) != 0
  end

  # The national direct-dialling prefix for a region, or "".
  def ndd_prefix_for_region(region, strip_non_digits: false)
    _s("aether_pn_embed_ndd_prefix_for_region", _enc(region), strip_non_digits ? 1 : 0)
  end

  # The id at position index in the metadata's region table.
  def region_at(index)
    _s("aether_pn_embed_region_at", index.to_i)
  end

  # Every region id the metadata carries, as an array of ISO-3166 codes.
  def regions
    n = _lib.call("aether_pn_embed_region_count")
    (0...n).map { |i| region_at(i) }
  end

  # All region ids that share a country calling code (e.g. "1" -> ["US", …]).
  def regions_for_country_code(cc)
    lib = _lib
    n = lib.call("aether_pn_embed_cc_region_count", _enc(cc.to_s))
    (0...n).map { |i| lib.take_string(lib.call("aether_pn_embed_cc_region_at", _enc(cc.to_s), i)) }
  end

  # ---- parsed number ----

  # A parsed phone number. Wraps the caller-owned parsed-number string the ABI
  # returns; its fields are read on demand through the pn_* accessors.
  class ParsedNumber
    def initialize(pn_string)
      @pn = pn_string
    end

    # The raw parsed-number handle string (for format_in_original etc.).
    attr_reader :pn

    def region
      PhoneNumberAe.send(:_s, "aether_pn_embed_pn_region", enc)
    end

    def country_code
      PhoneNumberAe.send(:_s, "aether_pn_embed_pn_country_code", enc)
    end

    def national_number
      PhoneNumberAe.send(:_s, "aether_pn_embed_pn_national_number", enc)
    end

    def extension
      PhoneNumberAe.send(:_s, "aether_pn_embed_pn_extension", enc)
    end

    def italian_leading_zero?
      lib.call("aether_pn_embed_pn_italian_leading_zero", enc) != 0
    end

    def source
      lib.call("aether_pn_embed_pn_source", enc)
    end

    # Non-empty if the parse failed.
    def error
      PhoneNumberAe.send(:_s, "aether_pn_embed_pn_error", enc)
    end

    def region_code
      PhoneNumberAe.send(:_s, "aether_pn_embed_region_code_for_number", enc)
    end

    def national_significant_number
      PhoneNumberAe.send(:_s, "aether_pn_embed_national_significant_number", enc)
    end

    def length_of_ndc
      lib.call("aether_pn_embed_length_of_ndc", enc)
    end

    def length_of_area_code
      lib.call("aether_pn_embed_length_of_area_code", enc)
    end

    def geographical?
      lib.call("aether_pn_embed_is_geographical", enc) != 0
    end

    private

    def lib
      PhoneNumberAe.send(:_lib)
    end

    def enc
      PhoneNumberAe.send(:_enc, @pn)
    end
  end

  # Parse a raw number (a human might type) into a ParsedNumber.
  def parse(number, region)
    ParsedNumber.new(_s("aether_pn_embed_parse", _enc(number), _enc(region)))
  end

  # The national number extracted from raw input (cc + punctuation stripped).
  def national_number(region, number)
    _s("aether_pn_embed_national_number", _enc(region), _enc(number))
  end

  # ---- validation ----

  # True if the national number is a length the region allows.
  def is_possible_number(region, number)
    _lib.call("aether_pn_embed_is_possible_number", _enc(region), _enc(number)) != 0
  end

  # A ValidationResult int (VR_*) explaining possibility.
  def is_possible_number_with_reason(region, number)
    _lib.call("aether_pn_embed_is_possible_number_with_reason", _enc(region), _enc(number))
  end

  # True if the number matches the region's national-number patterns.
  def is_valid_number(region, number)
    _lib.call("aether_pn_embed_is_valid_number", _enc(region), _enc(number)) != 0
  end

  # True if the number is valid for the given region specifically.
  def is_valid_number_for_region(number, region)
    _lib.call("aether_pn_embed_is_valid_number_for_region", _enc(number), _enc(region)) != 0
  end

  # The PhoneNumberType (a TYPE_* int; -1 for unknown).
  def number_type(region, number)
    _lib.call("aether_pn_embed_number_type", _enc(region), _enc(number))
  end

  # True if the number can be dialled from outside its country.
  def can_be_internationally_dialled(region, number)
    _lib.call("aether_pn_embed_can_be_internationally_dialled", _enc(region), _enc(number)) != 0
  end

  # ---- formatting ----

  # Format the number in the given style (E164 / INTERNATIONAL / NATIONAL / RFC3966).
  def format(region, number, style = NATIONAL)
    _s("aether_pn_embed_format", _enc(region), _enc(number), style.to_i)
  end

  def format_national(region, number)
    format(region, number, NATIONAL)
  end

  def format_international(region, number)
    format(region, number, INTERNATIONAL)
  end

  def format_e164(region, number)
    format(region, number, E164)
  end

  def format_rfc3966(region, number)
    format(region, number, RFC3966)
  end

  # Format as dialled from calling_from towards a number belonging to region.
  def format_out_of_country(region, number, calling_from)
    _s("aether_pn_embed_format_out_of_country", _enc(region), _enc(number), _enc(calling_from))
  end

  # Format a ParsedNumber the way it was originally entered.
  def format_in_original(parsed, calling_from)
    _s("aether_pn_embed_format_in_original", _enc(parsed.pn), _enc(calling_from))
  end

  # ---- relations / helpers ----

  # Compare two numbers; returns a MatchType int (MATCH_*).
  def is_number_match(a, b)
    _lib.call("aether_pn_embed_is_number_match", _enc(a), _enc(b))
  end

  # Trim a too-long number down to the region's longest valid length.
  def truncate_too_long(region, number)
    _s("aether_pn_embed_truncate_too_long", _enc(region), _enc(number))
  end

  # Strip everything but digits (also normalizes wide/eastern digits).
  def normalize_digits_only(str)
    _s("aether_pn_embed_normalize_digits_only", _enc(str))
  end

  # Map vanity letters to their dial-pad digits.
  def convert_alpha_characters(str)
    _s("aether_pn_embed_convert_alpha_characters", _enc(str))
  end

  # True if the input contains vanity letters.
  def is_alpha_number(str)
    _lib.call("aether_pn_embed_is_alpha_number", _enc(str)) != 0
  end

  # The ABI revision the loaded engine reports.
  def abi_version
    _lib.call("aether_pn_embed_abi_version")
  end

  # ---- AsYouTypeFormatter ----

  # Formats a number as it is typed, digit by digit. The engine state is a
  # caller-owned string threaded through each call; every input frees the old
  # state and adopts the new one.
  class AsYouTypeFormatter
    def initialize(region)
      @state = PhoneNumberAe.send(:_s, "aether_pn_embed_ayt_new", PhoneNumberAe.send(:_enc, region))
    end

    # Feed one character; return the formatted-so-far string.
    def input_digit(ch)
      @state = PhoneNumberAe.send(:_s, "aether_pn_embed_ayt_input",
                                  PhoneNumberAe.send(:_enc, @state),
                                  PhoneNumberAe.send(:_enc, ch.to_s))
      result
    end

    # The formatted string accumulated so far.
    def result
      PhoneNumberAe.send(:_s, "aether_pn_embed_ayt_result", PhoneNumberAe.send(:_enc, @state))
    end

    # Reset to an empty state.
    def clear
      @state = PhoneNumberAe.send(:_s, "aether_pn_embed_ayt_clear", PhoneNumberAe.send(:_enc, @state))
    end
  end

  # ---- PhoneNumberMatcher / find_numbers ----

  # One phone number found in free text: its byte span and the raw substring.
  class Match
    attr_reader :start, :end, :raw

    def initialize(start, end_, raw)
      @start = start
      @end = end_
      @raw = raw
    end
  end

  # Find phone numbers in free text. Returns an array of Match.
  def find_numbers(text, region, leniency = LENIENCY_VALID)
    lib = _lib
    t = _enc(text)
    r = _enc(region)
    len = leniency.to_i
    n = lib.call("aether_pn_embed_matcher_count", t, r, len)
    (0...n).map do |i|
      start = lib.call("aether_pn_embed_matcher_start", t, r, len, i)
      finish = lib.call("aether_pn_embed_matcher_end", t, r, len, i)
      raw = lib.take_string(lib.call("aether_pn_embed_matcher_raw", t, r, len, i))
      Match.new(start, finish, raw)
    end
  end

  # ---- ShortNumberInfo (short / emergency numbers) ----

  # Short numbers are dialled as-is: no country code, no national prefix. Each
  # call takes the raw short number plus a region. `expected_cost` returns a
  # ShortNumberCost int (COST_*).
  module ShortNumber
    module_function

    # True if the short number is a possible length for the region.
    def is_possible(region, number)
      PhoneNumberAe.send(:_lib).call("aether_pn_embed_short_is_possible",
                                     PhoneNumberAe.send(:_enc, region),
                                     PhoneNumberAe.send(:_enc, number)) != 0
    end

    # True if the short number matches a short-number pattern for the region.
    def is_valid(region, number)
      PhoneNumberAe.send(:_lib).call("aether_pn_embed_short_is_valid",
                                     PhoneNumberAe.send(:_enc, region),
                                     PhoneNumberAe.send(:_enc, number)) != 0
    end

    # True if the number is an emergency number for the region (e.g. "911" US).
    def is_emergency_number(region, number)
      PhoneNumberAe.send(:_lib).call("aether_pn_embed_short_is_emergency",
                                     PhoneNumberAe.send(:_enc, region),
                                     PhoneNumberAe.send(:_enc, number)) != 0
    end

    # True if dialling the number connects to an emergency service.
    def connects_to_emergency_number(region, number)
      PhoneNumberAe.send(:_lib).call("aether_pn_embed_short_connects_to_emergency",
                                     PhoneNumberAe.send(:_enc, region),
                                     PhoneNumberAe.send(:_enc, number)) != 0
    end

    # True if the short number is carrier-specific.
    def is_carrier_specific(region, number)
      PhoneNumberAe.send(:_lib).call("aether_pn_embed_short_is_carrier_specific",
                                     PhoneNumberAe.send(:_enc, region),
                                     PhoneNumberAe.send(:_enc, number)) != 0
    end

    # True if the short number is an SMS service (short code) for the region.
    def is_sms_service(region, number)
      PhoneNumberAe.send(:_lib).call("aether_pn_embed_short_is_sms_service",
                                     PhoneNumberAe.send(:_enc, region),
                                     PhoneNumberAe.send(:_enc, number)) != 0
    end

    # The expected cost of the short number, as a ShortNumberCost int (COST_*).
    def expected_cost(region, number)
      PhoneNumberAe.send(:_lib).call("aether_pn_embed_short_expected_cost",
                                     PhoneNumberAe.send(:_enc, region),
                                     PhoneNumberAe.send(:_enc, number))
    end

    # An example short number for the region, or "".
    def example_number(region)
      PhoneNumberAe.send(:_s, "aether_pn_embed_short_example_number",
                         PhoneNumberAe.send(:_enc, region))
    end
  end
end
