sub Main()
    ensure(UsesPosterGrid("browse","movie",[{type:"movie"}]),"movies use poster grid")
    ensure(UsesPosterGrid("browse","movie",[{id:"opaque",name:"Movie"}]),"catalog route type supplies missing item type")
    ensure(UsesPosterGrid("browse","series",[{type:"series"},{action:"next"}]),"series preserve paging cards")
    ensure(UsesPosterGrid("browse","search",[{type:"live"},{type:"movie"}]),"mixed search keeps visual movie cards")
    ensure(not UsesPosterGrid("browse","live",[{type:"live"}]),"live stays channel list")
    ensure(not UsesPosterGrid("streams","movie",[{type:"movie"}]),"sources stay metadata cards")
    ensure(RestoreCardIndex(8,12) = 8,"Back restores exact card across grid rows")
    ensure(RestoreCardIndex(80,12) = 11,"shortened results clamp cursor")
    ensure(RestoreCardIndex(invalid,0) = 0,"empty route safe")
    ensure(DiscoverTypeGroup("movie")="movie" and DiscoverTypeGroup("series")="series","canonical types keep their groups")
    ensure(DiscoverTypeGroup("anime")="anime" and DiscoverTypeGroup("anime.series")="anime" and DiscoverTypeGroup("anime.movie")="anime","anime namespaces fold into Anime")
    ensure(DiscoverTypeGroup("collection")="other","custom namespaces fold into Other")
    ensure(DiscoverTypeName("movie")="Movies" and DiscoverTypeName("anime.series")="Anime","type names use group labels")
    ensure(DiscoverTypeName("collection")="Other","custom type names map to Other")
    ensure(DiscoverTypeMatches("anime.series","anime"),"group matching spans namespaces")
    ensure(not DiscoverTypeMatches("movie","anime") and not DiscoverTypeMatches("live","movie"),"type matching stays in-group and never matches live")
    print "ROKU_BROWSE_POLICY_OK"
end sub
sub ensure(value as boolean, message as string)
    if not value
        print "FAIL ";message
        stop
    end if
end sub
