' Native decoder adapter. Source, resume and episode decisions arrive from host.
sub rStartSource(source as object, position = invalid as dynamic, track = invalid as dynamic)
    if m.admission <> invalid then return
    if m.replacement <> invalid
        if m.drawer.visible then m.drawerMessage.text = "Playback is still starting…" else m.top.findNode("playerSubtitle").text = "Playback is still starting…"
        return
    end if
    m.playSource = source
    m.playSequence = 0
    id = CreateObject("roDeviceInfo").getRandomUUID()
    body = {request_id:id,stream_id:source.id,client:RPlaybackFacts(m.config.capabilities),force_gateway:true,position:0,resume:RGet(m.viewingAction,"resume",false)}
    if m.playback <> invalid
        if m.playback.source.id = source.id
            for each key in ["audio_track","subtitle_track","subtitles_off"]
                if m.playback.body.doesExist(key) then body[key] = m.playback.body[key]
            end for
        end if
    end if
    if m.playback <> invalid
        if position <> invalid and not RPlaybackAllowed(m.playback.session,"seek") then return
        if RObject(track) and not RPlaybackAllowed(m.playback.session,"tracks") then return
        replacementId = RText(RGet(m.playIntent,"replace_id"))
        if position = invalid and replacementId <> ""
            if replacementId <> m.playback.session.id then return
            if not RObject(track) and not RPlaybackAllowed(m.playback.session,"change_source") then return
            body.resume = false
            body.replace_source = {playback_id:replacementId,observed_position:rPlayerPosition()}
        end if
    end if
    if position <> invalid
        body.position = position
        body.resume = false
    end if
    if RObject(track)
        for each key in track
            body[key] = track[key]
        end for
    end if
    permission = ""
    fromId = ""
    if m.playback <> invalid
        fromId = m.playback.session.id
        if position <> invalid
            permission = "seek"
        else if RObject(track)
            permission = "tracks"
        else if RText(RGet(m.playIntent,"replace_id")) <> ""
            permission = "change_source"
        end if
    end if
    m.admission = {request_id:id,id:"",due:rNow()+120,renew:0,poll:0,body:body,card:m.playCard,source:source,permission:permission,from_id:fromId}
    rSend("POST","/api/playback",body,"player:start",{request_id:id})
    if not m.pending.doesExist("player:start") then m.admission = invalid
    m.drawerMessage.text = "Preparing playback…"
end sub

sub rPlayerResponse(tag as string, data as object, request as object)
    if tag = "player:episodes"
        rPlayerEpisodesResponse(data,request)
    else if tag = "player:start" or tag = "player:poll"
        if m.admission = invalid or RGet(request.context,"request_id") <> m.admission.request_id
            if RText(data.id) <> "" then rCleanup("/api/playback/"+REncode(data.id),request)
            return
        end if
        m.admission.id = RText(data.id)
        m.admission.renew = rNow()+RGet(data,"renew_after_seconds",20)
        m.admission.poll = rNow()+1
        if data.status = "ready"
            if not RGateway(data)
                rAdmissionFailure("The server returned unsupported playback delivery.")
                return
            end if
            nextPlayer = {session:data,card:m.admission.card,source:m.admission.source,body:m.admission.body,renew:m.admission.renew,owner:request,acknowledged:false,firstFrame:false,started:rNow(),sequence:0}
            rLeaseClock(nextPlayer,data)
            m.admission = invalid
            if m.playback <> invalid
                m.replacement = m.playback
                m.replacement.content = m.player.content
                m.replacement.position = m.player.position
            end if
            m.playback = nextPlayer
            rInstallVideo(data)
        else if data.status <> "starting"
            rAdmissionFailure("This source could not start. Choose another source.")
        end if
    else if tag = "player:first-frame"
        if m.playback = invalid or RGet(request.context,"id") <> m.playback.session.id then return
        if data.ok <> true
            rPlaybackError("Playback authorization expired. Try again.")
            return
        end if
        m.playback.acknowledged = true
        rReleaseRecovery()
        rPlaybackEvent("start",false)
    else if tag = "player:next"
        if m.playback = invalid then return
        if not RPlaybackAllowed(m.playback.session,"next_episode") then return
        if RGet(request.context,"id") <> m.playback.session.id then return
        m.nextCard = invalid
        if RCard(data.item) and data.status = "Next" then m.nextCard = data.item
        rShowControls()
    else if left(tag,13) = "player:renew:"
        lease = rFindLease(mid(tag,14))
        if lease = invalid then return
        if data.id <> lease.session.id or data.status <> "ready" or RGet(RGet(data,"delivery",{}),"url") <> lease.session.delivery.url
            if m.replacement <> invalid and lease.session.id = m.replacement.session.id
                rReleaseRecovery()
            else
                rPlaybackError("Playback authorization changed. Try again.")
            end if
            return
        end if
        changed = not REqual(lease.session.actions,data.actions)
        lease.session.actions = RCopy(data.actions)
        rLeaseClock(lease,data)
        if m.playback <> invalid and lease.session.id = m.playback.session.id and changed
            if m.admission <> invalid
                permission = RText(RGet(m.admission,"permission"))
                if permission <> "" and RGet(m.admission,"from_id") = lease.session.id
                    if not RPlaybackAllowed(lease.session,permission) then rAdmissionFailure("Playback action is no longer available.")
                end if
            end if
            if not RPlaybackAllowed(lease.session,"next_episode") then m.nextCard = invalid
            if not RPlaybackAllowed(lease.session,"seek") then m.seekPosition = invalid
            if m.drawerKind = "episodes" and not RPlaybackAllowed(lease.session,"episodes") then rCloseDrawer()
            if m.drawerKind = "tracks" and not RPlaybackAllowed(lease.session,"tracks") then rCloseDrawer()
            if m.drawerKind = "sources" and not RPlaybackAllowed(lease.session,"change_source") then rCloseDrawer()
            if m.playerUi.visible and not m.drawer.visible then rShowControls()
        end if
    end if
