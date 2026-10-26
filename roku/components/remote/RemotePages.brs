sub rWelcome()
    rReset("welcome")
    m.navigation.visible = false
    m.top.findNode("entry").mode = "welcome"
    m.top.findNode("entry").visible = true
    rShowActions([{title:"Sign in",action:"signInChoice",width:360,entrySignIn:true}])
    m.actions.translation = [780,584]
    m.actions.setFocus(true)
end sub

sub rSignInChoice()
    rReset("choice")
    m.navigation.visible = false
    m.heading.text = ""
    m.top.findNode("entryHeading").visible = true
    m.heading.translation = [96,96]
    m.heading.font.size = 56
    m.top.findNode("entry").mode = "choice"
    m.top.findNode("entry").visible = true
    rows = [{title:"Use your phone",subtitle:"Scan a QR code — quickest",action:"pair",icon:"entry-phone",entryOption:true},{title:"Use a browser",subtitle:"Go to a web address and type a code",action:"pair",icon:"entry-browser",entryOption:true},{title:"Use a password",action:"password",icon:"entry-password",entryOption:true}]
    m.rows.itemSize = [908,108]
    m.rows.itemSpacing = [0,8]
    m.rows.translation = [92,246]
    m.rows.content = rContent(rows,900,100)
    m.rows.visible = true
    m.rows.setFocus(true)
end sub

sub rShowPair(data as object)
    rReset("pairing")
    m.navigation.visible = false
    m.heading.text = ""
    m.top.findNode("entryHeading").visible = true
    m.heading.translation = [96,96]
    m.heading.font.size = 56
    m.pairing.visible = true
    m.entryServer.visible = m.config.locked <> true
    m.entryServer.content = rContent([{title:"Use another server",action:"server",icon:"remote-server",width:420}],420,72)
    m.pairAddress.text = RText(data.verification_uri).replace("https://","")
    m.pairCode.text = RText(data.user_code)
    m.pairCode.size = 72
    if m.pairCode.text = ""
        m.pairCode.text = "Waiting"
        m.pairCode.size = 36
        m.top.findNode("pairWaiting").text = "Creating your sign-in code…"
    else
        m.top.findNode("pairWaiting").text = "Waiting for you to sign in…"
    end if
    rPairExpiry()
    ' The QR is an accelerator, never the only way in: the address and code are
    ' always readable, and a card that failed to load must not paint as a blank
    ' white box.
    m.top.findNode("pairQrFrame").visible = false
    m.top.findNode("pairQrHint").visible = false
    m.qr.uri = ""
    uri = RText(data.qr_uri)
    if left(uri,1) = "/" then uri = m.config.base+uri
    m.qrPending = uri
    m.qrRetried = false
    if left(uri,8) = "https://" or left(uri,7) = "http://"
        agent = CreateObject("roHttpAgent")
        agent.setCertificatesFile("common:/certs/ca-bundle.crt")
        m.qr.setHttpAgent(agent)
        m.qr.uri = uri
    else
        ' No scannable code from the server: say so instead of leaving a hole
        ' where the card would be.
        hint = m.top.findNode("pairQrHint")
        hint.visible = true
        hint.text = "Open "+m.pairAddress.text+" on your phone and enter the code shown here."
    end if
    rShowActions([{title:"New code",action:"pair",icon:"restart",width:180}])
    m.actions.translation = [1380,676]
    m.actions.setFocus(true)
end sub

sub rBootstrap(data as object)
    scope = {base:m.config.base,account_id:RText(data.identity.account_id),profile_id:RText(data.identity.profile_id)}
    sameScope = RObject(m.bootstrap) and REqual(m.bootstrapScope,scope)
    if not sameScope and RObject(m.bootstrap)
        rStopPlayer()
        m.epoch++
        rClearProfileViews()
    end if
    m.bootstrapScope = scope
    m.bootstrap = data
    rNavigation(data.navigation)
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
    if sameScope
        m.profilesRefreshPending = m.route = "profiles"
        if RObject(data.home)
            m.homeData = data.home
            m.homeRefreshPending = m.route = "home"
        end if
        return
    end if
    if m.profile = ""
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
    focusedId = ""
    if m.route = "profiles" and m.shelves.content <> invalid
        at = m.shelves.rowItemFocused
        if at.count() = 2
            row = m.shelves.content.getChild(at[0])
            if row <> invalid
                node = row.getChild(at[1])
                if node <> invalid then focusedId = RText(RGet(RGet(node.wire,"profile"),"id"))
            end if
        end if
    end if
    m.profilesRefreshPending = false
    rReset("profiles")
    m.management = data
    m.navigation.visible = false
    m.heading.text = "Who's watching?"
    m.heading.translation = [96,220]
    m.heading.width = 1728
    m.heading.horizAlign = "center"
    m.heading.font.size = 56
    values = []
    for each p in RArray(data.profiles)
        values.push({title:p.name,subtitle:"",profile:p,action:"selectProfile",poster:rAvatar(RText(p.avatar_id))})
    end for
    visibleProfiles = values.count()
    if visibleProfiles < 1 then visibleProfiles = 1
    if visibleProfiles > 5 then visibleProfiles = 5
    m.grid.translation = [int((1920-(visibleProfiles*256-56))/2),380]
    m.grid.itemSize = [200,276]
    m.grid.itemSpacing = [56,30]
    m.grid.numColumns = 5
    m.grid.numRows = 1
    m.grid.content = rContent(values,200,276,200,"poster")
    ' One virtualized horizontal row, including accounts with more than five
    ' profiles. Down always reaches management, never a second profile grid row.
    root = CreateObject("roSGNode","ContentNode")
    row = root.createChild("ContentNode")
    row.appendChildren(rContent(values,200,276,200,"poster").getChildren(-1,0))
    m.shelves.showRowLabel = [false]
    m.shelves.numRows = 1
    m.shelves.itemSize = [visibleProfiles*256-56,276]
    m.shelves.rowItemSize = [[200,276]]
    m.shelves.rowItemSpacing = [[56,0]]
    m.shelves.translation = m.grid.translation
    m.shelves.content = root
    for i = 0 to values.count()-1
        if values[i].profile.id = focusedId then m.shelves.jumpToRowItem = [0,i]
    end for
    m.shelves.visible = values.count() > 0
    m.shelves.setFocus(true)
    actions = []
    if RGet(RGet(data.capabilities,"create",{}),"availability") = "Available" then actions.push({title:"Add profile",action:"createProfile"})
    if RGet(RGet(data.capabilities,"rename",{}),"availability") = "Available" then actions.push({title:"Manage profiles",action:"manageProfiles"})
    rShowActions(actions, true, 1728)
    m.actions.translation = [96,780]
    if values.count() = 0 then m.actions.setFocus(true)
end sub

function rAvatar(id as string) as string
    if id = "vynxc" or id = "zayne" then return "pkg:/images/design/remote-avatar-"+id+".png"
    return ""
end function

