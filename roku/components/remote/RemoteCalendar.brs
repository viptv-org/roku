sub rCalendarStart()
    m.calendarOffset = 0
    m.calendarType = "series"
    rCalendarWeek()
end sub

sub rCalendarWeek()
    rRetireCalendar()
    days = []
    for i = 0 to 6
        date = CreateObject("roDateTime")
        date.fromSeconds(date.asSeconds()+(m.calendarOffset+i)*86400)
        date.toLocalTime()
        iso = left(date.toISOString(),10)
        days.push({title:mid(iso,6),action:"calendarDay",date:iso})
    end for
    m.calendarDay = days[0].date
    m.filters.itemSize = [160,64]
    m.filters.numColumns = 7
    m.filters.translation = [96,140]
    m.filters.content = rContent(days,160,64)
    m.filters.visible = true
    rShowActions([{title:"Calendar options",action:"calendarOptions",width:420}])
    m.actions.translation = [1404,140]
    m.heading.text = ""
    rCalendarFetch("")
end sub

sub rCalendarFetch(cursor as string)
    if cursor <> "" and cursor <> m.calendarCursor then return
    m.calendarPath = "/api/calendar?type="+m.calendarType+"&start="+m.calendarDay+"&end="+m.calendarDay+"&limit=100"
    if cursor <> "" then m.calendarPath += "&skip="+REncode(cursor)
    rSend("GET",m.calendarPath,invalid,"calendar",{day:m.calendarDay,type:m.calendarType,cursor:cursor,version:m.calendarVersion})
end sub

sub rCalendar(data as object, request as object)
    if request.context.version <> m.calendarVersion then return
    if request.context.cursor <> "" and request.context.cursor <> m.calendarCursor then return
    if request.context.day <> m.calendarDay or request.context.type <> m.calendarType then return
    for each entry in RArray(data.entries)
        m.calendarEntries.push(entry)
    end for
    while m.calendarEntries.count() > 300
        m.calendarEntries.shift()
    end while
    m.calendarCursor = ""
    values = []
    for each entry in m.calendarEntries
        date = CreateObject("roDateTime")
        date.fromISO8601String(entry.date)
        date.toLocalTime()
        time = right("0"+date.getHours().toStr(),2)+":"+right("0"+date.getMinutes().toStr(),2)
        values.push({title:entry.card.title,subtitle:RText(entry.episode_title,RText(entry.card.subtitle)),action:"detail",card:entry.card,calendarTime:time,poster:entry.card.poster})
    end for
    m.rows.translation = [96,250]
    m.rows.itemSize = [1100,132]
    m.rows.itemSpacing = [0,18]
    m.rows.numRows = 4
    m.rows.content = rContent(values,1100,132)
    m.rows.visible = true
    m.skeleton.visible = false
    m.top.findNode("calendarPreview").visible = values.count() > 0
    m.message.text = ""
    if values.count() = 0 then m.message.text = "No releases for this day."
    m.calendarCursor = RText(data.next_cursor)
    rCalendarPreview()
end sub

sub rCalendarPreview()
    if m.rows.content = invalid then return
    node = m.rows.content.getChild(m.rows.itemFocused)
    if node = invalid then node = m.rows.content.getChild(0)
    if node = invalid then return
    card = node.wire.card
    m.top.findNode("calendarPoster").uri = RText(card.landscape,RText(card.poster))
    m.top.findNode("calendarTitle").text = card.title
    m.top.findNode("calendarDescription").text = RText(card.description)
    if m.rows.itemFocused >= m.rows.content.getChildCount()-4 and m.calendarCursor <> ""
        rCalendarFetch(m.calendarCursor)
    end if
end sub

sub rRetireCalendar()
    m.calendarVersion++
    for each worker in m.workers
        if worker.request.tag = "calendar" then worker.cancel = true
    end for
    retained = []
    for each request in m.queue
        if request.tag <> "calendar" then retained.push(request)
    end for
    m.queue = retained
    retained = []
    for each request in m.retryAuth
        if request.tag <> "calendar" then retained.push(request)
    end for
    m.retryAuth = retained
    m.pending.delete("calendar")
    m.calendarEntries = []
    m.calendarCursor = ""
    m.rows.visible = false
    m.rows.content = invalid
    m.top.findNode("calendarPreview").visible = false
    m.top.findNode("calendarPoster").uri = ""
    m.message.text = "Loading releases…"
end sub