end sub

sub rInstallVideo(session as object)
    rRetireEpisodeRequests()
    rCancelDiscovery()
    m.pending.delete("player:first-frame")
    d = session.delivery
    m.drawer.visible = false
    m.drawerKind = ""
    m.player.control = "stop"
    content = CreateObject("roSGNode","ContentNode")
    content.url = d.url
    content.streamFormat = d.format
    content.title = m.playback.card.title
    m.player.content = content
    m.player.visible = true
    m.player.control = "play"
    if d.format = "mp4" and d.position > 0 then m.player.seek = d.position
    m.playerTitle.text = m.playback.card.title
    m.top.findNode("playerSubtitle").text = RText(m.playback.card.subtitle)
    m.nextCard = invalid
    m.seekPosition = invalid
    m.lastProgress = rNow()
    ' A new lease starts a new timeline: clear the previous title's fill, thumb
    ' and countdown before the first poll describes this one.
    m.playerProgress.width = 0
    thumb = m.top.findNode("playerThumb")
    thumb.translation = [m.playerTrack.translation[0]-22,thumb.translation[1]]
    m.playerTime.text = rTime(0)
    m.top.findNode("playerRemaining").text = "--:--"
    rShowControls()
end sub

sub rVideoState()
    if m.playback = invalid then return
    state = m.player.state
    if state = "playing"
        if not m.playback.firstFrame
            m.playback.firstFrame = true
            rSend("POST","/api/playback/"+REncode(m.playback.session.id)+"/first-frame",{},"player:first-frame",{id:m.playback.session.id})
        end if
    else if state = "paused"
        rPlaybackEvent("pause",false)
    else if state = "finished"
        rVideoFinished()
    else if state = "error"
        rPlaybackError("This source could not play. Try another source.")
    end if
end sub

sub rVideoFinished()
    if m.playback = invalid then return
    if RGet(m.playback,"ended",false) then return
        m.playback.ended = true
        rPlaybackEvent("stop",true)
        rSaveProgress(true)
        card = m.playback.card
        if RPlaybackAllowed(m.playback.session,"next_episode")
            body = RMetadataFields(card)
            body.identity = card.identity
            body.parent_identity = card.parent_identity
            rSend("POST",rProfilePath("/continue/next"),body,"player:next",{id:m.playback.session.id})
        end if
        rShowControls()
end sub

