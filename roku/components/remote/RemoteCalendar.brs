sub rCalendarStart()
    m.calendarOffset = 0
    m.calendarType = "series"
    rCalendarWeek()
end sub

sub rCalendarWeek()
    m.calendarEntries = []
    m.calendarCursor = ""
    days = []
    for i = 0 to 6
        date = CreateObject("roDateTime")
        date.fromSeconds(date.asSeconds()+(m.calendarOffset+i)*86400)
        date.toLocalTime()
        iso = left(date.toISOString(),10)
        days.push({title:mid(iso,6),action:"calendarDay",date:iso})
    end for
    m.calendarDay = days[0].date
    m.filters.itemSize = [232,64]
    m.filters.numColumns = 7
    m.filters.translation = [96,222]
    m.filters.content = rContent(days,232,64)
    m.filters.visible = true
    rShowActions([{title:"Series / Anime",action:"calendarType",width:260},{title:"Previous week",action:"calendarWeek",offset:-7,width:260},{title:"Next week",action:"calendarWeek",offset:7,width:260}])
    m.actions.translation = [96,140]
    m.heading.text = ""
    rCalendarFetch("")
end sub

sub rCalendarFetch(cursor as string)
    m.calendarPath = "/api/calendar?type="+m.calendarType+"&start="+m.calendarDay+"&end="+m.calendarDay+"&limit=100"
    if cursor <> "" then m.calendarPath += "&skip="+REncode(cursor)
    rSend("GET",m.calendarPath,invalid,"calendar",{day:m.calendarDay,type:m.calendarType,cursor:cursor})
end sub

sub rCalendar(data as object, request as object)
    if request.context.day <> m.calendarDay or request.context.type <> m.calendarType then return
    for each entry in RArray(data.entries)
        m.calendarEntries.push(entry)
    end for
    while m.calendarEntries.count() > 300
        m.calendarEntries.shift()
    end while
    m.calendarCursor = RText(data.next_cursor)
    values = []
    for each entry in m.calendarEntries
        date = CreateObject("roDateTime")
        date.fromISO8601String(entry.date)
        date.toLocalTime()
        time = right("0"+date.getHours().toStr(),2)+":"+right("0"+date.getMinutes().toStr(),2)
        values.push({title:entry.card.title,subtitle:RText(entry.episode_title,RText(entry.card.subtitle)),action:"detail",card:entry.card,calendarTime:time,poster:entry.card.poster})
    end for
    m.rows.translation = [96,332]
    m.rows.itemSize = [1100,132]
    m.rows.itemSpacing = [0,18]
    m.rows.numRows = 4
    m.rows.content = rContent(values,1100,132)
    m.rows.visible = true
    m.skeleton.visible = false
    m.top.findNode("calendarPreview").visible = values.count() > 0
    if values.count() = 0 then m.message.text = "No releases for this day."
    rCalendarPreview()
end sub

sub rCalendarPreview()
    if m.rows.content = invalid then return
    node = m.rows.content.getChild(m.rows.itemFocused)
    if node = invalid then node = m.rows.content.getChild(0)
    if node = invalid then return
    card = node.wire.card
    m.top.findNode("calendarPoster").uri = RText(card.poster)
    m.top.findNode("calendarTitle").text = card.title
    m.top.findNode("calendarDescription").text = RText(card.description)
    if m.rows.itemFocused >= m.rows.content.getChildCount()-4 and m.calendarCursor <> ""
        rCalendarFetch(m.calendarCursor)
    end if
end sub
