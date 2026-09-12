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
    m.searchFocusPending = false
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

sub accountUseProfiles(profiles as dynamic)
    values = AccountProfileRows(profiles,false)
    primary = ""
    for each value in values
        id = Txt(value.id)
        if id <> "" and (primary = "" or val(id) < val(primary)) then primary = id
    end for
    for each value in values
        ' Legacy servers omit this flag; explicit server policy takes precedence.
        if Txt(value.id) <> "" and GetInterface(value.is_primary,"ifBoolean") = invalid then value.is_primary = Txt(value.id) = primary
    end for
    remembered = Txt(m.config.last_profile_id)
    if remembered <> "" and m.switchingProfile <> true and m.managingProfiles <> true
        for each item in values
            if Txt(item.id) = remembered
                if item.presentation_complete = true
                    accountChoose(item)
                else if m.canCreateProfile = true
                    accountStartProfileSetup(item)
                else
                    accountShowProfileGrid(values)
                    m.status.text = "Finish profile setup on your phone at " + Txt(m.config.base,"https://viptv.syek.tech")
                end if
                return
            end if
        end for
        m.config.last_profile_id = ""
        request("CONFIG_SAVE","",m.config,"sideconfig")
    end if
    m.switchingProfile = false
    realCount = 0
    imported = invalid
    for each item in values
        if Txt(item.id) <> ""
            realCount++
            if item.presentation_complete <> true and imported = invalid then imported = item
        end if
    end for
    if m.profileSetupCancelled = true
        m.profileSetupCancelled = false
        accountShowProfileGrid(values)
    else if realCount = 0 and m.canCreateProfile = true
        accountStartProfileSetup(invalid)
    else if realCount = 1 and imported <> invalid and m.canCreateProfile = true
        accountStartProfileSetup(imported)
    else
        accountShowProfileGrid(values)
    end if
end sub

sub accountShowProfileGrid(values as object)
    m.accountProfiles = values
    m.profilePage = 0
    if Txt(m.profileFocusId) <> ""
        for i = 0 to values.count()-1
            if Txt(values[i].id) = m.profileFocusId then m.profilePage = int(i / 5)
        end for
    end if
    accountRenderProfilePage()
end sub

sub accountRenderProfilePage()
    page = AccountProfilePage(m.accountProfiles,m.profilePage)
    m.profilePage = page.index
    values = page.items
    title = "Who's watching?"
    if m.managingProfiles = true then title = "Manage profiles"
    rows(title,values,"profiles","")
    m.heading.translation = [100,146]
    m.heading.width = 1080
    m.heading.horizAlign = "center"
    m.heading.font.size = 44
    if m.profileGrid = invalid then return
    content = CreateObject("roSGNode","ContentNode")
    for each value in values
        child = content.createChild("ContentNode")
        child.addFields(value)
        child.addFields({uiOwnerFocused:false})
    end for
    columns = values.count()
    if columns < 1 then columns = 1
    gridWidth = columns * 178 + (columns - 1) * 34
    m.profileGrid.numColumns = columns
    m.profileGrid.translation = [int((1280 - gridWidth) / 2),252]
    m.profileGrid.content = content
    m.profileGrid.visible = values.count() > 0
    m.profileGrid.jumpToItem = 0
    if Txt(m.profileFocusId) <> ""
        for i = 0 to values.count()-1
            if Txt(values[i].id) = m.profileFocusId then m.profileGrid.jumpToItem = i
        end for
    end if
    m.profileButtons = AccountProfileButtons(m.accountProfiles.count(),m.canCreateProfile = true,m.managingProfiles = true)
    accountFillProfileButtons(m.profileActions,m.profileButtons,240,56,530)
    accountFillProfileButtons(m.profilePages,[{name:"Previous",action:"previous"},{name:"Next",action:"next"}],180,40,612)
    m.profilePages.visible = page.count > 1
    m.profilePageLabel.visible = page.count > 1
    m.profilePageLabel.text = (page.index+1).toStr() + " / " + page.count.toStr()
    if values.count() > 0
        m.profileGrid.setFocus(true)
    else
        m.profileActions.setFocus(true)
    end if
    uiFocusChanged()
end sub

sub accountFillProfileButtons(grid as object,items as object,width as integer,height as integer,y as integer)
    content = CreateObject("roSGNode","ContentNode")
    for each item in items
        child = content.createChild("ContentNode")
        child.title = item.name
        child.addFields({uiWidth:width,uiHeight:height,uiOwnerFocused:false})
    end for
    count = items.count()
    grid.content = content
    grid.visible = count > 0
    if count = 0 then return
    grid.numColumns = count
    grid.translation = [int((1280-count*width-(count-1)*16)/2),y]
end sub

