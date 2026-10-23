sub rWelcome()
    rReset("welcome")
    m.navigation.visible = false
    m.heading.text = "Sign in to VIPTV"
    m.heading.translation = [96,96]
    m.heading.font.size = 56
    m.top.findNode("welcomeArt").visible = true
    rows = [{title:"Use your phone",subtitle:"Scan a QR code — quickest",action:"pair"},{title:"Use a browser",subtitle:"Go to a web address and type a code",action:"pair"},{title:"Use a password",action:"password"}]
    if m.config.locked <> true then rows.push({title:"Server",subtitle:m.config.base,action:"server"})
    m.rows.itemSize = [900,104]
    m.rows.translation = [96,250]
    rShowRows(rows)
    m.rows.setFocus(true)
end sub

sub rShowPair(data as object)
    rReset("pairing")
    m.navigation.visible = false
    m.heading.text = "Sign in with your phone"
    m.pairing.visible = true
    m.pairAddress.text = RText(data.verification_uri)
    m.pairCode.text = RText(data.user_code)
    uri = RText(data.qr_uri)
    if left(uri,5) = "/api/" then uri = m.config.base+uri
    m.qr.uri = uri
    rShowActions([{title:"New code",action:"pair"}])
    m.actions.translation = [96,720]
    m.actions.setFocus(true)
end sub

sub rBootstrap(data as object)
    m.bootstrap = data
    m.management = data.profile_management
    m.preferences = data.preferences
    m.membership = data.library_membership
    m.revisions = data.revisions
    m.revisionDue = rNow()+30
    m.profile = RText(data.identity.profile_id)
    for each profile in RArray(data.profile_management.profiles)
        if profile.id = m.profile
            m.navigation.profileName = profile.name
            m.navigation.avatarUri = rAvatar(RText(profile.avatar_id))
        end if
    end for
    if m.profile = ""
        remembered = RText(m.config.last_profile_id)
        for each p in RArray(m.management.profiles)
            if p.id = remembered and p.locked <> true and p.selection_requires_parent <> true
                rSend("POST","/api/auth/profile",{profile_id:p.id},"auth:profile")
                return
            end if
        end for
        rProfiles(m.management)
    else
        rReset("home")
        if RObject(data.home)
            rHome(data.home)
        else
            rNavigate("home")
        end if
    end if
end sub

sub rProfiles(data as object)
    rReset("profiles")
    m.management = data
    m.navigation.visible = false
    m.heading.text = "Who's watching?"
    m.heading.translation = [96,220]
    m.heading.horizAlign = "center"
    m.heading.font.size = 56
    values = []
    for each p in RArray(data.profiles)
        values.push({title:p.name,subtitle:"",profile:p,action:"selectProfile",poster:rAvatar(RText(p.avatar_id))})
    end for
    visibleProfiles = values.count()
    if visibleProfiles > 5 then visibleProfiles = 5
    m.grid.translation = [int((1920-(visibleProfiles*256-56))/2),380]
    m.grid.itemSize = [200,276]
    m.grid.itemSpacing = [56,30]
    m.grid.numColumns = 5
    m.grid.numRows = 1
    m.grid.content = rContent(values,200,276,200,"poster")
    m.grid.visible = true
    m.grid.setFocus(true)
    actions = []
    if RGet(RGet(data.capabilities,"create",{}),"availability") = "Available" then actions.push({title:"Add profile",action:"createProfile"})
    if RGet(RGet(data.capabilities,"rename",{}),"availability") = "Available" then actions.push({title:"Manage profiles",action:"manageProfiles"})
    rShowActions(actions)
    m.actions.translation = [630,780]
    if values.count() = 0 then m.actions.setFocus(true)
end sub

function rAvatar(id as string) as string
    if id = "vynxc" or id = "zayne" then return "pkg:/images/design/remote-avatar-"+id+".png"
    return ""
end function

