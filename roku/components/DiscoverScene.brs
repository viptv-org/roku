sub openDiscover(kind as string)
    cancelBrowse()
    m.discoverActive = true
    m.discoverType = kind
    m.mediaType = kind
    m.discoverGenre = ""
    m.discoverExtras = {}
    m.search = ""
    m.discoverCatalogs = []
    m.catalog = invalid
    m.offsetHistory = []
    m.nextOffset = invalid
    rows("Discover",[{name:"Loading catalogs…",action:"waiting"}],"loading","Movies, series and live catalogs from your configured addons.")
    request("GET","/api/catalogs",invalid,"discovercatalogs")
end sub

sub discoverUseCatalogs(data as dynamic)
    m.discoverCatalogs = []
    for each catalog in Bounded(data,2048)
        m.discoverCatalogs.push(catalog)
    end for
    supported = false
    for each catalog in m.discoverCatalogs
        if DiscoverTypeMatches(Txt(catalog.type),m.discoverType) then supported = true
    end for
    if not supported and m.discoverCatalogs.count() > 0
        for each catalog in m.discoverCatalogs
            if Txt(catalog.type) <> "live"
                m.discoverType = Txt(catalog.type)
                exit for
            end if
        end for
    end if
    discoverChooseDefaultCatalog()
    discoverBuildFilters()
    browse(m.discoverType,0)
end sub

sub discoverChooseDefaultCatalog()
    m.catalog = invalid
    for each catalog in m.discoverCatalogs
        if DiscoverTypeMatches(Txt(catalog.type),m.discoverType)
            if not UiCatalogRequired(catalog,"search")
                m.catalog = catalog
                exit for
            end if
        end if
    end for
    if m.catalog = invalid and m.discoverCatalogs.count() > 0
        for each catalog in m.discoverCatalogs
            if DiscoverTypeMatches(Txt(catalog.type),m.discoverType) then m.catalog = catalog
        end for
    end if
    uiRequiredGenre()
end sub

sub discoverBuildFilters()
    uiDiscoverFilters()
end sub

sub discoverFilterSelected()
    uiDiscoverFilterSelected()
end sub

sub browse(kind as string, offset as integer)
    cancelBrowse()
    m.mediaType = kind
    m.offset = offset
    title = "Discover"
    if kind = "live" then title = "Live TV"
    rows(title,[],"browse","")
    if m.discoverActive = true and kind <> "live"
        discoverBuildFilters()
        if m.catalog = invalid
            uiEmpty("No catalogs yet","Add a movie or series catalog in your account settings.")
            return
        end if
        missing = DiscoverMissingOption(m.catalog,m.search,m.discoverGenre,m.discoverExtras)
        if missing <> ""
            uiEmpty("Choose " + missing,"Use the filters above to browse this catalog.")
            if acknowledgementMayFocus() then m.discoverFilters.setFocus(true)
            return
        end if
        if UiCatalogRequired(m.catalog,"search") and Txt(m.search).trim() = ""
            uiEmpty("Search this catalog","Choose Search above to find a title.")
            if acknowledgementMayFocus() then m.discoverFilters.setFocus(true)
            return
        end if
    end if
    if kind = "live"
        path = LiveChannelPath(Txt(m.liveCategory),Txt(m.search),offset)
    else
        path = "/api/discover?type=" + Enc(kind) + "&skip=" + offset.toStr()
        query = Txt(m.search).trim()
        ' Omitting an empty search preserves normal Stremio catalog browsing and
        ' its authoritative cursor; search= would incorrectly invoke aggregation.
        if query <> "" then path += "&search=" + Enc(query)
        if m.catalog <> invalid then path += "&catalog=" + Enc(Txt(m.catalog.id)) + "&addon_id=" + Enc(Txt(m.catalog.addon_id))
        genre = Txt(m.discoverGenre).trim()
        if m.discoverActive = true and genre <> "" then path += "&genre=" + Enc(genre)
        if m.discoverActive = true and m.discoverExtras <> invalid
            if m.discoverExtras.count() > 0 then path += "&extras=" + Enc(FormatJson(m.discoverExtras))
        end if
    end if
    request("GET",path,invalid,"browse")
    m.status.text = "Loading " + kind + "…"
end sub

function acknowledgementMayFocus() as boolean
    if m.uiReady = true
        if m.choicePanel.visible or m.fullTextPanel.visible then return false
        if m.profileEditor.visible or m.textEntry.visible then return false
    end if
    ' Focus safety applies both during response rendering and local view changes
    ' such as submitting a native keyboard dialog.
    if m.sidebar <> invalid
        if m.sidebar.hasFocus() then return false
    end if
    if m.top <> invalid
        if m.top.dialog <> invalid then return false
    end if
    if m.video <> invalid
        if m.video.visible then return false
    end if
    if m.pausedVOD = true then return false
    return true
end function
