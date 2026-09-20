sub findStreams(item as object, manual = true as boolean, preferredSource = invalid as dynamic, automatic = false as boolean)
    ' Home-shelf playback returns to the title's detail page on Back. A running
    ' next-episode transition keeps its already-chosen return target.
    if m.nextPrepping <> true
        if m.mode = "home" and item <> invalid and Txt(item.type) <> "live" then m.playerReturnDetail = CopyRouteData(item)
        if m.mode <> "home" then m.playerReturnDetail = invalid
    end if
    saveView()
    cancelBrowse()
    if Txt(m.sourcePreferencesProfile) <> m.profile or m.sourcePreferences = invalid
        m.sourcePreferencesProfile = m.profile
        m.sourcePreferences = invalid
        request("GET","/api/profiles/"+Enc(m.profile)+"/preferences",invalid,"sourcepreferences:"+m.profile)
    end if
    resetAttempts()
    m.sourcesAt = invalid
    m.refreshingSources = false
    m.resumeSourcePreference = preferredSource
    m.automaticContinuation = automatic
    m.continuationSourcePreference = invalid
    if preferredSource <> invalid
        if preferredSource.continuation = true then m.continuationSourcePreference = CopyRouteData(preferredSource)
    end if
    m.manualSources = manual or preferredSource = invalid
    m.sourceHintCache = {}
    m.playItem = {}
    m.playItem.append(item)
    m.streams = []
    m.discoveryDone = false
    m.position = 0
    m.duration = 0
    if item.position <> invalid then m.position = item.position
    if item.duration <> invalid then m.duration = item.duration
    m.skipNearEndContinuation = NearEpisodeEnd(m.position,m.duration)
    body = {type:item.type,id:item.id,name:Txt(item.seriesName,item.name)}
    body.append(StreamContext(item))
    if m.continuationSourcePreference <> invalid
        provider = Txt(m.continuationSourcePreference.source_addon_id)
        if left(provider,5) = "iptv:"
            body.only_provider_id = val(mid(provider,6))
        else
            body.only_addons = true
        end if
    end if
    request("POST","/api/streams",body,"streamstart")
    if not m.manualSources
        ' Resume is an explicit operation, never a timer attached to the picker.
        m.mode = "resuming"
        m.status.text = "Resuming… Back to choose a source"
        if m.continuationSourcePreference <> invalid then m.status.text = "Finding next episode source… Back to choose a source"
        uiBusy(true)
    else if m.heading <> invalid
        rows("Choose a source",[],"streams","")
        uiSourceHeader()
    end if
end sub

sub pollStreams()
    m.pollCount++
    request("GET","/api/streams/" + Enc(m.job) + "?after=" + m.cursor.toStr(),invalid,"streampoll")
end sub

sub beginPlayback(force as boolean)
    if m.pendingPlayback
        m.status.text = "Playback is already preparing. Please wait."
        return
    end if
    if m.refreshingSources = true then return
    if m.refreshClock <> invalid
        m.prepSpent += m.refreshClock.totalMilliseconds()
        m.refreshClock = invalid
    end if
    issued = m.activeSourceAt
    if issued = invalid then issued = m.sourcesAt
    if m.playItem.type <> "live" and SourceIdsExpired(issued,CreateObject("roDateTime").asSeconds())
        refreshSourceIds()
        return
    end if
    cancelBrowse()
    if m.prepSpent = invalid then resetAttempts()
    if m.prepSpent >= 180000
        sourceExhausted("Playback preparation timed out.")
        return
    end if
    m.prepClock = CreateObject("roTimespan")
    m.prepClock.mark()
    if m.budgetTimer <> invalid
        m.budgetTimer.duration = (180000 - m.prepSpent) / 1000.0
        m.budgetTimer.control = "start"
    end if
    m.pendingPlayback = true
    m.pausedVOD = false
    m.forced = force
    if m.playItem.type = "live" then m.position = 0
    if m.duration > 0 and m.position >= m.duration then m.position = 0
    uiBusy(true)
    body = PlaybackBody(m.playItem,m.profile,m.config.capabilities,m.position,force)
    if m.directRetryUsed = true then body.managed_only = true
    body.append(TrackRequestFields(m.playItem,m.trackPreferences))
    if Txt(m.playItem.audio_language) <> "" then body.audio_language = m.playItem.audio_language
    request("POST","/api/playback",body,"playback")
    if m.pendingPlayback then m.pendingRequestId = m.generation.toStr() + "-" + m.requestSequence.toStr()
end sub

