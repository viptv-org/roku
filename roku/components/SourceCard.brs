sub init()
    m.provider = m.top.findNode("provider")
    m.description = m.top.findNode("description")
    m.badges = m.top.findNode("badges")
    m.surface = m.top.findNode("surface")
    m.provider.font.size = 19
    m.description.font.size = 15
    m.badges.font.size = 13
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
    m.surface.blendColor = "#212124FF"
    m.provider.color = "#F4F2EE"
    m.description.color = "#B6B4AF"
    m.badges.color = "#DAD8D3"
    if active
        m.surface.blendColor = "#F4F2EEFF"
        m.provider.color = "#0B0B0C"
        m.description.color = "#4A4945"
        m.badges.color = "#4A4945"
    end if
end sub

sub badgesChanged()
    if m.top.itemContent <> invalid then m.badges.text = m.top.itemContent.sourceBadges
end sub