sub rHome(data as object, restore = invalid as dynamic)
    m.homeRefreshPending = false
    if RText(RGet(data.scope,"profile_id")) <> m.profile
        rError("The server returned a different profile. Try again.")
        return
    end if
    wasFocused = m.shelves.isInFocusChain()
    selection = m.homeFocus
    if RObject(restore) then selection = restore
    if wasFocused then selection = rHomeSelection()
    m.homeRenderVersion++
    m.pendingHomeHero = invalid
    m.heroTick.control = "stop"
    m.homeRebuilding = true
    m.homeData = data
    m.homeDue = rNow()+2
    m.homeRows = []
    for each row in RArray(data.rows)
        state = RText(RGet(row,"state"))
        if RArray(row.cards).count() > 0 or state = "Pending" or state = "Failed" then m.homeRows.push(row)
    end for
    m.featured = RArray(data.featured)
    m.heroCard = data.hero
    if m.heroCard = invalid and m.featured.count() > 0 then m.heroCard = m.featured[0]
    if not m.homeBrowsing and RCard(m.heroCard)
        rHero(m.heroCard)
        rHeroActions()
    end if
    root = m.shelves.content
    reuse = root <> invalid and m.shelves.visible
    if reuse then reuse = root.getChildCount() = m.homeRows.count()
    if reuse
        for i = 0 to m.homeRows.count()-1
            old = root.getChild(i).wire
            if old.id <> m.homeRows[i].id or not REqual(old.view,m.homeRows[i].view) then reuse = false
        end for
    end if
    if not reuse then root = CreateObject("roSGNode","ContentNode")
    sizes = []
    spaces = []
    heights = []
    gaps = []
    changed = not reuse
    readyCards = 0
    for i = 0 to m.homeRows.count()-1
        row = m.homeRows[i]
        shelf = root.getChild(i)
        if not reuse then shelf = root.createChild("ContentNode")
        readyCards += RArray(row.cards).count()
        landscape = RGet(RGet(row,"view",{}),"card_shape") = "landscape"
        if landscape
            sizes.push([422.4,314])
            spaces.push([20,0])
        else
            sizes.push([255.2,459])
            spaces.push([16,0])
        end if
        if not reuse or not REqual(shelf.wire,row)
            cards = invalid
            state = RText(RGet(row,"state"))
            if state = "Pending"
                if landscape
                    cards = rContent(rHomeSkeletonCards(),422,314,238)
                else
                    cards = rContent(rHomeSkeletonCards(),255,459,383,"poster")
                end if
            else if state = "Failed"
                cards = rContent([{title:"Couldn’t load this row",subtitle:RText(RGet(row,"message"),"This row is unavailable."),action:"retry",homeRowRetry:true,width:940}],940,221,0)
            else
                describe = "metadata"
                if RText(RGet(row,"id")) = "continue" then describe = "subtitle"
                if landscape
                    cards = rContent(RArray(row.cards),422,314,238,"landscape",describe)
                else
                    cards = rContent(RArray(row.cards),255,459,383,"poster",describe)
                end if
            end if
            shelf.removeChildrenIndex(shelf.getChildCount(),0)
            shelf.appendChildren(cards.getChildren(-1,0))
            shelf.title = RText(row.title)
            if not shelf.hasField("wire") then shelf.addFields({wire:row,homeTitleHeight:40}) else shelf.wire = row
            changed = true
        end if
        rowHeight = sizes[sizes.count()-1][1]+52
        if RText(RGet(row,"state")) = "Failed" then rowHeight = 273
        heights.push(rowHeight)
        gaps.push(40)
    end for
    if not reuse
        m.shelves.rowLabelOffset = [[0,12]]
        m.shelves.rowHeights = heights
        m.shelves.rowSpacings = gaps
        m.shelves.rowItemSize = sizes
        m.shelves.rowItemSpacing = spaces
        m.shelves.itemSize = [1824,551]
        m.top.findNode("shelfClip").clippingRect = [80,0,1840,1080]
        m.shelves.content = root
    end if
    m.shelves.visible = root.getChildCount() > 0
    m.skeleton.visible = data.complete <> true and readyCards = 0 and root.getChildCount() = 0
    m.homeRebuilding = false
    if root.getChildCount() = 0 and m.heroCard = invalid
        if data.complete = true
            m.message.text = "No catalogs configured"
            m.message.translation = [96,300]
            m.message.width = 1000
            m.message.font.size = 32
            m.retryBar.content = rContent([{title:"Open settings",action:"settings",width:300}],300,72)
            m.retryBar.translation = [96,392]
            m.retryBar.visible = true
            m.retryBar.setFocus(true)
        else if data.complete <> true
            m.navigation.setFocus(true)
        end if
    end if
    if readyCards = 0 and not RCard(m.heroCard)
        if root.getChildCount() > 0
            m.homeBrowsing = true
            rHomeScroll(true)
            m.actions.visible = false
            m.shelves.setFocus(true)
        else
            m.homeBrowsing = false
            rHomeScroll(false)
            m.actions.visible = false
            if not m.retryBar.visible then m.navigation.setFocus(true)
        end if
        return
    end if
    target = rHomeTarget(selection)
    if target.count() = 2
        if changed or RObject(restore)
            m.homeExpectedFocus = target
            m.shelves.jumpToRowItem = target
            ' A no-op jump may not emit a native field event. Acknowledge only
            ' when the observed index already matches the intended identity.
            rShelfFocused()
        end if
        m.homeFocus = rHomeSelection(target)
    else if m.homeBrowsing
        rHomeLeaveShelves()
    end if
    if m.homeBrowsing
        m.actions.visible = false
        rHomeApply(true)
        if wasFocused or RObject(restore) or not RCard(m.heroCard) then m.shelves.setFocus(true)
        rShelfFocused()
    else if not wasFocused and not reuse
        ' Arriving on Home always starts on the billboard. Focusing the shelves
        ' here skipped the hero-to-shelf transition and left the remote on a row
        ' that was still half off-screen, so Down could not enter it.
        if RCard(m.heroCard)
            rHomeApply(false)
            if m.actions.visible and m.actions.content <> invalid then m.actions.setFocus(true) else m.navigation.setFocus(true)
        else
            rHomeEnterShelves()
        end if
    end if
end sub

function rHomeSkeletonCards() as object
    cards = []
    for i = 0 to 5
        cards.push({title:"",subtitle:"",homeSkeleton:true})
    end for
    return cards
end function

function rHomeSelection(index = invalid as dynamic) as dynamic
    if index = invalid then index = m.shelves.rowItemFocused
    if RArray(index).count() <> 2 or m.shelves.content = invalid then return invalid
    row = m.shelves.content.getChild(index[0])
    if row = invalid then return invalid
    node = row.getChild(index[1])
    if node = invalid or not RCard(node.wire) then return invalid
    return {row_id:row.wire.id,key:RIdentityKey(node.wire),index:index}
end function

function rHomeTarget(selection as dynamic) as object
    root = m.shelves.content
    if root = invalid or root.getChildCount() = 0 then return []
    rowIndex = 0
    itemIndex = 0
    if RObject(selection)
        rowIndex = selection.index[0]
        itemIndex = selection.index[1]
        for i = 0 to root.getChildCount()-1
            if root.getChild(i).wire.id = selection.row_id then rowIndex = i
        end for
    end if
    if rowIndex >= root.getChildCount() then rowIndex = root.getChildCount()-1
    row = root.getChild(rowIndex)
    if row.getChildCount() = 0
        for i = 0 to root.getChildCount()-1
            if root.getChild(i).getChildCount() > 0
                rowIndex = i
                row = root.getChild(i)
                exit for
            end if
        end for
    end if
    if row.getChildCount() = 0 then return []
    if itemIndex >= row.getChildCount() then itemIndex = row.getChildCount()-1
    if RObject(selection)
        for i = 0 to row.getChildCount()-1
            if RIdentityKey(row.getChild(i).wire) = selection.key then itemIndex = i
        end for
    end if
    return [rowIndex,itemIndex]
end function

sub rHomeEnterShelves()
    rHomeApply(true)
    m.shelves.setFocus(true)
    rShelfFocused()
end sub

sub rHomeLeaveShelves()
    m.homeBrowsing = false
    m.pendingHomeHero = invalid
    m.heroTick.control = "stop"
    rHomeApply(false)
    if RCard(m.heroCard)
        m.actions.setFocus(true)
    else
        m.navigation.setFocus(true)
    end if
end sub

' One owner for Home's layout. The hero composition, the shelf offset and the
' action bar always describe the same focus state, so a restored route can
' never leave the hero painted for browsing while the shelves sit at their
' settled position.
sub rHomeApply(browsing as boolean)
    ' A late Home response must never repaint a different route's layout.
    if m.route <> "home" then return
    m.homeBrowsing = browsing
    m.actions.visible = not browsing and RCard(m.heroCard)
    rHomeScroll(browsing)
    if RCard(m.heroCard) then rHero(m.heroCard)
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

