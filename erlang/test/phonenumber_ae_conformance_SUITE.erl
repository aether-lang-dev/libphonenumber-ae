%%% The binding conformance suite (docs/conformance.md, v5), as EUnit.
%%%
%%% Proves the Erlang binding marshals every value shape across the FFI. It is
%%% NOT a phone-number test suite — the behavioural cases live in the engine's
%%% own tests and run once, in Aether. Here we sample each KIND of value that
%%% crosses the FFI so the marshalling is proven, not the library.
%%%
%%% Named _SUITE for consistency with the OTP convention, but it is EUnit —
%%% one file, no ct_run, no configuration. `.tests.ae` runs it with eunit:test.
-module(phonenumber_ae_conformance_SUITE).

-include_lib("eunit/include/eunit.hrl").

%%------------------------------------------------------------------
%% The 44 checks (docs/conformance.md, v5)
%%------------------------------------------------------------------

t01_country_code_us_test() ->
    ?assertEqual(<<"1">>, phonenumber_ae:country_code(<<"US">>)).

t02_country_code_gb_test() ->
    ?assertEqual(<<"44">>, phonenumber_ae:country_code(<<"GB">>)).

t03_unknown_region_test() ->
    ?assertEqual(<<>>, phonenumber_ae:country_code(<<"ZZ">>)).

t04_example_number_test() ->
    ?assertEqual(<<"2015550123">>, phonenumber_ae:example_number(<<"US">>)).

t05_possible_lengths_test() ->
    ?assertEqual(<<"10">>, phonenumber_ae:possible_lengths(<<"US">>)).

t06_region_for_cc_test() ->
    ?assertEqual(<<"GB">>, phonenumber_ae:region_code_for_country_code(<<"44">>)).

t07_is_nanpa_test() ->
    ?assert(phonenumber_ae:is_nanpa_country(<<"US">>)).

t08_region_enumeration_test() ->
    ?assert(phonenumber_ae:region_count() >= 200),
    Regs = phonenumber_ae:regions(),
    ?assertEqual(phonenumber_ae:region_count(), length(Regs)),
    ?assertEqual(2, byte_size(hd(Regs))),
    %% region_at/1 agrees with the list's head
    ?assertEqual(hd(Regs), phonenumber_ae:region_at(0)).

t09_cc_region_test() ->
    ?assertEqual(<<"US">>, phonenumber_ae:cc_region_at(<<"1">>, 0)),
    ?assertEqual(<<"US">>, hd(phonenumber_ae:regions_for_country_code(<<"1">>))).

t10_14_parse_test() ->
    Pn = phonenumber_ae:parse(<<"+1 201 555 0123 ext 42">>, <<"US">>),
    ?assertEqual(<<>>, phonenumber_ae:pn_error(Pn)),
    ?assertEqual(<<"2015550123">>, phonenumber_ae:pn_national_number(Pn)),
    ?assertEqual(<<"42">>, phonenumber_ae:pn_extension(Pn)),
    ?assertEqual(<<"1">>, phonenumber_ae:pn_country_code(Pn)),
    ?assertEqual(from_number_with_plus, phonenumber_ae:pn_source(Pn)),
    ?assertEqual(<<"US">>, phonenumber_ae:region_code_for_number(Pn)).

t15_parse_trunk_prefix_test() ->
    Pn = phonenumber_ae:parse(<<"01212345678">>, <<"GB">>),
    ?assertEqual(<<"1212345678">>, phonenumber_ae:pn_national_number(Pn)).

t16_is_possible_test() ->
    ?assert(phonenumber_ae:is_possible_number(<<"US">>, <<"2015550123">>)).

t17_reason_too_short_test() ->
    ?assertEqual(too_short,
                 phonenumber_ae:is_possible_number_with_reason(<<"US">>, <<"201555">>)).

t18_is_valid_test() ->
    ?assert(phonenumber_ae:is_valid_number(<<"US">>, <<"2015550123">>)).

t19_invalid_shape_test() ->
    ?assertNot(phonenumber_ae:is_valid_number(<<"US">>, <<"1015550123">>)).

t20_valid_with_cc_test() ->
    ?assert(phonenumber_ae:is_valid_number(<<"US">>, <<"+12015550123">>)).

t21_number_type_test() ->
    %% US fixedLine==mobile -> fixed_line_or_mobile; GB has distinct patterns.
    ?assertEqual(fixed_line_or_mobile, phonenumber_ae:number_type(<<"US">>, <<"2015550123">>)),
    ?assertEqual(10, phonenumber_ae:number_type_code(<<"US">>, <<"2015550123">>)),
    ?assertEqual(fixed_line, phonenumber_ae:number_type(<<"GB">>, <<"2070313000">>)),
    ?assertEqual(0, phonenumber_ae:number_type_code(<<"GB">>, <<"2070313000">>)).

t22_format_national_test() ->
    ?assertEqual(<<"(201) 555-0123">>,
                 phonenumber_ae:format(<<"US">>, <<"2015550123">>, national)).

t23_format_e164_test() ->
    ?assertEqual(<<"+12015550123">>,
                 phonenumber_ae:format(<<"US">>, <<"2015550123">>, e164)).

t24_format_international_test() ->
    ?assertEqual(<<"+1 201-555-0123">>,
                 phonenumber_ae:format(<<"US">>, <<"2015550123">>, international)).

