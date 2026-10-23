' Native decoder adapter. Source, resume and episode decisions arrive from host.
sub rStartSource(source as object, position = invalid as dynamic, track = invalid as dynamic)
    if m.admission <> invalid then return
    m.playSource = source
    m.playSequence = 0
    id = rNow().toStr()+"-"+m.sequence.toStr()+"-roku"
    body = {request_id:id,stream_id:source.id,client:RPlaybackFacts(m.config.capabilities),force_gateway:true,position:0,resume:RGet(m.viewingAction,"resume",false)}
    if m.playback <> invalid
        if m.playback.source.id = source.id
            for each key in ["audio_track","subtitle_track","subtitles_off"]
                if m.playback.body.doesExist(key) then body[key] = m.playback.body[key]
            end for
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
    m.admission = {request_id:id,id:"",due:rNow()+120,renew:0,poll:0,body:body,card:m.playCard,source:source}
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
                rPlaybackError("The server returned unsupported playback delivery.")
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
            rPlaybackError("This source could not start. Choose another source.")
        end if
    else if tag = "player:first-frame"
        if m.playback = invalid or RGet(request.context,"id") <> m.playback.session.id then return
        if data.ok <> true
            rPlaybackError("Playback authorization expired. Try again.")
            return
        end if
        m.playback.acknowledged = true
        if m.replacement <> invalid
            rCleanup("/api/playback/"+REncode(m.replacement.session.id),m.replacement.owner)
            m.replacement = invalid
        end if
        rPlaybackEvent("start",false)
    else if tag = "player:next"
        if RCard(data.item) and data.status = "Next"
            m.nextCard = data.item
            rShowControls()
        end if
    else if left(tag,13) = "player:renew:"
        lease = rFindLease(mid(tag,14))
        if lease = invalid then return
        if data.id <> lease.session.id or data.status <> "ready" or RGet(RGet(data,"delivery",{}),"url") <> lease.session.delivery.url
            rPlaybackError("Playback authorization changed. Try again.")
            return
        end if
        rLeaseClock(lease,data)
    end if
end sub

sub rInstallVideo(session as object)
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
        m.playback.ended = true
        rPlaybackEvent("stop",true)
        rSaveProgress(true)
        card = m.playback.card
        if RObject(card.parent_identity)
            body = RMetadataFields(card)
            body.identity = card.identity
            body.parent_identity = card.parent_identity
            rSend("POST",rProfilePath("/continue/next"),body,"player:next")
        end if
        rShowControls()
    else if state = "error"
        rPlaybackError("This source could not play. Try another source.")
    end if
end sub

sub rPlayerPoll(now as double)
    if m.admission <> invalid
        if now >= m.admission.due
            rPlaybackError("Playback preparation timed out. Try again.")
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
    if now-m.lastProgress >= 15 and m.playback.firstFrame
        m.lastProgress = now
        rSaveProgress(false)
    end if
    position = rPlayerPosition()
    duration = RGet(m.playback.session.delivery,"duration",0)
    if m.seekPosition <> invalid then position = m.seekPosition
    m.playerTime.text = rTime(position)
    if m.playback.session.delivery.live = true then m.playerTime.text = "LIVE"
    remaining = duration-position
    if remaining < 0 then remaining = 0
    m.top.findNode("playerRemaining").text = "−"+rTime(remaining)
    m.top.findNode("playerThumb").visible = duration > 0 and m.playback.session.delivery.live <> true
    if duration > 0
        fraction = position/duration
        if fraction > 1 then fraction = 1
        m.playerProgress.width = 1728*fraction
        m.top.findNode("playerThumb").translation = [74+1728*fraction,923]
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
    if left(tag,13) = "player:renew:"
        lease = rFindLease(mid(tag,14))
        if lease = invalid
            if m.admission = invalid then return
            if m.admission.id <> mid(tag,14) then return
        else
            transient = result.status = 0 or result.status = 408 or result.status = 429 or result.status >= 500
            if transient and lease.clock.totalMilliseconds() < lease.remaining*1000
                lease.renew = rNow()+2
                return
            end if
        end if
    else if tag = "player:first-frame"
        if m.playback = invalid then return
        if RGet(request.context,"id") <> m.playback.session.id then return
    else if tag = "player:start" or tag = "player:poll"
        if m.admission = invalid then return
        if RGet(request.context,"request_id") <> m.admission.request_id then return
    end if
    rPlaybackError(RText(result.error,"Playback failed. Try again."))
end sub

function rPlayerPosition() as double
    if m.playback = invalid then return 0
    return m.player.position+RGet(m.playback.session.delivery,"timeline_offset_seconds",0)
end function

function rTime(seconds as double) as string
    minutes = int(seconds/60)
    remainder = int(seconds) mod 60
    return minutes.toStr()+":"+right("0"+remainder.toStr(),2)
