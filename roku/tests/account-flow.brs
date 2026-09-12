sub Main()
    m.failures = 0
    m.accountEpoch = 3
    m.generation = 2
    m.config = {base:"https://tv.example",access_token:"paired",refresh_token:"stored-refresh",last_profile_id:"7",auth_version:3,auth_origin:"https://tv.example",account_id:"a"}
    m.profile = ""
    m.identity = {text:""}
    m.status = {text:""}
    m.description = {text:"",translation:[776,414],width:436,height:182,numLines:6}
    m.detailTitle = {text:"",height:110}
    m.detailInfo = {visible:true}
    m.heading = {text:""}
    m.authTimer = {control:"stop",duration:5}
    m.pairQr = {uri:"",visible:false}
    m.profileGrid = invalid
    m.queue = []: m.tasks = []: m.calls = []
    m.cache = {secret:"old"}: m.views = ["old"]
    m.accountMode = true: m.authBusy = false: m.canCreateProfile = true

    accountConnect()
    check(m.config.last_profile_id = "7" and m.calls.peek().path = "/api/device/refresh","paired startup retains remembered profile and refreshes")
    epoch = m.accountEpoch
    accountResponse("auth:refresh",{ok:true,data:{access_token:"new-access",refresh_token:"new-refresh",expires_in:900}},{account_epoch:epoch})
    check(m.config.access_token = "new-access" and m.calls.peek().path = "/api/auth/me","refresh rotates account credentials")
    accountResponse("auth:me",{ok:true,data:{account_id:"a",can_create_profile:true,profiles:[{id:"7",name:"Kid",avatar_style:"critters",avatar_url:"https://api.dicebear.com/10.x/critters/png?seed=opaque&size=256",presentation_complete:true}]}},{account_epoch:epoch})
    check(m.calls.peek().path = "/api/auth/profile" and m.calls.peek().body.profile_id = 7,"valid remembered profile is revalidated then selected")
    accountResponse("auth:profile",{ok:true,data:{}},{account_epoch:m.accountEpoch})
    check(m.profile = "7" and m.config.last_profile_id = "7" and m.homeOpened = true,"remembered profile opens only after backend acknowledgement")

    accountPair()
    check(m.calls.peek().path = "/api/device/code" and m.calls.peek().connection.access_token = "","fresh pairing requests code without credential")
    check(m.config.access_token = "" and m.config.last_profile_id = "" and m.views.count() = 0,"pairing clears prior account and remembered profile")
    epoch = m.accountEpoch
    data = {device_code:"private",user_code:"AB12CD34",verification_uri:"https://tv.example/device",verification_uri_complete:"https://tv.example/device?code=AB12CD34",qr_uri:"/api/device/qr/AB12CD34",expires_in:120,interval:5}
    accountResponse("auth:code",{ok:true,data:data},{account_epoch:epoch-1})
    check(m.pairing = invalid,"stale code does not restore pairing")
    accountResponse("auth:code",{ok:true,data:data},{account_epoch:epoch})
    check(m.mode = "pairing" and m.authTimer.control = "start" and m.pairQr.visible,"pair UI displays QR and arms dedicated timer")
    check(m.pairQr.uri = "https://tv.example/api/device/qr/AB12CD34" and instr(1,m.description.text,"AB12CD34") > 0,"QR and manual code use same account deep link")
    check(left(m.description.text,len("https://tv.example/device")) = "https://tv.example/device" and instr(1,m.description.text,"?code=") = 0,"pairing prints short readable URL beside separate code")
    check(m.description.translation[1] = 450 and m.description.height = 150 and m.detailTitle.text = "Scan to sign in" and m.detailTitle.height = 48 and not m.detailInfo.visible,"QR layout reserves clear lower instructions and heading")
    accountTick()
    check(m.calls.peek().path = "/api/device/token" and m.calls.peek().body.device_code = "private","timer polls canonical device code")
    accountResponse("auth:token",{ok:false,status:400,auth_code:"slow_down"},{account_epoch:epoch})
    check(m.authTimer.duration = 10,"slow_down increases interval")
    accountResponse("auth:token",{ok:false,status:400,auth_code:"authorization_pending"},{account_epoch:epoch})
    check(m.authTimer.duration = 10,"pending preserves backoff")
    accountResponse("auth:token",{ok:true,data:{access_token:"access",refresh_token:"refresh",expires_in:600}},{account_epoch:epoch})
    check(m.config.auth_version = 3 and m.config.access_token = "access" and not m.pairQr.visible,"token exchange stores paired account credential and hides QR")
    check(m.description.translation[1] = 414 and m.description.height = 182 and m.detailTitle.height = 110 and m.detailInfo.visible,"leaving pairing restores normal details layout")
    accountResponse("auth:me",{ok:true,data:{account_id:"b",can_create_profile:true,profiles:[]}},{account_epoch:epoch})
    check(m.keyboardKind = "accountprofilename","zero-profile account opens profile setup")
    accountSubmitProfileName("Alex")
    check(m.mode = "accountavatars" and m.lastRows.count() = AccountAvatarStyles().count(),"profile setup shows remote kid-friendly avatar choices")
    accountProfileAction(m.lastRows[0])
    check(m.calls.peek().path = "/api/profiles" and m.calls.peek().body.name = "Alex" and m.calls.peek().body.avatar_style = "critters","device creates profile with allowlisted style")
    accountResponse("auth:newprofile",{ok:true,data:{id:"9",name:"Alex",avatar_style:"critters",avatar_url:"https://api.dicebear.com/10.x/critters/png?seed=random&size=256",presentation_complete:true}},{account_epoch:m.accountEpoch})
    check(m.calls.peek().path = "/api/auth/profile","created profile is explicitly selected")
    accountResponse("auth:profile",{ok:true,data:{}},{account_epoch:m.accountEpoch})
    check(m.profile = "9" and m.config.last_profile_id = "9","created profile becomes remembered after acknowledgement")

    accountReset(): m.config.last_profile_id = "missing": epoch = m.accountEpoch
    accountUseProfiles([{id:"4",name:"One",presentation_complete:true},{id:"5",name:"Two",presentation_complete:true}])
    check(m.config.last_profile_id = "" and m.mode = "profiles","stale remembered profile falls back to chooser")
    accountUseProfiles([{id:"1",name:"Default",presentation_complete:false}])
    check(m.keyboardKind = "accountprofilename" and m.keyboardInitial = "Default","imported incomplete profile requires presentation setup")
    accountSubmitProfileName("Owner")
    accountFinishProfileSetup("moods")
    check(m.calls.peek().method = "PATCH" and m.calls.peek().path = "/api/profiles/1" and m.calls.peek().body.avatar_style = "moods","imported profile setup patches same profile ID")

    accountRevoked()
    check(m.config.access_token = "" and m.config.refresh_token = "" and m.config.last_profile_id = "" and m.config.auth_version = 3,"revocation clears all paired and remembered state")
    if m.failures > 0 then stop
    print "ROKU_ACCOUNT_FLOW_OK"
end sub
sub request(method as string,path as string,body as dynamic,tag as string,connection=invalid as dynamic)
    m.calls.push({method:method,path:path,body:body,tag:tag,connection:connection})
end sub
sub cancelBrowse()
    m.generation++
end sub
sub stopPlayback()
end sub
sub rows(title as string,values as object,mode as string,subtitle="" as string)
    m.mode = mode: m.lastRows = values
end sub
sub showSettings()
    m.mode = "settings"
end sub
sub home()
    m.homeOpened = true
end sub
sub keyboard(kind as string,title as string,initial as string)
    m.keyboardKind = kind: m.keyboardInitial = initial
end sub
sub check(value as boolean,label as string)
    if not value
        print "FAIL ";label
        m.failures++
    end if
end sub
