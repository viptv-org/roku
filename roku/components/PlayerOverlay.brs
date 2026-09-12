sub init()
    m.row = 0
    m.button = 1
    m.preview = invalid
    m.scrubKey = ""
    m.scrubRepeats = 0
    m.justCommittedSeek = false
    m.seekDebounceTimer = m.top.findNode("seekDebounceTimer")
    m.seekDebounceTimer.observeField("fire","commitSeekPreview")
    m.hideTimer = m.top.findNode("hideTimer")
    if m.hideTimer <> invalid then m.hideTimer.observeField("fire","hidePanel")
end sub

sub openedChanged()
    if m.top.opened and m.hideTimer <> invalid then m.hideTimer.control = "start"
    render()
end sub

sub hidePanel()
    if m.top.model = invalid then return
    ' A modal owns focus; never hide controls underneath it or a sidebar.
    if not m.top.hasFocus()
        if m.hideTimer <> invalid then m.hideTimer.control = "start"
        return
    end if
    if Txt(m.top.model.state) = "buffering"
        if m.hideTimer <> invalid then m.hideTimer.control = "start"
    else if m.preview = invalid and m.top.model.paused <> true
        m.top.opened = false
        render()
    end if
end sub

sub render()
    data = m.top.model
    if data = invalid then return
    if data.live = true
        cancelSeekPreview()
        m.row = 1
        m.preview = invalid
        if m.button < 3 then m.button = 3
    end if
    state = Txt(data.state)
    buffering = state = "buffering" or state = "opening" or data.seeking = true
    if m.lastSession <> invalid and m.lastSession <> Txt(data.session) then cancelSeekPreview()
    if m.lastSession <> Txt(data.session)
        m.lastSession = Txt(data.session)
        m.hideTimer.control = "start"
    end if
    if m.lastState <> state
        m.lastState = state
        if buffering then m.top.opened = true
        m.hideTimer.control = "start"
    end if
    shown = m.top.opened or buffering
    for each id in ["topGradient","bottomGradient","title","context","seekRow","timeLeft","timeRight","controlRow","eyebrow"]
        m.top.findNode(id).visible = shown
    end for
    title = m.top.findNode("title")
    displayTitle = Txt(data.title)
    now = CreateObject("roDateTime").asSeconds()
    programme = data.programme
    hasProgramme = false
    if programme <> invalid
        if programme.start <> invalid and programme.end <> invalid then hasProgramme = programme.start <= now and programme.end > now
    end if
    if data.live = true and hasProgramme then displayTitle = Txt(programme.title,data.title)
    if title.text <> displayTitle then title.text = displayTitle
    ' The top-left identifies the content, not the app. Live swaps the V mark for
    ' the channel logo/name; VOD replaces the wordmark with the actual title.
    live = (data.live = true)
    m.top.findNode("brandMark").visible = shown and not live
    m.top.findNode("brandWordmark").visible = shown and not live
    if Txt(data.episode) <> "" then m.top.findNode("brandWordmark").text = Txt(data.episode) else m.top.findNode("brandWordmark").text = displayTitle
    identity = m.top.findNode("channelIdentity")
    identity.visible = shown and live
    m.top.findNode("channelName").text = Txt(data.title)
    logo = m.top.findNode("channelLogo")
    if logo.uri <> Txt(data.logo) then logo.uri = Txt(data.logo)
    m.top.findNode("channelName").translation = [164,42]
    if Txt(data.logo) = "" then m.top.findNode("channelName").translation = [64,42]
    logo.visible = Txt(data.logo) <> ""
    m.top.findNode("channelLogoSurface").visible = logo.visible
    eyebrow = "NOW PLAYING"
    if data.live = true then eyebrow = "ON NOW  ·  LIVE TV"
    m.top.findNode("eyebrow").text = eyebrow
    status = "PLAYING"
    if data.paused = true then status = "PAUSED"
    if data.live = true then status = "● LIVE"
    if buffering then status = "LOADING"
    m.top.findNode("playbackStatus").text = status
    m.top.findNode("programmeProgress").visible = shown and data.live = true and hasProgramme
    repeats = 0
    if shown then repeats = -1
    if title.repeatCount <> repeats then title.repeatCount = repeats
    m.top.findNode("context").text = Txt(data.context)
    spinner = m.top.findNode("spinner")
    spinner.visible = buffering
    if spinner.poster.uri = "" then spinner.poster.uri = "pkg:/images/ui-spinner.png"
    spinner.poster.width = 60
    spinner.poster.height = 60
    if buffering then spinner.control = "start" else spinner.control = "stop"
    position = data.position
    if position = invalid then position = 0
    duration = data.duration
    if duration = invalid then duration = 0
    if data.seeking = true and data.seek_target <> invalid then position = data.seek_target
    if m.preview <> invalid then position = m.preview
    fraction = 0.0
    current = 0.0
    if duration > 0
        fraction = position / duration
        current = data.position / duration
    end if
    if fraction < 0 then fraction = 0
    if fraction > 1 then fraction = 1
    if current < 0 then current = 0
    if current > 1 then current = 1
    m.top.findNode("seekFill").width = 1152 * current
    m.top.findNode("seekFill").visible = current > 0
    m.top.findNode("seekThumb").translation = [1152*fraction-8,-5]
    m.top.findNode("seekThumb").visible = m.row = 0 and data.live <> true and duration > 0
    m.top.findNode("seekPreviewMarker").translation = [1152*current-1,-3]
    m.top.findNode("seekPreviewMarker").visible = m.preview <> invalid
    m.top.findNode("timeLeft").text = PlayerTime(position)
    m.top.findNode("timeRight").text = PlayerTime(duration)
    if data.live = true
        m.top.findNode("seekRow").visible = false
        m.top.findNode("timeLeft").text = "LIVE"
        m.top.findNode("timeRight").text = "Live broadcast"
        if hasProgramme
            m.top.findNode("timeLeft").text = "ON NOW"
            m.top.findNode("timeRight").text = int((programme.end-now+59)/60).toStr()+" min left"
            m.top.findNode("programmeFill").width = 1152.0*(now-programme.start)/(programme.end-programme.start)
        end if
    end if
    pause = "Pause"
    if data.paused = true then pause = "Resume"
    m.top.findNode("controlRow").translation = [64,624]
    m.top.findNode("controlSurface").visible = false
    positions = [0,80,160,928,1008,1088,240]
    if data.next_episode <> true and m.button = 6
        m.button = 1
        if data.live = true then m.button = 3
    end if
    if data.live = true then positions = [0,0,0,0,544,1088,0]
    m.top.findNode("btnPauseLabel").text = pause
    pauseIcon = "pause"
    if data.paused = true then pauseIcon = "play"
    m.top.findNode("btnPauseIcon").uri = "pkg:/images/ui-nav-player-"+pauseIcon+".png"
    focused = m.row = 1 and m.top.hasFocus()
    m.top.findNode("focusPill").visible = focused
    m.top.findNode("focusPill").translation = [positions[m.button],0]
    labels = ["btnRewindLabel","btnPauseLabel","btnForwardLabel","btnAudioLabel","btnSubtitlesLabel","btnExitLabel","btnNextLabel"]
    icons = ["btnRewindIcon","btnPauseIcon","btnForwardIcon","btnAudioIcon","btnSubtitlesIcon","btnExitIcon","btnNextIcon"]
    for i = 0 to 6
        label = m.top.findNode(labels[i])
        label.visible = false
        label.color = "#F5F5F5"
        if focused and i = m.button then label.color = "#101112"
        icon = m.top.findNode(icons[i])
        icon.translation = [positions[i]+18,18]
        icon.visible = data.live <> true or i >= 3
        if i = 6 then icon.visible = data.next_episode = true and data.live <> true
        icon.blendColor = label.color
    end for
    m.top.findNode("hint").text = ""
    m.top.findNode("hint").visible = false
