sub render()
    if m.top.content = invalid then return
    m.top.findNode("title").text = m.top.content.title
    message = m.top.content.searchMessage
    m.top.findNode("message").visible = message <> invalid and message <> ""
    if message = invalid then message = ""
    m.top.findNode("message").text = message
    headingHeight = m.top.content.searchHeadingHeight
    if headingHeight = invalid then headingHeight = 40
    m.top.findNode("message").translation = [0,headingHeight+20]
    height = m.top.content.searchTitleHeight
    if height = invalid
        m.top.findNode("spacer").height = 52
        m.top.findNode("title").height = 40
    else
        m.top.findNode("spacer").height = height
        m.top.findNode("title").height = headingHeight
    end if
    if m.top.content.homeTitleHeight <> invalid
        m.top.findNode("spacer").height = m.top.content.homeTitleHeight
        m.top.findNode("title").height = m.top.content.homeTitleHeight
        ' Native Group bounds include the hidden message's old geometry.
        ' Collapse it so the row's12px label gap follows the40px title box.
        m.top.findNode("message").translation = [0,0]
        m.top.findNode("message").height = 0
    else
        m.top.findNode("message").height = 26
    end if
end sub
