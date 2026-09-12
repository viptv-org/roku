sub init()
    for each id in ["poster","artworkMask","title","subtitle","fallback","focusFrame","progressTrack","progressFill","surface"]
        m[id] = m.top.findNode(id)
    end for
    m.poster.observeField("loadStatus","artLoaded")
    m.title.font.size = 21
    m.subtitle.font.size = 17
end sub

sub contentChanged()
    item = m.top.itemContent
    if item = invalid then return
    changed = true
    if m.observedItem <> invalid then changed = not m.observedItem.isSameNode(item)
    if changed
        if m.observedItem <> invalid
            for each field in ["uiOwnerFocused","HDPosterUrl","artworkKind"]
                m.observedItem.unobserveField(field)
            end for
        end if
        m.observedItem = item
        item.observeField("uiOwnerFocused","focusChanged")
        item.observeField("HDPosterUrl","contentChanged")
        item.observeField("artworkKind","contentChanged")
    end if
    m.title.text = item.title
    m.subtitle.text = item.subtitle
    if not item.hasField("artState") then item.addFields({artState:"none"})
    m.poster.visible = false
    m.fallback.text = item.title
    m.fallback.visible = true
    m.poster.translation = [0,0]
    m.poster.width = 256
    m.poster.height = 144
    m.poster.loadDisplayMode = "scaleToZoom"
    m.poster.loadWidth = ImagePixels(256)
    m.poster.loadHeight = ImagePixels(144)
    if item.artworkKind = "portrait"
        ' Preserve the source aspect ratio, then crop rather than stretch.
        ' The complete poster remains available on the detail page.
        m.poster.loadWidth = ImagePixels(256)
        m.poster.loadHeight = ImagePixels(384)
    else if item.artworkKind = "logo"
        m.poster.translation = [40,22]
        m.poster.width = 176
        m.poster.height = 100
        m.poster.loadDisplayMode = "scaleToFit"
        m.poster.loadWidth = ImagePixels(176)
        m.poster.loadHeight = ImagePixels(100)
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
    fillWidth = 240*fraction
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
    if active
        m.title.repeatCount = -1
        m.subtitle.repeatCount = -1
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
    m.fallback.visible = not ready
end sub
