sub stopPlayback(restore = true as boolean)
    saveProgress()
    ' Retire a still-pending next-episode transition before restoring the view.
    if m.nextPrepping = true or m.nextTransitionSession <> ""
        if m.nextTransitionSession <> "" then request("DELETE","/api/playback/" + Enc(m.nextTransitionSession),invalid,"cleanup",m.nextTransitionConnection)
        m.nextTransitionSession = ""
        m.nextTransitionConnection = invalid
    end if
    m.nextPrepping = false
    if m.playItem <> invalid
        if m.playItem.type <> "live"
            m.playItem.position = m.position
            m.playItem.duration = m.duration
        end if
    end if
    if m.budgetTimer <> invalid then m.budgetTimer.control = "stop"
    if m.prepClock <> invalid and m.prepSpent <> invalid
        m.prepSpent += m.prepClock.totalMilliseconds()
        m.prepClock = invalid
    end if
    if m.playerHint <> invalid then m.playerHint.visible = false
    if m.hintTimer <> invalid then m.hintTimer.control = "stop"
    if m.seekTimer <> invalid then m.seekTimer.control = "stop"
    if m.seeking = true
        if Txt(m.pendingStartupId) <> "" then cancelBrowse()
        m.seeking = false
        m.seekPhase = ""
        if Txt(m.seekNewSession) <> "" then request("DELETE","/api/playback/" + Enc(m.seekNewSession),invalid,"cleanup",m.seekNewConnection)
        m.seekNewSession = ""
        m.seekNewContent = invalid
        m.seekData = invalid
        m.seekOldContent = invalid
    end if
    m.playing = false
    m.managedLive = false
    m.liveRecoveryRequested = false
    m.pausedVOD = false
    if m.playerOverlay <> invalid then m.playerOverlay.visible = false
    if m.playerBackdrop <> invalid then m.playerBackdrop.visible = false
    if m.playerTick <> invalid then m.playerTick.control = "stop"
    m.startup.control = "stop"
    m.heartbeat.control = "stop"
    m.video.control = "stop"
    m.video.visible = false
    if m.session <> "" then request("DELETE","/api/playback/" + Enc(m.session),invalid,"cleanup",m.sessionConnection)
    m.session = ""
    if restore
        if m.captionRestore <> invalid
            m.video.globalCaptionMode = m.captionRestore
            m.captionRestore = invalid
        end if
        if m.playerReturnDetail <> invalid
            target = m.playerReturnDetail
            m.playerReturnDetail = invalid
            returnToDetail(target)
        else
            restoreView()
        end if
        m.status.text = ""
    end if
end sub

sub returnToDetail(item as object)
    if item = invalid then restoreView() : return
    m.selected = CopyRouteData(item)
    if item.position <> invalid then m.position = item.position else m.position = 0
    cancelBrowse()
    path = "/api/meta/" + Enc(Txt(item.type,"movie")) + "/" + Enc(PresentationMetadataId(item))
    cached = m.cache[path]
    now = CreateObject("roDateTime").asSeconds()
    if cached <> invalid
        if now - cached.time < 300
            showMetadata(cached.data)
            return
        end if
    end if
    rows(Txt(item.seriesName,Txt(item.name)),[],"loading","")
    m.metaPath = path
    request("GET", path, invalid, "meta")
    m.status.text = "Loading details…"
end sub

sub pauseVOD()
    if not m.playing or m.playItem.type = "live" or m.playbackLive = true or m.seeking = true then return
    ' Pause the current Video node in place. Never delete the server session,
    ' clear content, hide video, or replace the paused frame.
    if m.pausedVOD = true or m.video.state = "paused"
        m.directSeekPause = false
        m.video.control = "resume"
        m.pausedVOD = false
    else
        m.video.control = "pause"
        m.pausedVOD = true
    end if
    if m.playerOverlay <> invalid
        m.playerOverlay.visible = true
        m.playerOverlay.opened = true
        m.playerOverlay.setFocus(true)
        updatePlayer()
    end if
end sub

sub seekRestart(delta as integer)
    if not m.playing or m.playItem.type = "live" or m.playbackLive = true then return
    saveProgress()
    seekToPosition(m.position + delta)
end sub