sub rHome(data as object)
    priorFocus = m.top.focusedChild
    priorCursor = m.shelves.rowItemFocused
    hadContent = m.shelves.visible and m.shelves.content <> invalid
    if RText(RGet(data.scope,"profile_id")) <> m.profile
        rError("The server returned a different profile. Try again.")
        return
    end if
    m.homeData = data
    m.homeDue = rNow()+2
    m.homeRows = RArray(data.rows)
    m.featured = RArray(data.featured)
    m.heroCard = data.hero
    if m.heroCard = invalid and m.featured.count() > 0 then m.heroCard = m.featured[0]
    if RCard(m.heroCard)
        rHero(m.heroCard)
        rHeroActions()
    end if
    root = CreateObject("roSGNode","ContentNode")
    sizes = []
    spaces = []
    for each row in m.homeRows
        shelf = root.createChild("ContentNode")
        shelf.title = RText(row.title)
        shelf.addFields({wire:row})
        if RGet(RGet(row,"view",{}),"card_shape") = "landscape"
            cards = rContent(RArray(row.cards),422,314,238)
            sizes.push([422.4,314])
            spaces.push([20,0])
        else
            cards = rContent(RArray(row.cards),255,459,383,"poster")
            sizes.push([255.2,459])
            spaces.push([16,0])
        end if
        shelf.appendChildren(cards.getChildren(-1,0))
    end for
    m.shelves.rowItemSize = sizes
    m.shelves.rowItemSpacing = spaces
    m.shelves.itemSize = [1728,551]
    m.shelves.content = root
    m.shelves.visible = root.getChildCount() > 0
    m.skeleton.visible = false
    readyCards = 0
    for each row in m.homeRows
        readyCards += RArray(row.cards).count()
    end for
    if data.complete <> true and readyCards = 0 then m.skeleton.visible = true
    if root.getChildCount() = 0 and m.heroCard = invalid then m.message.text = "Nothing to watch yet. Configure your sources in Settings."
    if hadContent and priorFocus <> invalid
        if priorCursor.count() = 2 and priorCursor[0] < root.getChildCount()
            if priorCursor[1] < root.getChild(priorCursor[0]).getChildCount() then m.shelves.jumpToRowItem = priorCursor
        end if
        priorFocus.setFocus(true)
    else
        rFocusContent()
    end if
end sub

sub rHeroActions()
    if not RCard(m.heroCard) then return
    savedIcon = "plus"
    if rIsSaved(m.heroCard) then savedIcon = "check"
    values = [{title:"Play",icon:"play",action:"play",card:m.heroCard,width:220,ring:false,heroAction:true}]
    if GetInterface(RGet(RGet(m.heroCard,"view",{}),"saved"),"ifBoolean") <> invalid then values.push({title:"",icon:savedIcon,action:"saveTitle",card:m.heroCard,width:72,ring:false,heroAction:true})
    values.push({title:"",icon:"info",action:"detail",card:m.heroCard,width:72,ring:false,heroAction:true})
    rShowActions(values)
end sub

sub rHeroReady()
    if m.route = "home" and not m.homeBrowsing and m.backdrop.loadStatus = "ready" then m.heroSlideDue = rNow()+8
end sub

sub rCarousel(now as double)
    if m.route <> "home" or m.homeBrowsing or m.drawer.visible or m.playback <> invalid or m.featured.count() < 2 then return
    if m.heroSlideDue = 0 then m.heroSlideDue = now+8
    if now >= m.heroSlideDue
        m.heroIndex = (m.heroIndex+1) mod m.featured.count()
        m.heroCard = m.featured[m.heroIndex]
        m.heroSlideDue = now+8
        rHero(m.heroCard)
        rHeroActions()
        m.top.findNode("heroArrival").control = "start"
    end if
    group = m.top.findNode("heroIndicators")
    group.visible = true
    if m.indicatorIndex = m.heroIndex and m.indicatorCount = m.featured.count() and m.indicatorFill <> invalid
        fraction = 1-(m.heroSlideDue-now)/8
        if fraction < 0 then fraction = 0
        if fraction > 1 then fraction = 1
        m.indicatorFill.width = int(48*fraction)
        return
    end if
    m.indicatorIndex = m.heroIndex
    m.indicatorCount = m.featured.count()
    group.removeChildrenIndex(group.getChildCount(),0)
    x = 0
    for i = 0 to m.featured.count()-1
        if i >= 12 then exit for
        width = 16
        if i = m.heroIndex then width = 48
        track = group.createChild("Rectangle")
        track.translation = [x,0]
        track.width = width
        track.height = 4
        track.color = "#F4F2EE59"
        if i = m.heroIndex
            fill = group.createChild("Rectangle")
            fill.translation = [x,0]
            fraction = 1-(m.heroSlideDue-now)/8
            if fraction < 0 then fraction = 0
            if fraction > 1 then fraction = 1
            fill.width = int(48*fraction)
            fill.height = 4
            fill.color = "#F4F2EE"
            m.indicatorFill = fill
        end if
        x += width+8
    end for
end sub

sub rHomeScroll(browse as boolean)
    top = 824
    if browse
        top = 545
        at = m.shelves.rowItemFocused
        if at.count() = 2 and m.shelves.content <> invalid
            row = m.shelves.content.getChild(at[0])
            if row <> invalid
                if RGet(RGet(row.wire,"view",{}),"card_shape") = "landscape" then top = 690
            end if
        end if
    end if
    motion = m.top.findNode("homeMotion")
    motion.control = "stop"
    m.top.findNode("homeSlide").keyValue = [m.shelves.translation,[96,top]]
    motion.control = "start"
    m.top.findNode("heroIndicators").visible = not browse and m.featured.count() > 1
