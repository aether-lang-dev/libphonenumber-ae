defmodule PhonenumberAeTest do
  @moduledoc """
  The binding conformance suite (docs/conformance.md, v3).

  Proves the Elixir surface marshals every value shape across the FFI. It is
  NOT a phone-number test suite — the behavioural cases live in the engine's
  own tests and run once, in Aether. Here we sample each KIND of value crossing
  the FFI so the marshalling is proven, not the library.
  """

  # async: false — the tests all share one NIF and one loaded engine.
  use ExUnit.Case, async: false

  doctest PhonenumberAe

  alias PhonenumberAe.{AsYouTypeFormatter, ParsedNumber}

  # ---- the 40 checks (docs/conformance.md, v3) ----

  test "01 country_code US" do
    assert PhonenumberAe.country_code("US") == "1"
  end

  test "02 country_code GB" do
    assert PhonenumberAe.country_code("GB") == "44"
  end

  test "03 unknown region" do
    assert PhonenumberAe.country_code("ZZ") == ""
  end

  test "04 example number" do
    assert PhonenumberAe.example_number("US") == "2015550123"
  end

  test "05 possible lengths" do
    assert PhonenumberAe.possible_lengths("US") == "10"
  end

  test "06 region for cc" do
    assert PhonenumberAe.region_code_for_country_code("44") == "GB"
  end

  test "07 is_nanpa" do
    assert PhonenumberAe.is_nanpa_country?("US") == true
  end

  test "08 region enumeration" do
    assert PhonenumberAe.region_count() >= 200
    regs = PhonenumberAe.regions()
    assert length(regs) == PhonenumberAe.region_count()
    assert String.length(hd(regs)) == 2
    assert PhonenumberAe.region_at(0) == hd(regs)
  end

  test "09 cc region" do
    assert PhonenumberAe.cc_region_at("1", 0) == "US"
    assert hd(PhonenumberAe.regions_for_country_code("1")) == "US"
  end

  test "10-14 parse" do
    num = PhonenumberAe.parse("+1 201 555 0123 ext 42", "US")
    assert ParsedNumber.error(num) == ""
    assert ParsedNumber.national_number(num) == "2015550123"
    assert ParsedNumber.extension(num) == "42"
    assert ParsedNumber.country_code(num) == "1"
    assert ParsedNumber.source(num) == :from_number_with_plus
    assert ParsedNumber.region_code(num) == "US"
  end

  test "15 parse trunk prefix" do
    num = PhonenumberAe.parse("01212345678", "GB")
    assert ParsedNumber.national_number(num) == "1212345678"
  end

  test "16 is_possible" do
    assert PhonenumberAe.is_possible_number?("US", "2015550123") == true
  end

  test "17 reason too short" do
    assert PhonenumberAe.is_possible_number_with_reason("US", "201555") == :too_short
  end

  test "18 is_valid" do
    assert PhonenumberAe.is_valid_number?("US", "2015550123") == true
  end

  test "19 invalid shape" do
    assert PhonenumberAe.is_valid_number?("US", "1015550123") == false
  end

  test "20 valid with +cc" do
    assert PhonenumberAe.is_valid_number?("US", "+12015550123") == true
  end

  test "21 number type" do
    # US fixedLine==mobile -> :fixed_line_or_mobile; GB has distinct patterns.
    assert PhonenumberAe.number_type("US", "2015550123") == :fixed_line_or_mobile
    assert PhonenumberAe.number_type_code("US", "2015550123") == 10
    assert PhonenumberAe.number_type("GB", "2070313000") == :fixed_line
    assert PhonenumberAe.number_type_code("GB", "2070313000") == 0
  end

  test "22 format national" do
    assert PhonenumberAe.format("US", "2015550123", :national) == "(201) 555-0123"
  end

  test "23 format E164" do
    assert PhonenumberAe.format("US", "2015550123", :e164) == "+12015550123"
  end

  test "24 format international" do
    assert PhonenumberAe.format("US", "2015550123", :international) == "+1 201-555-0123"
  end

  test "25 format RFC3966" do
    assert PhonenumberAe.format("US", "2015550123", :rfc3966) == "tel:+1-201-555-0123"
  end

  test "26 match exact" do
    assert PhonenumberAe.is_number_match("+12015550123", "+1 201 555 0123") == :exact
  end

  test "27 match none" do
    assert PhonenumberAe.is_number_match("+12015550123", "+12025550123") == :no_match
  end

  test "28 normalize" do
    assert PhonenumberAe.normalize_digits_only("+1 (201) 555.0123") == "12015550123"
  end

  test "29 alpha" do
    assert PhonenumberAe.convert_alpha_characters("1-800-FLOWERS") == "1-800-3569377"
  end

  test "30 truncate" do
    assert PhonenumberAe.truncate_too_long("US", "20155501239999") == "2015550123"
  end

  test "31 as you type" do
    ayt = AsYouTypeFormatter.new("US")

    {_ayt, out} =
      "2015550123"
      |> String.graphemes()
      |> Enum.reduce({ayt, ""}, fn c, {f, _} -> AsYouTypeFormatter.input_digit(f, c) end)

    assert out == "(201) 555-0123"
  end

  test "32 matcher count" do
    matches = PhonenumberAe.find_numbers("call 201-555-0123 or +1 202 555 0199", "US")
    assert length(matches) == 2
  end

  test "33 matcher raw" do
    matches = PhonenumberAe.find_numbers("call 201-555-0123 now", "US")
    assert hd(matches).raw == "201-555-0123"
  end

  test "34 abi version" do
    assert PhonenumberAe.abi_version() == 7
  end

  # ---- ShortNumberInfo (docs/conformance.md #35–40, v5) ----

  test "35 short emergency US" do
    assert PhonenumberAe.is_emergency_number?("US", "911") == true
  end

  test "36 short not emergency" do
    assert PhonenumberAe.is_emergency_number?("US", "999") == false
  end

  test "37 short emergency GB" do
    assert PhonenumberAe.is_emergency_number?("GB", "999") == true
  end

  test "38 short valid" do
    assert PhonenumberAe.short_is_valid?("US", "911") == true
  end

  test "39 short cost" do
    assert PhonenumberAe.short_expected_cost("US", "911") == :toll_free
    assert PhonenumberAe.short_expected_cost_code("US", "911") == 0
  end

  test "40 short example" do
    assert PhonenumberAe.short_example_number("US") == "112"
  end

  # ---- TimeZones + Carrier + Geocoder (docs/conformance.md #41–45, v6) ----

  test "41 tz US" do
    assert PhonenumberAe.time_zones_for_number("US", "2015550123") == ["America/New_York"]
  end

  test "42 tz GB" do
    assert PhonenumberAe.time_zones_for_number("GB", "2070313000") == ["Europe/London"]
  end

  test "43 tz unknown" do
    assert PhonenumberAe.unknown_time_zone() == "Etc/Unknown"
  end

  test "44 carrier" do
    assert PhonenumberAe.carrier_name_for_number("GB", "7106000000") == "O2"
  end

  test "45 geocoder" do
    assert PhonenumberAe.geo_description_for_number("US", "6502530000") == "Mountain View, CA"
  end

  # ---- extras: the marshalling corners the 45 do not reach ----

  # The NIF takes iodata, so a caller with a plain charlist should not have to
  # flatten it first.
  test "iodata input" do
    assert PhonenumberAe.country_code(~c"US") == "1"
  end

  test "format helpers" do
    assert PhonenumberAe.format_national("US", "2015550123") == "(201) 555-0123"
    assert PhonenumberAe.format_e164("US", "2015550123") == "+12015550123"
    assert PhonenumberAe.format_international("US", "2015550123") == "+1 201-555-0123"
    assert PhonenumberAe.format_rfc3966("US", "2015550123") == "tel:+1-201-555-0123"
  end

  # find_numbers carries start/end offsets alongside the raw text.
  test "match offsets" do
    [m | _] = PhonenumberAe.find_numbers("call 201-555-0123 now", "US")
    assert m.raw == "201-555-0123"
    assert m.end > m.start
  end
end