sub videoNodeState(event as object)
    node = event.getRoSGNode()
    if node.isSameNode(m.video)
        if m.seeking = true
            seekPrimaryVideoState()
        else
            videoState()
        end if
    end if
end sub

sub videoState()
    ' The old decoder is intentionally paused during atomic replacement.
    if m.seeking = true then return
    state = m.video.state
    if m.managedLive = true and m.playing = true and (state = "error" or state = "finished")
        requestLiveRecovery()
        return
    end if
    if m.directSeekPause = true
        pauseAgain = state = "playing"
        m.directSeekPause = DirectSeekPause(m.video,true)
        if pauseAgain
            m.pausedVOD = true
            return
        end if
    end if
    if state = "playing"
        firstFrame = m.hasPlayed <> true
        m.hasPlayed = true
        if firstFrame and m.playbackLive = true then saveProgress()
        if firstFrame
            if m.playStartClock <> invalid then print "VIPTV_PLAYBACK_START mode=";m.playbackMode;" player_ms=";m.playStartClock.totalMilliseconds()
            m.playStartClock = invalid
            prefetchContinuation()
        end if
        m.startup.control = "stop"
        if m.budgetTimer <> invalid then m.budgetTimer.control = "stop"
        if m.prepClock <> invalid
            if m.prepSpent <> invalid then m.prepSpent += m.prepClock.totalMilliseconds()
            m.prepClock = invalid
        end if
        if m.resumePosition <> invalid
            if m.resumePosition > 0 and m.playItem.type <> "live" and m.playbackLive <> true then m.video.seek = m.resumePosition
            m.resumePosition = invalid
        end if
    else if state = "error"
        retryPlayback("Video error " + m.video.errorCode.toStr() + ": " + m.video.errorMsg)
    else if state = "finished"
        if not m.playing then return
        saveProgress()
        if m.playItem.type = "live" or m.playbackLive = true
            stopPlayback(false)
            if m.liveRetunes = invalid then m.liveRetunes = 0
            if m.liveRetunes < 2
                m.liveRetunes++
                beginPlayback(false)
            else
                sourceExhausted("Live stream ended.")
            end if
        else if FarBeforeEnd(m.position,m.duration)
            stopPlayback(false)
            sourceExhausted("Selected source ended early. Choose another source.")
        else if m.playItem.type = "series" and m.hasPlayed = true and NearEpisodeEnd(m.position,m.duration)
            continuationBegin(true)
        else
            stopPlayback()
        end if
    end if
end sub

sub startupFailed()
    retryPlayback("Playback did not start within 25 seconds.")
end sub

sub retryPlayback(reason as string)
    if not m.playing then return
    category = ""
    if m.video.state = "error" and GetInterface(m.video.errorInfo,"ifAssociativeArray") <> invalid then category = lcase(Txt(m.video.errorInfo.category))
    originFailure = category = "http" or category = "drm"
    if m.playbackMode = "direct" and m.directRetryUsed <> true and not originFailure
        saveProgress()
        stopPlayback(false)
        m.directRetryUsed = true
        beginPlayback(false)
        return
    end if
    if m.managedLive = true
        requestLiveRecovery()
        return
    end if
    force = not m.forced and m.codecRetryUsed <> true and not originFailure
    stopPlayback(false)
    if force
        m.codecRetryUsed = true
        beginPlayback(true)
    else
        if retryContinuationSource() then return
        sourceExhausted("Selected source could not play. Choose another source.")
    end if
end sub

sub heartbeat()
    if m.session = "" then return
    request("POST","/api/playback/" + Enc(m.session) + "/heartbeat",{},"sideheartbeat")
    saveProgress()
end sub

sub saveProgress()
    if not m.playing then return
    if m.playItem.type = "live" or m.playbackLive = true
        if m.hasPlayed <> true then return
        body = {id:m.playItem.id,type:"live",name:m.playItem.name,poster:Txt(m.playItem.logo,Txt(m.playItem.poster)),position:0,duration:0}
        request("PUT","/api/profiles/" + Enc(m.profile) + "/progress",body,"sideprogress")
        m.homeDirty = true
        return
    end if
    if m.video.position > 0 then m.position = m.timelineOffset + m.video.position
    if m.playbackMode = "direct" and m.video.duration > 0
        if m.duration <= 0 or m.video.duration > m.duration then m.duration = m.video.duration
    end if
    ' Duration 0 honestly means unknown, never the rolling HLS window length.
    if m.position <= 0 then return
    ' Persist canonical series name so episode resume can still match IPTV fallback.
    body = {id:m.playItem.id,type:m.playItem.type,name:Txt(m.playItem.seriesName,m.playItem.name),poster:Txt(m.playItem.poster),position:m.position,duration:m.duration}
    body.append(StreamContext(m.playItem))
    body.append(StableSourcePreference(m.playItem))
    m.homeDirty = true
    request("PUT","/api/profiles/" + Enc(m.profile) + "/progress",body,"sideprogress")