sub rPlayerPoll(now as double)
    if m.admission <> invalid
        if now >= m.admission.due
            rAdmissionFailure("Playback preparation timed out. Try again.")
        else if m.admission.id <> ""
            if now >= m.admission.poll
                m.admission.poll = now+1
                rSend("GET","/api/playback/"+REncode(m.admission.id),invalid,"player:poll",{request_id:m.admission.request_id})
            end if
            if now >= m.admission.renew
                m.admission.renew = now+20
                rSend("POST","/api/playback/"+REncode(m.admission.id)+"/heartbeat",{},"player:renew:"+m.admission.id)
            end if
        end if
    end if
    if m.playback = invalid then return
    if not m.playback.firstFrame and now-m.playback.started > 30
        rPlaybackError("The video did not start. Try another source.")
        return
    end if
    if m.replacement <> invalid
        if m.replacement.clock.totalMilliseconds() >= m.replacement.remaining*1000 then rReleaseRecovery()
    end if
    for each lease in [m.playback,m.replacement]
        if lease <> invalid
            if lease.clock.totalMilliseconds() >= lease.remaining*1000
                rPlaybackError("Playback authorization expired. Try again.")
                return
            end if
        end if
        if lease <> invalid and now >= lease.renew
            lease.renew = now+RGet(lease.session,"renew_after_seconds",20)
            rSend("POST","/api/playback/"+REncode(lease.session.id)+"/heartbeat",{},"player:renew:"+lease.session.id)
        end if
    end for
    if now-m.lastProgress >= 15 and m.playback.firstFrame and not RGet(m.playback,"ended",false)
        m.lastProgress = now
        rSaveProgress(false)
    end if
    rPaintPlayerClock()
end sub

' Timeline + readout. Split out of the poll so a key press can repaint the scrub
' preview immediately without re-entering the lease bookkeeping.
sub rPaintPlayerClock()
    if m.playback = invalid then return
    live = m.playback.session.delivery.live = true
    position = rPlayerPosition()
    duration = rPlayerDuration()
    if position < 0 then position = 0
    target = position
    if m.seekPosition <> invalid then target = m.seekPosition
    if target < 0 then target = 0
    if duration > 0 and target > duration then target = duration
    ' The readout keeps describing the playing position; the scrub target only
    ' rides the thumb, exactly like the Android TV timeline.
    m.playerTime.text = rTime(position)
    m.top.findNode("playerRemaining").text = "--:--"
    m.top.findNode("playerEnds").text = ""
    ' While a scrub is pending the pill row steps aside, exactly like the
    ' Android TV player, so the preview has the whole band above the timeline.
    if m.playerUi.visible then m.playerActions.visible = m.seekPosition = invalid
    thumb = m.top.findNode("playerThumb")
    thumb.visible = duration > 0 and not live and RPlaybackAllowed(m.playback.session,"seek")
    m.playerProgress.width = 0
    m.top.findNode("seekDelta").visible = false
    m.top.findNode("seekBubble").visible = false
    if live
        m.playerTime.text = "LIVE"
        m.top.findNode("playerRemaining").text = ""
    else if duration > 0
        remaining = duration-position
        if remaining < 0 then remaining = 0
        m.top.findNode("playerRemaining").text = "−"+rTime(remaining)
        trackX = m.playerTrack.translation[0]
        trackWidth = m.playerTrack.width
        liveFraction = position/duration
        if liveFraction > 1 then liveFraction = 1
        targetFraction = target/duration
        if targetFraction > 1 then targetFraction = 1
        m.playerProgress.width = trackWidth*liveFraction
        thumb.translation = [trackX+trackWidth*targetFraction-22,thumb.translation[1]]
        if m.seekPosition <> invalid
            ' Delta band between what is playing and where the remote is pointing,
            ' plus a time pill above the thumb.
            ' ("to" is a BrightScript keyword, so the band uses startF/endF.)
            startF = liveFraction
            endF = targetFraction
            if startF > endF
                swap = startF
                startF = endF
                endF = swap
            end if
            delta = m.top.findNode("seekDelta")
            delta.translation = [trackX+trackWidth*startF,m.playerTrack.translation[1]]
            delta.width = trackWidth*(endF-startF)
            delta.visible = true
            bubble = m.top.findNode("seekBubble")
            bubbleX = trackX+trackWidth*targetFraction-98
            if bubbleX < trackX then bubbleX = trackX
            if bubbleX > trackX+trackWidth-196 then bubbleX = trackX+trackWidth-196
            bubble.translation = [bubbleX,m.playerTrack.translation[1]-70]
            jump = int(target-position)
            arrow = "+"
            if jump < 0 then arrow = "−"
            m.top.findNode("seekBubbleText").text = rTime(target)+"  "+arrow+abs(jump).toStr()+"s"
            bubble.visible = true
        end if
        m.top.findNode("playerEnds").text = "Ends at "+rClockTime(remaining)
    end if
