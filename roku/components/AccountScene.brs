' Account-only pairing and profile gateway. Auth polling has its own timer/epoch.
sub initAccount()
    m.accountEpoch = 0
    m.accountMode = true
    m.canCreateProfile = true
    m.managingProfiles = false
    m.authTimer = m.top.findNode("authTimer")
    m.authTimer.observeField("fire","accountTick")
    m.authBusy = false
    m.pairing = invalid
    m.pendingProfile = invalid
    m.profileDraft = invalid
    m.pairQr = m.top.findNode("pairQr")
    m.profileGrid = m.top.findNode("profileGrid")
    m.profileActions = m.top.findNode("profileActions")
    m.profilePages = m.top.findNode("profilePages")
    m.profilePageLabel = m.top.findNode("profilePageLabel")
    m.profileActions.observeField("itemSelected","accountProfileButtonSelected")
    m.profilePages.observeField("itemSelected","accountProfilePageSelected")
    m.authLoading = m.top.findNode("authLoading")
    m.authLoadingSpinner = m.top.findNode("authLoadingSpinner")
    m.authLoadingSpinner.poster.width = 60
    m.authLoadingSpinner.poster.height = 60
    m.pairQrTimer = m.top.findNode("pairQrTimer")
    m.pairQrTimer.observeField("fire","accountQrTimeout")
    m.pairQr.observeField("loadStatus","accountQrLoaded")
    m.pairVisual = invalid
    m.top.findNode("pairInstruction").font.size = 32
    m.top.findNode("pairAddress").font.size = 28
    m.top.findNode("pairCode").font.size = 44
end sub

' Gateways own the full screen; never reuse a media detail panel for sign-in.
sub accountLayout(gateway as boolean)
    m.gatewayActive = gateway
    chrome = m.top.findNode("appChrome")
    if chrome <> invalid then chrome.visible = not gateway
    brand = m.top.findNode("gatewayBrand")
    if brand <> invalid then brand.visible = gateway
    if m.identity <> invalid then m.identity.visible = false
    if m.footer <> invalid then m.footer.visible = false
    m.heading.translation = [132,42]
    m.heading.width = 760
    m.heading.height = 54
    m.heading.wrap = false
    m.heading.horizAlign = "left"
    m.status.translation = [132,670]
    m.status.width = 1100
    m.status.horizAlign = "left"
    m.standardList.translation = [132,118]
    m.standardList.numRows = 10
    if not gateway then return
    for each id in ["art","detailTitle","detailInfo","description","detailPanel","discoverFilters","posterGrid","sourceList","homePanel"]
        node = m.top.findNode(id)
        if node <> invalid then node.visible = false
    end for
    m.heading.translation = [96,170]
    m.heading.width = 1088
    m.heading.font.size = 42
    if m.mode = "pairing"
        m.heading.font.size = 52
        m.heading.height = 68
    end if
    m.status.translation = [96,666]
    m.status.width = 1088
    m.standardList.translation = [96,462]
    m.standardList.itemSize = [420,48]
    m.standardList.numRows = 2
    if m.mode = "profiles" or m.mode = "accountavatars"
        m.standardList.visible = false
        m.heading.translation = [96,132]
        m.heading.horizAlign = "center"
        m.status.horizAlign = "center"
    end if
end sub

function accountNow() as integer
    return CreateObject("roDateTime").asSeconds()
end function

sub accountReset()
    startupCancel()
    m.uiHeroMetadata = {}
    m.uiLandscapeCache = {}
    m.uiLandscapeOrder = []
    m.uiArtworkTried = {}
    m.uiArtworkOrder = []
    m.uiArtworkInflight = {}
    if m.profileEditor <> invalid then m.profileEditor.visible = false
    if m.textEntry <> invalid
        m.textEntry.visible = false
        if m.textEntry.secret then m.textEntry.callFunc("clear")
    end if
    cancelBrowse()
    m.accountEpoch++
    m.cache = {}
    m.cacheKeys = []
    m.views = []
    m.playerReturnDetail = invalid
    m.homeData = invalid
    m.homeRoot = invalid
    m.homePosition = [0,0]
    m.homeKeyValue = ""
    m.profile = ""
    if m.identity <> invalid then m.identity.text = ""
    m.pendingProfile = invalid
    m.profileDraft = invalid
    m.authBusy = false
    retained = []
    for each entry in m.queue
        if left(Txt(entry.tag),7) = "cleanup" then retained.push(entry)
    end for
    m.queue = retained
    for each task in m.tasks
        if left(Txt(task.request.tag),7) <> "cleanup" then task.cancel = true
    end for
