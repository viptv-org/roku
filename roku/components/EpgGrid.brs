sub init()
    for each id in ["clock","day","selection","ticks","filters","rows","nowLine","empty","position","details","detailHeading","detailBody","refresh","guideBatch","guideReveal"]
        m[id] = m.top.findNode(id)
    end for
    m.rowViews = []
    m.channels = []
    m.cache = {}
    m.order = []
    m.labels = {}
    m.filtersData = [{id:"search",name:"Search Live TV"},{id:"all",name:"All US channels"},{id:"favorites",name:"My channels"},{id:"recent",name:"Recent"}]
    m.menu = 1
    m.row = 0
    m.offset = 0
    m.total = 0
    m.menuFocus = false
    m.message = "Loading channels…"
    m.guideBatch.observeField("fire","epgRender")
    m.guideReveal.observeField("fire","epgReveal")
    m.refresh.observeField("fire","epgRender")
    m.top.observeField("visible","epgVisibility")
end sub

sub open(scope as string)
    if m.scope <> scope
        m.cache = {}
        m.order = []
        m.labels = {}
        m.filtersData = [{id:"search",name:"Search Live TV"},{id:"all",name:"All US channels"},{id:"favorites",name:"My channels"},{id:"recent",name:"Recent"}]
    end if
    m.top.query = ""
    m.scope = scope
    m.menu = 1
    m.row = 0
    m.channels = []
    m.offset = 0
    m.total = 0
    m.menuFocus = false
    m.message = "Loading channels…"
    m.followNow = true
    m.anchor = CreateObject("roDateTime").asSeconds()
    m.window = (m.anchor \ 1800)*1800
    m.details.visible = false
    m.top.visible = true
    m.top.setFocus(true)
    epgRender()
    m.top.route = {filter:m.filtersData[m.menu],offset:0,search:m.top.query}
end sub

sub resume()
    m.details.visible = false
    m.top.visible = true
    m.top.setFocus(true)
    epgRender()
end sub

sub epgVisibility()
    if m.top.visible then m.refresh.control = "start" else m.refresh.control = "stop"
end sub

sub epgCategories()
    m.filtersData = [{id:"search",name:"Search Live TV"},{id:"all",name:"All US channels"},{id:"favorites",name:"My channels"},{id:"recent",name:"Recent"}]
    for each category in Bounded(m.top.categories,100)
        if Txt(category.id) <> "" then m.filtersData.push({id:category.id,name:Txt(category.name)})
    end for
    if m.menu >= m.filtersData.count() then m.menu = 1
    epgRender()
end sub

sub epgData()
    data = m.top.data
    if data = invalid then return
    m.channels = Bounded(data.channels,40)
    m.offset = data.offset
    m.total = data.total
    m.row = 0
    if data.focusEnd = true then m.row = m.channels.count()-1
    if m.row < 0 then m.row = 0
    m.message = Txt(data.message,"No channels here yet. Choose another filter.")
    m.holdingGuides = true
    m.guideReveal.control = "stop"
    m.guideReveal.control = "start"
    epgRender()
end sub

sub epgGuide()
    result = m.top.guide
    if result = invalid then return
    id = Txt(result.id)
    if id = "" then return
    if not m.cache.doesExist(id)
        if m.order.count() >= 40 then m.cache.delete(m.order.shift())
        m.order.push(id)
    end if
    ttl = 300
    if result.ok <> true then ttl = 60
    programs = Bounded(result.programs,100)
    if result.ok <> true and m.cache.doesExist(id) then programs = m.cache[id].programs
    m.cache[id] = {programs:programs,expires:CreateObject("roDateTime").asSeconds()+ttl,ok:result.ok}
    if Txt(result.timezone) <> ""
        m.labels = {}
        for each tick in Bounded(result.timeline,54)
            if tick.start <> invalid then m.labels[tick.start.toStr()] = tick
        end for
    end if
    epgRequestGuides()
    if m.holdingGuides = true
        complete = true
        for i = m.visibleFirst to m.visibleLast
            if not m.cache.doesExist(Txt(m.channels[i].id)) then complete = false
        end for
        if complete then epgReveal()
    else
        ' Coalesce nearby completions without a full page rebuild per response.
        if m.guideBatch.control <> "start" then m.guideBatch.control = "start"
    end if
