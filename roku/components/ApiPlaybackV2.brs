' Background-only lease startup. Backend control never follows media URLs.
function RokuPlaybackV2Start(request as object, result as object) as object
    body = RokuPlaybackV2Body(request,DeviceCapabilities())
    if body = invalid
        result.error = "This device could not report a supported playback configuration."
        return result
    end if
    control = {}
    control.append(request)
    control.body = body
    deadline = 120000
    if MatchInteger(request.timeout_ms,1,120000) then deadline = request.timeout_ms
    clock = CreateObject("roTimespan")
    clock.mark()
    identity = ""
    posted = false
    renewAt = 20000
    waitPort = CreateObject("roMessagePort")
    while true
        remaining = deadline - clock.TotalMilliseconds()
        if m.top.cancel or remaining <= 0 then exit while
        control.timeout_ms = remaining
        method = "POST"
        if posted
            method = "GET"
            control.path = "/api/v2/playback/" + Enc(identity)
            control.body = invalid
        end if
        raw = HttpRequestRaw(control,RokuPlaybackV2Empty(result.tag),method,false)
        posted = true
        if AccountIsObject(raw.data)
            if RokuPlaybackV2Id(raw.data.id) and identity = "" then identity = raw.data.id
        end if
        if not raw.ok
            result = raw
            exit while
        end if
        result = RokuPlaybackV2Result(raw,identity,false)
        if not result.ok then exit while
        if result.data.status = "starting" and clock.TotalMilliseconds() >= renewAt
            heartbeat = {}
            heartbeat.append(control)
            heartbeat.path = "/api/v2/playback/" + Enc(identity) + "/heartbeat"
            heartbeat.body = {}
            heartbeat.timeout_ms = deadline - clock.TotalMilliseconds()
            raw = HttpRequestRaw(heartbeat,RokuPlaybackV2Empty(result.tag),"POST",false)
            if not raw.ok
                result = raw
                exit while
            end if
            result = RokuPlaybackV2Result(raw,identity,false)
            if not result.ok then exit while
            renewAt = clock.TotalMilliseconds() + 20000
        end if
        if result.data.status = "starting" and not m.top.cancel
            progress = {}
            progress.append(control)
            progress.path = "/api/v2/playback/" + Enc(identity) + "/progress"
            progress.body = invalid
            progress.timeout_ms = deadline - clock.TotalMilliseconds()
            if progress.timeout_ms > 1500 then progress.timeout_ms = 1500
            if progress.timeout_ms > 0
                observed = HttpRequestRaw(progress,RokuPlaybackV2Empty(result.tag),"GET",false)
                if observed.ok and AccountIsObject(observed.data) and not m.top.cancel
                    text = RokuTorrentStageText(observed.data.stage)
                    if text <> "" then m.top.startupStage = text
                end if
            end if
        end if
        if result.data.status = "ready"
            if not m.top.cancel and clock.TotalMilliseconds() < deadline
                result.data = result.data.session
                return result
            end if
            exit while
        end if
        for pause = 1 to 5
            if m.top.cancel or clock.TotalMilliseconds() >= deadline then exit for
            event = wait(100,waitPort)
        end for
    end while
    if posted
        refused = result.status >= 400 and result.status < 500 and result.status <> 408
        if identity <> "" or not refused then RokuPlaybackV2Cleanup(request,body,identity)
    end if
    result.ok = false
    result.data = invalid
    if m.top.cancel
        result.error = "Cancelled"
    else if clock.TotalMilliseconds() >= deadline
        result.status = 408
        result.error = "Playback preparation timed out. Try again or choose another source."
    end if
    return result
end function

function RokuPlaybackV2Empty(tag as dynamic) as object
    return {tag:tag,ok:false,data:invalid,error:"",status:0}
end function

function RokuPlaybackV2Result(raw as object, expectedId as string, requireReady as boolean) as object
    lease = RokuPlaybackV2Lease(raw.data,expectedId)
    if not lease.ok
        raw.ok = false
        raw.data = invalid
        raw.error = lease.error
        return raw
    end if
    data = lease.data
    if data.status = "failed" or data.status = "expired" or data.status = "released"
        raw.ok = false
        raw.data = invalid
        raw.status = 409
        raw.error = Txt(data.error,"Playback authorization expired. Start playback again.")
    else if data.expires_at <= CreateObject("roDateTime").asSeconds()
        raw.ok = false
        raw.data = invalid
        raw.status = 410
        raw.error = "Playback authorization expired. Start playback again."
    else if requireReady and data.status <> "ready"
        raw.ok = false
        raw.data = invalid
        raw.error = "Playback is not ready. Start playback again."
    else
        raw.data = data
        if requireReady then raw.data = data.session
    end if
    return raw
end function

' Cancellation has separate authority/deadline; reconciliation reuses the exact body.
sub RokuPlaybackV2Cleanup(request as object, body as object, identity as string)
    control = {}
    control.append(request)
    control.cleanup = true
    control.timeout_ms = 5000
    clock = CreateObject("roTimespan")
    clock.mark()
    if identity = ""
        control.path = "/api/v2/playback"
        control.body = body
        raw = HttpRequestRaw(control,RokuPlaybackV2Empty(request.tag),"POST",false)
        if AccountIsObject(raw.data)
            if RokuPlaybackV2Id(raw.data.id) then identity = raw.data.id
        end if
    end if
    remaining = 5000 - clock.TotalMilliseconds()
    if identity <> "" and remaining > 0
        control.path = "/api/v2/playback/" + Enc(identity)
        control.body = invalid
        control.timeout_ms = remaining
        raw = HttpRequestRaw(control,RokuPlaybackV2Empty(request.tag),"DELETE",false)
    end if
end sub

' Canonical SRC-TORRENT-RUNTIME-002 copy; unknown/raw upstream text is never shown.
function RokuTorrentStageText(value as dynamic) as string
    stage = Txt(value)
    if stage = "finding_peers" then return "Finding peers…"
    if stage = "fetching_metadata" then return "Fetching metadata…"
    if stage = "opening_archive" then return "Opening archive…"
    if stage = "buffering" then return "Buffering…"
    return ""
end function
