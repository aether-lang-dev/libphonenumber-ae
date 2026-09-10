%%% phonenumber_ae — validate, parse and format international phone numbers.
%%%
%%% A thin Erlang binding over the monorepo's ONE shared native engine
%%% (core/native/libphonenumber_ae.so, compiled from Google libphonenumber's
%%% own metadata as pure Aether). No phone-number logic lives here: every
%%% function marshals to an `aether_pn_embed_*` call (ABI v5, docs/abi.md)
%%% through phonenumber_ae_nif.
%%%
%%%     <<"1">>          = phonenumber_ae:country_code(<<"US">>),
%%%     PN               = phonenumber_ae:parse(<<"+1 201 555 0123 ext 42">>, <<"US">>),
%%%     <<"2015550123">> = phonenumber_ae:pn_national_number(PN),
%%%     true             = phonenumber_ae:is_valid_number(<<"US">>, <<"+1 201 555 0123">>),
%%%     <<"(201) 555-0123">> =
%%%         phonenumber_ae:format(<<"US">>, <<"2015550123">>, national),
%%%     fixed_line       = phonenumber_ae:number_type(<<"US">>, <<"2015550123">>).
%%%
%%% This module's job is to turn the NIF's integer 0/1 predicates into
%%% booleans, its enum integers into atoms, and its format-style atom into the
%%% ABI integer. The engine is stateless — a parsed number and an AsYouType
%%% state are themselves caller-owned STRINGS (binaries here), passed back to
%%% accessor calls — so there is nothing to open or close.
-module(phonenumber_ae).

-export([%% metadata
         country_code/1, example_number/1, example_number_for_type/2,
         invalid_example_number/1, possible_lengths/1,
         region_code_for_country_code/1, is_nanpa_country/1,
         ndd_prefix_for_region/1, ndd_prefix_for_region/2,
         region_count/0, region_at/1, regions/0,
         cc_region_count/1, cc_region_at/2, regions_for_country_code/1,
         %% parse + accessors
         parse/2, national_number/2,
         pn_region/1, pn_country_code/1, pn_national_number/1, pn_extension/1,
         pn_italian_leading_zero/1, pn_source/1, pn_error/1,
         region_code_for_number/1, national_significant_number/1,
         length_of_ndc/1, length_of_area_code/1, is_geographical/1,
         %% validation
         is_possible_number/2, is_possible_number_with_reason/2,
         is_valid_number/2, is_valid_number_for_region/2,
         number_type/2, number_type_code/2,
         can_be_internationally_dialled/2,
         %% formatting
         format/3, format_national/2, format_international/2, format_e164/2,
         format_rfc3966/2, format_out_of_country/3, format_in_original/2,
         %% relations / helpers
         is_number_match/2, truncate_too_long/2, normalize_digits_only/1,
         convert_alpha_characters/1, is_alpha_number/1,
         %% AsYouType
         ayt_new/1, ayt_input/2, ayt_result/1, ayt_clear/1,
         %% matcher / findNumbers
         find_numbers/2, find_numbers/3,
         matcher_count/3, matcher_start/4, matcher_end/4, matcher_raw/4,
         %% ShortNumberInfo
         short_is_possible/2, short_is_valid/2,
         is_emergency_number/2, connects_to_emergency_number/2,
         short_is_carrier_specific/2, short_is_sms_service/2,
         short_expected_cost/2, short_expected_cost_code/2,
         short_example_number/1,
         %% PhoneNumberToTimeZonesMapper
         time_zones_for_number/2, time_zone_count/2, unknown_time_zone/0,
         %% PhoneNumberToCarrierMapper
         carrier_name_for_number/2, carrier_name_for_valid_number/2,
         %% introspection
         abi_version/0]).

-export_type([format_style/0, number_type/0, validation_result/0,
              match_type/0, country_code_source/0, leniency/0,
              short_number_cost/0, parsed_number/0, ayt_state/0, match/0]).