end sub

sub rLeaseClock(lease as object, data as object)
    lease.clock = CreateObject("roTimespan")
    lease.clock.mark()
    lease.remaining = RGet(data,"expires_at",0)-rNow()
    lease.renew = rNow()+RGet(data,"renew_after_seconds",20)
end sub

function rFindLease(id as string) as dynamic
    for each lease in [m.playback,m.replacement]
        if lease <> invalid
            if lease.session.id = id then return lease
        end if
    end for
    return invalid
end function

sub rPlayerFailure(tag as string, result as object, request as object)
    if tag = "player:episodes"
        if not rEpisodeRequestCurrent(request) then return
        m.episodeFailed = {id:request.context.id,version:request.context.episode_version,cursor:request.context.cursor,append:request.context.append}
        values = []
        for each card in RArray(m.playerEpisodes)
            values.push({title:card.title,subtitle:RText(card.subtitle),episode:card,action:"player:episode",ring:false})
        end for
        values.push({title:"Retry",action:"player:retryEpisodes",ring:false})
        focus = m.drawerRows.itemFocused
        rDrawerLayout("episodes")
        m.drawerRows.content = rContent(values,rDrawerContentWidth(),rDrawerRowHeight("episodes"))
        if focus >= 0 and focus < values.count() then m.drawerRows.jumpToItem = focus
        m.drawerMessage.text = RText(result.error,"Could not load episodes. Try again.")
        if values.count() = 1 then m.drawerRows.setFocus(true)
        return
    end if
    if left(tag,13) = "player:renew:"
        lease = rFindLease(mid(tag,14))
        if lease = invalid
            if m.admission = invalid then return
            if m.admission.id <> mid(tag,14) then return
            rAdmissionFailure(RText(result.error,"Playback preparation could not continue. Try again."))
            return
        else
            transient = result.status = 0 or result.status = 408 or result.status = 429 or result.status >= 500
            if transient and lease.clock.totalMilliseconds() < lease.remaining*1000
                lease.renew = rNow()+2
                return
            end if
            if m.replacement <> invalid and lease.session.id = m.replacement.session.id
                rReleaseRecovery()
                return
            end if
        end if
    else if tag = "player:first-frame" or tag = "player:next"
        if m.playback = invalid then return
        if RGet(request.context,"id") <> m.playback.session.id then return
    else if tag = "player:start" or tag = "player:poll"
        if m.admission = invalid then return
        if RGet(request.context,"request_id") <> m.admission.request_id then return
        rAdmissionFailure(RText(result.error,"This source could not start. Try again."))
        return
    end if
    rPlaybackError(RText(result.error,"Playback failed. Try again."))
end sub

function rPlayerPosition() as double
    if m.playback = invalid then return 0
    return m.player.position+RGet(m.playback.session.delivery,"timeline_offset_seconds",0)
end function

' Length of the title in original-title seconds. The producer advertises the full
' source duration; when it reports 0 (a stream it could not probe) the decoder's
' own duration is used, in the same cut-window coordinates as the player clock.
function rPlayerDuration() as double
    if m.playback = invalid then return 0
    duration = RGet(m.playback.session.delivery,"duration",0)
    if duration > 0 then return duration
    observed = m.player.duration
    if observed > 0 then return observed+RGet(m.playback.session.delivery,"timeline_offset_seconds",0)
    return 0
end function

' Local wall-clock time for "Ends at", matching the Android TV player's h:mm AM/PM.
function rClockTime(remaining as double) as string
    date = CreateObject("roDateTime")
    date.fromSeconds(date.asSeconds()+int(remaining))
    date.toLocalTime()
    hours = date.getHours()
    suffix = " AM"
    if hours >= 12 then suffix = " PM"
    if hours > 12 then hours -= 12
    if hours = 0 then hours = 12
    return hours.toStr()+":"+right("0"+date.getMinutes().toStr(),2)+suffix
