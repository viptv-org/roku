sub main()
    m.failures = 0
    q = chr(34)
    fixture = {base:"http://fixture.example:8080"}
    packaged = ParsePackagedConnection(FormatJson(fixture))
    check(packaged <> invalid, "valid origin-only package")
    if packaged = invalid then stop
    check(ParsePackagedConnection("not JSON") = invalid, "malformed rejected before parsing")
    check(ParsePackagedConnection(FormatJson({base:"https://fixture.example/path"})) = invalid, "path rejected")
    check(ParsePackagedConnection(FormatJson({base:"https://fixture.example",token:""})) = invalid, "static token field rejected")
    check(ParsePackagedConnection(FormatJson({base:"https://fixture.example",extra:true})) = invalid, "unexpected fields rejected")
    check(ParsePackagedConnection("{" + q + "base" + q + ":" + q + "https://fixture.example" + q + "," + q + "base" + q + ":" + q + "https://fixture.example" + q + "}") = invalid, "duplicate key shape rejected")
    original = {base:fixture.base,access_token:"paired",refresh_token:"refresh",last_profile_id:"7",auth_version:3,auth_origin:fixture.base,locked:false}
    same = LockedConnection(original, packaged)
    check(same.locked and same.last_profile_id = "7" and same.access_token = "paired", "matching paired account state retained")
    check(original.locked = false, "input unchanged")
    stale = LockedConnection({base:"https://other.example",access_token:"paired",refresh_token:"refresh",last_profile_id:"7",auth_version:3,auth_origin:"https://other.example"}, packaged)
    check(stale.locked and stale.base = fixture.base and stale.access_token = "" and stale.last_profile_id = "", "origin mismatch clears account state and enforces package")
    saved = LockedConnection({base:"not an origin",token:"discard-me",profile:"99"}, packaged)
    check(saved.base = fixture.base and saved.access_token = "" and saved.last_profile_id = "", "save cannot replace packaged origin or import static key")
    public = LockedConnection({base:"https://public.example",access_token:"public-paired",refresh_token:"rotate",last_profile_id:"9",auth_version:3,auth_origin:"https://public.example",locked:true}, invalid)
    check(public.locked = false and public.last_profile_id = "9" and public.base = "https://public.example", "absent package preserves valid public account configuration")
    if m.failures = 0 then print "ROKU_LOCKED_CONFIG_OK" else stop
end sub

sub check(value as boolean, label as string)
    if not value
        m.failures++
        print "FAIL "; label
    end if
end sub