%% The ABI's format styles. These atoms map onto integer selectors, which are
%% append-only and must never be renumbered (core/embed.ae). Note the v2
%% numbering: e164 is 0 (was 2 in v1).
-type format_style() :: e164 | international | national | rfc3966.

%% The PhoneNumberType, as an atom. `unknown` is the -1 sentinel.
-type number_type() :: unknown | fixed_line | mobile | toll_free
                     | premium_rate | shared_cost | voip | personal_number
                     | pager | uan | voicemail | fixed_line_or_mobile.

%% The ValidationResult of is_possible_number_with_reason/2, as an atom.
-type validation_result() :: is_possible | is_possible_local_only
                           | invalid_country_code | too_short
                           | invalid_length | too_long.

%% The MatchType of is_number_match/2, as an atom.
-type match_type() :: not_a_number | no_match | short_nsn | nsn | exact.

%% The CountryCodeSource of pn_source/1, as an atom.
-type country_code_source() :: from_number_with_plus | from_number_with_idd
                             | from_number_without_plus | from_default_country
                             | unspecified.

%% Matcher leniency.
-type leniency() :: possible | valid.

%% The ShortNumberCost of short_expected_cost/2, as an atom.
-type short_number_cost() :: toll_free | standard_rate | premium_rate | unknown.

%% A parsed number: the caller-owned parsed-number string the ABI returns. Pass
%% it to the pn_* accessors. (A binary; the "handle" is just the string.)
-type parsed_number() :: binary().

%% An AsYouTypeFormatter state: also just a caller-owned string.
-type ayt_state() :: binary().

%% A number found in free text: {Start, End, Raw}.
-type match() :: {non_neg_integer(), non_neg_integer(), binary()}.

%%------------------------------------------------------------------
%% Metadata
%%------------------------------------------------------------------

%% The country calling code for a region ("1", "44", …), or <<>> if unknown.
-spec country_code(iodata()) -> binary().
country_code(Region) -> phonenumber_ae_nif:country_code(Region).

%% An example national number for the region, or <<>>.
-spec example_number(iodata()) -> binary().
example_number(Region) -> phonenumber_ae_nif:example_number(Region).

%% An example national number of a given type, or <<>>.
-spec example_number_for_type(iodata(), number_type() | integer()) -> binary().
example_number_for_type(Region, Type) when is_atom(Type) ->
    phonenumber_ae_nif:example_number_for_type(Region, type_code(Type));
example_number_for_type(Region, Type) ->
    phonenumber_ae_nif:example_number_for_type(Region, Type).

%% An example number that is invalid for the region, or <<>>.
-spec invalid_example_number(iodata()) -> binary().
invalid_example_number(Region) ->
    phonenumber_ae_nif:invalid_example_number(Region).

%% The possible-lengths spec for the region (e.g. <<"9,10">>), or <<>>.
-spec possible_lengths(iodata()) -> binary().
possible_lengths(Region) -> phonenumber_ae_nif:possible_lengths(Region).

%% The (main) region for a country calling code, e.g. "44" -> <<"GB">>.
-spec region_code_for_country_code(iodata()) -> binary().
region_code_for_country_code(Cc) ->
    phonenumber_ae_nif:region_code_for_country_code(to_iodata(Cc)).

%% True if the region is part of the North American Numbering Plan.
-spec is_nanpa_country(iodata()) -> boolean().
is_nanpa_country(Region) ->
    to_bool(phonenumber_ae_nif:is_nanpa_country(Region)).

%% The national-direct-dialling prefix for the region (e.g. <<"1">>, <<"0">>).
-spec ndd_prefix_for_region(iodata()) -> binary().
ndd_prefix_for_region(Region) -> ndd_prefix_for_region(Region, false).

%% As above; StripNonDigits drops any '~'-style formatting characters.
-spec ndd_prefix_for_region(iodata(), boolean()) -> binary().
ndd_prefix_for_region(Region, StripNonDigits) ->
    phonenumber_ae_nif:ndd_prefix_for_region(Region, bool_int(StripNonDigits)).

