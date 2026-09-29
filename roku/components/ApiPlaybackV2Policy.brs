' Task-scoped BE-002 boundary. Never render/log raw envelopes or credentials.
function RokuPlaybackV2Body(request as object, capabilities as object) as dynamic
    body = request.body
    if not AccountIsObject(body) then return invalid
    source = Txt(body.stream_id)
    identity = Txt(body.startup_id,Txt(request.request_id))
    if len(source) < 1 or len(source) > 256 then return invalid
    if not RokuPlaybackV2Id(identity) then return invalid
    if not ApiIsNumber(body.position) then return invalid
    if body.position < 0 or body.position > 604800 then return invalid
    if not MatchInteger(capabilities.max_width,1,16384) or not MatchInteger(capabilities.max_height,1,16384) then return invalid
    video = []
    audio = []
    if capabilities.h264 = true then video.push("h264")
    if capabilities.hevc = true then video.push("hevc")
    if capabilities.aac = true then audio.push("aac")
    conversion = "auto"
    if body.force_transcode = true then conversion = "audio_video"
    output = {request_id:identity,stream_id:source,position:body.position,force_gateway:true,conversion:conversion,subtitles_off:body.subtitles_off = true,client:{platform:"roku",can_play_direct:false,max_width:capabilities.max_width,max_height:capabilities.max_height,video_codecs:video,audio_codecs:audio}}
    if MatchInteger(body.audio_track_index,0,65535) then output.audio_track = body.audio_track_index
    if output.subtitles_off <> true and MatchInteger(body.subtitle_track_index,0,65535) then output.subtitle_track = body.subtitle_track_index
    if Txt(body.audio_language) <> "" and len(Txt(body.audio_language)) <= 32 then output.audio_language = body.audio_language
    return output
end function

function RokuPlaybackV2Id(value as dynamic) as boolean
    if GetInterface(value,"ifString") = invalid then return false
    return CreateObject("roRegex","^[a-zA-Z0-9_-]{1,128}$","").IsMatch(value)
end function

' Closed states: a terminal/pending lease never contains playable media.
function RokuPlaybackV2Lease(value as dynamic, expectedId = "" as string) as object
    failure = {ok:false,error:"The server returned an invalid playback session.",error_code:"invalid_playback_response",data:invalid}
    if not AccountIsObject(value) then return failure
    if not RokuPlaybackV2Id(value.id) then return failure
    if expectedId <> "" and value.id <> expectedId then return failure
    status = Txt(value.status)
    if status <> "starting" and status <> "ready" and status <> "failed" and status <> "expired" and status <> "released" then return failure
    if not ApiIsNumber(value.expires_at) then return failure
    if value.expires_at < 0 or value.expires_at > 9007199254740# then return failure
    if not MatchInteger(value.renew_after_seconds,1,300) then return failure
    output = {id:value.id,status:status,expires_at:value.expires_at,renew_after_seconds:value.renew_after_seconds}
    if status <> "ready"
        if status = "failed" or status = "expired" or status = "released"
            code = Txt(value.error_code)
            if code = "" then code = "playback_expired"
            output.error_code = left(code,80)
            output.error = ApiDisplayError(FormatJson({error_code:code}),409)
        end if
        return {ok:true,data:output}
    end if
    delivery = value.delivery
    if not AccountIsObject(delivery) then return failure
    ' Roku always requires an authorized gateway, even if it can decode MP4 directly.
    if delivery.kind <> "gateway" then return failure
    url = Txt(delivery.url)
    if len(url) > 16384 then return failure
    safeUrl = CreateObject("roRegex","^https://(\[[0-9a-f:.]+\]|[a-z0-9](?:[a-z0-9.-]*[a-z0-9])?)(:[0-9]{1,5})?/[^\x00-\x20\\#]*$","i")
    if not safeUrl.IsMatch(url) then return failure
    slash = Instr(9,url,"/")
    if slash < 1 then return failure
    if ApiOrigin(Left(url,slash-1)) = "" then return failure
    if delivery.headers <> invalid
        if not AccountIsObject(delivery.headers) then return failure
        if delivery.headers.count() <> 0 then return failure
    end if
    if delivery.authorization <> invalid then return failure
    if delivery.format <> "hls" then return failure
    if delivery.mode <> "direct" and delivery.mode <> "remux" and delivery.mode <> "transcode" then return failure
    if delivery.video_mode <> "copy" and delivery.video_mode <> "encode" then return failure
    if delivery.audio_mode <> "copy" and delivery.audio_mode <> "encode" and delivery.audio_mode <> "none" then return failure
    if not ApiIsNumber(delivery.position) or not ApiIsNumber(delivery.duration) then return failure
    if delivery.position < 0 or delivery.position > 604800 or delivery.duration < 0 or delivery.duration > 604800 then return failure
    if GetInterface(delivery.live,"ifBoolean") = invalid or GetInterface(delivery.subtitles_supported,"ifBoolean") = invalid then return failure
    if not ApiIsArray(delivery.audio_tracks) or not ApiIsArray(delivery.subtitle_tracks) then return failure
    if delivery.audio_tracks.count() > 256 or delivery.subtitle_tracks.count() > 256 then return failure
    for each tracks in [delivery.audio_tracks,delivery.subtitle_tracks]
        for each track in tracks
            if not AccountIsObject(track) then return failure
            if not MatchInteger(track.input_index,0,65535) then return failure
        end for
    end for
    session = {id:value.id,url:url,format:"hls",mode:delivery.mode,delivery_kind:"gateway",video_mode:delivery.video_mode,audio_mode:delivery.audio_mode,position:delivery.position,duration:delivery.duration,live:delivery.live,audio_tracks:RokuPlaybackV2Tracks(delivery.audio_tracks),subtitle_tracks:RokuPlaybackV2Tracks(delivery.subtitle_tracks),subtitles_supported:delivery.subtitles_supported,expires_at:value.expires_at,renew_after_seconds:value.renew_after_seconds}
    if delivery.live then session.position = 0
    for each track in session.audio_tracks
        if track.selected = true then session.selected_audio = track
    end for
    for each track in session.subtitle_tracks
        if track.selected = true then session.selected_subtitle = track
    end for
    output.session = session
    return {ok:true,data:output}
end function

function RokuPlaybackV2Tracks(values as object) as object
    output = []
    for each value in Bounded(values,32)
        track = {input_index:value.input_index}
        if MatchInteger(value.output_index,0,65535) then track.output_index = value.output_index
        for each field in ["name","label","language","codec"]
            if GetInterface(value[field],"ifString") <> invalid then track[field] = left(value[field],128)
        end for
        for each field in ["selected","supported","selectable"]
            if GetInterface(value[field],"ifBoolean") <> invalid then track[field] = value[field]
        end for
        output.push(track)
    end for
    return output
end function