' Detail page planes. The title summary and its action row occupy the top of the
' page; the episode row only grows into that space when it has focus, and the
' action row steps aside instead of being painted over by the cards.
sub rDetailLayout(episodeFocus as boolean)
    if m.route <> "detail" then return
    resting = 888
    browsing = 660
    if not m.shelves.visible then return
    m.detailEpisodes = episodeFocus
    m.actions.visible = not episodeFocus and m.actions.content <> invalid
    if m.filters.visible then
        m.filters.translation = [96,816]
        if episodeFocus then m.filters.translation = [96,588]
    end if
    top = resting
    if episodeFocus then top = browsing
    motion = m.top.findNode("homeMotion")
    slide = m.top.findNode("homeSlide")
    if not REqual(slide.keyValue[1],[96,top]) or (motion.state <> "running" and not REqual(m.shelves.translation,[96,top]))
        motion.control = "stop"
        slide.keyValue = [m.shelves.translation,[96,top]]
        motion.control = "start"
    end if
end sub

sub rDetailScroll(episodeFocus as boolean)
    rDetailLayout(episodeFocus)
end sub

sub rHomeScroll(browse as boolean)
    if m.route <> "home" then return
    m.navigation.focusable = not browse
    navOpacity = 1
    if browse then navOpacity = 0
    navMotion = m.top.findNode("homeNavMotion")
    fade = m.top.findNode("homeNavFade")
    if fade.keyValue[1] <> navOpacity or (navMotion.state <> "running" and m.navigation.opacity <> navOpacity)
        navMotion.control = "stop"
        fade.keyValue = [m.navigation.opacity,navOpacity]
        navMotion.control = "start"
    end if
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
    slide = m.top.findNode("homeSlide")
    if not REqual(slide.keyValue[1],[96,top]) or (motion.state <> "running" and not REqual(m.shelves.translation,[96,top]))
        motion.control = "stop"
        slide.keyValue = [m.shelves.translation,[96,top]]
        motion.control = "start"
    end if
    m.top.findNode("heroIndicators").visible = not browse and m.featured.count() > 1
end sub

sub rHero(card as object, shape = "landscape" as string)
    m.hero.visible = true
    m.heroTitle.text = RText(card.title)
    m.heroMeta.parts = RArray(RGet(RGet(card,"view",{}),"hero_metadata_parts"))
    if m.route = "detail" then m.heroMeta.parts = RArray(RGet(RGet(card,"view",{}),"metadata_parts"))
    m.heroMeta.badges = RArray(RGet(RGet(card,"view",{}),"hero_badges"))
    m.heroDescription.text = RText(card.description)
    m.backdrop.translation = [0,0]
    m.backdrop.width = 1920
    m.backdrop.height = 1080
    m.top.findNode("scrimX").uri = "pkg:/images/design/remote-home-x.png"
    m.top.findNode("scrimY").uri = "pkg:/images/design/remote-home-y.png"
    m.top.findNode("scrimY").height = 1080
    m.heroTitle.font.size = 48
    m.heroTitle.width = 800
    m.top.findNode("homePoster").visible = false
    m.top.findNode("homePosterArt").uri = ""
    m.heroTitle.translation = [96,306]
    m.heroTitle.height = 160
    m.heroLogo.translation = [96,306]
    m.heroLogo.width = 410
    m.heroLogo.height = 160
    m.heroMeta.translation = [96,494]
    m.heroDescription.width = 780
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
        m.heroTitle.width = 1000
        m.heroTitle.height = 120
        m.heroLogo.translation = [96,96]
        m.heroLogo.width = 420
        m.heroLogo.height = 120
        m.heroMeta.translation = [96,240]
        m.heroDescription.translation = [96,290]
        m.heroDescription.width = 700
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
        m.heroLogo.width = 260
        if card.identity.kind = "series" then m.heroLogo.width = 460
        m.heroDescription.width = 800
        m.heroMeta.translation = [96,meta]
        m.heroDescription.translation = [96,meta+50]
        m.heroDescription.height = 0
        m.heroDescription.maxLines = 3
        m.heroDescription.numLines = 0
    end if
    logo = RText(card.logo)
    if left(logo,5) = "/api/" then logo = m.config.base+logo
    m.logoBounds = {position:m.heroLogo.translation,width:m.heroLogo.width,height:m.heroLogo.height}
    m.heroLogo.visible = false
    m.heroTitle.visible = true
    m.heroLogo.uri = logo
    rLogoReady()
    uri = RText(card.landscape)
    if m.route = "home" and m.homeBrowsing
        preview = RGet(RGet(card,"view",{}),"preview",{})
        uri = RText(RGet(preview,"background"))
        if shape = "poster"
            poster = RText(card.poster)
            if left(poster,5) = "/api/" then poster = m.config.base+poster
            m.top.findNode("homePosterArt").uri = poster
            m.top.findNode("homePoster").visible = poster <> ""
            ' A poster has no landscape art, so the stage needs the soft copy.
            uri = RText(RGet(preview,"soft"))
            if uri = "" then uri = RSoftArt(RText(RGet(preview,"background")))
            if uri = "" then uri = RSoftArt(poster)
        end if
    else if uri = ""
        ' A title with only portrait art still needs a soft hero stage.
        poster = RText(card.poster)
        if left(poster,5) = "/api/" then poster = m.config.base+poster
        uri = RSoftArt(poster)
    end if
    if left(uri,5) = "/api/" then uri = m.config.base+uri
    rBackdrop(uri)
end sub

sub rShelfFocused(event = invalid as dynamic)
    if m.route = "profiles" then return
    if m.route = "search"
        rSearchFocused()
        return
    end if
    index = m.shelves.rowItemFocused
    if event <> invalid then index = event.getData()
    if index.count() <> 2 or m.shelves.content = invalid then return
    if m.route = "home"
        if m.homeRebuilding then return
        if event <> invalid and not REqual(index,m.shelves.rowItemFocused) then return
        if m.homeExpectedFocus <> invalid
            if not REqual(index,m.homeExpectedFocus) then return
            m.homeExpectedFocus = invalid
        end if
    end if
    row = m.shelves.content.getChild(index[0])
    if row = invalid then return
    item = row.getChild(index[1])
    if m.route = "detail"
        hasEpisodes = RObject(m.detailData) and RArray(m.detailData.episodes).count() > 0
        rDetailScroll(hasEpisodes and index[0] = 0)
    end if
    if m.route = "home" and item <> invalid
        m.homeFocus = rHomeSelection(index)
        if not m.homeBrowsing then return
        rHomeScroll(true)
        now = m.homeFocusClock.totalMilliseconds()
        delay = 0.12
        if now-m.homeLastFocusTime < 400 then delay = 0.35
        m.homeLastFocusTime = now
        m.pendingHomeHero = {card:item.wire,shape:row.wire.view.card_shape,row_id:row.wire.id,key:RIdentityKey(item.wire),epoch:m.epoch,generation:m.generation,profile:m.profile,version:m.homeRenderVersion}
        m.heroTick.control = "stop"
        m.heroTick.duration = delay
        m.heroTick.control = "start"
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
    if m.drawer.visible or m.playback <> invalid
        m.pendingHomeHero = invalid
        return
    end if
    pending = m.pendingHomeHero
    m.pendingHomeHero = invalid
    if m.route <> "home" or not m.homeBrowsing or not RObject(pending) then return
    if pending.epoch <> m.epoch or pending.generation <> m.generation or pending.profile <> m.profile or pending.version <> m.homeRenderVersion then return
    if m.homeExpectedFocus <> invalid or m.top.findNode("homeMotion").state = "running"
        m.pendingHomeHero = pending
        m.heroTick.duration = 0.05
        m.heroTick.control = "start"
        return
    end if
    selection = rHomeSelection()
    if not RObject(selection) then return
    if selection.row_id <> pending.row_id or selection.key <> pending.key then return
    rHero(pending.card,pending.shape)
end sub

sub rShelfSelected(event = invalid as dynamic)
    index = m.shelves.rowItemSelected
    if event <> invalid then index = event.getData()
    if RArray(index).count() <> 2 or m.shelves.content = invalid then return
    row = m.shelves.content.getChild(index[0])
    if row = invalid then return
    node = row.getChild(index[1])
    if node <> invalid
        if m.route = "home" and m.homeExpectedFocus <> invalid then return
        if m.route = "search" and RGet(node.wire,"action") = "liveChannel"
            rRun(node.wire)
            return
        end if
        if m.route = "profiles"
            rRun(node.wire)
            return
        end if
        if m.route = "home"
            preview = RGet(RGet(node.wire,"view",{}),"preview")
            if not RHomePreview(preview) then return
            if preview.action = "play" then rRun({action:"play",card:node.wire}) else rDetail(node.wire,true)
        else if m.route = "detail" and RObject(node.wire.identity.episode)
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