%%------------------------------------------------------------------
%% Region enumeration
%%------------------------------------------------------------------

-spec region_count() -> non_neg_integer().
region_count() -> phonenumber_ae_nif:region_count().

-spec region_at(integer()) -> binary().
region_at(Index) -> phonenumber_ae_nif:region_at(Index).

%% Every region id the metadata carries, as a list of ISO-3166 codes.
-spec regions() -> [binary()].
regions() -> phonenumber_ae_nif:regions().

%% How many regions share a country calling code.
-spec cc_region_count(iodata()) -> non_neg_integer().
cc_region_count(Cc) -> phonenumber_ae_nif:cc_region_count(to_iodata(Cc)).

%% The region id at Index among those sharing a country calling code.
-spec cc_region_at(iodata(), integer()) -> binary().
cc_region_at(Cc, Index) -> phonenumber_ae_nif:cc_region_at(to_iodata(Cc), Index).

%% Every region sharing a country calling code (e.g. "1" -> [<<"US">>, ...]).
-spec regions_for_country_code(iodata()) -> [binary()].
regions_for_country_code(Cc) ->
    Bin = to_iodata(Cc),
    N = phonenumber_ae_nif:cc_region_count(Bin),
    [phonenumber_ae_nif:cc_region_at(Bin, I) || I <- lists:seq(0, N - 1)].

%%------------------------------------------------------------------
%% Parse + parsed-number accessors
%%------------------------------------------------------------------

%% Parse raw input into a caller-owned parsed-number value. Read its fields with
%% the pn_* accessors below. pn_error/1 is non-empty if the parse failed.
-spec parse(iodata(), iodata()) -> parsed_number().
parse(Input, Region) -> phonenumber_ae_nif:parse(Input, Region).

%% The national number extracted from raw input (cc + punctuation stripped).
-spec national_number(iodata(), iodata()) -> binary().
national_number(Region, Input) ->
    phonenumber_ae_nif:national_number(Region, Input).

-spec pn_region(parsed_number()) -> binary().
pn_region(Pn) -> phonenumber_ae_nif:pn_region(Pn).

-spec pn_country_code(parsed_number()) -> binary().
pn_country_code(Pn) -> phonenumber_ae_nif:pn_country_code(Pn).

-spec pn_national_number(parsed_number()) -> binary().
pn_national_number(Pn) -> phonenumber_ae_nif:pn_national_number(Pn).

-spec pn_extension(parsed_number()) -> binary().
pn_extension(Pn) -> phonenumber_ae_nif:pn_extension(Pn).

-spec pn_italian_leading_zero(parsed_number()) -> boolean().
pn_italian_leading_zero(Pn) ->
    to_bool(phonenumber_ae_nif:pn_italian_leading_zero(Pn)).

%% The CountryCodeSource, as an atom.
-spec pn_source(parsed_number()) -> country_code_source().
pn_source(Pn) -> source_atom(phonenumber_ae_nif:pn_source(Pn)).

%% The parse error, or <<>> if the parse succeeded.
-spec pn_error(parsed_number()) -> binary().
pn_error(Pn) -> phonenumber_ae_nif:pn_error(Pn).

-spec region_code_for_number(parsed_number()) -> binary().
region_code_for_number(Pn) -> phonenumber_ae_nif:region_code_for_number(Pn).

-spec national_significant_number(parsed_number()) -> binary().
national_significant_number(Pn) ->
    phonenumber_ae_nif:national_significant_number(Pn).

-spec length_of_ndc(parsed_number()) -> integer().
length_of_ndc(Pn) -> phonenumber_ae_nif:length_of_ndc(Pn).

-spec length_of_area_code(parsed_number()) -> integer().
length_of_area_code(Pn) -> phonenumber_ae_nif:length_of_area_code(Pn).

