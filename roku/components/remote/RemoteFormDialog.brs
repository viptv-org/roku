' Renderer-only modal. Submission eligibility and validation belong to the server.
sub init()
    m.top.focusable = true
    for each id in ["measure","panel","ground","title","outline","labelGround","label","value","failure","cancel","cancelFocus","cancelText","confirm","confirmFocus","confirmText"]
        m[id] = m.top.findNode(id)
    end for
    render()
end sub

function isPin() as boolean
    return m.top.purpose = "unlock" or m.top.purpose = "unlockResume"
end function

sub render()
    if m.panel = invalid then return
    pin = isPin()
    width = 328
    title = "Name"
    label = "Name"
    confirm = "Save"
    confirmWidth = 58
    labelWidth = 34
    if m.top.purpose = "createProfile"
        title = "Add profile"
        confirm = "Add"
    else if pin
        width = 560
        title = "Unlock parental controls"
        label = "Parent PIN"
        labelWidth = 63
        confirm = "Unlock"
        confirmWidth = 70
    end if
    m.failure.width = width-48
    m.failure.height = 0
    m.failure.numLines = 0
    m.failure.text = m.top.error
    measured = m.failure.boundingRect()
    count = 0
    if m.top.error <> ""
        lineHeight = m.measure.boundingRect().height
        count = int((measured.height+lineHeight-1)/lineHeight)
        if count < 1 then count = 1
    end if
    extra = 0
    gap = 16
    if pin then gap = 14
    if count > 0 then extra = gap+20*count
    height = 232+extra
    m.panel.translation = [(1920-width)/2,(1080-height)/2]
    m.ground.width = width
    m.ground.height = height
    m.title.text = title
    focused = m.top.focusIndex = 0 and not m.top.busy
    uri = "pkg:/images/design/remote-form-outline.9.png"
    color = "#5C5B5A"
    if focused
        uri = "pkg:/images/design/remote-form-outline-focus.9.png"
        color = "#F4F2EE"
    end if
    m.outline.uri = uri
    m.outline.blendColor = color
    m.outline.width = width-48
    floated = focused or m.top.text <> ""
    m.label.text = label
    m.label.width = width-80
    m.label.height = 24
    m.label.translation = [40,96]
    font = m.label.font
    font.size = 16
    m.labelGround.visible = floated
    if floated
        m.label.translation = [40,72]
        m.label.height = 16
        m.label.width = labelWidth
        font.size = 12
        m.labelGround.translation = [36,72]
        m.labelGround.width = labelWidth+8
        m.labelGround.height = 16
    end if
    m.label.color = "#B6B4AF"
    if focused then m.label.color = "#F4F2EE"
    value = m.top.text
    if pin
        value = ""
        for i = 1 to len(m.top.text)
            value += "•"
        end for
    end if
    m.value.text = value
    m.value.width = width-80
    m.value.opacity = 1
    m.outline.opacity = 1
    m.label.opacity = 1
    if pin and m.top.busy
        m.value.opacity = 0.38
        m.outline.opacity = 0.38
        m.label.opacity = 0.38
    end if
    m.failure.visible = count > 0
    m.failure.translation = [24,136+gap]
    m.failure.width = width-48
    m.failure.height = count*20
    m.failure.text = m.top.error
    m.cancel.translation = [width-24-confirmWidth-8-70,164+extra]
    m.confirm.translation = [width-24-confirmWidth,164+extra]
    m.confirmFocus.width = confirmWidth
    m.confirmText.rowWidth = confirmWidth
    m.confirmText.text = confirm
    m.cancelFocus.visible = m.top.focusIndex = 1 and not (pin and m.top.busy)
    m.confirmFocus.visible = m.top.focusIndex = 2 and not m.top.busy
    m.cancelText.opacity = 1
    m.confirmText.opacity = 1
    if pin and m.top.busy then m.cancelText.opacity = 0.38
    if m.top.busy then m.confirmText.opacity = 0.38
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return false
    if key = "back"
        if not (isPin() and m.top.busy) then m.top.cancelled = true
        return true
    end if
    if key = "OK"
        if m.top.focusIndex = 0 and not m.top.busy
            m.top.editRequested = true
        else if m.top.focusIndex = 1 and not (isPin() and m.top.busy)
            m.top.cancelled = true
        else if m.top.focusIndex = 2 and not m.top.busy
            m.top.submitted = true
        end if
        return true
    end if
    if key = "up" then m.top.focusIndex = 0
    if key = "down" and m.top.focusIndex = 0 then m.top.focusIndex = 1
    if key = "left" and m.top.focusIndex > 0 then m.top.focusIndex = 1
    if key = "right" then m.top.focusIndex = 2
    return true
end function