end sub

sub epgReveal()
    m.holdingGuides = false
    m.guideReveal.control = "stop"
    epgRender()
end sub

sub epgRequestGuides()
    needed = []
    now = CreateObject("roDateTime").asSeconds()
    for i = m.visibleFirst to m.visibleLast+2
        if i >= m.channels.count() then exit for
        id = Txt(m.channels[i].id)
        if not m.cache.doesExist(id)
            needed.push(id)
        else if m.cache[id].expires <= now
            needed.push(id)
        end if
    end for
    m.top.needed = needed
end sub

function epgLabel(parent as object, text as string, x as integer, y as integer, width as integer, size as integer, color as string) as object
    node = parent.createChild("Label")
    node.translation = [x,y]
    node.width = width
    node.height = 32
    node.text = text
    node.color = color
    node.font = "font:SmallSystemFont"
    node.font.size = size
    return node
end function

function epgRect(parent as object, x as integer, y as integer, width as integer, height as integer, color as string) as object
    node = parent.createChild("Rectangle")
    node.translation = [x,y]
    node.width = width
    node.height = height
    node.color = color
    return node
end function

function epgTick(at as integer) as string
    key = at.toStr()
    if m.labels.doesExist(key) then return Txt(m.labels[key].display_time)
    return EpgTime(at)
end function

function epgProgrammes(id as string) as object
    if m.cache.doesExist(id) then return m.cache[id].programs
    return []
end function