end function

' Readout format shared with the KMP player: minutes under an hour, h:mm:ss above
' it, so a feature never reads as "104:00".
function rTime(seconds as double) as string
    total = int(seconds)
    if total < 0 then total = 0
    hours = int(total/3600)
    minutes = int((total mod 3600)/60)
    remainder = total mod 60
    if hours > 0 then return hours.toStr()+":"+right("0"+minutes.toStr(),2)+":"+right("0"+remainder.toStr(),2)
    return minutes.toStr()+":"+right("0"+remainder.toStr(),2)
end function

sub rShowControls()
    if m.playback = invalid then return
    values = []
    if RPlaybackAllowed(m.playback.session,"episodes") then values.push({title:"Episodes",icon:"remote-list",action:"player:episodes",width:250,ring:false,heroAction:true})
    if RPlaybackAllowed(m.playback.session,"tracks") then values.push({title:"Audio & subtitles",icon:"remote-captions",action:"player:tracks",width:340,ring:false,heroAction:true})
    if RPlaybackAllowed(m.playback.session,"change_source") then values.push({title:"Source",icon:"remote-sliders",action:"player:sources",width:210,ring:false,heroAction:true})
    if RPlaybackAllowed(m.playback.session,"next_episode") and m.nextCard <> invalid then values.push({title:"Next episode",icon:"next",action:"player:next",width:280,ring:false,heroAction:true})
    m.playerActions.content = rContent(values,240,56)
    m.playerUi.visible = true
    if values.count() > 0 then m.playerActions.setFocus(true) else m.playerInput.setFocus(true)
    m.hideControls.control = "stop"
    m.hideControls.control = "start"
end sub

sub rHideControls()
    if m.drawer.visible or m.seekPosition <> invalid then return
    ' Paused playback keeps its controls, like the Android TV player.
    if m.player.state = "paused" then return
    m.playerUi.visible = false
    m.playerInput.setFocus(true)
end sub

sub rPlayerSelected()
    if m.playerActions.content = invalid then return
    node = m.playerActions.content.getChild(m.playerActions.itemSelected)
    if node <> invalid then rPlayerAction(node.wire)
end sub

sub rPlayerAction(value as object)
    if m.playback = invalid then return
    action = value.action
    if action = "player:pause"
        if not RPlaybackAllowed(m.playback.session,"pause") then return
        if m.player.state = "paused" then m.player.control = "resume" else m.player.control = "pause"
        rShowControls()
    else if action = "player:sources"
        if not RPlaybackAllowed(m.playback.session,"change_source") then return
        m.playCard = m.playback.card
        m.playIntent = {explicit:true,replace_id:m.playback.session.id}
        m.top.removeChild(m.drawer)
        m.top.appendChild(m.drawer)
        rDiscoverSources(m.playCard)
    else if action = "player:tracks"
        if not RPlaybackAllowed(m.playback.session,"tracks") then return
        values = []
        for each track in RArray(m.playback.session.delivery.audio_tracks)
            if RTrackSelectable(track) then values.push({title:"Audio · "+RText(track.title,RText(track.language,"Track")),action:"player:track",track:{audio_track:track.input_index}})
        end for
        if m.playback.session.delivery.subtitles_supported = true then values.push({title:"Subtitles off",action:"player:track",track:{subtitles_off:true}})
        for each track in RArray(m.playback.session.delivery.subtitle_tracks)
            if RTrackSelectable(track) then values.push({title:"Subtitles · "+RText(track.title,RText(track.language,"Track")),action:"player:track",track:{subtitle_track:track.input_index,subtitles_off:false}})
        end for
        m.top.removeChild(m.drawer)
        m.top.appendChild(m.drawer)
        rOpenDrawer("Subtitles & audio",values,"tracks")
    else if action = "player:track"
        if not RPlaybackAllowed(m.playback.session,"tracks") then return
        m.playCard = m.playback.card
        m.playIntent = {explicit:true,replace_id:m.playback.session.id}
        rStartSource(m.playback.source,invalid,value.track)
    else if action = "player:next"
        if not RPlaybackAllowed(m.playback.session,"next_episode") or not RCard(m.nextCard) then return
        card = m.nextCard
        rStopPlayer()
        rCancelDiscovery()
        m.playIntent = {explicit:false}
        rSend("POST",rProfilePath("/viewing-action"),{card:card,restart:false},"viewing",{source_epoch:m.sourceEpoch})
    else if action = "player:retryEpisodes"
        failed = m.episodeFailed
        if not RObject(failed) or m.playback = invalid then return
        if failed.id <> m.playback.session.id or failed.version <> m.episodeVersion then return
        m.episodeFailed = invalid
        rPlayerEpisodes(failed.cursor,failed.append)
    else if action = "player:episodes"
        if not RPlaybackAllowed(m.playback.session,"episodes") then return
        m.playerEpisodes = []
        m.episodeCursor = ""
        m.top.removeChild(m.drawer)
        m.top.appendChild(m.drawer)
        rOpenDrawer("Episodes",[],"episodes")
        rPlayerEpisodes("0",false)
    else if action = "player:episode"
        card = value.episode
        rStopPlayer()
        m.drawer.visible = false
        m.drawerStack = []
        rCancelDiscovery()
        m.playIntent = {explicit:false}
        rSend("POST",rProfilePath("/viewing-action"),{card:card,restart:false},"viewing",{source_epoch:m.sourceEpoch})
    end if