end sub

sub rHero(card as object)
    m.hero.visible = true
    m.heroTitle.text = RText(card.title)
    m.heroMeta.text = RText(card.subtitle)
    m.heroDescription.text = RText(card.description)
    m.backdrop.translation = [0,0]
    m.backdrop.width = 1920
    m.backdrop.height = 1080
    m.top.findNode("scrimX").uri = "pkg:/images/design/remote-home-x.png"
    m.top.findNode("scrimY").uri = "pkg:/images/design/remote-home-y.png"
    m.top.findNode("scrimY").height = 1080
    m.heroTitle.font.size = 48
    m.heroTitle.translation = [96,306]
    m.heroTitle.height = 160
    m.heroLogo.translation = [96,306]
    m.heroLogo.width = 410
    m.heroLogo.height = 160
    m.heroMeta.translation = [96,494]
    m.heroDescription.translation = [96,546]
    m.heroDescription.height = 0
    m.heroDescription.maxLines = 2
    m.heroDescription.numLines = 0
    m.heroDescription.lineSpacing = 6
    if m.homeBrowsing = true
        m.backdrop.translation = [760,0]
        m.backdrop.width = 1160
        m.backdrop.height = 620
        m.top.findNode("scrimX").uri = "pkg:/images/design/remote-browse-x.png"
        m.top.findNode("scrimY").uri = "pkg:/images/design/remote-browse-y.png"
        m.top.findNode("scrimY").height = 620
        m.heroTitle.translation = [96,96]
        m.heroTitle.height = 120
        m.heroLogo.translation = [96,96]
        m.heroLogo.width = 420
        m.heroLogo.height = 120
        m.heroMeta.translation = [96,240]
        m.heroDescription.translation = [96,290]
        m.heroDescription.height = 0
        m.heroDescription.maxLines = 3
        m.heroDescription.numLines = 0
    else if m.route = "detail"
        m.top.findNode("scrimX").uri = "pkg:/images/design/remote-detail-x.png"
        if card.identity.kind = "series" then m.top.findNode("scrimX").uri = "pkg:/images/design/remote-series-x.png"
        m.top.findNode("scrimY").uri = "pkg:/images/design/remote-detail-y.png"
        top = 220
        height = 190
        meta = 432
        if card.identity.kind = "series"
            top = 250
            height = 134
            meta = 410
        end if
        m.heroTitle.translation = [96,top]
        m.heroTitle.height = height
        m.heroTitle.font.size = 52
        m.heroLogo.translation = [96,top]
        m.heroLogo.height = height
        m.heroMeta.translation = [96,meta]
        m.heroDescription.translation = [96,meta+50]
        m.heroDescription.height = 0
        m.heroDescription.maxLines = 3
        m.heroDescription.numLines = 0
    end if
    logo = RText(card.logo)
    if left(logo,5) = "/api/" then logo = m.config.base+logo
    m.heroLogo.uri = logo
    m.heroLogo.visible = logo <> ""
    m.heroTitle.visible = logo = ""
    uri = RText(card.landscape)
    if left(uri,5) = "/api/" then uri = m.config.base+uri
    m.backdrop.uri = uri
end sub

sub rShelfFocused()
    index = m.shelves.rowItemFocused
    if index.count() <> 2 or m.shelves.content = invalid then return
    row = m.shelves.content.getChild(index[0])
    if row = invalid then return
    item = row.getChild(index[1])
    if m.homeBrowsing = true and m.top.findNode("homeMotion").state <> "running"
        top = 545
        if RGet(RGet(row.wire,"view",{}),"card_shape") = "landscape" then top = 690
        m.shelves.translation = [96,top]
    end if
    if item <> invalid
        m.pendingHero = item.wire
        m.heroTick.control = "stop"
        m.heroTick.control = "start"
    end if
    if m.route = "home" and index[1] >= row.getChildCount()-3
        wire = row.wire
        cursor = RText(wire.next_cursor)
        if cursor <> "" and RObject(wire.browse)
            query = {}
            extras = []
            for each value in RArray(wire.browse.query)
                if value.id = "type" or value.id = "catalog" or value.id = "addon_id" or value.id = "connection_id"
                    if RArray(value.values).count() > 0 then query[value.id] = value.values[0]
                else
                    extras.push(value)
                end if
            end for
            query.skip = cursor
            if extras.count() > 0 then query.values = FormatJson(extras)
            rSend("GET","/api/discover?"+rQuery(query),invalid,"home:page:"+index[0].toStr(),{row:index[0],row_id:wire.id,cursor:cursor})
        end if
    end if
    if m.route = "detail" and index[0] = 0 and RObject(m.detailData)
        if index[1] >= row.getChildCount()-3 and RText(m.detailData.next_cursor) <> "" then rDetailPage(m.detailData.next_cursor,true)
    end if