t25_format_rfc3966_test() ->
    ?assertEqual(<<"tel:+1-201-555-0123">>,
                 phonenumber_ae:format(<<"US">>, <<"2015550123">>, rfc3966)).

t26_match_exact_test() ->
    ?assertEqual(exact,
                 phonenumber_ae:is_number_match(<<"+12015550123">>, <<"+1 201 555 0123">>)).

t27_match_none_test() ->
    ?assertEqual(no_match,
                 phonenumber_ae:is_number_match(<<"+12015550123">>, <<"+12025550123">>)).

t28_normalize_test() ->
    ?assertEqual(<<"12015550123">>,
                 phonenumber_ae:normalize_digits_only(<<"+1 (201) 555.0123">>)).

t29_alpha_test() ->
    ?assertEqual(<<"1-800-3569377">>,
                 phonenumber_ae:convert_alpha_characters(<<"1-800-FLOWERS">>)).

t30_truncate_test() ->
    ?assertEqual(<<"2015550123">>,
                 phonenumber_ae:truncate_too_long(<<"US">>, <<"20155501239999">>)).

t31_as_you_type_test() ->
    S0 = phonenumber_ae:ayt_new(<<"US">>),
    Final = lists:foldl(
              fun(Ch, S) -> phonenumber_ae:ayt_input(S, <<Ch>>) end,
              S0, "2015550123"),
    ?assertEqual(<<"(201) 555-0123">>, phonenumber_ae:ayt_result(Final)).

t32_matcher_count_test() ->
    Matches = phonenumber_ae:find_numbers(
                <<"call 201-555-0123 or +1 202 555 0199">>, <<"US">>, valid),
    ?assertEqual(2, length(Matches)).

t33_matcher_raw_test() ->
    [{_Start, _End, Raw} | _] =
        phonenumber_ae:find_numbers(<<"call 201-555-0123 now">>, <<"US">>, valid),
    ?assertEqual(<<"201-555-0123">>, Raw).

t34_abi_version_test() ->
    ?assertEqual(5, phonenumber_ae:abi_version()).

%%------------------------------------------------------------------
%% ShortNumberInfo (docs/conformance.md #35–40, v3)
%%------------------------------------------------------------------

t35_short_emergency_us_test() ->
    ?assert(phonenumber_ae:is_emergency_number(<<"US">>, <<"911">>)).

t36_short_not_emergency_test() ->
    ?assertNot(phonenumber_ae:is_emergency_number(<<"US">>, <<"999">>)).

t37_short_emergency_gb_test() ->
    ?assert(phonenumber_ae:is_emergency_number(<<"GB">>, <<"999">>)).

t38_short_valid_test() ->
    ?assert(phonenumber_ae:short_is_valid(<<"US">>, <<"911">>)).

t39_short_cost_test() ->
    ?assertEqual(toll_free,
                 phonenumber_ae:short_expected_cost(<<"US">>, <<"911">>)),
    ?assertEqual(0,
                 phonenumber_ae:short_expected_cost_code(<<"US">>, <<"911">>)).

t40_short_example_test() ->
    ?assertEqual(<<"112">>, phonenumber_ae:short_example_number(<<"US">>)).

%%------------------------------------------------------------------
%% TimeZones + Carrier (docs/conformance.md #41–44, v5)
%%------------------------------------------------------------------

t41_tz_us_test() ->
    ?assertEqual([<<"America/New_York">>],
                 phonenumber_ae:time_zones_for_number(<<"US">>, <<"2015550123">>)).

t42_tz_gb_test() ->
    ?assertEqual([<<"Europe/London">>],
                 phonenumber_ae:time_zones_for_number(<<"GB">>, <<"2070313000">>)).

t43_tz_unknown_test() ->
    ?assertEqual(<<"Etc/Unknown">>, phonenumber_ae:unknown_time_zone()).

t44_carrier_test() ->
    ?assertEqual(<<"O2">>,
                 phonenumber_ae:carrier_name_for_number(<<"GB">>, <<"7106000000">>)).

%%------------------------------------------------------------------
%% Extras — marshalling corners the 44 do not reach
%%------------------------------------------------------------------

%% The NIF takes iodata, not just binaries — a caller with a plain string list
%% should not have to flatten it first.
iodata_input_test() ->
    ?assertEqual(<<"1">>, phonenumber_ae:country_code("US")).

%% The format helpers wrap the style atom.
format_helpers_test() ->
    ?assertEqual(<<"(201) 555-0123">>,
                 phonenumber_ae:format_national(<<"US">>, <<"2015550123">>)),
    ?assertEqual(<<"+12015550123">>,
                 phonenumber_ae:format_e164(<<"US">>, <<"2015550123">>)),
    ?assertEqual(<<"+1 201-555-0123">>,
                 phonenumber_ae:format_international(<<"US">>, <<"2015550123">>)),
    ?assertEqual(<<"tel:+1-201-555-0123">>,
                 phonenumber_ae:format_rfc3966(<<"US">>, <<"2015550123">>)).

%% find_numbers/2 defaults leniency to valid, and carries start/end offsets.
find_numbers_offsets_test() ->
    [{Start, End, Raw} | _] =
        phonenumber_ae:find_numbers(<<"call 201-555-0123 now">>, <<"US">>),
    ?assertEqual(<<"201-555-0123">>, Raw),
    ?assert(End > Start).
