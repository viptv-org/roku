' Three bounded Task workers; JSON/HTTP never executes on the render thread.
sub rSend(method as string, path as string, body as dynamic, tag as string, context = invalid as dynamic, query = invalid as dynamic)
    if tag = "auth:persist" and m.pending.doesExist(tag)
        m.persistLatest = RCopy(body)
        return
    end if
    if m.pending.doesExist(tag) then return
    if m.queue.count() >= 24
        rError("The connection is busy. Try again.")
        return
    end if
    m.sequence++
    request = {method:method,path:path,body:RCopy(body),query:RCopy(query),tag:tag,base:m.config.base,access_token:m.config.access_token,contract_version:3,request_id:m.epoch.toStr()+"-"+m.sequence.toStr(),epoch:m.epoch,generation:m.generation,context:RCopy(context)}
    m.pending[tag] = request.request_id
    m.queue.push(request)
    rDispatch()
end sub

sub rDispatch()
    active = []
    mutating = false
    for each worker in m.workers
        if m.running.doesExist(worker.request.request_id)
            active.push(worker)
            if worker.request.method <> "GET" then mutating = true
        end if
    end for
    m.workers = active
    if m.workers.count() >= 3 then return
    chosen = -1
    for i = 0 to m.queue.count()-1
        if m.queue[i].method = "GET" or not mutating
            chosen = i
            exit for
        end if
    end for
    if chosen < 0 then return
    request = m.queue[chosen]
    m.queue.delete(chosen)
    worker = CreateObject("roSGNode","RemoteTask")
    worker.request = request
    worker.observeField("result","rResponse")
    m.workers.push(worker)
    m.running[request.request_id] = true
    worker.control = "RUN"
end sub

