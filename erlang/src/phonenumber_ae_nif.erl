%%% phonenumber_ae_nif — the raw NIF surface (ABI v7).
%%%
%%% This module exists only to load c_src/phonenumber_ae_nif.c and to give each
%%% native function a stub. Nothing here is meant to be called directly;
%%% `phonenumber_ae` is the module with the friendly API. It is exported all the
%%% same, because Elixir and Gleam bind against THIS module: they defdelegate /
%%% @external straight to these arities rather than each shipping their own
%%% copy of the C.
%%%
%%% Every stub raises if the NIF failed to load, which is the standard idiom —
%%% a stub that silently returned a wrong answer would be far worse than a crash
%%% pointing at the real problem.
-module(phonenumber_ae_nif).

-export([%% metadata
         country_code/1, example_number/1, example_number_for_type/2,
         invalid_example_number/1, possible_lengths/1,
         region_code_for_country_code/1, is_nanpa_country/1,
         ndd_prefix_for_region/2, region_count/0, region_at/1, regions/0,
         cc_region_count/1, cc_region_at/2,
         %% parse + accessors
         parse/2, national_number/2,
         pn_region/1, pn_country_code/1, pn_national_number/1, pn_extension/1,
         pn_italian_leading_zero/1, pn_source/1, pn_error/1,
         region_code_for_number/1, national_significant_number/1,
         length_of_ndc/1, length_of_area_code/1, is_geographical/1,
         %% validation
         is_possible_number/2, is_possible_number_with_reason/2,
         is_valid_number/2, is_valid_number_for_region/2, number_type/2,
         can_be_internationally_dialled/2,
         %% formatting
         format/3, format_out_of_country/3, format_in_original/2,
         %% relations / helpers
         is_number_match/2, truncate_too_long/2, normalize_digits_only/1,
         convert_alpha_characters/1, is_alpha_number/1,
         %% AsYouType
         ayt_new/1, ayt_input/2, ayt_result/1, ayt_clear/1,
         %% matcher
         matcher_count/3, matcher_start/4, matcher_end/4, matcher_raw/4,
         %% ShortNumberInfo
         short_is_possible/2, short_is_valid/2, short_is_emergency/2,
         short_connects_to_emergency/2, short_is_carrier_specific/2,
         short_is_sms_service/2, short_expected_cost/2, short_example_number/1,
         %% PhoneNumberToTimeZonesMapper
         tz_count/2, tz_at/3, tz_all/2, tz_unknown/0,
         %% PhoneNumberToCarrierMapper
         carrier_name/3, carrier_name_for_valid/3,
         %% PhoneNumberOfflineGeocoder
         geo_description/3, geo_description_for_valid/3,
         %% introspection
         abi_version/0]).

-on_load(init/0).

-define(APPNAME, phonenumber_ae_nif).
-define(LIBNAME, phonenumber_ae_nif).

%%------------------------------------------------------------------
%% Loading
%%------------------------------------------------------------------

%% Load the NIF, handing the C side our priv/ directory so it can find the
%% bundled engine .so without guessing. The C load callback tries
%% $LIBPHONENUMBER_AE_LIB first, then priv/, then the OS loader path.
init() ->
    PrivDir = priv_dir(),
    SoPath = filename:join(PrivDir, atom_to_list(?LIBNAME)),
    erlang:load_nif(SoPath, list_to_binary(PrivDir)).

%% code:priv_dir/1 fails when the app is only on the code path as loose beams
%% (which is how a bare `erl -pa ebin` run looks); fall back to the sibling of
%% the ebin directory this module was loaded from.
priv_dir() ->
    case code:priv_dir(?APPNAME) of
        {error, bad_name} ->
            case code:which(?MODULE) of
                Beam when is_list(Beam) ->
                    filename:join(filename:dirname(filename:dirname(Beam)), "priv");
                _ ->
                    "priv"
            end;
        Dir ->
            Dir
    end.

%%------------------------------------------------------------------
%% Stubs — replaced by the NIF at load time
%%------------------------------------------------------------------

%% ---- metadata ----

-spec country_code(iodata()) -> binary().
country_code(_Region) -> not_loaded(?LINE).

-spec example_number(iodata()) -> binary().
example_number(_Region) -> not_loaded(?LINE).

-spec example_number_for_type(iodata(), integer()) -> binary().
example_number_for_type(_Region, _Type) -> not_loaded(?LINE).

-spec invalid_example_number(iodata()) -> binary().
invalid_example_number(_Region) -> not_loaded(?LINE).

