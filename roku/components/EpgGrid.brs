sub init()
    for each id in ["clock","day","selection","ticks","filters","rows","nowLine","empty","position","details","detailHeading","detailTime","detailBody","detailActions","refresh","guideBatch","guideReveal","channelIdentity","programmeTitle","programmeTime","programmeRemaining","programmeNext","headerTrack","headerProgress","previewLogo","previewName"]
        m[id] = m.top.findNode(id)
    end for
    actions = CreateObject("roSGNode","ContentNode")
    for each title in ["Watch channel now","Close"]
        node = actions.createChild("ContentNode")
        node.title = title
        node.addFields({uiWidth:440,uiHeight:54})
    end for
    m.detailActions.content = actions
    m.detailActions.observeField("itemSelected","epgDetailSelected")
    m.rowViews = []
    m.channels = []
    m.cache = {}
    m.order = []
    m.labels = {}
    m.filtersData = [{id:"all",name:"All US channels"},{id:"favorites",name:"My channels"},{id:"recent",name:"Recent"},{id:"search",name:"Search"}]
    m.menu = 0
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
        m.filtersData = [{id:"all",name:"All US channels"},{id:"favorites",name:"My channels"},{id:"recent",name:"Recent"},{id:"search",name:"Search"}]
    end if
    m.top.query = ""
    m.scope = scope
    m.menu = 0
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
    m.filtersData = [{id:"all",name:"All US channels"},{id:"favorites",name:"My channels"},{id:"recent",name:"Recent"},{id:"search",name:"Search"}]
    for each category in Bounded(m.top.categories,100)
        if Txt(category.id) <> "" then m.filtersData.push({id:category.id,name:Txt(category.name)})
    end for
    if m.menu >= m.filtersData.count() then m.menu = 0
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
    font = CreateObject("roSGNode","Font")
    font.uri = "pkg:/fonts/onest_400.ttf"
    node.font = font
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

function epgSurface(parent as object, x as integer, y as integer, width as integer, height as integer, color as string, focused = false as boolean) as object
    node = parent.createChild("DesignSurface")
    node.translation = [x,y]
    node.width = width
    node.height = height
    node.radius = 10
    node.blendColor = color
    node.focused = focused
    return node
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
        label = epgLabel(m.ticks,epgTick(m.window+i*1800),338+i*222,309,211,15,"#B6B4AF")
    end for
    m.filters.removeChildrenIndex(m.filters.getChildCount(),0)
    if m.filterStart = invalid then m.filterStart = 0
    if m.menu < m.filterStart then m.filterStart = m.menu
    extent = 0
    for i = m.filterStart to m.menu
        extent += epgFilterWidth(m.filtersData[i].name)+10
    end for
    while extent > 1088 and m.filterStart < m.menu
        extent -= epgFilterWidth(m.filtersData[m.filterStart].name)+10
        m.filterStart++
    end while
    x = 128
    for i = m.filterStart to m.filtersData.count()-1
        width = epgFilterWidth(m.filtersData[i].name)
        if x+width > 1216 then exit for
        color = "#B6B4AF"
        fill = "#0B0B0CFF"
        focused = i = m.menu and m.menuFocus and m.top.active
        if i = m.menu then fill = "#34343AFF"
        if focused
            fill = "#F4F2EEFF"
            color = "#111113"
        end if
        surface = epgSurface(m.filters,x,250,width,37,fill,focused)
        surface.radius = 18.5
        label = epgLabel(m.filters,m.filtersData[i].name,x+16,250,width-32,16,color)
        label.height = 37
        label.vertAlign = "center"
        x += width+10
    end for
    for each view in m.rowViews
        view.group.visible = false
    end for
    firstRow = 0
    if m.row > 4 then firstRow = m.row-4
    m.visibleFirst = firstRow
    m.visibleLast = firstRow+4
    if m.visibleLast >= m.channels.count() then m.visibleLast = m.channels.count()-1
    m.empty.visible = m.channels.count() = 0
    m.empty.text = m.message
    for i = firstRow to m.visibleLast
        channel = m.channels[i]
        id = Txt(channel.id)
        slot = i-firstRow
        if slot >= m.rowViews.count()
            group = m.rows.createChild("Group")
            number = epgLabel(group,"",128,18,24,14,"#8F8D89")
            background = epgSurface(group,160,6,48,48,"#212124FF")
            icon = group.createChild("Poster")
            icon.translation = [164,10]
            icon.width = 40
            icon.height = 40
            icon.loadWidth = 80
            icon.loadHeight = 80
            icon.loadDisplayMode = "scaleToFit"
            icon.observeField("loadStatus","epgLogoStatus")
            label = epgLabel(group,"",164,18,40,12,"#F4F2EE")
            label.horizAlign = "center"
            name = epgLabel(group,"",220,20,101,15,"#F4F2EE")
            cellsGroup = group.createChild("Group")
            cellsGroup.clippingRect = [328,0,888,64]
            m.rowViews.push({group:group,background:background,icon:icon,label:label,name:name,number:number,cells:cellsGroup})
        end if
        view = m.rowViews[slot]
        view.group.visible = true
        view.group.translation = [0,343+slot*67]
        view.number.text = (m.offset+i+1).toStr()
        view.name.text = Txt(channel.name)
        logo = ImageUrl(Txt(channel.logo,Txt(channel.poster)),80,80,false,true)
        if view.icon.uri <> logo then view.icon.uri = logo
        view.icon.visible = logo <> ""
        view.label.visible = logo = "" or view.icon.loadStatus = "failed"
        view.label.text = ucase(left(Txt(channel.name),3))
        view.cells.removeChildrenIndex(view.cells.getChildCount(),0)
        cells = EpgCells(epgProgrammes(id),m.window,m.window+7200)
        selected = EpgCellAt(cells,m.anchor)
        for c = 0 to cells.count()-1
            cell = cells[c]
            geometry = EpgGeometry(cell,m.window,7200,888)
            focused = i = m.row and c = selected and not m.menuFocus and m.top.active
            fill = "#161618FF"
            current = cell.start <= now and cell.end > now
            if current then fill = "#212124FF"
            if focused then fill = "#F4F2EEFF"
            width = geometry.width-5
            if width < 1 then width = 1
            bar = epgSurface(view.cells,328+geometry.x,2,width,59,fill,focused)
            if geometry.width > 52
                hint = epgCompactTick(cell.start)+" – "+epgCompactTick(cell.end)
                if cell.missing
                    hint = "LIVE CHANNEL"
                    if not m.cache.doesExist(id) then hint = "Loading guide…"
                end if
                ink = "#F4F2EE"
                secondary = "#B6B4AF"
                if focused
                    ink = "#111113"
                    secondary = "#414548"
                end if
                label = epgLabel(view.cells,hint,340+geometry.x,8,width-24,12,secondary)
                label.height = 20
                label = epgLabel(view.cells,cell.title,340+geometry.x,29,width-24,16,ink)
                label.font.uri = "pkg:/fonts/onest_600.ttf"
                label.height = 25
                if current and not cell.missing
                    fraction = (now-cell.start)*1.0/(cell.end-cell.start)
                    progress = epgRect(view.cells,334+geometry.x,57,int((width-12)*fraction),3,"#F5C542")
                end if
            end if
            if i = m.row and c = selected
                m.selectedCell = cell
                epgHeader(channel,cell,now)
            end if
        end for
    end for
    x = 328+int((now-m.window)*888.0/7200)
    m.nowLine.visible = x >= 328 and x < 1216
    m.nowLine.translation = [x,338]
    if m.channels.count() = 0
        m.programmeTitle.text = "Live TV"
        m.channelIdentity.text = ""
        m.programmeTime.text = ""
        m.programmeRemaining.text = ""
        m.programmeNext.text = ""
        m.previewLogo.visible = false
        m.previewName.text = "Live TV"
        m.headerTrack.visible = false
        m.headerProgress.visible = false
    end if
    epgRequestGuides()
