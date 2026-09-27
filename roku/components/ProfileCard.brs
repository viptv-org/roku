sub init()
    m.catalog = ParseJson(ReadAsciiFile("pkg:/data/avatar-catalog.json"))
    m.avatar = m.top.findNode("avatar")
    m.fallback = m.top.findNode("avatarFallback")
    m.initial = m.top.findNode("initial")
    m.name = m.top.findNode("name")
    m.focusFrame = m.top.findNode("focusFrame")
    m.avatar.observeField("loadStatus", "avatarLoadChanged")
end sub

sub render()
    item = m.top.itemContent
    if item = invalid then return
    if m.ownerItem <> invalid then m.ownerItem.unobserveField("uiOwnerFocused")
    m.ownerItem = item
    if item.hasField("uiOwnerFocused") then item.observeField("uiOwnerFocused","renderFocus")
    label = Txt(item.name, "Profile").trim()
    if label = "" then label = "Profile"
    m.name.text = label
    m.name.font.size = 19
    m.initial.text = ucase(left(label, 1))
    if Txt(item.action) = "newprofile" then m.initial.text = "+"
    avatar = AccountAvatarUrl(item.avatar_url)
    style = AccountAvatarStyle(item.avatar_style)
    choice = val(Txt(item.avatar_choice))
    if style <> "" and choice >= 1 and choice <= 48
        local = "pkg:/images/avatar-catalog/"+style+"-"+int(choice).toStr()+".png"
        for each category in m.catalog.categories
            if category.style = style
                if category.items = invalid
                    avatar = local
                else if choice <= category.items.count()
                    avatar = category.items[int(choice)-1].local
                end if
                exit for
            end if
        end for
    end if
    m.top.findNode("editBadge").visible = item.managing = true and Txt(item.action) <> "newprofile"
    m.top.findNode("addIcon").visible = Txt(item.action) = "newprofile"
    m.avatar.visible = avatar <> ""
    if avatar = ""
        m.avatar.uri = ""
        m.fallback.visible = true
        m.initial.visible = true
    else
        m.fallback.visible = true
        m.initial.visible = true
        m.avatar.uri = avatar
    end if
    renderFocus()
    if Txt(item.action) = "newprofile" then m.initial.visible = false
end sub

sub avatarLoadChanged()
    loaded = m.avatar.loadStatus = "ready"
    m.avatar.visible = loaded
    m.fallback.visible = true
    m.initial.visible = not loaded
    if m.top.itemContent <> invalid
        if Txt(m.top.itemContent.action) = "newprofile" then m.initial.visible = false
    end if
end sub

sub renderFocus()
    if m.focusFrame = invalid then return
    owner = m.top.gridHasFocus
    focused = owner and m.top.focusPercent > 0.5
    m.focusFrame.opacity = 0
    m.name.repeatCount = 0
    m.name.color = "#B6B4AF"
    if focused
        m.focusFrame.opacity = 1
        m.name.color = "#F4F2EE"
        m.name.repeatCount = -1
    end if
end sub