end function

sub rShowControls()
    if m.playback = invalid then return
    values = []
    d = m.playback.session.delivery
    if RObject(m.playback.card.parent_identity) then values.push({title:"Episodes",icon:"remote-list",action:"player:episodes",width:250,ring:false,heroAction:true})
    if RArray(d.audio_tracks).count() > 0 or d.subtitles_supported = true then values.push({title:"Audio & subtitles",icon:"remote-captions",action:"player:tracks",width:340,ring:false,heroAction:true})
    values.push({title:"Source",icon:"remote-sliders",action:"player:sources",width:210,ring:false,heroAction:true})
    if m.nextCard <> invalid then values.push({title:"Next episode",icon:"next",action:"player:next",width:280,ring:false,heroAction:true})
    m.playerActions.content = rContent(values,240,56)
    m.playerUi.visible = true
    m.playerActions.setFocus(true)
    m.hideControls.control = "stop"
    m.hideControls.control = "start"
end sub

sub rHideControls()
    if m.drawer.visible or m.seekPosition <> invalid then return
    m.playerUi.visible = false
    m.player.setFocus(true)
end sub

sub rPlayerSelected()
    node = m.playerActions.content.getChild(m.playerActions.itemSelected)
    if node <> invalid then rPlayerAction(node.wire)
end sub

sub rPlayerAction(value as object)
    if m.playback = invalid then return
    action = value.action
    if action = "player:pause"
        if m.player.state = "paused" then m.player.control = "resume" else m.player.control = "pause"
        rShowControls()
    else if action = "player:sources"
        m.playCard = m.playback.card
        m.playIntent = {explicit:true}
        rDiscoverSources(m.playCard)
        m.top.removeChild(m.drawer)
        m.top.appendChild(m.drawer)
    else if action = "player:tracks"
        values = []
        for each track in RArray(m.playback.session.delivery.audio_tracks)
            values.push({title:"Audio · "+RText(track.title,RText(track.language,"Track")),action:"player:track",track:{audio_track:track.input_index}})
        end for
        if m.playback.session.delivery.subtitles_supported = true then values.push({title:"Subtitles off",action:"player:track",track:{subtitles_off:true}})
        for each track in RArray(m.playback.session.delivery.subtitle_tracks)
            values.push({title:"Subtitles · "+RText(track.title,RText(track.language,"Track")),action:"player:track",track:{subtitle_track:track.input_index,subtitles_off:false}})
        end for
        rOpenDrawer("Subtitles & audio",values,"tracks")
        m.top.removeChild(m.drawer)
        m.top.appendChild(m.drawer)
    else if action = "player:track"
        m.playCard = m.playback.card
        rStartSource(m.playback.source,rPlayerPosition(),value.track)
    else if action = "player:next"
        card = m.nextCard
        rStopPlayer()
        m.playIntent = {explicit:false}
        rSend("POST",rProfilePath("/viewing-action"),{card:card,restart:false},"viewing")
    else if action = "player:episodes"
        m.playerEpisodes = []
        m.episodeCursor = ""
        rOpenDrawer("Episodes",[],"episodes")
        m.top.removeChild(m.drawer)
        m.top.appendChild(m.drawer)
        rPlayerEpisodes("0",false)
    else if action = "player:episode"
        card = value.episode
        rStopPlayer()
        m.drawer.visible = false
        m.drawerStack = []
        m.playIntent = {explicit:false}
        rSend("POST",rProfilePath("/viewing-action"),{card:card,restart:false},"viewing")
    end if
end sub

sub rPlayerEpisodes(cursor as string, appendPage as boolean)
    if m.playback = invalid then return
    card = m.playback.card
    parent = card.parent_identity
    if not RObject(parent) then return
    query = {offset:cursor,limit:"24"}
    if card.metadata_origin <> invalid
        expected = ParseJson(FormatJson(card))
        expected.identity = parent
        expected.parent_identity = invalid
        query.metadata_origin = FormatJson(card.metadata_origin)
        query.card = FormatJson(expected)
    else
        query.provider_id = card.provider_id
    end if
    rSend("GET","/api/meta/"+REncode(parent.kind)+"/"+REncode(parent.id)+"?"+rQuery(query),invalid,"player:episodes",{id:m.playback.session.id,append:appendPage})
end sub