sub rResponse(event as object)
    worker = event.getRoSGNode()
    request = worker.request
    result = event.getData()
    m.running.delete(request.request_id)
    tag = request.tag
    if m.pending[tag] = request.request_id then m.pending.delete(tag)
    ' Durable credential writes serialize across profile/origin epochs. Always
    ' drain the latest snapshot, even when the earlier write's UI owner retired.
    if tag = "auth:persist"
        if not result.ok then rError(RText(result.error,"This TV could not save its sign-in."))
        if m.persistLatest <> invalid
            latest = m.persistLatest
            m.persistLatest = invalid
            rSend("CONFIG_SAVE","",latest,"auth:persist")
        end if
        return
    end if
    if tag = "auth:login" and RObject(request.body)
        request.body.password = ""
        worker.request = request
    end if
    if not rRequestCurrent(request)
        if rPinTag(tag) and RObject(request.body)
            request.body.pin = ""
            worker.request = request
        end if
        if result.ok and request.epoch = m.epoch and (tag = "save:profile" or rPinTag(tag))
            m.revisionDue = 0
            m.profilesRefreshPending = true
            rInvalidateReturnViews()
            if not rInputVisible() and not m.drawer.visible
                if rPinTag(tag) and m.route = "settings" and m.section = "Parental controls"
                    rSend("GET","/api/parent/status",invalid,"settings:parent")
                else if tag = "save:profile" and m.route = "profiles"
                    rSend("GET","/api/profiles",invalid,"profiles")
                end if
            end if
        end if
        ' A cancelled admission may still succeed on the host. Retire its lease.
        if result.ok and RObject(result.data)
            if (tag = "auth:login" or tag = "auth:refresh") and RText(result.data.access_token) <> ""
                owner = {base:request.base,access_token:result.data.access_token,epoch:request.epoch}
                if request.base <> m.config.base or result.data.access_token <> m.config.access_token then rCleanup("/api/auth/logout",owner,"POST")
            end if
            id = RText(result.data.id)
            if (request.path = "/api/playback" or tag = "player:poll") and id <> "" then rCleanup("/api/playback/"+REncode(id),request)
            if request.path = "/api/streams" and id <> "" then rCleanup("/api/streams/"+REncode(id),request)
        end if
        return
    end if
    if left(tag,8) = "cleanup:" then return
    if tag = "auth:profile" and not result.ok and request.generation <> m.generation
        if result.status = 0 or result.status >= 500 or (result.status >= 200 and result.status < 300) then rSend("GET","/api/bootstrap",invalid,"auth:bootstrap")
        return
    end if
    if result.status = 401 and tag <> "auth:refresh" and tag <> "auth:login" and RText(m.config.refresh_token) <> ""
        if request.access_token <> m.config.access_token
            rSend(request.method,request.path,request.body,request.tag,request.context,request.query)
            return
        end if
        if m.retryAuth.count() >= 8 and tag = "save:profile"
            rProfileMutationFailure(request,"The connection is busy. Try again.")
            return
        else if m.retryAuth.count() >= 8 and rPinTag(tag)
            rPinFailure(request,"The connection is busy. Enter your PIN again.")
            return
        end if
        if m.retryAuth.count() < 8 then m.retryAuth.push(request)
        rSend("POST","/api/auth/device/refresh",{refresh_token:m.config.refresh_token},"auth:refresh")
        return
    end if
    if tag = "auth:token" and (result.auth_code = "authorization_pending" or result.status = 429)
        if result.status = 429 then m.pairDue = rNow()+10
        return
    end if
    if not result.ok and tag = "save:preferences" and request.generation <> m.generation
        m.revisionDue = 0
        return
    end if
    if not result.ok and tag = "auth:refresh" and result.status <> 401 and result.status <> 403
        released = rReleaseFormAuthRetries(RText(result.error,"Sign-in refresh could not finish. Try again."))
        if released and m.retryAuth.count() = 0 then return
    end if
    if rPinTag(tag) and RObject(request.body)
        request.body.pin = ""
        worker.request = request
    end if
    if not result.ok and tag = "save:profile"
        if result.status <> 403 or result.auth_code <> "parent_required"
            rProfileMutationFailure(request,RText(result.error,"Changes could not be saved. Try again."))
            return
        end if
    end if
    if not result.ok and rPinTag(tag)
        message = RText(result.error,"The parent PIN was not accepted. Try again.")
        if result.auth_code = "parent_pin_invalid" then message = "That parent PIN was not accepted. Try again."
        rPinFailure(request,message)
        return
    end if
    backgroundLive = rLiveDataTag(tag) and tag <> "live" and tag <> RText(m.liveRetryTag)
    if not result.ok and result.status = 403 and result.auth_code = "parent_required" and not backgroundLive
        m.afterParent = request
        rTextInput("Parent PIN","unlockResume",true,"")
        return
    end if
    if not result.ok
        if tag = "auth:login"
            m.passwordForm.busy = false
            m.passwordForm.error = RText(result.error,"Sign-in failed. Try again.")
            if result.status = 401 then m.passwordForm.error = "Check your username and password."
            return
        end if
        if tag = "auth:refresh" and (result.status = 401 or result.status = 403)
            rForgetSession()
            rWelcome()
        else if left(tag,7) = "player:"
            rPlayerFailure(tag,result,request)
        else if rSearchTag(tag)
            rSearchFailure(request,RText(result.error,"Search is unavailable. Try again."))
        else if rLiveDataTag(tag)
            m.failedRequest = request
            m.liveFailureText = RText(result.error,"Live information could not be loaded. Try again.")
            if not m.drawer.visible and not rInputVisible() and m.playback = invalid then rError(m.liveFailureText)
        else if tag <> "auth:persist" and left(tag,5) <> "save:"
            m.failedRequest = request
            rError(RText(result.error,"The server could not complete this request."))
        else
            rError(RText(result.error,"Changes could not be saved. Try again."))
            if result.status = 409 and tag = "save:preferences" then rSend("GET",rProfilePath("/preferences"),invalid,"settings:preferences")
        end if
        return
    end if
    data = result.data
    if tag = "auth:config"
        m.config = data
        rStartupActions()
        if RText(m.config.base) = "" then m.config.base = "https://viptv.syek.tech"
        if RText(m.config.refresh_token) <> ""
            rSend("POST","/api/auth/device/refresh",{refresh_token:m.config.refresh_token},"auth:refresh")
        else
            rWelcome()
        end if
    else if tag = "auth:refresh" or tag = "auth:token" or tag = "auth:login"
        if RText(data.access_token) = "" or RText(data.refresh_token) = ""
            rError("The server returned an invalid sign-in response.")
            return
        end if
        if tag = "auth:login" then m.passwordForm.callFunc("resetForm")
        m.config.access_token = data.access_token
        m.config.refresh_token = data.refresh_token
        m.config.auth_origin = m.config.base
        m.config.auth_version = 3
        m.refreshDue = rNow()+RGet(data,"expires_in",300)-60
        m.pairChallenge = invalid
        for each queued in m.queue
            if queued.base = m.config.base and queued.epoch = m.epoch
                if left(queued.tag,8) <> "cleanup:" or queued.method = "DELETE" then queued.access_token = data.access_token
            end if
        end for
        rSend("CONFIG_SAVE","",m.config,"auth:persist")
        retries = m.retryAuth
        m.retryAuth = []
        if retries.count() = 0
            if m.keyboard.visible and m.inputPurpose = "server"
                m.bootstrapDeferred = true
            else
                rSend("GET","/api/bootstrap",invalid,"auth:bootstrap")
            end if
        else
            for each retry in retries
                if rRequestCurrent(retry) then rSend(retry.method,retry.path,retry.body,retry.tag,retry.context,retry.query)
            end for
        end if
    else if tag = "auth:bootstrap"
        if m.keyboard.visible and m.inputPurpose = "server"
            m.deferredBootstrap = data
        else
            rBootstrap(data)
        end if
    else if tag = "auth:profile"
        rStopPlayer()
        m.epoch++
        rClearProfileViews()
        m.profile = ""
        m.bootstrap = invalid
        m.bootstrapScope = invalid
        rSend("GET","/api/bootstrap",invalid,"auth:bootstrap")
    else if tag = "auth:code"
        m.pairChallenge = data
        m.pairExpires = rNow()+RGet(data,"expires_in",0)
        m.pairDue = rNow()+RGet(data,"interval",5)
        rShowPair(data)
    else if tag = "auth:logout"
        rForgetSession()
        rWelcome()
    else if left(tag,7) = "player:"
        rPlayerResponse(tag,data,request)
    else if left(tag,5) = "save:"
        rSaved(tag,data,request)
    else
        rPageResponse(tag,data,request)
    end if