end sub

sub accountClearRememberedProfile()
    m.profile = ""
    m.config.last_profile_id = ""
end sub

sub accountCancelCredentials()
    if m.authTimer <> invalid then m.authTimer.control = "stop"
    accountHideQr()
    m.pairing = invalid
    if m.accountEpoch = invalid then m.accountEpoch = 0
    m.accountEpoch++
    m.accountMode = true
    m.config.auth_version = 3
    m.config.auth_origin = m.config.base
    m.config.access_token = ""
    m.config.refresh_token = ""
    m.config.account_id = ""
    accountClearRememberedProfile()
end sub

sub accountConnect()
    if Txt(m.config.base) = "" then return
    accountReset()
    m.accountMode = true
    accountShowLoading()
    if m.config.auth_version = 3 and Txt(m.config.refresh_token) <> ""
        accountRefresh()
    else
        accountPair()
    end if
end sub

sub accountPair()
    stopPlayback()
    accountReset()
    accountCancelCredentials()
    m.authTimer.control = "stop"
    m.pairing = invalid
    accountShowLoading()
    m.authBusy = true
    request("POST","/api/device/code",{device_name:"VIPTV Roku"},"auth:code",{base:m.config.base,access_token:""})
end sub

sub accountCancelPair()
    m.authTimer.control = "stop"
    accountHideQr()
    m.pairing = invalid
    accountReset()
    showSettings()
end sub

sub accountRetry(message as string)
    m.authTimer.control = "stop"
    accountHideQr()
    m.pairing = invalid
    rows("Sign in to VIPTV",[{name:"Try again",action:"pair"}],"pairing",message)
end sub

sub accountRefresh()
    if m.authBusy = true then return
    m.authBusy = true
    request("POST","/api/device/refresh",{refresh_token:m.config.refresh_token},"auth:refresh",{base:m.config.base,access_token:""})
end sub

sub accountTick()
    if m.authBusy = true then return
    if m.pairing <> invalid
        if accountNow() >= m.pairing.expires_at
            accountRetry("That code expired. Request a new one to continue.")
            return
        end if
        m.authBusy = true
        request("POST","/api/device/token",{device_code:m.pairing.device_code},"auth:token",{base:m.config.base,access_token:""})
    else if m.config.auth_version = 3 and Txt(m.config.refresh_token) <> ""
        accountRefresh()
    end if
end sub

sub accountSaveTokens(data as object)
    m.config.auth_version = 3
    m.config.auth_origin = m.config.base
    previousToken = Txt(m.config.access_token)
    m.config.access_token = data.access_token
    for each entry in m.queue
        if entry.account_epoch = m.accountEpoch and entry.base = m.config.base and Txt(entry.access_token) = previousToken then entry.access_token = data.access_token
    end for
    m.config.refresh_token = data.refresh_token
    m.config.expires_at = accountNow() + data.expires_in
    m.pairing = invalid
    accountHideQr()
    m.authTimer.duration = AccountClamp(data.expires_in - 60,1,2592000)
    m.authTimer.control = "start"
    request("CONFIG_SAVE","",m.config,"sideconfig")
end sub

sub accountRevoked()
    stopPlayback()
    accountReset()
    accountCancelCredentials()
    request("CONFIG_SAVE","",m.config,"sideconfig")
    accountRetry("This TV was signed out. Scan a new code to reconnect.")
end sub

function accountQrUrl(data as object) as string
    qr = Txt(data.qr_uri)
    if left(qr,5) = "/api/" then return m.config.base + qr
    if left(qr,8) = "https://" and left(qr,len(AccountOrigin(m.config.base))+1) = AccountOrigin(m.config.base) + "/" then return qr
    return ""
end function

sub accountShowLoading()
    startupStatus("Connecting to your account…")
    rows("",[],"pairing","")
    m.authLoading.visible = true
    m.authLoadingSpinner.control = "start"
end sub

sub accountEndLoading()
    if m.homeInitialLoading = true then return
    if m.authLoading = invalid then return
    m.authLoading.visible = false
    m.authLoadingSpinner.control = "stop"
end sub