end sub

sub updatePlayer()
    if m.playerOverlay = invalid or m.playItem = invalid then return
    position = m.position
    if m.playing and m.video.position <> invalid
        if m.video.state = "playing" or m.video.state = "paused" then position = m.video.position + m.timelineOffset
    end if
    state = Txt(m.video.state)
    if m.seeking = true then state = "seeking"
    if m.nextPrepping = true then state = "buffering"
    if m.playing = true and m.skipNearEndContinuation <> true and state = "playing" and m.pausedVOD <> true and m.playItem.type = "series" and m.playbackLive <> true and NearEpisodeEnd(position,m.duration)
        if m.nextOwner = Txt(m.playItem.id) and m.nextScope = m.profile and m.nextResult <> invalid
            if m.nextResult.status = "next"
                m.position = position
                continuationBegin(true)
                return
            end if
        end if
    end if
    episode = ""
    if m.playItem.type = "series" and m.playbackLive <> true
        epCoords = StreamContext(m.playItem)
        if epCoords.season <> invalid and epCoords.episode <> invalid then episode = "S" + Txt(epCoords.season) + " E" + Txt(epCoords.episode)
        epName = Txt(m.playItem.episodeTitle)
        if epName <> ""
            if episode <> "" then episode = episode + " · " + epName else episode = epName
        end if
    end if
    m.playerOverlay.model = {session:m.session,state:state,title:Txt(m.playItem.seriesName,Txt(m.playItem.name)),episode:episode,context:PresentationContext(m.playItem),logo:Txt(m.playItem.logo,Txt(m.playItem.poster)),programme:m.playItem.now,position:position,duration:m.duration,live:m.playbackLive,paused:m.pausedVOD = true or m.video.state = "paused",seeking:m.seeking = true,seek_target:m.seekTarget,next_episode:m.playItem.type = "series" and m.playbackLive <> true}
end sub

sub playerCommand(event as object)
    command = event.getData()
    if command.kind = "next"
        continuationBegin(false)
    else if command.kind = "exit"
        stopPlayback()
    else if command.kind = "pause"
        if m.playbackLive = true or m.seeking = true then return
        pauseVOD()
    else if command.kind = "seek"
        if m.playbackLive = true then return
        target = ClampPlayerSeek(command.value,m.duration)
        seekToPosition(target)
    else if command.kind = "audio" or command.kind = "subtitles"
        showPlayerTracks(command.kind)
    end if
    updatePlayer()
end sub

function nextPlayerDialogId() as string
    if m.playerDialogSequence = invalid then m.playerDialogSequence = 0
    m.playerDialogSequence++
    return "player:" + m.playerDialogSequence.toStr()
end function

function playerDialogEventMatches(event as object) as boolean
    if m.top.dialog = invalid then return false
    node = event.getRoSGNode()
    if node = invalid then return false
    return left(Txt(node.id),7) = "player:" and Txt(node.id) = Txt(m.top.dialog.id)
end function

sub showPlayerTracks(kind as string, page = 0 as integer)
    m.trackKind = kind
    m.trackPage = page
    m.trackDialogSession = m.session
    m.trackDialogOwner = TrackOwner(m.playItem)
    m.trackChoices = []
    buttons = []
    tracks = Bounded(m.audioTracks,32)
    title = "Audio tracks"
    message = "Choose any available audio track. Language labels are informational."
    if kind = "subtitles"
        tracks = Bounded(m.subtitleTracks,32)
        title = "Subtitles"
        message = "Select a supported text track. Image subtitles cannot be displayed."
        if m.subtitlesSupported <> true then message = "Subtitles are unavailable for this output. Listed tracks cannot currently be displayed."
        if m.subtitlesSupported = true
            buttons.push("Off")
            m.trackChoices.push({action:"off"})
        end if
    end if
    for index = page to page + 4
        if index >= tracks.count() then exit for
        track = tracks[index]
        label = PlayerTrackLabel(track)
        if track.selected = true then label = "Playing · " + label
        if not PlayerTrackSelectable(track) or (kind = "subtitles" and m.subtitlesSupported <> true) then label = "Unavailable · " + label
        buttons.push(left(label,100))
        m.trackChoices.push(track)
    end for
    if page + 5 < tracks.count()
        buttons.push("More tracks")
        m.trackChoices.push({action:"next"})
    end if
    if page > 0
        buttons.push("Previous tracks")
        m.trackChoices.push({action:"previous"})
    end if
    if tracks.count() = 0
        message = "This stream supplies no selectable audio tracks."
        if kind = "subtitles" then message = "This stream supplies no selectable subtitles."
    end if
    buttons.push("Back to player")
    m.trackChoices.push({action:"back"})
    dialog = CreateObject("roSGNode","Dialog")
    dialog.id = nextPlayerDialogId()
    dialog.title = title
    dialog.message = message
    dialog.buttons = buttons
    dialog.observeField("buttonSelected","playerTrackSelected")
    dialog.observeField("wasClosed","playerDialogClosed")
    m.top.dialog = dialog
