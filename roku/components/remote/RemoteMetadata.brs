sub init()
    m.items = m.top.findNode("items")
    m.font = CreateObject("roSGNode","Font")
    m.font.uri = "pkg:/fonts/remote_onest_500.ttf"
    m.font.size = 24
    m.badgeFont = CreateObject("roSGNode","Font")
    m.badgeFont.uri = "pkg:/fonts/remote_onest_700.ttf"
    m.badgeFont.size = 18
end sub
sub render()
    m.items.removeChildrenIndex(m.items.getChildCount(),0)
    parts = RArray(m.top.parts)
    x = 0
    for i = 0 to parts.count()-1
        if i > 0
            dot = m.items.createChild("Label")
            dot.font = m.font
            dot.text = "·"
            dot.color = "#B6B4AF"
            dot.height = 32
            dot.translation = [x+12,0]
            x += dot.boundingRect().width+24
        end if
        label = m.items.createChild("Label")
        label.font = m.font
        label.text = RText(parts[i])
        label.color = "#D6D4CF"
        label.height = 32
        label.translation = [x,0]
        x += label.boundingRect().width
    end for
    if parts.count() > 0 then x += 28
    for each badge in RArray(m.top.badges)
        group = m.items.createChild("Group")
        group.translation = [x,0]
        outline = group.createChild("Poster")
        outline.uri = "pkg:/images/design/remote-metadata-badge.9.png"
        outline.height = 30
        outline.blendColor = "#FFFFFF8C"
        label = group.createChild("Label")
        label.font = m.badgeFont
        label.text = RText(RGet(badge,"label"))
        label.height = 30
        label.vertAlign = "center"
        label.color = "#D6D4CF"
        label.translation = [8,0]
        outline.width = label.boundingRect().width+16
        x += outline.width+12
    end for
end sub
