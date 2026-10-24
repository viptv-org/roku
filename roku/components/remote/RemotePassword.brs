sub init()
    m.top.focusable = true
    m.fields = m.top.findNode("fields")
    m.buttons = m.top.findNode("buttons")
    m.input = m.top.findNode("input")
    m.fields.focusable = true
    m.buttons.focusable = true
    m.editing = 0
    m.region = "keyboard"
    m.action = 0
    m.reveal = false
    m.syncing = false
    for i = 0 to 1
        group = m.fields.createChild("Group")
        group.translation = [0,i*140]
        label = passwordLabel(group,24,600,1130,30)
        if i = 0 then label.text = "Username" else label.text = "Password"
        label.color = "#B6B4AF"
        ground = group.createChild("Poster")
        ground.translation = [0,40]
        ground.width = 1130
        ground.height = 84
        ground.uri = "pkg:/images/design/remote-password-field.png"
        ground.blendColor = "#FFFFFF14"
        border = group.createChild("Poster")
        border.translation = [0,40]
        border.width = 1130
        border.height = 84
        value = passwordLabel(group,34,400,1064,41)
        value.translation = [28,61.5]
        cursor = group.createChild("Rectangle")
        cursor.width = 2
        cursor.height = 40
        cursor.color = "#F5C542"
        group.createChild("Group")
    end for
    m.labels = ["Sign in","Show password","Delete character","Use another server"]
    m.icons = ["entry-submit","entry-show","backspace","remote-server"]
    ys = [0,88,270,358]
    for i = 0 to 3
        group = m.buttons.createChild("Group")
        group.translation = [0,ys[i]]
        ground = group.createChild("Poster")
        ground.width = 534
        ground.height = 72
        ground.uri = "pkg:/images/design/remote-password-action.png"
        label = passwordLabel(group,26,700,0,32)
        label.text = m.labels[i]
        icon = group.createChild("Poster")
        icon.width = 28
        icon.height = 28
        ring = group.createChild("Poster")
        ring.uri = "pkg:/images/design/remote-password-action-focus.png"
        ring.translation = [-4,-4]
        ring.width = 542
        ring.height = 80
    end for
    m.input.observeField("text","edited")
    m.input.observeField("exitUp","inputUp")
    m.input.observeField("exitRight","inputRight")
    m.input.observeField("cancelled","cancel")
    m.top.observeField("focusedChild","paint")
    paint()
end sub
function passwordLabel(parent as object,size as integer,weight as integer,width as integer,height as integer) as object
    label = parent.createChild("Label")
    label.width = width
    label.height = height
    label.color = "#F4F2EE"
    font = CreateObject("roSGNode","Font")
    font.uri = "pkg:/fonts/remote_onest_"+weight.toStr()+".ttf"
    font.size = size
    label.font = font
    return label
end function
sub resetForm()
    m.top.username = ""
    m.top.password = ""
    m.top.error = ""
    m.top.busy = false
    m.reveal = false
    m.editing = 0
    m.action = 0
    m.input.secret = false
    m.input.callFunc("resetEntry")
    syncInput()
    focusKeyboard()
end sub
sub focusKeyboard()
    m.region = "keyboard"
    syncInput()
    m.input.setFocus(true)
    paint()
end sub
sub syncInput()
    m.syncing = true
    if m.editing = 0
        m.input.maxLength = 320
        if m.input.text <> m.top.username then m.input.text = m.top.username
    else
        m.input.maxLength = 512
        if m.input.text <> m.top.password then m.input.text = m.top.password
    end if
    m.syncing = false
end sub
sub edited()
    if m.syncing then return
    if m.editing = 0 then m.top.username = m.input.text else m.top.password = m.input.text
    m.top.error = ""
    paint()
end sub
sub inputUp()
    m.region = "fields"
    m.editing = 1
    m.input.setFocus(false)
    m.fields.setFocus(true)
    syncInput()
    paint()
end sub
sub inputRight()
    m.region = "actions"
    if m.action = 0 and (m.top.busy or m.top.username.trim() = "" or m.top.password = "") then m.action = 1
    m.input.setFocus(false)
    m.buttons.setFocus(true)
    paint()
end sub
sub cancel()
    m.top.cancelled = true