end sub

sub rSettleHero()
    if m.route = "live"
        rLoadGuides()
        return
    end if
    if m.drawer.visible or m.playback <> invalid then return
    if RCard(m.pendingHero) and m.route = "home" then rHero(m.pendingHero)
end sub

sub rShelfSelected()
    index = m.shelves.rowItemSelected
    row = m.shelves.content.getChild(index[0])
    node = row.getChild(index[1])
    if node <> invalid
        if (m.route = "detail" and RObject(node.wire.identity.episode)) or (m.route = "home" and RGet(row.wire,"id") = "continue")
            rRun({action:"play",card:node.wire})
        else
            rDetail(node.wire,true)
        end if
    end if
end sub

sub rGridSelected()
    node = m.grid.content.getChild(m.grid.itemSelected)
    if node = invalid then return
    if m.route = "profiles"
        rRun(node.wire)
    else
        rDetail(node.wire,true)
    end if
end sub

sub rGridFocused()
    if m.grid.content = invalid then return
    if m.grid.itemFocused < m.grid.content.getChildCount()-14 then return
    if m.nextCursor = "" then return
    if m.pageCursors.doesExist(m.nextCursor) then return
    m.pageCursors[m.nextCursor] = true
    if m.route = "movie" or m.route = "series" or m.route = "anime"
        m.browseQuery.skip = m.nextCursor
        rBrowsePage()
    else if m.route = "library"
        m.libraryQuery.offset = m.nextCursor
        rSend("GET",rProfilePath("/library?"+rQuery(m.libraryQuery)),invalid,"library")
    end if
end sub

sub rRowSelected()
    node = m.rows.content.getChild(m.rows.itemSelected)
    if node <> invalid then rRun(node.wire)
end sub

sub rActionSelected()
    node = m.actions.content.getChild(m.actions.itemSelected)
    if node <> invalid then rRun(node.wire)
end sub

sub rFilterSelected()
    node = m.filters.content.getChild(m.filters.itemSelected)
    if node <> invalid then rRun(node.wire)
end sub

sub rDrawerSelected()
    node = m.drawerRows.content.getChild(m.drawerRows.itemSelected)
    if node <> invalid then rRun(node.wire)
end sub

sub rRun(value as object)
    action = RText(value.action)
    if action = "pair"
        rSend("POST","/api/auth/device/code",{device_name:"VIPTV Roku"},"auth:code")
    else if action = "password"
        rTextInput("Username","username",false,"")
    else if action = "server"
        rTextInput("Server address","server",false,m.config.base)
    else if action = "selectProfile"
        rSend("POST","/api/auth/profile",{profile_id:value.profile.id},"auth:profile")
    else if action = "profiles" or action = "settings" or action = "history"
        rCloseDrawer()
        rNavigate(action)
    else if action = "detail"
        rDetail(value.card,true)
    else if action = "play" or action = "sources" or action = "restart"
        m.playIntent = {explicit:action = "sources",restart:action = "restart"}
        rSend("POST",rProfilePath("/viewing-action"),{card:value.card,restart:action = "restart"},"viewing")
    else if action = "source"
        rStartSource(value.source)
    else if action = "saveTitle"
        card = value.card
        if GetInterface(RGet(RGet(card,"view",{}),"saved"),"ifBoolean") = invalid
            rError("This server needs an update to provide saved-title actions.")
            return
        end if
        if rIsSaved(card)
            suffix = "/library/"+REncode(card.identity.kind)+"/"+REncode(card.identity.id)
            if card.metadata_origin <> invalid then suffix += "?metadata_origin="+REncode(FormatJson(card.metadata_origin))+"&card="+REncode(FormatJson(card))
            rSend("DELETE",rProfilePath(suffix),invalid,"save:library")
        else
            rSend("PUT",rProfilePath("/library"),{card:card},"save:library")
        end if
    else if action = "season"
        rDetailPage(value.offset)
    else if action = "catalogs"
        values = []
        for each catalog in RArray(m.controls.catalogs)
            values.push({title:catalog.name,action:"catalog",catalog:catalog})
        end for
        rOpenDrawer("Catalog",values,"catalogs")
    else if action = "catalog"
        m.browseQuery = {type:m.route,catalog:value.catalog.id,skip:"0"}
        if value.catalog.addon_id <> invalid then m.browseQuery.addon_id = value.catalog.addon_id.toStr()
        m.selectedCatalog = value.catalog
        m.cards = []
        rCloseDrawer()
        rBrowseFilters()
        rBrowsePage()
    else if action = "queryControl"
        m.controlDraft = value.control
        m.selectedValues = []
        values = [{title:"Apply",action:"applyFilter"}]
        for each choice in RArray(value.control.choices)
            values.push({title:choice.label,action:"filterValue",value:choice.value})
        end for
        if values.count() = 1
            rTextInput(value.control.label,"filter",false,"")
        else
            rOpenDrawer(value.control.label,values,"filter")
        end if
    else if action = "libraryFilters"
        values = []
        for each control in RArray(m.libraryControls)
            values.push({title:control.label,action:"queryControl",control:control})
        end for
        rOpenDrawer("Filters",values,"libraryFilters")
    else if action = "filterValue"
        rToggleFilter(value.value)
    else if action = "applyFilter"
        rApplyFilter()
    else if action = "liveChannel"
        m.liveChannel = value.channel
        m.playCard = value.channel.card
        rSend("POST",rProfilePath("/live/"+REncode(value.channel.id)+"/sources"),{connection_id:value.channel.connection_id},"live:sources")
    else if action = "liveGroup"
        m.liveQuery = ""
        if value.id <> "" then m.liveQuery = "&group_id="+REncode(value.id)
        rSend("GET",rProfilePath("/live/channels?limit=100"+m.liveQuery),invalid,"live")
    else if action = "retry"
        if m.failedRequest <> invalid
            q = m.failedRequest
            rSend(q.method,q.path,q.body,q.tag,q.context)
        end if
    else if action = "calendarDay"
        m.calendarDay = value.date
        m.calendarEntries = []
        m.calendarCursor = ""
        m.pending.delete("calendar")
        rCalendarFetch("")
    else if action = "calendarWeek"
        m.calendarOffset += value.offset
        m.pending.delete("calendar")
        rCalendarWeek()
    else if action = "calendarType"
        if m.calendarType = "series" then m.calendarType = "anime" else m.calendarType = "series"
        m.pending.delete("calendar")
        rCalendarWeek()
    else
        rSettingsAction(value)
    end if
