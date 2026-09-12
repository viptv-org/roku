sub init()
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
    m.name.font.size = 22
    m.initial.text = ucase(left(label, 1))
    if Txt(item.action) = "newprofile" then m.initial.text = "+"
    avatar = AccountAvatarUrl(item.avatar_url)
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
end sub

sub avatarLoadChanged()
    loaded = m.avatar.loadStatus = "ready"
    m.avatar.visible = loaded
    m.fallback.visible = not loaded
    m.initial.visible = not loaded
end sub

sub renderFocus()
    if m.focusFrame = invalid then return
    owner = m.top.gridHasFocus
    focused = owner and m.top.focusPercent > 0.5
    m.focusFrame.opacity = 0
    m.name.repeatCount = 0
    m.name.color = "#A6A8AA"
    if focused
        m.focusFrame.opacity = 1
        m.name.color = "#F5F5F5"
        m.name.repeatCount = -1
    end if
end sub
