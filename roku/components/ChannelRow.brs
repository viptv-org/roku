sub render()
    item = m.top.itemContent
    if item = invalid then return
    m.top.findNode("logo").uri = ImageUrl(item.HDPosterUrl,64,52,false,true)
    m.top.findNode("fallback").visible = item.HDPosterUrl = ""
    m.top.findNode("title").text = item.title
    m.top.findNode("title").font.size = 22
    saved = false
    if item.hasField("saved") then saved = item.saved
    m.top.findNode("favorite").visible = saved
    m.top.findNode("favorite").text = "♥"
    renderFocus()
end sub

sub renderFocus()
    active = m.top.listHasFocus and m.top.focusPercent > 0.5
    m.top.findNode("surface").blendColor = "#191B1DFF"
    m.top.findNode("title").color = "#F5F5F5"
    m.top.findNode("favorite").color = "#F5F5F5"
    m.top.findNode("title").repeatCount = 0
    if active
        m.top.findNode("surface").blendColor = "#F5F5F5FF"
        m.top.findNode("title").color = "#101112"
        m.top.findNode("favorite").color = "#101112"
        m.top.findNode("title").repeatCount = -1
    end if
end sub