end sub

function rIsSaved(card as object) as boolean
    return RGet(RGet(card,"view",{}),"saved",false) = true
end function

sub rDetail(card as object, push as boolean)
    if not RCard(card) then return
    if card.identity.kind = "live"
        m.playCard = card
        rSend("POST",rProfilePath("/live/"+REncode(card.identity.id)+"/sources"),{},"live:sources")
        return
    end if
    if push then rPush()
    rReset("detail")
    m.detailCard = card
    rHero(card)
    rDetailActions(card)
    m.actions.setFocus(true)
    rDetailPage(0)
end sub

sub rDetailActions(card as object, action = invalid as dynamic)
    label = RText(RGet(action,"label"),"Play")
    width = 260
    if RGet(action,"resume",false) then width = 420
    values = [{title:label,icon:"play",action:"play",card:card,width:width,ring:false,heroAction:true}]
    if GetInterface(RGet(RGet(card,"view",{}),"saved"),"ifBoolean") <> invalid
        icon = "plus"
        if rIsSaved(card) then icon = "check"
        values.push({title:"",icon:icon,action:"saveTitle",card:card,width:72,ring:false,heroAction:true})
    end if
    values.push({title:"",icon:"source",action:"sources",card:card,width:72,ring:false,heroAction:true})
    if RGet(action,"resume",false) then values.push({title:"",icon:"restart",action:"restart",card:card,width:72,ring:false,heroAction:true})
    rShowActions(values)
    if card.identity.kind = "series" then m.actions.translation = [96,648] else m.actions.translation = [96,668]
end sub

sub rDetailPage(offset as dynamic, appendPage = false as boolean)
    card = m.detailCard
    identity = RGet(card,"parent_identity",card.identity)
    cursor = RText(offset)
    if cursor = "" then cursor = offset.toStr()
    query = {offset:cursor,limit:"24"}
    if card.metadata_origin <> invalid
        expectation = ParseJson(FormatJson(card))
        expectation.identity = identity
        expectation.parent_identity = invalid
        query.metadata_origin = FormatJson(card.metadata_origin)
        query.card = FormatJson(expectation)
    else
        query.provider_id = card.provider_id
    end if
    rSend("GET","/api/meta/"+REncode(identity.kind)+"/"+REncode(identity.id)+"?"+rQuery(query),invalid,"detail",{append:appendPage,cursor:cursor})
end sub

function rQuery(query as object) as string
    values = []
    for each key in query
        values.push(REncode(key)+"="+REncode(query[key]))
    end for
    return values.join("&")
end function

sub rBrowsePage()
    rSend("GET","/api/discover?"+rQuery(m.browseQuery),invalid,"browse")
