sub Main()
    ensure(CaptionRestartRequired(true,"Off",false),"Off to On requires refresh")
    ensure(not CaptionRestartRequired(true,"On",false),"On keeps native caption readiness")
    ensure(CaptionRestartRequired(false,"On",true),"encoded output requires refresh")
    video = {globalCaptionMode:"Off",subtitleTrack:"stale"}
    PrepareNativeCaptions(video,true)
    ensure(video.globalCaptionMode = "On","enable captions before assigning/playing output")
    PrepareNativeCaptions(video,false)
    ensure(video.globalCaptionMode = "Off" and video.subtitleTrack = "","Off clears old native identity")
    ensure(MatchNativeCaption([{TrackName:"webvtt/9",input_index:5}],"") = "webvtt/9","real native identity not ffprobe input")
    ensure(MatchNativeCaption([{id:"5",input_index:5}],"") = "","numeric and generic IDs are not TrackName")
    ensure(MatchNativeCaption([{TrackName:"webvtt/2"},{TrackName:"webvtt/8"}],"") = "","multiple output captions require known identity")
    ensure(MatchNativeCaption([{TrackName:"webvtt/8"},{TrackName:"webvtt/2"}],"webvtt/2") = "webvtt/2","native reordering preserves TrackName")
    ensure(MatchNativeCaption([{TrackName:"eia608/1"},{TrackName:"webvtt/0"}],"") = "webvtt/0","single text rendition wins over incidental closed captions")
    ensure(MatchNativeCaption(invalid,"") = "","tracks can arrive asynchronously")
    print "ROKU_CAPTION_POLICY_OK"
end sub
sub ensure(value as boolean, message as string)
    if not value
        print "FAIL ";message
        stop
    end if
end sub
