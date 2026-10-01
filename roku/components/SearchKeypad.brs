sub init()
    m.top.textEditBox = m.top.findNode("edit")
    m.index = 0
    m.keys = []
    alphabet = "abcdefghijklmnopqrstuvwxyz1234567890"
    container = m.top.findNode("keys")
    for i = 0 to 38
        x = (i mod 6)*63
        y = int(i/6)*49
        width = 56
        if i >= 36
            x = (i-36)*128
            y = 294
            width = 118
        end if
        group = container.createChild("Group")
        group.translation = [x,y]
        surface = group.createChild("DesignSurface")
        surface.width = width
        surface.height = 42
        surface.radius = 11
        label = group.createChild("Label")
        label.width = width
        label.height = 42
        label.horizAlign = "center"
        label.vertAlign = "center"
        font = CreateObject("roSGNode","Font")
        font.uri = "pkg:/fonts/onest_700.ttf"
        font.size = 19
        label.font = font
        icon = group.createChild("Poster")
        icon.width = 22
        icon.height = 22
        icon.translation = [(width-22)/2,10]
        icon.visible = i >= 36
        name = ""
        if i < 36
            label.text = mid(alphabet,i+1,1)
        else
            name = ["space","backspace","delete"][i-36]
        end if
        m.keys.push({surface:surface,label:label,icon:icon,name:name})
    end for
    paint()
end sub
sub textChanged()
    if m.top.textEditBox <> invalid
        m.top.textEditBox.text = m.top.text
        m.top.textEditBox.cursorPosition = len(m.top.text)
    end if
end sub
sub paint()
    if m.keys = invalid then return
    for i = 0 to m.keys.count()-1
        key = m.keys[i]
        focused = m.top.active and i = m.index
        fill = "#212124FF"
        ink = "#F4F2EE"
        variant = "primary"
        if focused
            fill = "#F4F2EEFF"
            ink = "#111113"
            variant = "focus"
        end if
        key.surface.blendColor = fill
        key.surface.focused = focused
        key.label.color = ink
        if key.name <> "" then key.icon.uri = "pkg:/images/lucide/"+key.name+"-"+variant+".png"
    end for
end sub
function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return false
    if KeyboardMobileInput(m.top,key) then return true
    index = m.index
    if key = "left"
        if index < 36 and index mod 6 = 0 then return false
        if index = 36 then return false
        index--
    else if key = "right"
        if index < 36 and index mod 6 = 5 then return false
        if index = 38 then return false
        index++
    else if key = "up"
        if index < 6 then return true
        if index >= 36 then index = 30+(index-36)*2 else index -= 6
    else if key = "down"
        if index >= 36 then return true
        if index >= 30 then index = 36+int((index-30)/2) else index += 6
    else if key = "OK"
        if index < 36
            KeyboardMobileInput(m.top,"Lit_"+m.keys[index].label.text)
        else if index = 36
            KeyboardMobileInput(m.top,"Lit_ ")
        else if index = 37
            KeyboardMobileInput(m.top,"backspace")
        else
            m.top.text = ""
        end if
        return true
    else
        return false
    end if
    m.index = index
    m.top.active = true
    paint()
    return true
end function
