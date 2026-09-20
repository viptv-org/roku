sub acceptPlayback(data as object,origin as object)
        uiBusy(false)
        m.session = Txt(data.id)
        if m.nextPrepping = true or m.nextTransitionSession <> ""
            if m.nextTransitionSession <> "" and m.nextTransitionSession <> m.session
                request("DELETE","/api/playback/" + Enc(m.nextTransitionSession),invalid,"cleanup",m.nextTransitionConnection)
            end if
            m.nextTransitionSession = ""
            m.nextTransitionConnection = invalid
            m.nextPrepping = false
        end if
        m.managedLive = data.managed_live = true
        m.liveGeneration = data.generation
        m.liveRecoveryRequested = false
        m.liveHeartbeatFailures = 0
        if m.managedLive then m.heartbeat.duration = 3 else m.heartbeat.duration = 15
        m.audioTracks = Bounded(data.audio_tracks,32)
        m.subtitleTracks = Bounded(data.subtitle_tracks,32)
        m.subtitlesSupported = data.subtitles_supported = true
        m.selectedSubtitle = data.selected_subtitle
        for each track in m.audioTracks
            if track.selected = true
                language = StablePreferenceText(track.language,16)
                if language <> "" then m.playItem.audio_language = lcase(language)
            end if
        end for
        m.sessionConnection = origin
        url = ResolveUrl(origin.base,Txt(data.url))
        if url = ""
            m.status.text = "Server returned an unsupported playback URL."
            stopPlayback()
            return
        end if
        content = CreateObject("roSGNode","ContentNode")
        content.url = url
        content.streamFormat = Txt(data.format,"hls")
        content.title = Txt(m.playItem.displayName,Txt(m.playItem.name))
        m.playbackLive = m.playItem.type = "live"
        if data.live <> invalid then m.playbackLive = data.live
        content.live = m.playbackLive
        ' Jellyfin-derived caption ordering: Off→On must happen before content
        ' starts. Waiting for availableSubtitleTracks can otherwise deadlock on Roku.
        if m.captionRestore = invalid then m.captionRestore = m.video.globalCaptionMode
        m.nativeCaptionName = ""
        ApplyProfileCaptionStyle(m.video, data.preferences)
        PrepareNativeCaptions(m.video, data.selected_subtitle <> invalid)
        m.directSeekPause = false
        m.video.autoplayAfterSeek = true
        m.video.content = content
        m.timelineOffset = 0
        m.resumePosition = data.position
        if Txt(data.mode) <> "direct"
            ' FFmpeg has already sought the input; generated HLS starts at zero.
            m.timelineOffset = data.position
            m.resumePosition = invalid
        end if
        if data.duration <> invalid then m.duration = data.duration
        m.playbackMode = Txt(data.mode)
        uiHidePageExtras()
        if m.playerBackdrop <> invalid then m.playerBackdrop.visible = true
        m.video.visible = true
        m.playing = true
        if m.playerOverlay <> invalid
            m.playerOverlay.visible = true
            m.playerOverlay.opened = true
            m.playerOverlay.setFocus(true)
            updatePlayer()
            m.playerTick.control = "start"
        else
            m.top.setFocus(true)
        end if
        m.playStartClock = CreateObject("roTimespan")
        m.playStartClock.mark()
        m.video.control = "play"
        applyPlayerSubtitles()
        m.startup.control = "start"
        m.heartbeat.control = "start"
end sub

sub requestLiveRecovery()
    if m.managedLive <> true or not m.playing or Txt(m.session) = "" or m.liveRecoveryRequested = true then return
    m.liveRecoveryRequested = true
    m.startup.control = "stop"
    m.video.control = "stop"
    m.status.text = "Reconnecting channel…"
    uiBusy(true)
    request("POST","/api/playback/" + Enc(m.session) + "/recover",{generation:m.liveGeneration},"sideliverecover",m.sessionConnection)
end sub

sub managedLiveResponse(result as object,origin as object)
    if m.managedLive <> true or not m.playing or Txt(m.session) = "" then return
    expected = "/api/playback/" + Enc(m.session)
    if origin.path <> expected + "/heartbeat" and origin.path <> expected + "/recover" then return
    if not result.ok
        m.liveHeartbeatFailures++
        if m.liveHeartbeatFailures >= 3
            stopPlayback(false)
            sourceExhausted("Connection to the server was lost. Try again.")
        end if
        return
    end if
    m.liveHeartbeatFailures = 0
    data = result.data
    if data.managed_live <> true then return
    if data.state = "failed"
        stopPlayback(false)
        message = "No playable backup is available for this channel. Try again later."
        if data.reason = "recovery_budget_exhausted" then message = "This channel reached its recovery limit. Try again later."
        if data.reason = "recovery_deadline_exceeded" then message = "The backup took too long to start. Try again later."
        if data.reason = "connections_busy" then message = "All backup connections are busy. Try again shortly."
        sourceExhausted(message)
    else if data.state = "recovering"
        m.status.text = "Reconnecting channel…"
        uiBusy(true)
    else if data.state = "playing" and data.generation > m.liveGeneration
        if Txt(data.playback.id) <> m.session then return
        m.video.control = "stop"
        acceptPlayback(data.playback,m.sessionConnection)
        m.status.text = ""
    end if
end sub