-spec is_geographical(parsed_number()) -> boolean().
is_geographical(Pn) -> to_bool(phonenumber_ae_nif:is_geographical(Pn)).

%%------------------------------------------------------------------
%% Validity and typing
%%------------------------------------------------------------------

%% True if the national number is a length the region allows.
-spec is_possible_number(iodata(), iodata()) -> boolean().
is_possible_number(Region, Input) ->
    to_bool(phonenumber_ae_nif:is_possible_number(Region, Input)).

%% The ValidationResult as an atom (is_possible, too_short, …).
-spec is_possible_number_with_reason(iodata(), iodata()) -> validation_result().
is_possible_number_with_reason(Region, Input) ->
    validation_atom(
      phonenumber_ae_nif:is_possible_number_with_reason(Region, Input)).

%% True if the number matches the region's national-number patterns.
-spec is_valid_number(iodata(), iodata()) -> boolean().
is_valid_number(Region, Input) ->
    to_bool(phonenumber_ae_nif:is_valid_number(Region, Input)).

%% True if the number is valid for the specific region (not just its cc).
-spec is_valid_number_for_region(iodata(), iodata()) -> boolean().
is_valid_number_for_region(Input, Region) ->
    to_bool(phonenumber_ae_nif:is_valid_number_for_region(Input, Region)).

%% The PhoneNumberType as an atom (unknown | fixed_line | mobile | ...).
-spec number_type(iodata(), iodata()) -> number_type().
number_type(Region, Input) ->
    type_atom(phonenumber_ae_nif:number_type(Region, Input)).

%% The raw ABI type code (-1 unknown, 0 fixed_line, …). For a caller that wants
%% the number rather than the atom.
-spec number_type_code(iodata(), iodata()) -> integer().
number_type_code(Region, Input) ->
    phonenumber_ae_nif:number_type(Region, Input).

%% True if the number can be dialled from outside its country.
-spec can_be_internationally_dialled(iodata(), iodata()) -> boolean().
can_be_internationally_dialled(Region, Input) ->
    to_bool(phonenumber_ae_nif:can_be_internationally_dialled(Region, Input)).

%%------------------------------------------------------------------
%% Formatting
%%------------------------------------------------------------------

%% Format the number in the given style.
-spec format(iodata(), iodata(), format_style()) -> binary().
format(Region, Input, Style) ->
    phonenumber_ae_nif:format(Region, Input, style_code(Style)).

-spec format_national(iodata(), iodata()) -> binary().
format_national(Region, Input) -> format(Region, Input, national).

-spec format_international(iodata(), iodata()) -> binary().
format_international(Region, Input) -> format(Region, Input, international).

-spec format_e164(iodata(), iodata()) -> binary().
format_e164(Region, Input) -> format(Region, Input, e164).

-spec format_rfc3966(iodata(), iodata()) -> binary().
format_rfc3966(Region, Input) -> format(Region, Input, rfc3966).

%% Format as it would be dialled from CallingFrom (the region dialling out).
-spec format_out_of_country(iodata(), iodata(), iodata()) -> binary().
format_out_of_country(Region, Input, CallingFrom) ->
    phonenumber_ae_nif:format_out_of_country(Region, Input, CallingFrom).

%% Format a parsed number the way it was originally dialled.
-spec format_in_original(parsed_number(), iodata()) -> binary().
format_in_original(Pn, CallingFrom) ->
    phonenumber_ae_nif:format_in_original(Pn, CallingFrom).

%%------------------------------------------------------------------
%% Relations / helpers
%%------------------------------------------------------------------

%% Compare two numbers; returns a MatchType atom (exact, no_match, …).
-spec is_number_match(iodata(), iodata()) -> match_type().
is_number_match(A, B) ->
    match_atom(phonenumber_ae_nif:is_number_match(A, B)).

%% Drop digits past the region's maximum possible length.
-spec truncate_too_long(iodata(), iodata()) -> binary().
truncate_too_long(Region, Input) ->
    phonenumber_ae_nif:truncate_too_long(Region, Input).