end sub

sub rCleanup(path as string, owner as object, method = "DELETE" as string)
    token = owner.access_token
    ' Resource cleanup may outlive a token rotation, but never borrow another
    ' identity's credential. Explicit grant revocation keeps its exact token.
    if method = "DELETE" and owner.base = m.config.base and owner.epoch = m.epoch
        if RText(m.config.access_token) <> "" then token = m.config.access_token
    end if
    for each queued in m.queue
        if queued.method = method and queued.path = path and queued.base = owner.base and queued.access_token = token then return
    end for
    ' Admission is bounded separately at 24. Reserve eight cleanup slots;
    ' the host's expiring leases remain the final cleanup backstop offline.
    if m.queue.count() >= 32 then return
    m.sequence++
    tag = "cleanup:"+m.sequence.toStr()
    m.pending[tag] = m.epoch.toStr()+"-"+m.sequence.toStr()
    body = invalid
    if method = "POST" then body = {}
    m.queue.push({method:method,path:path,body:body,tag:tag,base:owner.base,access_token:token,epoch:owner.epoch,generation:m.generation,contract_version:3,cleanup:true,request_id:m.epoch.toStr()+"-"+m.sequence.toStr()})
end sub

function rNow() as double
    return CreateObject("roDateTime").asSeconds()
end function

function rProfilePath(suffix as string) as string
    return "/api/profiles/"+REncode(m.profile)+suffix
end function

sub rForgetSession()
    rRetireIdentityReads(true)
    rStopPlayer()
    m.epoch++
    m.profile = ""
    m.bootstrap = invalid
    m.deferredBootstrap = invalid
    m.bootstrapDeferred = false
    m.resumePairingAfterServer = false
    rClearProfileViews()
    m.retryAuth = []
    m.config.access_token = ""
    m.config.refresh_token = ""
    m.config.account_id = ""
    m.refreshDue = 0
    rSend("CONFIG_SAVE","",m.config,"auth:persist")
end sub

