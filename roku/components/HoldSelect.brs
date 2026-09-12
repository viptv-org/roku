sub init()
    m.holdTimer = m.top.findNode("holdTimer")
    m.holdTimer.observeField("fire","held")
    m.pressed = false
    m.didHold = false
end sub
sub held()
    if not m.top.hasFocus() or not m.pressed then return
    m.didHold = true
    m.pressed = false
    m.top.activation = {held:true}
end sub
function onKeyEvent(key as string, press as boolean) as boolean
    if press and (key = "left" or key = "right" or key = "up" or key = "down")
        if m.top.hasField("navigation") then m.top.navigation = key
    end if
    if key <> "OK" then return false
    if press
        if not m.pressed
            m.pressed = true
            m.didHold = false
            m.holdTimer.control = "start"
        end if
    else
        m.holdTimer.control = "stop"
        if m.pressed and not m.didHold then m.top.activation = {held:false}
        m.pressed = false
    end if
    return true
end function
