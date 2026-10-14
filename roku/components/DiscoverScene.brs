sub openDiscover(kind as string)
    cancelBrowse()
    m.discoverActive = true
    m.discoverType = kind
    m.mediaType = kind
    m.discoverGenre = ""
    m.discoverExtras = {}
    m.discoverVectors = {}
    m.search = ""
    m.discoverCatalogs = []
    m.catalog = invalid
    m.discoverPreferredCatalog = invalid
    m.offsetHistory = []
    m.nextOffset = invalid
    rows("Discover",[{name:"Loading catalogs…",action:"waiting"}],"loading","Movies, series and live catalogs from your configured addons.")
    request("GET","/api/v3/discovery-controls?type="+Enc(kind),invalid,"discovercatalogs")
end sub

sub discoverUseCatalogs(data as dynamic)
    m.discoverCatalogs = Bounded(data.catalogs,2048)
    m.discoverUnavailableMessage = Txt(data.message)
    m.discoverMediaTypes = Bounded(data.media_types,64)
    supported = false
    for each kind in m.discoverMediaTypes
        if kind = m.discoverType then supported = true
    end for
    if not supported and m.discoverMediaTypes.count() > 0
        openDiscover(m.discoverMediaTypes[0])
        return
    end if
    discoverChooseDefaultCatalog()
    if m.discoverPreferredCatalog <> invalid
        for each catalog in m.discoverCatalogs
            preferred = m.discoverPreferredCatalog
            if Txt(catalog.id) = Txt(preferred.id) and Txt(catalog.type) = Txt(preferred.type) and Txt(catalog.addon_id) = Txt(preferred.addon_id)
                m.catalog = catalog
                uiRequiredGenre()
                exit for
            end if
        end for
        m.discoverPreferredCatalog = invalid
    end if
    discoverBuildFilters()
    browse(m.discoverType,0)
end sub

sub discoverChooseDefaultCatalog()
    m.catalog = invalid
    for each catalog in m.discoverCatalogs
        if DiscoverTypeMatches(Txt(catalog.type),m.discoverType)
            if DiscoveryMissingControl(catalog,"","",{},{}) = ""
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
    if kind = "live"
        openEpg(false)
        return
    end if
    cancelBrowse()
    m.mediaType = kind
    m.offset = offset
    title = "Discover"
    if kind = "live" then title = "Live TV"
    rows(title,[],"browse","")
    if m.discoverActive = true and kind <> "live"
        discoverBuildFilters()
        if m.catalog = invalid
            uiEmpty("No catalogs are available",Txt(m.discoverUnavailableMessage,"Configure this profile’s discovery provider in the web account settings."))
            if acknowledgementMayFocus()
                if Bounded(m.discoverMediaTypes,64).count() > 0 then m.discoverTypes.setFocus(true) else m.sidebar.setFocus(true)
            end if
            return
        end if
        missing = DiscoveryMissingControl(m.catalog,m.search,m.discoverGenre,m.discoverExtras,m.discoverVectors)
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
        if m.catalog <> invalid
            if Txt(m.catalog.id) <> "" then path += "&catalog=" + Enc(Txt(m.catalog.id))
            if Txt(m.catalog.addon_id) <> "" then path += "&addon_id=" + Enc(Txt(m.catalog.addon_id))
        end if
        genre = Txt(m.discoverGenre).trim()
        if m.discoverActive = true and genre <> "" then path += "&genre=" + Enc(genre)
        if m.discoverActive = true and m.discoverExtras <> invalid
            if m.discoverExtras.count() > 0 then path += "&extras=" + Enc(FormatJson(m.discoverExtras))
        end if
    end if
    vectors = DiscoveryQueryValues(m.discoverVectors)
    if m.discoverActive = true and vectors.count() > 0 then path += "&values="+Enc(FormatJson(vectors))
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