end sub

function epgFilterWidth(name as string) as integer
    width = len(name)*9+40
    if width < 86 then width = 86
    if width > 224 then width = 224
    return width
end function

sub epgHeader(channel as object, cell as object, now as integer)
    m.channelIdentity.text = (m.offset+m.row+1).toStr()+" · "+Txt(channel.name)
    m.programmeTitle.text = cell.title
    if cell.missing then m.programmeTitle.text = Txt(channel.name)
    m.programmeTime.text = "No guide information"
    m.programmeRemaining.text = ""
    m.programmeNext.text = ""
    current = not cell.missing and cell.start <= now and cell.end > now
    m.headerTrack.visible = current
    m.headerProgress.visible = current
    if not cell.missing
        m.programmeTime.text = epgCompactTick(cell.start)+" – "+epgCompactTick(cell.end)
        if current
            m.headerProgress.width = 146.0*(now-cell.start)/(cell.end-cell.start)
            m.programmeRemaining.text = int((cell.end-now+59)/60).toStr()+" min left"
        end if
        for each programme in epgProgrammes(Txt(channel.id))
            if programme.start >= cell.end
                m.programmeNext.text = "Next at "+epgCompactTick(programme.start)+" · "+Txt(programme.title)
                exit for
            end if
        end for
    end if
    logo = ImageUrl(Txt(channel.logo,Txt(channel.poster)),303,158,false,true)
    if m.previewLogo.uri <> logo then m.previewLogo.uri = logo
    m.previewLogo.visible = logo <> ""
    m.previewName.visible = logo = ""
    m.previewName.text = Txt(channel.name)
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
    m.detailHeading.text = cell.title
    m.detailTime.text = Txt(m.channels[m.row].name)+" · "+epgCompactTick(cell.start)+" – "+epgCompactTick(cell.end)
    text = "No guide information. You can still watch this channel."
    if not cell.missing
        text = Txt(cell.programme.description,"No programme description available.")
        if cell.start > CreateObject("roDateTime").asSeconds() then text = "UPCOMING  ·  "+text
    end if
    m.detailBody.text = text
    m.details.visible = true
    m.detailActions.jumpToItem = 0
    m.detailActions.setFocus(true)
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not press or m.top.visible <> true then return false
    if m.details.visible
        if key = "back"
            m.details.visible = false
            m.top.setFocus(true)
        end if
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
        if key = "left" and m.menu > 0 then m.menu--
        if key = "right" and m.menu < m.filtersData.count()-1 then m.menu++
        if (key = "OK" or key = "down") and m.filtersData[m.menu].id = "search"
            m.top.searchRequested = true
            return true
        end if
        if key = "OK" or key = "down"
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
        else if key = "up"
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
        else
            m.menuFocus = true
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
    m.menu = 0
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

function epgCompactTick(at as integer) as string
    pieces = epgTick(at).split(" ")
    if pieces.count() > 1 then return pieces[0]+" "+pieces[1]
    return epgTick(at)
end function

sub epgDetailSelected()
    if m.detailActions.itemSelected = 0
        epgWatchChannel()
    else
        m.details.visible = false
        m.top.setFocus(true)
        epgRender()
    end if
end sub
