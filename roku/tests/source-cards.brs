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
    ' SourceCard handlers with node-field fakes (interpreter-independent; no SceneGraph runtime).
    nodes = {}
    for each id in ["provider","description","badges","surface","quality","qualitySurface","playIcon"]
        nodes[id] = {text:"",uri:"",color:"",blendColor:"",focused:false,font:{size:0}}
    end for
    m.top = {nodes:nodes,findNode:SourceCardFakeFind,listHasFocus:false,focusPercent:0}
    init()
    m.top.itemContent = {title:title,description:"Reported languages · " + SourceReportedLanguages(source),sourceBadges:"BEST MATCH · LAST PLAYED",hasField:SourceCardFakeHasField,observeField:SourceCardFakeObserve,unobserveField:SourceCardFakeObserve}
    contentChanged()
    ensure(nodes.quality.text = "2160p","quality chip shows the reported resolution")
    ensure(nodes.provider.text <> "" and instr(1,nodes.provider.text,"2160p") = 0,"provider line does not repeat the quality chip")
    ensure(nodes.description.text = "Reported languages · English / Italian +1","language information stays on its own line")
    ensure(nodes.badges.text = "BEST MATCH · LAST PLAYED","source badges remain separately visible")
    m.top.listHasFocus = true
    m.top.focusPercent = 1
    focusChanged()
    ensure(nodes.surface.focused and nodes.playIcon.uri = "pkg:/images/lucide/play-focus.png","focus uses the stable ring and focused play icon")
    m.top.focusPercent = 0
    focusChanged()
    ensure(not nodes.surface.focused and nodes.playIcon.uri = "pkg:/images/lucide/play-primary.png","recycled unfocused card resets cue")
    m.top.itemContent = {title:"Provider",description:"",hasField:SourceCardFakeHasField,observeField:SourceCardFakeObserve,unobserveField:SourceCardFakeObserve}
    contentChanged()
    ensure(nodes.quality.text = "Auto" and nodes.badges.text = "","recycled card without badges clears stale badges")
    print "ROKU_SOURCE_CARDS_OK"
end sub
sub ensure(value as boolean, message as string)
    if not value
        print "FAIL ";message
        stop
    end if
end sub

function SourceCardFakeFind(id as string) as dynamic
    return m.nodes[id]
end function
function SourceCardFakeHasField(name as string) as boolean
    return m.DoesExist(name)
end function
sub SourceCardFakeObserve(field as string, handler = "" as string)
end sub
