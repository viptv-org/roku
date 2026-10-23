sub init()
    m.programs = m.top.findNode("programs")
end sub
sub render()
    if m.observed <> invalid
        m.observed.unobserveField("guideData")
        m.observed.unobserveField("programIndex")
    end if
    m.observed = m.top.itemContent
    if m.observed = invalid then return
    m.observed.observeField("guideData","guideChanged")
    m.observed.observeField("programIndex","paint")
    m.top.findNode("name").text = m.observed.title
    guideChanged()
end sub
sub guideChanged()
    if m.observed = invalid then return
    m.programs.removeChildrenIndex(m.programs.getChildCount(),0)
    start = m.observed.windowStart
    index = 0
    for each item in RArray(RGet(m.observed.guideData,"programs"))
        begin = item.start_millis/1000
        finish = item.end_millis/1000
        if finish > start and begin < start+7200
            if begin < start then begin = start
            if finish > start+7200 then finish = start+7200
            x = (begin-start)*1400/7200
            width = (finish-begin)*1400/7200-8
            if width > 0 and m.programs.getChildCount() < 32
                group = m.programs.createChild("Group")
                group.addFields({programIndex:index})
                group.translation = [x,0]
                bg = group.createChild("Poster")
                bg.uri = "pkg:/images/design/row.9.png"
                bg.width = width
                bg.height = 72
                label = group.createChild("Label")
                label.text = item.title
                label.translation = [18,0]
                label.width = width-36
                label.height = 72
                label.vertAlign = "center"
                font = CreateObject("roSGNode","Font")
                font.uri = "pkg:/fonts/remote_onest_500.ttf"
                font.size = 24
                label.font = font
            end if
        end if
        index++
    end for
    if m.programs.getChildCount() = 0
        label = m.programs.createChild("Label")
        label.text = RText(RGet(m.observed.guideData,"reason"),"Program information unavailable")
        label.width = 1400
        label.height = 72
        label.vertAlign = "center"
        font = CreateObject("roSGNode","Font")
        font.uri = "pkg:/fonts/remote_onest_400.ttf"
        font.size = 24
        label.font = font
    end if
    paint()
end sub
sub paint()
    if m.observed = invalid then return
    focused = m.top.listHasFocus and m.top.focusPercent > 0.5
    m.top.findNode("channelGround").blendColor = "#161618FF"
    m.top.findNode("name").color = "#F4F2EE"
    if focused
        m.top.findNode("channelGround").blendColor = "#F4F2EEFF"
        m.top.findNode("name").color = "#111113"
    end if
    for each group in m.programs.getChildren(-1,0)
        if group.hasField("programIndex")
            group.getChild(0).blendColor = "#212124FF"
            group.getChild(1).color = "#F4F2EE"
            if focused and group.programIndex = m.observed.programIndex
                group.getChild(0).blendColor = "#F4F2EEFF"
                group.getChild(1).color = "#111113"
            end if
        end if
    end for
end sub
