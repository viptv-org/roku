sub Main()
    p = {source_addon_id:"addon:1",source_name:"One",source_quality:"1080p",source_audio:"English",audio_language:"eng",source_binge_group:"group-A"}
    same = {id:"same-group",source_addon_id:"addon:1",name:"1080p x264 English",source_binge_group:"group-A"}
    dub = {id:"best-audio",source_addon_id:"addon:2",name:"1080p x264 English dubbed"}
    check(BestContinuationSource([same,dub],p).id = dub.id,"weighted audio beats old provider/group preference")
    check(BestContinuationSource([],p) = invalid,"empty discovery never invents a source")
    check(BestContinuationSource([{id:"actual-provider-episode-2",source_addon_id:"iptv:2"}],{source_addon_id:"iptv:2"}).id = "actual-provider-episode-2","IPTV actual episode from same account supported")
    check(BestContinuationSource([{id:"wrong-account",source_addon_id:"iptv:3"}],{source_addon_id:"iptv:2"}) = invalid,"IPTV account remains fixed")
    resumed = StableSourcePreference({source_addon_id:"iptv:2",source_name:"Provider",source_fingerprint:"abc",audio_language:"eng"})
    check(resumed.source_addon_id = "iptv:2" and resumed.audio_language = "eng","IPTV resume and audio persisted")
    items = ContinueWatchingItems([{id:"episode",type:"series",series_id:"series",position:100,duration:100,queue_status:"pending"},{id:"old",type:"series",series_id:"series",position:5,duration:100}])
    check(items.count()=1 and items[0].id="episode","completed series stays actionable without older episode resurrection")
    print "CONTINUATION_POLICY_OK"
end sub
sub check(value as boolean, message as string)
    if not value then throw message
end sub
