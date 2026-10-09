sub init()
    for each id in ["poster","artworkMask","title","subtitle","fallback","focusFrame","progressTrack","progressFill","surface"]
        m[id] = m.top.findNode(id)
    end for
    m.poster.observeField("loadStatus","artLoaded")
    m.title.font.size = 16
    m.subtitle.font.size = 13
    if m.top.itemContent <> invalid then contentChanged()
end sub

sub contentChanged()
    if m.poster = invalid or m.artworkMask = invalid then return
    item = m.top.itemContent
    if item = invalid then return
    changed = true
    if m.observedItem <> invalid then changed = not m.observedItem.isSameNode(item)
    if changed
        if m.observedItem <> invalid
            for each field in ["uiOwnerFocused","HDPosterUrl","artworkKind","subtitle"]
                m.observedItem.unobserveField(field)
            end for
        end if
        m.observedItem = item
        item.observeField("uiOwnerFocused","focusChanged")
        item.observeField("HDPosterUrl","contentChanged")
        item.observeField("artworkKind","contentChanged")
        item.observeField("subtitle","contentChanged")
    end if
    w = 213
    h = 120
    if item.hasField("uiWidth") and item.uiWidth = 240
        w = 240
        h = 135
        ' Grid rows supply their cell height; the artwork shrinks so the
        ' title/subtitle labels stay inside the cell instead of colliding
        ' with the next row.
        if item.hasField("uiHeight") and item.uiHeight = 176 then h = 124
    end if
    shape = "card"
    if w = 240 then shape = "episode"
    m.artworkMask.uri = "pkg:/images/design/"+shape+"-corners.png"
    m.focusFrame.uri = "pkg:/images/design/"+shape+"-focus.png"
    for each id in ["surface","artworkMask","focusFrame"]
        m[id].width = w
        m[id].height = h
    end for
    m.title.translation = [0,h+12]
    m.subtitle.translation = [0,h+34]
    m.title.maxWidth = w
    m.subtitle.maxWidth = w
    m.fallback.width = w-20
    m.fallback.height = h-20
    m.progressTrack.translation = [9,h-12]
    m.progressFill.translation = [9,h-12]
    m.progressTrack.width = w-18
    skeleton = item.hasField("uiSkeleton") and item.uiSkeleton
    m.top.findNode("skeletonTitle").visible = skeleton
    m.top.findNode("skeletonMeta").visible = skeleton
    m.title.visible = not skeleton
    m.subtitle.visible = not skeleton
    m.title.text = item.title
    m.subtitle.text = item.subtitle
    if not item.hasField("artState") then item.addFields({artState:"none"})
    m.poster.visible = false
    m.fallback.text = item.title
    m.fallback.visible = true
    m.poster.translation = [0,0]
    m.poster.width = w
    m.poster.height = h
    m.poster.loadDisplayMode = "scaleToZoom"
    m.poster.loadWidth = w
    m.poster.loadHeight = h
    if item.artworkKind = "portrait"
        ' Preserve the source aspect ratio, then crop rather than stretch.
        ' The complete poster remains available on the detail page.
        m.poster.loadWidth = w
        m.poster.loadHeight = int(w*1.5)
    else if item.artworkKind = "logo"
        m.poster.translation = [27,13]
        m.poster.width = 159
        m.poster.height = 94
        m.poster.loadDisplayMode = "scaleToFit"
        m.poster.loadWidth = 176
        m.poster.loadHeight = 100
    end if
    uri = ImageUrl(item.HDPosterUrl,int(m.poster.width),int(m.poster.height),false,item.artworkKind = "logo")
    if m.artOriginal <> item.HDPosterUrl then m.artRetried = false
    m.artOriginal = item.HDPosterUrl
    if m.artRetried = true then uri = m.artOriginal
    if m.poster.uri <> uri
        item.artState = "loading"
        m.poster.uri = uri
    end if
    artLoaded()
    fraction = -1.0
    if item.progressFraction <> invalid then fraction = item.progressFraction
    m.progressTrack.visible = fraction >= 0
    m.progressFill.visible = fraction > 0
    if fraction > 1 then fraction = 1
    if fraction < 0 then fraction = 0
    fillWidth = (w-18)*fraction
    ' Keep a rounded dot visible for very small nonzero progress.
    if fillWidth < 6 then fillWidth = 6
    m.progressFill.width = fillWidth
    focusChanged()
end sub

sub focusChanged()
    if m.title = invalid then return
    ' Roku supplies different ownership fields for RowList and MarkupGrid.
    owner = m.top.rowListHasFocus or m.top.gridHasFocus
    active = owner and m.top.focusPercent > 0.5 and m.top.rowFocusPercent > 0.5
    m.focusFrame.visible = active
    m.title.repeatCount = 0
    m.subtitle.repeatCount = 0
    m.title.color = "#F4F2EE"
    m.subtitle.color = "#B6B4AF"
    if active
        m.title.color = "#FFFFFF"
        m.subtitle.color = "#DAD8D3"
    end if
end sub

sub artLoaded()
    item = m.top.itemContent
    if item = invalid then return
    if not item.hasField("artState") then item.addFields({artState:"none"})
    state = m.poster.loadStatus
    if state = "failed" and m.poster.uri <> m.artOriginal and m.artRetried <> true
        m.artRetried = true
        m.poster.uri = m.artOriginal
        item.artState = "loading"
        return
    end if
    item.artState = state
    ready = state = "ready" and m.poster.uri <> ""
    m.poster.visible = ready
    m.fallback.visible = not ready and not (item.hasField("uiSkeleton") and item.uiSkeleton)
end sub