sub rPoll()
    now = rNow()
    if m.route = "pairing" then rPairExpiry()
    if m.pairChallenge <> invalid
        if now >= m.pairExpires
            m.pairChallenge = invalid
            rError("This sign-in code expired. Request a new code.")
        else if now >= m.pairDue
            m.pairDue = now+RGet(m.pairChallenge,"interval",5)
            rSend("POST","/api/auth/device/token",{device_code:m.pairChallenge.device_code},"auth:token")
        end if
    end if
    if m.refreshDue > 0 and now >= m.refreshDue
        m.refreshDue = now+60
        rSend("POST","/api/auth/device/refresh",{refresh_token:m.config.refresh_token},"auth:refresh")
    end if
    if m.discovery <> invalid and RText(m.discovery.id) <> "" and now >= m.discovery.due
        m.discovery.due = now+1
        rSend("GET","/api/streams/"+REncode(m.discovery.id)+"?after="+m.discovery.after.toStr()+"&wait_ms=1000",invalid,"sources:poll",{source_epoch:m.sourceEpoch})
    end if
    if m.profile <> "" and m.playback = invalid and now >= m.revisionDue
        m.revisionDue = now+30
        rSend("GET",rProfilePath("/revisions"),invalid,"state:revisions")
    end if
    if m.profilesRefreshPending and m.route = "profiles" and not m.drawer.visible and not rInputVisible() then rProfiles(m.management)
    if m.route = "home" and RObject(m.homeData) and m.playback = invalid
        if m.homeRefreshPending and not m.drawer.visible and not rInputVisible() then rHome(m.homeData)
        if m.homeData.complete <> true and now >= m.homeDue
            m.homeDue = now+2
            rSend("GET",rProfilePath("/home"),invalid,"home")
        end if
    end if
    rRefreshVisibleGuides(now)
    rLibraryRefreshPoll(now)
    rPlayerPoll(now)
    rCarousel(now)
end sub

sub rCancelPairing()
    m.pairChallenge = invalid
    m.generation++
    for each worker in m.workers
        if worker.request.tag = "auth:code" or worker.request.tag = "auth:token" then worker.cancel = true
    end for
    retained = []
    for each queued in m.queue
        if queued.tag <> "auth:code" and queued.tag <> "auth:token" then retained.push(queued)
    end for
    m.queue = retained
    m.pending.delete("auth:code")
    m.pending.delete("auth:token")
end sub

function rRequestCurrent(request as object) as boolean
    tag = request.tag
    if tag = "auth:refresh" then return rRefreshOwner(request)
    if request.epoch <> m.epoch then return false
    if tag = "save:profile" and not rProfileMutationCurrent(request) then return false
    if rPinTag(tag) and not rPinCurrent(request) then return false
    if (tag = "browse" or tag = "library") and RGet(request.context,"catalog_version") <> m.catalogVersion then return false
    if (tag = "auth:code" or tag = "auth:token" or tag = "auth:login") and request.generation <> m.generation then return false
    if (left(tag,8) = "sources:" or tag = "live:sources" or tag = "viewing") and RGet(request.context,"source_epoch") <> m.sourceEpoch then return false
    if rSearchTag(tag) and RGet(request.context,"search_version") <> m.searchVersion then return false
    if tag = "search:channels"
        if not rSearchChannelCurrent(request) then return false
    end if
    if rLiveDataTag(tag)
        if RGet(request.context,"live_version") <> m.liveVersion or RGet(request.context,"query") <> m.liveQuery then return false
        if tag = "live:page" and not rLivePageCurrent(request) then return false
    end if
    if tag = "calendar"
        if RGet(request.context,"version") <> m.calendarVersion then return false
        if RGet(request.context,"day") <> m.calendarDay or RGet(request.context,"type") <> m.calendarType then return false
        cursor = RText(RGet(request.context,"cursor"))
        if cursor <> "" and cursor <> m.calendarCursor then return false
    end if
    if tag = "player:start" or tag = "player:poll"
        if m.admission = invalid then return false
        if RGet(request.context,"request_id") <> m.admission.request_id then return false
    end if
    if left(tag,13) = "player:renew:"
        id = mid(tag,14)
        if rFindLease(id) = invalid
            if m.admission = invalid then return false
            if m.admission.id <> id then return false
        end if
    end if
    if tag = "player:episodes"
        if not rEpisodeRequestCurrent(request) then return false
    end if
    if tag = "player:next" or tag = "player:first-frame"
        if m.playback = invalid then return false
        if tag = "player:next" and not RPlaybackAllowed(m.playback.session,"next_episode") then return false
        if RGet(request.context,"id") <> m.playback.session.id then return false
    end if
    if request.generation <> m.generation and left(tag,5) <> "auth:" and left(tag,5) <> "save:" and left(tag,7) <> "player:" and left(tag,8) <> "cleanup:" then return false
    return true
