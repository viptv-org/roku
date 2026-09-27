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
    label.font.size = 15
    chevron = m.top.findNode("chevron")
    chevron.visible = item.dropdown = true
    chevron.blendColor = "#B6B4AFFF"
    label.maxWidth = 208
    if chevron.visible then label.maxWidth = 186
    selected = item.selected = true
    owner = m.top.gridHasFocus
    active = owner and m.top.focusPercent > 0.5
    surface = m.top.findNode("surface")
    surface.blendColor = "#212124FF"
    label.color = "#B6B4AF"
    label.repeatCount = 0
    if selected
        surface.blendColor = "#34343AFF"
        label.color = "#F4F2EE"
    end if
    if active
        surface.blendColor = "#F4F2EEFF"
        label.color = "#0B0B0C"
        chevron.blendColor = "#0B0B0CFF"
        label.repeatCount = -1
    end if
end sub
