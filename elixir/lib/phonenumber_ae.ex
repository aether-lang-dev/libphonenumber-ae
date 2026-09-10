defmodule PhonenumberAe do
  @moduledoc """
  Validate, parse and format international phone numbers (ABI v2).

  This is a thin Elixir surface over the monorepo's **canonical BEAM NIF**,
  which lives in `erlang/` and is compiled exactly once. There is no C source
  in this directory and no second `.so` — every function here delegates to
  `:phonenumber_ae_nif`, the very same compiled module the Erlang and Gleam
  bindings load. One engine, one NIF, three languages.

  The engine itself (`core/native/libphonenumber_ae.so`) is pure Aether,
  compiled from Google libphonenumber's own metadata. No phone-number logic
  lives in this file: everything marshals to an `aether_pn_embed_*` call across
  the C ABI in `core/embed.ae` (docs/abi.md — 50 symbols, full
  PhoneNumberUtil parity).

      iex> PhonenumberAe.country_code("US")
      "1"
      iex> PhonenumberAe.is_valid_number?("US", "+1 201 555 0123")
      true
      iex> PhonenumberAe.format("US", "2015550123", :national)
      "(201) 555-0123"

  ## Finding the NIF

  `mix` does **not** honour `ERL_LIBS`, unlike `erl`, `escript` and `gleam`.
  So the app built by `erlang/.build.ae` is put on the code path explicitly —
  see `test/test_helper.exs`, which reads `$LIBPHONENUMBER_AE_BEAM_APP` and
  calls `Code.append_path/1`. That is the one wrinkle of consuming an OTP app
  that Mix did not build.

  ## No handles

  The ABI has no opaque handles. A parsed number and an as-you-type state are
  themselves caller-owned STRINGS: `PhonenumberAe.ParsedNumber` and
  `PhonenumberAe.AsYouTypeFormatter` wrap those strings, but every call is a
  direct FFI crossing.
  """

  @typedoc "A format style. Maps onto the ABI's integer selectors (append-only)."
  @type format_style :: :e164 | :international | :national | :rfc3966

  @typedoc "A PhoneNumberType. `:unknown` is the -1 sentinel."
  @type number_type ::
          :unknown
          | :fixed_line
          | :mobile
          | :toll_free
          | :premium_rate
          | :shared_cost
          | :voip
          | :personal_number
          | :pager
          | :uan
          | :voicemail

  @typedoc "A ValidationResult from `is_possible_number_with_reason/2`."
  @type validation_result ::
          :is_possible
          | :is_possible_local_only
          | :invalid_country_code
          | :too_short
          | :invalid_length
          | :too_long

  @typedoc "A MatchType from `is_number_match/2`."
  @type match_type :: :not_a_number | :no_match | :short_nsn | :nsn | :exact

  @typedoc "A CountryCodeSource, from a parsed number's `source`."
  @type country_code_source ::
          :from_number_with_plus
          | :from_number_with_idd
          | :from_number_without_plus
          | :from_default_country
          | :unspecified

  @typedoc "Matcher leniency."
  @type leniency :: :possible | :valid

  # ---- metadata ----

  @doc ~S'The country calling code for a region ("1", "44", …), or "" if unknown.'
  @spec country_code(iodata()) :: binary()
  defdelegate country_code(region), to: :phonenumber_ae_nif

  @doc ~S'An example national number for the region, or "".'
  @spec example_number(iodata()) :: binary()
  defdelegate example_number(region), to: :phonenumber_ae_nif

  @doc ~S'An example national number of a given type (`:mobile`, …), or "".'
  @spec example_number_for_type(iodata(), number_type() | integer()) :: binary()
  def example_number_for_type(region, type) when is_atom(type),
    do: :phonenumber_ae_nif.example_number_for_type(region, type_code(type))

  def example_number_for_type(region, type),
    do: :phonenumber_ae_nif.example_number_for_type(region, type)

  @doc ~S'An example number that is invalid for the region, or "".'
  @spec invalid_example_number(iodata()) :: binary()
  defdelegate invalid_example_number(region), to: :phonenumber_ae_nif

  @doc ~S'The possible-lengths spec for the region (e.g. "9,10"), or "".'
  @spec possible_lengths(iodata()) :: binary()
  defdelegate possible_lengths(region), to: :phonenumber_ae_nif

  @doc ~S'The (main) region for a country calling code, e.g. "44" -> "GB".'
  @spec region_code_for_country_code(iodata() | integer()) :: binary()
  def region_code_for_country_code(cc),
    do: :phonenumber_ae_nif.region_code_for_country_code(to_iodata(cc))

  @doc "True if the region is part of the North American Numbering Plan."
  @spec is_nanpa_country?(iodata()) :: boolean()
  def is_nanpa_country?(region),
    do: :phonenumber_ae_nif.is_nanpa_country(region) != 0

  @doc "The national-direct-dialling prefix for the region."
  @spec ndd_prefix_for_region(iodata(), boolean()) :: binary()
  def ndd_prefix_for_region(region, strip_non_digits \\ false),
    do: :phonenumber_ae_nif.ndd_prefix_for_region(region, bool_int(strip_non_digits))

  # ---- region enumeration ----

  @doc "How many regions the metadata carries."
  @spec region_count() :: non_neg_integer()
  defdelegate region_count(), to: :phonenumber_ae_nif

  @doc "The region id at `index` (0-based)."
  @spec region_at(integer()) :: binary()
  defdelegate region_at(index), to: :phonenumber_ae_nif

  @doc "Every region id the metadata carries, as a list of ISO-3166 codes."
  @spec regions() :: [binary()]
  defdelegate regions(), to: :phonenumber_ae_nif

  @doc "How many regions share a country calling code."
  @spec cc_region_count(iodata() | integer()) :: non_neg_integer()
  def cc_region_count(cc), do: :phonenumber_ae_nif.cc_region_count(to_iodata(cc))

  @doc "The region id at `index` among those sharing a country calling code."
  @spec cc_region_at(iodata() | integer(), integer()) :: binary()
  def cc_region_at(cc, index),
    do: :phonenumber_ae_nif.cc_region_at(to_iodata(cc), index)

  @doc ~S'Every region sharing a country calling code, e.g. "1" -> ["US", …].'
  @spec regions_for_country_code(iodata() | integer()) :: [binary()]
  def regions_for_country_code(cc) do
    bin = to_iodata(cc)
    n = :phonenumber_ae_nif.cc_region_count(bin)

    case n do
      0 -> []
      _ -> Enum.map(0..(n - 1), &:phonenumber_ae_nif.cc_region_at(bin, &1))
    end
  end

  # ---- parse ----

  @doc """
  Parse raw input into a `PhonenumberAe.ParsedNumber`. Read its fields with the
  struct's accessors; `error/1` is non-empty when the parse failed.
  """
  @spec parse(iodata(), iodata()) :: PhonenumberAe.ParsedNumber.t()
  def parse(input, region),
    do: PhonenumberAe.ParsedNumber.new(:phonenumber_ae_nif.parse(input, region))

  @doc "The national number extracted from raw input (cc + punctuation stripped)."
  @spec national_number(iodata(), iodata()) :: binary()
  defdelegate national_number(region, input), to: :phonenumber_ae_nif

  # ---- validity and typing ----

  @doc "True if the national number is a length the region allows."
  @spec is_possible_number?(iodata(), iodata()) :: boolean()
  def is_possible_number?(region, input),
    do: :phonenumber_ae_nif.is_possible_number(region, input) != 0

  @doc "The `t:validation_result/0` for the number (`:too_short`, …)."
  @spec is_possible_number_with_reason(iodata(), iodata()) :: validation_result()
  def is_possible_number_with_reason(region, input),
    do: validation_atom(:phonenumber_ae_nif.is_possible_number_with_reason(region, input))

  @doc "True if the number matches the region's national-number patterns."
  @spec is_valid_number?(iodata(), iodata()) :: boolean()
  def is_valid_number?(region, input),
    do: :phonenumber_ae_nif.is_valid_number(region, input) != 0

  @doc "True if the number is valid for the specific region (not just its cc)."
  @spec is_valid_number_for_region?(iodata(), iodata()) :: boolean()
  def is_valid_number_for_region?(input, region),
    do: :phonenumber_ae_nif.is_valid_number_for_region(input, region) != 0

  @doc "The `t:number_type/0` for the number (`:fixed_line`, `:mobile`, …)."
  @spec number_type(iodata(), iodata()) :: number_type()
  def number_type(region, input),
    do: type_atom(:phonenumber_ae_nif.number_type(region, input))

  @doc "The raw ABI type code (-1 unknown, 0 fixed_line, …)."
  @spec number_type_code(iodata(), iodata()) :: integer()
  def number_type_code(region, input),
    do: :phonenumber_ae_nif.number_type(region, input)

  @doc "True if the number can be dialled from outside its country."
  @spec can_be_internationally_dialled?(iodata(), iodata()) :: boolean()
  def can_be_internationally_dialled?(region, input),
    do: :phonenumber_ae_nif.can_be_internationally_dialled(region, input) != 0

  # ---- formatting ----
  #
  # The ABI takes an integer style; Elixir callers name it with an atom and
  # never see the number. These constants are ABI — append only, never
  # renumber (core/embed.ae). Note the v2 numbering: :e164 is 0 (was 2 in v1).

  @styles %{e164: 0, international: 1, national: 2, rfc3966: 3}

  @doc "Format the number in the given style."
  @spec format(iodata(), iodata(), format_style()) :: binary()
  def format(region, input, style \\ :national) when is_map_key(@styles, style),
    do: :phonenumber_ae_nif.format(region, input, Map.fetch!(@styles, style))

  @doc "`format/3` with the `:national` style."
  @spec format_national(iodata(), iodata()) :: binary()
  def format_national(region, input), do: format(region, input, :national)

  @doc "`format/3` with the `:international` style."
  @spec format_international(iodata(), iodata()) :: binary()
  def format_international(region, input), do: format(region, input, :international)

  @doc "`format/3` with the `:e164` style."
  @spec format_e164(iodata(), iodata()) :: binary()
  def format_e164(region, input), do: format(region, input, :e164)

  @doc "`format/3` with the `:rfc3966` style."
  @spec format_rfc3966(iodata(), iodata()) :: binary()
  def format_rfc3966(region, input), do: format(region, input, :rfc3966)

  @doc "Format as it would be dialled from `calling_from` (the region dialling out)."
  @spec format_out_of_country(iodata(), iodata(), iodata()) :: binary()
  defdelegate format_out_of_country(region, input, calling_from), to: :phonenumber_ae_nif

  @doc "Format a parsed number the way it was originally dialled."
  @spec format_in_original(PhonenumberAe.ParsedNumber.t(), iodata()) :: binary()
  def format_in_original(%PhonenumberAe.ParsedNumber{pn: pn}, calling_from),
    do: :phonenumber_ae_nif.format_in_original(pn, calling_from)

  # ---- relations / helpers ----

  @doc "Compare two numbers; returns a `t:match_type/0` (`:exact`, `:no_match`, …)."
  @spec is_number_match(iodata(), iodata()) :: match_type()
  def is_number_match(a, b),
    do: match_atom(:phonenumber_ae_nif.is_number_match(a, b))

  @doc "Drop digits past the region's maximum possible length."
  @spec truncate_too_long(iodata(), iodata()) :: binary()
  defdelegate truncate_too_long(region, input), to: :phonenumber_ae_nif

  @doc "Keep only the digits of a string (Unicode digits normalised to 0-9)."
  @spec normalize_digits_only(iodata()) :: binary()
  defdelegate normalize_digits_only(s), to: :phonenumber_ae_nif

  @doc "Convert vanity letters to their dial-pad digits (keeping punctuation)."
  @spec convert_alpha_characters(iodata()) :: binary()
  defdelegate convert_alpha_characters(s), to: :phonenumber_ae_nif

  @doc "True if the string contains any vanity letters."
  @spec is_alpha_number?(iodata()) :: boolean()
  def is_alpha_number?(s), do: :phonenumber_ae_nif.is_alpha_number(s) != 0

  # ---- find numbers ----

  @doc """
  Find phone numbers in free text (default leniency `:valid`). Returns a list of
  `PhonenumberAe.Match` structs, each carrying `start`, `end`, and `raw`.
  """
  @spec find_numbers(iodata(), iodata(), leniency()) :: [PhonenumberAe.Match.t()]
  def find_numbers(text, region, leniency \\ :valid) do
    l = leniency_code(leniency)
    n = :phonenumber_ae_nif.matcher_count(text, region, l)

    case n do
      0 ->
        []

      _ ->
        Enum.map(0..(n - 1), fn i ->
          %PhonenumberAe.Match{
            start: :phonenumber_ae_nif.matcher_start(text, region, l, i),
            end: :phonenumber_ae_nif.matcher_end(text, region, l, i),
            raw: :phonenumber_ae_nif.matcher_raw(text, region, l, i)
          }
        end)
    end
  end

  # ---- introspection ----

  @doc "The engine's ABI revision (2)."
  @spec abi_version() :: non_neg_integer()
  defdelegate abi_version(), to: :phonenumber_ae_nif

  # ---- internal ----

  defp bool_int(true), do: 1
  defp bool_int(false), do: 0

  defp to_iodata(cc) when is_integer(cc), do: Integer.to_string(cc)
  defp to_iodata(cc), do: cc

  # ABI number-type codes -> atoms. Append only, never renumber (core/embed.ae).
  defp type_atom(-1), do: :unknown
  defp type_atom(0), do: :fixed_line
  defp type_atom(1), do: :mobile
  defp type_atom(2), do: :toll_free
  defp type_atom(3), do: :premium_rate
  defp type_atom(4), do: :shared_cost
  defp type_atom(5), do: :voip
  defp type_atom(6), do: :personal_number
  defp type_atom(7), do: :pager
  defp type_atom(8), do: :uan
  defp type_atom(9), do: :voicemail
  # A newer engine could return an unseen code; degrade rather than crash.
  defp type_atom(_), do: :unknown

  defp type_code(:unknown), do: -1
  defp type_code(:fixed_line), do: 0
  defp type_code(:mobile), do: 1
  defp type_code(:toll_free), do: 2
  defp type_code(:premium_rate), do: 3
  defp type_code(:shared_cost), do: 4
  defp type_code(:voip), do: 5
  defp type_code(:personal_number), do: 6
  defp type_code(:pager), do: 7
  defp type_code(:uan), do: 8
  defp type_code(:voicemail), do: 9

  # ValidationResult codes -> atoms.
  defp validation_atom(0), do: :is_possible
  defp validation_atom(4), do: :is_possible_local_only
  defp validation_atom(1), do: :invalid_country_code
  defp validation_atom(2), do: :too_short
  defp validation_atom(5), do: :invalid_length
  defp validation_atom(3), do: :too_long
  defp validation_atom(_), do: :invalid_length

  # MatchType codes -> atoms.
  defp match_atom(0), do: :not_a_number
  defp match_atom(1), do: :no_match
  defp match_atom(2), do: :short_nsn
  defp match_atom(3), do: :nsn
  defp match_atom(4), do: :exact
  defp match_atom(_), do: :no_match

  # Matcher leniency codes.
  defp leniency_code(:possible), do: 0
  defp leniency_code(:valid), do: 1
end
