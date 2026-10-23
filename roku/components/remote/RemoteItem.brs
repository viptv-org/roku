sub init()
    for each id in ["ring","ground","art","artMask","initials","icon","progressGround","progress","label","detail","quality","format","rowPoster"]
        m[id] = m.top.findNode(id)
    end for
    m.art.observeField("loadStatus","artChanged")
end sub

sub render()
    c = m.top.itemContent
    if c = invalid then return
    w = c.uiWidth
    h = c.uiHeight
    imageHeight = c.imageHeight
    m.ground.width = w
    m.ground.height = h
    m.ring.translation = [-4,-4]
    m.ring.width = w+8
    m.ring.height = h+8
    m.art.visible = imageHeight > 0
    m.artMask.visible = imageHeight > 0
    m.artMask.maskSize = [w,imageHeight]
    m.artMask.maskUri = "pkg:/images/design/remote-wide-mask.png"
    if imageHeight > w then m.artMask.maskUri = "pkg:/images/design/remote-poster-mask.png"
    m.art.width = w
    m.art.height = imageHeight
    m.art.loadWidth = int(w)
    m.art.loadHeight = int(imageHeight)
    m.art.uri = c.HDPosterUrl
    m.initials.width = w
    m.initials.height = imageHeight
    m.initials.text = ucase(left(c.title,1))
    m.initials.font.size = int(w/4)
    artChanged()
    m.label.text = c.title
    m.detail.text = c.description
    m.label.width = w-32
    m.detail.width = w-32
    m.label.font.size = 26
    m.detail.font.size = 20
    m.quality.visible = false
    m.quality.translation = [28,20]
    m.format.visible = false
    m.rowPoster.visible = false
    m.icon.visible = RText(c.wire.icon) <> ""
    m.ground.uri = "pkg:/images/ui-round-fill.9.png"
    if m.icon.visible and w = h then m.ground.uri = "pkg:/images/design/circle.png"
    m.icon.translation = [int((w-30)/2),int((h-30)/2)]
    if m.icon.visible then m.icon.uri = "pkg:/images/lucide/"+c.wire.icon+"-primary.png"
    if imageHeight > 0
        m.label.translation = [0,imageHeight+12]
        m.detail.translation = [0,imageHeight+48]
        m.ground.height = imageHeight
        m.ring.height = imageHeight+8
        m.label.width = w
        m.detail.width = w
        shape = "remote-wide"
        if imageHeight > w then shape = "remote-poster"
        if RObject(c.wire.profile) then shape = "remote-profile"
        m.artMask.maskUri = "pkg:/images/design/"+shape+"-mask.png"
        m.ring.uri = "pkg:/images/design/"+shape+"-focus.png"
        m.ring.translation = [0,0]
        m.ring.width = w
        m.ring.height = imageHeight
    else
        m.label.translation = [24,12]
        m.detail.translation = [24,50]
        if h <= 76 then m.label.translation = [24,int((h-38)/2)]
        if c.description = "" then m.label.translation = [24,int((h-38)/2)]
        if m.icon.visible and c.title <> ""
            m.icon.translation = [28,int((h-24)/2)]
            m.icon.width = 24
            m.icon.height = 24
            m.label.translation = [64,int((h-38)/2)]
            m.label.width = w-80
        end if
    end if
    if RObject(c.wire.source)
        presentation = RGet(c.wire.source,"presentation",{})
        m.quality.visible = true
        m.quality.text = RText(presentation.quality,"—")
        m.format.visible = true
        m.format.text = RText(presentation.container,RText(presentation.delivery_format))
        m.label.translation = [164,20]
        m.label.width = w-192
        m.label.font.size = 28
        m.detail.translation = [164,60]
        m.detail.width = w-192
        m.detail.font.size = 22
    end if
    if RGet(c.wire,"sidebar",false)
        m.icon.translation = [24,22]
        m.icon.width = 28
        m.icon.height = 28
        m.label.translation = [70,17]
        m.label.width = w-94
    end if
    if RObject(c.wire.episode)
        m.rowPoster.visible = true
        m.rowPoster.uri = RText(c.wire.episode.landscape)
        m.rowPoster.translation = [24,18]
        m.rowPoster.width = 192
        m.rowPoster.height = 108
        m.rowPoster.loadWidth = 192
        m.rowPoster.loadHeight = 108
        m.label.translation = [240,30]
        m.label.width = w-264
        m.detail.translation = [240,76]
        m.detail.width = w-264
    end if
    if RText(c.wire.calendarTime) <> ""
        m.quality.visible = true
        m.quality.translation = [28,48]
        m.quality.text = c.wire.calendarTime
        m.rowPoster.visible = true
        m.rowPoster.uri = RText(c.wire.poster)
        m.label.translation = [276,28]
        m.label.width = w-304
        m.label.font.size = 30
        m.detail.translation = [276,70]
        m.detail.width = w-304
        m.detail.font.size = 24
    end if
    p = c.progressFraction
    m.progress.visible = imageHeight > 0 and p > 0
    m.progressGround.visible = m.progress.visible
    m.progress.translation = [0,imageHeight-4]
    m.progressGround.translation = [0,imageHeight-4]
    m.progress.width = w*p
    m.progressGround.width = w
    focusChanged()
end sub

sub focusChanged()
    if m.ring = invalid or m.top.itemContent = invalid then return
    active = (m.top.listHasFocus or m.top.gridHasFocus or m.top.rowListHasFocus) and m.top.focusPercent > 0.5 and m.top.rowFocusPercent > 0.5
    m.ring.visible = active and m.top.itemContent.imageHeight > 0
    if RGet(m.top.itemContent.wire,"ring",true) = false then m.ring.visible = false
    m.ground.blendColor = "#212124FF"
    if RGet(m.top.itemContent.wire,"heroAction",false) then m.ground.blendColor = "#F4F2EE29"
    if RGet(m.top.itemContent.wire,"sidebar",false) then m.ground.blendColor = "#161618FF"
    if RGet(m.top.itemContent.wire,"selected",false) then m.ground.blendColor = "#333333FF"
    if RObject(m.top.itemContent.wire.profile)
        m.ground.blendColor = "#40766BFF"
        avatar = RText(m.top.itemContent.wire.profile.avatar_id)
        if avatar = "initial-pink" then m.ground.blendColor = "#C24E6BFF"
        if avatar = "initial-blue" then m.ground.blendColor = "#3E6B8AFF"
    end if
    m.label.color = "#F4F2EE"
    m.detail.color = "#B6B4AF"
    m.quality.color = "#F4F2EE"
    m.format.color = "#B6B4AF"
    if active and m.top.itemContent.imageHeight = 0
        m.ground.blendColor = "#F4F2EEFF"
        m.label.color = "#111113"
        m.detail.color = "#4A4945"
        m.quality.color = "#111113"
        m.format.color = "#4A4945"
    end if
    if m.icon.visible
        variant = "primary"
        if active then variant = "focus"
        m.icon.uri = "pkg:/images/lucide/"+m.top.itemContent.wire.icon+"-"+variant+".png"
    end if
end sub

sub artChanged()
    if m.initials = invalid or m.top.itemContent = invalid then return
    m.initials.visible = m.top.itemContent.imageHeight > 0 and (m.art.uri = "" or m.art.loadStatus = "failed")
end sub
