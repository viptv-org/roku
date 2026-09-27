sub render()
    item = m.top.itemContent
    if item = invalid then return
    if m.ownerItem <> invalid then m.ownerItem.unobserveField("uiOwnerFocused")
    m.ownerItem = item
    if item.hasField("uiOwnerFocused") then item.observeField("uiOwnerFocused","renderFocus")
    width = 536
    height = 54
    if item.hasField("uiWidth") then width = item.uiWidth
    if item.hasField("uiHeight") then height = item.uiHeight
    m.top.findNode("surface").width = width
    m.top.findNode("surface").height = height
    frame = m.top.findNode("focusFrame")
    frame.width = width+4
    frame.height = height+4
    label = m.top.findNode("label")
    label.width = width
    label.height = height
    label.translation = [0,0]
    label.horizAlign = "center"
    label.font.size = 17
    m.top.findNode("surface").uri = "pkg:/images/design/pill.9.png"
    frame.uri = "pkg:/images/design/pill-focus.9.png"
    if height <= 40
        label.font.size = 15
        m.top.findNode("surface").uri = "pkg:/images/design/pill-small.9.png"
        frame.uri = "pkg:/images/design/pill-small-focus.9.png"
    end if
    label.text = item.title
    label.visible = item.title <> ""
    names = {"Switch profile":"profile","Manage profiles":"settings","About VIPTV":"info","Addons":"addons","Sign out":"exit","Done":"check","More info":"info","Choose source":"source","My List":"plus","Add to My List":"plus","Delete profile":"delete"}
    m.iconName = Txt(names[item.title])
    if item.hasField("uiIcon") then m.iconName = item.uiIcon
    for each prefix in ["Play","Resume","Watch"]
        if left(item.title,len(prefix)) = prefix then m.iconName = "play"
    end for
    icon = m.top.findNode("icon")
    icon.visible = m.iconName <> ""
    icon.translation = [16,int((height-19)/2)]
    if icon.visible
        label.translation = [36,0]
        label.width = width-48
        if item.title = "" then icon.translation = [int((width-19)/2),int((height-19)/2)]
    end if
    if item.hasField("uiField") and item.uiField = true
        m.iconName = "pencil"
        icon.visible = true
        icon.translation = [width-36,int((height-19)/2)]
        label.translation = [20,0]
        label.width = width-62
        label.horizAlign = "left"
        label.font.size = 25
    end if
    m.isRow = width >= 400 and not (item.hasField("uiField") and item.uiField = true)
    if m.isRow
        m.top.findNode("surface").uri = "pkg:/images/design/row.9.png"
        label.font.size = 19
        label.horizAlign = "left"
        label.translation = [20,0]
        label.width = width-40
        if icon.visible
            label.translation = [52,0]
            label.width = width-72
        end if
    end if
    renderFocus()
end sub

sub renderFocus()
    item = m.top.itemContent
    if item = invalid then return
    active = (m.top.listHasFocus or m.top.gridHasFocus) and m.top.focusPercent > 0.5
    surface = m.top.findNode("surface")
    label = m.top.findNode("label")
    surface.blendColor = "#2A2A2EFF"
    label.color = "#F4F2EE"
    variant = "primary"
    m.top.findNode("focusFrame").visible = active and m.isRow <> true
    if active
        surface.blendColor = "#F4F2EEFF"
        label.color = "#111113"
        variant = "focus"
    end if
    if left(item.title,6) = "Resume"
        surface.blendColor = "#F5C542FF"
        label.color = "#111113"
        variant = "focus"
    end if
    if item.title = "Delete profile"
        label.color = "#FF8A7E"
        if active then label.color = "#B42318"
    end if
    if m.iconName <> invalid and m.iconName <> "" then m.top.findNode("icon").uri = "pkg:/images/lucide/"+m.iconName+"-"+variant+".png"
end sub