%% Keep only the digits of a string (Unicode digits normalised to 0-9).
-spec normalize_digits_only(iodata()) -> binary().
normalize_digits_only(S) -> phonenumber_ae_nif:normalize_digits_only(S).

%% Convert vanity letters to their dial-pad digits (keeping punctuation).
-spec convert_alpha_characters(iodata()) -> binary().
convert_alpha_characters(S) ->
    phonenumber_ae_nif:convert_alpha_characters(S).

%% True if the string contains any vanity letters.
-spec is_alpha_number(iodata()) -> boolean().
is_alpha_number(S) -> to_bool(phonenumber_ae_nif:is_alpha_number(S)).

%%------------------------------------------------------------------
%% AsYouTypeFormatter (state threaded as a caller-owned binary)
%%------------------------------------------------------------------

%% A fresh formatter state for a region. Feed it with ayt_input/2.
-spec ayt_new(iodata()) -> ayt_state().
ayt_new(Region) -> phonenumber_ae_nif:ayt_new(Region).

%% Feed one character; returns a NEW state (the old one is now stale).
-spec ayt_input(ayt_state(), iodata()) -> ayt_state().
ayt_input(State, Ch) -> phonenumber_ae_nif:ayt_input(State, Ch).

%% The formatted-so-far string for a state.
-spec ayt_result(ayt_state()) -> binary().
ayt_result(State) -> phonenumber_ae_nif:ayt_result(State).

%% Reset the formatter, returning a cleared state for the same region.
-spec ayt_clear(ayt_state()) -> ayt_state().
ayt_clear(State) -> phonenumber_ae_nif:ayt_clear(State).

%%------------------------------------------------------------------
%% PhoneNumberMatcher / findNumbers
%%------------------------------------------------------------------

%% Find phone numbers in free text (default leniency: valid). Returns a list of
%% {Start, End, Raw} tuples.
-spec find_numbers(iodata(), iodata()) -> [match()].
find_numbers(Text, Region) -> find_numbers(Text, Region, valid).

-spec find_numbers(iodata(), iodata(), leniency()) -> [match()].
find_numbers(Text, Region, Leniency) ->
    L = leniency_code(Leniency),
    N = phonenumber_ae_nif:matcher_count(Text, Region, L),
    [{phonenumber_ae_nif:matcher_start(Text, Region, L, I),
      phonenumber_ae_nif:matcher_end(Text, Region, L, I),
      phonenumber_ae_nif:matcher_raw(Text, Region, L, I)}
     || I <- lists:seq(0, N - 1)].

%% Lower-level matcher accessors, for a caller that wants to drive the count
%% and per-index reads directly. Leniency is an atom (possible | valid).
-spec matcher_count(iodata(), iodata(), leniency()) -> non_neg_integer().
matcher_count(Text, Region, Leniency) ->
    phonenumber_ae_nif:matcher_count(Text, Region, leniency_code(Leniency)).

-spec matcher_start(iodata(), iodata(), leniency(), integer()) -> integer().
matcher_start(Text, Region, Leniency, Idx) ->
    phonenumber_ae_nif:matcher_start(Text, Region, leniency_code(Leniency), Idx).

-spec matcher_end(iodata(), iodata(), leniency(), integer()) -> integer().
matcher_end(Text, Region, Leniency, Idx) ->
    phonenumber_ae_nif:matcher_end(Text, Region, leniency_code(Leniency), Idx).

-spec matcher_raw(iodata(), iodata(), leniency(), integer()) -> binary().
matcher_raw(Text, Region, Leniency, Idx) ->
    phonenumber_ae_nif:matcher_raw(Text, Region, leniency_code(Leniency), Idx).

%%------------------------------------------------------------------
%% ShortNumberInfo (short / emergency numbers)
%%------------------------------------------------------------------
%%
%% Short numbers are dialled as-is (no country code, no national prefix): the
%% input is the raw short number plus a region.

