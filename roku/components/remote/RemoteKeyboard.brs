sub init()
    m.keys = m.top.findNode("keys")
    m.cursor = 10
    m.upper = false
    m.symbols = false
    m.top.observeField("focusedChild","paint")
    layout()
end sub
sub layout()
    if m.keys = invalid then return
    m.top.findNode("title").text = m.top.prompt
    m.top.findNode("ground").visible = not m.top.searchMode
    m.top.findNode("title").visible = not m.top.searchMode
    field = m.top.findNode("field")
    label = m.top.findNode("value")
    field.translation = [96,230]
    field.width = 1130
    label.translation = [120,246]
    label.width = 1082
    m.keys.translation = [96,370]
    m.keyValues = []
    m.keys.removeChildrenIndex(m.keys.getChildCount(),0)
    if m.top.searchMode
        field.translation = [96,140]
        field.width = 520
        field.height = 72
        label.translation = [116,157]
        label.width = 480
        m.keys.translation = [96,236]
        addKey("Space","space",0,0,255,68)
        addKey("Delete","delete",265,0,255,68)
        letters = "abcdefghijklmnopqrstuvwxyz1234567890"
        for i = 0 to len(letters)-1
            addKey(mid(letters,i+1,1),mid(letters,i+1,1),(i mod 6)*88,int(i/6)*76+76,80,68)
        end for
        m.cursor = 9
    else
        letters = "1234567890qwertyuiopasdfghjkl@zxcvbnm.-_"
        if m.symbols then letters = "1234567890!@#$%^&*()[]{}<>/\:;'"+chr(34)+".,?+=_-~"
        for i = 0 to len(letters)-1
            char = mid(letters,i+1,1)
            if m.upper then char = ucase(char)
            addKey(char,char,(i mod 10)*114,int(i/10)*86,104,76)
        end for
        commands = ["Shift","Symbols","Space","Delete","Clear","Done"]
        for i = 0 to 5
            addKey(commands[i],lcase(commands[i]),i*190,344,180,76)
        end for
        m.cursor = 10
    end if
    textChanged()
    paint()
end sub
sub addKey(label as string, value as string, x as integer, y as integer, width as integer, height as integer)
    group = m.keys.createChild("Group")
    group.translation = [x,y]
    ground = group.createChild("Poster")
    ground.uri = "pkg:/images/design/row.9.png"
    ground.width = width
    ground.height = height
    title = group.createChild("Label")
    title.text = label
    title.width = width
    title.height = height
    title.horizAlign = "center"
    title.vertAlign = "center"
    font = CreateObject("roSGNode","Font")
    font.uri = "pkg:/fonts/remote_onest_600.ttf"
    font.size = 28
    title.font = font
    if value = "space" or value = "delete"
        title.visible = false
        icon = group.createChild("Poster")
        name = "space"
        if value = "delete" then name = "backspace"
        group.addFields({keyIcon:name})
        icon.uri = "pkg:/images/lucide/"+name+"-primary.png"
        icon.width = 28
        icon.height = 28
        icon.translation = [int((width-28)/2),int((height-28)/2)]
    end if
    m.keyValues.push(value)
end sub
sub textChanged()
    label = m.top.findNode("value")
    if label = invalid then return
    value = m.top.text
    if m.top.secret
        value = ""
        for i = 1 to len(m.top.text)
            value += "•"
        end for
    end if
    label.text = value
    if value = "" then label.text = m.top.prompt
end sub
sub paint()
    if m.keys = invalid then return
    for i = 0 to m.keys.getChildCount()-1
        active = m.top.isInFocusChain() and i = m.cursor
        group = m.keys.getChild(i)
        group.getChild(0).blendColor = "#2A2A2EFF"
        group.getChild(1).color = "#F4F2EE"
        if active
            group.getChild(0).blendColor = "#F4F2EEFF"
            group.getChild(1).color = "#111113"
        end if
        if group.hasField("keyIcon")
            variant = "primary"
            if active then variant = "focus"
            group.getChild(2).uri = "pkg:/images/lucide/"+group.keyIcon+"-"+variant+".png"
        end if
    end for
end sub
function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return false
    columns = 10
    offset = 0
    if m.top.searchMode
        columns = 6
        offset = 2
    end if
    if key = "back"
        m.top.cancelled = true
    else if key = "left"
        if m.cursor > 0 then m.cursor--
    else if key = "right"
        if m.top.searchMode and m.cursor >= 2 and (m.cursor-2) mod 6 = 5
            m.top.exitRight = true
        else if m.cursor < m.keyValues.count()-1
            m.cursor++
        end if
    else if key = "up"
        m.cursor -= columns
        if m.cursor < 0 then m.cursor = 0
    else if key = "down"
        m.cursor += columns
        if m.cursor >= m.keyValues.count() then m.cursor = m.keyValues.count()-1
    else if key = "OK"
        value = m.keyValues[m.cursor]
        if value = "space"
            m.top.text += " "
        else if value = "delete"
            if len(m.top.text) > 0 then m.top.text = left(m.top.text,len(m.top.text)-1)
        else if value = "clear"
            m.top.text = ""
        else if value = "shift"
            m.upper = not m.upper
            layout()
        else if value = "symbols"
            m.symbols = not m.symbols
            layout()
        else if value = "done"
            m.top.submitted = true
        else if len(m.top.text) < 2048
            m.top.text += value
        end if
    else
        return false
    end if
    paint()
    return true
end function
