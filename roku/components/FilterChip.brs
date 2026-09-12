sub render()
    item = m.top.itemContent
    if item = invalid then return
    changed = true
    if m.ownerItem <> invalid then changed = not m.ownerItem.isSameNode(item)
    if changed
        if m.ownerItem <> invalid then m.ownerItem.unobserveField("uiOwnerFocused")
        m.ownerItem = item
        if item.hasField("uiOwnerFocused") then item.observeField("uiOwnerFocused","render")
    end if
    label = m.top.findNode("label")
    label.text = Txt(item.title,Txt(item.name,"All"))
    label.font.size = 21
    chevron = m.top.findNode("chevron")
    chevron.visible = item.dropdown = true
    chevron.blendColor = "#A6A8AAFF"
    label.maxWidth = 216
    if chevron.visible then label.maxWidth = 192
    selected = item.selected = true
    owner = m.top.gridHasFocus
    active = owner and m.top.focusPercent > 0.5
    surface = m.top.findNode("surface")
    surface.blendColor = "#202224FF"
    label.color = "#A6A8AA"
    label.repeatCount = 0
    if selected
        surface.blendColor = "#303234FF"
        label.color = "#F5F5F5"
    end if
    if active
        surface.blendColor = "#F5F5F5FF"
        label.color = "#101112"
        chevron.blendColor = "#101112FF"
        label.repeatCount = -1
    end if
end sub
