sub Main()
    source = {id:"opaque:source/1",name:"A very very long provider name that should not hide languages",title:"Film.2160p.HEVC.🇮🇹.🇬🇧.mkv",reported_languages:["eng","ita","fra","ENG"],description:"Full provider description"}
    before = FormatJson(source)
    title = SourceCardTitle(source)
    ensure(len(title) <= 45 and instr(1,title,"2160p") > 0 and instr(1,title,"HEVC") > 0,"long provider leaves bounded quality visible")
    ensure(SourceReportedLanguages(source) = "English / Italian +1","reported language words deduplicate and compact")
    ensure(SourceAudioStatus(source) = "Audio · English / Italian +1 (reported)","explicit English hint remains visibly reported rather than verified")
    ensure(SourceAudioStatus({reported_languages:["ita","fra"]}) = "Audio · Italian / French (reported)","foreign-only report stays listed without a playback gate")
    ensure(SourceAudioStatus({}) = "Audio · Language unknown","missing language remains visibly informational")
    ensure(FormatJson(source) = before,"presentation never changes opaque ID or source contract")
    ensure(SourceReportedLanguages({name:"Provider 🇮🇹 🇬🇧",title:"movie.mkv"}) = "Italian / English","flag hints survive cleaning")
    ensure(SourceReportedLanguages({name:"Provider",title:"movie.FRENCH.ENG.1080p"}) = "French / English","filename hints use bounded word tokens")
    ensure(SourceReportedLanguages({name:"It No Hi",title:"The Englishman"}) = "Unknown","no substring or two-letter title false positives")
    ensure(SourceReportedLanguages({name:"🇬🇧",reported_languages:["und"]}) = "Unknown","explicit unknown is not overruled by source decoration")
    ensure(SourceReportedLanguages({reported_languages:["en-US","pt-BR","ja"]}) = "English / Portuguese +1","reported ISO tags become compact words")
    ensure(SourceReportedLanguages({}) = "Unknown","no language claim when hints absent")
    ensure(SourceCardTitle({}) = "Source","empty source title is safe")
    ensure(SourceCardTitle({name:"Cinema Archive 2160p",title:"Film.2160p"}) = "Cinema Archive 2160p","visible provider resolution is not duplicated")
    ensure(SourceCardTitle({name:"Cinema 1080P HEVC",title:"Film.1080p.HEVC"}) = "Cinema 1080P HEVC","visible quality tokens are deduplicated case insensitively")
    ensure(SourceCardTitle({name:"Cinema Archive Premium 2160p",title:"Film.2160p"}) = "Cinema Archive Premiu… · 2160p","quality truncated out of provider is restored as suffix")
    m.provider = {}
    m.badges = {}
    m.badgeSurface = {}
    m.languages = {}
    m.surface = {}
    m.focusOutline = {}
    m.top = {itemContent:{title:title,description:"Reported languages · " + SourceReportedLanguages(source)},focusPercent:1}
    contentChanged()
    focusChanged()
    ensure(m.provider.text <> "" and instr(1,m.badges.text,"2160p") > 0 and instr(1,m.badges.text,"HEVC") > 0,"provider and source badges remain separately visible")
    ensure(m.languages.text = "Reported languages · English / Italian +1","language information stays on its own line")
    ensure(m.focusOutline.opacity = 1 and m.surface.color = "#292C39","focus has rounded outline and contrast cues")
    m.top.focusPercent = 0
    focusChanged()
    ensure(m.focusOutline.opacity = 0,"recycled unfocused card resets cue")
    m.top.itemContent = invalid
    contentChanged()
    ensure(m.provider.text = "" and m.badges.text = "" and m.languages.text = "","recycled empty card clears every line")
    print "ROKU_SOURCE_CARDS_OK"
end sub
sub ensure(value as boolean, message as string)
    if not value
        print "FAIL ";message
        stop
    end if
end sub
