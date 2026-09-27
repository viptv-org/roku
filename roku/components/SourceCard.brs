sub init()
    m.provider = m.top.findNode("provider")
    m.description = m.top.findNode("description")
    m.badges = m.top.findNode("badges")
    m.surface = m.top.findNode("surface")
    m.provider.font.size = 17
    m.description.font.size = 13
    m.badges.font.size = 12
end sub
sub contentChanged()
    if m.provider = invalid then return
    if m.observedItem <> invalid then m.observedItem.unobserveField("sourceBadges")
    item = m.top.itemContent
    m.observedItem = item
    if item = invalid then return
    if item.hasField("sourceBadges") then item.observeField("sourceBadges","badgesChanged")
    quality = "Auto"
    matches = CreateObject("roRegex","(^|[^a-z0-9])(2160p|1080p|720p|480p|4K|SD)([^a-z0-9]|$)","i").match(item.title+" "+item.description)
    if matches.count() > 2 then quality = matches[2]
    m.top.findNode("quality").text = quality
    m.provider.text = item.title.replace(quality,"").trim()
    if right(m.provider.text,1) = "·" then m.provider.text = left(m.provider.text,len(m.provider.text)-1).trim()
    m.description.text = item.description
    m.badges.text = ""
    badgesChanged()
    focusChanged()
end sub
sub focusChanged()
    if m.provider = invalid then return
    active = m.top.listHasFocus and m.top.focusPercent > 0.5
    m.top.findNode("surface").focused = active
    m.surface.blendColor = "#212124FF"
    m.provider.color = "#F4F2EE"
    m.description.color = "#B6B4AF"
    m.badges.color = "#DAD8D3"
    m.top.findNode("quality").color = "#F4F2EE"
    m.top.findNode("qualitySurface").blendColor = "#34343AFF"
    m.top.findNode("playIcon").uri = "pkg:/images/lucide/play-primary.png"
    if active
        m.surface.blendColor = "#F4F2EEFF"
        m.provider.color = "#0B0B0C"
        m.description.color = "#4A4945"
        m.badges.color = "#4A4945"
        m.top.findNode("quality").color = "#111113"
        m.top.findNode("qualitySurface").blendColor = "#DAD8D3FF"
        m.top.findNode("playIcon").uri = "pkg:/images/lucide/play-focus.png"
    end if
end sub

sub badgesChanged()
    item = m.top.itemContent
    if item = invalid or m.badges = invalid then return
    values = []
    if item.hasField("sourceBadges")
        for each name in ["BEST MATCH","LAST PLAYED","LIKELY COMPATIBLE"]
            if instr(1,item.sourceBadges,name)>0 then values.push(name)
        end for
    end if
    m.badges.text = values.join(" · ")
end sub
