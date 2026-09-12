sub Main()
    m.failures = 0
    package = {base:"https://tv.example"}
    paired = {base:package.base,access_token:"paired",last_profile_id:"7",auth_version:3,auth_origin:package.base,refresh_token:"rotate",account_id:"a",expires_at:100}
    loaded = LockedConnection(paired,package)
    check(loaded.access_token = "paired" and loaded.refresh_token = "rotate" and loaded.locked,"paired account credential survives origin lock")
    revoked = LockedConnection({base:package.base,auth_version:3,auth_origin:package.base,access_token:"",refresh_token:"",last_profile_id:"7"},package)
    check(revoked.access_token = "" and revoked.last_profile_id = "","revocation cannot restore a credential or remembered profile")
    foreign = paired: foreign.auth_origin = "https://other.example"
    check(LockedConnection(foreign,package).access_token = "","foreign origin cannot override package")
    check(ParsePackagedConnection(FormatJson({base:package.base})) <> invalid,"origin-only package accepted")
    check(ParsePackagedConnection(FormatJson({base:package.base,token:""})) = invalid,"package token field rejected")
    migrated = LockedConnection({base:package.base,token:"paired-v2",profile:"5",auth_version:2,auth_origin:package.base,refresh_token:"refresh-v2"},package)
    check(migrated.access_token = "paired-v2" and migrated.last_profile_id = "5","v2 paired credential migrates only with rotating refresh proof")
    discarded = LockedConnection({base:package.base,token:"static-key",profile:"5"},package)
    check(discarded.access_token = "" and discarded.last_profile_id = "","unversioned static key is discarded")

    check(AccountProfileRows([],false).count() = 0,"fresh account has zero profiles")
    check(AccountProfileRows([],true).count() = 1 and AccountProfileRows([],true)[0].action = "newprofile","zero profiles offers creation")
    profiles = AccountProfileRows([{id:1,name:"Kid",avatar_url:"https://api.dicebear.com/10.x/critters/png?seed=opaque&size=256",avatar_style:"critters",setup_complete:true}],true)
    check(profiles.count() = 2 and profiles[0].setup_complete and profiles[0].presentation_complete and profiles[0].avatar_style = "critters","canonical profile setup survives closed sanitizer")
    legacyProfile = AccountProfileRow({id:2,name:"Legacy",presentation_complete:true})
    check(legacyProfile.setup_complete and legacyProfile.presentation_complete,"legacy profile setup alias remains migration-compatible")
    check(AccountAvatarUrl("https://evil.example/avatar.png") = "","arbitrary avatar host rejected")
    check(AccountAvatarStyle("fun-emoji") = "","attribution-bearing style is not allowlisted")

    code = AccountWire("/api/device/code",{device_code:"secret",user_code:"AB12CD34",verification_uri_complete:"https://tv.example/device?code=AB12CD34",qr_uri:"/api/device/qr/AB12CD34",expires_in:600,interval:5})
    check(code.ok and code.data.interval = 5 and code.data.qr_uri = "/api/device/qr/AB12CD34","QR pairing fields survive sanitizer")
    check(not AccountWire("/api/device/code",{device_code:"secret",user_code:"AB12CD34",verification_uri_complete:"http://tv.example/device?code=AB12CD34",expires_in:600}).ok,"verification deep link must be HTTPS")
    check(not AccountWire("/api/device/token",{access_token:"x"}).ok,"incomplete token response rejected")
    tokens = AccountWire("/api/device/refresh",{access_token:"new",refresh_token:"rotated",expires_in:120,secret:"drop"})
    check(tokens.ok and tokens.data.secret = invalid,"closed token shape")
    me = AccountWire("/api/auth/me",{account:{id:5},permissions:{create_profile:true},profiles:[{id:2,name:"Viewer",avatar_url:"https://api.dicebear.com/10.x/moods/png?seed=random&size=256",avatar_style:"moods",setup_complete:true,password:"drop"}]})
    check(me.ok and me.data.account_id = "5" and me.data.can_create_profile,"account and permission shape")
    check(me.data.profiles[0].password = invalid and me.data.profiles[0].avatar_style = "moods","profile nested secrets stripped")
    check(AccountErrorCode("{" + chr(34) + "error" + chr(34) + ":" + chr(34) + "slow_down" + chr(34) + "}") = "slow_down","closed backoff code")
    check(AccountClamp(120,1,60) = 60,"backoff bounded")
    actual = SanitizeApiResponse("/api/device/code","POST",{device_code:"opaque-secret",user_code:"AB12CD34",verification_uri_complete:"https://tv.example/device?code=AB12CD34",qr_uri:"https://tv.example/api/device/qr/AB12CD34",expires_in:600,interval:5})
    check(actual.ok and actual.data.device_code = "opaque-secret","actual account-only code crosses ApiTask")
    session = AccountWire("/api/device/token",{session_id:"sid",account_id:1,profile_id:invalid,csrf_token:"drop",access_token:"access",refresh_token:"refresh",expires_in:900})
    check(session.ok and session.data.session_id = "sid" and session.data.profile_id = "" and session.data.csrf_token = invalid,"zero-profile session sanitized")
    created = SanitizeApiResponse("/api/profiles","POST",{id:"8",name:"Kid",avatar_style:"critters",avatar_url:"https://api.dicebear.com/10.x/critters/png?seed=opaque&size=256",presentation_complete:true})
    check(created.ok and created.data.avatar_style = "critters" and created.data.presentation_complete,"created avatar profile validated")
    if m.failures > 0 then stop
    print "ROKU_ACCOUNT_POLICY_OK"
end sub
sub check(value as boolean, label as string)
    if not value
        print "FAIL ";label
        m.failures++
    end if
end sub