sub seekToPosition(target as double, managed = false as boolean)
    if not m.playing or m.playItem.type = "live" or m.playbackLive = true or m.seeking = true then return
    target = ClampPlayerSeek(target,m.duration)
    if not managed and m.position <> invalid
        if abs(target - m.position) < 0.5 then return
    end if
    if m.playbackMode = "direct" and not managed
        m.directSeekPause = m.pausedVOD = true or m.video.state = "paused"
        m.video.autoplayAfterSeek = not m.directSeekPause
        m.video.seek = target
        return
    end if
    saveProgress()
    m.seeking = true
    m.seekPhase = "replacement"
    m.seekNewSession = ""
    m.seekNewConnection = invalid
    m.seekNewContent = invalid
    m.seekData = invalid
    m.seekFailureMessage = ""
    m.seekTarget = target
    m.seekOldSession = m.session
    m.seekOldConnection = m.sessionConnection
    m.seekOldContent = m.video.content
    m.seekOldPosition = m.position
    if m.video.position > 0 then m.seekOldPosition = m.timelineOffset + m.video.position
    m.seekOldTimelineOffset = m.timelineOffset
    m.seekWasPaused = (m.pausedVOD = true or m.video.state = "paused")
    m.video.control = "pause"
    m.pausedVOD = true
    m.pendingPlayback = true
    m.status.text = "Seeking to " + PlayerTime(target) + "…"
    if m.playerBackdrop <> invalid then m.playerBackdrop.visible = true
    m.video.visible = true
    if m.playerOverlay <> invalid
        m.playerOverlay.visible = true
        m.playerOverlay.opened = true
        m.playerOverlay.setFocus(true)
        updatePlayer()
    end if
    body = PlaybackBody(m.playItem,m.profile,m.config.capabilities,target,m.forced)
    ' Offset replacements use the generated timeline. Existing direct sessions
    ' already took the native-seek branch above.
    body.managed_only = true
    body.append(TrackRequestFields(m.playItem,m.trackPreferences))
    if Txt(m.playItem.audio_language) <> "" then body.audio_language = m.playItem.audio_language
    request("POST","/api/playback",body,"seekplayback")
    m.pendingRequestId = m.generation.toStr() + "-" + m.requestSequence.toStr()
    if m.seekTimer <> invalid
        m.seekTimer.duration = 60
        m.seekTimer.control = "start"
    end if
end sub

sub prepareSeekReplacement(data as object, connection as object)
    if m.seeking <> true
        if data.id <> invalid then request("DELETE","/api/playback/" + Enc(Txt(data.id)),invalid,"cleanup",connection)
        return
    end if
    url = ResolveUrl(connection.base,Txt(data.url))
    if url = ""
        seekReplacementFailed("Seek failed. Playback resumed at the prior position.")
        return
    end if
    m.seekNewSession = Txt(data.id)
    m.seekNewConnection = connection
    m.seekData = data
    content = CreateObject("roSGNode","ContentNode")
    content.url = url
    content.streamFormat = Txt(data.format,"hls")
    content.title = Txt(m.playItem.displayName,Txt(m.playItem.name))
    content.live = false
    m.seekNewContent = content
    beginPrimarySeekFallback()
end sub

' The ready backend session starts on the existing decoder immediately. Keep the
' old backend session/content until success so a failed decoder start can roll back.
sub beginPrimarySeekFallback()
    if m.seeking <> true or m.seekPhase <> "replacement" then return
    if Txt(m.seekNewSession) = "" or m.seekNewContent = invalid
        beginSeekRollback("Seek failed. Playback resumed at the prior position.")
        return
    end if
    if m.seekTimer <> invalid then m.seekTimer.control = "stop"
    m.seekPhase = "primary"
    m.status.text = "Seeking to " + PlayerTime(m.seekTarget) + "…"
    m.video.control = "stop"
    PrepareNativeCaptions(m.video,m.seekData.selected_subtitle <> invalid)
    m.video.content = m.seekNewContent
    m.video.visible = true
    m.video.control = "play"
    if m.seekTimer <> invalid
        m.seekTimer.duration = 25
        m.seekTimer.control = "start"
    end if
end sub

sub seekPrimaryVideoState()
    if m.seeking <> true then return
    if m.seekPhase = "primary"
        if m.video.state = "playing"
            finishSeekSuccess()
        else if m.video.state = "error"
            beginSeekRollback("Seek failed. Playback resumed at the prior position.")
        end if
    else if m.seekPhase = "rollback"
        if m.video.state = "playing"
            relative = m.seekOldPosition - m.seekOldTimelineOffset
            if relative > 0 then m.video.seek = relative
            finishSeekRollback(true)
        else if m.video.state = "error"
            finishSeekRollback(false)
        end if
    end if
end sub