sub accountShowQr(data as object)
    if m.pairQr = invalid then return
    accountHideQr()
    m.authLoading.visible = true
    m.authLoadingSpinner.control = "start"
    uri = accountQrUrl(data)
    m.pairVisual = {data:data,epoch:m.accountEpoch,uri:uri}
    m.pairQrTimer.control = "start"
    if uri = ""
        accountRevealPair(false)
        return
    end if
    ' Preload behind the opaque startup cover; reveal only after the image settles.
    m.pairQr.uri = uri
    accountQrLoaded()
end sub

sub accountQrLoaded()
    if m.pairVisual = invalid then return
    if m.pairVisual.epoch <> m.accountEpoch then return
    if m.pairQr.uri <> m.pairVisual.uri then return
    if m.pairQr.loadStatus = "ready" or m.pairQr.loadStatus = "loaded"
        accountRevealPair(true)
    else if m.pairQr.loadStatus = "failed"
        accountRevealPair(false)
    end if
end sub

sub accountQrTimeout()
    accountRevealPair(false)
end sub

sub accountRevealPair(qrReady as boolean)
    visual = m.pairVisual
    if visual = invalid then return
    if visual.epoch <> m.accountEpoch then return
    if m.pairing <> invalid
        if accountNow() >= m.pairing.expires_at
            accountRetry("That code expired. Request a new one to continue.")
            return
        end if
    end if
    m.pairVisual = invalid
    m.pairQrTimer.control = "stop"
    data = visual.data
    rows("Sign in to VIPTV",[],"pairing","")
    address = Txt(data.verification_uri)
    if address = "" then address = Txt(data.verification_uri_complete)
    instruction = "Scan the QR code with your phone."
    prefix = "Or visit "
    if not qrReady
        instruction = "Enter this code on your phone to sign in."
        prefix = "Visit "
    end if
    m.top.findNode("pairInstruction").text = instruction
    m.top.findNode("pairAddress").text = prefix + address
    m.top.findNode("pairCode").text = data.user_code
    m.top.findNode("pairQrSurface").visible = qrReady
    m.pairQr.visible = qrReady
    m.top.findNode("pairPanel").visible = true
    accountEndLoading()
end sub

sub accountHideQr()
    m.pairVisual = invalid
    if m.pairQrTimer <> invalid then m.pairQrTimer.control = "stop"
    if m.pairQr <> invalid
        m.pairQr.visible = false
        m.pairQr.uri = ""
    end if
    panel = m.top.findNode("pairPanel")
    if panel <> invalid then panel.visible = false
end sub

