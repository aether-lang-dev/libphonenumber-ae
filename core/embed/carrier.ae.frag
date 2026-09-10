// FRAGMENT: carrier — PhoneNumberToCarrierMapper surface. After base.ae.frag.
import core.carrier
exports(pn_embed_carrier_name, pn_embed_carrier_name_for_valid)
pn_embed_carrier_name(region: string, input: string) -> string {
    e164 = e164_digits_for(region, input)
    if e164 == "" { return pn_raw_dup("") }
    return pn_raw_dup(carrier.carrier_name_for_e164(e164))
}
pn_embed_carrier_name_for_valid(region: string, input: string) -> string {
    if phonenumber.is_valid_number(region, input) == 0 { return pn_raw_dup("") }
    return pn_embed_carrier_name(region, input)
}
