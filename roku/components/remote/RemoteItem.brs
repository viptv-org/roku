sub init()
    for each id in ["tileBadgeGround","tileBadgeLabel","watchedBadge","resumeRemaining","resumeTrack","resumeFill","sourceAddon","sourceBest","sourceBestGround","historyMask","historyArt","episodeDescription","settingValue","settingChevron","settingTrack","settingThumb","ring","ground","art","artMask","initials","icon","progressGround","progress","label","detail","quality","format","rowPoster"]
        m[id] = m.top.findNode(id)
    end for
    m.art.observeField("loadStatus","artChanged")
end sub

sub render()
    c = m.top.itemContent
    if c = invalid then return
    m.top.findNode("surface").translation = [0,0]
    for each id in ["settingValue","settingChevron","settingTrack","settingThumb"]
        m[id].visible = false
    end for
    for each id in ["resumeRemaining","resumeTrack","resumeFill","sourceAddon","sourceBest","sourceBestGround"]
        m[id].visible = false
    end for
    m.label.height = 38
    m.label.maxLines = 1
    m.label.wrap = false
    m.detail.height = 32
    m.tileBadgeGround.uri = "pkg:/images/design/remote-tile-badge.9.png"
    m.tileBadgeGround.translation = [10,10]
    m.tileBadgeGround.height = 30
    m.tileBadgeLabel.translation = [20,10]
    m.tileBadgeLabel.height = 30
    m.tileBadgeLabel.font.size = 17
    m.tileBadgeGround.visible = false
    m.tileBadgeLabel.visible = false
    m.watchedBadge.visible = false
    m.historyMask.visible = false
    m.episodeDescription.visible = false
    m.label.visible = c.showLabels
    m.detail.visible = c.showLabels
    if m.entryTitle <> invalid then m.entryTitle.visible = false
    if m.entryDetail <> invalid then m.entryDetail.visible = false
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
    m.art.translation = [0,0]
    m.art.loadDisplayMode = "scaleToZoom"
    m.initials.font.uri = "pkg:/fonts/remote_onest_700.ttf"
    m.art.width = w
    m.art.height = imageHeight
    m.art.loadWidth = int(w)
    m.art.loadHeight = int(imageHeight)
    if RGet(c.wire,"homeSkeleton",false)
        m.art.uri = ""
        m.art.visible = false
        m.artMask.visible = false
        m.initials.visible = false
        m.label.visible = false
        m.detail.visible = false
        m.ground.uri = "pkg:/images/design/remote-wide-mask.png"
        m.ground.visible = true
        focusChanged()
        return
    end if
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
    m.label.horizAlign = "left"
    m.label.font.uri = "pkg:/fonts/remote_onest_600.ttf"
    m.detail.font.uri = "pkg:/fonts/remote_onest_400.ttf"
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
        m.label.translation = [0,imageHeight+14]
        m.label.font.size = 24
        m.label.height = 29
        m.detail.translation = [0,imageHeight+47]
        m.detail.height = 26
        m.ground.height = imageHeight
        m.ring.height = imageHeight+8
        m.label.width = w
        m.detail.width = w
        shape = "remote-wide"
        if imageHeight > w then shape = "remote-poster"
        if RObject(c.wire.profile) then shape = "remote-profile"
        if c.uiRole = "recommendation" then shape = "remote-recommendation"
        if c.uiRole = "episode" then shape = "remote-episode"
        m.artMask.maskUri = "pkg:/images/design/"+shape+"-mask.png"
        m.ground.uri = "pkg:/images/design/"+shape+"-mask.png"
        m.ring.uri = "pkg:/images/design/"+shape+"-focus.png"
        m.ring.translation = [0,0]
        m.ring.width = w
        m.ring.height = imageHeight
        if RObject(c.wire.profile)
            m.label.horizAlign = "center"
            m.detail.horizAlign = "center"
        end if
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
        if RGet(c,"uiButton",false) then centerButton(w,h,c)
    end if
    if RObject(c.wire.source)
        renderSource(c,w,h)
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
    if RGet(c.wire,"entryOption",false)
        m.top.findNode("surface").translation = [4,4]
        m.ground.uri = "pkg:/images/design/remote-entry-option-mask.png"
        m.ring.uri = "pkg:/images/design/remote-entry-option-focus.png"
        m.icon.translation = [32,34]
        m.icon.width = 32
        m.icon.height = 32
        m.label.translation = [90,17]
        m.label.font.uri = "pkg:/fonts/remote_onest_700.ttf"
        m.label.font.size = 30
        m.label.height = 36
        m.label.width = w-122
        m.detail.translation = [90,53]
        m.detail.font.uri = "pkg:/fonts/remote_onest_500.ttf"
        m.detail.font.size = 22
        m.detail.height = 30
        m.detail.width = w-122
        if c.description = "" then m.label.translation = [90,32]
        if m.entryTitle = invalid
            m.entryTitle = m.top.findNode("surface").createChild("RemoteTrackedLabel")
            m.entryDetail = m.top.findNode("surface").createChild("RemoteTrackedLabel")
            m.entryTitle.size = 30
            m.entryTitle.tracking = 0
            m.entryDetail.size = 22
            m.entryDetail.weight = "500"
            m.entryDetail.tracking = 0
        end if
        m.entryTitle.text = c.title
        m.entryTitle.translation = [90,15]
        if c.description = "" then m.entryTitle.translation = [90,30]
        m.entryDetail.translation = [90,52]
        m.entryDetail.text = c.description
        m.entryTitle.visible = true
        m.entryDetail.visible = true
        m.label.visible = false
        m.detail.visible = false
    end if
    if RGet(c.wire,"entrySignIn",false)
        m.ground.uri = "pkg:/images/design/remote-entry-signin-mask.png"
        m.ring.uri = "pkg:/images/design/remote-entry-signin-focus.png"
        m.label.horizAlign = "center"
        m.label.translation = [0,20]
        m.label.width = w
        m.label.font.uri = "pkg:/fonts/remote_onest_700.ttf"
        m.label.font.size = 26
    end if
    if RGet(c.wire,"setting",false)
        m.ground.uri = "pkg:/images/design/remote-settings-row.png"
        m.label.translation = [28,32]
        m.label.height = 32
        m.label.width = w-560
        m.detail.translation = [28,53]
        m.detail.font.uri = "pkg:/fonts/remote_onest_500.ttf"
        m.detail.font.size = 20
        m.detail.width = w-152
        if c.description <> "" then m.label.translation = [28,17]
        if RGet(c.wire,"toggle",false)
            m.label.width = w-152
            m.settingTrack.visible = true
            m.settingThumb.visible = true
            m.settingTrack.translation = [w-96,29]
            m.settingTrack.blendColor = "#494949"
            m.settingThumb.blendColor = "#F4F2EE"
            m.settingThumb.translation = [w-92,33]
            if c.wire.checked
                m.settingTrack.blendColor = "#F5C542"
                m.settingThumb.blendColor = "#0B0B0C"
                m.settingThumb.translation = [w-62,33]
            end if
        else
            m.settingValue.visible = true
            m.settingValue.text = c.wire.settingValue
            m.settingValue.translation = [w-480,33]
            m.settingValue.width = 420
            m.settingChevron.visible = true
            m.settingChevron.translation = [w-52,36]
        end if
    end if
    if c.uiRole = "episode"
        m.label.translation = [0,266]
        m.label.font.size = 24
        m.label.height = 30
        episode = RGet(c.wire.identity,"episode")
        if RObject(episode) and RGet(episode,"episode") <> invalid then m.label.text = episode.episode.toStr()+". "+c.title
        m.detail.translation = [0,299]
        m.detail.font.size = 20
        m.detail.height = 26
        m.initials.text = c.title
        m.initials.font.size = 22
        m.episodeDescription.visible = RText(c.wire.description) <> ""
        m.episodeDescription.text = RText(c.wire.description)
        m.episodeDescription.translation = [0,333]
        m.episodeDescription.width = w
        m.episodeDescription.height = 56
    end if
    if RGet(c.wire,"history",false)
        m.top.findNode("surface").translation = [4,4]
        m.ground.uri = "pkg:/images/design/remote-history-row.png"
        m.ring.uri = "pkg:/images/design/remote-history-focus.png"
        m.historyMask.visible = true
        m.historyArt.uri = c.HDPosterUrl
        m.label.translation = [268,37]
        m.label.font.size = 28
        m.label.height = 34
        m.label.width = w-284
        m.detail.translation = [268,77]
        m.detail.font.size = 22
        m.detail.height = 28
        m.detail.width = w-284
    end if
    if RGet(c.wire,"menu",false)
        ' DropdownMenu row: 48px tall, 14px medium text, 12px inset. The flat
        ' ground is the row highlight over the popup artwork, not a card chip.
        m.ground.uri = "pkg:/images/design/remote-white.png"
        m.label.font.uri = "pkg:/fonts/remote_onest_500.ttf"
        m.label.font.size = 14
        m.label.wrap = false
        m.label.maxLines = 1
        m.label.translation = [12,10]
        m.label.height = 28
        m.label.vertAlign = "center"
        m.label.width = w-24
        m.detail.visible = false
    end if
    if RGet(c.wire,"homeRowRetry",false)
        m.ground.uri = "pkg:/images/design/remote-source-row.9.png"
        m.ring.uri = "pkg:/images/design/remote-source-row.9.png"
        m.label.translation = [28,24]
        m.label.width = w-56
        m.label.height = 30
        m.label.font.uri = "pkg:/fonts/remote_onest_700.ttf"
        m.label.font.size = 22
        m.detail.translation = [28,64]
        m.detail.width = w-56
        m.detail.height = 52
        m.detail.font.uri = "pkg:/fonts/remote_onest_400.ttf"
        m.detail.font.size = 19
        m.detail.maxLines = 2
        m.detail.wrap = true
        m.rowPoster.visible = false
        m.icon.visible = false
    end if
    if RGet(c.wire,"heroAction",false) and RText(c.wire.remainingLabel) <> ""
        m.resumeRemaining.text = c.wire.remainingLabel
        m.resumeRemaining.visible = true
        measure = CreateObject("roSGNode","Label")
        measure.font = m.label.font
        measure.text = c.title
        m.resumeRemaining.translation = [64+measure.boundingRect().width+54,20]
    end if
    if RGet(c.wire,"heroAction",false) and c.wire.resumeProgress <> invalid
        fraction = c.wire.resumeProgress
        if fraction >= 0 and fraction <= 1
            m.resumeTrack.translation = [28,h-16]
            m.resumeTrack.width = w-56
            m.resumeFill.translation = [28,h-16]
            m.resumeFill.width = (w-56)*fraction
            m.resumeTrack.visible = true
            m.resumeFill.visible = true
        end if
    end if
    badge = RGet(RGet(c.wire,"view",{}),"tile_badge")
    if imageHeight > 0 and RObject(badge)
        if RText(badge.role) = "watched"
            m.watchedBadge.translation = [w-44,10]
            m.watchedBadge.visible = true
        else if RText(badge.label) <> ""
            m.tileBadgeLabel.text = badge.label
            m.tileBadgeLabel.width = 0
            m.tileBadgeGround.width = m.tileBadgeLabel.boundingRect().width+20
            if m.tileBadgeGround.width > w-20
                m.tileBadgeGround.width = w-20
                m.tileBadgeLabel.width = w-40
            end if
            m.tileBadgeGround.blendColor = "#0B0B0CCC"
            m.tileBadgeLabel.color = "#F4F2EE"
            if RText(badge.role) = "new_episodes"
                m.tileBadgeGround.blendColor = "#F4F2EE"
                m.tileBadgeLabel.color = "#0B0B0C"
            end if
            m.tileBadgeGround.visible = true
            m.tileBadgeLabel.visible = true
        end if
    end if
    if c.uiRole = "logo"
        m.artMask.maskUri = "pkg:/images/design/remote-search-channel-mask.png"
        m.ground.uri = "pkg:/images/design/remote-search-channel-ground.png"
        m.ring.uri = "pkg:/images/design/remote-search-channel-focus.png"
        m.tileBadgeGround.uri = "pkg:/images/design/remote-search-channel-live.png"
        m.tileBadgeGround.translation = [12,12]
        m.tileBadgeGround.width = 60
        m.tileBadgeGround.height = 28
        m.tileBadgeGround.blendColor = "#E5484D"
        m.tileBadgeGround.visible = true
        m.tileBadgeLabel.translation = [21,12]
        m.tileBadgeLabel.width = 42
        m.tileBadgeLabel.height = 28
        m.tileBadgeLabel.text = "LIVE"
        m.tileBadgeLabel.color = "#FFFFFF"
        m.tileBadgeLabel.visible = true
        m.art.translation = [108,30]
        m.art.width = 140
        m.art.height = 140
        m.art.loadWidth = 140
        m.art.loadHeight = 140
        m.art.loadDisplayMode = "scaleToFit"
        m.initials.text = c.title
        m.initials.font.uri = "pkg:/fonts/remote_bricolage_800.ttf"
        m.initials.font.size = 56
        m.label.translation = [0,212]
        m.label.font.size = 22
        m.detail.translation = [0,242]
        m.detail.font.size = 20
        m.detail.text = RText(c.wire.subtitle)
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

