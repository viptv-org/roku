sub Main()
    identity = {id:"opaque:m3u/channel",kind:"channel",ids:[],episode:invalid,edition:invalid}
    card = {identity:identity,title:"News",provider_id:"m3u",metadata:invalid}
    page = {channels:[{id:identity.id,connection_id:"opaque-connection",card:card}],groups:[{id:"opaque/group",label:"News"}],connections:[],next_cursor:"40"}
    channels = EngineLivePage(page,0,40,false)
    check(channels.items[0].id = identity.id and channels.items[0].type = "live", "M3U identity survives projection")
    check(channels.catalog_id = "opaque-connection" and channels.generation = invalid, "opaque connection and unknown generation survive")
    check(channels.next_cursor = "40" and channels.previous_cursor = invalid, "host pagination survives")
    groups = EngineLivePage(page,0,1,true)
    check(groups.items[0].id = "opaque/group" and groups.items[0].name = "News", "opaque group survives")
    guide = EngineLiveGuide({programs:[{title:"News",start_millis:1791999999123#,end_millis:1792001799123#,description:"Now"}]})
    check(abs(guide.programs[0].start-1791999999.123#) < 0.00001#, "epoch precision survives milliseconds conversion")
    card.identity = {id:"substitution",kind:"channel"}
    check(EngineLivePage(page,0,40,false) = invalid, "substituted channel identity rejected")
    print "ROKU_ENGINE_LIVE_OK"
end sub

sub check(value as boolean, label as string)
    if not value
        print "FAILED: " + label
        stop
    end if
end sub
