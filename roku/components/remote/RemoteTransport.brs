' Three bounded Task workers; JSON/HTTP never executes on the render thread.
sub rSend(method as string, path as string, body as dynamic, tag as string, context = invalid as dynamic)
    if tag = "auth:persist" and m.pending.doesExist(tag)
        m.persistLatest = ParseJson(FormatJson(body))
        return
    end if
    if m.pending.doesExist(tag) then return
    if m.queue.count() >= 24
        rError("The connection is busy. Try again.")
        return
    end if
    m.sequence++
    request = {method:method,path:path,body:body,tag:tag,base:m.config.base,access_token:m.config.access_token,contract_version:3,request_id:m.epoch.toStr()+"-"+m.sequence.toStr(),epoch:m.epoch,generation:m.generation,context:context}
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
    staleSource = left(tag,8) = "sources:" and RGet(request.context,"source_epoch") <> m.sourceEpoch
    staleSearch = tag = "search" and RGet(request.context,"search_version") <> m.searchVersion
    if staleSearch or staleSource or request.epoch <> m.epoch or (request.generation <> m.generation and left(tag,5) <> "auth:" and left(tag,5) <> "save:" and left(tag,7) <> "player:" and left(tag,8) <> "cleanup:")
        ' A cancelled admission may still succeed on the host. Retire its lease.
        if result.ok and RObject(result.data)
            id = RText(result.data.id)
            if request.path = "/api/playback" and id <> "" then rCleanup("/api/playback/"+REncode(id),request)
            if request.path = "/api/streams" and id <> "" then rCleanup("/api/streams/"+REncode(id),request)
        end if
        return
    end if
    if left(tag,8) = "cleanup:" then return
    if result.status = 401 and tag <> "auth:refresh" and RText(m.config.refresh_token) <> ""
        if request.access_token <> m.config.access_token
            rSend(request.method,request.path,request.body,request.tag,request.context)
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
    if not result.ok and result.status = 403 and result.auth_code = "parent_required"
        m.afterParent = request
        rTextInput("Parent PIN","unlockResume",true,"")
        return
    end if
    if not result.ok
        if tag = "auth:refresh" and (result.status = 401 or result.status = 403)
            rForgetSession()
            rWelcome()
        else if left(tag,7) = "player:"
            rPlayerFailure(tag,result,request)
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
        m.config.access_token = data.access_token
        m.config.refresh_token = data.refresh_token
        m.config.auth_origin = m.config.base
        m.config.auth_version = 3
        m.refreshDue = rNow()+RGet(data,"expires_in",300)-60
        m.pairChallenge = invalid
        for each queued in m.queue
            queued.access_token = data.access_token
        end for
        rSend("CONFIG_SAVE","",m.config,"auth:persist")
        retries = m.retryAuth
        m.retryAuth = []
        if retries.count() = 0
            rSend("GET","/api/bootstrap",invalid,"auth:bootstrap")
        else
            for each retry in retries
                if retry.epoch = m.epoch and retry.generation = m.generation then rSend(retry.method,retry.path,retry.body,retry.tag,retry.context)
            end for
        end if
    else if tag = "auth:bootstrap"
        rBootstrap(data)
    else if tag = "auth:profile"
        m.epoch++
        m.config.last_profile_id = RText(request.body.profile_id)
        m.snapshots = []
        rSend("CONFIG_SAVE","",m.config,"auth:persist")
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

sub rCleanup(path as string, owner as object)
    for each queued in m.queue
        if queued.method = "DELETE" and queued.path = path and queued.base = owner.base and queued.access_token = owner.access_token then return
    end for
    ' Admission is bounded separately at 24. Reserve eight cleanup slots;
    ' the host's expiring leases remain the final cleanup backstop offline.
    if m.queue.count() >= 32 then return
    m.sequence++
    tag = "cleanup:"+m.sequence.toStr()
    m.pending[tag] = m.epoch.toStr()+"-"+m.sequence.toStr()
    m.queue.push({method:"DELETE",path:path,body:invalid,tag:tag,base:owner.base,access_token:owner.access_token,epoch:owner.epoch,generation:m.generation,contract_version:3,cleanup:true,request_id:m.epoch.toStr()+"-"+m.sequence.toStr()})
end sub

function rNow() as double
    return CreateObject("roDateTime").asSeconds()
end function

function rProfilePath(suffix as string) as string
    return "/api/profiles/"+REncode(m.profile)+suffix
end function

sub rForgetSession()
    rStopPlayer()
    m.epoch++
    m.profile = ""
    m.bootstrap = invalid
    m.snapshots = []
    m.retryAuth = []
    m.config.access_token = ""
    m.config.refresh_token = ""
    m.config.last_profile_id = ""
    m.refreshDue = 0
    rSend("CONFIG_SAVE","",m.config,"auth:persist")
end sub

sub rPoll()
    now = rNow()
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
    if m.discovery <> invalid and now >= m.discovery.due
        m.discovery.due = now+1
        rSend("GET","/api/streams/"+REncode(m.discovery.id)+"?after="+m.discovery.after.toStr()+"&wait_ms=1000",invalid,"sources:poll",{source_epoch:m.sourceEpoch})
    end if
    if m.profile <> "" and m.playback = invalid and now >= m.revisionDue
        m.revisionDue = now+30
        rSend("GET",rProfilePath("/revisions"),invalid,"state:revisions")
    end if
    if m.route = "home" and RObject(m.homeData) and m.playback = invalid
        if m.homeData.complete <> true and now >= m.homeDue
            m.homeDue = now+2
            rSend("GET",rProfilePath("/home"),invalid,"home")
        end if
    end if
    rPlayerPoll(now)
    rCarousel(now)
end sub
