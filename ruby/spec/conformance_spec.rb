# frozen_string_literal: true

# The binding conformance suite (docs/conformance.md, v6).
#
# Proves the Ruby binding marshals every value shape across the FFI. It is NOT
# a phone-number test suite — the behavioural cases live in the engine's own
# tests and run once, in Aether.

require "phonenumber_ae"

RSpec.describe PhoneNumberAe do
  it "01 country_code US" do
    expect(PhoneNumberAe.country_code("US")).to eq("1")
  end

  it "02 country_code GB" do
    expect(PhoneNumberAe.country_code("GB")).to eq("44")
  end

  it "03 country_code unknown region" do
    expect(PhoneNumberAe.country_code("ZZ")).to eq("")
  end

  it "04 example_number US" do
    expect(PhoneNumberAe.example_number("US")).to eq("2015550123")
  end

  it "05 possible_lengths US" do
    expect(PhoneNumberAe.possible_lengths("US")).to eq("10")
  end

  it "06 region_code_for_country_code 44" do
    expect(PhoneNumberAe.region_code_for_country_code("44")).to eq("GB")
  end

  it "07 is_nanpa_country US" do
    expect(PhoneNumberAe.is_nanpa_country("US")).to be(true)
  end

  it "08 region enumeration" do
    regs = PhoneNumberAe.regions
    expect(regs.size).to be >= 200
    expect(regs[0].length).to eq(2)
  end

  it "09 cc_region_at 1,0" do
    expect(PhoneNumberAe.regions_for_country_code("1")[0]).to eq("US")
  end

  context "10-14 parse +1 201 555 0123 ext 42 in US" do
    let(:num) { PhoneNumberAe.parse("+1 201 555 0123 ext 42", "US") }

    it "10 pn_national_number" do
      expect(num.national_number).to eq("2015550123")
    end

    it "11 pn_extension" do
      expect(num.extension).to eq("42")
    end

    it "12 pn_country_code" do
      expect(num.country_code).to eq("1")
    end

    it "13 pn_source is FROM_NUMBER_WITH_PLUS" do
      expect(num.source).to eq(PhoneNumberAe::SRC_FROM_NUMBER_WITH_PLUS)
    end

    it "14 region_code_for_number" do
      expect(num.region_code).to eq("US")
    end
  end

  it "15 parse trunk prefix stripped (GB)" do
    expect(PhoneNumberAe.parse("01212345678", "GB").national_number).to eq("1212345678")
  end

  it "16 is_possible_number (yes)" do
    expect(PhoneNumberAe.is_possible_number("US", "2015550123")).to be(true)
  end

  it "17 is_possible_number_with_reason TOO_SHORT" do
    expect(PhoneNumberAe.is_possible_number_with_reason("US", "201555")).to eq(PhoneNumberAe::VR_TOO_SHORT)
  end

  it "18 is_valid_number (yes)" do
    expect(PhoneNumberAe.is_valid_number("US", "2015550123")).to be(true)
  end

  it "19 is_valid_number (wrong shape)" do
    expect(PhoneNumberAe.is_valid_number("US", "1015550123")).to be(false)
  end

  it "20 is_valid_number with +cc" do
    expect(PhoneNumberAe.is_valid_number("US", "+12015550123")).to be(true)
  end

  it "21 number_type US is fixed-line-or-mobile, GB is fixed line" do
    expect(PhoneNumberAe.number_type("US", "2015550123")).to eq(PhoneNumberAe::TYPE_FIXED_LINE_OR_MOBILE)
    expect(PhoneNumberAe.number_type("GB", "2070313000")).to eq(PhoneNumberAe::TYPE_FIXED_LINE)
  end

  it "22 format national" do
    expect(PhoneNumberAe.format("US", "2015550123", PhoneNumberAe::NATIONAL)).to eq("(201) 555-0123")
  end

  it "23 format E164" do
    expect(PhoneNumberAe.format("US", "2015550123", PhoneNumberAe::E164)).to eq("+12015550123")
  end

  it "24 format international" do
    expect(PhoneNumberAe.format("US", "2015550123", PhoneNumberAe::INTERNATIONAL)).to eq("+1 201-555-0123")
  end

  it "25 format RFC3966" do
    expect(PhoneNumberAe.format("US", "2015550123", PhoneNumberAe::RFC3966)).to eq("tel:+1-201-555-0123")
  end

  it "26 is_number_match EXACT" do
    expect(PhoneNumberAe.is_number_match("+12015550123", "+1 201 555 0123")).to eq(PhoneNumberAe::MATCH_EXACT)
  end

  it "27 is_number_match NO_MATCH" do
    expect(PhoneNumberAe.is_number_match("+12015550123", "+12025550123")).to eq(PhoneNumberAe::MATCH_NO_MATCH)
  end

  it "28 normalize_digits_only" do
    expect(PhoneNumberAe.normalize_digits_only("+1 (201) 555.0123")).to eq("12015550123")
  end

  it "29 convert_alpha_characters" do
    expect(PhoneNumberAe.convert_alpha_characters("1-800-FLOWERS")).to eq("1-800-3569377")
  end

  it "30 truncate_too_long" do
    expect(PhoneNumberAe.truncate_too_long("US", "20155501239999")).to eq("2015550123")
  end

  it "31 AsYouType formats as typed" do
    ayt = PhoneNumberAe::AsYouTypeFormatter.new("US")
    out = ""
    "2015550123".each_char { |c| out = ayt.input_digit(c) }
    expect(out).to eq("(201) 555-0123")
  end

  it "32 matcher_count finds two numbers" do
    matches = PhoneNumberAe.find_numbers("call 201-555-0123 or +1 202 555 0199", "US", PhoneNumberAe::LENIENCY_VALID)
    expect(matches.size).to eq(2)
  end

  it "33 matcher_raw" do
    matches = PhoneNumberAe.find_numbers("call 201-555-0123 now", "US", PhoneNumberAe::LENIENCY_VALID)
    expect(matches[0].raw).to eq("201-555-0123")
  end

  it "34 abi version" do
    expect(PhoneNumberAe.abi_version).to eq(6)
  end

  it "35 short is_emergency_number US 911" do
    expect(PhoneNumberAe::ShortNumber.is_emergency_number("US", "911")).to be(true)
  end

  it "36 short is_emergency_number US 999 (that's GB)" do
    expect(PhoneNumberAe::ShortNumber.is_emergency_number("US", "999")).to be(false)
  end

  it "37 short is_emergency_number GB 999" do
    expect(PhoneNumberAe::ShortNumber.is_emergency_number("GB", "999")).to be(true)
  end

  it "38 short is_valid US 911" do
    expect(PhoneNumberAe::ShortNumber.is_valid("US", "911")).to be(true)
  end

  it "39 short expected_cost US 911 is toll-free" do
    expect(PhoneNumberAe::ShortNumber.expected_cost("US", "911")).to eq(PhoneNumberAe::COST_TOLL_FREE)
  end

  it "40 short example_number US" do
    expect(PhoneNumberAe::ShortNumber.example_number("US")).to eq("112")
  end

  it "41 time_zones_for_number US" do
    expect(PhoneNumberAe::TimeZones.time_zones_for_number("US", "2015550123")).to eq(["America/New_York"])
  end

  it "42 time_zones_for_number GB" do
    expect(PhoneNumberAe::TimeZones.time_zones_for_number("GB", "2070313000")).to eq(["Europe/London"])
  end

  it "43 unknown_time_zone" do
    expect(PhoneNumberAe::TimeZones.unknown_time_zone).to eq("Etc/Unknown")
  end

  it "44 carrier_name_for_number GB" do
    expect(PhoneNumberAe::Carrier.carrier_name_for_number("GB", "7106000000")).to eq("O2")
  end

  it "45 geo_description_for_number US" do
    expect(PhoneNumberAe::Geocoder.geo_description_for_number("US", "6502530000")).to eq("Mountain View, CA")
  end
end