end sub

sub emit(kind as string, value = invalid as dynamic)
    m.top.command = {kind:kind,value:value}
end sub

function SeekStepForRepeat(key as string, repeats as integer) as integer
    amount = 10
    if key = "fastforward" or key = "rewind" or key = "fwd" or key = "rev" then amount = 60
    multiplier = 1
    if repeats >= 2 then multiplier = 3
    if repeats >= 5 then multiplier = 6
    if repeats >= 9 then multiplier = 15
    if repeats >= 15 then multiplier = 60
    return amount * multiplier
end function

function onKeyEvent(key as string, press as boolean) as boolean
    if not press
        if key = m.scrubKey
            m.scrubKey = ""
            m.scrubRepeats = 0
            if m.preview <> invalid and m.top.model <> invalid
                if m.top.model.live <> true and m.top.model.seeking <> true
                    m.seekDebounceTimer.control = "stop"
                    m.seekDebounceTimer.control = "start"
                    render()
                    return true
                end if
            end if
        end if
        return false
    end if
    data = m.top.model
    if data = invalid then return false
    if data.live = true then m.row = 1
    if data.seeking = true
        if key = "back" then emit("exit")
        return true
    end if
    if m.hideTimer <> invalid then m.hideTimer.control = "start"
    if key = "back"
        if m.preview <> invalid
            cancelSeekPreview()
        else if m.top.opened
            m.top.opened = false
        else
            emit("exit")
        end if
        render()
        return true
    end if
    if key = "play"
        cancelSeekPreview()
        if data.live <> true then emit("pause")
        m.top.opened = true
        render()
        return true
    end if
    wasOpen = m.top.opened
    m.top.opened = true
    scrubKey = key = "left" or key = "right" or key = "fastforward" or key = "rewind" or key = "fwd" or key = "rev"
    if not scrubKey
        m.scrubKey = ""
        m.scrubRepeats = 0
        if key <> "OK" then m.justCommittedSeek = false
    end if
    if not wasOpen and data.live <> true and (key = "left" or key = "right") then m.row = 0
    if key = "down"
        cancelSeekPreview()
        m.row = 1
    else if key = "up"
        if data.live <> true then m.row = 0
    else if key = "left" or key = "right" or key = "fastforward" or key = "rewind" or key = "fwd" or key = "rev"
        if m.row = 1 and (key = "left" or key = "right")
            first = 0
            count = 6
            if data.next_episode = true then count = 7
            if data.live = true
                first = 3
                count = 3
            end if
            order = [0,1,2,3,4,5]
            if data.next_episode = true then order = [0,1,2,6,3,4,5]
            if data.live = true then order = [3,4,5]
            index = 0
            for i = 0 to order.count()-1
                if order[i] = m.button then index = i
            end for
            if key = "left" then index = (index+order.count()-1) mod order.count() else index = (index+1) mod order.count()
            m.button = order[index]
        else if data.live <> true and data.duration > 0
            m.seekDebounceTimer.control = "stop"
            if m.scrubKey = key
                m.scrubRepeats++
            else
                m.scrubKey = key
                m.scrubRepeats = 0
            end if
            delta = SeekStepForRepeat(key,m.scrubRepeats)
            if key = "left" or key = "rewind" or key = "rev" then delta = -delta
            if m.preview = invalid then m.preview = data.position
            m.preview = ClampPlayerSeek(m.preview + delta,data.duration)
            m.row = 0
        end if
    else if key = "OK"
        if m.preview <> invalid and m.row = 0
            commitSeekPreview()
        else if m.justCommittedSeek
            m.justCommittedSeek = false
        else if wasOpen and m.row = 1
            actions = ["rewind","pause","forward","audio","subtitles","exit","next"]
            if m.button = 0
                if data.duration > 0 then queueSeekStep(-10,"OK")
            else if m.button = 2
                if data.duration > 0 then queueSeekStep(30,"OK")
            else
                emit(actions[m.button])
            end if
        else if wasOpen and m.row = 0 and data.live <> true
            emit("pause")
        end if
    else if key = "replay" or key = "instantreplay"
        if data.live <> true then queueSeekStep(-10,key)
    else if key = "options" or key = "info"
        cancelSeekPreview()
        m.row = 1
        m.button = 3
    else
        return false
    end if
    render()
    return true
end function

sub cancelSeekPreview()
    if m.seekDebounceTimer <> invalid then m.seekDebounceTimer.control = "stop"
    m.preview = invalid
    m.scrubKey = ""
    m.scrubRepeats = 0
end sub

sub queueSeekStep(delta as integer, key as string)
    if m.top.model.duration <= 0 then return
    m.seekDebounceTimer.control = "stop"
    if m.preview = invalid then m.preview = m.top.model.position
    m.preview = ClampPlayerSeek(m.preview+delta,m.top.model.duration)
    m.scrubKey = key
    m.justCommittedSeek = false
end sub

sub commitSeekPreview()
    if m.seekDebounceTimer <> invalid then m.seekDebounceTimer.control = "stop"
    if m.preview = invalid then return
    data = m.top.model
    if data = invalid then return
    if data.live = true or data.seeking = true or not m.top.hasFocus()
        cancelSeekPreview()
        return
    end if
    target = m.preview
    cancelSeekPreview()
    if abs(target - data.position) < 0.5 then return
    m.justCommittedSeek = true
    emit("seek",target)
    render()
end sub
