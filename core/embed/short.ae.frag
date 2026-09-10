// FRAGMENT: short — ShortNumberInfo surface. Concatenated after base.ae.frag.
import core.shortnumber
exports(
    pn_embed_short_is_possible, pn_embed_short_is_valid,
    pn_embed_short_is_emergency, pn_embed_short_connects_to_emergency,
    pn_embed_short_is_carrier_specific, pn_embed_short_is_sms_service,
    pn_embed_short_expected_cost, pn_embed_short_example_number
)
pn_embed_short_is_possible(region: string, input: string) -> int {
    return shortnumber.is_possible_short_number(region, input)
}
pn_embed_short_is_valid(region: string, input: string) -> int {
    return shortnumber.is_valid_short_number(region, input)
}
pn_embed_short_is_emergency(region: string, input: string) -> int {
    return shortnumber.is_emergency_number(region, input)
}
pn_embed_short_connects_to_emergency(region: string, input: string) -> int {
    return shortnumber.connects_to_emergency_number(region, input)
}
pn_embed_short_is_carrier_specific(region: string, input: string) -> int {
    return shortnumber.is_carrier_specific(region, input)
}
pn_embed_short_is_sms_service(region: string, input: string) -> int {
    return shortnumber.is_sms_service(region, input)
}
pn_embed_short_expected_cost(region: string, input: string) -> int {
    return shortnumber.expected_cost(region, input)
}
pn_embed_short_example_number(region: string) -> string {
    return pn_raw_dup(shortnumber.short_example_number(region))
}