%% True if the short number is a possible length for the region.
-spec short_is_possible(iodata(), iodata()) -> boolean().
short_is_possible(Region, Input) ->
    to_bool(phonenumber_ae_nif:short_is_possible(Region, Input)).

%% True if the short number is valid (carrier-independent) for the region.
-spec short_is_valid(iodata(), iodata()) -> boolean().
short_is_valid(Region, Input) ->
    to_bool(phonenumber_ae_nif:short_is_valid(Region, Input)).

%% True if the short number is an emergency number for the region.
-spec is_emergency_number(iodata(), iodata()) -> boolean().
is_emergency_number(Region, Input) ->
    to_bool(phonenumber_ae_nif:short_is_emergency(Region, Input)).

%% True if dialling the number would connect to an emergency service.
-spec connects_to_emergency_number(iodata(), iodata()) -> boolean().
connects_to_emergency_number(Region, Input) ->
    to_bool(phonenumber_ae_nif:short_connects_to_emergency(Region, Input)).

%% True if the short number is carrier-specific in the region.
-spec short_is_carrier_specific(iodata(), iodata()) -> boolean().
short_is_carrier_specific(Region, Input) ->
    to_bool(phonenumber_ae_nif:short_is_carrier_specific(Region, Input)).

%% True if the short number is for an SMS service in the region.
-spec short_is_sms_service(iodata(), iodata()) -> boolean().
short_is_sms_service(Region, Input) ->
    to_bool(phonenumber_ae_nif:short_is_sms_service(Region, Input)).

%% The expected cost of the short number, as a ShortNumberCost atom
%% (toll_free | standard_rate | premium_rate | unknown).
-spec short_expected_cost(iodata(), iodata()) -> short_number_cost().
short_expected_cost(Region, Input) ->
    cost_atom(phonenumber_ae_nif:short_expected_cost(Region, Input)).

%% The raw ABI ShortNumberCost code (0 toll_free, …). For a caller that wants
%% the number rather than the atom.
-spec short_expected_cost_code(iodata(), iodata()) -> integer().
short_expected_cost_code(Region, Input) ->
    phonenumber_ae_nif:short_expected_cost(Region, Input).

%% An example short number for the region, or <<>>.
-spec short_example_number(iodata()) -> binary().
short_example_number(Region) ->
    phonenumber_ae_nif:short_example_number(Region).

%%------------------------------------------------------------------
%% PhoneNumberToTimeZonesMapper (timezone lookup)
%%------------------------------------------------------------------

%% The IANA time-zone ids for a number, as a list. When the engine knows no
%% zone (count 0) the result is a single-element list of the unknown zone,
%% mirroring the other bindings — never an empty list.
-spec time_zones_for_number(iodata(), iodata()) -> [binary()].
time_zones_for_number(Region, Input) ->
    case phonenumber_ae_nif:tz_count(Region, Input) of
        0 -> [unknown_time_zone()];
        N -> [phonenumber_ae_nif:tz_at(Region, Input, I)
              || I <- lists:seq(0, N - 1)]
    end.

%% How many time zones the engine maps the number to (0 = only the unknown zone).
-spec time_zone_count(iodata(), iodata()) -> non_neg_integer().
time_zone_count(Region, Input) ->
    phonenumber_ae_nif:tz_count(Region, Input).

%% The engine's sentinel unknown zone, <<"Etc/Unknown">>.
-spec unknown_time_zone() -> binary().
unknown_time_zone() -> phonenumber_ae_nif:tz_unknown().

%%------------------------------------------------------------------
%% PhoneNumberToCarrierMapper (English carrier names)
%%------------------------------------------------------------------

%% The carrier name for a number (English), or <<>> if none is known.
-spec carrier_name_for_number(iodata(), iodata()) -> binary().
carrier_name_for_number(Region, Input) ->
    phonenumber_ae_nif:carrier_name(Region, Input).

