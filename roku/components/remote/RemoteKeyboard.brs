sub init()
    m.top.focusable = true
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
    m.top.findNode("ground").visible = not m.top.searchMode and not m.top.entryMode
    m.top.findNode("title").visible = not m.top.searchMode and not m.top.entryMode
    field = m.top.findNode("field")
    label = m.top.findNode("value")
    field.translation = [96,230]
    field.width = 1130
    label.translation = [120,246]
    label.width = 1082
    m.keys.translation = [96,370]
    field.visible = not m.top.entryMode
    label.visible = not m.top.entryMode
    m.top.findNode("validation").visible = not m.top.entryMode
    if m.top.entryMode then m.keys.translation = [0,0]
    m.keyValues = []
    m.keyRects = []
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
        ' Start on the first letter key of the grid (Space and Delete come first).
        m.cursor = 2
    else
        letters = "1234567890qwertyuiopasdfghjkl@zxcvbnm.-_"
        if m.symbols then letters = "1234567890!@#$%^&*()[]{}<>/\:;'"+chr(34)+".,?+=_-~"
        for i = 0 to len(letters)-1
            char = mid(letters,i+1,1)
            if m.upper then char = ucase(char)
            keyWidth = 104
            x = (i mod 10)*114
            if m.top.entryMode
                baseWidth = int((m.top.entryWidth-90)/10)
                remainder = int(m.top.entryWidth-90)-baseWidth*10
                column = i mod 10
                keyWidth = baseWidth
                if column < remainder then keyWidth++
                extra = column
                if extra > remainder then extra = remainder
                x = column*(baseWidth+10)+extra
            end if
            addKey(char,char,x,int(i/10)*86,keyWidth,76)
        end for
        if m.top.entryMode
            addKey("","shift",0,344,104,76)
            symbolLabel = "#+="
            if m.symbols then symbolLabel = "abc"
            addKey(symbolLabel,"symbols",114,344,104,76)
            addKey("","space",228,344,332,76)
            addKey(".com",".com",570,344,218,76)
            addKey("@gmail.com","@gmail.com",798,344,m.top.entryWidth-798,76)
        else
        commands = ["Shift","Symbols","Space","Delete","Clear","Done"]
        for i = 0 to 5
            addKey(commands[i],lcase(commands[i]),i*190,344,180,76)
        end for
        end if
        m.cursor = 10
    end if
    textChanged()
    paint()
end sub
sub addKey(label as string, value as string, x as float, y as float, width as float, height as float)
    group = m.keys.createChild("Group")
    group.translation = [x,y]
    ground = group.createChild("Poster")
    ground.uri = "pkg:/images/design/row.9.png"
    shape = "remote-entry-key"
    if width = 332 then shape = "remote-entry-space"
    if width = 218 then shape = "remote-entry-suffix"
    if m.top.entryMode then ground.uri = "pkg:/images/design/"+shape+".png"
    if m.top.entryMode and m.top.entryWidth <> 1130 then ground.uri = "pkg:/images/design/remote-entry-fluid.9.png"
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
    if m.top.entryMode and value = "symbols" then font.size = 24
    if m.top.entryMode and (value = ".com" or value = "@gmail.com") then font.size = 26
    title.font = font
    if value = "space" or value = "delete" or (m.top.entryMode and value = "shift")
        title.visible = false
        icon = group.createChild("Poster")
        name = "space"
        if value = "delete" then name = "backspace"
        if value = "shift" then name = "entry-shift"
        group.addFields({keyIcon:name})
        icon.uri = "pkg:/images/lucide/"+name+"-primary.png"
        icon.width = 28
        icon.height = 28
        icon.translation = [int((width-28)/2),int((height-28)/2)]
    end if
    if m.top.entryMode
        ring = group.createChild("Poster")
        ring.uri = "pkg:/images/design/"+shape+"-focus.png"
        if m.top.entryWidth <> 1130 then ring.uri = "pkg:/images/design/remote-entry-fluid-focus.9.png"
        ring.translation = [-4,-4]
        ring.width = width+8
        ring.height = height+8
    end if
    m.keyRects.push({x:x,y:y,width:width,height:height})
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
        if m.top.entryMode
            group.getChild(0).blendColor = "#FFFFFF17"
            ' The last five keys are the action row, not letters (40 letter keys).
            if i >= 40 then group.getChild(0).blendColor = "#FFFFFF2E"
            group.getChild(group.getChildCount()-1).visible = active
        end if
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
    if m.top.busy and key <> "back" then return true
    columns = 10
    if m.top.searchMode
        columns = 6
    end if
    if m.top.entryMode and (key = "up" or key = "down" or key = "left" or key = "right")
        entryMove(key)
        paint()
        return true
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
            if len(m.top.text) < m.top.maxLength then m.top.text += " "
        else if value = "delete"
            if len(m.top.text) > 0 then m.top.text = left(m.top.text,len(m.top.text)-1)
        else if value = "clear"
            m.top.text = ""
        else if value = "shift"
            old = m.cursor
            m.upper = not m.upper
            layout()
            if m.top.entryMode then m.cursor = old
        else if value = "symbols"
            old = m.cursor
            m.symbols = not m.symbols
            layout()
            if m.top.entryMode then m.cursor = old
        else if value = "done"
            m.top.submitted = true
        else if len(m.top.text)+len(value) <= m.top.maxLength
            m.top.text += value
        end if
    else
        return false
    end if
    paint()
    return true
end function

sub entryMove(key as string)
    current = m.keyRects[m.cursor]
    candidate = -1
    distance = 1000000
    cx = current.x+current.width/2
    for i = 0 to m.keyRects.count()-1
        r = m.keyRects[i]
        dx = r.x+r.width/2-cx
        dy = r.y-current.y
        eligible = false
        if key = "left" then eligible = dy = 0 and dx < 0
        if key = "right" then eligible = dy = 0 and dx > 0
        if key = "up" then eligible = dy < 0
        if key = "down" then eligible = dy > 0
        score = abs(dy)*100+abs(dx)
        if eligible and score < distance
            candidate = i
            distance = score
        end if
    end for
    if candidate >= 0
        m.cursor = candidate
    else if key = "up"
        m.top.exitUp = true
    else if key = "right"
        m.top.exitRight = true
    else if key = "left"
        m.top.exitLeft = true
    else if key = "down"
        m.top.exitDown = true
    end if
end sub

sub resetEntry()
    m.upper = false
    m.symbols = false
    layout()
end sub

sub busyChanged()
    if m.keys = invalid then return
    m.keys.opacity = 1
    m.top.findNode("validation").color = "#F87171"
    if m.top.busy
        m.keys.opacity = 0.55
        m.top.findNode("validation").color = "#B6B4AF"
    end if
end sub