sub rGridFocused(event = invalid as dynamic)
    observed = m.grid.itemFocused
    if event <> invalid then observed = event.getData()
    if m.catalogExpectedFocus <> invalid
        if observed = m.catalogExpectedFocus
            m.catalogExpectedFocus = invalid
            rCatalogQueueVisibility()
        end if
        return
    end if
    if observed <> m.grid.itemFocused then return
    rCatalogQueueVisibility()
    if m.route = "library" and (m.libraryRefresh <> invalid or m.pending.doesExist("library") or rLibraryRetryRequired()) then return
    if m.grid.content = invalid then return
    if m.route = "library"
        for each request in m.retryAuth
            if request.tag = "library" and rRequestCurrent(request) then return
        end for
    end if
    if m.route = "library" and m.grid.itemFocused < 7
        if rLibraryPrevious() then return
    end if
    if m.grid.itemFocused < m.grid.content.getChildCount()-14 then return
    if m.nextCursor = "" then return
    if m.route = "library"
        for each page in m.libraryPages
            offset = RGet(page.data.query,"offset")
            if offset <> invalid and offset.toStr() = m.nextCursor then return
        end for
    end if
    if m.pageCursors.doesExist(m.nextCursor) then return
    m.pageCursors[m.nextCursor] = true
    if m.route = "movie" or m.route = "series" or m.route = "anime"
        m.browseQuery.skip = m.nextCursor
        rBrowsePage()
    else if m.route = "library"
        m.libraryQuery.offset = m.nextCursor
        rLibraryPage()
    end if
end sub

sub rRowSelected()
    node = m.rows.content.getChild(m.rows.itemSelected)
    if node <> invalid then rRun(node.wire)
end sub

sub rActionSelected()
    if m.actions.content = invalid then return
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
    if action = "home"
        rNavigate("home")
    else if action = "signInChoice"
        rSignInChoice()
    else if action = "pair"
        m.pairChallenge = invalid
        rShowPair({})
        rSend("POST","/api/auth/device/code",{device_name:"VIPTV Roku"},"auth:code")
    else if action = "password"
        rPassword()
    else if action = "server"
        if m.config.locked = true then return
        rTextInput("Server address","server",false,m.config.base)
    else if action = "selectProfile"
        rSend("POST","/api/auth/profile",{profile_id:value.profile.id},"auth:profile")
    else if action = "profiles" or action = "settings" or action = "history"
        rCloseDrawer()
        rNavigate(action)
    else if action = "detail"
        rDetail(value.card,true)
    else if action = "play" or action = "sources" or action = "restart"
        rCancelAdmission()
        rCancelDiscovery()
        m.playIntent = {explicit:action = "sources",restart:action = "restart"}
        rSend("POST",rProfilePath("/viewing-action"),{card:value.card,restart:action = "restart"},"viewing",{source_epoch:m.sourceEpoch})
    else if action = "source"
        ' A fresh choice clears the previous attempt's reason.
        m.sourceError = ""
        rSourceStatus()
        rStartSource(value.source)
    else if action = "saveTitle"
        card = value.card
        if GetInterface(RGet(RGet(card,"view",{}),"saved"),"ifBoolean") = invalid
            rError("This server needs an update to provide saved-title actions.")
            return
        end if
        if rIsSaved(card)
            suffix = "/library/"+REncode(card.identity.kind)+"/"+REncode(card.identity.id)
            query = invalid
            if card.metadata_origin <> invalid then query = {metadata_origin:card.metadata_origin,card:card}
            rSend("DELETE",rProfilePath(suffix),invalid,"save:library",invalid,query)
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
        rRetireCatalog()
        m.browseQuery = {type:m.route,catalog:value.catalog.id,skip:"0"}
        if value.catalog.addon_id <> invalid then m.browseQuery.addon_id = value.catalog.addon_id.toStr()
        m.selectedCatalog = value.catalog
        m.cards = []
        rCloseDrawer()
        rBrowseFilters()
        rBrowsePage()
    else if action = "browseFilters"
        rFiltersOpen()
    else if action = "libraryType"
        rRetireCatalog()
        m.libraryQuery.type = value.value
        m.libraryQuery.offset = "0"
        m.cards = []
        rLibraryPage()
    else if action = "libraryFilters"
        rLibrarySheetOpen()
    else if action = "liveChannel"
        m.liveChannel = value.channel
        m.playIntent = {explicit:false}
        rLiveSources(value.channel.card,value.channel.connection_id)
    else if action = "liveGroup"
        rLiveGroup(value.id)
    else if action = "retry" and RGet(value,"homeRowRetry",false)
        m.homeDue = rNow()+2
        rSend("GET",rProfilePath("/home"),invalid,"home")
    else if action = "retry"
        if m.failedRequest <> invalid
            q = m.failedRequest
            if not rRequestCurrent(q)
                m.failedRequest = invalid
                m.retryBar.visible = false
                return
            end if
            focused = m.retryBar.isInFocusChain()
            rSend(q.method,q.path,q.body,q.tag,q.context,q.query)
            if m.pending.doesExist(q.tag)
                m.failedRequest = invalid
                if q.tag = "library" then m.libraryRevisionPending = false
                if rLiveDataTag(q.tag) then m.liveRetryTag = q.tag
                m.retryBar.visible = false
                if focused and (q.tag = "library" or q.tag = "browse") and m.grid.visible then m.grid.setFocus(true)
                if focused and rLiveDataTag(q.tag) and m.rows.visible then m.rows.setFocus(true)
            end if
        end if
    else if action = "calendarDay"
        rRetireCalendar()
        m.calendarDay = value.date
        ' Repaint the chips with the new selection and keep the remote on it.
        rCalendarDays()
        if m.filters.content <> invalid
            for i = 0 to m.filters.content.getChildCount()-1
                if RText(m.filters.content.getChild(i).wire.date) = m.calendarDay then m.filters.jumpToItem = i
            end for
        end if
        rCalendarFetch("")
    else if action = "calendarWeek"
        rCloseDrawer()
        m.calendarOffset += value.offset
        rCalendarWeek()
    else if action = "calendarOptions"
        rOpenDrawer("Calendar",[{title:"Movies",action:"calendarSelectType",type:"movie"},{title:"Series",action:"calendarSelectType",type:"series"},{title:"Anime",action:"calendarSelectType",type:"anime"},{title:"Previous week",action:"calendarWeek",offset:-7},{title:"Next week",action:"calendarWeek",offset:7}],"calendarOptions")
    else if action = "calendarSelectType"
        m.calendarType = value.type
        rCloseDrawer()
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
        m.playIntent = {explicit:false}
        rLiveSources(card)
        return
    end if
    if push then rPush()
    rReset("detail")
    m.detailCard = card
    m.navigation.visible = false
    rHero(card)
    rDetailActions(card)
    m.actions.setFocus(true)
    rDetailPage(0)
end sub

sub rDetailActions(card as object, action = invalid as dynamic)
    label = RText(RGet(action,"label"),"Play")
    width = 260
    if RGet(action,"resume",false) then width = 420
    values = [{title:label,icon:"play",action:"play",card:card,width:width,ring:false,heroAction:true,remainingLabel:RText(RGet(action,"remaining_label")),resumeProgress:RGet(action,"progress")}]
    if GetInterface(RGet(RGet(card,"view",{}),"saved"),"ifBoolean") <> invalid
        icon = "plus"
        if rIsSaved(card) then icon = "check"
        values.push({title:"",icon:icon,action:"saveTitle",card:card,width:72,ring:false,heroAction:true})
    end if
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
        expectation = RCopy(card)
        expectation.identity = identity
        expectation.parent_identity = invalid
        query.metadata_origin = card.metadata_origin
        query.card = expectation
    else
        query.provider_id = card.provider_id
    end if
    rSend("GET","/api/meta/"+REncode(identity.kind)+"/"+REncode(identity.id),invalid,"detail",{append:appendPage,cursor:cursor},query)
