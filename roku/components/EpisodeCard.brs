sub init()
    ' Mask textures use display pixels even when card layout uses HD coordinates.
    device = CreateObject("roDeviceInfo")
    layout = device.GetDisplaySize()
    pixels = device.GetUIResolution()
    if layout <> invalid and pixels <> invalid
        if layout.w > 0 and layout.h > 0
            m.top.findNode("artworkClip").maskSize = [256*pixels.width/layout.w,144*pixels.height/layout.h]
        end if
    end if
    m.thumbnail = m.top.findNode("thumbnail")
    m.thumbnail.observeField("loadStatus","artLoaded")
end sub
sub artLoaded()
    ready = m.thumbnail.loadStatus = "ready" and m.thumbnail.uri <> ""
    m.thumbnail.visible = ready
    m.top.findNode("placeholder").visible = not ready
end sub

sub render()
    item = m.top.itemContent
    if item = invalid then return
    uri = ImageUrl(item.HDPosterUrl,256,144)
    if m.thumbnail.uri <> uri
        m.thumbnail.visible = false
        m.top.findNode("placeholder").visible = true
        m.thumbnail.loadWidth = ImagePixels(256)
        m.thumbnail.loadHeight = ImagePixels(144)
        m.thumbnail.uri = uri
    else
        artLoaded()
    end if
    watched = item.hasField("watched") and item.watched
    m.top.findNode("watchedBadge").visible = watched
    fraction = 0
    if item.hasField("progressFraction") then fraction = item.progressFraction
    m.top.findNode("progress").visible = fraction > 0 and not watched
    m.top.findNode("progress").width = 240 * fraction
    m.top.findNode("number").visible = not (item.hasField("pageAction") and item.pageAction)
    m.top.findNode("number").text = "EPISODE"
    if item.hasField("episodeNumber") then m.top.findNode("number").text = "EPISODE " + Txt(item.episodeNumber)
    m.top.findNode("title").text = item.title
    if item.hasField("episodeTitle") then m.top.findNode("title").text = item.episodeTitle
    m.top.findNode("title").font.size = 22
    m.top.findNode("summary").text = item.description
    m.top.findNode("summary").font.size = 19
    renderFocus()
end sub

sub renderFocus()
    active = m.top.gridHasFocus and m.top.focusPercent > 0.5
    m.top.findNode("surface").visible = active
    m.top.findNode("title").color = "#F5F5F5"
    m.top.findNode("summary").color = "#A6A8AA"
    m.top.findNode("title").repeatCount = 0
    if active
        m.top.findNode("surface").blendColor = "#F5F5F5FF"
        m.top.findNode("title").color = "#FFFFFF"
        m.top.findNode("summary").color = "#C5C6C7"
        m.top.findNode("title").repeatCount = -1
    end if
end sub
