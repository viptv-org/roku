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
    renderFocus()
end sub

sub renderFocus()
    active = m.top.listHasFocus and m.top.focusPercent > 0.5
    m.top.findNode("surface").focused = active
    m.top.findNode("surface").blendColor = "#161618FF"
    m.top.findNode("title").color = "#F4F2EE"
    m.top.findNode("favorite").uri = "pkg:/images/lucide/check-primary.png"
    m.top.findNode("title").repeatCount = 0
    if active
        m.top.findNode("surface").blendColor = "#F4F2EEFF"
        m.top.findNode("title").color = "#0B0B0C"
        m.top.findNode("favorite").uri = "pkg:/images/lucide/check-focus.png"
        m.top.findNode("title").repeatCount = -1
    end if
end sub
