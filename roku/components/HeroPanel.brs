sub init()
    m.top.findNode("backdrop").observeField("loadStatus","heroArtLoaded")
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
    instant = m.top.findNode("backdropInstant")
    if instant <> invalid then instant.visible = instant.uri <> "" and not art.visible
end sub

sub render()
    item = m.top.model
    if item = invalid then return
    compact = m.top.compact
    height = 720
    if compact then height = 336
    m.top.clippingRect = [0,0,1280,height]
    for each id in ["base","gradientLeft","gradientBottom"]
        m.top.findNode(id).height = height
    end for
    ' Keep the same image framing when the shelf moves up; clip, do not zoom.
    m.top.findNode("backdrop").height = 720
    portrait = Txt(item.poster)
    backdrop = ""
    for each field in ["backdrop","background"]
        uri = Txt(item[field])
        if uri <> "" and uri <> portrait
            backdrop = uri
            exit for
        end if
    end for
    art = m.top.findNode("backdrop")
    if m.artOriginal <> backdrop then m.artRetried = false
    m.artOriginal = backdrop
    ' Show the shelf's already-decoded card image instantly while the hi-res loads.
    instant = m.top.findNode("backdropInstant")
    instantUri = ""
    if backdrop <> "" then instantUri = ImageUrl(backdrop,256,144,false)
    if instant.uri <> instantUri then instant.uri = instantUri
    instant.loadWidth = ImagePixels(256)
    instant.loadHeight = ImagePixels(144)
    uri = ImageUrl(backdrop,1280,720,true)
    if m.artRetried = true then uri = backdrop
    art.loadWidth = ImagePixels(1280)
    art.loadHeight = ImagePixels(720)
    if art.uri <> uri
        m.top.artState = "loading"
        art.uri = uri
    end if
    heroArtLoaded()
    fallback = m.top.findNode("portrait")
    fallback.uri = ""
    fallback.visible = false
    fallback.translation = [938,102]
    fallback.width = 252
    fallback.height = 378
    m.top.findNode("gradientLeft").visible = backdrop <> ""
    m.top.findNode("gradientBottom").visible = backdrop <> ""
    eyebrow = m.top.findNode("eyebrow")
    eyebrow.font.size = 14
    eyebrow.text = "FEATURED " + ucase(Txt(item.type))
    if Txt(item.type) = "live" then eyebrow.text = "LIVE NOW"
    if item.progressFraction <> invalid
        if item.progressFraction >= 0 then eyebrow.text = "CONTINUE WATCHING"
    end if
    if Txt(item.type) = "" then eyebrow.text = ""
    title = m.top.findNode("title")
    title.font.size = 44
    if title.text <> Txt(item.name,"VIPTV") then title.text = Txt(item.name,"VIPTV")
    facts = []
    year = Txt(item.year,Txt(item.releaseInfo))
    if year <> "" then facts.push(year)
    runtime = Txt(item.runtime)
    if runtime <> "" then facts.push(runtime)
    genres = []
    for each genre in Bounded(item.genres,2)
        if Txt(genre) <> "" then genres.push(Txt(genre))
    end for
    if genres.count() > 0 then facts.push(genres.join(" / "))
    if Txt(item.context) <> "" then facts.push(item.context)
    factLabel = m.top.findNode("facts")
    factText = facts.join("  ·  ")
    if factLabel.text <> factText then factLabel.text = factText
    factLabel.font.size = 18
    summary = m.top.findNode("summary")
    description = Txt(item.description)
    if description = "" then description = Txt(item.overview)
    summary.text = description
    summary.font.size = 20
    eyebrow.translation = [100,128]
    title.translation = [100,166]
    summary.translation = [100,228]
    factLabel.translation = [100,322]
    if compact
        eyebrow.translation = [100,44]
        title.translation = [100,76]
        title.font.size = 38
        factLabel.translation = [100,138]
        summary.translation = [100,178]
        fallback.translation = [1010,28]
        fallback.width = 176
        fallback.height = 264
    end if
end sub
