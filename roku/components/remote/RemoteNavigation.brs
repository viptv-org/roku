sub init()
    m.items = m.top.findNode("items")
    m.top.observeField("focusedChild","paint")
end sub

sub render()
    m.items.removeChildrenIndex(m.items.getChildCount(),0)
    x = 300
    for each item in RArray(m.top.destinations)
        width = item.width
        group = CreateObject("roSGNode","Group")
        if item.id = "menu" then x = 1768
        group.translation = [x,38]
        ring = group.createChild("Poster")
        ring.uri = "pkg:/images/ui-round-fill.9.png"
        ring.width = width+6
        ring.height = 62
        ring.translation = [-3,-3]
        ground = group.createChild("Poster")
        ground.uri = "pkg:/images/ui-round-fill.9.png"
        ground.width = width
        ground.height = 56
        ground.blendColor = "#212124FF"
        label = group.createChild("Label")
        label.text = item.label
        label.width = width
        label.height = 56
        label.horizAlign = "center"
        label.vertAlign = "center"
        font = CreateObject("roSGNode","Font")
        font.uri = "pkg:/fonts/remote_onest_500.ttf"
        font.size = 26
        label.font = font
        underline = group.createChild("Rectangle")
        underline.translation = [18,49]
        underline.width = width-36
        underline.height = 3
        underline.color = "#F4F2EE"
        if RText(item.icon) <> ""
            icon = group.createChild("Poster")
            icon.uri = "pkg:/images/lucide/"+item.icon+"-primary.png"
            icon.width = 30
            icon.height = 30
            icon.translation = [13,13]
            if item.id = "menu"
                icon.uri = "pkg:/images/design/circle.png"
                icon.width = 56
                icon.height = 56
                icon.translation = [0,0]
                icon.blendColor = "#40766BFF"
                initial = group.createChild("Label")
                initial.text = ucase(left(m.top.profileName,1))
                initial.width = 56
                initial.height = 56
                initial.horizAlign = "center"
                initial.vertAlign = "center"
                initial.font = font
                if m.top.avatarUri <> ""
                    icon.uri = m.top.avatarUri
                    icon.blendColor = "#FFFFFFFF"
                    initial.visible = false
                end if
            end if
        end if
        m.items.appendChild(group)
        x += width+8
    end for
    paint()
end sub

sub paint()
    if m.items = invalid then return
    for i = 0 to m.items.getChildCount()-1
        group = m.items.getChild(i)
        focused = m.top.isInFocusChain() and m.top.cursor = i
        group.getChild(0).visible = focused
        group.getChild(1).visible = focused
        group.getChild(3).visible = m.top.destinations[i].id = m.top.active
    end for
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return false
    if key = "left"
        if m.top.cursor > 0 then m.top.cursor--
    else if key = "right"
        if m.top.cursor < m.items.getChildCount()-1 then m.top.cursor++
    else if key = "OK"
        if m.items.getChildCount() > 0 then m.top.selected = m.top.destinations[m.top.cursor].id
    else if key = "down"
        m.top.down = true
    else if key <> "up"
        return false
    end if
    return true
end function
