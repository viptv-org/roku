sub Main()
    caps = {max_width:3840,max_height:2160,h264:true,hevc:true,aac:true,direct_play:true}
    request = {request_id:"1-2",body:{startup_id:"start_1",stream_id:"source_1",position:42,force_transcode:false,quality:"1080p",audio_track_index:2,subtitle_track_index:3,subtitles_off:true}}
    body = RokuPlaybackV2Body(request,caps)
    if body.client.platform <> "roku" or body.client.can_play_direct <> false or body.force_gateway <> true then throw "gateway policy lost"
    if body.client.max_height <> 2160 or body.DoesExist("quality") then throw "decoder facts capped"
    if body.audio_track <> 2 or body.DoesExist("subtitle_track") then throw "track/off precedence lost"
    if body.position <> 42 or body.stream_id <> "source_1" then throw "source or position changed"
    request.body.force_transcode = true
    if RokuPlaybackV2Body(request,caps).conversion <> "audio_video" then throw "conversion lost"
    value = {id:"pb2_fixture",status:"ready",expires_at:1800000060#,renew_after_seconds:20,delivery:{kind:"gateway",url:"https://gateway.example/base/media/viewer/cap/index.m3u8",format:"hls",mode:"direct",video_mode:"copy",audio_mode:"copy",position:42,duration:120,live:false,audio_tracks:[{input_index:2,selected:true,language:"en"}],subtitle_tracks:[],subtitles_supported:false}}
    lease = RokuPlaybackV2Lease(value,"pb2_fixture")
    if not lease.ok then throw "valid lease refused"
    if lease.data.session.delivery_kind <> "gateway" or lease.data.session.position <> 42 or lease.data.session.selected_audio.input_index <> 2 then throw "delivery facts lost"
    value.delivery.audio_tracks[0].url = "https://provider.invalid/private-track"
    if RokuPlaybackV2Lease(value).data.session.audio_tracks[0].DoesExist("url") then throw "raw track authority exposed"
    if RokuPlaybackV2Lease(value,"foreign").ok then throw "identity mismatch accepted"
    for each state in ["starting","failed","expired","released"]
        value.status = state
        value.error_code = "provider_connection_limit"
        value.error = "https://provider.invalid/private-token"
        lease = RokuPlaybackV2Lease(value)
        if not lease.ok or lease.data.DoesExist("session") then throw "terminal media exposed"
        if instr(1,FormatJson(lease),"private-token") > 0 then throw "private error exposed"
        if state = "failed" and instr(1,lease.data.error,"connection limit") = 0 then throw "provider cause lost"
    end for
    value.status = "ready"
    for each url in ["http://gateway.example/media/a","https://user:secret@gateway.example/media/a","https://gateway.example/media/a#fragment","https://gateway.example:99999/media/a"]
        value.delivery.url = url
        if RokuPlaybackV2Lease(value).ok then throw "unsafe media URL accepted"
    end for
    value.delivery.url = "https://gateway.example/media/a"
    value.delivery.kind = "direct"
    if RokuPlaybackV2Lease(value).ok then throw "unsolicited direct playback accepted"
    value.delivery.kind = "gateway"
    value.delivery.headers = {Authorization:"source-secret"}
    if RokuPlaybackV2Lease(value).ok then throw "gateway source auth accepted"
    discovery = SanitizeApiResponse("/api/v2/streams/job?after=0","GET",{events:[{seq:1,source:"iptv:1",streams:[{id:"source",source_addon_id:"iptv:1"}]},{seq:2,source:"iptv:2",streams:[],error_code:"provider_connection_limit",error:"https://provider.invalid/private-token"}],done:true})
    if not discovery.ok or discovery.data.events[0].streams.count() <> 1 then throw "healthy source dropped"
    if instr(1,discovery.data.events[1].error,"connection limit") = 0 or instr(1,FormatJson(discovery),"private-token") > 0 then throw "discovery cause lost or leaked"
    check(RokuTorrentStageText("finding_peers") = "Finding peers…","measured peer stage uses canonical copy")
    check(RokuTorrentStageText("fetching_metadata") = "Fetching metadata…","measured metadata stage uses canonical copy")
    check(RokuTorrentStageText("opening_archive") = "Opening archive…","measured archive stage uses canonical copy")
    check(RokuTorrentStageText("buffering") = "Buffering…","measured buffering stage uses canonical copy")
    check(RokuTorrentStageText("private raw upstream message") = "","unknown progress text is refused")
    print "PLAYBACK_V2_CONTRACT_OK"
end sub

sub check(value as boolean, message as string)
    if not value then throw message
end sub