sub accountProfileButtonSelected()
    index = m.profileActions.itemSelected
    if index < 0 or index >= m.profileButtons.count() then return
    accountProfileAction(m.profileButtons[index])
end sub

sub accountProfilePageSelected()
    if m.profilePages.itemSelected = 0
        m.profilePage--
    else
        m.profilePage++
    end if
    page = AccountProfilePage(m.accountProfiles,m.profilePage)
    m.profilePage = page.index
    m.profileFocusId = ""
    if page.items.count() > 0 then m.profileFocusId = Txt(page.items[0].id)
    accountRenderProfilePage()
end sub

function accountProfileKey(key as string) as boolean
    if m.mode <> "profiles" or m.profileGrid = invalid then return false
    if key = "down" and m.profileGrid.hasFocus()
        index = m.profileGrid.itemFocused
        if index <> invalid and m.items <> invalid
            if index >= 0 and index < m.items.count() then m.profileFocusId = Txt(m.items[index].id)
        end if
    end if
    if key = "down" and m.profileGrid.hasFocus() and m.profileActions.visible
        m.profileActions.setFocus(true)
    else if key = "down" and m.profileGrid.hasFocus() and m.profilePages.visible
        m.profilePages.setFocus(true)
    else if key = "up" and m.profileActions.hasFocus() and m.profileGrid.visible
        m.profileGrid.setFocus(true)
    else if key = "down" and m.profileActions.hasFocus() and m.profilePages.visible
        m.profilePages.setFocus(true)
    else if key = "up" and m.profilePages.hasFocus()
        if m.profileActions.visible
            m.profileActions.setFocus(true)
        else
            m.profileGrid.setFocus(true)
        end if
    else
        return false
    end if
    uiFocusChanged()
    return true
end function

sub accountStartProfileSetup(profile as dynamic)
    if m.canCreateProfile <> true
        m.status.text = "Manage profiles on your phone at " + Txt(m.config.base,"https://viptv.syek.tech")
        return
    end if
    cancelBrowse()
    for each node in [m.profileGrid,m.profileActions,m.profilePages,m.profilePageLabel]
        if node <> invalid then node.visible = false
    end for
    m.mode = "profileeditor"
    m.profileDraft = {editing:m.managingProfiles = true,profile:profile,name:"",avatar_style:"disney",avatar_choice:1,avatar_url:"pkg:/images/avatar-characters/disney-1.png"}
    if profile <> invalid
        m.profileDraft.name = Txt(profile.name)
        m.profileDraft.avatar_style = AccountAvatarStyle(profile.avatar_style)
        m.profileDraft.avatar_choice = profile.avatar_choice
        m.profileDraft.avatar_url = AccountAvatarUrl(profile.avatar_url)
    end if
    accountEndLoading()
    uiBusy(false)
    m.profileEditor.draft = m.profileDraft
    m.profileEditor.callFunc("open")
end sub

sub accountSubmitProfileName(name as string)
    if m.profileDraft = invalid then return
    m.profileDraft.name = left(name.trim(),80)
    m.profileEditor.draft = m.profileDraft
    m.profileEditor.callFunc("refresh")
end sub

sub accountEditorAction()
    action = m.profileEditor.action
    m.profileDraft = m.profileEditor.draft
    if action = "name"
        keyboard("accountprofilename","Name this profile",m.profileDraft.name)
    else if action = "cancel"
        m.profileEditor.visible = false
        m.profileDraft = invalid
        m.profileSetupCancelled = true
        accountOpenProfiles()
    else if action = "delete"
        accountConfirmProfileDelete()
    else if action = "submit"
        if m.profileDraft.name.trim() = ""
            m.profileEditor.message = "Enter a name to continue."
            return
        end if
        accountFinishProfileSetup(m.profileDraft.avatar_style)
    end if
end sub

sub accountFinishProfileSetup(styleValue as dynamic)
    if m.profileDraft = invalid or m.authBusy = true then return
    style = AccountAvatarStyle(styleValue)
    if style = "" then return
    body = {name:m.profileDraft.name.trim(),avatar_style:style}
    if m.profileDraft.avatar_choice <> invalid then body.avatar_choice = m.profileDraft.avatar_choice
    m.authBusy = true
    m.profileEditor.saving = true
    m.profileEditor.message = "Saving profile…"
    profile = m.profileDraft.profile
    if profile = invalid
        request("POST","/api/profiles",body,"auth:newprofile")
    else
        body.setup_complete = true
        request("PATCH","/api/profiles/" + Enc(Txt(profile.id)),body,"auth:setupprofile")
    end if
end sub

