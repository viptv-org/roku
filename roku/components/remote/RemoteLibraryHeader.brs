sub init()
    m.top.focusable = true
    m.items = m.top.findNode("items")
    m.group = m.top.findNode("group")
    m.top.observeField("focusedChild","paint")
end sub
sub render()
    m.items.removeChildrenIndex(m.items.getChildCount(),0)
    if m.top.content = invalid then return
    if m.top.content.getChildCount() = 0
        m.group.visible = false
        return
    end if
    count = m.top.content.getChildCount()-1
    width = 168
    if count > 3 then width = 140
    m.group.width = count*width+12
    m.group.visible = count > 0
    for i = 0 to m.top.content.getChildCount()-1
        item = m.top.content.getChild(i)
        tile = m.items.createChild("Group")
        tile.translation = [6+i*width,6]
        surface = tile.createChild("Poster")
        surface.width = width
        surface.height = 52
        surface.uri = "pkg:/images/design/remote-library-type.png"
        if width = 168 then surface.uri = "pkg:/images/design/remote-library-type-wide.png"
        label = tile.createChild("Label")
        label.width = width
        label.height = 52
        label.horizAlign = "center"
        label.vertAlign = "center"
        label.text = item.title
        font = CreateObject("roSGNode","Font")
        font.uri = "pkg:/fonts/remote_onest_400.ttf"
        font.size = 24
        label.font = font
        if item.wire.action = "libraryFilters"
            tile.translation = [1564,0]
            surface.uri = "pkg:/images/design/remote-library-filter.png"
            surface.width = 164
            surface.height = 64
            label.translation = [60,0]
            label.width = 80
            label.height = 64
            icon = tile.createChild("Poster")
            icon.translation = [24,20]
            icon.width = 24
            icon.height = 24
        end if
        ring = tile.createChild("Poster")
        ring.translation = [-4,-4]
        ring.width = surface.width+8
        ring.height = surface.height+8
        ring.uri = "pkg:/images/design/remote-library-type-focus.png"
        if width = 168 then ring.uri = "pkg:/images/design/remote-library-type-wide-focus.png"
        if item.wire.action = "libraryFilters" then ring.uri = "pkg:/images/design/remote-library-filter-focus.png"
        ring.blendColor = "#FFFFFFFF"
    end for
    if m.top.itemFocused >= m.items.getChildCount() then m.top.itemFocused = 0
    paint()
end sub
sub paint()
    if m.items = invalid or m.top.content = invalid then return
    for i = 0 to m.items.getChildCount()-1
        tile = m.items.getChild(i)
        item = m.top.content.getChild(i)
        focused = m.top.isInFocusChain() and i = m.top.itemFocused
        surface = tile.getChild(0)
        label = tile.getChild(1)
        tile.getChild(tile.getChildCount()-1).visible = focused
        surface.opacity = 0
        surface.blendColor = "#0B0B0C"
        label.color = "#F4F2EE"
        if item.wire.selected = true then surface.opacity = 1
        if item.wire.action = "libraryFilters"
            surface.opacity = 1
            surface.blendColor = "#212124"
            tile.getChild(2).uri = "pkg:/images/lucide/remote-sliders-primary.png"
        end if
        if focused
            surface.opacity = 1
            surface.blendColor = "#F4F2EE"
            label.color = "#0B0B0C"
            if item.wire.action = "libraryFilters" then tile.getChild(2).uri = "pkg:/images/lucide/remote-sliders-focus.png"
        end if
    end for
end sub
function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return false
    if key = "left"
        if m.top.itemFocused > 0 then m.top.itemFocused--
    else if key = "right"
        if m.top.itemFocused < m.items.getChildCount()-1 then m.top.itemFocused++
    else if key = "OK"
        m.top.itemSelected = m.top.itemFocused
    else
        return false
    end if
    return true
end function