end sub

sub rPlayerEpisodes(cursor as string, appendPage as boolean)
    if m.playback = invalid then return
    if not RPlaybackAllowed(m.playback.session,"episodes") then return
    card = m.playback.card
    parent = card.parent_identity
    if not RObject(parent) then return
    if not appendPage
        rRetireEpisodeRequests()
        m.playerEpisodes = []
        m.episodeCursor = ""
        rDrawerLayout("episodes")
        m.drawerRows.content = rContent([],rDrawerContentWidth(),rDrawerRowHeight("episodes"))
    else
        if m.episodeFailed <> invalid or cursor <> m.episodeCursor then return
    end if
    rDrawerLayout(m.drawerKind)
    m.drawerMessage.text = "Loading episodes…"
    query = {offset:cursor,limit:"24"}
    if card.metadata_origin <> invalid
        expected = RCopy(card)
        expected.identity = parent
        expected.parent_identity = invalid
        query.metadata_origin = card.metadata_origin
        query.card = expected
    else
        query.provider_id = card.provider_id
    end if
    rSend("GET","/api/meta/"+REncode(parent.kind)+"/"+REncode(parent.id),invalid,"player:episodes",{id:m.playback.session.id,append:appendPage,cursor:cursor,episode_version:m.episodeVersion},query)
end sub

sub rPlayerEpisodesResponse(data as object, request as object)
    if not rEpisodeRequestCurrent(request) then return
    hadRows = m.drawerRows.content <> invalid
    if hadRows then hadRows = m.drawerRows.content.getChildCount() > 0
    m.episodeFailed = invalid
    m.drawerMessage.text = ""
    m.episodeCursor = ""
    if not request.context.append then m.playerEpisodes = []
    m.playerEpisodes.append(RArray(data.episodes))
    while m.playerEpisodes.count() > 300
        m.playerEpisodes.shift()
    end while
    values = []
    for each card in m.playerEpisodes
        values.push({title:card.title,subtitle:RText(card.subtitle),episode:card,action:"player:episode",ring:false})
    end for
    rDrawerLayout("episodes")
    focus = m.drawerRows.itemFocused
    m.drawerRows.content = rContent(values,rDrawerContentWidth(),rDrawerRowHeight("episodes"))
    if focus >= 0 and focus < values.count() then m.drawerRows.jumpToItem = focus
    seasons = []
    for each season in RArray(data.seasons)
        label = "Episodes"
        if season.season <> invalid then label = "Season "+season.season.toStr()
        seasons.push({title:label,offset:season.offset,width:200})
    end for
    m.sourceFilters.content = rContent(seasons,200,52)
    m.sourceFilters.visible = seasons.count() > 1
    m.sourceFilters.containerWidth = rDrawerContentWidth()
    rDrawerLayout("episodes")
    m.episodeCursor = RText(data.next_cursor)
    if values.count() = 0
        m.drawerMessage.text = "No episodes are available."
        if m.sourceFilters.visible then m.sourceFilters.setFocus(true)
    else if not hadRows and not m.sourceFilters.isInFocusChain()
        m.drawerRows.setFocus(true)
    end if