sub rPlayerEpisodesResponse(data as object, request as object)
    if m.playback = invalid or m.drawerKind <> "episodes" then return
    if request.context.id <> m.playback.session.id then return
    if not request.context.append then m.playerEpisodes = []
    m.playerEpisodes.append(RArray(data.episodes))
    while m.playerEpisodes.count() > 300
        m.playerEpisodes.shift()
    end while
    m.episodeCursor = RText(data.next_cursor)
    values = []
    for each card in m.playerEpisodes
        values.push({title:card.title,subtitle:RText(card.subtitle),episode:card,action:"player:episode",ring:false})
    end for
    m.drawerRows.itemSize = [800,144]
    m.drawerRows.numRows = 4
    focus = m.drawerRows.itemFocused
    m.drawerRows.content = rContent(values,800,144)
    if focus >= 0 and focus < values.count() then m.drawerRows.jumpToItem = focus
    seasons = []
    for each season in RArray(data.seasons)
        label = "Episodes"
        if season.season <> invalid then label = "Season "+season.season.toStr()
        seasons.push({title:label,offset:season.offset,width:200})
    end for
    m.sourceFilters.content = rContent(seasons,200,52)
    m.sourceFilters.visible = seasons.count() > 1
    m.drawerRows.translation = [64,278]
end sub

function rPlayerKey(key as string) as boolean
    if m.drawer.visible then return false
    if key = "play"
        rPlayerAction({action:"player:pause"})
    else if key = "left" or key = "right" or key = "rewind" or key = "fastforward"
        if m.playerUi.visible and m.playerActions.isInFocusChain() and m.seekPosition = invalid then return false
        if m.playback.session.delivery.live = true then return true
        position = rPlayerPosition()
        if m.seekPosition <> invalid then position = m.seekPosition
        delta = 10
        if key = "left" or key = "rewind" then delta = -10
        position += delta
        duration = RGet(m.playback.session.delivery,"duration",0)
        if position < 0 then position = 0
        if duration > 0 and position > duration then position = duration
        m.seekPosition = position
        m.playerUi.visible = true
        m.playerTime.text = rTime(position)+" · OK to seek · Back to cancel"
        m.top.setFocus(true)
    else if key = "OK" and m.seekPosition <> invalid
        position = m.seekPosition
        m.seekPosition = invalid
        m.playCard = m.playback.card
        rStartSource(m.playback.source,position)
    else if key = "down" and m.playerActions.isInFocusChain()
        m.top.setFocus(true)
        m.hideControls.control = "stop"
    else if key = "OK" or key = "up" or key = "down" or key = "options"
        rShowControls()
    else
        return false
    end if
    return true
end function

sub rSaveProgress(ended as boolean)
    if m.playback = invalid or m.playback.session.delivery.live = true then return
    if m.playback.firstFrame <> true then return
    card = m.playback.card
    record = {presentation:card,identity:card.identity,parent_identity:card.parent_identity,provider_id:card.provider_id,title:card.title,poster:card.poster,landscape:card.landscape,position_millis:int(rPlayerPosition()*1000),duration_millis:int(RGet(m.playback.session.delivery,"duration",0)*1000),updated_at_millis:0,metadata_origin:card.metadata_origin}
    rSend("PUT",rProfilePath("/progress"),{record:record,parent_identity:card.parent_identity,ended:ended},"save:progress:"+m.playback.session.id+":"+m.sequence.toStr())
end sub

sub rPlaybackEvent(kind as string, ended as boolean)
    if m.playback = invalid or m.playback.session.delivery.live = true then return
    if m.playback.firstFrame <> true then return
    m.playback.sequence++
    card = m.playback.card
    body = {attempt_id:m.playback.session.id,sequence:m.playback.sequence,identity:card.identity,parent_identity:card.parent_identity,event:kind,position_millis:int(rPlayerPosition()*1000),duration_millis:int(RGet(m.playback.session.delivery,"duration",0)*1000),ended:ended}
    rSend("POST",rProfilePath("/playback-events"),body,"save:event:"+m.playback.session.id+":"+m.playback.sequence.toStr())
end sub

sub rStopPlayer()
    if m.admission <> invalid
        for each worker in m.workers
            if worker.request.tag = "player:start" or worker.request.tag = "player:poll"
                if RGet(worker.request.context,"request_id") = m.admission.request_id then worker.cancel = true
            end if
        end for
        m.pending.delete("player:start")
        m.pending.delete("player:poll")
        path = "/api/playback-requests/"+REncode(m.admission.request_id)
        if m.admission.id <> "" then path = "/api/playback/"+REncode(m.admission.id)
        rCleanup(path,{base:m.config.base,access_token:m.config.access_token,epoch:m.epoch})
        m.admission = invalid
    end if
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
        if m.playback <> invalid then rCleanup("/api/playback/"+REncode(m.playback.session.id),m.playback.owner)
        previous = m.replacement
        m.replacement = invalid
        m.playback = previous
        m.player.control = "stop"
        m.player.content = previous.content
        m.player.control = "play"
        m.player.seek = previous.position
        rShowControls()
        m.playerTime.text = message
    else
        rStopPlayer()
        rError(message)
        rFocusContent()
    end if
end sub