sub accountProfileAction(item as object)
    if Txt(item.action) = "manageprofiles"
        accountManageProfiles()
    else if Txt(item.action) = "profilesdone"
        m.managingProfiles = false
        accountOpenProfiles()
    else if Txt(item.action) = "newprofile"
        accountStartProfileSetup(invalid)
    else if Txt(item.action) = "accountavatar"
        accountFinishProfileSetup(item.avatar_style)
    else if m.managingProfiles = true or item.presentation_complete <> true
        m.profileFocusId = Txt(item.id)
        accountStartProfileSetup(item)
    else
        accountChoose(item)
    end if
end sub

sub accountChoose(item as object)
    if m.authBusy = true
        m.status.text = "Finishing sign-in. Try that profile again shortly."
        return
    end if
    accountReset()
    m.pendingProfile = item
    m.authBusy = true
    m.status.text = "Opening " + Txt(item.name,"profile") + "…"
    profileId = item.id
    idText = Txt(item.id)
    if CreateObject("roRegex","^[0-9]{1,9}$","").isMatch(idText) then profileId = int(val(idText))
    request("POST","/api/auth/profile",{profile_id:profileId},"auth:profile")
end sub

' Opening the chooser is not signing out, nor clearing the remembered profile.
sub accountOpenProfiles()
    m.switchingProfile = true
    cancelBrowse()
    rows("Who's watching?",[],"profiles","")
    if Txt(m.config.refresh_token) = ""
        accountConnect()
        return
    end if
    request("GET","/api/profiles",invalid,"profiles")
    m.status.text = "Loading profiles…"
end sub

function accountProfileBack() as boolean
    if m.mode <> "profiles" then return false
    if m.parentUnlockPending = true
        m.pendingProfile = invalid
        m.parentUnlockPending = false
        m.authBusy = false
        m.accountEpoch++
    end if
    if m.managingProfiles = true
        m.managingProfiles = false
        accountOpenProfiles()
        return true
    end if
    m.switchingProfile = false
    cancelBrowse()
    if m.profile <> ""
        m.views = []
        home()
    end if
    return true
end function

' PIN is transient: no registry/config writes and no background polling.
sub accountSubmitParentPin(result as object)
    if not result.accepted
        if m.parentAction = "profilemutation"
            m.parentAction = ""
            m.profileMutation = invalid
            m.authBusy = false
            m.profileEditor.callFunc("open")
            return
        end if
        if m.parentAction = "logout"
            m.parentAction = ""
            m.authBusy = false
            showSettings()
            return
        end if
        m.pendingProfile = invalid
        m.authBusy = false
        accountOpenProfiles()
        return
    end if
    pin = Txt(result.text)
    result.text = ""
    if not CreateObject("roRegex","^[0-9]{4,8}$","").isMatch(pin)
        keyboard("parentpin","Enter a 4–8 digit parent PIN","")
        return
    end if
    m.authBusy = true
    m.parentUnlockPending = true
    m.status.text = "Unlocking… Back cancels."
    if m.parentAction = "logout"
        showSettings()
    else if m.profileGrid <> invalid
        m.profileGrid.setFocus(true)
    end if
    request("POST","/api/parent/unlock",{pin:pin},"auth:parentunlock")
end sub

sub accountSignOut()
    m.authBusy = true
    m.status.text = "Signing out…"
    request("POST","/api/auth/logout",{},"auth:logout")
end sub

sub accountManageProfiles()
    m.profileFocusId = Txt(m.profile)
    m.managingProfiles = true
    accountOpenProfiles()
end sub

sub accountConfirmProfileDelete()
    if m.profileDraft = invalid then return
    profile = m.profileDraft.profile
    if profile = invalid then return
    if profile.is_primary = true then return
    dialog = CreateObject("roSGNode","Dialog")
    dialog.title = "Delete " + Txt(profile.name) + "?"
    dialog.message = "This removes this profile's watch history, favorites and preferences. Other profiles are kept."
    dialog.buttons = ["Cancel","Delete profile"]
    dialog.observeField("buttonSelected","accountDeleteConfirmed")
    dialog.observeField("wasClosed","accountDeleteClosed")
    m.top.dialog = dialog
end sub

sub accountDeleteConfirmed(event = invalid as dynamic)
    if m.top.dialog = invalid then return
    if event <> invalid
        if not event.getRoSGNode().isSameNode(m.top.dialog) then return
    end if
    confirmed = m.top.dialog.buttonSelected = 1
    m.top.dialog.close = true
    if not confirmed then return
    if m.profileDraft = invalid then return
    profile = m.profileDraft.profile
    if profile = invalid then return
    if profile.is_primary = true then return
    m.authBusy = true
    m.profileEditor.saving = true
    m.profileEditor.message = "Deleting profile…"
    request("DELETE","/api/profiles/" + Enc(Txt(profile.id)),invalid,"auth:deleteprofile")
end sub

sub accountDeleteClosed()
    if m.profileEditor.visible and m.authBusy <> true then m.profileEditor.callFunc("open")
end sub