-spec possible_lengths(iodata()) -> binary().
possible_lengths(_Region) -> not_loaded(?LINE).

-spec region_code_for_country_code(iodata()) -> binary().
region_code_for_country_code(_Cc) -> not_loaded(?LINE).

-spec is_nanpa_country(iodata()) -> integer().
is_nanpa_country(_Region) -> not_loaded(?LINE).

-spec ndd_prefix_for_region(iodata(), integer()) -> binary().
ndd_prefix_for_region(_Region, _StripNonDigits) -> not_loaded(?LINE).

-spec region_count() -> non_neg_integer().
region_count() -> not_loaded(?LINE).

-spec region_at(integer()) -> binary().
region_at(_Index) -> not_loaded(?LINE).

-spec regions() -> [binary()].
regions() -> not_loaded(?LINE).

-spec cc_region_count(iodata()) -> integer().
cc_region_count(_Cc) -> not_loaded(?LINE).

-spec cc_region_at(iodata(), integer()) -> binary().
cc_region_at(_Cc, _Index) -> not_loaded(?LINE).

%% ---- parse + accessors ----

-spec parse(iodata(), iodata()) -> binary().
parse(_Input, _Region) -> not_loaded(?LINE).

-spec national_number(iodata(), iodata()) -> binary().
national_number(_Region, _Input) -> not_loaded(?LINE).

-spec pn_region(iodata()) -> binary().
pn_region(_Pn) -> not_loaded(?LINE).

-spec pn_country_code(iodata()) -> binary().
pn_country_code(_Pn) -> not_loaded(?LINE).

-spec pn_national_number(iodata()) -> binary().
pn_national_number(_Pn) -> not_loaded(?LINE).

-spec pn_extension(iodata()) -> binary().
pn_extension(_Pn) -> not_loaded(?LINE).

-spec pn_italian_leading_zero(iodata()) -> integer().
pn_italian_leading_zero(_Pn) -> not_loaded(?LINE).

-spec pn_source(iodata()) -> integer().
pn_source(_Pn) -> not_loaded(?LINE).

-spec pn_error(iodata()) -> binary().
pn_error(_Pn) -> not_loaded(?LINE).

-spec region_code_for_number(iodata()) -> binary().
region_code_for_number(_Pn) -> not_loaded(?LINE).

-spec national_significant_number(iodata()) -> binary().
national_significant_number(_Pn) -> not_loaded(?LINE).

-spec length_of_ndc(iodata()) -> integer().
length_of_ndc(_Pn) -> not_loaded(?LINE).

-spec length_of_area_code(iodata()) -> integer().
length_of_area_code(_Pn) -> not_loaded(?LINE).

-spec is_geographical(iodata()) -> integer().
is_geographical(_Pn) -> not_loaded(?LINE).

%% ---- validation ----

-spec is_possible_number(iodata(), iodata()) -> integer().
is_possible_number(_Region, _Input) -> not_loaded(?LINE).

-spec is_possible_number_with_reason(iodata(), iodata()) -> integer().
is_possible_number_with_reason(_Region, _Input) -> not_loaded(?LINE).

-spec is_valid_number(iodata(), iodata()) -> integer().
is_valid_number(_Region, _Input) -> not_loaded(?LINE).

-spec is_valid_number_for_region(iodata(), iodata()) -> integer().
is_valid_number_for_region(_Input, _Region) -> not_loaded(?LINE).

-spec number_type(iodata(), iodata()) -> integer().
number_type(_Region, _Input) -> not_loaded(?LINE).

-spec can_be_internationally_dialled(iodata(), iodata()) -> integer().
can_be_internationally_dialled(_Region, _Input) -> not_loaded(?LINE).

%% ---- formatting ----

-spec format(iodata(), iodata(), integer()) -> binary().
format(_Region, _Input, _Fmt) -> not_loaded(?LINE).

-spec format_out_of_country(iodata(), iodata(), iodata()) -> binary().
format_out_of_country(_Region, _Input, _CallingFrom) -> not_loaded(?LINE).

-spec format_in_original(iodata(), iodata()) -> binary().
format_in_original(_Pn, _CallingFrom) -> not_loaded(?LINE).

%% ---- relations / helpers ----

-spec is_number_match(iodata(), iodata()) -> integer().
is_number_match(_A, _B) -> not_loaded(?LINE).

-spec truncate_too_long(iodata(), iodata()) -> binary().
truncate_too_long(_Region, _Input) -> not_loaded(?LINE).

