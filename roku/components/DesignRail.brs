sub init()
    m.icons = []
end sub
sub rebuild()
    container = m.top.findNode("items")
    container.removeChildrenIndex(container.getChildCount(),0)
    m.icons = []
    if m.top.content = invalid then return
    positions = [36,123,175,227,279,331,639]
    for i = 0 to m.top.content.getChildCount()-1
        icon = container.createChild("NavIcon")
        icon.translation = [27,positions[i]]
        icon.itemContent = m.top.content.getChild(i)
        m.icons.push(icon)
    end for
    render()
end sub
sub jump()
    m.top.itemFocused = m.top.jumpToItem
    render()
end sub
sub render()
    expanded = m.top.active
    m.top.findNode("scrim").visible = expanded
    width = 96
    if expanded then width = 347
    m.top.findNode("panel").width = width
    for i = 0 to m.icons.count()-1
        m.icons[i].expanded = expanded
        m.icons[i].listHasFocus = expanded
        fraction = 0.0
        if i = m.top.itemFocused then fraction = 1.0
        m.icons[i].focusPercent = fraction
    end for
end sub
function onKeyEvent(key as string, press as boolean) as boolean
    if key = "OK"
        if not press then m.top.itemSelected = m.top.itemFocused
        return true
    end if
    if not press then return false
    index = m.top.itemFocused
    if key = "up" and index > 0 then index--
    if key = "down" and index < m.icons.count()-1 then index++
    if key = "up" or key = "down"
        m.top.itemFocused = index
        render()
        return true
    end if
    return false
end function