end sub
sub paint()
    if m.fields = invalid then return
    values = [m.top.username,m.top.password]
    for i = 0 to 1
        group = m.fields.getChild(i)
        border = group.getChild(2)
        border.uri = "pkg:/images/design/remote-password-field-idle.png"
        border.blendColor = "#FFFFFF24"
        if m.editing = i
            border.uri = "pkg:/images/design/remote-password-field-active.png"
            border.blendColor = "#F4F2EE"
        end if
        label = group.getChild(3)
        label.text = values[i]
        label.color = "#F4F2EE"
        if i = 1 and not m.reveal
            label.text = ""
            for j = 1 to len(values[i])
                label.text += "•"
            end for
        end if
        if values[i] = ""
            label.color = "#B6B4AF"
            if i = 0 then label.text = "username" else label.text = "Password"
        end if
        measure = CreateObject("roSGNode","Label")
        measure.font = label.font
        measure.text = label.text
        x = 36+measure.boundingRect().width
        mask = group.getChild(5)
        mask.visible = i = 1 and not m.reveal and values[i] <> ""
        label.visible = not mask.visible
        if mask.visible
            measure.text = "•"
            stepWidth = measure.boundingRect().width+6.8
            count = len(values[i])
            limit = int(1064/stepWidth)
            if count > limit then count = limit
            while mask.getChildCount() > count
                mask.removeChildrenIndex(1,mask.getChildCount()-1)
            end while
            while mask.getChildCount() < count
                dot = passwordLabel(mask,34,400,int(stepWidth+1),41)
            end while
            for j = 0 to count-1
                dot = mask.getChild(j)
                dot.text = "•"
                if j = count-1 and len(values[i]) > limit then dot.text = "…"
                dot.translation = [28+j*stepWidth,61.5]
            end for
            x = 36+count*stepWidth
        end if
        if x > 1098 then x = 1098
        group.getChild(4).translation = [x,62]
        group.getChild(4).visible = m.editing = i
    end for
    if not m.top.serverAllowed and m.action = 3 then m.action = 2
    m.buttons.getChild(3).visible = m.top.serverAllowed
    errorY = 716
    if not m.top.serverAllowed then errorY = 628
    m.top.findNode("errorLabel").translation = [1290,errorY]
    m.top.findNode("busyLabel").translation = [1290,errorY+128]
    for i = 0 to 3
        group = m.buttons.getChild(i)
        enabled = true
        if i = 0 then enabled = not m.top.busy and m.top.username.trim() <> "" and m.top.password <> ""
        active = m.region = "actions" and m.action = i and m.top.isInFocusChain() and enabled
        group.opacity = 1
        if not enabled then group.opacity = 0.38
        group.getChild(0).blendColor = "#F4F2EE29"
        group.getChild(1).color = "#F4F2EE"
        variant = "primary"
        if active
            group.getChild(0).blendColor = "#F4F2EE"
            group.getChild(1).color = "#0B0B0C"
            variant = "focus"
        end if
        label = group.getChild(1)
        label.text = m.labels[i]
        icon = m.icons[i]
        if i = 1 and m.reveal
            label.text = "Hide password"
            icon = "entry-hide"
        end if
        x = (534-label.boundingRect().width-40)/2
        group.getChild(2).translation = [x,22]
        group.getChild(2).uri = "pkg:/images/lucide/"+icon+"-"+variant+".png"
        label.translation = [x+40,20]
        group.getChild(3).visible = active
    end for
    m.top.findNode("busyLabel").visible = m.top.busy
    syncInput()
end sub
function onKeyEvent(key as string,press as boolean) as boolean
    if not press then return false
    if key = "back"
        cancel()
    else if m.region = "fields"
        if key = "up" then m.editing = 0
        if key = "down"
            if m.editing = 0 then m.editing = 1 else focusKeyboard()
        else if key = "OK"
            focusKeyboard()
        else if key = "right"
            inputRight()
        end if
        syncInput()
    else if m.region = "actions"
        if key = "up" and m.action > 0
            if m.action <> 1 or (not m.top.busy and m.top.username.trim() <> "" and m.top.password <> "") then m.action--
        end if
        lastAction = 2
        if m.top.serverAllowed then lastAction = 3
        if key = "down" and m.action < lastAction then m.action++
        if key = "left" then focusKeyboard()
        if key = "OK"
            if m.action = 0 and not m.top.busy and m.top.username.trim() <> "" and m.top.password <> ""
                m.top.submitted = true
            else if m.action = 1
                m.reveal = not m.reveal
            else if m.action = 2
                if m.editing = 0
                    if len(m.top.username) > 0 then m.top.username = left(m.top.username,len(m.top.username)-1)
                else
                    if len(m.top.password) > 0 then m.top.password = left(m.top.password,len(m.top.password)-1)
                end if
                syncInput()
            else if m.action = 3 and m.top.serverAllowed
                m.top.serverRequested = true
            end if
        end if
    else
        return false
    end if
    paint()
    return true
end function