sub epgRender()
    if m.top.visible <> true or m.window = invalid then return
    now = CreateObject("roDateTime").asSeconds()
    if m.followNow
        m.anchor = now
        m.window = (now \ 1800)*1800
    end if
    m.clock.visible = false
    m.day.visible = false
    m.ticks.removeChildrenIndex(m.ticks.getChildCount(),0)
    for i = 0 to 3
        label = epgLabel(m.ticks,epgTick(m.window+i*1800),432+i*201,116,197,19,"#FFFFFF")
    end for
    m.filters.removeChildrenIndex(m.filters.getChildCount(),0)
    firstMenu = 0
    if m.menu > 7 then firstMenu = m.menu-7
    for i = firstMenu to m.filtersData.count()-1
        if i >= firstMenu+8 then exit for
        y = 166+(i-firstMenu)*48
        color = "#A6A8AA"
        if i = m.menu
            color = "#FFFFFF"
            if m.menuFocus and m.top.active
                bar = epgRect(m.filters,104,y-3,184,42,"#F5F5F5")
                color = "#101112"
            end if
        end if
        label = epgLabel(m.filters,m.filtersData[i].name,112,y-3,172,19,color)
        label.height = 42
        label.vertAlign = "center"
    end for
    ' Reuse logo nodes: rebuilding them on every focus/guide event flashes artwork.
    for each view in m.rowViews
        view.group.visible = false
    end for
    firstRow = 0
    if m.row > 4 then firstRow = m.row-4
    m.selection.text = ""
    m.visibleFirst = firstRow
    m.visibleLast = firstRow+4
    if m.visibleLast >= m.channels.count() then m.visibleLast = m.channels.count()-1
    m.empty.visible = m.channels.count() = 0
    m.empty.text = m.message
    for i = firstRow to m.channels.count()-1
        if i >= firstRow+5 then exit for
        channel = m.channels[i]
        id = Txt(channel.id)
        slot = i-firstRow
        y = 166+slot*91
        if slot >= m.rowViews.count()
            group = m.rows.createChild("Group")
            background = epgRect(group,300,0,128,87,"#202224")
            icon = group.createChild("Poster")
            icon.translation = [308,7]
            icon.width = 112
            icon.height = 73
            icon.loadWidth = ImagePixels(112)
            icon.loadHeight = ImagePixels(73)
            icon.loadDisplayMode = "scaleToFit"
            icon.observeField("loadStatus","epgLogoStatus")
            label = epgLabel(group,"",308,16,112,16,"#FFFFFF")
            label.height = 60
            label.wrap = true
            label.numLines = 3
            label.horizAlign = "center"
            cellsGroup = group.createChild("Group")
            m.rowViews.push({group:group,background:background,icon:icon,label:label,cells:cellsGroup})
        end if
        view = m.rowViews[slot]
        view.group.visible = true
        view.group.translation = [0,y]
        view.background.color = "#202224"
        if i = m.row and not m.menuFocus and m.top.active then view.background.color = "#303234"
        logo = ImageUrl(Txt(channel.logo,Txt(channel.poster)),112,73,false,true)
        if view.icon.uri <> logo then view.icon.uri = logo
        view.icon.visible = logo <> ""
        view.label.visible = logo = "" or view.icon.loadStatus = "failed"
        view.label.text = Txt(channel.name)
        view.cells.removeChildrenIndex(view.cells.getChildCount(),0)
        parent = view.cells
        y = 0
        cells = EpgCells(epgProgrammes(id),m.window,m.window+7200)
        selected = EpgCellAt(cells,m.anchor)
        for c = 0 to cells.count()-1
            cell = cells[c]
            geometry = EpgGeometry(cell,m.window,7200,804)
            color = "#202224"
            focused = i = m.row and c = selected and not m.menuFocus and m.top.active
            if focused then color = "#F5F5F5"
            width = geometry.width-3
            if width < 1 then width = 1
            bar = epgRect(parent,432+geometry.x,y,width,87,color)
            if focused then bar = epgRect(parent,432+geometry.x,y,3,87,"#FFFFFF")
            if geometry.width > 52
                hint = epgTick(cell.start)
                if cell.programme <> invalid then hint = Txt(cell.programme.display_time,hint)
                if cell.start <= now and cell.end > now then hint = int((cell.end-now+59)/60).toStr()+" MIN LEFT"
                if cell.missing
                    hint = "LIVE CHANNEL"
                    if not m.cache.doesExist(id) then hint = "LOADING GUIDE…"
                end if
                ink = "#F5F5F5"
                secondary = "#A6A8AA"
                if focused
                    ink = "#101112"
                    secondary = "#414548"
                end if
                label = epgLabel(parent,hint,444+geometry.x,y+10,width-22,15,secondary)
                label = epgLabel(parent,cell.title,444+geometry.x,y+38,width-22,20,ink)
                label.height = 48
                label.wrap = true
                label.numLines = 2
            end if
            if i = m.row and c = selected
                m.selectedCell = cell
                m.selection.text = cell.title
                if cell.missing then m.selection.text = Txt(channel.name)
            end if
        end for
    end for
    x = 432+int((now-m.window)*804.0/7200)
    m.nowLine.visible = x >= 432 and x < 1236
    m.nowLine.translation = [x,150]
    m.position.text = m.total.toStr() + " channels"
    if m.channels.count() > 0 then m.position.text = (m.offset+m.row+1).toStr()+" / "+m.total.toStr()
    epgRequestGuides()
end sub

sub epgRoute(offset as integer, last = false as boolean)
    m.message = "Loading channels…"
    m.channels = []
    m.details.visible = false
    m.top.route = {filter:m.filtersData[m.menu],offset:offset,focusEnd:last,search:m.top.query}
    epgRender()
end sub