' Source rows are the one list row whose text is provider free text, so they
' get a taller fixed row: two lines of release title above one line of technical
' detail. The row height is owned by the list (RemoteScene's source item size);
' this draws inside it and never changes it.
sub renderSource(c as object, w as integer, h as integer)
    presentation = RGet(c.wire.source,"view",{})
    m.ground.uri = "pkg:/images/design/remote-source-row.9.png"
    m.quality.visible = true
    m.quality.text = RRenderable(RText(presentation.quality_label))
    m.format.visible = RText(presentation.format_label) <> ""
    m.format.text = RRenderable(RText(presentation.format_label))
    ' Quality stacks over format in a fixed 116px column.
    qualityTop = int((h-62)/2)
    m.quality.translation = [28,qualityTop]
    m.format.translation = [28,qualityTop+36]
    ' Text is assigned after its box, so a wrapped title is laid out against the
    ' height it is allowed to use instead of the previous row's one-line box.
    m.label.font.size = 26
    m.label.wrap = true
    m.label.maxLines = 2
    m.detail.font.size = 22
    m.detail.wrap = false
    m.detail.maxLines = 1
    addon = RRenderable(RText(presentation.addon_label))
    m.sourceAddon.visible = addon <> ""
    m.sourceAddon.text = addon
    m.sourceAddon.width = 0
    addonWidth = int(m.sourceAddon.boundingRect().width)+2
    if addonWidth > 170 then addonWidth = 170
    m.sourceAddon.width = addonWidth
    m.sourceAddon.translation = [w-28-addonWidth,int((h-28)/2)]
    ' Release title and badge share the top line; the detail keeps the full
    ' width under them. Nothing is reserved for a column the row does not show.
    columnRight = w-28
    if addon <> "" then columnRight -= addonWidth+20
    badgeWidth = 0
    if RGet(c.wire,"bestMatch",false)
        badgeWidth = m.sourceBest.width+20
        m.sourceBestGround.translation = [columnRight-badgeWidth,23]
        m.sourceBestGround.width = badgeWidth
        m.sourceBest.translation = [columnRight-badgeWidth+10,27]
        m.sourceBest.visible = true
        m.sourceBestGround.visible = true
    end if
    textWidth = columnRight-164
    if badgeWidth > 0 then textWidth -= badgeWidth+16
    if textWidth < 120 then textWidth = 120
    ' A 26px line occupies 40px of the panel's line box, so two lines need 84.
    ' The title box is bottom-aligned: a one-line release name still sits
    ' directly above its technical line instead of floating away from it.
    m.label.vertAlign = "bottom"
    m.label.translation = [164,8]
    m.label.width = textWidth
    m.label.height = 84
    m.detail.translation = [164,92]
    m.detail.width = columnRight-164
    m.detail.height = 30
    m.label.text = RRenderable(c.title)
    m.detail.text = RRenderable(c.description)
    ' A source with no release text keeps its title in the middle of the row
    ' instead of leaving a hole under it.
    if RText(m.detail.text) = ""
        m.label.vertAlign = "center"
        m.label.translation = [164,0]
        m.label.height = h
    end if