sub finishSeekSuccess()
    if m.seeking <> true then return
    oldSession = m.seekOldSession
    oldConnection = m.seekOldConnection
    data = m.seekData
    m.session = m.seekNewSession
    m.sessionConnection = m.seekNewConnection
    m.timelineOffset = m.seekTarget
    if Txt(data.mode) = "direct" then m.timelineOffset = 0
    m.position = m.seekTarget
    if data.duration <> invalid then m.duration = data.duration
    m.playbackMode = Txt(data.mode)
    m.audioTracks = Bounded(data.audio_tracks,32)
    m.subtitleTracks = Bounded(data.subtitle_tracks,32)
    m.subtitlesSupported = data.subtitles_supported = true
    m.selectedSubtitle = data.selected_subtitle
    m.nativeCaptionName = ""
    m.seeking = false
    m.seekPhase = ""
    m.pendingPlayback = false
    if m.seekTimer <> invalid then m.seekTimer.control = "stop"
    m.pausedVOD = (m.seekWasPaused = true)
    if m.pausedVOD then m.video.control = "pause"
    if oldSession <> "" then request("DELETE","/api/playback/" + Enc(oldSession),invalid,"cleanup",oldConnection)
    m.seekNewSession = ""
    m.seekNewContent = invalid
    m.seekData = invalid
    m.status.text = ""
    applyPlayerSubtitles()
    updatePlayer()
end sub

sub beginSeekRollback(message as string)
    if m.seeking <> true then return
    m.seekFailureMessage = message
    if m.seekTimer <> invalid then m.seekTimer.control = "stop"
    if Txt(m.seekNewSession) <> "" then request("DELETE","/api/playback/" + Enc(m.seekNewSession),invalid,"cleanup",m.seekNewConnection)
    m.seekNewSession = ""
    if m.seekPhase = "primary" and m.seekOldContent <> invalid
        m.seekPhase = "rollback"
        m.video.control = "stop"
        PrepareNativeCaptions(m.video,m.selectedSubtitle <> invalid)
        m.video.content = m.seekOldContent
        m.video.visible = true
        m.video.control = "play"
        if m.seekTimer <> invalid then m.seekTimer.control = "start"
    else
        finishSeekRollback(true)
    end if
end sub

sub finishSeekRollback(recovered as boolean)
    if m.seekTimer <> invalid then m.seekTimer.control = "stop"
    m.pendingPlayback = false
    m.seeking = false
    m.seekPhase = ""
    m.position = m.seekOldPosition
    m.timelineOffset = m.seekOldTimelineOffset
    m.session = m.seekOldSession
    m.sessionConnection = m.seekOldConnection
    m.video.visible = true
    m.pausedVOD = (m.seekWasPaused = true)
    if recovered
        if m.pausedVOD
            m.video.control = "pause"
        else
            m.video.control = "resume"
        end if
        m.status.text = Txt(m.seekFailureMessage,"Seek failed. Playback resumed at the prior position.")
    else
        m.playing = false
        m.pausedVOD = false
        m.video.control = "stop"
        m.video.visible = false
        if Txt(m.seekOldSession) <> "" then request("DELETE","/api/playback/" + Enc(m.seekOldSession),invalid,"cleanup",m.seekOldConnection)
        m.session = ""
        m.heartbeat.control = "stop"
        if m.playerTick <> invalid then m.playerTick.control = "stop"
        if m.playerBackdrop <> invalid then m.playerBackdrop.visible = false
        m.status.text = "Seek failed and playback could not be restored. Choose the source again."
    end if
    m.seekNewContent = invalid
    m.seekData = invalid
    m.seekOldContent = invalid
    if m.playerOverlay <> invalid
        m.playerOverlay.visible = recovered
        m.playerOverlay.opened = recovered
        if recovered then m.playerOverlay.setFocus(true)
        updatePlayer()
    end if
    if not recovered then sourceExhausted("Seek failed and playback could not be restored. Choose the source again.")
end sub

sub seekReplacementFailed(message = "Seek failed. Playback resumed at the prior position." as string)
    if m.seeking <> true then return
    if Txt(m.pendingStartupId) <> "" then cancelBrowse()
    if m.seekPhase = "replacement" and Txt(m.seekNewSession) <> "" and m.seekNewContent <> invalid
        beginPrimarySeekFallback()
    else if m.seekPhase = "primary" or m.seekPhase = "rollback"
        if m.seekPhase = "primary"
            beginSeekRollback(message)
        else
            finishSeekRollback(false)
        end if
    else
        m.seekFailureMessage = message
        beginSeekRollback(message)
    end if
end sub
