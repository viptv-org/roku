sub init()
    m.avatar = m.top.findNode("avatar")
    m.avatar.observeField("loadStatus","render")
end sub
sub contentChanged()
    render()
end sub
sub render()
    item = m.top.itemContent
    if item = invalid or m.avatar = invalid then return
    profile = item.isProfile = true
    active = m.top.listHasFocus and m.top.focusPercent > 0.5
    icon = m.top.findNode("icon")
    icon.visible = not profile
    name = item.title
    if profile
        name = Txt(item.profileName,"Profile")
        m.top.findNode("initial").text = ucase(left(name,1))
        uri = Txt(item.avatarUrl)
        if m.avatar.uri <> uri then m.avatar.uri = uri
    else
        icons = {Home:"home",Discover:"discover","Live TV":"live","My List":"list",Search:"search",Settings:"settings"}
        key = Txt(icons[item.title],"home")
        variant = "secondary"
        if active then variant = "focus"
        icon.uri = "pkg:/images/lucide/"+key+"-"+variant+".png"
    end if
    ready = profile and m.avatar.loadStatus = "ready" and m.avatar.uri <> ""
    m.avatar.visible = ready
    m.top.findNode("avatarFallback").visible = profile and not ready
    m.top.findNode("initial").visible = profile and not ready
    m.top.findNode("surface").visible = active
    width = 42
    if m.top.expanded then width = 293
    m.top.findNode("surface").width = width
    label = m.top.findNode("label")
    label.text = name
    label.visible = m.top.expanded
    label.color = "#F4F2EE"
    if active then label.color = "#111113"
end sub
