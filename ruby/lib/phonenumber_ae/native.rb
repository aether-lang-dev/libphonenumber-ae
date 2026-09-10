# frozen_string_literal: true

# Fiddle bindings for the phonenumber engine (libphonenumber_ae.so), ABI v5.
#
# This file is the ONLY place in the Ruby binding that knows about the C ABI.
# Everything above it (`phone_number.rb`) is idiomatic Ruby over these symbols.
# No phone-number logic lives here or anywhere else in this gem — the engine is
# `core/phonenumber.ae`, shared by every language binding.
#
# Library resolution, in order:
#   1. an explicit path passed to `Native.load(path)`
#   2. $LIBPHONENUMBER_AE_LIB       (what the in-tree .tests.ae leaves set)
#   3. native/ bundled next to this gem's lib dir (what a built gem ships)
#   4. the OS loader's own search path

require "fiddle"
require "rbconfig"

module PhoneNumberAe
  # Low-level FFI seam. Everything here mirrors core/embed.ae one-for-one.
  module Native
    LIB_NAME =
      case RbConfig::CONFIG["host_os"]
      when /darwin/ then "libphonenumber_ae.dylib"
      when /mswin|mingw|cygwin/ then "phonenumber_ae.dll"
      else "libphonenumber_ae.so"
      end

    # ---- format styles (ABI constants — append only, never renumber) ----
    E164 = 0
    INTERNATIONAL = 1
    NATIONAL = 2
    RFC3966 = 3

    # ---- number types (number_type result; -1 = unknown) ----
    TYPE_UNKNOWN = -1
    TYPE_FIXED_LINE = 0
    TYPE_MOBILE = 1
    TYPE_TOLL_FREE = 2
    TYPE_PREMIUM_RATE = 3
    TYPE_SHARED_COST = 4
    TYPE_VOIP = 5
    TYPE_PERSONAL_NUMBER = 6
    TYPE_PAGER = 7
    TYPE_UAN = 8
    TYPE_VOICEMAIL = 9
    TYPE_FIXED_LINE_OR_MOBILE = 10

    # ---- ValidationResult (is_possible_number_with_reason) ----
    VR_IS_POSSIBLE = 0
    VR_IS_POSSIBLE_LOCAL_ONLY = 4
    VR_INVALID_COUNTRY_CODE = 1
    VR_TOO_SHORT = 2
    VR_INVALID_LENGTH = 5
    VR_TOO_LONG = 3

    # ---- MatchType (is_number_match) ----
    MATCH_NOT_A_NUMBER = 0
    MATCH_NO_MATCH = 1
    MATCH_SHORT_NSN = 2
    MATCH_NSN = 3
    MATCH_EXACT = 4

    # ---- CountryCodeSource (pn_source) ----
    SRC_FROM_NUMBER_WITH_PLUS = 1
    SRC_FROM_NUMBER_WITH_IDD = 5
    SRC_FROM_NUMBER_WITHOUT_PLUS = 10
    SRC_FROM_DEFAULT_COUNTRY = 20

    # ---- matcher leniency ----
    LENIENCY_POSSIBLE = 0
    LENIENCY_VALID = 1

    # ---- ShortNumberCost (short_expected_cost) ----
    COST_TOLL_FREE = 0
    COST_STANDARD_RATE = 1
    COST_PREMIUM_RATE = 2
    COST_UNKNOWN = 3

    P = Fiddle::TYPE_VOIDP
    I = Fiddle::TYPE_INT
    V = Fiddle::TYPE_VOID

    # name => [argtypes, restype].
    #
    # Every string-returning symbol is declared as TYPE_VOIDP, not
    # Fiddle::TYPE_CONST_STRING: the pointer is caller-owned and has to come
    # back through aether_pn_embed_free_string. Letting Fiddle turn it into a
    # Ruby String directly would lose the pointer and leak the buffer.
    SIGS = {
      # lifecycle / metadata
      "aether_pn_embed_abi_version" => [[], I],
      "aether_pn_embed_free_string" => [[P], V],
      "aether_pn_embed_country_code" => [[P], P],
      "aether_pn_embed_example_number" => [[P], P],
      "aether_pn_embed_example_number_for_type" => [[P, I], P],
      "aether_pn_embed_invalid_example_number" => [[P], P],
      "aether_pn_embed_possible_lengths" => [[P], P],
      "aether_pn_embed_region_code_for_country_code" => [[P], P],
      "aether_pn_embed_is_nanpa_country" => [[P], I],
      "aether_pn_embed_ndd_prefix_for_region" => [[P, I], P],
      "aether_pn_embed_region_count" => [[], I],
      "aether_pn_embed_region_at" => [[I], P],
      "aether_pn_embed_cc_region_count" => [[P], I],
      "aether_pn_embed_cc_region_at" => [[P, I], P],
      # parse + parsed-number accessors
      "aether_pn_embed_parse" => [[P, P], P],
      "aether_pn_embed_national_number" => [[P, P], P],
      "aether_pn_embed_pn_region" => [[P], P],
      "aether_pn_embed_pn_country_code" => [[P], P],
      "aether_pn_embed_pn_national_number" => [[P], P],
      "aether_pn_embed_pn_extension" => [[P], P],
      "aether_pn_embed_pn_italian_leading_zero" => [[P], I],
      "aether_pn_embed_pn_source" => [[P], I],
      "aether_pn_embed_pn_error" => [[P], P],
      "aether_pn_embed_region_code_for_number" => [[P], P],
      "aether_pn_embed_national_significant_number" => [[P], P],
      "aether_pn_embed_length_of_ndc" => [[P], I],
      "aether_pn_embed_length_of_area_code" => [[P], I],
      "aether_pn_embed_is_geographical" => [[P], I],
      # validation
      "aether_pn_embed_is_possible_number" => [[P, P], I],
      "aether_pn_embed_is_possible_number_with_reason" => [[P, P], I],
      "aether_pn_embed_is_valid_number" => [[P, P], I],
      "aether_pn_embed_is_valid_number_for_region" => [[P, P], I],
      "aether_pn_embed_number_type" => [[P, P], I],
      "aether_pn_embed_can_be_internationally_dialled" => [[P, P], I],
      # formatting
      "aether_pn_embed_format" => [[P, P, I], P],
      "aether_pn_embed_format_out_of_country" => [[P, P, P], P],
      "aether_pn_embed_format_in_original" => [[P, P], P],
      # relations / helpers
      "aether_pn_embed_is_number_match" => [[P, P], I],
      "aether_pn_embed_truncate_too_long" => [[P, P], P],
      "aether_pn_embed_normalize_digits_only" => [[P], P],
      "aether_pn_embed_convert_alpha_characters" => [[P], P],
      "aether_pn_embed_is_alpha_number" => [[P], I],
      # AsYouType
      "aether_pn_embed_ayt_new" => [[P], P],
      "aether_pn_embed_ayt_input" => [[P, P], P],
      "aether_pn_embed_ayt_result" => [[P], P],
      "aether_pn_embed_ayt_clear" => [[P], P],
      # matcher
      "aether_pn_embed_matcher_count" => [[P, P, I], I],
      "aether_pn_embed_matcher_start" => [[P, P, I, I], I],
      "aether_pn_embed_matcher_end" => [[P, P, I, I], I],
      "aether_pn_embed_matcher_raw" => [[P, P, I, I], P],
      # ShortNumberInfo
      "aether_pn_embed_short_is_possible" => [[P, P], I],
      "aether_pn_embed_short_is_valid" => [[P, P], I],
      "aether_pn_embed_short_is_emergency" => [[P, P], I],
      "aether_pn_embed_short_connects_to_emergency" => [[P, P], I],
      "aether_pn_embed_short_is_carrier_specific" => [[P, P], I],
      "aether_pn_embed_short_is_sms_service" => [[P, P], I],
      "aether_pn_embed_short_expected_cost" => [[P, P], I],
      "aether_pn_embed_short_example_number" => [[P], P],
      # PhoneNumberToTimeZonesMapper
      "aether_pn_embed_tz_count" => [[P, P], I],
      "aether_pn_embed_tz_at" => [[P, P, I], P],
      "aether_pn_embed_tz_all" => [[P, P], P],
      "aether_pn_embed_tz_unknown" => [[], P],
      # PhoneNumberToCarrierMapper
      "aether_pn_embed_carrier_name" => [[P, P], P],
      "aether_pn_embed_carrier_name_for_valid" => [[P, P], P]
    }.freeze

    # A loaded engine: the Fiddle::Handle plus a memoized Fiddle::Function per
    # exported symbol. `fn.call("aether_pn_embed_country_code", ...)` is the
    # whole calling convention.
    class Lib
      attr_reader :path

      def initialize(path)
        @path = path
        @handle = Fiddle.dlopen(path)
        @fns = {}
        Native::SIGS.each do |name, (argtypes, restype)|
          @fns[name] = Fiddle::Function.new(@handle[name], argtypes, restype)
        rescue Fiddle::DLError => e
          raise Fiddle::DLError, "missing symbol #{name} in #{path}: #{e.message}"
        end
      end

      def call(name, *args)
        (@fns[name] || raise(ArgumentError, "unknown ABI symbol #{name}")).call(*args)
      end

      # Copy an ABI-returned string out and free it through the ABI.
      #
      # Every char* the engine returns is caller-owned; leaking it is the
      # single easiest mistake to make in any of these bindings, so all string
      # reads go through this one method.
      def take_string(ptr)
        return "" if ptr.nil?
        return "" if ptr.is_a?(Integer) && ptr.zero?

        p = ptr.is_a?(Fiddle::Pointer) ? ptr : Fiddle::Pointer.new(ptr)
        return "" if p.null?

        begin
          p.to_s.force_encoding(Encoding::UTF_8)
        ensure
          call("aether_pn_embed_free_string", p)
        end
      end
    end

    class << self
      # Load the engine .so, caching it process-wide. Returns a Lib.
      def load(path = nil)
        return @lib if @lib && path.nil?

        last = nil
        lib = nil
        candidates(path).each do |cand|
          lib = Lib.new(cand)
          break
        rescue Fiddle::DLError => e
          last = e
        end
        if lib.nil?
          raise Fiddle::DLError,
                "could not load the phonenumber engine (#{LIB_NAME}). Set " \
                "LIBPHONENUMBER_AE_LIB to its absolute path, or install a gem " \
                "that bundles it. Last error: #{last}"
        end

        @lib = lib if path.nil?
        lib
      end

      def candidates(explicit = nil)
        return [explicit] if explicit && !explicit.empty?

        out = []
        env = ENV["LIBPHONENUMBER_AE_LIB"]
        out << env if env && !env.empty?
        here = File.dirname(File.expand_path(__dir__)) # ruby/lib
        out << File.join(here, "..", "native", LIB_NAME)
        out << File.join(here, "phonenumber_ae", "native", LIB_NAME)
        out << LIB_NAME
        out
      end
    end
  end
end