end function

sub rClearProfileViews()
    rRetireIdentityReads()
    m.retryAuth = []
    rReset("startup")
    m.navigation.visible = false
    m.top.findNode("entry").mode = "startup"
    m.top.findNode("entry").visible = true
    m.snapshots = []
    m.profilesRefreshPending = false
    m.homeRefreshPending = false
    m.heroTick.control = "stop"
    m.searchTick.control = "stop"
    for each key in ["homeData","heroCard","pendingHomeHero","detailCard","detailData","controls","selectedCatalog","libraryControls","libraryDefaults","libraryQuery","browseQuery","liveData","liveChannel","preferences","membership","management","revisions","afterParent","failedRequest","sourceDraft","sourceField","sourceSchema","sourceSchemas","integrations","addonStates","preferenceControl","editProfile","nextCard","viewingAction","playCard","playSource"]
        m[key] = invalid
    end for
    m.liveFailureText = ""
    m.liveRetryTag = ""
    m.liveGuides = {}
    m.liveOrder = []
    m.livePages = []
    m.cards = []
    m.featured = []
    m.calendarEntries = []
    m.playerEpisodes = []
    m.searchTerm = ""
    m.navigation.profileName = ""
    m.navigation.avatarUri = ""
    for each id in ["grid","shelves","rows","actions","filters","drawerRows","sourceFilters","libraryHeader","settingsNav","playerActions"]
        m[id].content = invalid
    end for
    m.backdrop.uri = ""
    m.heroLogo.uri = ""
    m.heroTitle.text = ""
    m.heroDescription.text = ""
    m.heroMeta.parts = []
    m.heroMeta.badges = []
    m.keyboard.text = ""
    m.passwordForm.username = ""
    m.passwordForm.password = ""
    m.filterPage.callFunc("release")
    m.librarySheet.callFunc("release")
    m.bootstrapScope = invalid
    m.pairChallenge = invalid
    m.qr.uri = ""
    m.pairCode.text = ""
    m.pairAddress.text = ""
    m.drawerTitle.text = ""
    m.drawerSubtitle.text = ""
    m.top.findNode("calendarPoster").uri = ""
    for each id in ["calendarTitle","calendarDescription","playerSubtitle"]
        m.top.findNode(id).text = ""
    end for
end sub

function rRefreshOwner(request as object) as boolean
    token = RText(RGet(request.body,"refresh_token"))
    return token <> "" and request.base = m.config.base and token = RText(m.config.refresh_token)
end function

sub rRetireIdentityReads(forgetRefresh = false as boolean)
    for each worker in m.workers
        request = worker.request
        if request.tag = "auth:bootstrap" then worker.cancel = true
        if request.tag = "auth:refresh" and (forgetRefresh or not rRefreshOwner(request))
            ' Rotation may have committed; retain its worker for reply/cleanup,
            ' but release the old pending slot for a new credential owner.
            if m.pending[request.tag] = request.request_id then m.pending.delete(request.tag)
        end if
    end for
    retained = []
    for each request in m.queue
        retire = request.tag = "auth:bootstrap"
        if request.tag = "auth:refresh" then retire = forgetRefresh or not rRefreshOwner(request)
        if retire
            if m.pending[request.tag] = request.request_id then m.pending.delete(request.tag)
        else
            retained.push(request)
        end if
    end for
    m.queue = retained
    m.pending.delete("auth:bootstrap")
    if forgetRefresh then m.pending.delete("auth:refresh")
end sub
