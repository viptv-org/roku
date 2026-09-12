sub render()
    item = m.top.itemContent
    if item = invalid then return
    if m.ownerItem <> invalid then m.ownerItem.unobserveField("uiOwnerFocused")
    m.ownerItem = item
    if item.hasField("uiOwnerFocused") then item.observeField("uiOwnerFocused","renderFocus")
    width = 536
    height = 56
    if item.hasField("uiWidth") then width = item.uiWidth
    if item.hasField("uiHeight") then height = item.uiHeight
    m.top.findNode("surface").width = width
    m.top.findNode("surface").height = height
    label = m.top.findNode("label")
    label.width = width
    label.height = height
    label.translation = [0,0]
    label.font.size = 22
    label.text = item.title
    renderFocus()
end sub

sub renderFocus()
    owner = m.top.listHasFocus or m.top.gridHasFocus
    active = owner and m.top.focusPercent > 0.5
    surface = m.top.findNode("surface")
    label = m.top.findNode("label")
    surface.blendColor = "#202224FF"
    label.color = "#F5F5F5"
    if active
        surface.blendColor = "#F5F5F5FF"
        label.color = "#101112"
    end if
end sub