sub epgDetails()
    if m.channels.count() = 0 then return
    cell = m.selectedCell
    m.detailHeading.text = Txt(m.channels[m.row].name)+"  ·  "+cell.title
    text = "Schedule unavailable. You can still watch this channel live."
    if not cell.missing
        text = Txt(cell.programme.display_time,epgTick(cell.start))+"  ·  "+Txt(cell.programme.description,"No programme description available.")
        if cell.start > CreateObject("roDateTime").asSeconds() then text = "UPCOMING  ·  "+text
    end if
    m.detailBody.text = text
    m.details.visible = true
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not press or m.top.visible <> true then return false
    if m.details.visible
        if key = "back" then m.details.visible = false
        if key = "OK" then epgWatchChannel()
        return true
    end if
    if key = "back"
        m.top.leave = true
        return true
    end if
    if key = "replay" or key = "instantreplay"
        m.followNow = true
        m.anchor = CreateObject("roDateTime").asSeconds()
        m.window = (m.anchor \ 1800)*1800
        m.menuFocus = false
    else if m.menuFocus
        if key = "up" and m.menu > 0 then m.menu--
        if key = "down" and m.menu < m.filtersData.count()-1 then m.menu++
        if (key = "OK" or key = "right") and m.menu = 0
            m.top.searchRequested = true
            return true
        end if
        if key = "OK" or key = "right"
            m.menuFocus = false
            active = m.top.route
            unchanged = false
            if active <> invalid
                unchanged = Txt(active.filter.id) = Txt(m.filtersData[m.menu].id) and Txt(active.search) = Txt(m.top.query)
            end if
            if not unchanged
                m.row = 0
                epgRoute(0)
            end if
        else if key = "left"
            m.top.leave = true
        end if
    else if m.channels.count() = 0
        if key = "left" then m.menuFocus = true
        if key = "OK" then epgRoute(m.offset)
    else if key = "up"
        if m.row > 0
            m.row--
        else if m.offset > 0
            epgRoute(m.offset-40,true)
        end if
    else if key = "down"
        if m.row < m.channels.count()-1
            m.row++
        else if m.offset+m.channels.count() < m.total
            epgRoute(m.offset+40)
        end if
    else if key = "left" or key = "right"
        m.followNow = false
        cells = EpgCells(epgProgrammes(Txt(m.channels[m.row].id)),m.window,m.window+7200)
        c = EpgCellAt(cells,m.anchor)
        if key = "left"
            if c > 0
                m.anchor = cells[c-1].start
            else
                now = CreateObject("roDateTime").asSeconds()
                boundary = (now \ 1800)*1800
                if m.window > boundary
                    previous = m.window
                    m.window -= 3600
                    if m.window < boundary then m.window = boundary
                    earlier = EpgCells(epgProgrammes(Txt(m.channels[m.row].id)),m.window,m.window+7200)
                    m.anchor = earlier[EpgCellAt(earlier,previous-1)].start
                else
                    m.menuFocus = true
                end if
            end if
        else if c+1 < cells.count()
            m.anchor = cells[c+1].start
        else
            now = CreateObject("roDateTime").asSeconds()
            if m.window < (now \ 1800)*1800+86400
                m.window += 3600
                m.anchor = m.window+3600
            end if
        end if
    else if key = "rewind"
        m.followNow = false
        now = CreateObject("roDateTime").asSeconds()
        m.window -= 3600
        if m.window < (now \ 1800)*1800 then m.window = (now \ 1800)*1800
        m.anchor = m.window
    else if key = "options" or key = "info"
        epgDetails()
    else if key = "OK" or key = "play"
        if m.selectedCell.start > CreateObject("roDateTime").asSeconds() and key <> "play"
            epgDetails()
        else
            epgWatchChannel()
        end if
    else
        return false
    end if
    epgRender()
    return true
end function

sub epgSearchChanged()
    if m.top.visible <> true then return
    m.menu = 1
    m.menuFocus = false
    m.row = 0
    epgRoute(0)
end sub

sub epgWatchChannel()
    item = CopyRouteData(m.channels[m.row])
    now = CreateObject("roDateTime").asSeconds()
    for each programme in epgProgrammes(Txt(item.id))
        if programme.start <= now and programme.end > now then item.now = CopyRouteData(programme)
    end for
    m.top.watch = item
end sub

sub chooseFilter(id as string)
    for i = 1 to m.filtersData.count()-1
        if m.filtersData[i].id = id
            m.menu = i
            epgRoute(0)
            return
        end if
    end for
end sub

sub epgLogoStatus(event as object)
    icon = event.getRoSGNode()
    for each view in m.rowViews
        if view.icon.isSameNode(icon)
            view.label.visible = icon.uri = "" or icon.loadStatus = "failed"
            view.icon.visible = icon.uri <> "" and icon.loadStatus <> "failed"
            return
        end if
    end for
end sub