-spec normalize_digits_only(iodata()) -> binary().
normalize_digits_only(_S) -> not_loaded(?LINE).

-spec convert_alpha_characters(iodata()) -> binary().
convert_alpha_characters(_S) -> not_loaded(?LINE).

-spec is_alpha_number(iodata()) -> integer().
is_alpha_number(_S) -> not_loaded(?LINE).

%% ---- AsYouType ----

-spec ayt_new(iodata()) -> binary().
ayt_new(_Region) -> not_loaded(?LINE).

-spec ayt_input(iodata(), iodata()) -> binary().
ayt_input(_State, _Ch) -> not_loaded(?LINE).

-spec ayt_result(iodata()) -> binary().
ayt_result(_State) -> not_loaded(?LINE).

-spec ayt_clear(iodata()) -> binary().
ayt_clear(_State) -> not_loaded(?LINE).

%% ---- matcher ----

-spec matcher_count(iodata(), iodata(), integer()) -> integer().
matcher_count(_Text, _Region, _Leniency) -> not_loaded(?LINE).

-spec matcher_start(iodata(), iodata(), integer(), integer()) -> integer().
matcher_start(_Text, _Region, _Leniency, _Idx) -> not_loaded(?LINE).

-spec matcher_end(iodata(), iodata(), integer(), integer()) -> integer().
matcher_end(_Text, _Region, _Leniency, _Idx) -> not_loaded(?LINE).

-spec matcher_raw(iodata(), iodata(), integer(), integer()) -> binary().
matcher_raw(_Text, _Region, _Leniency, _Idx) -> not_loaded(?LINE).

%% ---- ShortNumberInfo ----

-spec short_is_possible(iodata(), iodata()) -> integer().
short_is_possible(_Region, _Input) -> not_loaded(?LINE).

-spec short_is_valid(iodata(), iodata()) -> integer().
short_is_valid(_Region, _Input) -> not_loaded(?LINE).

-spec short_is_emergency(iodata(), iodata()) -> integer().
short_is_emergency(_Region, _Input) -> not_loaded(?LINE).

-spec short_connects_to_emergency(iodata(), iodata()) -> integer().
short_connects_to_emergency(_Region, _Input) -> not_loaded(?LINE).

-spec short_is_carrier_specific(iodata(), iodata()) -> integer().
short_is_carrier_specific(_Region, _Input) -> not_loaded(?LINE).

-spec short_is_sms_service(iodata(), iodata()) -> integer().
short_is_sms_service(_Region, _Input) -> not_loaded(?LINE).

-spec short_expected_cost(iodata(), iodata()) -> integer().
short_expected_cost(_Region, _Input) -> not_loaded(?LINE).

-spec short_example_number(iodata()) -> binary().
short_example_number(_Region) -> not_loaded(?LINE).

%% ---- PhoneNumberToTimeZonesMapper ----

-spec tz_count(iodata(), iodata()) -> integer().
tz_count(_Region, _Input) -> not_loaded(?LINE).

-spec tz_at(iodata(), iodata(), integer()) -> binary().
tz_at(_Region, _Input, _Idx) -> not_loaded(?LINE).

-spec tz_all(iodata(), iodata()) -> binary().
tz_all(_Region, _Input) -> not_loaded(?LINE).

-spec tz_unknown() -> binary().
tz_unknown() -> not_loaded(?LINE).

%% ---- PhoneNumberToCarrierMapper ----

-spec carrier_name(iodata(), iodata(), iodata()) -> binary().
carrier_name(_Region, _Input, _Lang) -> not_loaded(?LINE).

-spec carrier_name_for_valid(iodata(), iodata(), iodata()) -> binary().
carrier_name_for_valid(_Region, _Input, _Lang) -> not_loaded(?LINE).

%% ---- PhoneNumberOfflineGeocoder ----

-spec geo_description(iodata(), iodata(), iodata()) -> binary().
geo_description(_Region, _Input, _Lang) -> not_loaded(?LINE).

-spec geo_description_for_valid(iodata(), iodata(), iodata()) -> binary().
geo_description_for_valid(_Region, _Input, _Lang) -> not_loaded(?LINE).

%% ---- introspection ----

-spec abi_version() -> non_neg_integer().
abi_version() -> not_loaded(?LINE).

not_loaded(Line) ->
    erlang:nif_error({not_loaded, [{module, ?MODULE}, {line, Line}]}).
