sub init()
    m.programs = m.top.findNode("programs")
    m.emptyProgram = m.top.findNode("emptyProgram")
    m.programFont = CreateObject("roSGNode","Font")
    m.programFont.uri = "pkg:/fonts/remote_onest_500.ttf"
    m.programFont.size = 24
end sub
sub render()
    if m.observed <> invalid
        m.observed.unobserveField("guideData")
        m.observed.unobserveField("programIndex")
    end if
    m.observed = m.top.itemContent
    if m.observed = invalid
        m.rendered = invalid
        m.top.findNode("name").text = ""
        m.emptyProgram.text = ""
        m.emptyProgram.visible = false
        for each group in m.programs.getChildren(-1,0)
            group.visible = false
            group.getChild(1).text = ""
        end for
        return
    end if
    m.observed.observeField("guideData","guideChanged")
    m.observed.observeField("programIndex","paint")
    m.top.findNode("name").text = m.observed.title
    guideChanged()
end sub
sub guideChanged()
    if m.observed = invalid then return
    entries = []
    start = m.observed.viewport.start_millis
    index = 0
    for each item in RArray(RGet(m.observed.guideData,"programs"))
        begin = item.start_millis-start
        finish = item.end_millis-start
        if finish > 0 and begin < 7200000#
            if begin < 0 then begin = 0
            if finish > 7200000# then finish = 7200000#
            x! = begin*1400#/7200000#
            width! = (finish-begin)*1400#/7200000#-8
            if width! > 0 then entries.push({index:index,x:x!,width:width!,title:item.title})
            if entries.count() = 32 then exit for
        end if
        index++
    end for
    reason = ""
    if entries.count() = 0 then reason = RText(RGet(m.observed.guideData,"reason"),"Program information unavailable")
    model = {entries:entries,reason:reason}
    if REqual(m.rendered,model)
        paint()
        return
    end if
    m.rendered = RCopy(model)
    while m.programs.getChildCount() < entries.count()
        group = m.programs.createChild("Group")
        group.addFields({programIndex:-1})
        bg = group.createChild("Poster")
        bg.uri = "pkg:/images/design/row.9.png"
        bg.height = 72
        label = group.createChild("Label")
        label.translation = [18,0]
        label.height = 72
        label.vertAlign = "center"
        label.font = m.programFont
    end while
    for i = 0 to m.programs.getChildCount()-1
        group = m.programs.getChild(i)
        group.visible = i < entries.count()
        if group.visible
            entry = entries[i]
            group.programIndex = entry.index
            group.translation = [entry.x,0]
            group.getChild(0).width = entry.width
            label = group.getChild(1)
            label.text = entry.title
            label.visible = entry.width > 36
            if label.visible then label.width = entry.width-36 else label.width = 0
        else
            group.getChild(1).text = ""
        end if
    end for
    m.emptyProgram.text = reason
    m.emptyProgram.visible = entries.count() = 0
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
        if group.visible
            group.getChild(0).blendColor = "#212124FF"
            group.getChild(1).color = "#F4F2EE"
            if focused and group.programIndex = m.observed.programIndex
                group.getChild(0).blendColor = "#F4F2EEFF"
                group.getChild(1).color = "#111113"
            end if
        end if
    end for
end sub