end sub

sub rBrowseFilters()
    values = []
    if RArray(m.controls.catalogs).count() > 0 then values.push({title:"Catalog",action:"catalogs"})
    controls = RArray(m.controls.controls)
    if RObject(m.selectedCatalog) then controls = RArray(m.selectedCatalog.controls)
    for each control in controls
        values.push({title:control.label,action:"queryControl",control:control})
    end for
    m.filters.content = rContent(values,260,64)
    m.filters.visible = values.count() > 0
end sub

sub rToggleFilter(value as string)
    found = -1
    for i = 0 to m.selectedValues.count()-1
        if m.selectedValues[i] = value then found = i
    end for
    if found >= 0
        m.selectedValues.delete(found)
    else if m.controlDraft.kind <> "MultiChoice"
        m.selectedValues = [value]
    else
        limit = RGet(m.controlDraft,"maximum_selections",64)
        if m.selectedValues.count() < limit then m.selectedValues.push(value)
    end if
    m.drawerMessage.text = m.selectedValues.count().toStr()+" selected"
end sub

sub rApplyFilter()
    if m.route = "library"
        if m.selectedValues.count() > 0 then m.libraryQuery[m.controlDraft.id] = m.selectedValues[0] else m.libraryQuery.delete(m.controlDraft.id)
        m.libraryQuery.offset = "0"
        m.cards = []
        m.pageCursors = {}
        rCloseDrawer()
        rSend("GET",rProfilePath("/library?"+rQuery(m.libraryQuery)),invalid,"library")
        return
    end if
    values = []
    if RText(m.browseQuery.values) <> "" then values = RArray(ParseJson(m.browseQuery.values))
    updated = []
    for each value in values
        if value.id <> m.controlDraft.id then updated.push(value)
    end for
    updated.push({id:m.controlDraft.id,values:m.selectedValues})
    m.browseQuery.values = FormatJson(updated)
    m.browseQuery.skip = "0"
    m.cards = []
    m.pageCursors = {}
    rCloseDrawer()
    rBrowsePage()
end sub

