// FRAGMENT: geo — PhoneNumberOfflineGeocoder surface. After base.ae.frag.
import core.geocoder
exports(pn_embed_geo_description, pn_embed_geo_description_for_valid)
pn_embed_geo_description(region: string, input: string, lang: string) -> string {
    e164 = e164_digits_for(region, input)
    if e164 == "" { return pn_raw_dup("") }
    return pn_raw_dup(geocoder.description_for_e164(e164, lang))
}
pn_embed_geo_description_for_valid(region: string, input: string, lang: string) -> string {
    if phonenumber.is_valid_number(region, input) == 0 { return pn_raw_dup("") }
    return pn_embed_geo_description(region, input, lang)
}
