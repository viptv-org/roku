sub init()
    m.provider = m.top.findNode("provider")
    m.description = m.top.findNode("description")
    m.badges = m.top.findNode("badges")
    m.surface = m.top.findNode("surface")
    m.provider.font.size = 22
    m.description.font.size = 19
    m.badges.font.size = 16
end sub
sub contentChanged()
    if m.observedItem <> invalid then m.observedItem.unobserveField("sourceBadges")
    item = m.top.itemContent
    m.observedItem = item
    if item = invalid then return
    if item.hasField("sourceBadges") then item.observeField("sourceBadges","badgesChanged")
    m.provider.text = item.title
    m.description.text = item.description
    m.badges.text = ""
    if item.hasField("sourceBadges") then m.badges.text = item.sourceBadges
    focusChanged()
end sub
sub focusChanged()
    if m.provider = invalid then return
    active = m.top.listHasFocus and m.top.focusPercent > 0.5
    m.surface.blendColor = "#202224FF"
    m.provider.color = "#F5F5F5"
    m.description.color = "#A6A8AA"
    m.badges.color = "#C5C6C7"
    if active
        m.surface.blendColor = "#F5F5F5FF"
        m.provider.color = "#101112"
        m.description.color = "#393B3D"
        m.badges.color = "#393B3D"
    end if
end sub

sub badgesChanged()
    if m.top.itemContent <> invalid then m.badges.text = m.top.itemContent.sourceBadges
end sub