end sub

sub playerTrackSelected(event as object)
    if not playerDialogEventMatches(event) then return
    index = event.getData()
    if index < 0 or index >= m.trackChoices.count() then return
    choice = m.trackChoices[index]
    closePlayerTracks()
    if m.trackDialogOwner <> TrackOwner(m.playItem) or m.trackDialogSession <> m.session then return
    if choice.action = "back" then return
    if choice.action = "next"
        showPlayerTracks(m.trackKind,m.trackPage + 5)
        return
    else if choice.action = "previous"
        showPlayerTracks(m.trackKind,m.trackPage - 5)
        return
    end if
    if choice.action <> "off"
        if not MatchInteger(choice.input_index,0,65535) then return
        if not PlayerTrackSelectable(choice) then return
        if m.trackKind = "subtitles" and m.subtitlesSupported <> true then return
    end if
    choosePlayerTrack(choice)
end sub

sub choosePlayerTrack(choice as object)
    if m.trackPreferences = invalid then m.trackPreferences = {}
    if Txt(m.trackPreferences.owner) <> TrackOwner(m.playItem) then m.trackPreferences = {}
    m.trackPreferences.owner = TrackOwner(m.playItem)
    if m.trackKind = "audio"
        m.trackPreferences.audio_track_index = choice.input_index
        language = StablePreferenceText(choice.language,16)
        if language <> "" then m.playItem.audio_language = lcase(language)
    else
        if m.captionRestore = invalid then m.captionRestore = m.video.globalCaptionMode
        if choice.action = "off"
            m.trackPreferences.delete("subtitle_track_index")
            m.trackPreferences.subtitles_off = true
            m.video.globalCaptionMode = "Off"
        else
            m.trackPreferences.subtitle_track_index = choice.input_index
            m.trackPreferences.subtitles_off = false
        end if
    end if
    saveProgress()
    seekToPosition(m.position,true)
end sub

sub applyPlayerSubtitles()
    if m.playItem = invalid or m.subtitlesSupported <> true then return
    preferences = TrackRequestFields(m.playItem,m.trackPreferences)
    if preferences.subtitle_track_index = invalid then return
    if not m.playing or m.selectedSubtitle = invalid then return
    id = MatchNativeCaption(m.video.availableSubtitleTracks,Txt(m.nativeCaptionName))
    if id <> ""
        m.nativeCaptionName = id
        m.video.subtitleTrack = id
    end if
end sub

sub playerDialogClosed(event = invalid as dynamic)
    ' A delayed close event must not steal a replacement modal or sidebar focus.
    if m.top.dialog <> invalid
        if event <> invalid
            node = event.getRoSGNode()
            if node = invalid then return
            if Txt(node.id) <> Txt(m.top.dialog.id) then return
        else if m.top.dialog.close <> true
            return
        end if
    end if
    if m.sidebar <> invalid
        if m.sidebar.hasFocus() then return
    end if
    if m.playerOverlay <> invalid
        if m.playerOverlay.visible and (m.playing or m.pausedVOD = true)
            m.playerOverlay.opened = true
            m.playerOverlay.setFocus(true)
            return
        end if
    end if
    if m.mode = "sourceerror" and m.pendingPlayback <> true then m.list.setFocus(true)
end sub

sub closePlayerTracks()
    if m.top.dialog <> invalid then m.top.dialog.close = true
    if m.playerOverlay <> invalid
        m.playerOverlay.opened = true
        m.playerOverlay.setFocus(true)
    end if
end sub

sub hidePlayerHint()
    m.playerHint.visible = false
end sub
