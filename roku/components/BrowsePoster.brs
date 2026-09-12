sub init()
    m.poster = m.top.findNode("poster")
    m.artworkMask = m.top.findNode("artworkMask")
    m.title = m.top.findNode("title")
    m.fallback = m.top.findNode("fallback")
    m.focusFrame = m.top.findNode("focusFrame")
    m.surface = m.top.findNode("surface")
end sub

sub contentChanged()
    item = m.top.itemContent
    m.fallback.visible = false
    m.poster.visible = true
    m.artworkMask.visible = true
    if item = invalid
        m.poster.uri = ""
        m.title.text = ""
        m.fallback.text = ""
        return
    end if
    m.poster.uri = item.HDPosterUrl
    m.title.text = item.title
    if item.HDPosterUrl = ""
        m.fallback.text = item.title
        m.fallback.visible = true
        m.poster.visible = false
        m.artworkMask.visible = false
    end if
end sub

sub focusChanged()
    hasListFocus = m.top.listHasFocus
    focused = hasListFocus and m.top.focusPercent > 0.5
    m.focusFrame.visible = focused
    if focused
        m.title.color = "#FFFFFF"
        m.title.repeatCount = -1
        m.surface.color = "#282A2E"
    else
        m.title.color = "#A0A4A8"
        m.title.repeatCount = 0
        m.surface.color = "#202224"
    end if
end sub