end sub

' True when the nearest focusable ancestor (the list, grid or action bar that owns
' this item) is in the focus chain.
function ROwnerFocused() as boolean
    node = m.top.getParent()
    for i = 0 to 6
        if node = invalid then return false
        if node.hasField("focusable") and node.focusable = true then return node.isInFocusChain()
        node = node.getParent()
    end for
    return false
end function

' Buttons centre their icon and label as one unit, so an action row reads as a
' single control instead of text pinned to one edge.
sub centerButton(w as integer, h as integer, c as object)
    m.label.horizAlign = "left"
    textW = 0
    if RText(c.title) <> ""
        measure = CreateObject("roSGNode","Label")
        measure.font = m.label.font
        measure.text = c.title
        measure.width = 0
        textW = int(measure.boundingRect().width)
    end if
    gap = 10
    iconW = 0
    if m.icon.visible
        iconW = 24
        m.icon.width = 24
        m.icon.height = 24
    end if
    total = iconW+textW
    if iconW > 0 and textW > 0 then total += gap
    start = int((w-total)/2)
    if start < 12 then start = 12
    if iconW > 0
        m.icon.translation = [start,int((h-24)/2)]
        start += iconW+gap
    end if
    m.label.translation = [start,int((h-38)/2)]
    m.label.width = textW+4
