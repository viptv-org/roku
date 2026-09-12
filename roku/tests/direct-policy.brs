sub Main()
    caps = {max_width:1920,max_height:1080,hevc_sdr:false,direct_play:true}
    english = SourceMatch({name:"Provider",title:"Movie.1080p.x264.English.AAC"},caps,{audio_language:"en"})
    ensure(not english.best and english.likely,"plain English text is compatible but insufficient for best match")
    multi = SourceMatch({title:"Movie.1080p.x264.MULTI AUDIO"},caps,{audio_language:"en"})
    ensure(not multi.best and multi.rank < english.rank,"MULTI scores above plain English but is not verified English")
    ensure(not SourceMatch({title:"Movie.1080p.x265.English"},caps,{}).likely,"unsupported HEVC is not a direct hint")
    ensure(not SourceMatch({title:"Movie.2160p.x264.English"},caps,{}).likely,"oversized sources are not output matches")
    ensure(not SourceMatch({title:"Movie.1080p.x264.HDR.English"},caps,{}).likely,"HDR remains conservative")
    ensure(SourceMatch({title:"Movie.1080p.x264.Spanish.Audio"},caps,{audio_language:"es"}).best,"profile language takes priority")
    ensure(not SourceMatch({title:"Movie.1080p.x264",description:"English subtitles"},caps,{}).best,"subtitles do not prove spoken language")
    body = PlaybackBody({id:"source1",type:"movie"},"profile1",caps,125,false)
    ensure(body.capabilities.direct_play and body.position = 125,"opt-in and original position survive transport policy")
    ensure(not PlaybackBody({id:"source1",type:"movie"},"profile1",invalid,0,false).capabilities.direct_play,"unknown clients stay managed")
    print "DIRECT_POLICY_OK"
end sub
sub ensure(value as boolean, message as string)
    if not value
        print "FAIL ";message
        stop
    end if
end sub