end sub

sub rBrowsePage()
    rSend("GET","/api/discover",invalid,"browse",{catalog_version:m.catalogVersion},m.browseQuery)
end sub

sub rBrowseFilters()
    values = []
    if RArray(m.controls.catalogs).count() > 0
        label = "Catalog"
        if RObject(m.selectedCatalog) then label = m.selectedCatalog.name
        values.push({title:label,action:"catalogs"})
    end if
    controls = RArray(m.controls.controls)
    if RObject(m.selectedCatalog) then controls = RArray(m.selectedCatalog.controls)
    if controls.count() > 0 then values.push({title:"Filters",icon:"remote-sliders",action:"browseFilters"})
    m.filters.itemSize = [300,64]
    m.filters.translation = [96,140]
    m.filters.content = rContent(values,300,64)
    m.filters.visible = values.count() > 0
    y = 180
    if m.filters.visible then y = 244
    rCatalogViewport(y)
end sub

sub rPageResponse(tag as string, data as dynamic, request as object)
    m.skeleton.visible = false
    if rLiveDataTag(tag) and tag = RText(m.liveRetryTag)
        m.liveRetryTag = ""
        if m.failedRequest = invalid
            m.liveFailureText = ""
            m.message.text = RText(RGet(m.liveData,"reason"))
            m.retryBar.visible = false
        end if
    end if
    if tag = "home"
        rHome(data)
    else if tag = "state:revisions"
        changed = m.revisions <> invalid and not REqual(m.revisions,data)
        m.revisions = data
        if changed
            rInvalidateReturnViews()
            rSend("GET","/api/bootstrap",invalid,"auth:bootstrap")
            if m.route = "library" then m.libraryRevisionPending = true
            if m.route = "home" and not m.drawer.visible then rSend("GET",rProfilePath("/home"),invalid,"home")
            if m.route <> "home" then m.homeData = invalid
        end if
    else if tag = "profiles"
        rProfiles(data)
    else if tag = "controls"
        m.controls = data
        m.selectedCatalog = invalid
        for each catalog in RArray(data.catalogs)
            if catalog.id = RGet(m.browseQuery,"catalog") then m.selectedCatalog = catalog
        end for
        rBrowseFilters()
    else if tag = "browse" or tag = "library"
        if tag = "library" and (not RObject(RGet(data,"query")) or not RObject(RGet(data,"default_query")))
            rError("The server returned an invalid library query.")
            return
        end if
        if not RCards(data.cards)
            rError("The server returned an invalid catalog.")
            return
        end if
        selectedKey = ""
        if m.grid.content <> invalid
            focused = m.grid.content.getChild(m.grid.itemFocused)
            if focused <> invalid and RCard(focused.wire) then selectedKey = RIdentityKey(focused.wire)
        end if
        if RText(m.restoreKey) <> "" then selectedKey = m.restoreKey
        unchanged = false
        if tag = "library"
            data = rLibraryWindow(data,request)
            if data = invalid then return
            unchanged = REqual(m.cards,data.cards)
            if m.grid.content = invalid
                unchanged = false
            else if m.grid.content.getChildCount() <> data.cards.count()
                unchanged = false
            end if
            m.cards = data.cards
            m.failedRequest = invalid
            m.retryBar.visible = false
            m.message.text = RText(data.reason)
        else
            m.cards.append(data.cards)
        end if
        while m.cards.count() > 300
            m.cards.shift()
        end while
        m.nextCursor = RText(data.next_cursor)
        target = 0
        for i = 0 to m.cards.count()-1
            if RIdentityKey(m.cards[i]) = selectedKey then target = i
        end for
        m.restoreKey = invalid
        if not unchanged
            m.catalogExpectedFocus = invalid
            if target > 0 then m.catalogExpectedFocus = target
            m.grid.content = rContent(m.cards,232,424,348,"poster")
            m.grid.jumpToItem = target
        end if
        m.grid.visible = true
        if m.cards.count() = 0 and m.message.text = "" then m.message.text = "No titles found."
        if tag = "library"
            m.libraryQuery = RQueryFields(data.query)
            m.libraryDefaults = RQueryFields(data.default_query)
            m.libraryControls = data.controls
            rLibraryHeader(data)
            m.grid.itemSpacing = [16,22]
            rLibraryStatus(false)
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
        rowSizes = []
        rowSpacing = []
        rowHeights = []
        rowGaps = []
        labels = []
        if RArray(data.episodes).count() > 0
            row = root.createChild("ContentNode")
            row.title = "Episodes"
            row.addFields({homeTitleHeight:0})
            items = rContent(data.episodes,448,389,252)
            for each node in items.getChildren(-1,0)
                node.uiRole = "episode"
            end for
            rowSizes.push([448,389])
            rowHeights.push(389)
            rowGaps.push(20)
            labels.push(false)
            rowSpacing.push([24,0])
            row.appendChildren(items.getChildren(-1,0))
        end if
        if RArray(data.recommendations).count() > 0
            row = root.createChild("ContentNode")
            row.title = "More Like This"
            items = rContent(data.recommendations,232,348,348,"poster")
            for each node in items.getChildren(-1,0)
                node.showLabels = false
                node.uiRole = "recommendation"
            end for
            rowSizes.push([232,348])
            rowHeights.push(400)
            rowGaps.push(40)
            labels.push(true)
            rowSpacing.push([16,0])
            row.appendChildren(items.getChildren(-1,0))
        end if
        m.shelves.rowHeights = rowHeights
        m.shelves.rowSpacings = rowGaps
        m.shelves.showRowLabel = labels
        m.shelves.rowItemSize = rowSizes
        m.shelves.rowItemSpacing = rowSpacing
        m.shelves.itemSize = [1728,456]
        m.shelves.translation = [96,836]
        if RArray(data.episodes).count() > 0
            m.shelves.translation = [96,888]
            m.shelves.itemSize = [1728,389]
            m.shelves.rowLabelOffset = [[0,0]]
        end if
        m.shelves.content = root
        if RGet(request.context,"append",false) and position.count() = 2 then m.shelves.jumpToRowItem = position
        m.shelves.visible = root.getChildCount() > 0
        seasons = []
        for each season in RArray(data.seasons)
            label = "Episodes"
            if season.season <> invalid then label = "Season "+season.season.toStr()
            seasons.push({title:label,action:"season",offset:season.offset,button:true,width:176})
        end for
        m.filters.content = rContent(seasons,176,52)
        m.filters.translation = [96,816]
        if m.detailEpisodes then m.filters.translation = [96,588]
        m.filters.itemSize = [176,52]
        m.filters.visible = seasons.count() > 0
    else if tag = "detail:action"
        rDetailActions(m.detailCard,data)
    else if tag = "calendar"
        rCalendar(data,request)
    else if tag = "history"
        rHistory(data)
    else if tag = "search"
        m.searchFailures.delete(tag)
        rSearchErrors()
        m.searchMediaRows = RArray(data.rows)
        if data.complete = false
            message = "Some search results are unavailable. Try again."
            for each group in m.searchMediaRows
                if RText(group.message) <> "" then message = group.message
            end for
            rSearchFailure(request,message)
        end if
        rSearchRender()
    else if tag = "search:channels"
        m.searchFailures.delete(tag)
        rSearchErrors()
        rSearchChannelResponse(data,request)
    else if tag = "live"
        rLive(data)
    else if tag = "live:page"
        rLivePage(data,request)
    else if left(tag,11) = "live:guide:"
        rLiveGuide(data,request)
    else if tag = "live:sources"
        m.viewingAction = data.action
        m.playCard = data.action.card
        m.drawerSubtitle.text = data.action.card.title
        m.discovery = {id:"",after:0,due:9999999999#,streams:RArray(data.streams),done:true}
        rRankSources()
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
        rShowSources(RArray(data.streams),RText(data.best_match_id))
        filters = [{title:"All "+RGet(data,"total",0).toStr(),height:invalid,width:140}]
        for each filter in RArray(data.quality_filters)
            filters.push({title:RText(filter.label)+" "+RGet(filter,"count",0).toStr(),height:filter.height,width:140})
        end for
        m.sourceFilters.content = rContent(filters,140,52)
        m.sourceFilters.visible = true
        m.sourceFilters.scroll = true
        m.sourceFilters.containerWidth = rDrawerContentWidth()
        rSourceProviders(m.sourceStreams,m.sourceBest)
        ' The server's ranking note explains how Play chose, so the footer is the
        ' place for it instead of an empty line under the list.
        m.sourceNote = RText(RGet(data,"selection_note"))
        rDrawerLayout("sources")
        if m.drawerRows.content <> invalid and m.drawerRows.content.getChildCount() = 0 then m.drawerRows.content = rContent([],rDrawerContentWidth(),rDrawerRowHeight("sources"))
        rSourceStatus()
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
    if card.identity.kind = "live"
        rLiveSources(card)
        return
    end if
    rCancelDiscovery()
    rOpenDrawer("Choose a source",[],"sources")
    m.playCard = card
    m.sourceNote = ""
    m.drawerSubtitle.text = card.title
    m.drawerMessage.text = "Finding sources…"
    m.sourceQuality = invalid
    m.sourceProvider = ""
    m.sourceStreams = []
    m.sourceBest = ""
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

sub rClearSourceError()
    m.sourceError = ""
end sub

sub rShowSources(sources as object, bestId = "" as string)
    if not m.drawer.visible then rOpenDrawer("Choose a source",[],"sources")
    m.sourceStreams = sources
    m.sourceBest = bestId
    selectedId = ""
    if m.drawerRows.content <> invalid
        focused = m.drawerRows.content.getChild(m.drawerRows.itemFocused)
        if focused <> invalid then selectedId = RText(RGet(RGet(focused.wire,"source",{}),"id"))
    end if
    values = []
    for each source in sources
        if m.sourceProvider = "" or RSourceProvider(source) = m.sourceProvider
            view = RGet(source,"view",{})
            values.push({title:RText(view.title),subtitle:RText(view.body),action:"source",source:source,bestMatch:bestId <> "" and source.id = bestId,ring:false})
        end if
    end for
    focus = m.drawerRows.itemFocused
    for i = 0 to values.count()-1
        if values[i].source.id = selectedId then focus = i
    end for
    ' Source rows are taller than a plain drawer row so a long release name and
    ' its technical line both fit. The list owns that height; the row only draws.
    rDrawerLayout("sources")
    m.drawerRows.content = rContent(values,rDrawerContentWidth(),rDrawerRowHeight("sources"))
    if focus >= 0 and focus < values.count() then m.drawerRows.jumpToItem = focus
    rSourceStatus()
end sub

' Sheet subtitle and footer: what is being chosen, how much was found, and how
' Play decides. Kept in one place so a poll cannot leave a stale line behind.
sub rSourceStatus()
    title = m.drawerSubtitle.text
    if m.playCard <> invalid then title = RText(m.playCard.title)
    visibleSources = 0
    providers = {}
    for each source in RArray(m.sourceStreams)
        if m.sourceProvider = "" or RSourceProvider(source) = m.sourceProvider then visibleSources++
        label = RSourceProvider(source)
        if label <> "" then providers[label] = true
    end for
    count = providers.count()
    summary = visibleSources.toStr()+" "+rPlural(visibleSources,"source","sources")+" from "+count.toStr()+" "+rPlural(count,"add-on","add-ons")
    m.drawerSubtitle.text = title
    if title <> "" then m.drawerSubtitle.text = title+" · "+summary
    m.drawerMessage.color = "#B6B4AF"
    m.drawerMessage.text = RText(m.sourceNote)
    if m.discovery <> invalid and not m.discovery.done then m.drawerMessage.text = "Finding sources…"
    if visibleSources = 0 then m.drawerMessage.text = "No sources are available."
    ' A failed start outranks every status line until the viewer picks again.
    if RText(m.sourceError) <> ""
        m.drawerMessage.text = m.sourceError
        m.drawerMessage.color = "#FF7A6E"
    end if
end sub

' Chip width for a provider filter. A fixed 200px chip left a one-word provider
' with as much room as a long one, so the row wasted its scroll on padding.
function rChipWidth(label as string) as integer
    width = 44+int(len(RRenderable(label))*12.5)
    if width < 132 then width = 132
    if width > 300 then width = 300
    return width
end function

function rPlural(count as integer, one as string, many as string) as string
    if count = 1 then return one
    return many
end function

function RSourceProvider(source as object) as string
    view = RGet(source,"view",{})
    label = RText(RGet(view,"addon_label"))
    if label = "" then label = RText(RGet(view,"provider_label"))
    return label
end function

sub rSourceProviders(sources as object, bestId as string)
    ' Provider facets come from the labels the server already attached to each
    ' ranked source. Selecting one narrows the visible rows; ranking itself
    ' stays server-owned.
    labels = []
    counts = {}
    for each source in RArray(sources)
        label = RSourceProvider(source)
        if label <> ""
            if not counts.doesExist(label)
                labels.push(label)
                counts[label] = 0
            end if
            counts[label] = counts[label]+1
        end if
    end for
    m.providerFilters.visible = labels.count() > 1
    if not m.providerFilters.visible then return
    values = [{title:"All sources",value:"",width:rChipWidth("All sources")}]
    for each label in labels
        text = label+" "+counts[label].toStr()
        values.push({title:text,value:label,width:rChipWidth(text)})
    end for
    m.providerFilters.content = rContent(values,200,44)
    m.providerFilters.scroll = true
    m.providerFilters.containerWidth = rDrawerContentWidth()
    ' A second filter row pushes the list down, so the plan is recomputed here
    ' instead of in each caller.
    if m.drawerKind = "sources" then rDrawerLayout("sources")
end sub

sub rProviderFilterSelected()
    node = m.providerFilters.content.getChild(m.providerFilters.itemSelected)
    if node = invalid then return
    m.sourceProvider = RText(node.wire.value)
    rShowSources(m.sourceStreams,m.sourceBest)
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
        if left(worker.request.tag,8) = "sources:" or worker.request.tag = "live:sources" or worker.request.tag = "viewing"
            if worker.request.method = "GET" then worker.cancel = true
            if m.pending[worker.request.tag] = worker.request.request_id then m.pending.delete(worker.request.tag)
        end if
    end for
    retained = []
    for each queued in m.queue
        if left(queued.tag,8) = "sources:" or queued.tag = "live:sources" or queued.tag = "viewing"
            m.pending.delete(queued.tag)
        else
            retained.push(queued)
        end if
    end for
    m.queue = retained
    retained = []
    for each request in m.retryAuth
        if left(request.tag,8) <> "sources:" and request.tag <> "live:sources" and request.tag <> "viewing" then retained.push(request)
    end for
    m.retryAuth = retained
    if m.discovery <> invalid
        if RText(m.discovery.id) <> "" then rSend("DELETE","/api/streams/"+REncode(m.discovery.id),invalid,"cleanup:discovery")
        m.discovery = invalid
    end if
end sub

sub rPairExpiry()
    label = m.top.findNode("pairExpiry")
    label.text = ""
    if m.pairChallenge = invalid then return
    remaining = int(m.pairExpires-rNow())
    if remaining < 0 then remaining = 0
    seconds = (remaining mod 60).toStr()
    if len(seconds) = 1 then seconds = "0"+seconds
    label.text = "Code expires in "+int(remaining/60).toStr()+":"+seconds
end sub

sub rLogoReady()
    if not RObject(m.logoBounds) then return
    ready = m.heroLogo.uri <> "" and m.heroLogo.loadStatus = "ready" and m.heroLogo.bitmapWidth > 0 and m.heroLogo.bitmapHeight > 0
    m.heroLogo.visible = ready
    m.heroTitle.visible = not ready
    if not ready then return
    scale = m.logoBounds.width/m.heroLogo.bitmapWidth
    if m.heroLogo.bitmapHeight*scale > m.logoBounds.height then scale = m.logoBounds.height/m.heroLogo.bitmapHeight
    m.heroLogo.width = m.heroLogo.bitmapWidth*scale
    m.heroLogo.height = m.heroLogo.bitmapHeight*scale
    m.heroLogo.translation = [m.logoBounds.position[0],m.logoBounds.position[1]+m.logoBounds.height-m.heroLogo.height]
end sub

sub rLibraryPage()
    rSend("GET",rProfilePath("/library"),invalid,"library",{catalog_version:m.catalogVersion},m.libraryQuery)
end sub

sub rRetireCatalog()
    m.restoreKey = invalid
    m.libraryRevisionPending = false
    m.libraryPages = []
    m.libraryCursors = []
    m.libraryFirst = 0
    m.libraryRefresh = invalid
    m.libraryRefreshDue = 0
    m.catalogVersion++
    for each worker in m.workers
        if worker.request.tag = "browse" or worker.request.tag = "library" then worker.cancel = true
    end for
    retained = []
    for each request in m.queue
        if request.tag <> "browse" and request.tag <> "library" then retained.push(request)
    end for
    m.queue = retained
    m.pending.delete("browse")
    m.pending.delete("library")
    m.pageCursors = {}
    m.nextCursor = ""
end sub

sub rLibraryHeader(data as object)
    values = []
    for each control in RArray(data.controls)
        if control.id = "type"
            for each choice in RArray(control.choices)
                values.push({title:choice.label,action:"libraryType",value:choice.value,selected:choice.value = RGet(data.query,"type")})
            end for
        end if
    end for
    if RArray(data.controls).count() > 0 then values.push({title:"Filters",action:"libraryFilters"})
    m.libraryHeader.content = rContent(values,140,52)
    m.libraryHeader.visible = values.count() > 0
end sub

sub rLibraryHeaderSelected()
    node = m.libraryHeader.content.getChild(m.libraryHeader.itemSelected)
    if node <> invalid then rRun(node.wire)
end sub

sub rPassword()
    rReset("password")
    m.passwordForm.serverAllowed = m.config.locked <> true
    m.passwordForm.visible = true
    m.passwordForm.callFunc("resetForm")
end sub
sub rPasswordSubmit()
    if m.pending.doesExist("auth:login") then return
    if m.passwordForm.username.trim() = "" or m.passwordForm.password = "" then return
    m.passwordForm.busy = true
    m.passwordForm.error = ""
    rSend("POST","/api/auth/device/login",{username:m.passwordForm.username,password:m.passwordForm.password,device_name:"VIPTV Roku"},"auth:login")
    m.passwordForm.password = ""
end sub
sub rPasswordCancel()
    ' Retire UI ownership, but let an admitted HTTP request finish so any late
    ' grant can be revoked. Unsent credentials never leave the queue.
    retained = []
    for each request in m.queue
        if request.tag <> "auth:login" then retained.push(request)
    end for
    m.queue = retained
    m.pending.delete("auth:login")
    m.passwordForm.callFunc("resetForm")
    rSignInChoice()
end sub
sub rPasswordServer()
    if m.passwordForm.busy or m.config.locked = true then return
    rTextInput("Server address","server",false,m.config.base)
end sub

sub rFiltersOpen()
    controls = RArray(m.controls.controls)
    if RObject(m.selectedCatalog) then controls = RArray(m.selectedCatalog.controls)
    visible = []
    for each control in controls
        if control.id <> "type" and control.id <> "catalog" and RGet(control,"maximum_selections",1) <> 0 then visible.push(control)
    end for
    draft = {}
    for each value in RArray(m.browseQuery.values)
        draft[value.id] = RCopy(value.values)
    end for
    for each control in visible
        if m.browseQuery.doesExist(control.id) and GetInterface(m.browseQuery[control.id],"ifString") <> invalid then draft[control.id] = [m.browseQuery[control.id]]
    end for
    m.filterPage.controls = visible
    m.filterPage.draft = draft
    m.filterPage.catalogLabel = "Catalog"
    if RObject(m.selectedCatalog)
        m.filterPage.catalogLabel = RText(m.selectedCatalog.name)
        if RText(m.selectedCatalog.connection_name) <> "" then m.filterPage.catalogLabel += " · "+m.selectedCatalog.connection_name
    end if
    m.filterPage.visible = true
    m.filterPage.callFunc("open")
end sub
sub rFiltersCancel()
    m.filterPage.visible = false
    m.filterPage.draft = {}
    if m.filters.visible then m.filters.setFocus(true) else rFocusContent()
end sub
sub rFiltersSubmit()
    query = RCopy(m.browseQuery)
    if m.filterPage.resetCatalog
        query = {type:m.route}
        m.selectedCatalog = invalid
    end if
    values = []
    for each control in RArray(m.filterPage.controls)
        query.delete(control.id)
        selection = RArray(RGet(m.filterPage.draft,control.id))
        if selection.count() > 0 then values.push({id:control.id,values:RCopy(selection)})
    end for
    query.values = values
    query.skip = "0"
    rRetireCatalog()
    m.browseQuery = query
    m.cards = []
    rFiltersCancel()
    rBrowseFilters()
    rBrowsePage()
end sub

sub rLibrarySheetOpen()
    if not RObject(m.libraryDefaults)
        rError("This server needs an update to support Library filters.")
        return
    end if
    m.librarySheet.defaultQuery = RCopy(m.libraryDefaults)
    m.librarySheet.controls = RArray(m.libraryControls)
    m.librarySheet.query = RCopy(m.libraryQuery)
    m.librarySheet.visible = true
    m.librarySheet.callFunc("open")
end sub
sub rLibrarySheetSubmit()
    if not m.librarySheet.visible then return
    if m.queue.count() >= 24
        m.librarySheet.error = "The connection is busy. Try Apply again."
        return
    end if
    rRetireCatalog()
    m.libraryQuery = RQueryFields(m.librarySheet.draft)
    m.libraryQuery.offset = "0"
    m.cards = []
    rLibraryPage()
    m.librarySheet.callFunc("close")
end sub
sub rLibrarySheetDismiss()
    if not m.librarySheet.visible then return
    m.librarySheet.visible = false
    m.librarySheet.draft = {}
    if rInputVisible() then return
    if m.route = "library" and m.libraryHeader.visible then m.libraryHeader.setFocus(true) else rFocusContent()
end sub

sub rNavigation(entries as dynamic)
    oldMediaAllowed = m.searchMediaAllowed
    oldChannelsAllowed = m.searchChannelsAllowed
    m.searchMediaAllowed = false
    m.searchChannelsAllowed = false
    focused = ""
    old = RArray(m.navigation.destinations)
    at = m.navigation.cursor
    if at >= 0 and at < old.count() then focused = old[at].id
    widths = {search:56,home:104,movie:118,series:108,anime:115,live:80,calendar:146,library:121,profiles:56}
    items = []
    cursor = 0
    for each entry in RArray(entries)
        id = RText(RGet(entry,"id"))
        if widths.doesExist(id)
            item = {id:id,label:RText(entry.label),width:widths[id]}
            if id = "profiles"
                item.id = "menu"
                item.icon = "profile"
                item.label = ""
            else if id = "search"
                m.searchMediaAllowed = RGet(entry,"media_search",false) = true
                m.searchChannelsAllowed = RGet(entry,"channel_search",false) = true
                item.icon = "search"
                item.label = ""
            end if
            if item.id = focused then cursor = items.count()
            items.push(item)
        end if
    end for
    if m.route = "search" and (oldMediaAllowed <> m.searchMediaAllowed or oldChannelsAllowed <> m.searchChannelsAllowed) then rSearchSubmit()
    if REqual(old,items) then return
    m.navigation.cursor = cursor
    m.navigation.destinations = items
end sub

sub rLibraryRefreshPoll(now as double)
    if m.route <> "library" or rLibraryRetryRequired() then return
    if m.drawer.visible or m.librarySheet.visible or rInputVisible() then return
    if m.libraryRevisionPending
        if m.libraryPages.count() = 0 then return
        retained = m.libraryPages
        cursors = m.libraryCursors
        first = m.libraryFirst
        rRetireCatalog()
        m.libraryPages = retained
        m.libraryCursors = cursors
        m.libraryFirst = first
        m.libraryRefreshDue = now
    end if
    if m.pending.doesExist("library") then return
    for each request in m.retryAuth
        if request.tag = "library" and rRequestCurrent(request) then return
    end for
    if m.libraryRefresh = invalid
        if m.libraryRefreshDue <= 0 or now < m.libraryRefreshDue or m.libraryPages.count() = 0 then return
        m.libraryRefresh = {pages:[],target:m.libraryPages.count(),nextQuery:RCopy(m.libraryPages[0].data.query)}
    end if
    if m.libraryRefresh.nextQuery = invalid or m.queue.count() >= 24 then return
    rSend("GET",rProfilePath("/library"),invalid,"library",{catalog_version:m.catalogVersion,refresh:true},m.libraryRefresh.nextQuery)
    if m.pending.doesExist("library") then m.libraryRefresh.nextQuery = invalid
end sub

function rLibraryWindow(data as object, request as object) as dynamic
    due = 0
    delay = RGet(data,"refresh_after_millis")
    if GetInterface(delay,"ifInt") <> invalid or GetInterface(delay,"ifFloat") <> invalid or GetInterface(delay,"ifDouble") <> invalid
        if delay > 0 then due = rNow()+int(delay/1000)+1
    end if
    page = {data:RCopy(data),due:due}
    if RGet(request.context,"refresh",false)
        if m.libraryRefresh = invalid then return invalid
        m.libraryRefresh.pages.push(page)
        cursor = RText(data.next_cursor)
        if m.libraryRefresh.pages.count() < m.libraryRefresh.target and cursor <> ""
            query = RQueryFields(data.query)
            query.offset = cursor
            m.libraryRefresh.nextQuery = query
            rLibraryRefreshPoll(rNow())
            return invalid
        end if
        m.libraryPages = m.libraryRefresh.pages
        for i = 0 to m.libraryPages.count()-1
            index = m.libraryFirst+i
            if index < 10001
                if index < m.libraryCursors.count() then m.libraryCursors[index] = m.libraryPages[i].data.query.offset else m.libraryCursors.push(m.libraryPages[i].data.query.offset)
            end if
        end for
        m.libraryRefresh = invalid
        m.pageCursors = {}
    else if RGet(request.context,"direction") = "previous"
        pages = [page]
        pages.append(m.libraryPages)
        while pages.count() > 3
            pages.pop()
        end while
        m.libraryPages = pages
        m.libraryFirst = request.context.page_index
        m.pageCursors = {}
    else
        index = m.libraryFirst+m.libraryPages.count()
        if index < 10001
            if index < m.libraryCursors.count() then m.libraryCursors[index] = data.query.offset else m.libraryCursors.push(data.query.offset)
        end if
        m.libraryPages.push(page)
        while m.libraryPages.count() > 3
            m.libraryPages.shift()
            m.libraryFirst++
        end while
        m.pageCursors = {}
    end if
    cards = []
    m.libraryRefreshDue = 0
    reason = ""
    for each retained in m.libraryPages
        cards.append(retained.data.cards)
        if RText(retained.data.reason) <> "" then reason = retained.data.reason
        if retained.due > 0 and (m.libraryRefreshDue = 0 or retained.due < m.libraryRefreshDue) then m.libraryRefreshDue = retained.due
    end for
    result = RCopy(m.libraryPages[m.libraryPages.count()-1].data)
    result.cards = cards
    result.reason = reason
    return result
end function

sub rLiveSources(card as object, connection = invalid as dynamic)
    rCancelAdmission()
    rCancelDiscovery()
    m.playCard = card
    m.sourceQuality = invalid
    rOpenDrawer("Choose a source",[],"sources")
    m.drawerSubtitle.text = card.title
    m.drawerMessage.text = "Finding sources…"
    body = {}
    if connection <> invalid then body.connection_id = connection
    rSend("POST",rProfilePath("/live/"+REncode(card.identity.id)+"/sources"),body,"live:sources",{source_epoch:m.sourceEpoch})
end sub

function rLibraryPrevious() as boolean
    if m.route <> "library" or m.libraryFirst <= 0 or m.libraryPages.count() = 0 then return false
    if m.pending.doesExist("library") or m.libraryRefresh <> invalid or rLibraryRetryRequired() then return true
    for each request in m.retryAuth
        if request.tag = "library" and rRequestCurrent(request) then return true
    end for
    index = m.libraryFirst-1
    if index >= m.libraryCursors.count() then return false
    query = RQueryFields(m.libraryPages[0].data.query)
    query.offset = m.libraryCursors[index]
    rSend("GET",rProfilePath("/library"),invalid,"library",{catalog_version:m.catalogVersion,direction:"previous",page_index:index},query)
    return true
end function

function rLibraryRetryRequired() as boolean
    if not RObject(m.failedRequest) then return false
    return m.failedRequest.tag = "library" and rRequestCurrent(m.failedRequest)
end function

sub rLibraryStatus(failed as boolean)
    m.message.translation = [96,236]
    m.message.width = 1400
    m.message.color = "#B6B4AF"
    if failed then m.message.color = "#FF7A6E"
    height = 0
    if m.message.text <> ""
        measure = CreateObject("roSGNode","Label")
        measure.font = m.message.font
        measure.text = m.message.text
        height = 31
        if measure.boundingRect().width > m.message.width or instr(1,m.message.text,chr(10)) > 0 then height = 62
    end if
    m.message.height = 0
    ' Native wrapped labels require a full two-line drawing area; reserve only
    ' the measured line count in the catalog layout below the transparent label.
    if height > 0 then m.message.height = 62
    rCatalogViewport(236+height)
end sub

sub rBackdrop(uri as string)
    width = int(m.backdrop.width)
    height = int(m.backdrop.height)
    if m.backdrop.uri = uri and (m.backdrop.loadWidth <> width or m.backdrop.loadHeight <> height) then m.backdrop.uri = ""
    m.backdrop.loadWidth = width
    m.backdrop.loadHeight = height
    m.backdrop.uri = uri
end sub

sub rCatalogViewport(y as integer)
    m.catalogViewportY = y
    m.grid.translation = [96,y+m.catalogOffset]
    m.top.findNode("catalogClip").clippingRect = [80,y,1760,1080-y]
    rCatalogQueueVisibility()
end sub

sub rCatalogQueueVisibility()
    if m.route <> "movie" and m.route <> "series" and m.route <> "anime" and m.route <> "library" then return
    m.catalogLayoutTick.control = "stop"
    m.catalogLayoutTick.control = "start"
end sub

sub rCatalogEnsureVisible()
    if m.route <> "movie" and m.route <> "series" and m.route <> "anime" and m.route <> "library" then return
    if not m.grid.visible or not m.grid.isInFocusChain() or m.catalogExpectedFocus <> invalid then return
    if m.drawer.visible or rInputVisible() or m.librarySheet.visible or m.filterPage.visible then return
    if m.grid.content = invalid then return
    if m.grid.content.getChild(m.grid.itemFocused) = invalid then return
    bounds = m.grid.sceneSubBoundingRect("focusItem")
    if not RObject(bounds) then return
    ' A missing native subpart returns the whole grid bounds. Never use that as a card.
    if abs(bounds.width-m.grid.itemSize[0]) > 1 or abs(bounds.height-m.grid.itemSize[1]) > 1 then return
    offset = rCatalogVisibleOffset(bounds,m.catalogViewportY,m.catalogOffset)
    if offset = m.catalogOffset then return
    m.catalogOffset = offset
    m.grid.translation = [96,m.catalogViewportY+offset]
end sub

function rCatalogVisibleOffset(bounds as object, viewportTop as integer, oldOffset as integer) as integer
    offset = oldOffset
    if bounds.y < viewportTop
        offset += viewportTop-bounds.y
    else if bounds.y+bounds.height > 1080
        offset -= bounds.y+bounds.height-1080
    end if
    if offset > 0 then offset = 0
    return offset
end function