end sub

sub focusChanged()
    if m.ring = invalid or m.top.itemContent = invalid then return
    ' focusPercent is the only field every Roku list node drives. rowFocusPercent
    ' is not set by MarkupGrid/MarkupList item components and is not reported
    ' reliably by RowList on device, so requiring it hid the focus ring on every
    ' card. Owner-focus still removes the phantom ring from a list that has never
    ' held focus.
    active = m.top.focusPercent > 0.5 and ROwnerFocused()
    if m.top.itemContent.focusedCaptions
        m.label.visible = m.top.itemContent.showLabels and active
        m.detail.visible = m.top.itemContent.showLabels and active
    end if
    m.ring.blendColor = "#FFFFFFFF"
    m.ring.visible = active and (m.top.itemContent.imageHeight > 0 or RGet(m.top.itemContent.wire,"entryOption",false) or RGet(m.top.itemContent.wire,"entrySignIn",false) or RGet(m.top.itemContent.wire,"history",false))
    if RGet(m.top.itemContent.wire,"ring",true) = false then m.ring.visible = false
    m.ground.blendColor = "#212124FF"
    if m.top.itemContent.uiRole = "logo" then m.ground.blendColor = "#FFFFFFFF"
    if RObject(m.top.itemContent.wire.source) then m.ground.blendColor = "#222222FF"
    if RGet(m.top.itemContent.wire,"setting",false) then m.ground.blendColor = "#191919FF"
    if RGet(m.top.itemContent.wire,"entryOption",false) then m.ground.blendColor = "#FFFFFF12"
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
    if RGet(m.top.itemContent.wire,"menu",false)
        m.label.color = "#F4F2EE"
        m.ground.blendColor = "#FFFFFF00"
        if active then m.ground.blendColor = "#FFFFFF1F"
        m.ring.visible = false
    end if
    m.resumeRemaining.color = m.label.color
    m.resumeTrack.color = m.label.color
    m.resumeFill.color = m.label.color
    m.sourceAddon.color = m.detail.color
    m.sourceBestGround.blendColor = m.label.color
    m.sourceBest.blendColor = "#0B0B0C"
    if active then m.sourceBest.blendColor = "#F4F2EE"
    m.settingValue.color = m.detail.color
    m.settingChevron.uri = "pkg:/images/lucide/remote-chevron-secondary.png"
    if active then m.settingChevron.uri = "pkg:/images/lucide/remote-chevron-focus.png"
    if m.entryTitle <> invalid then m.entryTitle.textColor = m.label.color
    if m.entryDetail <> invalid then m.entryDetail.textColor = m.detail.color
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