%% The carrier name, but only when the number is valid; else <<>>.
-spec carrier_name_for_valid_number(iodata(), iodata()) -> binary().
carrier_name_for_valid_number(Region, Input) ->
    phonenumber_ae_nif:carrier_name_for_valid(Region, Input).

%%------------------------------------------------------------------
%% Introspection
%%------------------------------------------------------------------

%% The engine's ABI revision (5).
-spec abi_version() -> non_neg_integer().
abi_version() -> phonenumber_ae_nif:abi_version().

%%------------------------------------------------------------------
%% Internal — ABI constant <-> atom mapping (append only, never renumber)
%%------------------------------------------------------------------

to_bool(0) -> false;
to_bool(_) -> true.

bool_int(true)  -> 1;
bool_int(false) -> 0.

%% A country calling code may be given as an integer (44) or iodata (<<"44">>).
to_iodata(Cc) when is_integer(Cc) -> integer_to_binary(Cc);
to_iodata(Cc)                     -> Cc.

%% ABI format-style selectors (core/embed.ae, v2): E164=0, INTERNATIONAL=1,
%% NATIONAL=2, RFC3966=3.
style_code(e164)          -> 0;
style_code(international)  -> 1;
style_code(national)      -> 2;
style_code(rfc3966)       -> 3.

%% ABI number-type codes <-> atoms.
type_atom(-1) -> unknown;
type_atom(0)  -> fixed_line;
type_atom(1)  -> mobile;
type_atom(2)  -> toll_free;
type_atom(3)  -> premium_rate;
type_atom(4)  -> shared_cost;
type_atom(5)  -> voip;
type_atom(6)  -> personal_number;
type_atom(7)  -> pager;
type_atom(8)  -> uan;
type_atom(9)  -> voicemail;
type_atom(10) -> fixed_line_or_mobile;
%% A newer engine could return a code this build has not seen; degrade rather
%% than crash. The append-only rule means the number is still meaningful.
type_atom(_)  -> unknown.

type_code(unknown)         -> -1;
type_code(fixed_line)      -> 0;
type_code(mobile)          -> 1;
type_code(toll_free)       -> 2;
type_code(premium_rate)    -> 3;
type_code(shared_cost)     -> 4;
type_code(voip)            -> 5;
type_code(personal_number) -> 6;
type_code(pager)           -> 7;
type_code(uan)             -> 8;
type_code(voicemail)       -> 9;
type_code(fixed_line_or_mobile) -> 10.

%% ValidationResult codes -> atoms.
validation_atom(0) -> is_possible;
validation_atom(4) -> is_possible_local_only;
validation_atom(1) -> invalid_country_code;
validation_atom(2) -> too_short;
validation_atom(5) -> invalid_length;
validation_atom(3) -> too_long;
validation_atom(_) -> invalid_length.

%% MatchType codes -> atoms.
match_atom(0) -> not_a_number;
match_atom(1) -> no_match;
match_atom(2) -> short_nsn;
match_atom(3) -> nsn;
match_atom(4) -> exact;
match_atom(_) -> no_match.

%% CountryCodeSource codes -> atoms.
source_atom(1)  -> from_number_with_plus;
source_atom(5)  -> from_number_with_idd;
source_atom(10) -> from_number_without_plus;
source_atom(20) -> from_default_country;
source_atom(_)  -> unspecified.

%% Matcher leniency codes.
leniency_code(possible) -> 0;
leniency_code(valid)    -> 1.

%% ShortNumberCost codes -> atoms (0 toll-free, 1 standard, 2 premium, 3 unknown).
cost_atom(0) -> toll_free;
cost_atom(1) -> standard_rate;
cost_atom(2) -> premium_rate;
cost_atom(3) -> unknown;
%% A newer engine could return a code this build has not seen; degrade rather
%% than crash. The append-only rule means the number is still meaningful.
cost_atom(_) -> unknown.
