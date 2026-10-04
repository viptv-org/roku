sub acceptPlayback(data as object,origin as object)
        if Txt(data.delivery_kind) = "gateway" then registerRokuPlaybackLease(data,origin)
        uiBusy(false)
        m.session = Txt(data.id)
        transitionSession = Txt(m.nextTransitionSession)
        if m.nextPrepping = true or transitionSession <> ""
            if transitionSession <> "" and transitionSession <> m.session
                request("DELETE",PlaybackSessionPath(m.nextTransitionConnection,transitionSession),invalid,"cleanup",m.nextTransitionConnection)
            end if
            m.nextTransitionSession = ""
            m.nextTransitionConnection = invalid
            m.nextPrepping = false
        end if
        m.heartbeat.duration = 15
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
        m.playbackDeliveryKind = Txt(data.delivery_kind)
        m.managedPausePosition = invalid
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
        preferences = data.preferences
        if m.playbackDeliveryKind = "gateway" and Txt(m.sourcePreferencesProfile) = m.profile then preferences = m.sourcePreferences
        ApplyProfileCaptionStyle(m.video, preferences)
        PrepareNativeCaptions(m.video, data.selected_subtitle <> invalid)
        m.directSeekPause = false
        m.video.autoplayAfterSeek = true
        m.video.content = content
        m.timelineOffset = 0
        m.resumePosition = data.position
        if Txt(data.mode) <> "direct" or m.playbackDeliveryKind = "gateway"
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
