// FRAGMENT: tz — PhoneNumberToTimeZonesMapper surface. After base.ae.frag.
import core.timezone
exports(pn_embed_tz_count, pn_embed_tz_at, pn_embed_tz_all, pn_embed_tz_unknown)
pn_embed_tz_count(region: string, input: string) -> int {
    e164 = e164_digits_for(region, input)
    if e164 == "" { return 0 }
    return timezone.time_zone_count_for_e164(e164)
}
pn_embed_tz_at(region: string, input: string, idx: int) -> string {
    e164 = e164_digits_for(region, input)
    if e164 == "" { return pn_raw_dup(timezone.unknown_time_zone()) }
    return pn_raw_dup(timezone.time_zone_at_for_e164(e164, idx))
}
pn_embed_tz_all(region: string, input: string) -> string {
    e164 = e164_digits_for(region, input)
    if e164 == "" { return pn_raw_dup(timezone.unknown_time_zone()) }
    return pn_raw_dup(timezone.time_zones_for_e164(e164))
}
pn_embed_tz_unknown() -> string {
    return pn_raw_dup(timezone.unknown_time_zone())
}