sub rPageResponse(tag as string, data as dynamic, request as object)
    m.skeleton.visible = false
    if tag = "home"
        rHome(data)
    else if tag = "state:revisions"
        changed = m.revisions <> invalid and FormatJson(m.revisions) <> FormatJson(data)
        m.revisions = data
        if changed
            m.snapshots = []
            if m.route = "home" and not m.drawer.visible then rSend("GET",rProfilePath("/home"),invalid,"home")
            if m.route <> "home" then m.homeData = invalid
        end if
    else if left(tag,10) = "home:page:"
        row = m.shelves.content.getChild(request.context.row)
        if row <> invalid
            wire = row.wire
            if wire.next_cursor = request.context.cursor and wire.id = request.context.row_id
                extra = rContent(RArray(data.cards),320,252,180)
                row.appendChildren(extra.getChildren(-1,0))
                wire.next_cursor = data.next_cursor
                wire.cards.append(RArray(data.cards))
                while wire.cards.count() > 200
                    wire.cards.shift()
                end while
                row.wire = wire
                m.homeData.rows[request.context.row] = wire
                ' Keep a bounded native row window; back navigation refetches.
                if row.getChildCount() > 200 then row.removeChildrenIndex(row.getChildCount()-200,0)
            end if
        end if
    else if tag = "profiles"
        rProfiles(data)
    else if tag = "controls"
        m.controls = data
        m.selectedCatalog = invalid
        rBrowseFilters()
    else if tag = "browse" or tag = "library"
        if not RCards(data.cards)
            rError("The server returned an invalid catalog.")
            return
        end if
        selectedKey = ""
        if m.grid.content <> invalid
            focused = m.grid.content.getChild(m.grid.itemFocused)
            if focused <> invalid and RCard(focused.wire) then selectedKey = RIdentityKey(focused.wire)
        end if
        m.cards.append(data.cards)
        while m.cards.count() > 300
            m.cards.shift()
        end while
        m.nextCursor = RText(data.next_cursor)
        m.grid.content = rContent(m.cards,232,410,348,"poster")
        for i = 0 to m.cards.count()-1
            if RIdentityKey(m.cards[i]) = selectedKey then m.grid.jumpToItem = i
        end for
        m.grid.visible = true
        if m.restoreIndex <> invalid
            if m.restoreIndex < m.cards.count() then m.grid.jumpToItem = m.restoreIndex
            m.restoreIndex = invalid
        end if
        if m.cards.count() = 0 then m.message.text = "No titles found."
        if tag = "library"
            m.libraryControls = data.controls
            m.filters.content = rContent([{title:"Filters",action:"libraryFilters"}],260,64)
            m.filters.visible = RArray(data.controls).count() > 0
        end if
    else if tag = "detail"
        if not RCard(data.item)
            rError("The server returned invalid title details.")
            return
        end if
        position = m.shelves.rowItemFocused
        if RGet(request.context,"append",false) and RObject(m.detailData)
            episodes = RArray(m.detailData.episodes)
            episodes.append(RArray(data.episodes))
            while episodes.count() > 300
                episodes.shift()
            end while
            data.episodes = episodes
        end if
        rHero(data.item)
        if m.detailCard.identity.episode = invalid then m.detailCard = data.item else m.detailCard.view = data.item.view
        if not RGet(request.context,"append",false)
            rDetailActions(m.detailCard)
            rSend("POST",rProfilePath("/viewing-action"),{card:m.detailCard,restart:false},"detail:action")
        end if
        m.detailData = data
        root = CreateObject("roSGNode","ContentNode")
        if RArray(data.episodes).count() > 0
            row = root.createChild("ContentNode")
            row.title = "Episodes"
            items = rContent(data.episodes,320,252,180)
            row.appendChildren(items.getChildren(-1,0))
        end if
        if RArray(data.recommendations).count() > 0
            row = root.createChild("ContentNode")
            row.title = "More like this"
            items = rContent(data.recommendations,320,252,180)
            row.appendChildren(items.getChildren(-1,0))
        end if
        m.shelves.content = root
        if RGet(request.context,"append",false) and position.count() = 2 then m.shelves.jumpToRowItem = position
        m.shelves.visible = root.getChildCount() > 0
        seasons = []
        for each season in RArray(data.seasons)
            label = "Episodes"
            if season.season <> invalid then label = "Season "+season.season.toStr()
            seasons.push({title:label,action:"season",offset:season.offset})
        end for
        m.filters.content = rContent(seasons,260,64)
        m.filters.translation = [96,700]
        m.filters.visible = seasons.count() > 1
    else if tag = "detail:action"
        rDetailActions(m.detailCard,data)
    else if tag = "calendar"
        rCalendar(data,request)
    else if tag = "history"
        entries = RArray(data)
        m.historyEntries.append(entries)
        m.historyMore = entries.count() = 100
        m.historyOffset += entries.count()
        while m.historyEntries.count() > 300
            m.historyEntries.shift()
        end while
        values = []
        for each entry in m.historyEntries
            values.push({title:entry.card.title,subtitle:RText(entry.date,RText(entry.card.subtitle)),action:"detail",card:entry.card})
        end for
        rShowRows(values)
        m.filters.content = rContent([{title:"Clear history",action:"confirmClearHistory"}],260,64)
        m.filters.visible = values.count() > 0
        m.rows.translation = [96,360]
        if values.count() = 0 then m.message.text = "Nothing here yet."
    else if tag = "search"
        root = CreateObject("roSGNode","ContentNode")
        for each group in RArray(data.rows)
            row = root.createChild("ContentNode")
            row.title = group.title
            items = rContent(RArray(group.cards),212,394,318,"poster")
            row.appendChildren(items.getChildren(-1,0))
        end for
        m.heading.text = ""
        m.shelves.translation = [700,140]
        m.shelves.itemSize = [1124,460]
        m.shelves.rowItemSize = [[212,394]]
        m.shelves.rowItemSpacing = [[16,0]]
        m.shelves.content = root
        m.shelves.visible = true
        if root.getChildCount() = 0 then m.message.text = "No results found."
    else if tag = "live"
        rLive(data)
    else if tag = "live:page"
        rLivePage(data,request)
    else if left(tag,11) = "live:guide:"
        rLiveGuide(data,request)
    else if tag = "live:sources"
        m.playIntent = {explicit:true,restart:false}
        m.viewingAction = {resume:false,card:m.playCard}
        rShowSources(RArray(data.streams))
    else if tag = "viewing"
        m.viewingAction = data
        m.playCard = data.card
        rDiscoverSources(data.card)
    else if tag = "sources:start"
        m.discovery = {id:data.id,after:0,due:0,streams:[],done:false}
    else if tag = "sources:poll"
        if m.discovery = invalid then return
        for each event in RArray(data.events)
            for each source in RArray(event.streams)
                found = false
                for i = 0 to m.discovery.streams.count()-1
                    if m.discovery.streams[i].id = source.id
                        m.discovery.streams[i] = source
                        found = true
                        exit for
                    end if
                end for
                if not found and m.discovery.streams.count() < 500 then m.discovery.streams.push(source)
            end for
        end for
        m.discovery.after += RArray(data.events).count()
        m.discovery.done = data.done = true
        rRankSources()
        if m.discovery.done then m.discovery.due = 9999999999#
    else if tag = "sources:rank"
        if m.discovery <> invalid
            if RGet(request.context,"after") <> m.discovery.after or RGet(request.context,"quality") <> m.sourceQuality
                rRankSources()
                return
            end if
        end if
        rShowSources(RArray(data.streams))
        filters = [{title:"All "+RGet(data,"total",0).toStr(),height:invalid,width:140}]
        for each filter in RArray(data.quality_filters)
            filters.push({title:filter.label+" "+filter.count.toStr(),height:filter.height,width:140})
        end for
        m.sourceFilters.content = rContent(filters,140,52)
        m.sourceFilters.visible = true
        m.drawerRows.translation = [64,278]
        ' Server preference authorizes best-match, and the server ranking is
        ' authoritative. Wait for discovery completion; never rank locally.
        if m.discovery <> invalid and m.discovery.done and m.playIntent.explicit <> true and m.viewingAction.source_selection = "best"
            for each source in RArray(data.streams)
                if source.id = data.best_match_id then rStartSource(source)
            end for
        end if
    else
        rSettingsResponse(tag,data,request)
    end if
