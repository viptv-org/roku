sub init()
    m.top.findNode("backdrop").observeField("loadStatus","heroArtLoaded")
    m.top.findNode("titleLogo").observeField("loadStatus","logoLoaded")
    m.top.findNode("metadataLayoutTimer").observeField("fire","layoutMetadata")
end sub
sub logoLoaded()
    logo = m.top.findNode("titleLogo")
    ready = logo.uri <> "" and logo.loadStatus = "ready"
    if ready and logo.bitmapHeight > 0
        width = 79.0*logo.bitmapWidth/logo.bitmapHeight
        if width > 400 then width = 400
        logo.width = width
    end if
    logo.visible = ready
    m.top.findNode("title").visible = not ready
end sub
sub heroArtLoaded()
    art = m.top.findNode("backdrop")
    if art.loadStatus = "failed" and art.uri <> m.artOriginal and m.artRetried <> true
        m.artRetried = true
        art.uri = m.artOriginal
        m.top.artState = "loading"
        return
    end if
    m.top.artState = art.loadStatus
    art.visible = art.uri <> "" and art.loadStatus = "ready"
    ambient = m.top.findNode("backdropInstant")
    ambient.visible = ambient.uri <> ""
end sub
sub render()
    item = m.top.model
    if item = invalid then return
    m.top.clippingRect = [0,0,1280,633]
    backdrop = ""
    for each field in ["backdrop","background"]
        uri = Txt(item[field])
        if uri <> "" and uri <> Txt(item.poster)
            backdrop = uri
            exit for
        end if
    end for
    art = m.top.findNode("backdrop")
    if m.artOriginal <> backdrop then m.artRetried = false
    m.artOriginal = backdrop
    uri = ImageUrl(backdrop,1120,720,true)
    if m.artRetried = true then uri = backdrop
    if art.uri <> uri then art.uri = uri
    ambient = m.top.findNode("backdropInstant")
    low = ImageUrl(backdrop,80,45,false)
    if ambient.uri <> low then ambient.uri = low
    heroArtLoaded()
    m.top.findNode("portrait").visible = false
    eyebrow = m.top.findNode("eyebrow")
    eyebrow.font.size = 14
    eyebrow.text = "FEATURED " + ucase(Txt(item.type))
    if Txt(item.type) = "live" then eyebrow.text = "LIVE NOW"
    if item.progressFraction <> invalid and item.progressFraction >= 0 then eyebrow.text = "CONTINUE WATCHING"
    if Txt(item.type) = "" then eyebrow.text = ""
    title = m.top.findNode("title")
    title.font.size = 37
    title.text = Txt(item.name,"VIPTV")
    if len(title.text) > 30 then title.font.size = 32
    logo = m.top.findNode("titleLogo")
    logoUri = ImageUrl(Txt(item.logo),410,118,false,true)
    if logo.uri <> logoUri then logo.uri = logoUri
    logoLoaded()
    context = m.top.findNode("episode")
    context.font.size = 16
    context.text = Txt(item.context)
    context.visible = context.text <> ""
    fraction = -1.0
    if item.progressFraction <> invalid then fraction = item.progressFraction
    if fraction > 1 then fraction = 1
    m.top.findNode("progressTrack").visible = fraction >= 0
    m.top.findNode("progressFill").visible = fraction > 0
    m.top.findNode("progressFill").width = 120*fraction
    if fraction < 0 then m.top.findNode("progressFill").width = 0
    elapsed = m.top.findNode("elapsed")
    elapsed.text = Txt(item.elapsed)
    elapsed.visible = elapsed.text <> ""
    layoutMetadata()
    m.top.findNode("metadataLayoutTimer").control = "start"
    facts = []
    if Txt(item.year,Txt(item.releaseInfo)) <> "" then facts.push(Txt(item.year,Txt(item.releaseInfo)))
    if Txt(item.imdbRating) <> "" then facts.push("IMDb " + Txt(item.imdbRating))
    if Txt(item.runtime) <> "" then facts.push(Txt(item.runtime))
    for each genre in Bounded(item.genres,3)
        facts.push(Txt(genre))
    end for
    factsY = 262
    if not context.visible and fraction < 0 and not elapsed.visible then factsY = 228
    factLabel = m.top.findNode("facts")
    factLabel.text = facts.join(" · ")
    factLabel.font.size = 15
    factLabel.translation = [128,factsY]
    summary = m.top.findNode("summary")
    summary.text = Txt(item.description,Txt(item.overview))
    summary.font.size = 17
    summary.translation = [128,factsY+36]
end sub

sub layoutMetadata()
    context = m.top.findNode("episode")
    context.width = 0
    contextWidth = 0
    if context.visible then contextWidth = context.localBoundingRect().width
    if contextWidth > 340 then contextWidth = 340
    context.width = contextWidth
    nextX = 128
    if context.visible then nextX += contextWidth+12
    track = m.top.findNode("progressTrack")
    track.translation = [nextX,238]
    m.top.findNode("progressFill").translation = track.translation
    if track.visible then nextX += 120+12
    m.top.findNode("elapsed").translation = [nextX,228]
end sub
