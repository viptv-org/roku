sub Main()
    m.calls = 0
    m.captionUrl = "https://gateway.example/base/media/viewer/token/caption_1.srt"
    request = {tag:"subtitle",body:{external_subtitle_id:"opaque-subtitle"},access_token:"fixture-only",base:"https://api.example"}
    session = {id:"viewer",url:"https://gateway.example/base/media/viewer/token/index.m3u8",external_subtitles_supported:true,live:false}
    result = RokuPrepareProviderCaption(request,session,12000)
    check(result.ok and m.calls = 1,"external selection attaches to the replacement viewer before publication")
    check(m.sent.path = "/api/v2/playback/viewer/subtitles" and m.sent.body.count() = 1 and m.sent.body.subtitle_id = "opaque-subtitle","only the opaque subtitle ID is sent to the API")
    content = {}
    ApplyProviderCaption(content,result.data)
    check(content.SubtitleTracks[0].TrackName = m.captionUrl and content.SubtitleTracks[0].Language = "eng","native content receives the viewer URL and caption language")
    check(content.SubtitleConfig.TrackName = m.captionUrl,"caption selection exists before decoder content is assigned")
    m.captionUrl = "https://other.example/base/media/viewer/token/caption_1.srt"
    check(not RokuPrepareProviderCaption(request,session,12000).ok,"a different media origin is refused")
    m.captionUrl = "https://gateway.example/base/media/foreign/token/caption_1.srt"
    check(not RokuPrepareProviderCaption(request,session,12000).ok,"a different viewer capability is refused")
    check(not RokuCaptionUrl(session.url,session.url+"?access_token=secret"),"API-style credential queries cannot become caption tracks")
    before = m.calls
    session.external_subtitles_supported = false
    check(not RokuPrepareProviderCaption(request,session,12000).ok and m.calls = before,"old gateways do not receive unsupported attachment requests")
    owner = {id:"episode",stream_id:"source"}
    fields = TrackRequestFields(owner,{owner:"source:source",external_subtitle_id:"opaque-subtitle",subtitle_track_index:2})
    check(fields.external_subtitle_id = "opaque-subtitle" and fields.subtitle_track_index = invalid,"external and embedded subtitle intents do not conflict")
    check(TrackRequestFields({id:"other",stream_id:"different"},{owner:"source:source",external_subtitle_id:"opaque-subtitle"}).count() = 0,"a different source cannot inherit caption intent")
    print "ROKU_PROVIDER_CAPTIONS_OK"
end sub

function HttpRequestRaw(request as object,result as object,method as string,sanitize as boolean) as object
    m.calls++ : m.sent = request
    return {ok:true,status:200,data:{url:m.captionUrl,format:"srt",language:"en",label:"English",timeline_offset_seconds:48.6#}}
end function

function RokuPlaybackV2Empty(tag as dynamic) as object
    return {tag:tag,ok:false,status:0,error:"",data:invalid}
end function

sub check(value as boolean,label as string)
    if not value then throw label
end sub
