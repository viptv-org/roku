' Runtime contract for the real MainScene queue and AccountScene refresh logic.
sub Main()
    m.config = {base:"https://tv.example",access_token:"fixture-access",refresh_token:"fixture-refresh",last_profile_id:"7",account_id:"fixture-account",auth_version:3}
    m.queue = []
    m.generation = 4
    m.requestSequence = 0
    m.accountEpoch = 9
    request("GET","/api/profiles",invalid,"propagation")
    entry = m.queue[0]
    propagationAssert(entry.base = m.config.base and entry.access_token = "fixture-access","MainScene propagates canonical access token")
    propagationAssert(entry.last_profile_id = "7" and entry.account_epoch = 9,"MainScene propagates remembered-profile and account epoch scope")
    propagationAssert(entry.token = invalid and entry.profile = invalid,"MainScene queue contains no retired config aliases")

    m.queue = []
    m.authTimer = {control:"",duration:0}
    m.authBusy = false
    accountRefresh()
    refresh = m.queue[0]
    propagationAssert(refresh.path = "/api/device/refresh" and refresh.access_token = "","device refresh intentionally queues without bearer access")
    propagationAssert(refresh.account_epoch = m.accountEpoch and refresh.token = invalid,"device refresh remains owned by current account epoch and canonical field")

    m.queue = []
    m.authBusy = false
    m.config.access_token = "fixture-access"
    request("GET","/api/profiles",invalid,"rotate-me")
    accountSaveTokens({access_token:"rotated-access",refresh_token:"rotated-refresh",expires_in:120})
    propagationAssert(m.queue[0].access_token = "rotated-access" and m.queue[0].account_epoch = m.accountEpoch,"refresh rotates already queued account request")
    propagationAssert(m.queue[0].token = invalid,"refresh never creates retired queue alias")
    print "ROKU_REQUEST_PROPAGATION_OK"
end sub

sub propagationAssert(condition as boolean, label as string)
    if not condition
        print "TEST_FAIL "; label
        stop
    end if
end sub
