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
    print "ROKU_BROWSE_POLICY_OK"
end sub
sub ensure(value as boolean, message as string)
    if not value
        print "FAIL ";message
        stop
    end if
end sub