function accountResponse(tag as string, result as object, origin as object) as boolean
    if left(tag,5) <> "auth:" then return false
    if tag = "auth:parentunlock" then origin.body = invalid
    if origin.account_epoch <> m.accountEpoch then return true
    m.authBusy = false
    if (tag = "auth:token") and m.pairing <> invalid
        if accountNow() >= m.pairing.expires_at
            accountRetry("That code expired. Request a new one to continue.")
            return true
        end if
    end if
    if not result.ok
        code = Txt(result.auth_code)
        if tag = "auth:logout"
            if code = "parent_required"
                m.parentAction = "logout"
                keyboard("parentpin","Enter parent PIN to sign out","")
            else
                m.parentAction = ""
                m.status.text = "Could not sign out. Your session is still open; try again."
                showSettings()
            end if
            return true
        end if
        if (tag = "auth:newprofile" or tag = "auth:setupprofile" or tag = "auth:deleteprofile") and code = "parent_required"
            m.profileEditor.saving = false
            m.parentAction = "profilemutation"
            m.profileMutation = {method:origin.method,path:origin.path,body:origin.body,tag:tag}
            keyboard("parentpin","Enter parent PIN to manage profiles","")
            return true
        end if
        if tag = "auth:parentunlock"
            m.parentUnlockPending = false
            m.status.text = "Incorrect PIN. Try again."
            if result.status = 429 then m.status.text = "Too many attempts. Wait before trying again."
            if m.pendingProfile <> invalid or m.parentAction = "logout" or m.parentAction = "profilemutation"
                title = "Parent PIN · try again"
                if result.status = 429 then title = "Too many attempts · wait, then try again"
                keyboard("parentpin",title,"")
            end if
            return true
        end if
        if tag = "auth:profile" and code = "parent_required"
            m.parentAction = "profile"
            keyboard("parentpin","Enter parent PIN","")
            return true
        end if
        if tag = "auth:token" and (code = "authorization_pending" or code = "slow_down" or result.status = 429 or result.status <= 0 or result.status >= 500)
            if m.pairing <> invalid
                if code = "slow_down" or result.status = 429 or result.status <= 0 or result.status >= 500 then m.pairing.interval = AccountClamp(m.pairing.interval + 5,1,60)
                m.authTimer.duration = m.pairing.interval
                m.authTimer.control = "start"
            end if
        else if tag = "auth:refresh" and (result.status <= 0 or result.status >= 500 or result.status = 429)
            m.authTimer.duration = 30
            m.authTimer.control = "start"
            m.status.text = "Connection interrupted. Retrying sign-in…"
        else if tag = "auth:refresh" or code = "revoked" or code = "device_revoked" or code = "invalid_grant"
            accountRevoked()
        else if tag = "auth:newprofile" or tag = "auth:setupprofile" or tag = "auth:deleteprofile"
            m.profileEditor.saving = false
            m.profileEditor.message = "Couldn't save your profile. Please try again."
        else if tag = "auth:profile"
            m.status.text = "That profile is no longer available. Choose another profile."
            m.config.last_profile_id = ""
            request("CONFIG_SAVE","",m.config,"sideconfig")
            request("GET","/api/profiles",invalid,"profiles")
        else
            accountRetry("Sign-in failed or the code expired. Try again.")
        end if
        return true
    end if
    data = result.data
    if tag = "auth:parentunlock"
        m.parentUnlockPending = false
        if data.unlocked = true and m.parentAction = "profilemutation"
            mutation = m.profileMutation
            m.parentAction = ""
            m.profileMutation = invalid
            m.authBusy = true
            m.profileEditor.saving = true
            request(mutation.method,mutation.path,mutation.body,mutation.tag)
        else if data.unlocked = true and m.parentAction = "logout"
            accountSignOut()
        else if m.pendingProfile <> invalid and data.unlocked = true
            accountChoose(m.pendingProfile)
        else
            m.status.text = "Could not unlock. Select a profile to try again."
        end if
    else if tag = "auth:logout"
        m.parentAction = ""
        accountCancelCredentials()
        request("CONFIG_SAVE","",m.config,"sideconfig")
        accountPair()
    else if tag = "auth:code"
        m.pairing = {device_code:data.device_code,expires_at:accountNow()+data.expires_in,interval:AccountClamp(data.interval,1,60)}
        accountShowQr(data)
        m.authTimer.duration = m.pairing.interval
        m.authTimer.control = "start"
    else if tag = "auth:token" or tag = "auth:refresh"
        accountSaveTokens(data)
        if m.profile = "" then accountShowLoading()
        request("GET","/api/auth/me",invalid,"auth:me")
    else if tag = "auth:me"
        m.accountMode = true
        m.config.account_id = Txt(data.account_id)
        m.canCreateProfile = data.can_create_profile = true
        if m.profileEditor <> invalid
            if m.profileEditor.visible then return true
        end if
        if data.profiles <> invalid
            accountUseProfiles(data.profiles)
        else
            request("GET","/api/profiles",invalid,"profiles")
        end if
    else if tag = "auth:profile"
        if Txt(data.access_token) <> "" and Txt(data.refresh_token) <> "" and data.expires_in <> invalid then accountSaveTokens(data)
        if m.pendingProfile <> invalid
            m.profile = Txt(m.pendingProfile.id)
            m.config.last_profile_id = m.profile
            m.identity.text = Txt(m.pendingProfile.name)
            updateProfileNav(m.pendingProfile)
            m.pendingProfile = invalid
            request("CONFIG_SAVE","",m.config,"sideconfig")
            home()
        end if
    else if tag = "auth:newprofile" or tag = "auth:setupprofile"
        m.profileEditor.visible = false
        m.profileDraft = invalid
        if m.managingProfiles = true
            m.profileFocusId = Txt(data.id)
            if Txt(data.id) = m.profile then updateProfileNav(data)
            accountOpenProfiles()
        else
            accountChoose(data)
        end if
    else if tag = "auth:deleteprofile"
        deleted = Txt(m.profileDraft.profile.id)
        m.profileEditor.visible = false
        m.profileDraft = invalid
        m.profileFocusId = ""
        if deleted = m.profile
            accountClearRememberedProfile()
            m.homeData = invalid
            m.homeRoot = invalid
            m.views = []
            request("CONFIG_SAVE","",m.config,"sideconfig")
        end if
        accountOpenProfiles()
    end if
    return true
end function