end sub

sub rDiscoverSources(card as object)
    rCancelDiscovery()
    rOpenDrawer("Sources",[],"sources")
    m.drawerSubtitle.text = card.title
    m.drawerMessage.text = "Finding sources…"
    m.sourceQuality = invalid
    body = RMetadataFields(card)
    body.type = card.identity.kind
    body.id = card.identity.id
    if RObject(card.identity.episode)
        body.season = card.identity.episode.season
        body.episode = card.identity.episode.episode
    end if
    if card.parent_identity <> invalid then body.series_id = card.parent_identity.id
    rSend("POST","/api/streams",body,"sources:start",{source_epoch:m.sourceEpoch})
end sub

sub rRankSources()
    if m.discovery = invalid then return
    ids = []
    for each source in m.discovery.streams
        ids.push(source.id)
    end for
    body = {ids:ids,device_max_height:m.config.capabilities.max_height}
    if m.sourceQuality <> invalid then body.quality_height = m.sourceQuality
    rSend("POST",rProfilePath("/source-ranking"),body,"sources:rank",{source_epoch:m.sourceEpoch,after:m.discovery.after,quality:m.sourceQuality})
end sub

sub rShowSources(sources as object)
    if not m.drawer.visible then rOpenDrawer("Sources",[],"sources")
    selectedId = ""
    if m.drawerRows.content <> invalid
        focused = m.drawerRows.content.getChild(m.drawerRows.itemFocused)
        if focused <> invalid then selectedId = RText(RGet(RGet(focused.wire,"source",{}),"id"))
    end if
    values = []
    for each source in sources
        p = RGet(source,"presentation",{})
        detail = []
        for each field in ["video_codec","size_label"]
            if RText(p[field]) <> "" then detail.push(p[field])
        end for
        values.push({title:RText(source.name,RText(source.label,RText(p.provider_name,"Source"))),subtitle:RText(source.detail,detail.join(" · ")),action:"source",source:source,ring:false})
    end for
    focus = m.drawerRows.itemFocused
    for i = 0 to values.count()-1
        if values[i].source.id = selectedId then focus = i
    end for
    m.drawerRows.content = rContent(values,800,104)
    if focus >= 0 and focus < values.count() then m.drawerRows.jumpToItem = focus
    m.drawerMessage.text = ""
    if m.discovery <> invalid and not m.discovery.done then m.drawerMessage.text = "Finding more sources…"
    if values.count() = 0 then m.drawerMessage.text = "No sources are available."
end sub

sub rSourceFilterSelected()
    node = m.sourceFilters.content.getChild(m.sourceFilters.itemSelected)
    if node = invalid then return
    if m.drawerKind = "episodes"
        rPlayerEpisodes(node.wire.offset.toStr(),false)
        return
    end if
    m.sourceQuality = node.wire.height
    m.playIntent.explicit = true
    rRankSources()
end sub

sub rCancelDiscovery()
    m.sourceEpoch++
    for each worker in m.workers
        if left(worker.request.tag,8) = "sources:"
            if worker.request.method = "GET" then worker.cancel = true
            if m.pending[worker.request.tag] = worker.request.request_id then m.pending.delete(worker.request.tag)
        end if
    end for
    retained = []
    for each queued in m.queue
        if left(queued.tag,8) = "sources:"
            m.pending.delete(queued.tag)
        else
            retained.push(queued)
        end if
    end for
    m.queue = retained
    if m.discovery <> invalid
        rSend("DELETE","/api/streams/"+REncode(m.discovery.id),invalid,"cleanup:discovery")
        m.discovery = invalid
    end if
end sub