end sub

' Transport keys follow the Android TV player: Left/Right scrub at any time with
' a live preview, OK commits the scrub (or toggles playback when nothing is
' pending), Up/Down move between the timeline and the action pills.
function rPlayerKey(key as string) as boolean
    if m.drawer.visible then return false
    if key = "play"
        rPlayerAction({action:"player:pause"})
    else if key = "left" or key = "right" or key = "rewind" or key = "fastforward"
        if not RPlaybackAllowed(m.playback.session,"seek") then return true
        position = rPlayerPosition()
        if m.seekPosition <> invalid then position = m.seekPosition
        delta = 10
        if key = "left" or key = "rewind" then delta = -10
        position += delta
        duration = rPlayerDuration()
        if position < 0 then position = 0
        if duration > 0 and position > duration then position = duration
        m.seekPosition = position
        m.playerUi.visible = true
        m.hideControls.control = "stop"
        m.playerInput.setFocus(true)
        rPaintPlayerClock()
    else if key = "OK" and m.seekPosition <> invalid
        if not RPlaybackAllowed(m.playback.session,"seek") then return true
        position = m.seekPosition
        m.seekPosition = invalid
        m.top.findNode("seekBubble").visible = false
        m.top.findNode("seekDelta").visible = false
        m.playCard = m.playback.card
        rStartSource(m.playback.source,position)
    else if key = "up" and m.playerInput.isInFocusChain()
        rShowControls()
    else if key = "down" and m.playerActions.isInFocusChain()
        m.playerInput.setFocus(true)
        m.hideControls.control = "stop"
    else if key = "OK"
        if m.seekPosition <> invalid
            ' handled above
        else if not m.playerUi.visible
            rShowControls()
        else if not m.playerActions.isInFocusChain()
            rPlayerAction({action:"player:pause"})
        end if
    else if key = "options" or key = "info"
        rShowControls()
    else
        return false
    end if
    return true
end function

sub rSaveProgress(ended as boolean)
    if m.playback = invalid then return
    if RGet(m.playback,"ended",false) and not ended then return
    if not RPlaybackAllowed(m.playback.session,"report_progress") then return
    if m.playback.firstFrame <> true then return
    card = m.playback.card
    record = {presentation:card,identity:card.identity,parent_identity:card.parent_identity,provider_id:card.provider_id,title:card.title,poster:card.poster,landscape:card.landscape,position_millis:int(rPlayerPosition()*1000),duration_millis:int(rPlayerDuration()*1000),updated_at_millis:0,metadata_origin:card.metadata_origin}
    rSend("PUT",rProfilePath("/progress"),{record:record,parent_identity:card.parent_identity,ended:ended},"save:progress:"+m.playback.session.id+":"+m.sequence.toStr())
end sub

sub rPlaybackEvent(kind as string, ended as boolean)
    if m.playback = invalid then return
    if RGet(m.playback,"ended",false) and not ended then return
    if not RPlaybackAllowed(m.playback.session,"report_progress") then return
    if m.playback.firstFrame <> true then return
    m.playback.sequence++
    card = m.playback.card
    body = {attempt_id:m.playback.session.id,sequence:m.playback.sequence,identity:card.identity,parent_identity:card.parent_identity,event:kind,position_millis:int(rPlayerPosition()*1000),duration_millis:int(rPlayerDuration()*1000),ended:ended}
    rSend("POST",rProfilePath("/playback-events"),body,"save:event:"+m.playback.session.id+":"+m.playback.sequence.toStr())
end sub

sub rStopPlayer()
    rRetireEpisodeRequests()
    rCancelAdmission()
    if m.playback <> invalid
        if m.playback.ended <> true
            rPlaybackEvent("stop",false)
            rSaveProgress(false)
        end if
        rCleanup("/api/playback/"+REncode(m.playback.session.id),m.playback.owner)
    end if
    if m.replacement <> invalid then rCleanup("/api/playback/"+REncode(m.replacement.session.id),m.replacement.owner)
    m.playback = invalid
    m.replacement = invalid
    m.player.control = "stop"
    m.player.content = invalid
    m.player.visible = false
    m.playerUi.visible = false
    m.seekPosition = invalid
    m.hideControls.control = "stop"
end sub

