sub render()
    if m.top.itemContent = invalid then return
    size = 128
    if m.top.itemContent.hasField("uiSize") then size = m.top.itemContent.uiSize
    for each id in ["frame","outline"]
        m.top.findNode(id).width = size
        m.top.findNode(id).height = size
    end for
    m.top.findNode("image").width = size-16
    m.top.findNode("image").height = size-16
    m.top.findNode("image").loadWidth = size-16
    m.top.findNode("image").loadHeight = size-16
    m.top.findNode("image").loadDisplayMode = "scaleToFit"
    m.top.findNode("image").uri = m.top.itemContent.hdPosterUrl
    focus()
end sub
sub focus()
    m.top.findNode("outline").visible = m.top.gridHasFocus and m.top.focusPercent > 0.5
end sub
