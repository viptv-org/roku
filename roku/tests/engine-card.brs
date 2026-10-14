sub Main()
    parent = {id:"opaque-parent/42",kind:"series",ids:[],episode:invalid,edition:invalid}
    one = {id:"opaque-first",kind:"series",ids:[],episode:{order:"aired",season:1,episode:1},edition:invalid}
    two = {id:"opaque-second",kind:"series",ids:[],episode:{order:"aired",season:1,episode:2},edition:invalid}
    card = {identity:two,parent_identity:parent,provider_id:"simkl",title:"Actual episode",poster:"https://images.example/poster.webp",landscape:"https://images.example/still.webp",logo:"https://images.example/logo.png",description:"Host description",metadata:{year:2026,runtime_minutes:24,genres:["Drama"],rating:8.5}}
    before = FormatJson(card)
    item = EngineCard(card)
    check(item.id = "opaque-second" and item.series_id = "opaque-parent/42", "opaque identities survive without parsing")
    check(item.season = 1 and item.episode = 2 and item.logo = card.logo, "coordinates and transparent logo survive")
    check(FormatJson(card) = before, "presentation does not mutate host card")
    history = {identity:one,parent_identity:parent,position_millis:96000,duration_millis:100000,completed_at_millis:1000}
    nextItem = EngineContinuation({card:card,record:history,status:"Next",previous_identity:one})
    check(nextItem.position = invalid and nextItem.duration = invalid and nextItem.queue_status = "next", "next target cannot inherit prior completion clock")
    mismatch = EngineContinuation({card:card,record:history,status:"Resume"})
    check(mismatch.position = invalid, "resume identity mismatch cannot move playhead")
    history.identity = two
    resume = EngineContinuation({card:card,record:history,status:"Resume"})
    check(resume.position = 96 and resume.duration = 100, "matching actual resume clocks convert milliseconds to seconds")
    check(not EngineSameIdentity(one,two), "episode coordinates are identity")
    check(EngineCard({title:"No identity"}) = invalid, "malformed host card cannot render")
    home = {rows:[{id:"never-parse-this",title:"Trending Anime",state:"Ready",cards:[card],browse:{target:"Discover",query:[{id:"type",values:["anime"]},{id:"catalog",values:["simkl-trending"]}]}}]}
    catalogs = EngineCatalogs(home)
    check(catalogs.count() = 1 and catalogs[0].type = "anime" and catalogs[0].id = "simkl-trending", "shelf routes come from explicit server action")
    check(catalogs[0].engine_cards[0].id = two.id and catalogs[0].engine_ready, "startup shelf cards do not require a second discover request")
    check(EngineQueue({entries:[{card:card,record:history,status:"Next"}],next_cursor:"40"}).next_offset = 40, "authoritative continuation cursor survives projection")
    bootstrap = {identity:{profile_id:"1"},home:home,library:{cards:[]},continuation:{entries:[]},subtitle_availability:{available:true,provider_count:1}}
    check(EngineBootstrap(bootstrap).subtitles_available = true, "profile subtitle availability comes from the startup aggregate")
    bootstrap.delete("subtitle_availability")
    check(EngineBootstrap(bootstrap).subtitles_available = false, "older host does not imply enabled subtitle providers")
    print "ROKU_ENGINE_CARD_OK"
end sub

sub check(value as boolean, label as string)
    if not value
        print "FAILED: " + label
        stop
    end if
end sub