sub rPlaybackError(message as string)
    if m.replacement <> invalid
        if m.replacement.clock.totalMilliseconds() >= m.replacement.remaining*1000 then rReleaseRecovery()
    end if
    if m.replacement <> invalid
        if m.playback <> invalid then rCleanup("/api/playback/"+REncode(m.playback.session.id),m.playback.owner)
        previous = m.replacement
        m.replacement = invalid
        m.playback = previous
        m.player.control = "stop"
        m.player.content = previous.content
        m.player.control = "play"
        if RPlaybackAllowed(previous.session,"seek") then m.player.seek = previous.position
        rShowControls()
        m.playerTime.text = message
    else
        rStopPlayer()
        rError(message)
        rFocusContent()
    end if
end sub

sub rRetireEpisodeRequests()
    m.episodeVersion++
    m.episodeFailed = invalid
    m.episodeCursor = ""
    for each worker in m.workers
        if worker.request.tag = "player:episodes" then worker.cancel = true
    end for
    retained = []
    for each request in m.queue
        if request.tag <> "player:episodes" then retained.push(request)
    end for
    m.queue = retained
    retained = []
    for each request in m.retryAuth
        if request.tag <> "player:episodes" then retained.push(request)
    end for
    m.retryAuth = retained
    m.pending.delete("player:episodes")
end sub
function rEpisodeRequestCurrent(request as object) as boolean
    if m.playback = invalid or not m.drawer.visible or m.drawerKind <> "episodes" or m.drawerClosing then return false
    if RGet(request.context,"id") <> m.playback.session.id then return false
    if RGet(request.context,"episode_version") <> m.episodeVersion then return false
    if RGet(request.context,"append",false)
        if RGet(request.context,"cursor") <> m.episodeCursor then return false
    end if
    return true
end function

sub rCancelAdmission()
    if m.admission = invalid then return
    id = m.admission.request_id
    renewTag = "player:renew:"+m.admission.id
    for each worker in m.workers
        if RGet(worker.request.context,"request_id") = id or (m.admission.id <> "" and worker.request.tag = renewTag) then worker.cancel = true
    end for
    retained = []
    for each request in m.queue
        if RGet(request.context,"request_id") <> id and (m.admission.id = "" or request.tag <> renewTag) then retained.push(request)
    end for
    m.queue = retained
    retained = []
    for each request in m.retryAuth
        if RGet(request.context,"request_id") <> id and (m.admission.id = "" or request.tag <> renewTag) then retained.push(request)
    end for
    m.retryAuth = retained
    m.pending.delete("player:start")
    m.pending.delete("player:poll")
    if m.admission.id <> "" then m.pending.delete(renewTag)
    path = "/api/playback-requests/"+REncode(id)
    if m.admission.id <> "" then path = "/api/playback/"+REncode(m.admission.id)
    rCleanup(path,{base:m.config.base,access_token:m.config.access_token,epoch:m.epoch})
    m.admission = invalid
end sub
sub rAdmissionFailure(message as string)
    ' Visible in the dev console: the viewer sees the same text on screen, and a
    ' failing source can be reported without a packet capture.
    print "VIPTV_PLAYBACK_FAILURE "; message
    rCancelAdmission()
    if m.drawer.visible
        ' Keep the reason on screen: the source list keeps polling, and every
        ' fresh ranking used to overwrite this line with the selection note
        ' before anyone could read it.
        m.sourceError = message
        rSourceStatus()
        m.drawerRows.setFocus(true)
    else if m.playback <> invalid
        rShowControls()
        m.top.findNode("playerSubtitle").text = message
    else
        rError(message)
        rFocusContent()
    end if
end sub

sub rReleaseRecovery()
    if m.replacement = invalid then return
    previous = m.replacement
    m.replacement = invalid
    tag = "player:renew:"+previous.session.id
    for each worker in m.workers
        if worker.request.tag = tag then worker.cancel = true
    end for
    retained = []
    for each request in m.queue
        if request.tag <> tag then retained.push(request)
    end for
    m.queue = retained
    retained = []
    for each request in m.retryAuth
        if request.tag <> tag then retained.push(request)
    end for
    m.retryAuth = retained
    m.pending.delete(tag)
    rCleanup("/api/playback/"+REncode(previous.session.id),previous.owner)
end sub
