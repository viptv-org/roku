' Native input bridge only. All actions and permissions belong to the Scene/server.
sub init()
    m.top.focusable = true
end sub
function onKeyEvent(key as string, press as boolean) as boolean
    if press then m.top.keyPressed = key
    return true
end function
