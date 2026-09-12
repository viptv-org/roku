sub init()
    m.avatar = m.top.findNode("avatar")
    m.avatar.observeField("loadStatus","avatarLoaded")
end sub

sub contentChanged()
    render()
end sub

sub render()
    item = m.top.itemContent
    if item = invalid or m.avatar = invalid then return
    profile = item.isProfile = true
    icon = m.top.findNode("icon")
    m.avatar.visible = profile and m.avatar.loadStatus = "ready"
    m.top.findNode("avatarFallback").visible = profile and not m.avatar.visible
    m.top.findNode("initial").visible = profile and not m.avatar.visible
    icon.visible = not profile
    name = item.title
    if profile
        name = Txt(item.profileName)
        if name = "" then name = "Profile"
        m.top.findNode("initial").text = ucase(left(name,1))
        uri = Txt(item.avatarUrl)
        if m.avatar.uri <> uri then m.avatar.uri = uri
    else
        icons = {Home:"home",Discover:"discover","Live TV":"tv","My List":"list",Search:"search",Settings:"settings"}
        key = icons[item.title]
        if key = invalid then key = "home"
        icon.uri = "pkg:/images/ui-nav-" + key + ".png"
    end if
    active = m.top.listHasFocus and m.top.focusPercent > 0.5
    m.top.findNode("surface").visible = active
    m.top.findNode("surface").width = 60
    icon.blendColor = "#A6A8AAFF"
    if active then icon.blendColor = "#101112FF"
end sub

sub avatarLoaded()
    render()
end sub
